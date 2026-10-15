// @ts-nocheck
import {extractWithGemini} from './document-intake-gemini.js';
import {extractWithOpenAI} from './document-intake-openai.js';
export function getIntakeAIProvider(){
 const id=process.env.LVSP_AI_PROVIDER||'gemini';
 const supported=['gemini','openai'].includes(id);
 const key=id==='gemini'?process.env.GEMINI_API_KEY:id==='openai'?process.env.OPENAI_API_KEY:null;
 return {id:supported?id:'unconfigured',label:id==='gemini'?'Google Gemini':id==='openai'?'OpenAI':'Unconfigured provider',configured:Boolean(supported&&key&&process.env.LVSP_AI_MODEL)};
}
export async function extractIntakeDocuments(documents){
 const provider=getIntakeAIProvider();
 if(!provider.configured)throw Object.assign(new Error('Configure the selected AI provider, model and server API key'),{code:'AI_NOT_CONFIGURED',statusCode:503});
 return provider.id==='gemini'?extractWithGemini(documents):extractWithOpenAI(documents);
}
