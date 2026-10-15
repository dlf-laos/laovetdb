import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=p=>fs.readFileSync(new URL(`../../../${p}`,import.meta.url),'utf8');
const migration=read('database/migrations/000840_import_plan_analytics.sql');
const web=read('apps/web/src/app.ts');
const legacyWeb=read('apps/web/src/legacy-parity.ts');
const legacyApi=read('apps/api/src/core/legacy-parity.ts');
const bulk=read('apps/api/src/core/bulk-import.ts');
const server=read('apps/api/src/server.ts');

test('v1.9 adds safe plan/import analytics views without destructive DDL',()=>{
  assert.match(migration,/analytics\.v_import_transaction_detail/);
  assert.match(migration,/analytics\.v_import_plan_tracking/);
  assert.match(migration,/analytics\.v_import_company_summary/);
  assert.match(migration,/analytics\.v_import_product_summary/);
  assert.match(migration,/unit_compatible/);
  assert.match(migration,/COUNT_VALUE/);
  assert.match(migration,/REFERENCE_ONLY/);
  assert.match(migration,/mixed physical units|never subtract/i);
  assert.doesNotMatch(migration,/\bDROP\s+TABLE\b/i);
  assert.doesNotMatch(migration,/\bDELETE\s+FROM\b/i);
});

test('v1.9 annual plan UI explicitly separates quantity value and item-count tracking',()=>{
  assert.match(web,/trackingBasis/);
  assert.match(web,/plannedItemCount/);
  assert.match(web,/SUMMARY_GROUP/);
  assert.match(web,/COUNT_VALUE/);
  assert.match(web,/20 ລາຍການ/);
  assert.match(web,/Plan vs Actual/);
  assert.match(web,/remainingItemCount/);
});

test('v1.9 import application items can link to annual plan items and record actual clearance',()=>{
  assert.match(web,/planItemId/);
  assert.match(web,/approvedQuantity/);
  assert.match(web,/clearedQuantity/);
  assert.match(web,/itemValue/);
  assert.match(server,/planItemId/);
});

test('v1.9 central report center contains filtered import analytics and rankings',()=>{
  assert.match(legacyWeb,/Import Plan & Analytics/);
  assert.match(legacyWeb,/openImportPlanAnalyticsDashboard/);
  assert.match(legacyWeb,/Top Companies/);
  assert.match(legacyWeb,/Top Products/);
  assert.match(legacyWeb,/Plan vs Actual/);
  assert.match(legacyWeb,/Checkpoint/);
  assert.match(legacyApi,/reports\/import-analytics/);
  assert.match(legacyApi,/v_import_transaction_detail/);
  assert.match(legacyApi,/v_import_plan_tracking/);
});

test('v1.9 bulk import recognizes boss Excel headers and plan references',()=>{
  assert.match(bulk,/ປີແຜນ/);
  assert.match(bulk,/ຊື່ບໍລິສັດນຳເຂົ້າ/);
  assert.match(bulk,/ຊື່ອ້າງອີງຕາມແຜນ/);
  assert.match(bulk,/ຊື່ສິນຄ້າຕົວຈິງນຳເຂົ້າ/);
  assert.match(bulk,/ດ່ານນຳເຂົ້າ/);
  assert.match(bulk,/planItemId/);
  assert.match(bulk,/planMatchMethod/);
  assert.match(bulk,/COUNT_VALUE/);
});

test('v1.9 does not fabricate an updated_at column on the base import_plan_item table',()=>{
  const block=legacyApi.match(/update trade\.import_plan_item set[\s\S]*?where id=\$5/)?.[0]||'';
  assert.ok(block.length>0);
  assert.doesNotMatch(block,/updated_at/);
});

test('v1.9 FIX1 gives annual-plan lookup map an explicit value type',()=>{
  assert.match(web,/new Map<string,any>\(\(pr\.data\|\|\[\]\)\.map/);
});
