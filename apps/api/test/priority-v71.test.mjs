import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const web=fs.readFileSync(new URL('../../web/src/app.ts',import.meta.url),'utf8');
const css=fs.readFileSync(new URL('../../web/public/styles.css',import.meta.url),'utf8');

test('v0.7.1 restores detailed admin(4)-style certificate structure',()=>{
  assert.match(web,/legacy-cert-legal/);
  assert.match(web,/08\/ສພຊ/);
  assert.match(web,/199-ລບ/);
  assert.match(web,/legacy-cert-notes/);
  assert.match(web,/img_watermark\.jpg/);
  assert.match(web,/ຫົວໜ້າກົມ/);
});

test('v0.7.1 preserves per-presentation certificate numbers and printing',()=>{
  assert.match(web,/certNo\(p,x,i,total\)/);
  assert.match(web,/printDrugCertificate/);
  assert.match(css,/legacy-cert-grid/);
  assert.match(css,/legacy-cert-wm/);
});
