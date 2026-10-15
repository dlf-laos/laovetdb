// @ts-nocheck
// Google Gemini API adapter. Browser login/email is never used as an API credential.
import {buildOpenAIIntakeRequest,validateProviderIntake} from './document-intake-openai.js';
const error=(code,message,statusCode=502)=>Object.assign(new Error(message),{code,statusCode});
export function buildGeminiIntakeRequest(documents,model){
 // Reuse the same pure schema/instruction builder and local evidence validator.
 const contract=buildOpenAIIntakeRequest(documents,model);
 const parts=[];
 for(const document of documents){
  parts.push({text:'Source document ID: '+document.document_id});
  if(document.mime_type==='text/plain')parts.push({text:'UNTRUSTED DOCUMENT CONTENT:\n'+document.payload.toString('utf8')});
  else parts.push({inlineData:{mimeType:document.mime_type,data:document.payload.toString('base64')}});
 }
 return {systemInstruction:{parts:[{text:contract.instructions}]},contents:[{role:'user',parts}],generationConfig:{responseMimeType:'application/json',responseJsonSchema:contract.text.format.schema,maxOutputTokens:10000,candidateCount:1}};
}
export async function extractWithGemini(documents){
 const model=process.env.LVSP_AI_MODEL;
 if(!process.env.GEMINI_API_KEY||!model)throw error('AI_NOT_CONFIGURED','Gemini API key and model must be configured on the server',503);
 if(!/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(model))throw error('INVALID_AI_MODEL','Use a Gemini model ID, not a URL or model path',503);
 const request=buildGeminiIntakeRequest(documents,model);
 let response;
 try{response=await fetch('https://generativelanguage.googleapis.com/v1beta/models/'+encodeURIComponent(model)+':generateContent',{method:'POST',headers:{'x-goog-api-key':process.env.GEMINI_API_KEY,'content-type':'application/json'},body:JSON.stringify(request),signal:AbortSignal.timeout(35000)});}catch{throw error('AI_UNAVAILABLE','Gemini request failed or timed out. No extracted values were saved.');}
 if(!response.ok)throw error('AI_PROVIDER_ERROR','Gemini rejected the request (HTTP '+response.status+'). Check server key/model/quota.');
 const result=await response.json();
 const candidate=result.candidates?.[0];
 if(result.promptFeedback?.blockReason||!candidate||candidate.finishReason!=='STOP')throw error('AI_INCOMPLETE','Gemini blocked or did not complete extraction. No fields were saved.');
 const text=(candidate.content?.parts||[]).filter(part=>typeof part.text==='string'&&part.thought!==true).map(part=>part.text).join('');
 let parsed;try{parsed=JSON.parse(text);}catch{throw error('INVALID_AI_OUTPUT','Gemini did not return valid structured JSON');}
 return {...validateProviderIntake(parsed,documents),provider:'gemini',model,responseId:typeof result.responseId==='string'?result.responseId.slice(0,150):null,schemaVersion:'lvsp.document-intake.v1'};
}
