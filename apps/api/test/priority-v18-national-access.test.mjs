import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=p=>fs.readFileSync(new URL(`../../../${p}`,import.meta.url),'utf8');
const migration=read('database/migrations/000830_national_access_foundation.sql');
const store=read('apps/api/src/core/postgres-store.ts');
const server=read('apps/api/src/server.ts');
const web=read('apps/web/src/app.ts');
const security=read('apps/api/src/core/security.ts');

test('v1.8 adds a public module roadmap with active, development and planned states',()=>{
  assert.match(migration,/CREATE TABLE IF NOT EXISTS system\.module_catalog/);
  assert.match(migration,/IN_DEVELOPMENT/);
  assert.match(migration,/ESTABLISHMENT_LICENSING/);
  assert.match(server,/public\/module-catalog/);
  assert.match(web,/Modules ຂອງ LVSP|Services & Modules/);
});

test('v1.8 extends access scopes to organization, geography and checkpoint facility',()=>{
  assert.match(migration,/ADD COLUMN IF NOT EXISTS scope_type/);
  assert.match(migration,/ADD COLUMN IF NOT EXISTS facility_id/);
  assert.match(migration,/PROVINCE/);
  assert.match(migration,/DISTRICT/);
  assert.match(migration,/CHECKPOINT/);
  assert.match(migration,/v_user_access_matrix/);
});

test('v1.8 supports named provincial district and checkpoint roles',()=>{
  for(const role of ['PROVINCIAL_ADMIN','PROVINCIAL_LICENSING_OFFICER','DISTRICT_LICENSING_OFFICER','DISTRICT_INSPECTOR','CHECKPOINT_SUPERVISOR']) assert.match(migration,new RegExp(role));
  assert.match(security,/CHECKPOINT_SUPERVISOR/);
});

test('v1.8 keeps legal issuing delegation as controlled DRAFT metadata, not hard-coded authority',()=>{
  assert.match(migration,/license_authority_rule/);
  assert.match(migration,/policy_status.*DRAFT/s);
  assert.match(migration,/DRAFT rows are not legal authority/);
  assert.match(web,/not hard-coded|ບໍ່ຖືກ hard-code/);
});

test('v1.8 exposes admin APIs for organizations scopes and scoped assignments',()=>{
  assert.match(server,/admin\/access-foundation/);
  assert.match(server,/admin\/organizations/);
  assert.match(server,/admin\/access-scopes/);
  assert.match(server,/users\\\/\(\[\^\/\]\+\)\\\/assignments|users\/\(\[\^\/\]\+\)\/assignments/);
  assert.match(store,/createAdminAccessScope/);
  assert.match(store,/addAdminUserAssignment/);
});

test('v1.8 staff user administration creates temporary-password accounts from the UI',()=>{
  assert.match(web,/Create staff account|ສ້າງ Account ພະນັກງານ/);
  assert.match(web,/mustChangePassword:true/);
  assert.match(web,/National Access/);
});
