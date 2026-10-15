import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {parseSpreadsheet} from '../dist/core/bulk-import.js';

test('Priority v0.5 parses Annual Plan XLSX bulk template',()=>{
  const p=new URL('../../web/public/templates/Annual_Import_Plan_Template.xlsx',import.meta.url);
  const b=fs.readFileSync(p);
  const out=parseSpreadsheet(b.toString('base64'),'Annual_Import_Plan_Template.xlsx');
  assert.equal(out.rows.length,2);
  assert.equal(out.rows[0].itemType,'MEDICINE');
  assert.equal(out.rows[1].itemType,'VETERINARY_DEVICE');
  assert.equal(out.rows[0].packageDescription,'100 ເມັດ/ກ່ອງ');
});

test('Priority v0.5 parses CSV bulk rows without one-by-one entry',()=>{
  const csv='ປະເພດ,ຊື່ (ລາວ),ຊື່ (English),ເລກທະບຽນ,ຂະໜາດບັນຈຸ,ຈຳນວນ,ໜ່ວຍ,ມູນຄ່າ USD\nຢາ,ຢາ A,Drug A,REG-1,100 mL,70,ຂວດ,1000\n';
  const out=parseSpreadsheet(Buffer.from(csv).toString('base64'),'items.csv');
  assert.equal(out.rows.length,1);
  assert.equal(out.rows[0].quantity,70);
  assert.equal(out.rows[0].registrationNo,'REG-1');
});
