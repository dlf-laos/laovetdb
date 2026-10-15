import test,{mock} from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {S3Client} from '@aws-sdk/client-s3';
import {putIntakeDocument,readIntakeDocument} from '../dist/core/document-intake-storage.js';
test('S3 adapter signs through the official SDK, uses encryption and checks retrieved evidence',async()=>{
 const saved=Object.fromEntries(['LVSP_INTAKE_STORAGE','LVSP_INTAKE_S3_BUCKET','AWS_REGION','LVSP_INTAKE_S3_PRIVATE_CONFIRMED'].map(k=>[k,process.env[k]]));
 delete process.env.LVSP_INTAKE_STORAGE;process.env.LVSP_INTAKE_S3_BUCKET='test-private-bucket';process.env.AWS_REGION='us-east-1';process.env.LVSP_INTAKE_S3_PRIVATE_CONFIRMED='true';
 const bytes=Buffer.from('Private test evidence');const key='lvsp/intake/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222';
 const stub=mock.method(S3Client.prototype,'send',async command=>{
  assert.equal(command.input.Bucket,'test-private-bucket');assert.equal(command.input.Key,key);
  if(command.constructor.name==='PutObjectCommand'){assert.equal(command.input.ServerSideEncryption,'AES256');assert.equal(command.input.IfNoneMatch,'*');assert.equal(command.input.ACL,undefined);return {};}
  return {ContentLength:bytes.length,Body:(async function*(){yield bytes;})()};
 });
 try{
  assert.equal((await putIntakeDocument(key,bytes)).provider,'S3');
  const file={storage_provider:'S3',object_key:key,size_bytes:bytes.length,sha256_checksum:crypto.createHash('sha256').update(bytes).digest('hex')};
  assert.deepEqual(await readIntakeDocument(file),bytes);
  await assert.rejects(readIntakeDocument({...file,sha256_checksum:'invalid'}),/checksum/);
  await assert.rejects(putIntakeDocument('../escape',bytes),/Invalid intake object/);
  assert.equal(stub.mock.callCount(),3);
 }finally{stub.mock.restore();for(const [key,value] of Object.entries(saved)){if(value===undefined)delete process.env[key];else process.env[key]=value;}}
});
test('storage fails closed when a private bucket is not configured',async()=>{
 const saved=process.env.LVSP_INTAKE_S3_PRIVATE_CONFIRMED;process.env.LVSP_INTAKE_S3_PRIVATE_CONFIRMED='false';
 try{await assert.rejects(putIntakeDocument('lvsp/intake/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222',Buffer.from('x')),/private S3/);}finally{if(saved===undefined)delete process.env.LVSP_INTAKE_S3_PRIVATE_CONFIRMED;else process.env.LVSP_INTAKE_S3_PRIVATE_CONFIRMED=saved;}
});
test('Neon storage requires a branch HTTPS endpoint and uses path-style requests',async()=>{
 const names=['LVSP_INTAKE_STORAGE','LVSP_INTAKE_S3_BUCKET','AWS_REGION','AWS_ENDPOINT_URL_S3','LVSP_INTAKE_S3_PRIVATE_CONFIRMED','AWS_ACCESS_KEY_ID','AWS_SECRET_ACCESS_KEY','AWS_SESSION_TOKEN'];
 const saved=Object.fromEntries(names.map(k=>[k,process.env[k]]));
 Object.assign(process.env,{LVSP_INTAKE_STORAGE:'neon-s3',LVSP_INTAKE_S3_BUCKET:'private-preview',AWS_REGION:'us-east-2',LVSP_INTAKE_S3_PRIVATE_CONFIRMED:'true',AWS_ENDPOINT_URL_S3:'http://untrusted.example'});
 const key='lvsp/intake/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222';
 let stub;
 try{
  await assert.rejects(putIntakeDocument(key,Buffer.from('evidence')),/verified Neon branch HTTPS/);
  process.env.AWS_ENDPOINT_URL_S3='https://br-test-preview.storage.c-5.us-east-2.aws.neon.tech';
  process.env.AWS_ACCESS_KEY_ID='test-neon-access';process.env.AWS_SECRET_ACCESS_KEY='test-neon-secret';process.env.AWS_SESSION_TOKEN='unrelated-host-token';
  stub=mock.method(S3Client.prototype,'send',async function(command){
   assert.equal(this.config.forcePathStyle,true);
   const credentials=await this.config.credentials();assert.equal(credentials.accessKeyId,'test-neon-access');assert.equal(credentials.sessionToken,undefined);
   assert.equal((await this.config.endpoint()).hostname,'br-test-preview.storage.c-5.us-east-2.aws.neon.tech');
   assert.equal(command.input.ServerSideEncryption,undefined);
   assert.equal(command.input.ACL,undefined);
   assert.equal(command.input.IfNoneMatch,'*');
   return {};
  });
  await putIntakeDocument(key,Buffer.from('evidence'));assert.equal(stub.mock.callCount(),1);
 }finally{stub?.mock.restore();for(const [key,value] of Object.entries(saved)){if(value===undefined)delete process.env[key];else process.env[key]=value;}}
});
