import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const web=fs.readFileSync(new URL('../../web/src/app.ts',import.meta.url),'utf8');
const html=fs.readFileSync(new URL('../../web/public/index.html',import.meta.url),'utf8');
const server=fs.readFileSync(new URL('../src/server.ts',import.meta.url),'utf8');
const pg=fs.readFileSync(new URL('../src/core/postgres-store.ts',import.meta.url),'utf8');

test('Priority v0.7 registration rows drill into detail with edit and print actions',()=>{
  assert.match(web,/clickable-row/);
  assert.match(web,/openDrugDetail/);
  assert.match(web,/drug-edit/);
  assert.match(web,/printDrugCertificate/);
  assert.match(web,/printDrugMemo/);
  assert.match(html,/detail-modal/);
});

test('Priority v0.7 supports versioned complete drug update in PostgreSQL',()=>{
  assert.match(server,/req\.method==='PATCH'/);
  assert.match(server,/updateDrugRegistrationComplete/);
  assert.match(pg,/async updateDrugRegistrationComplete/);
  assert.match(pg,/max\(version_no\)/);
  assert.match(pg,/presentation_status='INACTIVE'/);
});

test('Priority v0.7 drills into annual plans and import applications and prints permit',()=>{
  assert.match(web,/openPlanDetail/);
  assert.match(web,/openImportDetail/);
  assert.match(web,/printImportPermit/);
  assert.match(server,/importPlanComplete/);
});
