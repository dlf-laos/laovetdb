import test,{mock} from 'node:test';
import assert from 'node:assert/strict';
import {buildOpenAIIntakeRequest,validateProviderIntake,extractWithOpenAI} from '../dist/core/document-intake-openai.js';
const documents=[{document_id:'document-1',mime_type:'text/plain',payload:Buffer.from('Product: Example')}];
const output={extraction:{schemaVersion:'lvsp.document-intake.v1',fields:[]},classifications:[{documentId:'document-1',documentType:'APPLICATION',confidence:0.8,reason:'Application content'}]};
test('provider request uses strict structured output and treats document content as evidence',()=>{
 const request=buildOpenAIIntakeRequest(documents,'configured-model');assert.equal(request.store,false);assert.equal(request.text.format.strict,true);assert.match(request.instructions,/untrusted evidence/);assert.equal(request.input[0].content[1].type,'input_text');
 assert.throws(()=>buildOpenAIIntakeRequest([],'model'),/up to 8/);
});
test('classifications cannot cite foreign documents or omit a document',()=>{
 assert.throws(()=>validateProviderIntake({...output,classifications:[]},documents));
 assert.throws(()=>validateProviderIntake({...output,classifications:[{...output.classifications[0],documentId:'foreign'}]},documents));
 assert.equal(validateProviderIntake(output,documents).classifications[0].requiresReview,true);
});
test('adapter parses and validates a mocked response without any real provider call',async()=>{
 const saved={provider:process.env.LVSP_AI_PROVIDER,model:process.env.LVSP_AI_MODEL,key:process.env.OPENAI_API_KEY};
 process.env.LVSP_AI_PROVIDER='openai';process.env.LVSP_AI_MODEL='test-model';process.env.OPENAI_API_KEY='test-only-placeholder';
 const stub=mock.method(globalThis,'fetch',async(url,options)=>{
  assert.equal(url,'https://api.openai.com/v1/responses');assert.equal(JSON.parse(options.body).store,false);
  return new Response(JSON.stringify({id:'mock-response',status:'completed',output:[{type:'message',content:[{type:'output_text',text:JSON.stringify(output)}]}]}),{status:200});
 });
 try{const result=await extractWithOpenAI(documents);assert.equal(result.provider,'openai');assert.equal(result.extraction.fields[0].status,'NOT_FOUND');assert.equal(stub.mock.callCount(),1);}finally{
  stub.mock.restore();for(const [key,value] of [['LVSP_AI_PROVIDER',saved.provider],['LVSP_AI_MODEL',saved.model],['OPENAI_API_KEY',saved.key]]){if(value===undefined)delete process.env[key];else process.env[key]=value;}
 }
});
