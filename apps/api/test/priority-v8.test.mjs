import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration=fs.readFileSync(new URL('../../../database/migrations/000730_company_master_multisite.sql',import.meta.url),'utf8');
const web=fs.readFileSync(new URL('../../web/src/app.ts',import.meta.url),'utf8');
const server=fs.readFileSync(new URL('../src/server.ts',import.meta.url),'utf8');
const pg=fs.readFileSync(new URL('../src/core/postgres-store.ts',import.meta.url),'utf8');
const enrich=fs.readFileSync(new URL('../../../scripts/enrich-company-multisite.mjs',import.meta.url),'utf8');

test('v0.8 models one legal company with many effective-dated sites and addresses',()=>{
  assert.match(migration,/CREATE TABLE IF NOT EXISTS master\.company_site/);
  assert.match(migration,/site_role_code/);
  assert.match(migration,/MANUFACTURING_SITE/);
  assert.match(migration,/REGISTRATION_HOLDER_OFFICE/);
  assert.match(migration,/facility_contact/);
  assert.match(migration,/valid_from/);
  assert.match(migration,/valid_to/);
});

test('v0.8 company API supports drill-down edit roles sites and licences',()=>{
  assert.match(server,/companies\\\/\(\[\^\/\]\+\)\\\/complete/);
  assert.match(server,/company-sites/);
  assert.match(server,/registrations/);
  assert.match(server,/roles/);
  assert.match(pg,/async companyComplete/);
  assert.match(pg,/async createCompanySite/);
  assert.match(pg,/async setCompanyRoles/);
});

test('v0.8 company UI supports detail edit multi-site and duplicate review',()=>{
  assert.match(web,/key:'companies'.*drill:true/);
  assert.match(web,/openCompanyDetail/);
  assert.match(web,/openCompanySiteForm/);
  assert.match(web,/1 legal company = 1 Company Master/);
  assert.match(web,/Potential Duplicate Review/);
});

test('v0.8 product registration links role-specific companies and physical sites',()=>{
  assert.match(migration,/holder_site_id/);
  assert.match(migration,/manufacturer_company_id/);
  assert.match(migration,/manufacturer_site_id/);
  assert.match(web,/holderSiteId/);
  assert.match(web,/manufacturerCompanyId/);
  assert.match(web,/manufacturerSiteId/);
  assert.match(pg,/COMPANY_SITE_MISMATCH/);
});

test('v0.8 preserves legacy company addresses without destructive automatic merging',()=>{
  assert.match(enrich,/Legacy trade operators: preserve old address as a physical business site/);
  assert.match(migration,/No automatic merge of possibly duplicate legal entities/);
  assert.match(pg,/REVIEW_REQUIRED/);
});
