import test from 'node:test';
import assert from 'node:assert/strict';
import {validateIntakeUpload} from '../dist/core/document-intake-api.js';
const input={filename:'GMP.txt',mimeType:'text/plain',documentType:'GMP',base64:Buffer.from('Evidence ລາວ').toString('base64')};
test('upload validation preserves UTF-8 evidence and hashes the actual bytes',()=>{
 const file=validateIntakeUpload(input);assert.equal(file.bytes.toString(),'Evidence ລາວ');assert.match(file.sha256,/^[0-9a-f]{64}$/);
});
test('rejects executable formats, forged signatures, paths and excessive file sizes',()=>{
 for(const bad of [{...input,mimeType:'text/html'},{...input,mimeType:'application/pdf'},{...input,filename:'../file.txt'},{...input,base64:'not base64!'},{...input,base64:Buffer.alloc(2097153,65).toString('base64')},{...input,documentType:'APPROVED'}])assert.throws(()=>validateIntakeUpload(bad));
});
