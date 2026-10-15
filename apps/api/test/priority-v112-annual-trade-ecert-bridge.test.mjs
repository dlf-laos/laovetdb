import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=(p)=>fs.readFileSync(new URL(p,import.meta.url),'utf8');
const sql=read('../../../database/migrations/000860_annual_trade_plan_ecert_bridge.sql');
const server=read('../src/server.ts');
const app=read('../../web/src/app.ts');
const legacy=read('../../web/src/legacy-workspaces-v16.ts');
const legacyApi=read('../src/core/legacy-parity.ts');
const verify=read('../../web/public/verify.html');

test('v1.12 000860 extends the existing annual-plan engine without table replacement',()=>{
  assert.match(sql,/trade\.annual_plan_service_type/);
  assert.match(sql,/trade\.import_plan_profile/);
  assert.match(sql,/analytics\.v_annual_trade_plan_overview/);
  assert.match(sql,/FEED_PRODUCT/);
  assert.match(sql,/ANIMAL_PRODUCT/);
  assert.doesNotMatch(sql,/\bDROP\s+TABLE\b/i);
  assert.doesNotMatch(sql,/\bDELETE\s+FROM\b/i);
});

test('v1.12 bridges legacy certificates to 000850 instead of creating a third registry',()=>{
  assert.match(sql,/certification\.ecert_legacy_certificate_link/);
  assert.match(sql,/REFERENCES document\.certificate/);
  assert.match(sql,/REFERENCES certification\.ecert_document/);
  assert.match(sql,/certification\.ecert_profile/);
  assert.match(sql,/certification\.ecert_profile_attestation/);
});

test('v1.12 pet health certificate is export-only and legal conditions stay configurable',()=>{
  assert.match(sql,/PET_IMPORT_PERMIT/);
  assert.match(sql,/PET_EXPORT_PERMIT/);
  assert.match(sql,/PET_EXPORT_HEALTH_CERTIFICATE/);
  assert.doesNotMatch(sql,/PET_IMPORT_HEALTH_CERTIFICATE/);
  assert.match(sql,/configuration_status[\s\S]*?DRAFT/i);
  assert.match(sql,/not hard-coded/i);
});

test('v1.12 wires public verification to 000850 with legacy fallback',()=>{
  assert.match(server,/\/api\/v1\/public\/ecert\/verify/);
  assert.match(server,/certification\.verify_public_ecert/);
  assert.match(server,/ecert_verification_event/);
  assert.match(verify,/\/api\/v1\/public\/ecert\/verify/);
  assert.match(verify,/\/api\/v1\/public\/search/);
  assert.match(verify,/PUBLIC VERIFICATION PILOT/);
});

test('v1.12 annual-plan UI captures service work area and movement type',()=>{
  assert.match(app,/Annual Trade Plans/);
  assert.match(app,/name="serviceType"/);
  assert.match(app,/name="movementType"/);
  assert.match(app,/\/import-plans\/\$\{encodeURIComponent\(r\.data\.id\)\}\/profile/);
  assert.match(legacyApi,/pp\.service_type/);
  assert.match(legacy,/x\.serviceType/);
});

test('v1.12 FIX1 adds effective-dated DVS service governance instead of hard-coding division ownership',()=>{
  assert.match(sql,/governance\.organizational_unit/);
  assert.match(sql,/governance\.service_catalog/);
  assert.match(sql,/governance\.service_scope_history/);
  assert.match(sql,/governance\.v_current_service_scope/);
  assert.match(sql,/DVS_LEAD/);
  assert.match(sql,/DVS_PARTICIPANT/);
  assert.match(sql,/EXTERNAL_OWNER/);
  assert.match(sql,/UNCONFIRMED/);
  assert.match(sql,/DVS_MANDATE_2025_PROVISIONAL/);
});

test('v1.12 FIX1 is ready for future DLF, Customs and Lao National Single Window integration',()=>{
  assert.match(sql,/integration\.external_system/);
  assert.match(sql,/integration\.external_identifier/);
  assert.match(sql,/integration\.message_envelope/);
  assert.match(sql,/integration\.v_single_window_readiness/);
  assert.match(sql,/'CUSTOMS'/);
  assert.match(sql,/'LNSW'/);
  assert.match(sql,/'DLF_GATEWAY'/);
  assert.match(sql,/no endpoint or credential is hard-coded/i);
});

test('v1.12 FIX1 keeps uncertain and shared DLF responsibilities configurable',()=>{
  assert.match(sql,/'ANIMAL_FEED_TRADE','UNCONFIRMED'/);
  assert.match(sql,/'LIVE_ANIMAL_TRADE','DVS_PARTICIPANT'/);
  assert.match(sql,/'LAB_TESTING','EXTERNAL_OWNER'/);
  assert.match(sql,/'VET_DRUG_REGISTRATION','DVS_LEAD'/);
  assert.doesNotMatch(sql,/\bDROP\s+TABLE\b/i);
  assert.doesNotMatch(sql,/\bDELETE\s+FROM\b/i);
});

