import test from 'node:test';
import assert from 'node:assert/strict';
import {server,store} from '../dist/server.js';
let base;
test.before(async()=>{await store.reset();await new Promise(r=>server.listen(0,'127.0.0.1',r));base=`http://127.0.0.1:${server.address().port}`});
test.after(async()=>{await new Promise(r=>server.close(r));});
async function req(path,options={}){const r=await fetch(base+path,{headers:{'content-type':'application/json','x-lvsp-role':'SYSTEM_ADMIN'},...options});const b=await r.json();return {r,b};}
async function post(path,body={}){return req('/api/v1'+path,{method:'POST',body:JSON.stringify(body)});} 
async function get(path){return req('/api/v1'+path);}

test('Build 01 — auth, master data, workflow foundation',async()=>{
 const login=await post('/auth/login',{username:'admin',password:'lvsp-demo-change-me'});assert.equal(login.r.status,200);assert.ok(login.b.data.token);
 const company=await post('/companies',{legalNameLo:'ບໍລິສັດ Build 01',enterpriseNo:'B01-001',status:'ACTIVE'});assert.equal(company.r.status,201);
 const facility=await post('/facilities',{nameLo:'ສະຖານປະກອບການ Build 01',status:'ACTIVE'});assert.equal(facility.r.status,201);
 const workflow=await post('/workflows',{workflowCode:'WF-B01',nameLo:'ການທົດສອບ',isActive:true});assert.equal(workflow.r.status,201);
 const audit=await get('/audit-events');assert.ok(audit.b.data.length>=3);
});

test('Build 02 — case, application, decision, registration and licensing',async()=>{
 const app=await post('/applications',{caseNo:'APP-B02',applicationType:'NEW',status:'DRAFT'});assert.equal(app.r.status,201);
 const sub=await post(`/applications/${app.b.data.id}/submit`);assert.equal(sub.b.data.status,'SUBMITTED');
 const decision=await post('/decisions',{decisionNo:'DEC-B02',decisionType:'APPROVED',status:'ISSUED'});assert.equal(decision.r.status,201);
 const reg=await post('/registrations',{registrationNo:'REG-B02',status:'ACTIVE'});assert.equal(reg.r.status,201);
 const lic=await post('/licenses',{licenseNo:'LIC-B02',status:'ACTIVE'});assert.equal(lic.r.status,201);
 const cert=await post('/certificates',{certificateNo:'CERT-B02',status:'VALID'});assert.ok(cert.b.data.verificationToken);
});

test('Build 03 — facility/factory, product, package and feed',async()=>{
 const f=await post('/facilities',{nameLo:'Factory B03',status:'PROPOSED'});
 const est=await post(`/facilities/${f.b.data.id}/establishment-applications`,{establishmentType:'VETERINARY_MEDICINE',status:'UNDER_REVIEW'});assert.equal(est.r.status,201);
 const line=await post(`/facilities/${f.b.data.id}/production-lines`,{lineType:'INJECTION',status:'ACTIVE'});assert.equal(line.r.status,201);
 const p=await post('/products',{tradeName:'LVSP TEST PRODUCT',lifecycleStatus:'DRAFT'});
 const v=await post(`/products/${p.b.data.id}/versions`,{versionNo:1,status:'DRAFT'});assert.equal(v.r.status,201);
 const pack=await post(`/products/${p.b.data.id}/packages`,{packageCode:'100ML',status:'ACTIVE'});assert.equal(pack.r.status,201);
 const feed=await post('/feed',{productId:p.b.data.id,feedCategory:'TEST'});
 const formula=await post(`/feed/${feed.b.data.id}/formulas`,{formulaCode:'F-B03',status:'ACTIVE'});assert.equal(formula.r.status,201);
});

test('Build 04 — inspection, compliance, enforcement and LIMS',async()=>{
 const i=await post('/inspections',{inspectionNo:'IN-B04',status:'IN_PROGRESS',triggerType:'ROUTINE'});
 const visit=await post(`/inspections/${i.b.data.id}/visits`,{visitNo:1,status:'SCHEDULED'});assert.equal(visit.r.status,201);
 const finding=await post(`/inspections/${i.b.data.id}/findings`,{findingNo:1,observation:'Test finding',status:'OPEN'});assert.equal(finding.r.status,201);
 const capa=await post('/capa',{findingId:finding.b.data.id,status:'REQUESTED'});const submitted=await post(`/capa/${capa.b.data.id}/submit`);assert.equal(submitted.b.data.status,'SUBMITTED');
 const sample=await post('/laboratory/samples',{sampleNo:'S-B04',sampleType:'SERUM',sampleStatus:'COLLECTED'});assert.equal(sample.r.status,201);
 const result=await post('/laboratory/results',{status:'DRAFT'});let x=await post(`/laboratory/results/${result.b.data.id}/validate`);assert.equal(x.b.data.status,'VALIDATED');x=await post(`/laboratory/results/${result.b.data.id}/approve`);assert.equal(x.b.data.status,'APPROVED');
});

test('Build 05 — farm, animal and movement traceability',async()=>{
 const farm=await post('/farms',{farmCode:'FARM-B05',status:'ACTIVE'});assert.equal(farm.r.status,201);
 const animal=await post('/animals',{animalNo:'A-B05',lifecycleStatus:'ACTIVE'});assert.equal(animal.r.status,201);
 const move=await post('/movements',{movementNo:'MOV-B05',status:'DRAFT'});let x=await post(`/movements/${move.b.data.id}/authorize`);assert.equal(x.b.data.status,'AUTHORIZED');x=await post(`/movements/${move.b.data.id}/depart`);assert.equal(x.b.data.status,'IN_TRANSIT');x=await post(`/movements/${move.b.data.id}/arrive`);assert.equal(x.b.data.status,'ARRIVED');x=await post(`/movements/${move.b.data.id}/complete`);assert.equal(x.b.data.status,'COMPLETED');
});

test('Build 06 — surveillance, disease, outbreak and vaccination',async()=>{
 const d=await post('/diseases',{diseaseCode:'D-B06',nameLo:'ພະຍາດທົດສອບ'});assert.equal(d.r.status,201);
 const c=await post('/disease-cases',{caseNo:'DC-B06',status:'OPEN'});const confirmed=await post(`/disease-cases/${c.b.data.id}/confirm`);assert.equal(confirmed.b.data.status,'CONFIRMED');
 const o=await post('/outbreaks',{outbreakNo:'OB-B06',status:'ACTIVE'});const zone=await post(`/outbreaks/${o.b.data.id}/zones`,{zoneType:'CONTROL',status:'ACTIVE'});assert.equal(zone.r.status,201);
 const vac=await post('/vaccination-campaigns',{campaignNo:'VC-B06',nameLo:'Campaign',status:'PLANNED'});assert.equal(vac.r.status,201);
});

test('Build 07 — trade, border and fisheries',async()=>{
 const op=await post('/trade/operators',{operatorNo:'OP-B07',operatorStatus:'ACTIVE'});assert.equal(op.r.status,201);
 const shipment=await post('/trade/shipments',{shipmentNo:'SH-B07',status:'DRAFT'});let x=await post(`/trade/shipments/${shipment.b.data.id}/declare`);assert.equal(x.b.data.status,'DECLARED');x=await post(`/trade/shipments/${shipment.b.data.id}/risk-assess`,{riskBand:'LOW'});assert.equal(x.b.data.status,'RISK_ASSESSED');x=await post(`/trade/shipments/${shipment.b.data.id}/clearance`);assert.equal(x.b.data.status,'CLEARED');
 const aq=await post('/aquaculture/stock-batches',{batchNo:'AQ-B07',status:'ACTIVE'});const production=await post(`/aquaculture/stock-batches/${aq.b.data.id}/production`,{estimatedQuantity:100});assert.equal(production.r.status,201);
});

test('Build 08 — GIS, analytics/integration and platform hardening',async()=>{
 const layer=await post('/gis/layers',{layerCode:'FACILITY',nameLo:'Facilities',status:'ACTIVE'});assert.equal(layer.r.status,201);
 const integration=await post('/integrations',{systemCode:'TEST-G2G',name:'Test Government API',status:'ACTIVE'});assert.equal(integration.r.status,201);
 const report=await post('/reports',{dashboardCode:'EXEC',nameLo:'Executive Dashboard',status:'ACTIVE'});assert.equal(report.r.status,201);
 const meta=await get('/meta');assert.equal(meta.r.status,200);assert.ok(meta.b.data.counts);
 const outbox=await get('/outbox-events');assert.ok(outbox.b.data.length>=20);
});
