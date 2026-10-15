import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const web=fs.readFileSync(new URL('../../web/src/app.ts',import.meta.url),'utf8');
const migration=fs.readFileSync(new URL('../../../database/migrations/000800_vet_drug_registration_operational.sql',import.meta.url),'utf8');
test('VM-1003 uses review-first UI',()=>{assert.match(web,/renderVetDrugReviewDraft/);assert.match(web,/VM-1003/);assert.match(web,/review-copy-request/);assert.match(web,/review-open-drug/);});
test('dossier and correction workflow remain authoritative',()=>{assert.match(migration,/veterinary_drug_application_document/);assert.match(migration,/verification_status/);assert.match(migration,/REQUEST_CORRECTION/);assert.match(migration,/veterinary_drug_review/);});
