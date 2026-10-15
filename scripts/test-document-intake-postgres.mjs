// Creates and stops its own loopback-only, disposable PostgreSQL cluster.
// Never reads DATABASE_URL or a production environment file for test targeting.
import {mkdtempSync,readFileSync,readdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
import pg from 'pg';
const binaries='/Applications/Postgres.app/Contents/Versions/latest/bin';
const directory=mkdtempSync(path.join(tmpdir(),'lvsp-intake-pg-'));
const data=path.join(directory,'data');
const port=55439;
function run(command,args){const result=spawnSync(path.join(binaries,command),args,{encoding:'utf8'});if(result.status!==0)throw new Error(result.stderr||result.stdout||command+' failed');}
run('initdb',['-D',data,'-U','lvsp_intake_test','--auth=trust','--no-locale','-E','UTF8']);
let started=false,server,store,client;
try{
 run('pg_ctl',['-D',data,'-l',path.join(directory,'postgres.log'),'-o',`-h 127.0.0.1 -p ${port} -k ${directory}`,'-w','start']);started=true;
 const url=`postgresql://lvsp_intake_test@127.0.0.1:${port}/postgres`;
 client=new pg.Client({connectionString:url});await client.connect();
 const files=readdirSync('database/migrations').filter(x=>x.endsWith('.sql')).sort();
 for(const file of files)await client.query(readFileSync('database/migrations/'+file,'utf8'));
 console.log(`${files.length} migrations applied in disposable cluster`);
 process.env.LVSP_INTAKE_STORAGE='test-filesystem';process.env.LVSP_INTAKE_TEST_DIRECTORY=path.join(directory,'objects');
 process.env.DATABASE_URL=url;process.env.DATABASE_URL_DIRECT=url;process.env.NODE_ENV='test';process.env.AUTH_MODE='database';process.env.LVSP_STORAGE='postgres';
 delete process.env.OPENAI_API_KEY;delete process.env.GEMINI_API_KEY;process.env.LVSP_AI_PROVIDER='';
 process.env.LVSP_AUTH_SECRET='isolated-intake-test-secret-not-a-production-secret';
 ({server,store}=await import('../apps/api/dist/server.js'));
 const {issueToken}=await import('../apps/api/dist/core/auth.js');
 const users=[];for(const role of ['REGISTRY_OFFICER','REGISTRY_OFFICER','MANAGEMENT_VIEWER']){
  const id=(await client.query(`insert into security.app_user(username,status) values($1,'ACTIVE') returning id`,['intake-'+users.length])).rows[0].id;
  users.push(issueToken(id,[role]));
 }
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
 const base=`http://127.0.0.1:${server.address().port}/api/v1/document-intake`;
 async function request(route='',method='GET',body,token=users[0]){
  const response=await fetch(base+route,{method,headers:{'content-type':'application/json',...(token?{authorization:'Bearer '+token}:{})},body:body===undefined?undefined:JSON.stringify(body)});
  return {status:response.status,body:await response.json()};
 }
 assert.equal((await request('','GET',undefined,null)).status,401);
 assert.equal((await request('','GET',undefined,users[2])).status,403);
 const draft=await request('','POST',{title:'Disposable dossier'});assert.equal(draft.status,201);const id=draft.body.data.id;
 assert.equal((await request('/'+id,'GET',undefined,users[1])).status,404);
 const payload={version:1,filename:'evidence.txt',mimeType:'text/plain',documentType:'APPLICATION',base64:Buffer.from('Product evidence ລາວ').toString('base64')};
 const uploaded=await request('/'+id+'/documents','POST',payload);assert.equal(uploaded.status,201);const fileId=uploaded.body.data.id;
 const hidden=await fetch(base.replace('/document-intake','/documents/')+uploaded.body.data.document_id,{headers:{authorization:'Bearer '+users[1]}});assert.equal(hidden.status,404);
 const metadataOnly=(await client.query("select count(*)::int n from information_schema.columns where table_schema='document' and table_name='intake_attachment' and column_name='payload'")).rows[0].n;assert.equal(metadataOnly,0);
 assert.equal((await request('/'+id+'/documents','POST',payload)).status,409);
 assert.equal((await request('/'+id+'/documents','POST',{...payload,version:2})).body.error.code,'DUPLICATE_DOCUMENT');
 const unauthorized=await fetch(base+'/'+id+'/documents/'+fileId,{headers:{authorization:'Bearer '+users[1]}});assert.equal(unauthorized.status,404);
 const download=await fetch(base+'/'+id+'/documents/'+fileId,{headers:{authorization:'Bearer '+users[0]}});assert.equal(download.status,200);assert.equal(await download.text(),'Product evidence ລາວ');assert.equal(download.headers.get('cache-control'),'no-store');
 assert.equal((await request('/'+id+'/extract','POST',{})).body.error.code,'AI_NOT_CONFIGURED');
 const originalFetch=globalThis.fetch;
 const documentId=uploaded.body.data.document_id;
 const mockOutput={extraction:{schemaVersion:'lvsp.document-intake.v1',fields:[{key:'productName',status:'FOUND',value:'Product evidence',confidence:0.7,sources:[{documentId,page:1,location:null,quote:'Product evidence ລາວ'}]}]},classifications:[{documentId,documentType:'APPLICATION',confidence:0.8,reason:'Mocked test content'}]};
 globalThis.fetch=async(url,options)=>{
  if(String(url).startsWith('https://generativelanguage.googleapis.com/'))return new Response(JSON.stringify({responseId:'mock-only',candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(mockOutput)}]}}]}),{status:200});
  return originalFetch(url,options);
 };
 process.env.LVSP_AI_PROVIDER='gemini';process.env.LVSP_AI_MODEL='mock-gemini';process.env.GEMINI_API_KEY='test-only-placeholder';
 try{
  assert.equal((await request('/'+id+'/extract','POST',{version:2,provider:'openai',confirmProviderDisclosure:true})).status,409);
  assert.equal((await request('/'+id+'/extract','POST',{version:2,provider:'gemini'})).status,400);
  assert.equal((await request('/'+id+'/extract','POST',{version:2,provider:'gemini',confirmProviderDisclosure:true})).status,200);
  const extracted=(await request('/'+id)).body.data;assert.equal(extracted.ai_extraction.extraction.fields[0].value,'Product evidence');assert.equal(extracted.ai_extraction.provider,'gemini');assert.equal(extracted.aiProvider.label,'Google Gemini');assert.ok(extracted.ai_extracted_by);
 }finally{globalThis.fetch=originalFetch;delete process.env.OPENAI_API_KEY;delete process.env.GEMINI_API_KEY;process.env.LVSP_AI_PROVIDER='';}
 const review={version:3,confirmReviewed:true,fields:{productName:'Reviewed product'},note:'Evidence checked; not an approval'};
 const confirmed=await request('/'+id+'/review','POST',review);assert.equal(confirmed.status,200);assert.equal(confirmed.body.data.status,'REVIEWED');assert.ok(confirmed.body.data.reviewed_by);
 assert.equal((await request('/'+id+'/documents','POST',{...payload,version:4})).status,409);
 assert.equal((await request('/'+id+'/review','POST',{...review,version:4})).status,409);
 const complete=(await request('/'+id)).body.data;assert.equal(complete.officialRegistrationCreated,false);assert.equal(complete.documents.length,1);
 assert.equal((await client.query('select count(*)::int n from registration.veterinary_drug_application')).rows[0].n,0);
 assert.equal((await client.query('select count(*)::int n from audit.event where resource_id=$1',[id])).rows[0].n,5);
 assert.equal((await client.query('select count(*)::int n from integration.outbox_event where aggregate_id=$1',[id])).rows[0].n,4);
 await assert.rejects(client.query('delete from registration.document_intake_draft where id=$1',[id]));
 await assert.rejects(client.query('update registration.document_intake_draft set title=$2 where id=$1',[id,'Changed after review']));
 console.log('PASS: private upload/download, ownership, roles, UTF-8, duplicate/stale/locked checks, review, audit/outbox, mocked server AI extraction with disclosure consent, and no official registration writes');
}finally{
 if(server?.listening)await new Promise(resolve=>server.close(resolve));
 await store?.close?.();await client?.end();
 if(started)run('pg_ctl',['-D',data,'-m','fast','-w','stop']);
 console.log('Disposable cluster stopped; test artifacts:',directory);
}
