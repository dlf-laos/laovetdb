import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const api=fs.readFileSync(new URL('../src/core/vet-drug-operational.ts',import.meta.url),'utf8');
const server=fs.readFileSync(new URL('../src/server.ts',import.meta.url),'utf8');
const web=fs.readFileSync(new URL('../../web/src/app.ts',import.meta.url),'utf8');
const workspace=fs.readFileSync(new URL('../../web/src/vet-drug-operational.ts',import.meta.url),'utf8');
const migration=fs.readFileSync(new URL('../../../database/migrations/000800_vet_drug_registration_operational.sql',import.meta.url),'utf8');

test('v1.3 server exposes PostgreSQL veterinary drug operational API without replacing 000800',()=>{
  assert.match(server,/handleVetDrugOperationalApi/);
  assert.match(api,/\/api\/v1\/veterinary-drug-applications/);
  assert.match(api,/POSTGRES_REQUIRED/);
  assert.match(api,/registration\.transition_veterinary_drug_application/);
  assert.match(api,/APPLICATION_NOT_APPROVED/);
  assert.match(api,/integration\.outbox_event/);
  assert.match(api,/audit\.event/);
  assert.doesNotMatch(api,/delete\s+from\s+registration\.veterinary_drug/i);
});

test('v1.3 uses six-section staff workspace from existing drug registration detail',()=>{
  assert.match(web,/openVetDrugOperationalWorkspace/);
  assert.match(web,/drug-operational/);
  assert.match(workspace,/1\. ຄຳຮ້ອງ/);
  assert.match(workspace,/2\. ພາກສ່ວນ/);
  assert.match(workspace,/3\. ຂະໜາດ/);
  assert.match(workspace,/4\. ເອກະສານ/);
  assert.match(workspace,/5\. ກວດທົບ/);
  assert.match(workspace,/6\. ຕັດສິນ/);
  assert.match(workspace,/PENDING_LEGAL_VERIFICATION/);
});

test('v1.3 preserves core regulatory separation and command guard from 000800',()=>{
  assert.match(migration,/Product != Application\/Case != Registration != Package\/Presentation != Certificate/);
  assert.match(migration,/guard_veterinary_drug_status_update/);
  assert.match(migration,/transition_veterinary_drug_application/);
  assert.match(migration,/prevent_hard_delete/);
});
