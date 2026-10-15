import test from 'node:test';
import assert from 'node:assert/strict';
import {server,store} from '../dist/server.js';

let base;
test.before(async()=>{await store.reset();await new Promise(r=>server.listen(0,'127.0.0.1',r));base=`http://127.0.0.1:${server.address().port}`});
test.after(async()=>{await new Promise(r=>server.close(r));});

async function req(path,options={}){const r=await fetch(base+path,{headers:{'content-type':'application/json','x-lvsp-role':'SYSTEM_ADMIN'},...options});let b=await r.json();return {r,b};}

test('health and readiness',async()=>{let x=await req('/health');assert.equal(x.r.status,200);assert.equal(x.b.status,'ok');x=await req('/ready');assert.equal(x.r.status,200)});

test('create and list company',async()=>{const c=await req('/api/v1/companies',{method:'POST',body:JSON.stringify({legalNameLo:'ບໍລິສັດ ທົດສອບ',enterpriseNo:'ENT-001',status:'ACTIVE'})});assert.equal(c.r.status,201);assert.ok(c.b.data.id);const l=await req('/api/v1/companies');assert.equal(l.r.status,200);assert.equal(l.b.meta.total,1)});

test('application command transition writes audit and outbox',async()=>{const c=await req('/api/v1/applications',{method:'POST',body:JSON.stringify({caseNo:'APP-001',status:'DRAFT'})});const id=c.b.data.id;const s=await req(`/api/v1/applications/${id}/submit`,{method:'POST',body:'{}'});assert.equal(s.r.status,200);assert.equal(s.b.data.status,'SUBMITTED');const a=await req('/api/v1/audit-events');const o=await req('/api/v1/outbox-events');assert.ok(a.b.data.length>=2);assert.ok(o.b.data.length>=2)});

test('certificate public verification',async()=>{const c=await req('/api/v1/certificates',{method:'POST',body:JSON.stringify({certificateNo:'CERT-001',status:'VALID'})});const token=c.b.data.verificationToken;const v=await req(`/api/v1/certificates/verify/${token}`);assert.equal(v.r.status,200);assert.equal(v.b.data.valid,true)});

test('OpenAPI command path recognized',async()=>{const c=await req('/api/v1/movements',{method:'POST',body:JSON.stringify({movementNo:'MOV-1',status:'DRAFT'})});const x=await req(`/api/v1/movements/${c.b.data.id}/authorize`,{method:'POST',body:'{}'});assert.equal(x.r.status,200);assert.equal(x.b.data.status,'AUTHORIZED')});
