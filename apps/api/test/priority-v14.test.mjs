import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../..');
const migration=fs.readFileSync(path.join(root,'database/migrations/000810_legacy_registration_trade_parity.sql'),'utf8');
const api=fs.readFileSync(path.join(root,'apps/api/src/core/legacy-parity.ts'),'utf8');
const web=fs.readFileSync(path.join(root,'apps/web/src/legacy-parity.ts'),'utf8');
const app=fs.readFileSync(path.join(root,'apps/web/src/app.ts'),'utf8');
const server=fs.readFileSync(path.join(root,'apps/api/src/server.ts'),'utf8');

test('v1.4 one internal memo supports many registrations with presentation snapshots',()=>{
  assert.match(migration,/CREATE TABLE IF NOT EXISTS registration\.veterinary_drug_internal_memo\s*\(/);
  assert.match(migration,/CREATE TABLE IF NOT EXISTS registration\.veterinary_drug_internal_memo_item\s*\(/);
  assert.match(migration,/selected_presentations JSONB/);
  assert.match(migration,/uq_vet_drug_memo_item_active_profile/);
  assert.match(api,/Select at least one veterinary drug registration for the memo/);
  assert.match(api,/selectedPackageIds/);
  assert.match(web,/1 ຕົວຢາ = 1 ແຖວໃນໃບ/);
  assert.match(web,/openRegistrationBatchMemo/);
});

test('v1.4 preserves legacy trade coordination checklist and quality states',()=>{
  for(const code of ['IET_APPLICATION_FORM','ORIGIN_EXPORT_PERMIT','ANALYSIS_REPORT','INVOICE_PACKING_LIST','GMP_HACCP','HEALTH_QUALITY_CERT','PRODUCT_REGISTRATION','OTHER_DOCUMENTS']) assert.match(migration,new RegExp(code));
  assert.match(migration,/presence_status/);
  assert.match(migration,/quality_status/);
  assert.match(migration,/POLICY/);
  assert.match(web,/openTradeCoordinationSheet/);
  assert.match(web,/ຖືກຕ້ອງ/);
  assert.match(web,/ນະໂຍບາຍ/);
});

test('v1.4 shared report builder restores selectable columns filters periods and exports',()=>{
  assert.match(migration,/analytics\.v_veterinary_drug_registry_report/);
  assert.match(migration,/analytics\.v_veterinary_trade_permit_report/);
  assert.match(web,/Regulatory Report Builder/);
  assert.match(web,/This Month/);
  assert.match(web,/Last Month/);
  assert.match(web,/This Quarter/);
  assert.match(web,/This Year/);
  assert.match(web,/Print \/ PDF/);
  assert.match(web,/Word/);
  assert.match(web,/Excel/);
  assert.match(web,/CSV/);
});

test('v1.4 capabilities remain integrated after v1.5 workspace consolidation',()=>{
  assert.match(server,/handleLegacyParityApi/);
  assert.match(api,/INTERNAL_READ_ROLES/);
  assert.match(api,/INTERNAL_WRITE_ROLES/);
  assert.match(api,/FINALIZE_ROLES/);
  assert.doesNotMatch(app,/key:'registration_memos'/);
  assert.match(app,/key:'regulatory_reports'/);
  assert.match(app,/drug-memo-center-btn/);
  assert.match(app,/renderRegistrationMemoCenter/);
  assert.match(app,/openTradeCoordinationSheet\(id\)/);
  assert.doesNotMatch(app,/id="drug-report"/);
  assert.doesNotMatch(app,/id="trade-report"/);
  assert.doesNotMatch(migration,/^\s*DROP TABLE/im);
  assert.doesNotMatch(migration,/^\s*DELETE FROM\b/im);
});
