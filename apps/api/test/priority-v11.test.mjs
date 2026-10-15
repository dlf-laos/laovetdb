import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {server,store} from '../dist/server.js';

let base;
test.before(async()=>{if(store.reset)await store.reset();await new Promise(r=>server.listen(0,'127.0.0.1',r));base=`http://127.0.0.1:${server.address().port}`});
test.after(async()=>{await new Promise(r=>server.close(r));});

test('v1.1 provincial reporting API is PostgreSQL-only in the executable development server',async()=>{
  const r=await fetch(base+'/api/v1/reporting/config',{headers:{'x-lvsp-user':'v11-admin','x-lvsp-role':'SYSTEM_ADMIN'}});
  // automated tests run on the in-memory development store; the real module intentionally requires PostgreSQL.
  assert.equal(r.status,501);
});

test('v1.1 migration models source reports, indicators, trade and monthly consolidation without destructive delete',()=>{
  const sql=fs.readFileSync(new URL('../../../database/migrations/000760_provincial_reporting_consolidation.sql',import.meta.url),'utf8');
  assert.match(sql,/CREATE SCHEMA IF NOT EXISTS reporting/i);
  assert.match(sql,/reporting\.report_submission/);
  assert.match(sql,/reporting\.indicator_value/);
  assert.match(sql,/reporting\.trade_stat/);
  assert.match(sql,/reporting\.monthly_report_draft/);
  assert.match(sql,/REPORTING_MODULE_ENABLED/);
  assert.match(sql,/WEEKLY.*MONTHLY/s);
  assert.doesNotMatch(sql,/DROP\s+(TABLE|SCHEMA)/i);
});

test('v1.1 source implements one reporting module with region assignments, verification gate and anti-double-counting',()=>{
  const web=fs.readFileSync(new URL('../../web/src/app.ts',import.meta.url),'utf8');
  const serverSrc=fs.readFileSync(new URL('../src/server.ts',import.meta.url),'utf8');
  const storeSrc=fs.readFileSync(new URL('../src/core/postgres-store.ts',import.meta.url),'utf8');
  assert.match(web,/key:'provincial_reporting'/);
  assert.match(web,/renderReportingInbox/);
  assert.match(web,/renderReportingEntry/);
  assert.match(web,/renderReportingSummary/);
  assert.match(web,/renderReportingAssignments/);
  assert.match(web,/REPORTING_MODULE_ENABLED/);
  assert.match(serverSrc,/canVerifyReporting/);
  assert.match(serverSrc,/Technical reviewer or management role required/);
  assert.match(storeSrc,/report_type==='MONTHLY'/);
  assert.match(storeSrc,/report_type='WEEKLY'/);
  assert.match(storeSrc,/report_type==='WEEKLY'/);
  assert.match(storeSrc,/report_type='MONTHLY'/);
  assert.match(storeSrc,/include_in_consolidation=false/);
  assert.match(storeSrc,/suggestedNarrativeLo/);
});
