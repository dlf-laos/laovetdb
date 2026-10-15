import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=p=>fs.readFileSync(new URL(`../../../${p}`,import.meta.url),'utf8');
const server=read('apps/api/src/server.ts');
const store=read('apps/api/src/core/postgres-store.ts');
const web=read('apps/web/src/app.ts');
const css=read('apps/web/public/styles.css');

test('v1.8.2 exposes a public unified search endpoint',()=>{
  assert.match(server,/\/api\/v1\/public\/search/);
  assert.match(store,/async publicSearch\(/);
  assert.match(store,/DRUG_REGISTRATION/);
  assert.match(store,/TRADE_DOCUMENT/);
  assert.match(store,/MODULE/);
});

test('v1.8.2 searches public permit and document references safely',()=>{
  assert.match(store,/application_no/);
  assert.match(store,/permit_no/);
  assert.match(store,/decision_no/);
  assert.match(store,/Notification Letter/);
  assert.match(store,/APPROVED','CLEARED','COMPLETED/);
});

test('v1.8.2 public page is search-first and does not dump the registry table',()=>{
  assert.match(web,/public-global-search/);
  assert.match(web,/\/public\/search\?q=/);
  assert.match(web,/ເລກທະບຽນ/);
  assert.match(web,/ເລກໃບອະນຸຍາດ/);
  assert.doesNotMatch(web,/id="public-drug-body"/);
  assert.match(css,/public-search-results-list/);
});
