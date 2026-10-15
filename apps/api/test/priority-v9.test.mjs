import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {server,store} from '../dist/server.js';

let base;
test.before(async()=>{if(store.reset)await store.reset();await new Promise(r=>server.listen(0,'127.0.0.1',r));base=`http://127.0.0.1:${server.address().port}`});
test.after(async()=>{await new Promise(r=>server.close(r));});
async function call(path,options={}){const headers={'content-type':'application/json','x-lvsp-user':'v9-test-user','x-lvsp-role':'SYSTEM_ADMIN',...(options.headers||{})};const r=await fetch(base+path,{...options,headers});let b={};try{b=await r.json()}catch{}return {r,b}}

test('v0.9 public guided service catalog works without applicant workflow entry',async()=>{
  const x=await fetch(base+'/api/v1/public/service-catalog');assert.equal(x.status,200);const b=await x.json();assert.ok(b.data.length>=3);assert.ok(b.data.some(x=>x.serviceCode==='VM-1003'));assert.ok(b.data.some(x=>x.serviceCode==='TR-1007'));
  const g=await fetch(base+'/api/v1/public/services/TR-1007');assert.equal(g.status,200);const gb=await g.json();assert.ok(gb.data.steps.length>=6);assert.ok(gb.data.requirements.some(x=>x.requirementCode==='ITEM_LIST'));
});

test('v0.9 guided draft progresses and appears in My Work',async()=>{
  const c=await call('/api/v1/service-drafts',{method:'POST',body:JSON.stringify({serviceCode:'TR-1007'})});assert.equal(c.r.status,201);const id=c.b.data.draft.id;assert.ok(id);const first=c.b.data.steps[0];
  const s=await call(`/api/v1/service-drafts/${id}`,{method:'PATCH',body:JSON.stringify({stepCode:first.stepCode,completed:true,payload:{note:'ready'}})});assert.equal(s.r.status,200);assert.equal(s.b.data.steps[0].status,'COMPLETED');
  const w=await call('/api/v1/my-work');assert.equal(w.r.status,200);assert.ok(Array.isArray(w.b.data.domainQueues));
  const d=await call('/api/v1/service-drafts');assert.equal(d.r.status,200);assert.ok(d.b.data.some(x=>x.id===id));
});

test('v0.9 source implements configurable guided UX, work queue and domain linking',()=>{
  const migration=fs.readFileSync(new URL('../../../database/migrations/000740_guided_services_workflow.sql',import.meta.url),'utf8');
  const web=fs.readFileSync(new URL('../../web/src/app.ts',import.meta.url),'utf8');
  const serverSrc=fs.readFileSync(new URL('../src/server.ts',import.meta.url),'utf8');
  assert.match(migration,/system\.service_guide/);assert.match(migration,/system\.service_step/);assert.match(migration,/casework\.service_draft/);
  assert.match(migration,/TR-1007/);assert.match(migration,/mixed items/i);assert.match(migration,/bulk_excel/);
  assert.match(web,/guided_services/);assert.match(web,/renderServiceDraft/);assert.match(web,/renderMyWork/);assert.match(web,/browse-services-btn/);assert.match(web,/activeServiceDraftId/);
  assert.match(serverSrc,/public\/service-catalog/);assert.match(serverSrc,/service-drafts/);assert.match(serverSrc,/my-work/);
});
