import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=p=>fs.readFileSync(new URL(`../../../${p}`,import.meta.url),'utf8');
const web=read('apps/web/src/app.ts');
const css=read('apps/web/public/styles.css');

test('v1.8.1 prints trade notification letters from an isolated print document',()=>{
  assert.match(web,/function printPermitStandalone/);
  assert.match(web,/contentDocument/);
  assert.match(web,/LVSP Notification Letter/);
  assert.match(web,/printPermitStandalone\(`<section class="permit-page"/);
});

test('v1.8.1 exposes every public module as an inspectable catalog item',()=>{
  assert.match(web,/public-module-card/);
  assert.match(web,/data-public-module/);
  assert.match(web,/All Module Overview|ພາບລວມ Modules ທັງໝົດ/);
  assert.match(web,/public-module-detail/);
  assert.match(css,/public-module-detail-grid/);
});

test('v1.8.1 keeps operational work behind login while showing public module context',()=>{
  assert.match(web,/Login required for internal operations|ຕ້ອງ Login ສຳລັບວຽກພາຍໃນ/);
  assert.match(web,/Import, export and transit are part of LVSP|ວຽກນຳເຂົ້າ · ສົ່ງອອກ · ສົ່ງຜ່ານ/);
  assert.match(web,/modules currently being built|ກຳລັງສ້າງ/);
});
