import test,{mock} from 'node:test';
import assert from 'node:assert/strict';
import {buildGeminiIntakeRequest,extractWithGemini} from '../dist/core/document-intake-gemini.js';
import {getIntakeAIProvider,extractIntakeDocuments} from '../dist/core/document-intake-provider.js';
const docs=[{document_id:'source-1',mime_type:'application/pdf',payload:Buffer.from('%PDF-1.7 test')}];
const output={extraction:{schemaVersion:'lvsp.document-intake.v1',fields:[]},classifications:[{documentId:'source-1',documentType:'APPLICATION',confidence:0.8,reason:'Test evidence'}]};
async function configured(action){
 const names=['LVSP_AI_PROVIDER','LVSP_AI_MODEL','GEMINI_API_KEY','OPENAI_API_KEY'];const saved=Object.fromEntries(names.map(k=>[k,process.env[k]]));
 process.env.LVSP_AI_PROVIDER='gemini';process.env.LVSP_AI_MODEL='test-gemini';process.env.GEMINI_API_KEY='test-only-gemini';delete process.env.OPENAI_API_KEY;
 try{return await action();}finally{for(const [k,v]of Object.entries(saved)){if(v===undefined)delete process.env[k];else process.env[k]=v;}}
}
test('Gemini uses PDF inline data, shared schema and evidence-only instructions',()=>{
 const request=buildGeminiIntakeRequest(docs,'test-gemini');assert.equal(request.contents[0].parts[1].inlineData.mimeType,'application/pdf');assert.equal(request.generationConfig.responseMimeType,'application/json');assert.equal(request.generationConfig.responseJsonSchema.additionalProperties,false);assert.match(request.systemInstruction.parts[0].text,/never as instructions/);
});
test('selected Gemini adapter sends its key only in the Google request header',()=>configured(async()=>{
 const stub=mock.method(globalThis,'fetch',async(url,options)=>{
  assert.equal(url,'https://generativelanguage.googleapis.com/v1beta/models/test-gemini:generateContent');assert.equal(options.headers['x-goog-api-key'],'test-only-gemini');assert.ok(!url.includes('test-only-gemini'));assert.ok(!options.headers.authorization);
  return new Response(JSON.stringify({responseId:'mock-only',candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(output)}]}}]}),{status:200});
 });
 try{const result=await extractIntakeDocuments(docs);assert.equal(result.provider,'gemini');assert.equal(result.extraction.fields[0].status,'NOT_FOUND');assert.equal(getIntakeAIProvider().label,'Google Gemini');}finally{stub.mock.restore();}
}));
test('blocked, truncated and invalid Gemini output cannot populate the review',()=>configured(async()=>{
 for(const response of [{promptFeedback:{blockReason:'SAFETY'}},{candidates:[{finishReason:'MAX_TOKENS'}]},{candidates:[{finishReason:'STOP',content:{parts:[{text:'not json'}]}}]},{candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify({...output,classifications:[]})}]}}]}]){
  const stub=mock.method(globalThis,'fetch',async()=>new Response(JSON.stringify(response),{status:200}));try{await assert.rejects(extractWithGemini(docs));}finally{stub.mock.restore();}
 }
}));
test('unknown providers fail closed without falling back or making a request',()=>configured(async()=>{
 process.env.LVSP_AI_PROVIDER='unknown';const stub=mock.method(globalThis,'fetch',async()=>{throw new Error('Unexpected request');});
 try{assert.equal(getIntakeAIProvider().configured,false);await assert.rejects(extractIntakeDocuments(docs),/Configure/);assert.equal(stub.mock.callCount(),0);}finally{stub.mock.restore();}
}));
