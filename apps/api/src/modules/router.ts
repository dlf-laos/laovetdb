// Generic modular API execution layer generated around the approved LVSP OpenAPI contract.
// @ts-nocheck
import crypto from 'node:crypto';
import { assertCommandAllowed } from '../core/state-machine.js';
import { applyDevelopmentNumber } from '../core/numbering.js';

const ACTION_STATUS:any = {
  submit:'SUBMITTED', withdraw:'WITHDRAWN', assign:'ASSIGNED', 'complete-review':'REVIEW_COMPLETED',
  renew:'RENEWAL_REQUESTED', vary:'VARIATION_REQUESTED', amend:'AMENDMENT_REQUESTED', suspend:'SUSPENDED', restore:'ACTIVE', revoke:'REVOKED',
  complete:'COMPLETED', validate:'VALIDATED', approve:'APPROVED', authorize:'AUTHORIZED', depart:'IN_TRANSIT', arrive:'ARRIVED',
  confirm:'CONFIRMED', close:'CLOSED', declare:'DECLARED', 'risk-assess':'RISK_ASSESSED', inspection:'INSPECTION_REQUIRED', quarantine:'QUARANTINED', clearance:'CLEARED',
  submit_capa:'SUBMITTED', verify:'VERIFIED', harvest:'HARVESTED', production:'PRODUCTION_RECORDED'
};

const CHILD_RESOURCE:any = {
  'request-information':'information_requests', 'respond-information':'information_responses', decisions:'decisions',
  'establishment-applications':'facility_establishment_applications', 'production-lines':'production_lines', 'gmp-assessments':'gmp_assessments',
  versions:'product_versions', packages:'product_packages', 'registration-applications':'product_registration_applications', batches:'product_batches', formulas:'feed_formulas',
  visits:'inspection_visits', findings:'findings', actions:'enforcement_actions', appeals:'enforcement_appeals',
  'custody-events':'sample_custody_events', investigations:'disease_investigations', samples:'laboratory_samples', zones:'outbreak_zones', 'control-measures':'outbreak_control_measures',
  certificates:'certificates', production:'aquaculture_production', harvest:'aquaculture_harvest'
};

function normalizedResource(pathname:string) {
  const parts = pathname.split('/').filter(Boolean).filter((x)=>x!=='api' && x!=='v1');
  const cut = parts.findIndex((p)=>p.startsWith('{'));
  const base = (cut >= 0 ? parts.slice(0,cut) : parts).join('_');
  return base.replaceAll('-','_');
}

function paginate(list:any[], url:any) {
  const q = (url.searchParams.get('q') || '').toLowerCase();
  const status = url.searchParams.get('status');
  let rows = list;
  if (q) rows = rows.filter((r)=>JSON.stringify(r).toLowerCase().includes(q));
  if (status) rows = rows.filter((r)=>String(r.status||r.lifecycleStatus||'').toLowerCase()===status.toLowerCase());
  const page = Math.max(1, Number(url.searchParams.get('page') || 1));
  const pageSize = Math.min(200, Math.max(1, Number(url.searchParams.get('pageSize') || 50)));
  const total = rows.length;
  rows = rows.slice((page-1)*pageSize, page*pageSize);
  return { rows, meta:{page,pageSize,total} };
}

export function buildRouteMatcher(routes:any[]) {
  return routes.map((r)=>{
    const names:string[]=[];
    const regex = new RegExp('^'+r.path.replace(/\{([^}]+)\}/g,(_,n)=>{names.push(n);return '([^/]+)';})+'$');
    return {...r, regex, names};
  });
}

export async function executeRoute(ctx:any) {
  const { route, params, method, apiPath, body, store, url, principal, ids } = ctx;
  if (route.path === '/health') return { status:200, body:{status:'ok',service:'lvsp-api',time:new Date().toISOString()} };
  if (route.path === '/ready') { const h=store.health?await store.health():{ok:true,mode:store.mode}; return { status:200, body:{status:'ready',storage:store.mode,database:h.database||null,details:h} }; }
  if (route.path === '/certificates/verify/{token}') {
    const cert=await store.find('certificates',(x:any)=>x.verificationToken===params.token || x.verification_token===params.token || x.certificateNo===params.token);
    if (!cert) return {status:404, body:{error:{code:'CERTIFICATE_NOT_FOUND',message:'Certificate not found',requestId:ids.requestId}}};
    return {status:200, body:{data:{valid:!['REVOKED','CANCELLED','EXPIRED'].includes(cert.status),certificate:cert},meta:{requestId:ids.requestId}}};
  }

  // Metadata endpoints added for the local runnable app.
  if (apiPath === '/meta' && method === 'GET') {
    const counts:any={};
    
    return {status:200, body:{data:{counts,mode:'local-development'},meta:{requestId:ids.requestId}}};
  }

  const resource = normalizedResource(route.path);
  if (method === 'GET' && route.path.includes('/{id}') && params.id) {
    const record=await store.get(resource,params.id);
    if (!record || (resource==='documents' && record.businessEntityType==='DOCUMENT_INTAKE')) return {status:404, body:{error:{code:'NOT_FOUND',message:`${resource} record not found`,requestId:ids.requestId}}};
    return {status:200, body:{data:record,meta:{requestId:ids.requestId}}};
  }
  if (method === 'GET') {
    const {rows,meta}=paginate((await store.list(resource)).filter((record:any)=>resource!=='documents'||record.businessEntityType!=='DOCUMENT_INTAKE'),url);
    return {status:200, body:{data:rows,meta:{...meta,requestId:ids.requestId}}};
  }

  if (method === 'POST') {
    const parts=route.path.split('/').filter(Boolean);
    const idIndex=parts.findIndex((p)=>p==='{id}');
    const tail=idIndex>=0 ? parts.slice(idIndex+1).join('/') : '';

    // collection create
    if (idIndex < 0) {
      let input={...body};
      // Mixed veterinary-product import applications use one document with item-level rules.
      // The API records the eligibility result; it does not split the user's application.
      if(resource==='import_application_items'){
        const typ=String(input.itemType||'').toUpperCase();
        if(['MEDICINE','VACCINE','BIOLOGICAL'].includes(typ) && input.productId){
          const reg=await store.find('drug_registrations',(x:any)=>String(x.productId)===String(input.productId));
          if(!reg){ input.eligibilityStatus='BLOCKED'; input.eligibilityMessage='No veterinary product registration found'; }
          else {
            const exp=reg.expiryDate?new Date(reg.expiryDate):null; const expired=!!(exp && exp.getTime()<Date.now());
            const active=['ACTIVE','VALID','APPROVED'].includes(String(reg.registrationStatus||'').toUpperCase());
            input.registrationNo=input.registrationNo||reg.registrationNo||null;
            input.eligibilityStatus=active&&!expired?'ELIGIBLE':'BLOCKED';
            input.eligibilityMessage=active&&!expired?'Registration valid':'Registration inactive or expired';
          }
        } else if(typ==='VETERINARY_DEVICE' && input.deviceId){
          const dev=await store.get('veterinary_devices',String(input.deviceId));
          const active=dev && ['ACTIVE','VALID','APPROVED','AUTHORIZED'].includes(String(dev.authorizationStatus||'').toUpperCase());
          input.registrationNo=input.registrationNo||dev?.registrationNo||null;
          input.eligibilityStatus=active?'ELIGIBLE':'REVIEW_REQUIRED';
          input.eligibilityMessage=active?'Device authorization valid':'Device requires regulatory review';
        }
      }
      if(store.mode==='local-json') input=await applyDevelopmentNumber(store,resource,input);
      if (resource==='certificates' && !input.verificationToken) input.verificationToken=crypto.randomBytes(18).toString('hex');
      const record=await store.create(resource,input);
      await store.audit({actorUserId:principal.userId,actionCode:`${resource}.create`,resourceType:resource,resourceId:record.id,correlationId:ids.correlationId,afterData:record});
      await store.enqueue({eventType:`${resource}.created.v1`,aggregateType:resource,aggregateId:record.id,correlationId:ids.correlationId,payload:record});
      return {status:201, body:{data:record,meta:{requestId:ids.requestId}}};
    }

    const baseResource = normalizedResource('/'+parts.slice(0,idIndex).join('/'));
    const target=await store.get(baseResource,params.id);
    if (!target) return {status:404,body:{error:{code:'NOT_FOUND',message:`${baseResource} record not found`,requestId:ids.requestId}}};

    if (tail && CHILD_RESOURCE[tail]) {
      const childResource=CHILD_RESOURCE[tail];
      const parentField=baseResource.replace(/s$/,'')+'Id';
      let input={...body,[parentField]:params.id};
      if(store.mode==='local-json') input=await applyDevelopmentNumber(store,childResource,input);
      if (childResource==='certificates' && !input.verificationToken) input.verificationToken=crypto.randomBytes(18).toString('hex');
      const child=await store.create(childResource,input);
      await store.audit({actorUserId:principal.userId,actionCode:`${childResource}.create`,resourceType:childResource,resourceId:child.id,correlationId:ids.correlationId,afterData:child});
      await store.enqueue({eventType:`${childResource}.created.v1`,aggregateType:childResource,aggregateId:child.id,correlationId:ids.correlationId,payload:child});
      return {status:201,body:{data:child,meta:{requestId:ids.requestId}}};
    }

    if (tail) {
      const action=tail;
      assertCommandAllowed(baseResource, action, target, principal);
      let status=ACTION_STATUS[action] || ACTION_STATUS[action.replace('-','_')] || action.toUpperCase().replaceAll('-','_');
      if (baseResource==='capa' && action==='submit') status='SUBMITTED';
      const updated=await store.update(baseResource,params.id,{...body,status,lastAction:action,lastActionAt:new Date().toISOString()});
      await store.audit({actorUserId:principal.userId,actionCode:`${baseResource}.${action}`,resourceType:baseResource,resourceId:params.id,correlationId:ids.correlationId,beforeData:target,afterData:updated});
      await store.enqueue({eventType:`${baseResource}.${action.replaceAll('-','_')}.v1`,aggregateType:baseResource,aggregateId:params.id,correlationId:ids.correlationId,payload:{id:params.id,status}});
      return {status:200,body:{data:updated,meta:{requestId:ids.requestId}}};
    }
  }

  return {status:501, body:{error:{code:'NOT_IMPLEMENTED',message:'Route recognized but not implemented',requestId:ids.requestId}}};
}
