import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const web=fs.readFileSync(new URL('../../web/src/app.ts',import.meta.url),'utf8');
const parity=fs.readFileSync(new URL('../../web/src/legacy-parity.ts',import.meta.url),'utf8');
test('certificate print host is body-level and asset-aware',()=>{assert.match(web,/document\.body\.appendChild\(pa\)/);assert.match(web,/fonts\?\.ready/);});
test('memo center is local and reports centralized',()=>{assert.doesNotMatch(web,/key:'registration_memos'/);assert.match(web,/drug-memo-center-btn/);assert.match(web,/key:'regulatory_reports'/);assert.doesNotMatch(web,/id=\"drug-report\"/);assert.doesNotMatch(web,/id=\"trade-report\"/);});
test('provincial queue hidden and VM-1003 review-first',()=>{assert.match(web,/PROVINCIAL_REPORT/);assert.match(web,/VM-1003/);assert.match(web,/REVIEW/);});
test('A4 memo and central reports are print-safe and preset driven',()=>{assert.match(parity,/table-layout:fixed/);assert.match(parity,/overflow-wrap:anywhere/);assert.match(parity,/REPORT_PRESETS/);assert.match(parity,/lpr-page-source/);assert.match(parity,/lpr-page-preset/);assert.match(parity,/async function printHtml/);});
