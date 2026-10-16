import {handleAmuApi} from './core/amu-api.js';
// LVSP zero-dependency executable API for development and UAT scaffolding.
// PostgreSQL remains the authoritative production database specification.
// @ts-nocheck
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { JsonFileStore } from './core/store.js';
import { PostgresStore } from './core/postgres-store.js';
import { getPrincipal, authorize } from './core/security.js';
import {authenticateLocal,issueToken} from './core/auth.js';
import { readJson, requestIds, sendJson, failure } from './core/http.js';
import { buildRouteMatcher, executeRoute } from './modules/router.js';
import { parseSpreadsheet, enrichRows } from './core/bulk-import.js';
import { fallbackCatalog, fallbackGuide } from './core/guided-services.js';
import { vetDrugReferenceFallback } from './core/vet-drug-reference.js';
import { handleVetDrugOperationalApi } from './core/vet-drug-operational.js';
import {handleDocumentIntakeApi} from './core/document-intake-api.js';
import {handleDepartmentOperationsApi} from './core/department-operations.js';
import { handleLegacyParityApi } from './core/legacy-parity.js';

const __filename=fileURLToPath(import.meta.url);
const __dirname=path.dirname(__filename);
const repoRoot=path.resolve(__dirname,'../../..');
const port=Number(process.env.PORT || 8787);
const authMode=String(process.env.AUTH_MODE || 'demo').toLowerCase();
const nodeEnv=String(process.env.NODE_ENV||'development').toLowerCase();
if(nodeEnv==='production' && !['database','oidc'].includes(authMode)) throw new Error('Production requires AUTH_MODE=database or oidc');
if(nodeEnv==='production' && String(process.env.LVSP_AUTH_SECRET||'').length<32) throw new Error('LVSP_AUTH_SECRET must be at least 32 characters in production');
const dataFile=process.env.LVSP_LOCAL_DATA_FILE || path.join(repoRoot,'apps/api/runtime/lvsp-data.json');
const routesFile=path.join(repoRoot,'apps/api/runtime/routes.json');
const webRoot=path.join(repoRoot,'apps/web/public');
const fieldRoot=path.join(repoRoot,'apps/field/public');
const releaseVersion=fs.existsSync(path.join(repoRoot,'VERSION'))?fs.readFileSync(path.join(repoRoot,'VERSION'),'utf8').trim():'development';
const openapiFile=path.join(repoRoot,'openapi/lvsp-openapi.yaml');
const storageMode=String(process.env.LVSP_STORAGE || 'json').toLowerCase();
const store = storageMode==='postgres'
  ? await PostgresStore.create(process.env.DATABASE_URL || '')
  : new JsonFileStore(dataFile);
if(nodeEnv==='production' && storageMode!=='postgres') throw new Error('Production requires LVSP_STORAGE=postgres');
if(authMode==='database' && store.mode!=='postgres') throw new Error('AUTH_MODE=database requires LVSP_STORAGE=postgres');
const routes=buildRouteMatcher(JSON.parse(fs.readFileSync(routesFile,'utf8')));

function isAdminPrincipal(principal:any){return Array.isArray(principal?.roles)&&principal.roles.some((r:string)=>['SYSTEM_ADMIN','SECURITY_ADMIN'].includes(r));}
function canVerifyReporting(principal:any){return Array.isArray(principal?.roles)&&principal.roles.some((r:string)=>['SYSTEM_ADMIN','SECURITY_ADMIN','TECHNICAL_REVIEWER','MANAGEMENT_VIEWER'].includes(r));}
async function guidedCatalog(publicOnly=true){return store.mode==='postgres'?await (store as any).guidedServiceCatalog(publicOnly):fallbackCatalog();}
async function guidedGuide(serviceCode:string){return store.mode==='postgres'?await (store as any).guidedServiceGuide(serviceCode):fallbackGuide(serviceCode);}
async function localDraftComplete(id:string,startedBy:string,isAdmin=false){
  const d=await store.get('service_drafts',id);if(!d||(!isAdmin&&String(d.startedBy)!==String(startedBy)))return undefined;
  return {draft:d,steps:Array.isArray(d.steps)?d.steps:[],requirements:Array.isArray(d.requirements)?d.requirements:[]};
}
async function createGuidedDraft(serviceCode:string,startedBy:string,input:any={}){
  if(store.mode==='postgres')return (store as any).createServiceDraft(serviceCode,startedBy,input);
  const guide=fallbackGuide(serviceCode);if(!guide)throw Object.assign(new Error('Guided service not found'),{statusCode:404,code:'SERVICE_NOT_FOUND'});
  const steps=(guide.steps||[]).map((x:any,i:number)=>({...x,id:`step-${i+1}`,status:i===0?'IN_PROGRESS':'NOT_STARTED',stepPayload:{},completedAt:null}));
  const requirements=(guide.requirements||[]).map((x:any,i:number)=>({...x,id:`req-${i+1}`,status:'PENDING',checkedAt:null}));
  const d=await store.create('service_drafts',{serviceCodeSnapshot:serviceCode,serviceNameLo:guide.service.nameLo,serviceNameEn:guide.service.nameEn,icon:guide.service.icon,launchModuleKey:guide.service.launchModuleKey,startedBy,status:'IN_PROGRESS',currentStepCode:steps[0]?.stepCode||null,draftPayload:input.payload||{},companyId:input.companyId||null,steps,requirements,lastSavedAt:new Date().toISOString()});
  return {draft:d,steps,requirements};
}
async function listGuidedDrafts(startedBy:string,isAdmin=false){
  if(store.mode==='postgres')return (store as any).serviceDrafts(startedBy,isAdmin);
  const rows=await store.list('service_drafts');return rows.filter((x:any)=>isAdmin||String(x.startedBy)===String(startedBy)).sort((a:any,b:any)=>String(b.updatedAt||'').localeCompare(String(a.updatedAt||''))).map((x:any)=>({...x,completedSteps:(x.steps||[]).filter((s:any)=>s.status==='COMPLETED').length,totalSteps:(x.steps||[]).length}));
}
async function getGuidedDraft(id:string,startedBy:string,isAdmin=false){return store.mode==='postgres'?await (store as any).serviceDraftComplete(id,startedBy,isAdmin):await localDraftComplete(id,startedBy,isAdmin);}
async function saveGuidedDraftStep(id:string,startedBy:string,input:any,isAdmin=false){
  if(store.mode==='postgres')return (store as any).saveServiceDraftStep(id,startedBy,input,isAdmin);
  const d:any=await store.get('service_drafts',id);if(!d)throw Object.assign(new Error('Service draft not found'),{statusCode:404,code:'SERVICE_DRAFT_NOT_FOUND'});if(!isAdmin&&String(d.startedBy)!==String(startedBy))throw Object.assign(new Error('Not allowed to access this draft'),{statusCode:403,code:'FORBIDDEN'});
  const steps=[...(d.steps||[])];const ix=steps.findIndex((x:any)=>x.stepCode===String(input.stepCode||d.currentStepCode||''));if(ix<0)throw Object.assign(new Error('Unknown service step'),{statusCode:400,code:'INVALID_SERVICE_STEP'});
  const completed=input.completed!==false;steps[ix]={...steps[ix],status:completed?'COMPLETED':'IN_PROGRESS',stepPayload:{...(steps[ix].stepPayload||{}),...(input.payload||{})},completedAt:completed?(steps[ix].completedAt||new Date().toISOString()):null};
  const reqs=[...(d.requirements||[])].map((x:any)=>input.requirements&&Object.prototype.hasOwnProperty.call(input.requirements,x.requirementCode)?{...x,status:String(input.requirements[x.requirementCode]),checkedAt:new Date().toISOString()}:x);
  const next=steps.find((x:any)=>x.status!=='COMPLETED');const patch={steps,requirements:reqs,currentStepCode:next?.stepCode||steps[ix].stepCode,status:next?'IN_PROGRESS':'GUIDE_COMPLETED',draftPayload:{...(d.draftPayload||{}),...(input.payload||{})},lastSavedAt:new Date().toISOString()};await store.update('service_drafts',id,patch);return localDraftComplete(id,startedBy,true);
}
async function linkGuidedDraft(id:string,startedBy:string,targetResource:string,targetId:string,isAdmin=false){
  if(store.mode==='postgres')return (store as any).linkServiceDraft(id,startedBy,targetResource,targetId,isAdmin);
  const d:any=await store.get('service_drafts',id);if(!d)throw Object.assign(new Error('Service draft not found'),{statusCode:404,code:'SERVICE_DRAFT_NOT_FOUND'});if(!isAdmin&&String(d.startedBy)!==String(startedBy))throw Object.assign(new Error('Not allowed'),{statusCode:403,code:'FORBIDDEN'});return store.update('service_drafts',id,{targetResource,targetId,status:'DOMAIN_DRAFT_CREATED',completedAt:d.completedAt||new Date().toISOString(),lastSavedAt:new Date().toISOString()});
}
async function getMyWork(userId:string,isAdmin=false){
  if(store.mode==='postgres')return (store as any).myWorkQueue(userId,isAdmin);
  const drafts=await listGuidedDrafts(userId,isAdmin);const queues=[] as any[];for(const [resource,queueType,statusKey] of [['import_applications','IMPORT_APPLICATION','status'],['drug_registrations','DRUG_REGISTRATION','registrationStatus'],['import_plans','ANNUAL_PLAN','status']] as any[]){const rows=await store.list(resource);const m=new Map<string,number>();for(const r of rows){const st=String(r[statusKey]||'UNKNOWN');m.set(st,(m.get(st)||0)+1)}for(const [status,itemCount] of m)queues.push({queueType,status,itemCount});}return {tasks:[],domainQueues:queues,guidedDrafts:Object.entries(drafts.reduce((a:any,x:any)=>{a[x.status]=(a[x.status]||0)+1;return a},{})).map(([status,itemCount])=>({status,itemCount})),drafts};
}

function contentType(file:string){
  const ext=path.extname(file).toLowerCase();
  return ({'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.json':'application/json; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.yaml':'application/yaml; charset=utf-8','.webmanifest':'application/manifest+json; charset=utf-8'} as any)[ext] || 'application/octet-stream';
}

function staticFile(res:any,file:string){
  if(!fs.existsSync(file) || !fs.statSync(file).isFile()) return false;
  const b=fs.readFileSync(file); res.writeHead(200,{'content-type':contentType(file),'content-length':b.length});res.end(b);return true;
}

const server=http.createServer(async(req,res)=>{
  const ids=requestIds(req);
  try{
    if(req.method==='OPTIONS'){res.writeHead(204,{'access-control-allow-origin':'*','access-control-allow-headers':'*','access-control-allow-methods':'GET,POST,PATCH,PUT,OPTIONS'});return res.end();}
    const url=new URL(req.url || '/',`http://${req.headers.host || 'localhost'}`);
    if(url.pathname.startsWith('/api/v1/')){
      const apiPath=url.pathname.slice('/api/v1'.length);
      const auth=authorize(getPrincipal(req),req.method||'GET',apiPath);
      if(!auth.ok)return sendJson(res,auth.code==='UNAUTHENTICATED'?401:403,failure(auth.code,auth.code==='UNAUTHENTICATED'?'Authentication required':'Insufficient permission',ids),ids);
    }
    if(await handleAmuApi({req,res,url,store,ids,principal:getPrincipal(req)}))return;
    if(await handleDocumentIntakeApi({req,res,url,store,ids,principal:getPrincipal(req)}))return;
    if(await handleDepartmentOperationsApi({req,res,url,store,ids,principal:getPrincipal(req)}))return;
    if(url.pathname==='/openapi.yaml') return staticFile(res,openapiFile);
    if(url.pathname==='/api/v1/public/service-catalog' && req.method==='GET'){
      const data=await guidedCatalog(true);return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/public/module-catalog' && req.method==='GET'){
      const data=store.mode==='postgres'?await (store as any).publicModuleCatalog(true):[];
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/public/overview' && req.method==='GET'){
      const data=store.mode==='postgres'?await (store as any).publicOverview():{activeDrugRegistrations:0,activeCompanies:0,completedTradeRecords:0};
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/public/drug-registry' && req.method==='GET'){
      const q=String(url.searchParams.get('q')||'');const limit=Number(url.searchParams.get('limit')||100);
      const data=store.mode==='postgres'?await (store as any).publicDrugRegistry(q,limit):[];
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/public/ecert/verify' && req.method==='GET'){
      const q=String(url.searchParams.get('q')||'').trim();
      if(!q)return sendJson(res,200,{data:[],meta:{requestId:ids.requestId}},ids);
      if(q.length>240)return sendJson(res,400,failure('QUERY_TOO_LONG','Verification query is too long',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','National e-Cert verification requires PostgreSQL mode',ids),ids);
      const pool=(store as any).pool;
      const vr=await pool.query(`select
        certificate_no as "certificateNo",verification_code as "verificationCode",
        document_type_code as "documentTypeCode",source_module_code as "sourceModuleCode",
        case_reference_no as "caseReferenceNo",verification_status as "verificationStatus",
        lifecycle_status as "lifecycleStatus",issue_date as "issueDate",valid_from as "validFrom",
        valid_until as "validUntil",issuer_public_name as "issuerPublicName",
        origin_country_code as "originCountryCode",destination_country_code as "destinationCountryCode",
        subject_summary as "subjectSummary",public_payload as "publicPayload",
        electronically_signed as "electronicallySigned",paper_fallback_allowed as "paperFallbackAllowed"
        from certification.verify_public_ecert($1)`,[q]);
      const safeRows=(vr.rows||[]).map((x:any)=>x.verificationStatus==='NOT_PUBLIC'
        ? {certificateNo:x.certificateNo,documentTypeCode:x.documentTypeCode,sourceModuleCode:x.sourceModuleCode,verificationStatus:'NOT_PUBLIC'}
        : x);
      try{
        const certNo=vr.rows?.[0]?.certificateNo||null;
        let ecertId:any=null;
        if(certNo){const er=await pool.query('select ecert_id from certification.ecert_document where certificate_no=$1 limit 1',[certNo]);ecertId=er.rows?.[0]?.ecert_id||null}
        await pool.query(`insert into certification.ecert_verification_event(ecert_id,query_kind,result_code)
          values($1,'PUBLIC_WEB',$2)`,[ecertId,vr.rows?.[0]?.verificationStatus||'NOT_FOUND']);
      }catch{}
      return sendJson(res,200,{data:safeRows,meta:{requestId:ids.requestId,source:'national-ecert'}},ids);
    }

    if(url.pathname==='/api/v1/public/search' && req.method==='GET'){
      const q=String(url.searchParams.get('q')||'').trim();const limit=Number(url.searchParams.get('limit')||60);
      if(q.length<2)return sendJson(res,200,{data:[],meta:{requestId:ids.requestId,query:q,minLength:2}},ids);
      const data=store.mode==='postgres'?await (store as any).publicSearch(q,limit):[];
      return sendJson(res,200,{data,meta:{requestId:ids.requestId,query:q}},ids);
    }
    const publicGuide=url.pathname.match(/^\/api\/v1\/public\/services\/([^/]+)$/);
    if(publicGuide && req.method==='GET'){
      const data=await guidedGuide(decodeURIComponent(publicGuide[1]));if(!data||data.service?.allowPublicBrowse===false)return sendJson(res,404,failure('SERVICE_NOT_FOUND','Service guide not found',ids),ids);return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/auth/login' && req.method==='POST'){
      const body=await readJson(req);
      let principal:any=null;
      if(authMode==='database'){
        if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Database authentication requires PostgreSQL mode',ids),ids);
        principal=await (store as any).authenticateAppUser(String(body.username||''),String(body.password||''));
      }else if(['demo','local'].includes(authMode)){
        principal=authenticateLocal(String(body.username||''),String(body.password||''));
      }else{
        return sendJson(res,501,failure('AUTH_PROVIDER_NOT_CONFIGURED','OIDC authentication adapter is not configured in this build',ids),ids);
      }
      if(!principal){
        try{await store.audit({actionCode:'auth.login_failed',resourceType:'security_session',correlationId:ids.correlationId,metadata:{username:String(body.username||'').slice(0,120)}})}catch{}
        return sendJson(res,401,failure('INVALID_CREDENTIALS','Invalid username or password',ids),ids);
      }
      const token=issueToken(principal.userId,principal.roles,28800,{username:principal.username,mustChangePassword:principal.mustChangePassword});
      try{await store.audit({actorUserId:principal.userId,actionCode:'auth.login_success',resourceType:'security_session',correlationId:ids.correlationId,metadata:{username:principal.username}})}catch{}
      return sendJson(res,200,{data:{token,tokenType:'Bearer',expiresIn:28800,user:{id:principal.userId,username:principal.username,roles:principal.roles,mustChangePassword:Boolean(principal.mustChangePassword)}},meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/auth/me' && req.method==='GET'){
      const principal=getPrincipal(req);
      if(!principal.isAuthenticated) return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      return sendJson(res,200,{data:{id:principal.userId,username:principal.username,roles:principal.roles,mustChangePassword:Boolean(principal.mustChangePassword)},meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/auth/change-password' && req.method==='POST'){
      const principal=getPrincipal(req);
      if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Password change requires PostgreSQL mode',ids),ids);
      const body=await readJson(req);const data=await (store as any).changeOwnPassword(principal.userId,String(body.currentPassword||''),String(body.newPassword||''));
      const token=issueToken(principal.userId,principal.roles,28800,{username:principal.username,mustChangePassword:false});
      await store.audit({actorUserId:principal.userId,actionCode:'auth.password_changed',resourceType:'security_user',resourceId:principal.userId,correlationId:ids.correlationId});
      return sendJson(res,200,{data:{...data,token,tokenType:'Bearer',expiresIn:28800},meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname.startsWith('/api/v1')){
      const apiPath=url.pathname.slice('/api/v1'.length)||'/';
      const principal=getPrincipal(req);const gate=authorize(principal,req.method||'GET',apiPath);
      if(!gate.ok){
        const status=gate.code==='UNAUTHENTICATED'?401:403;
        const message=gate.code==='PASSWORD_CHANGE_REQUIRED'?'Password change required before continuing':gate.code==='UNAUTHENTICATED'?'Authentication required':'Insufficient permission';
        return sendJson(res,status,failure(gate.code,message,ids),ids);
      }
    }

    if(url.pathname==='/api/v1/public/platform-settings' && req.method==='GET'){
      const data=store.mode==='postgres'?await (store as any).platformSettings(true):[];return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/admin/modules' && req.method==='GET'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      const data=store.mode==='postgres'?await (store as any).publicModuleCatalog(false):[];return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    const adminModule=url.pathname.match(/^\/api\/v1\/admin\/modules\/([^/]+)$/);
    if(adminModule && req.method==='PATCH'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Module administration requires PostgreSQL mode',ids),ids);
      const code=decodeURIComponent(adminModule[1]);const body=await readJson(req);const data=await (store as any).updateAdminModule(code,body);
      await store.audit({actorUserId:principal.userId,actionCode:'admin.module_catalog_update',resourceType:'module_catalog',correlationId:ids.correlationId,afterData:data,metadata:{moduleCode:code}});
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/admin/access-foundation' && req.method==='GET'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      const data=store.mode==='postgres'?await (store as any).adminAccessFoundation():{organizations:[],adminUnits:[],facilities:[],scopes:[],modules:[]};
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/admin/access-matrix' && req.method==='GET'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      const data=store.mode==='postgres'?await (store as any).adminAccessMatrix():[];return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/admin/organizations' && req.method==='POST'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Organization administration requires PostgreSQL mode',ids),ids);
      const body=await readJson(req);const data=await (store as any).createAdminOrganization(body);
      await store.audit({actorUserId:principal.userId,actionCode:'security.organization.create',resourceType:'organization',resourceId:data.id,correlationId:ids.correlationId,afterData:data});
      return sendJson(res,201,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/admin/access-scopes' && req.method==='POST'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Access scope administration requires PostgreSQL mode',ids),ids);
      const body=await readJson(req);const data=await (store as any).createAdminAccessScope(body);
      await store.audit({actorUserId:principal.userId,actionCode:'security.scope.create',resourceType:'access_scope',resourceId:data.id,correlationId:ids.correlationId,afterData:data});
      return sendJson(res,201,{data,meta:{requestId:ids.requestId}},ids);
    }
    const userAssignment=url.pathname.match(/^\/api\/v1\/admin\/users\/([^/]+)\/assignments$/);
    if(userAssignment && req.method==='POST'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Scoped role assignment requires PostgreSQL mode',ids),ids);
      const body=await readJson(req);const data=await (store as any).addAdminUserAssignment(decodeURIComponent(userAssignment[1]),body,principal.userId);
      await store.audit({actorUserId:principal.userId,actionCode:'security.user.scope_role_assign',resourceType:'security_user',resourceId:decodeURIComponent(userAssignment[1]),correlationId:ids.correlationId,afterData:body});
      return sendJson(res,201,{data,meta:{requestId:ids.requestId}},ids);
    }
    const assignmentUpdate=url.pathname.match(/^\/api\/v1\/admin\/user-assignments\/([^/]+)$/);
    if(assignmentUpdate && req.method==='PATCH'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Scoped role assignment requires PostgreSQL mode',ids),ids);
      const body=await readJson(req);if(String(body.status||'').toUpperCase()!=='INACTIVE')return sendJson(res,400,failure('INVALID_STATUS','Only INACTIVE is supported for assignment removal',ids),ids);
      const data=await (store as any).deactivateAdminUserAssignment(decodeURIComponent(assignmentUpdate[1]));
      await store.audit({actorUserId:principal.userId,actionCode:'security.user.scope_role_deactivate',resourceType:'user_role_assignment',resourceId:decodeURIComponent(assignmentUpdate[1]),correlationId:ids.correlationId});
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/admin/overview' && req.method==='GET'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      let data:any;if(store.mode==='postgres')data=await (store as any).adminOverview();else data={counts:{users:(await store.list('users')).length,roles:0,activeServices:(await guidedCatalog(false)).length,workflows:(await store.list('workflows')).length,openTasks:0,fieldCaptures:(await store.list('field_captures')).length,auditToday:(await store.auditEvents()).length},runtime:{ok:true,mode:store.mode}};
      data.releaseVersion=releaseVersion;data.authMode=authMode;return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/admin/users' && req.method==='GET'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      const data=store.mode==='postgres'?await (store as any).adminUsers():await store.list('users');return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/admin/users' && req.method==='POST'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','User administration requires PostgreSQL mode',ids),ids);
      const body=await readJson(req);const data=await (store as any).createAdminUser(body,principal.userId);
      await store.audit({actorUserId:principal.userId,actionCode:'security.user.create',resourceType:'security_user',resourceId:data.id,correlationId:ids.correlationId,afterData:{username:data.username,email:data.email,roles:data.roles}});
      return sendJson(res,201,{data,meta:{requestId:ids.requestId}},ids);
    }
    const adminUser=url.pathname.match(/^\/api\/v1\/admin\/users\/([^/]+)$/);
    if(adminUser && req.method==='PATCH'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','User administration requires PostgreSQL mode',ids),ids);
      const id=decodeURIComponent(adminUser[1]);const body=await readJson(req);const before=(await (store as any).adminUsers()).find((x:any)=>String(x.id)===id);const data=await (store as any).updateAdminUser(id,body);
      await store.audit({actorUserId:principal.userId,actionCode:'security.user.update',resourceType:'security_user',resourceId:id,correlationId:ids.correlationId,beforeData:before,afterData:data});
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    const adminUserPassword=url.pathname.match(/^\/api\/v1\/admin\/users\/([^/]+)\/password$/);
    if(adminUserPassword && req.method==='POST'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','User administration requires PostgreSQL mode',ids),ids);
      const id=decodeURIComponent(adminUserPassword[1]);const body=await readJson(req);const data=await (store as any).resetAdminUserPassword(id,String(body.password||''),body.mustChangePassword!==false);
      await store.audit({actorUserId:principal.userId,actionCode:'security.user.password_reset',resourceType:'security_user',resourceId:id,correlationId:ids.correlationId});
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    const adminUserRoles=url.pathname.match(/^\/api\/v1\/admin\/users\/([^/]+)\/roles$/);
    if(adminUserRoles && req.method==='PUT'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','User administration requires PostgreSQL mode',ids),ids);
      const id=decodeURIComponent(adminUserRoles[1]);const body=await readJson(req);const data=await (store as any).setAdminUserRoles(id,Array.isArray(body.roles)?body.roles:[],principal.userId);
      await store.audit({actorUserId:principal.userId,actionCode:'security.user.roles_update',resourceType:'security_user',resourceId:id,correlationId:ids.correlationId,afterData:{roles:body.roles||[]}});
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/admin/roles' && req.method==='GET'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      const data=store.mode==='postgres'?await (store as any).adminRoles():[];return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/admin/services' && req.method==='GET'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      const data=store.mode==='postgres'?await (store as any).adminServices():await guidedCatalog(false);return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    const adminService=url.pathname.match(/^\/api\/v1\/admin\/services\/([^/]+)$/);
    if(adminService && req.method==='PATCH'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Service administration requires PostgreSQL mode',ids),ids);
      const body=await readJson(req);const code=decodeURIComponent(adminService[1]);const before=(await (store as any).adminServices()).find((x:any)=>x.serviceCode===code);const data=await (store as any).updateAdminService(code,body);
      await store.audit({actorUserId:principal.userId,actionCode:'admin.service_config_update',resourceType:'service_definition',correlationId:ids.correlationId,beforeData:before,afterData:data,metadata:{serviceCode:code}});return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/admin/settings' && req.method==='GET'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      const data=store.mode==='postgres'?await (store as any).platformSettings(false):[];return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    const adminSetting=url.pathname.match(/^\/api\/v1\/admin\/settings\/([^/]+)$/);
    if(adminSetting && req.method==='PATCH'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Platform settings require PostgreSQL mode',ids),ids);
      const body=await readJson(req);const code=decodeURIComponent(adminSetting[1]);const data=await (store as any).updatePlatformSetting(code,body.value,principal.userId);
      await store.audit({actorUserId:principal.userId,actionCode:'admin.platform_setting_update',resourceType:'platform_setting',correlationId:ids.correlationId,afterData:data,metadata:{settingCode:code}});return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/admin/audit' && req.method==='GET'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);return sendJson(res,200,{data:await store.auditEvents(),meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/admin/field-captures' && req.method==='GET'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);
      const data=store.mode==='postgres'?await (store as any).fieldCaptures():await store.list('field_captures');return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/field-captures/sync' && req.method==='POST'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);const body=await readJson(req);const items=Array.isArray(body.items)?body.items:[body];if(items.length>100)return sendJson(res,413,failure('TOO_MANY_ITEMS','Maximum 100 field captures per sync request',ids),ids);
      const saved=[] as any[];for(const item of items){const row=store.mode==='postgres'?await (store as any).fieldCaptureSync(principal.userId,item):await store.create('field_captures',{...item,submittedBySubject:principal.userId,syncStatus:'RECEIVED',receivedAt:new Date().toISOString()});saved.push(row)}
      await store.audit({actorUserId:principal.userId,actionCode:'field.capture_sync',resourceType:'field_capture_draft',correlationId:ids.correlationId,afterData:{count:saved.length}});return sendJson(res,201,{data:{saved,count:saved.length},meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/audit-events'){const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);return sendJson(res,200,{data:await store.auditEvents(),meta:{requestId:ids.requestId}},ids);}
    if(url.pathname==='/api/v1/outbox-events'){const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);return sendJson(res,200,{data:await store.outboxEvents(),meta:{requestId:ids.requestId}},ids);}
    if(url.pathname==='/api/v1/meta'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const resources=['companies','facilities','applications','products','drug_registrations','veterinary_devices','import_plans','import_applications','inspections','laboratory_samples','disease_cases','trade_shipments','licenses','certificates','provincial_reports'];
      const counts:any={}; for(const r of resources) counts[r]=(await store.list(r)).length;
      return sendJson(res,200,{data:{counts,storageMode:store.mode,authMode,apiVersion:'v1',releaseVersion},meta:{requestId:ids.requestId}},ids);
    }

    if(url.pathname==='/api/v1/reporting/config' && req.method==='GET'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Provincial reporting requires PostgreSQL mode',ids),ids);
      const data=await (store as any).reportingConfig();return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/reporting/dashboard' && req.method==='GET'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Provincial reporting requires PostgreSQL mode',ids),ids);
      const now=new Date();const year=Number(url.searchParams.get('year')||now.getFullYear());const month=Number(url.searchParams.get('month')||(now.getMonth()+1));const data=await (store as any).reportingDashboard(year,month,principal.userId,isAdminPrincipal(principal));return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/reporting/monthly-summary' && req.method==='GET'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Provincial reporting requires PostgreSQL mode',ids),ids);
      const now=new Date();const year=Number(url.searchParams.get('year')||now.getFullYear());const month=Number(url.searchParams.get('month')||(now.getMonth()+1));if(month<1||month>12)return sendJson(res,400,failure('INVALID_MONTH','month must be 1-12',ids),ids);const data=await (store as any).reportingMonthlySummary(year,month,principal.userId,isAdminPrincipal(principal));return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/reporting/submissions' && req.method==='GET'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Provincial reporting requires PostgreSQL mode',ids),ids);
      const data=await (store as any).reportingSubmissions({year:url.searchParams.get('year')||undefined,month:url.searchParams.get('month')||undefined,provinceCode:url.searchParams.get('provinceCode')||undefined,status:url.searchParams.get('status')||undefined},principal.userId,isAdminPrincipal(principal));return sendJson(res,200,{data,meta:{requestId:ids.requestId,total:data.length}},ids);
    }
    if(url.pathname==='/api/v1/reporting/submissions' && req.method==='POST'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Provincial reporting requires PostgreSQL mode',ids),ids);const body=await readJson(req);
      const data=await (store as any).createReportingSubmission(body,principal.userId,isAdminPrincipal(principal));await store.audit({actorUserId:principal.userId,actionCode:'reporting.submission.create',resourceType:'provincial_report',resourceId:data.id,correlationId:ids.correlationId,afterData:data});return sendJson(res,201,{data,meta:{requestId:ids.requestId}},ids);
    }
    const reportingSubmission=url.pathname.match(/^\/api\/v1\/reporting\/submissions\/([^/]+)$/);
    if(reportingSubmission && req.method==='GET'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Provincial reporting requires PostgreSQL mode',ids),ids);const data=await (store as any).reportingSubmissionComplete(decodeURIComponent(reportingSubmission[1]),principal.userId,isAdminPrincipal(principal));return data?sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids):sendJson(res,404,failure('REPORT_NOT_FOUND','Report not found',ids),ids);
    }
    if(reportingSubmission && req.method==='PATCH'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Provincial reporting requires PostgreSQL mode',ids),ids);const id=decodeURIComponent(reportingSubmission[1]);const before=await (store as any).reportingSubmissionComplete(id,principal.userId,isAdminPrincipal(principal));const body=await readJson(req);const data=await (store as any).updateReportingSubmission(id,body,principal.userId,isAdminPrincipal(principal));await store.audit({actorUserId:principal.userId,actionCode:'reporting.submission.update',resourceType:'provincial_report',resourceId:id,correlationId:ids.correlationId,beforeData:before?.report,afterData:data});return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    const reportingIndicators=url.pathname.match(/^\/api\/v1\/reporting\/submissions\/([^/]+)\/indicators$/);
    if(reportingIndicators && req.method==='POST'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Provincial reporting requires PostgreSQL mode',ids),ids);const id=decodeURIComponent(reportingIndicators[1]);const body=await readJson(req);const rows=Array.isArray(body.rows)?body.rows:[];const data=await (store as any).upsertReportingIndicators(id,rows,principal.userId,isAdminPrincipal(principal));await store.audit({actorUserId:principal.userId,actionCode:'reporting.indicators.save',resourceType:'provincial_report',resourceId:id,correlationId:ids.correlationId,afterData:{count:rows.length}});return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    const reportingTrade=url.pathname.match(/^\/api\/v1\/reporting\/submissions\/([^/]+)\/trade-stats$/);
    if(reportingTrade && req.method==='POST'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Provincial reporting requires PostgreSQL mode',ids),ids);const id=decodeURIComponent(reportingTrade[1]);const body=await readJson(req);const data=await (store as any).createReportingTradeStat(id,body,principal.userId,isAdminPrincipal(principal));await store.audit({actorUserId:principal.userId,actionCode:'reporting.trade_stat.create',resourceType:'provincial_report',resourceId:id,correlationId:ids.correlationId,afterData:data});return sendJson(res,201,{data,meta:{requestId:ids.requestId}},ids);
    }
    const reportingNotes=url.pathname.match(/^\/api\/v1\/reporting\/submissions\/([^/]+)\/notes$/);
    if(reportingNotes && req.method==='POST'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Provincial reporting requires PostgreSQL mode',ids),ids);const id=decodeURIComponent(reportingNotes[1]);const body=await readJson(req);const data=await (store as any).addReportingActivityNote(id,body,principal.userId,isAdminPrincipal(principal));await store.audit({actorUserId:principal.userId,actionCode:'reporting.note.create',resourceType:'provincial_report',resourceId:id,correlationId:ids.correlationId,afterData:data});return sendJson(res,201,{data,meta:{requestId:ids.requestId}},ids);
    }
    const reportingStatus=url.pathname.match(/^\/api\/v1\/reporting\/submissions\/([^/]+)\/status$/);
    if(reportingStatus && req.method==='POST'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Provincial reporting requires PostgreSQL mode',ids),ids);const id=decodeURIComponent(reportingStatus[1]);const body=await readJson(req);const requestedStatus=String(body.status||'').toUpperCase();if(requestedStatus==='VERIFIED'&&!canVerifyReporting(principal))return sendJson(res,403,failure('FORBIDDEN','Technical reviewer or management role required to verify provincial reporting data',ids),ids);const before=await (store as any).reportingSubmissionComplete(id,principal.userId,isAdminPrincipal(principal));const data=await (store as any).setReportingStatus(id,requestedStatus,principal.userId,isAdminPrincipal(principal));await store.audit({actorUserId:principal.userId,actionCode:'reporting.status.change',resourceType:'provincial_report',resourceId:id,correlationId:ids.correlationId,beforeData:before?.report,afterData:data});return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    const reportingAssignment=url.pathname.match(/^\/api\/v1\/reporting\/regions\/([^/]+)\/assignment$/);
    if(reportingAssignment && req.method==='PUT'){
      const principal=getPrincipal(req);if(!isAdminPrincipal(principal))return sendJson(res,403,failure('FORBIDDEN','System administrator role required',ids),ids);if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Provincial reporting requires PostgreSQL mode',ids),ids);const body=await readJson(req);const regionCode=decodeURIComponent(reportingAssignment[1]);const data=await (store as any).upsertReportingRegionAssignment(regionCode,body,principal.userId);await store.audit({actorUserId:principal.userId,actionCode:'reporting.assignment.update',resourceType:'reporting_region',correlationId:ids.correlationId,afterData:data,metadata:{regionCode}});return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }

    if(url.pathname==='/api/v1/guided-services' && req.method==='GET'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      return sendJson(res,200,{data:await guidedCatalog(false),meta:{requestId:ids.requestId}},ids);
    }
    const guidedService=url.pathname.match(/^\/api\/v1\/guided-services\/([^/]+)$/);
    if(guidedService && req.method==='GET'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const data=await guidedGuide(decodeURIComponent(guidedService[1]));return data?sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids):sendJson(res,404,failure('SERVICE_NOT_FOUND','Service guide not found',ids),ids);
    }
    if(url.pathname==='/api/v1/service-drafts' && req.method==='GET'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      return sendJson(res,200,{data:await listGuidedDrafts(principal.userId,isAdminPrincipal(principal)),meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/service-drafts' && req.method==='POST'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const body=await readJson(req);const code=String(body.serviceCode||'').trim();if(!code)return sendJson(res,400,failure('SERVICE_CODE_REQUIRED','serviceCode is required',ids),ids);
      const data=await createGuidedDraft(code,principal.userId,body);await store.audit({actorUserId:principal.userId,actionCode:'guided_service.start',resourceType:'service_draft',resourceId:data?.draft?.id,correlationId:ids.correlationId,afterData:{serviceCode:code}});return sendJson(res,201,{data,meta:{requestId:ids.requestId}},ids);
    }
    const serviceDraft=url.pathname.match(/^\/api\/v1\/service-drafts\/([^/]+)$/);
    if(serviceDraft && req.method==='GET'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const data=await getGuidedDraft(decodeURIComponent(serviceDraft[1]),principal.userId,isAdminPrincipal(principal));return data?sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids):sendJson(res,404,failure('SERVICE_DRAFT_NOT_FOUND','Service draft not found',ids),ids);
    }
    if(serviceDraft && req.method==='PATCH'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const body=await readJson(req);const id=decodeURIComponent(serviceDraft[1]);const data=await saveGuidedDraftStep(id,principal.userId,body,isAdminPrincipal(principal));await store.audit({actorUserId:principal.userId,actionCode:'guided_service.step_save',resourceType:'service_draft',resourceId:id,correlationId:ids.correlationId,afterData:{stepCode:body.stepCode,completed:body.completed!==false}});return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    const serviceDraftLink=url.pathname.match(/^\/api\/v1\/service-drafts\/([^/]+)\/link$/);
    if(serviceDraftLink && req.method==='POST'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const body=await readJson(req);if(!body.targetResource||!body.targetId)return sendJson(res,400,failure('TARGET_REQUIRED','targetResource and targetId are required',ids),ids);const id=decodeURIComponent(serviceDraftLink[1]);const data=await linkGuidedDraft(id,principal.userId,String(body.targetResource),String(body.targetId),isAdminPrincipal(principal));await store.audit({actorUserId:principal.userId,actionCode:'guided_service.link_domain_record',resourceType:'service_draft',resourceId:id,correlationId:ids.correlationId,afterData:{targetResource:body.targetResource,targetId:body.targetId}});return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/my-work' && req.method==='GET'){
      const principal=getPrincipal(req);if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);const data=await getMyWork(principal.userId,isAdminPrincipal(principal));return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }

    if(url.pathname==='/api/v1/company-role-types' && req.method==='GET'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const data=store.mode==='postgres'?await (store as any).companyRoleTypes():[]; return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    const companyRoles=url.pathname.match(/^\/api\/v1\/companies\/([^/]+)\/roles$/);
    if(companyRoles && req.method==='PUT'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const companyId=decodeURIComponent(companyRoles[1]);const before=await (store as any).companyComplete(companyId);const body=await readJson(req);const data=await (store as any).setCompanyRoles(companyId,Array.isArray(body.roleCodes)?body.roleCodes:[]);
      await store.audit({actorUserId:principal.userId,actionCode:'company.roles_update',resourceType:'company',resourceId:companyId,correlationId:ids.correlationId,beforeData:before?.roles,afterData:data?.roles});return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/countries' && req.method==='GET'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const data=store.mode==='postgres'?await (store as any).countries():[]; return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    const companyDetail=url.pathname.match(/^\/api\/v1\/companies\/([^/]+)\/complete$/);
    if(companyDetail && req.method==='GET'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Company multi-site view requires PostgreSQL mode',ids),ids);
      const data=await (store as any).companyComplete(decodeURIComponent(companyDetail[1]));
      return data?sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids):sendJson(res,404,failure('NOT_FOUND','Company not found',ids),ids);
    }
    const companyBase=url.pathname.match(/^\/api\/v1\/companies\/([^/]+)$/);
    if(companyBase && req.method==='PATCH'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const id=decodeURIComponent(companyBase[1]); const before=await store.get('companies',id); if(!before)return sendJson(res,404,failure('NOT_FOUND','Company not found',ids),ids);
      const body=await readJson(req); const data=await store.update('companies',id,body);
      await store.audit({actorUserId:principal.userId,actionCode:'company.update',resourceType:'company',resourceId:id,correlationId:ids.correlationId,beforeData:before,afterData:data});
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/company-sites' && req.method==='GET'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Company sites require PostgreSQL mode',ids),ids);
      const data=await (store as any).companySites(url.searchParams.get('companyId')||undefined);
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    const companySitesCreate=url.pathname.match(/^\/api\/v1\/companies\/([^/]+)\/sites$/);
    if(companySitesCreate && req.method==='POST'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const companyId=decodeURIComponent(companySitesCreate[1]); const body=await readJson(req); const data=await (store as any).createCompanySite(companyId,body);
      await store.audit({actorUserId:principal.userId,actionCode:'company.site_create',resourceType:'company',resourceId:companyId,correlationId:ids.correlationId,afterData:data});
      return sendJson(res,201,{data,meta:{requestId:ids.requestId}},ids);
    }
    const companySiteUpdate=url.pathname.match(/^\/api\/v1\/company-sites\/([^/]+)$/);
    if(companySiteUpdate && req.method==='PATCH'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const body=await readJson(req); const data=await (store as any).updateCompanySite(decodeURIComponent(companySiteUpdate[1]),body);
      await store.audit({actorUserId:principal.userId,actionCode:'company.site_update',resourceType:'company_site',resourceId:decodeURIComponent(companySiteUpdate[1]),correlationId:ids.correlationId,afterData:data});
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    const companyRegCreate=url.pathname.match(/^\/api\/v1\/companies\/([^/]+)\/registrations$/);
    if(companyRegCreate && req.method==='POST'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const companyId=decodeURIComponent(companyRegCreate[1]); const body=await readJson(req); if(!body.registrationNo)return sendJson(res,400,failure('REGISTRATION_NO_REQUIRED','Registration/licence number is required',ids),ids);
      const data=await (store as any).createCompanyExternalRegistration(companyId,body);
      await store.audit({actorUserId:principal.userId,actionCode:'company.external_registration_create',resourceType:'company',resourceId:companyId,correlationId:ids.correlationId,afterData:data});
      return sendJson(res,201,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/company-duplicate-candidates' && req.method==='GET'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const data=store.mode==='postgres'?await (store as any).companyDuplicateCandidates():[];
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }

    if(url.pathname==='/api/v1/veterinary-drug-reference-data' && req.method==='GET'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const data=store.mode==='postgres'?await (store as any).veterinaryDrugReferenceData():vetDrugReferenceFallback;
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/drug-registrations/next-number' && req.method==='GET'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const registrationType=String(url.searchParams.get('registrationType')||'IMPORT').toUpperCase();
      if(store.mode!=='postgres'){
        const pref=registrationType==='DOMESTIC'?'L':registrationType==='REPACK'?'R':'F';const d=new Date();const ym=String(d.getUTCFullYear())+String(d.getUTCMonth()+1).padStart(2,'0');
        return sendJson(res,200,{data:{registrationType,prefix:pref,registrationNo:`ຢສ-${pref}-${ym}-PREVIEW`,preview:true},meta:{requestId:ids.requestId}},ids);
      }
      const data=await (store as any).previewDrugRegistrationNo(registrationType);return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }

    const drugDetail=url.pathname.match(/^\/api\/v1\/drug-registrations\/([^/]+)\/complete$/);
    if(drugDetail && req.method==='GET'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Detailed print view requires PostgreSQL mode',ids),ids);
      const data=await (store as any).drugRegistrationComplete(decodeURIComponent(drugDetail[1]));
      return data?sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids):sendJson(res,404,failure('NOT_FOUND','Drug registration not found',ids),ids);
    }
    if(drugDetail && req.method==='PATCH'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Detailed update requires PostgreSQL mode',ids),ids);
      const before=await (store as any).drugRegistrationComplete(decodeURIComponent(drugDetail[1]));
      if(!before)return sendJson(res,404,failure('NOT_FOUND','Drug registration not found',ids),ids);
      const body=await readJson(req); const data=await (store as any).updateDrugRegistrationComplete(decodeURIComponent(drugDetail[1]),body);
      await store.audit({actorUserId:principal.userId,actionCode:'drug_registration.complete_update',resourceType:'drug_registration',resourceId:decodeURIComponent(drugDetail[1]),correlationId:ids.correlationId,beforeData:before,afterData:data});
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    const annualPlanProfile=url.pathname.match(/^\/api\/v1\/import-plans\/([^/]+)\/profile$/);
    if(annualPlanProfile && (req.method==='GET'||req.method==='PUT')){
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Annual Trade Plan profile requires PostgreSQL mode',ids),ids);
      const planId=decodeURIComponent(annualPlanProfile[1]);
      if(!/^[0-9a-fA-F-]{36}$/.test(planId))return sendJson(res,400,failure('INVALID_PLAN_ID','Invalid annual plan id',ids),ids);
      const pool=(store as any).pool;
      if(req.method==='GET'){
        const rr=await pool.query(`select p.*,s.name_lo service_name_lo,s.name_en service_name_en,
          s.annual_plan_required,s.allowed_movements,s.configuration_status service_configuration_status
          from trade.import_plan_profile p
          left join trade.annual_plan_service_type s on s.service_type=p.service_type
          where p.import_plan_id=$1`,[planId]);
        return rr.rowCount?sendJson(res,200,{data:rr.rows[0],meta:{requestId:ids.requestId}},ids):sendJson(res,404,failure('NOT_FOUND','Annual Trade Plan profile not found',ids),ids);
      }
      const body=await readJson(req);
      const movementType=String(body.movementType||'IMPORT').toUpperCase();
      const serviceType=String(body.serviceType||'VET_DRUG_DEVICE').toUpperCase();
      const detailLevel=String(body.detailLevel||'ITEM').toUpperCase();
      if(!['IMPORT','EXPORT','TRANSIT','RE_EXPORT'].includes(movementType))return sendJson(res,400,failure('INVALID_MOVEMENT_TYPE','Invalid annual-plan movement type',ids),ids);
      if(!['ITEM','CATEGORY','HYBRID'].includes(detailLevel))return sendJson(res,400,failure('INVALID_DETAIL_LEVEL','Invalid annual-plan detail level',ids),ids);
      const sr=await pool.query('select * from trade.annual_plan_service_type where service_type=$1',[serviceType]);
      if(!sr.rowCount)return sendJson(res,400,failure('INVALID_SERVICE_TYPE','Unknown Annual Trade Plan service type',ids),ids);
      const allowed=Array.isArray(sr.rows[0].allowed_movements)?sr.rows[0].allowed_movements:[];
      if(!allowed.includes(movementType))return sendJson(res,400,failure('MOVEMENT_NOT_ALLOWED','Movement type is not configured for this Annual Trade Plan work area',ids),ids);
      const client=await pool.connect();let before:any=null,after:any=null;
      try{
        await client.query('begin');
        const pr=await client.query('select id from trade.import_plan where id=$1 for update',[planId]);
        if(!pr.rowCount){await client.query('rollback');return sendJson(res,404,failure('NOT_FOUND','Annual plan not found',ids),ids)}
        const br=await client.query('select * from trade.import_plan_profile where import_plan_id=$1 for update',[planId]);before=br.rows[0]||null;
        await client.query(`insert into trade.import_plan_profile(import_plan_id,detail_level,movement_type,service_type,notes)
          values($1,$2,$3,$4,$5)
          on conflict(import_plan_id) do update set detail_level=excluded.detail_level,movement_type=excluded.movement_type,
          service_type=excluded.service_type,notes=coalesce(excluded.notes,trade.import_plan_profile.notes),updated_at=now()`,
          [planId,detailLevel,movementType,serviceType,body.notes||null]);
        const ar=await client.query('select * from trade.import_plan_profile where import_plan_id=$1',[planId]);after=ar.rows[0];
        await client.query('commit');
      }catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
      await store.audit({actorUserId:getPrincipal(req).userId,actionCode:'annual_trade_plan.profile.update',resourceType:'import_plan',resourceId:planId,correlationId:ids.correlationId,beforeData:before,afterData:after});
      return sendJson(res,200,{data:after,meta:{requestId:ids.requestId}},ids);
    }

    const planDetail=url.pathname.match(/^\/api\/v1\/import-plans\/([^/]+)\/complete$/);
    if(planDetail && req.method==='GET'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Detailed annual-plan view requires PostgreSQL mode',ids),ids);
      const data=await (store as any).importPlanComplete(decodeURIComponent(planDetail[1]));
      return data?sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids):sendJson(res,404,failure('NOT_FOUND','Annual import plan not found',ids),ids);
    }
    const importDetail=url.pathname.match(/^\/api\/v1\/import-applications\/([^/]+)\/complete$/);
    if(importDetail && req.method==='GET'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Detailed print view requires PostgreSQL mode',ids),ids);
      const data=await (store as any).importApplicationComplete(decodeURIComponent(importDetail[1]));
      return data?sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids):sendJson(res,404,failure('NOT_FOUND','Import application not found',ids),ids);
    }
    if(url.pathname==='/api/v1/species' && req.method==='GET'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const data=store.mode==='postgres'?await (store as any).species():[]; return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/units' && req.method==='GET'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const data=store.mode==='postgres'?await (store as any).unitsOfMeasure():[]; return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/export-applications' && req.method==='POST'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Export applications require PostgreSQL mode',ids),ids);
      const body=await readJson(req); const data=await (store as any).createExportApplication(body,principal.userId);
      await store.audit({actorUserId:principal.userId,actionCode:'export_application.submit',resourceType:'export_application',resourceId:data?.application?.id,correlationId:ids.correlationId,afterData:{caseNo:data?.application?.caseNo}});
      return sendJson(res,201,{data,meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/export-applications' && req.method==='GET'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const data=store.mode==='postgres'?await (store as any).exportApplications():[]; return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }
    const exportDetail=url.pathname.match(/^\/api\/v1\/export-applications\/([^/]+)\/complete$/);
    if(exportDetail && req.method==='GET'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','Detailed export view requires PostgreSQL mode',ids),ids);
      const data=await (store as any).exportApplicationComplete(decodeURIComponent(exportDetail[1]));
      return data?sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids):sendJson(res,404,failure('NOT_FOUND','Export application not found',ids),ids);
    }
    if(url.pathname==='/api/v1/animuse/summary' && req.method==='GET'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      if(store.mode!=='postgres')return sendJson(res,501,failure('POSTGRES_REQUIRED','ANIMUSE summary requires PostgreSQL mode',ids),ids);
      const y=Number(url.searchParams.get('year')||0)||undefined; const data=await (store as any).animuseSummary(y);
      return sendJson(res,200,{data,meta:{requestId:ids.requestId}},ids);
    }

    if(url.pathname==='/api/v1/drug-registrations/complete' && req.method==='POST'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const body=await readJson(req); let profile=body.profile||{}; if(store.mode==='postgres'){profile=await (store as any).prepareDrugRegulatoryProfile(profile,{create:true});profile=await (store as any).normalizeDrugPartyLinks(profile);} const presentations=Array.isArray(body.presentations)?body.presentations:[];
      if(!profile.tradeName||!presentations.length)return sendJson(res,400,failure('INVALID_DRUG_REGISTRATION','Trade name and at least one presentation are required',ids),ids);
      const product=await store.create('products',{tradeName:profile.tradeName,genericName:profile.genericName||null,productCode:profile.registrationNo||undefined,productTypeCode:'VETERINARY_PHARMACEUTICAL',lifecycleStatus:String(profile.registrationStatus||'DRAFT').toUpperCase()==='ACTIVE'?'ACTIVE':'DRAFT'});
      const reg=await store.create('drug_registrations',{...profile,productId:product.id});
      const createdPresentations=[];
      for(let i=0;i<presentations.length;i++){const p=presentations[i]||{};const pkg=await store.create('product_packages',{productId:product.id,packageCode:(profile.registrationNo?profile.registrationNo+'-':'')+(p.subCode||String(i+1).padStart(2,'0')),subCode:p.subCode||String(i+1).padStart(2,'0'),status:'ACTIVE',presentationStatus:'ACTIVE'});const pv=await store.create('package_versions',{packageId:pkg.id,versionNo:1,packDescription:p.packDescription||null,containerType:p.containerType||null,status:'ACTIVE',strengthText:p.strengthText||null,basisText:p.basisText||null,targetText:p.targetText||null,totalWeightText:p.totalWeightText||null,isKit:!!p.isKit});for(let j=0;j<(p.composition||[]).length;j++){const c=p.composition[j];if(!c.ingredientName)continue;await store.create('package_compositions',{packageVersionId:pv.id,sequenceNo:j+1,ingredientName:c.ingredientName,ingredientRole:c.ingredientRole||'ACTIVE',quantityText:c.quantityText||null,unitText:c.unitText||null,partText:c.partText||null,equivalenceText:c.equivalenceText||null})}createdPresentations.push({package:pkg,version:pv})}
      await store.audit({actorUserId:principal.userId,actionCode:'drug_registration.complete_create',resourceType:'drug_registration',resourceId:reg.id,correlationId:ids.correlationId,afterData:{registration:reg,presentations:createdPresentations.length}});
      return sendJson(res,201,{data:{product,registration:reg,presentations:createdPresentations},meta:{requestId:ids.requestId}},ids);
    }

    if(url.pathname==='/api/v1/bulk-import/preview' && req.method==='POST'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const body=await readJson(req); const target=body.target==='application'?'application':'plan'; const parsed=parseSpreadsheet(String(body.dataBase64||''),String(body.filename||'upload.xlsx'));
      let context:any={}; if(target==='application'&&body.parentId){const parent=await store.get('import_applications',String(body.parentId));context={planId:parent?.planId||null};}
      const rows=await enrichRows(store,parsed.rows,target,context);
      const summary={total:rows.length,valid:rows.filter(x=>x.validationStatus==='VALID').length,warnings:rows.filter(x=>x.validationStatus==='WARNING').length,errors:rows.filter(x=>x.validationStatus==='ERROR').length,planMatched:rows.filter(x=>x.planItemId).length,planUnmatched:target==='application'?rows.filter(x=>!x.planItemId).length:0};
      return sendJson(res,200,{data:{...parsed,rows,summary},meta:{requestId:ids.requestId}},ids);
    }
    if(url.pathname==='/api/v1/bulk-import/commit' && req.method==='POST'){
      const principal=getPrincipal(req); if(!principal.isAuthenticated)return sendJson(res,401,failure('UNAUTHENTICATED','Authentication required',ids),ids);
      const body=await readJson(req); const target=body.target==='application'?'application':'plan'; const parentId=String(body.parentId||''); if(!parentId)return sendJson(res,400,failure('PARENT_REQUIRED','Select a plan/application first',ids),ids);
      const parsed=parseSpreadsheet(String(body.dataBase64||''),String(body.filename||'upload.xlsx')); const parent=target==='application'?await store.get('import_applications',parentId):null; const rows=await enrichRows(store,parsed.rows,target,{planId:parent?.planId||null});
      if(rows.some(x=>x.validationStatus==='ERROR'))return sendJson(res,422,{error:{code:'BULK_VALIDATION_FAILED',message:'Spreadsheet contains validation errors',rows},meta:{requestId:ids.requestId}},ids);
      const existing=target==='plan'?await store.list('import_plan_items'):await store.list('import_application_items'); const start=existing.filter((x:any)=>String(target==='plan'?x.planId:x.applicationId)===parentId).length;
      const created=[]; for(let i=0;i<rows.length;i++){const r=rows[i]; const common={itemNo:start+i+1,itemType:r.itemType,itemName:r.itemName||r.itemNameEn,registrationNo:r.registrationNo||null,packageDescription:r.packageDescription||null,productId:r.productId,deviceId:r.deviceId,packageId:r.packageId||null,unitCode:r.unitCode||null,manufacturerName:r.manufacturerName||null,manufacturerCountry:r.manufacturerCountry||null,sourceFileName:parsed.filename,sourceRowNo:r.rowNo,sourcePayload:r.raw,validationStatus:r.validationStatus,validationMessage:[...(r.errors||[]),...(r.warnings||[])].join('; ')||null};
        const input=target==='plan'?{...common,planId:parentId,lineMode:r.lineMode||'ITEM',plannedItemCount:r.plannedItemCount??null,plannedQuantity:r.quantity,plannedValue:r.value||null,currencyCode:r.currencyCode}:{...common,applicationId:parentId,planItemId:r.planItemId||null,requestedQuantity:r.quantity,approvedQuantity:r.quantityMeaning==='APPROVED'?r.quantity:null,itemValue:r.value||null,currencyCode:r.currencyCode,batchLotNo:r.batchLotNo||null,manufactureDate:r.manufactureDate||null,expiryDate:r.expiryDate||null,eligibilityStatus:r.eligibilityStatus,eligibilityMessage:r.eligibilityMessage};
        const rec=await store.create(target==='plan'?'import_plan_items':'import_application_items',input);
        if(target==='plan'&&store.mode==='postgres'&&rec?.id){await (store as any).pool.query(`insert into trade.import_plan_item_profile(plan_item_id,scope_type,category_code,planned_value_usd,planned_item_count,tracking_basis,count_is_reference,allow_item_mapping)
          values($1,$2,$3,$4,$5,$6,true,true)
          on conflict(plan_item_id) do update set scope_type=excluded.scope_type,category_code=excluded.category_code,planned_value_usd=excluded.planned_value_usd,planned_item_count=excluded.planned_item_count,tracking_basis=excluded.tracking_basis,updated_at=now()`,
          [rec.id,r.lineMode==='SUMMARY_GROUP'?'CATEGORY':'ITEM',r.sourceCategory||null,r.plannedValueUsd??r.value??null,r.plannedItemCount??null,r.trackingBasis||'QUANTITY']);}
        created.push(rec);
      }
      await store.audit({actorUserId:principal.userId,actionCode:`bulk_import.${target}`,resourceType:target==='plan'?'import_plan':'import_application',resourceId:parentId,correlationId:ids.correlationId,afterData:{filename:parsed.filename,count:created.length}});
      return sendJson(res,201,{data:{created:created.length,rows},meta:{requestId:ids.requestId}},ids);
    }

    const vetDrugOperational=await handleVetDrugOperationalApi({
      req,url,store,principal:getPrincipal(req),ids,readJson
    });
    if(vetDrugOperational) return sendJson(res,vetDrugOperational.status,vetDrugOperational.body,ids);

    const legacyParity=await handleLegacyParityApi({
      req,url,store,principal:getPrincipal(req),ids,readJson
    });
    if(legacyParity) return sendJson(res,legacyParity.status,legacyParity.body,ids);

    if(url.pathname.startsWith('/api/v1') || url.pathname==='/health' || url.pathname==='/ready'){
      const apiPath=url.pathname.startsWith('/api/v1') ? (url.pathname.slice('/api/v1'.length)||'/') : url.pathname;
      const route=routes.find(r=>r.method===(req.method||'GET') && r.regex.test(apiPath));
      if(!route) return sendJson(res,404,failure('ROUTE_NOT_FOUND','API route not found',ids),ids);
      const match=apiPath.match(route.regex); const params:any={}; route.names.forEach((n:string,i:number)=>params[n]=decodeURIComponent(match[i+1]));
      const principal=getPrincipal(req); const auth=authorize(principal,req.method||'GET',apiPath);
      if(!auth.ok) return sendJson(res,auth.code==='UNAUTHENTICATED'?401:403,failure(auth.code,auth.code==='UNAUTHENTICATED'?'Authentication required':'Insufficient permission',ids),ids);
      const body=(req.method==='POST'||req.method==='PUT'||req.method==='PATCH') ? await readJson(req) : {};
      const result=await executeRoute({route,params,method:req.method,apiPath,body,store,url,principal,ids});
      return sendJson(res,result.status,result.body,ids);
    }

    if(url.pathname==='/field'||url.pathname.startsWith('/field/')){
      let rel=url.pathname==='/field'||url.pathname==='/field/'?'index.html':url.pathname.slice('/field/'.length);
      if(rel.includes('..')) return sendJson(res,400,failure('INVALID_PATH','Invalid path',ids),ids);
      const candidate=path.join(fieldRoot,rel);if(staticFile(res,candidate))return;
      return staticFile(res,path.join(fieldRoot,'index.html')) || sendJson(res,404,failure('NOT_FOUND','Field app not found',ids),ids);
    }
    let rel=url.pathname==='/'?'index.html':url.pathname.slice(1);
    if(rel.includes('..')) return sendJson(res,400,failure('INVALID_PATH','Invalid path',ids),ids);
    const candidate=path.join(webRoot,rel);
    if(staticFile(res,candidate)) return;
    return staticFile(res,path.join(webRoot,'index.html')) || sendJson(res,404,failure('NOT_FOUND','Not found',ids),ids);
  }catch(e:any){
    if(!e.statusCode || e.statusCode>=500) console.error(e);
    return sendJson(res,e.statusCode||500,failure(e.code||'INTERNAL_ERROR',e.statusCode?e.message:'Unexpected server error',ids),ids);
  }
});

if(process.env.NODE_ENV!=='test' && process.env.VERCEL!=='1'){
  server.listen(port,()=>console.log(`LVSP running at http://localhost:${port}`));
}
export {server,store};
