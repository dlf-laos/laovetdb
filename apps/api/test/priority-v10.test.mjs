import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {server,store} from '../dist/server.js';
let base;
test.before(async()=>{if(store.reset)await store.reset();await new Promise(r=>server.listen(0,'127.0.0.1',r));base=`http://127.0.0.1:${server.address().port}`});
test.after(async()=>{await new Promise(r=>server.close(r));});
async function call(path,options={}){const headers={'content-type':'application/json','x-lvsp-user':'v10-admin','x-lvsp-role':'SYSTEM_ADMIN',...(options.headers||{})};const r=await fetch(base+path,{...options,headers});let b={};try{b=await r.json()}catch{}return {r,b}}

test('v1.0 serves installable staff PWA and field PWA shells',async()=>{
  let r=await fetch(base+'/manifest.webmanifest');assert.equal(r.status,200);let m=await r.json();assert.equal(m.short_name,'LVSP');assert.equal(m.display,'standalone');
  r=await fetch(base+'/sw.js');assert.equal(r.status,200);const sw=await r.text();assert.match(sw,/const CACHE='lvsp-shell-(?:v1\.[^']+|release-\d{8})';/);
  r=await fetch(base+'/field/');assert.equal(r.status,200);const html=await r.text();assert.match(html,/LVSP Field/);assert.match(html,/manifest\.webmanifest/);
  r=await fetch(base+'/field/sw.js');assert.equal(r.status,200);
});

test('v1.0 central admin overview and field offline sync are executable',async()=>{
  const a=await call('/api/v1/admin/overview');assert.equal(a.r.status,200);assert.ok(a.b.data.counts);assert.ok(a.b.data.releaseVersion);
  const f=await call('/api/v1/field-captures/sync',{method:'POST',body:JSON.stringify({items:[{localCaptureId:'offline-1',captureType:'INSPECTION_NOTE',facility:'Demo Facility',finding:'Demo note',latitude:17.9,longitude:102.6,capturedAt:new Date().toISOString()}]})});assert.equal(f.r.status,201);assert.equal(f.b.data.count,1);
  const q=await call('/api/v1/admin/field-captures');assert.equal(q.r.status,200);assert.ok(q.b.data.some(x=>x.localCaptureId==='offline-1'));
});

test('v1.0 source includes non-secret settings, staging field capture and admin/PWA UX',()=>{
  const migration=fs.readFileSync(new URL('../../../database/migrations/000750_pwa_admin_field_foundation.sql',import.meta.url),'utf8');
  const web=fs.readFileSync(new URL('../../web/src/app.ts',import.meta.url),'utf8');
  const field=fs.readFileSync(new URL('../../field/src/app.ts',import.meta.url),'utf8');
  const serverSrc=fs.readFileSync(new URL('../src/server.ts',import.meta.url),'utf8');
  assert.match(migration,/system\.platform_setting/);assert.match(migration,/is_secret BOOLEAN/);assert.match(migration,/inspection\.field_capture_draft/);
  assert.match(web,/admin_center/);assert.match(web,/initPwa/);assert.match(web,/renderAdminCenter/);assert.match(web,/Install Staff App/);
  assert.match(field,/field-captures\/sync/);assert.match(field,/serviceWorker/);
  assert.match(serverSrc,/admin\/overview/);assert.match(serverSrc,/field-captures\/sync/);assert.match(serverSrc,/fieldRoot/);
});
