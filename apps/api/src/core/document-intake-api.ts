// @ts-nocheck
import crypto from 'node:crypto';
import {putIntakeDocument,readIntakeDocument} from './document-intake-storage.js';
import {sendJson} from './http.js';
import {getIntakeAIProvider,extractIntakeDocuments} from './document-intake-provider.js';
import {intakeFields,documentTypes} from './document-intake.js';
const roles=['SYSTEM_ADMIN','SECURITY_ADMIN','REGISTRY_OFFICER','TECHNICAL_REVIEWER','APPROVING_AUTHORITY'];
const fail=(code,message,statusCode=400)=>{throw Object.assign(new Error(message),{code,statusCode});};
const uuid=value=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
async function body(req){
 const limit=3*1024*1024;
 if(Number(req.headers['content-length'])>limit)fail('PAYLOAD_TOO_LARGE','Maximum request size is 3 MiB',413);
 let size=0;const chunks=[];
 for await(const chunk of req){size+=chunk.length;if(size>limit)fail('PAYLOAD_TOO_LARGE','Maximum request size is 3 MiB',413);chunks.push(chunk);}
 try{return JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{fail('INVALID_JSON','Invalid JSON');}
}
export function validateIntakeUpload(input){
 if(!input||typeof input!=='object'||typeof input.filename!=='string'||input.filename.length>180||!input.filename.trim()||/[\x00-\x1f/\\]/.test(input.filename))fail('INVALID_FILE','Invalid filename');
 const allowed={'application/pdf':'pdf','image/png':'png','image/jpeg':'jpeg','text/plain':'txt'};
 if(!allowed[input.mimeType])fail('UNSUPPORTED_FILE','Pilot accepts PDF, PNG, JPEG and UTF-8 text only',415);
 if(typeof input.base64!=='string'||input.base64.length>2796204||!/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(input.base64))fail('INVALID_FILE','Invalid file encoding');
 const bytes=Buffer.from(input.base64,'base64');
 if(!bytes.length||bytes.length>2097152)fail('FILE_TOO_LARGE','Each pilot document must be between 1 byte and 2 MiB',413);
 const hex=bytes.subarray(0,8).toString('hex');
 if(input.mimeType==='application/pdf'&&bytes.subarray(0,5).toString()!=='%PDF-')fail('INVALID_FILE','PDF signature mismatch');
 if(input.mimeType==='image/png'&&hex!=='89504e470d0a1a0a')fail('INVALID_FILE','PNG signature mismatch');
 if(input.mimeType==='image/jpeg'&&!hex.startsWith('ffd8ff'))fail('INVALID_FILE','JPEG signature mismatch');
 if(input.mimeType==='text/plain'&&(bytes.includes(0)||Buffer.from(bytes.toString('utf8'),'utf8').compare(bytes)!==0))fail('INVALID_FILE','Text must be valid UTF-8');
 if(!documentTypes.includes(input.documentType))fail('INVALID_DOCUMENT_TYPE','Choose a document type; AI classification is not configured');
 return {bytes,filename:input.filename.trim(),mimeType:input.mimeType,documentType:input.documentType,sha256:crypto.createHash('sha256').update(bytes).digest('hex')};
}
export async function handleDocumentIntakeApi({req,res,url,store,ids,principal}){
 if(!url.pathname.startsWith('/api/v1/document-intake'))return false;
 if(!principal.isAuthenticated)fail('UNAUTHENTICATED','Sign in required',401);
 if(!principal.roles.some(role=>roles.includes(role)))fail('FORBIDDEN','Registration staff role required',403);
 if(store.mode!=='postgres')fail('POSTGRES_REQUIRED','Document intake requires the configured PostgreSQL backend',503);
 const route=url.pathname.match(/^\/api\/v1\/document-intake(?:\/([^/]+)(?:\/(documents|review|extract)(?:\/([^/]+))?)?)?$/);
 if(!route)fail('NOT_FOUND','Intake route not found',404);
 const [,id,action,fileId]=route;
 if(id&&!uuid(id)||fileId&&!uuid(fileId))fail('NOT_FOUND','Draft or document not found',404);
 const client=await store.pool.connect();
 try{
  await client.query('begin');
  const admin=principal.roles.some(role=>['SYSTEM_ADMIN','SECURITY_ADMIN'].includes(role));
  let draft;
  if(id){
   draft=(await client.query('select * from registration.document_intake_draft where id=$1 and (owner_id=$2 or $3) for update',[id,principal.userId,admin])).rows[0];
   if(!draft)fail('NOT_FOUND','Draft not found',404);
  }
  let data,status=200,auditAction;
  if(!id&&req.method==='GET'){
   data=(await client.query('select id,title,status,version,updated_at from registration.document_intake_draft where owner_id=$1 or $2 order by updated_at desc limit 100',[principal.userId,admin])).rows;
  }else if(!id&&req.method==='POST'){
   const input=await body(req);const title=typeof input?.title==='string'?input.title.trim():'';
   if(!title||title.length>300)fail('INVALID_TITLE','Title required, maximum 300 characters');
   draft=(await client.query('insert into registration.document_intake_draft(title,owner_id) values($1,$2) returning *',[title,principal.userId])).rows[0];data=draft;status=201;auditAction='create';
  }else if(id&&!action&&req.method==='GET'){
   const documents=(await client.query(`select a.id,a.document_id,d.document_type,f.original_filename,f.mime_type,f.size_bytes,f.sha256_checksum from document.intake_attachment a join document.document d on d.id=a.document_id join document.file f on f.id=a.file_id where a.draft_id=$1 order by f.uploaded_at`,[id])).rows;
   data={...draft,documents,aiProvider:getIntakeAIProvider(),aiStatus:getIntakeAIProvider().configured?'CONFIGURED':'NOT_CONFIGURED',officialRegistrationCreated:false};
  }else if(action==='documents'&&fileId&&req.method==='GET'){
   const attachment=(await client.query(`select f.original_filename,f.mime_type,f.storage_provider,f.object_key,f.size_bytes,f.sha256_checksum from document.intake_attachment a join document.file f on f.id=a.file_id where a.id=$1 and a.draft_id=$2`,[fileId,id])).rows[0];
   if(!attachment)fail('NOT_FOUND','Document not found',404);
   const downloaded=await readIntakeDocument(attachment);
   await client.query('insert into audit.event(actor_user_id,action_code,resource_type,resource_id,metadata) values($1,$2,$3,$4,$5)',[principal.userId,'intake.document.download','document_intake',id,JSON.stringify({attachmentId:fileId})]);
   await client.query('commit');
   res.writeHead(200,{'content-type':attachment.mime_type,'content-length':downloaded.length,'content-disposition':`attachment; filename="document"; filename*=UTF-8''${encodeURIComponent(attachment.original_filename)}`,'cache-control':'no-store','x-content-type-options':'nosniff','content-security-policy':"sandbox; default-src 'none'"});res.end(downloaded);return true;
  }else if(action==='extract'&&req.method==='POST'){
   if(!getIntakeAIProvider().configured)fail('AI_NOT_CONFIGURED','No extraction provider is configured. Documents remain private; nothing was sent to an AI service.',503);
   const input=await body(req);
   if(draft.status!=='DRAFT')fail('LOCKED_DRAFT','Reviewed intake is locked',409);
   if(input?.version!==draft.version)fail('STALE_VERSION','Reload this draft before extraction',409);
   const provider=getIntakeAIProvider();
   if(input.provider!==provider.id)fail('AI_PROVIDER_CHANGED','Reload the dossier and confirm the current AI provider',409);
   if(input.confirmProviderDisclosure!==true)fail('DISCLOSURE_CONFIRMATION_REQUIRED','Confirm sending these dossier documents to '+provider.label+' for extraction');
   const documents=(await client.query('select a.document_id,f.mime_type,f.storage_provider,f.object_key,f.size_bytes,f.sha256_checksum from document.intake_attachment a join document.file f on f.id=a.file_id where a.draft_id=$1 order by a.id',[id])).rows;
   if(!documents.length)fail('DOCUMENT_REQUIRED','Attach documents first');
   if(documents.length>8||documents.reduce((n,d)=>n+Number(d.size_bytes),0)>8388608)fail('AI_DOCUMENT_LIMIT','Pilot AI accepts up to 8 documents / 8 MiB per dossier',413);
   await client.query('commit');
   await Promise.all(documents.map(async document=>{document.payload=await readIntakeDocument(document);}));
   let extracted;
   try{extracted=await extractIntakeDocuments(documents);}catch(error){
    await client.query('insert into audit.event(actor_user_id,action_code,resource_type,resource_id,metadata) values($1,$2,$3,$4,$5)',[principal.userId,'intake.ai.failed','document_intake',id,JSON.stringify({code:error.code||'AI_FAILED',provider:getIntakeAIProvider().id,model:process.env.LVSP_AI_MODEL})]);throw error;
   }
   await client.query('begin');
   const current=(await client.query('select version,status from registration.document_intake_draft where id=$1 for update',[id])).rows[0];
   if(current.version!==draft.version||current.status!=='DRAFT')fail('STALE_VERSION','Dossier changed during extraction. Reload and retry.',409);
   data=(await client.query('update registration.document_intake_draft set ai_extraction=$2,ai_extracted_by=$3,ai_extracted_at=now(),version=version+1,updated_at=now() where id=$1 returning id,version',[id,JSON.stringify(extracted),principal.userId])).rows[0];auditAction='ai.extract';
  }else if(action==='documents'&&!fileId&&req.method==='POST'){
   const input=await body(req);
   if(draft.status!=='DRAFT')fail('LOCKED_DRAFT','Reviewed intake is locked',409);
   if(input?.version!==draft.version)fail('STALE_VERSION','Reload this draft before uploading',409);
   const total=(await client.query('select count(*)::int n from document.intake_attachment where draft_id=$1',[id])).rows[0].n;
   if(total>=20)fail('DOCUMENT_LIMIT','Maximum 20 documents per pilot intake',409);
   const file=validateIntakeUpload(input);
   const duplicate=(await client.query('select 1 from document.intake_attachment a join document.file f on f.id=a.file_id where a.draft_id=$1 and f.sha256_checksum=$2',[id,file.sha256])).rowCount;
   if(duplicate)fail('DUPLICATE_DOCUMENT','This document is already attached',409);
   const object=await putIntakeDocument('lvsp/intake/'+id+'/'+crypto.randomUUID(),file.bytes);
   const documentId=(await client.query(`insert into document.document(document_type,title,business_entity_type,business_entity_id,created_by) values($1,$2,'DOCUMENT_INTAKE',$3,$4) returning id`,[file.documentType,file.filename,id,principal.userId])).rows[0].id;
   const fileRecord=(await client.query(`insert into document.file(document_id,storage_provider,object_key,original_filename,mime_type,size_bytes,sha256_checksum,uploaded_by) values($1,$8,$2,$3,$4,$5,$6,$7) returning id`,[documentId,object.key,file.filename,file.mimeType,file.bytes.length,file.sha256,principal.userId,object.provider])).rows[0];
   data=(await client.query('insert into document.intake_attachment(draft_id,document_id,file_id) values($1,$2,$3) returning id,document_id',[id,documentId,fileRecord.id])).rows[0];
   await client.query('update registration.document_intake_draft set version=version+1,updated_at=now() where id=$1',[id]);status=201;auditAction='document.upload';
  }else if(action==='review'&&req.method==='POST'){
   const input=await body(req);
   if(draft.status!=='DRAFT')fail('LOCKED_DRAFT','Reviewed intake is locked',409);
   if(input?.version!==draft.version)fail('STALE_VERSION','Reload this draft before confirming',409);
   if(!input.fields||typeof input.fields!=='object'||Array.isArray(input.fields))fail('INVALID_REVIEW','Review fields required');
   const fields={};
   for(const [key,value] of Object.entries(input.fields)){
    if(!intakeFields.includes(key)||typeof value!=='string'||value.length>10000)fail('INVALID_REVIEW','Unknown field or invalid value');
    fields[key]=value.trim();
   }
   if(input.confirmReviewed!==true)fail('REVIEW_REQUIRED','Confirm that you reviewed the source documents');
   const count=(await client.query('select count(*)::int n from document.intake_attachment where draft_id=$1',[id])).rows[0].n;
   if(!count)fail('DOCUMENT_REQUIRED','Attach source documents before review');
   if(typeof input.note!=='string'||input.note.length>10000)fail('INVALID_REVIEW','Review note is required, maximum 10000 characters');
   data=(await client.query(`update registration.document_intake_draft set reviewed_fields=$2,review_note=$3,status='REVIEWED',reviewed_by=$4,reviewed_at=now(),updated_at=now(),version=version+1 where id=$1 returning *`,[id,JSON.stringify(fields),input.note,principal.userId])).rows[0];auditAction='review.confirm';
  }else fail('METHOD_NOT_ALLOWED','Unsupported intake operation',405);
  if(auditAction){
   const draftId=draft.id;
   await client.query('insert into audit.event(actor_user_id,action_code,resource_type,resource_id,metadata,before_data,after_data) values($1,$2,$3,$4,$5,$6,$7)',[principal.userId,'intake.'+auditAction,'document_intake',draftId,JSON.stringify({version:draft.version,attachmentId:action==='documents'?data.id:undefined,officialRegistrationCreated:false}),auditAction==='review.confirm'?JSON.stringify({fields:draft.reviewed_fields,status:draft.status}):null,auditAction==='review.confirm'?JSON.stringify({fields:data.reviewed_fields,status:data.status}):auditAction==='ai.extract'?JSON.stringify({provider:getIntakeAIProvider().id,model:process.env.LVSP_AI_MODEL,version:data.version}):null]);
   await client.query(`insert into integration.outbox_event(event_type,aggregate_type,aggregate_id,schema_version,payload) values($1,'document_intake',$2,1,$3)`,['intake.'+auditAction+'.v1',draftId,JSON.stringify({draftId,action:auditAction})]);
  }
  await client.query('commit');sendJson(res,status,{data,meta:{requestId:ids.requestId}},ids);return true;
 }catch(error){await client.query('rollback');if(error.code==='42P01')fail('MIGRATION_REQUIRED','Document intake migration 000940 has not been installed',503);throw error;}finally{client.release();}
}
