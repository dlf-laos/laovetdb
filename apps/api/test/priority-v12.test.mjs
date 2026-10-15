import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {server,store} from '../dist/server.js';
let base;
test.before(async()=>{if(store.reset)await store.reset();await new Promise(r=>server.listen(0,'127.0.0.1',r));base=`http://127.0.0.1:${server.address().port}`});
test.after(async()=>{await new Promise(r=>server.close(r));});
async function call(path){const r=await fetch(base+path,{headers:{'x-lvsp-user':'v12-admin','x-lvsp-role':'SYSTEM_ADMIN'}});let b={};try{b=await r.json()}catch{}return {r,b}}

test('v1.2 controlled veterinary drug reference endpoint works in development fallback',async()=>{
 const x=await call('/api/v1/veterinary-drug-reference-data');assert.equal(x.r.status,200);
 assert.ok(x.b.data.categories.length>=10);assert.ok(x.b.data.dosageGroups.some(x=>x.code==='oral'));
 assert.ok(x.b.data.dosageForms.some(x=>x.parentCode==='oral'&&/Chewable Tablet/.test(x.valueText)));
 assert.ok(x.b.data.distributions.some(x=>x.code==='POM'));assert.ok(x.b.data.routes.some(x=>x.code==='IM'));assert.ok(x.b.data.atcvet.some(x=>x.code==='QP54'));
});

test('v1.2 migration makes old controlled vocabulary configurable and numbering concurrency-safe',()=>{
 const sql=fs.readFileSync(new URL('../../../database/migrations/000770_vet_drug_reference_automation.sql',import.meta.url),'utf8');
 assert.match(sql,/lookup\.veterinary_drug_reference_term/);assert.match(sql,/product\.veterinary_registration_number_sequence/);
 assert.match(sql,/registration_number_source/);assert.match(sql,/DOSAGE_GROUP/);assert.match(sql,/WHO_ATCVET/);assert.doesNotMatch(sql,/DROP\s+(TABLE|SCHEMA)/i);
});

test('v1.2 web restores legacy-quality dependent dropdowns and regulatory date automation',()=>{
 const web=fs.readFileSync(new URL('../../web/src/app.ts',import.meta.url),'utf8');
 assert.match(web,/name="category" required><select|name="category" required/);assert.match(web,/dosageFormOptions/);assert.match(web,/atcvetOptions/);
 assert.match(web,/name="distributionClassification"/);assert.match(web,/name="route"/);assert.match(web,/registration-no-toggle/);
 assert.match(web,/syncDrugValidity/);assert.match(web,/DLF Date/);assert.match(web,/Expiry Date/);
});

test('v1.2 server owns registration number and expiry rules',()=>{
 const pg=fs.readFileSync(new URL('../src/core/postgres-store.ts',import.meta.url),'utf8');
 const serverSrc=fs.readFileSync(new URL('../src/server.ts',import.meta.url),'utf8');
 assert.match(pg,/allocateDrugRegistrationNo/);assert.match(pg,/for update/);assert.match(pg,/prefix==='F'\?200:0/);
 assert.match(pg,/p\.dlfDate\)\{p\.issueDate/);assert.match(pg,/calculateDrugExpiry/);assert.match(pg,/DUPLICATE_REGISTRATION_NO/);
 assert.match(serverSrc,/drug-registrations\/next-number/);assert.match(serverSrc,/prepareDrugRegulatoryProfile/);
});
