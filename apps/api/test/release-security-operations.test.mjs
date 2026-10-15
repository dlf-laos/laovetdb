import test from 'node:test';
import assert from 'node:assert/strict';
import {server,store} from '../dist/server.js';
import {issueToken} from '../dist/core/auth.js';
let base;
const token=(id,roles,extra={})=>issueToken(id,roles,3600,extra);
const owner=token('owner',['SYSTEM_ADMIN']);
const reviewer=token('reviewer',['TECHNICAL_REVIEWER']);
async function req(path,method='GET',body,credential=owner){
 const r=await fetch(base+'/api/v1'+path,{method,headers:{'content-type':'application/json',...(credential?{authorization:'Bearer '+credential}:{})},body:body===undefined?undefined:JSON.stringify(body)});
 return {status:r.status,body:await r.json()};
}
test.before(async()=>{process.env.AUTH_MODE='local';await store.reset();await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});base='http://127.0.0.1:'+server.address().port;});
test.after(async()=>{await new Promise(resolve=>server.close(resolve));});
test('manual endpoints require authentication and enforce write roles',async()=>{
 assert.equal((await req('/export-applications','POST',{},null)).status,401);
 assert.equal((await req('/export-applications','POST',{},token('manager',['MANAGEMENT_VIEWER']))).status,403);
 assert.equal((await req('/species','GET',undefined,token('changed',['SYSTEM_ADMIN'],{mustChangePassword:true}))).status,403);
 assert.equal((await req('/public/overview','GET',undefined,null)).status,200);
 assert.equal((await req('/public/search','POST',{},null)).status,401);
});
test('budget lifecycle requires a separate reviewer, rejects stale edits, and locks verified records',async()=>{
 const input={reportMonth:'2026-10',title:'Budget line',plannedAmount:1000000,actualAmount:600000,notes:'Reference'};
 const created=await req('/department-operations/budget','POST',input);assert.equal(created.status,201);
 const row=created.body.data;assert.equal(row.status,'DRAFT');
 assert.equal((await req('/department-operations/budget/'+row.id,'PATCH',{...input,version:99})).status,409);
 const submitted=await req('/department-operations/budget/'+row.id+'/submit','POST',{version:1,status:'VERIFIED'});assert.equal(submitted.body.data.status,'SUBMITTED');
 assert.equal((await req('/department-operations/budget/'+row.id+'/verify','POST',{version:2})).status,403);
 const verified=await req('/department-operations/budget/'+row.id+'/verify','POST',{version:2},reviewer);assert.equal(verified.status,200);assert.equal(verified.body.data.status,'VERIFIED');
 assert.equal((await req('/department-operations/budget/'+row.id,'PATCH',{...input,version:3})).status,409);
 const listed=await req('/department-operations/budget?month=2026-10');assert.equal(listed.body.data.length,1);
 assert.equal(listed.body.data[0].actualAmount,600000);
 assert.ok((await store.auditEvents()).some(x=>x.actionCode==='department.budget.verify'));
 assert.ok((await store.outboxEvents()).some(x=>x.eventType==='department.budget.verify.v1'));
});
test('monthly work supports return and correction and rejects invalid month and amounts',async()=>{
 assert.equal((await req('/department-operations/budget','POST',{reportMonth:'2026-10',title:'bad',plannedAmount:-1,actualAmount:0})).status,400);
 assert.equal((await req('/department-operations/work','POST',{reportMonth:'2026-13',title:'bad'})).status,400);
 const created=await req('/department-operations/work','POST',{reportMonth:'2026-10',title:'Monthly work',plannedResult:'Plan',actualResult:'Result'});const id=created.body.data.id;
 await req('/department-operations/work/'+id+'/submit','POST',{version:1});
 const returned=await req('/department-operations/work/'+id+'/return','POST',{version:2},reviewer);assert.equal(returned.body.data.status,'RETURNED');
 const edited=await req('/department-operations/work/'+id,'PATCH',{version:3,reportMonth:'2026-10',title:'Corrected',actualResult:'Updated'});assert.equal(edited.status,200);assert.equal(edited.body.data.version,4);
});
test('regulatory command bodies cannot override the state selected by the command',async()=>{
 const created=await req('/applications','POST',{caseNo:'RELEASE-SECURITY',status:'DRAFT'});
 const submitted=await req('/applications/'+created.body.data.id+'/submit','POST',{status:'APPROVED',lastAction:'approve'});
 assert.equal(submitted.status,200);assert.equal(submitted.body.data.status,'SUBMITTED');assert.equal(submitted.body.data.lastAction,'submit');
});
