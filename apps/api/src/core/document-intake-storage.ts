// @ts-nocheck
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {S3Client,PutObjectCommand,GetObjectCommand} from '@aws-sdk/client-s3';
const fail=(code,message,statusCode=503)=>{throw Object.assign(new Error(message),{code,statusCode});};
function validKey(key){if(!/^lvsp\/intake\/[a-f0-9-]{36}\/[a-f0-9-]{36}$/.test(key))fail('INVALID_OBJECT_KEY','Invalid intake object reference',400);return key;}
function testRoot(){
 if(process.env.NODE_ENV!=='test'||!process.env.LVSP_INTAKE_TEST_DIRECTORY)fail('STORAGE_NOT_CONFIGURED','Local file storage is available only for isolated tests');
 return path.resolve(process.env.LVSP_INTAKE_TEST_DIRECTORY);
}
function s3(){
 if(!process.env.LVSP_INTAKE_S3_BUCKET||!process.env.AWS_REGION||process.env.LVSP_INTAKE_S3_PRIVATE_CONFIRMED!=='true')fail('STORAGE_NOT_CONFIGURED','Configure a private S3 bucket, AWS region/credentials and confirm private access before uploading dossiers');
 const neon=process.env.LVSP_INTAKE_STORAGE==='neon-s3';
 const endpoint=process.env.AWS_ENDPOINT_URL_S3;
 if(neon&&(!endpoint||!/^https:\/\/br-[a-z0-9-]+\.storage\.c-\d+\.[a-z0-9-]+\.aws\.neon\.tech\/?$/.test(endpoint)))fail('STORAGE_NOT_CONFIGURED','Configure the verified Neon branch HTTPS storage endpoint');
 if(neon&&(!process.env.AWS_ACCESS_KEY_ID||!process.env.AWS_SECRET_ACCESS_KEY))fail('STORAGE_NOT_CONFIGURED','Configure the Neon storage credential');
 return new S3Client({region:process.env.AWS_REGION,...(neon?{endpoint,forcePathStyle:true,credentials:{accessKeyId:process.env.AWS_ACCESS_KEY_ID,secretAccessKey:process.env.AWS_SECRET_ACCESS_KEY}}:{}),maxAttempts:2,requestHandler:{connectionTimeout:3000,requestTimeout:10000}});
}
export async function putIntakeDocument(key,bytes){
 validKey(key);
 if(process.env.LVSP_INTAKE_STORAGE==='test-filesystem'){
  const file=path.join(testRoot(),key);fs.mkdirSync(path.dirname(file),{recursive:true,mode:0o700});fs.writeFileSync(file,bytes,{mode:0o600,flag:'wx'});return {provider:'LOCAL_TEST',key};
 }
 const client=s3();
 try{await client.send(new PutObjectCommand({Bucket:process.env.LVSP_INTAKE_S3_BUCKET,Key:key,Body:bytes,ContentType:'application/octet-stream',...(process.env.LVSP_INTAKE_STORAGE==='neon-s3'?{}:{ServerSideEncryption:'AES256'}),IfNoneMatch:'*'}));return {provider:'S3',key};}
 catch{fail('STORAGE_WRITE_FAILED','Private object storage upload failed; document metadata was not committed');}finally{client.destroy();}
}
export async function readIntakeDocument(file){
 validKey(file.object_key);let bytes;
 if(file.storage_provider==='LOCAL_TEST')bytes=fs.readFileSync(path.join(testRoot(),file.object_key));
 else if(file.storage_provider==='S3'){
  const client=s3();
  try{
   const object=await client.send(new GetObjectCommand({Bucket:process.env.LVSP_INTAKE_S3_BUCKET,Key:file.object_key}));
   if(Number(object.ContentLength)>2097152)fail('STORAGE_INTEGRITY_ERROR','Stored document exceeds its allowed size',502);
   let size=0;const chunks=[];
   for await(const chunk of object.Body){size+=chunk.length;if(size>2097152)fail('STORAGE_INTEGRITY_ERROR','Stored document exceeds its allowed size',502);chunks.push(chunk);}
   bytes=Buffer.concat(chunks);
  }catch{fail('STORAGE_READ_FAILED','Private source document could not be retrieved');}finally{client.destroy();}
 }else fail('STORAGE_NOT_CONFIGURED','Unknown private document storage provider');
 if(bytes.length!==Number(file.size_bytes)||crypto.createHash('sha256').update(bytes).digest('hex')!==file.sha256_checksum)fail('STORAGE_INTEGRITY_ERROR','Stored document checksum or size does not match its registered metadata',502);
 return bytes;
}
