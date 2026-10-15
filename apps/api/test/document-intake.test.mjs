import test from 'node:test';
import assert from 'node:assert/strict';
import {validateIntakeExtraction,prepareIntakeReview,intakeFields} from '../src/core/document-intake.ts';
const source={documentId:'case-document-1',page:1,location:null,quote:'Product: Example'};
const field={key:'productName',status:'FOUND',value:'Example',confidence:0.95,sources:[source]};
const envelope=(fields=[field])=>({schemaVersion:'lvsp.document-intake.v1',fields});
const validate=value=>validateIntakeExtraction(value,new Set(['case-document-1']));
test('preserves evidence, fills omitted fields as missing, and requires human review',()=>{
 const data=validate(envelope());assert.equal(data.fields.length,intakeFields.length);
 assert.deepEqual(data.fields[0].sources,[source]);assert.equal(data.fields[1].value,null);
 const review=prepareIntakeReview(data);assert.equal(review.officialWriteAllowed,false);
 assert.ok(review.fields.every(x=>x.requiresReview));
});
test('rejects foreign dossier references and unsupported output properties',()=>{
 assert.throws(()=>validate(envelope([{...field,sources:[{...source,documentId:'another-case'}]}])),/authorized dossier/);
 assert.throws(()=>validate({...envelope(),officialStatus:'APPROVED'}),/properties/);
});
test('rejects invented missing values, invalid confidence, missing evidence and duplicate fields',()=>{
 for(const bad of [{...field,status:'NOT_FOUND'},{...field,confidence:NaN},{...field,confidence:1.1},{...field,sources:[]},{...field,sources:[{...source,page:0}]}])assert.throws(()=>validate(envelope([bad])));
 assert.throws(()=>validate(envelope([field,field])),/duplicate/);
});
test('flags conflicts and low confidence without selecting an official value',()=>{
 const review=prepareIntakeReview(validate(envelope([{...field,status:'CONFLICT',sources:[source,{...source,page:2}]},{...field,key:'genericName',confidence:0.3}])));
 assert.equal(review.fields[0].flag,'CONFLICT');assert.equal(review.fields[1].flag,'LOW_CONFIDENCE');
 assert.throws(()=>validate(envelope([{...field,status:'CONFLICT'}])),/Evidence/);
});
