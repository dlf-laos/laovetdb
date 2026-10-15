import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const web=fs.readFileSync(new URL('../../web/src/legacy-parity.ts',import.meta.url),'utf8');
const app=fs.readFileSync(new URL('../../web/src/app.ts',import.meta.url),'utf8');
const version=fs.readFileSync(new URL('../../../VERSION',import.meta.url),'utf8');

test('v1.10 exposes hybrid central + module reporting architecture',()=>{
  assert.match(version,/^1\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?\s*$/);
  assert.match(web,/HYBRID REPORTING ARCHITECTURE/);
  assert.match(web,/Module Report = ລາຍລະອຽດວຽກ/);
  assert.match(web,/All LVSP Executive Overview/);
  assert.match(web,/Report Coverage by Module/);
});

test('v1.10 registers all 18 LVSP module report areas without inventing planned data',()=>{
  assert.match(web,/const MODULE_REPORT_CATALOG/);
  for(const code of ['VET_DRUG_REGISTRATION','VET_DRUG_TRADE','CENTRAL_REPORTS','COMPANY_MASTER','PRODUCT_MASTER','ESTABLISHMENT_LICENSING','BORDER_CLEARANCE','INSPECTION','VETERINARY_DEVICES','LABORATORY','DISEASE_SURVEILLANCE','GIS','ANIMAL_FEED_TRADE','ANIMAL_PRODUCT_TRADE','FARM_REGISTRATION','SLAUGHTERHOUSE','WET_MARKET','COMPLAINTS_GUIDANCE']) assert.match(web,new RegExp(code));
  assert.match(web,/No fake reports/);
  assert.match(web,/status:'PLANNED'/);
});

test('v1.10 provides real generic module report builder and module-level entry points',()=>{
  assert.match(web,/export async function openGenericModuleReport/);
  for(const ep of ['/companies','/products','/veterinary-devices','/inspections','/laboratory/samples','/disease-cases','/trade/shipments','/gis/layers']) assert.ok(web.includes(`endpoint:'${ep}'`));
  assert.match(web,/export function openModuleReportForKey/);
  assert.match(app,/moduleReportAvailable/);
  assert.match(app,/module-report-btn/);
});

test('v1.10 preserves specialized drug, trade and import analytics reporting',()=>{
  assert.match(web,/openRegulatoryReportBuilder/);
  assert.match(web,/openImportPlanAnalyticsDashboard/);
  assert.match(web,/reports\/import-analytics/);
  assert.match(web,/REPORT_PRESETS/);
});
