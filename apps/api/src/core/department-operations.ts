// @ts-nocheck
import {readJson,sendJson} from './http.js';
const resources={work:'department_work_items',budget:'department_budget_entries'};
const tables={work:'reporting.department_work_item',budget:'reporting.department_budget_entry'};
const writers=new Set(['SYSTEM_ADMIN','SECURITY_ADMIN','TECHNICAL_REVIEWER','APPROVING_AUTHORITY']);
const reviewers=new Set(['SYSTEM_ADMIN','SECURITY_ADMIN','TECHNICAL_REVIEWER','APPROVING_AUTHORITY']);
const fail=(code,message,statusCode=400)=>{throw Object.assign(new Error(message),{code,statusCode});};
function fields(kind,body){
  if(!/^\d{4}-(0[1-9]|1[0-2])$/.test(String(body.reportMonth||'')))fail('INVALID_MONTH','Select a valid reporting month.');
  const title=String(body.title||'').trim();if(!title||title.length>300)fail('INVALID_TITLE','Title is required, up to 300 characters.');
  const result={reportMonth:body.reportMonth,title,notes:String(body.notes||'').slice(0,10000)};
  if(kind==='budget'){
    for(const key of ['plannedAmount','actualAmount']){
      const value=Number(body[key]);if(body[key]===undefined||body[key]===''||!Number.isSafeInteger(value)||value<0)fail('INVALID_AMOUNT','Amounts must be non-negative whole Lao kip.');
      result[key]=value;
    }
    result.currency='LAK';
  }else{result.plannedResult=String(body.plannedResult||'').slice(0,10000);result.actualResult=String(body.actualResult||'').slice(0,10000);}
  return result;
}
export async function handleDepartmentOperationsApi({req,res,url,store,ids,principal}){
  const match=url.pathname.match(/^\/api\/v1\/department-operations\/(work|budget)(?:\/([a-f0-9-]{36})(?:\/(submit|verify|return))?)?$/);
  if(!match)return false;
  if(!principal.isAuthenticated)fail('UNAUTHENTICATED','Authentication required',401);
  const [,kind,id,command]=match;const resource=resources[kind];
  const admin=principal.roles.some(x=>['SYSTEM_ADMIN','SECURITY_ADMIN'].includes(x));
  const canReview=principal.roles.some(x=>reviewers.has(x));
  const canWrite=principal.roles.some(x=>writers.has(x));
  if(!canReview&&!principal.roles.includes('MANAGEMENT_VIEWER'))fail('FORBIDDEN','Department staff access required',403);
  if(req.method==='GET'&&!id){
    const month=url.searchParams.get('month');if(!/^\d{4}-(0[1-9]|1[0-2])$/.test(month||''))fail('INVALID_MONTH','Select a valid reporting month.');
    let rows;
    if(store.mode==='postgres'){
      const query=await store.pool.query(`select id from ${tables[kind]} where report_month=$1 order by created_at desc`,[month]);
      rows=await Promise.all(query.rows.map(x=>store.get(resource,x.id)));
    }else rows=(await store.list(resource)).filter(x=>x.reportMonth===month);
    sendJson(res,200,{data:rows,meta:{requestId:ids.requestId,month,currency:kind==='budget'?'LAK':undefined}},ids);return true;
  }
  if(!canWrite)fail('FORBIDDEN','Department write role required',403);
  if(!['POST','PATCH'].includes(req.method))fail('METHOD_NOT_ALLOWED','Use GET, POST or PATCH',405);
  const body=await readJson(req);
  // All PostgreSQL record, audit and outbox writes commit together.
  const client=store.mode==='postgres'?await store.pool.connect():null;
  const tx=client?new store.constructor(client):store;
  try{
    if(client)await client.query('begin');
    let before,data,action;
    if(!id&&req.method==='POST'){
      data=await tx.create(resource,{...fields(kind,body),ownerSubject:principal.userId,status:'DRAFT',version:1});action='create';
    }else if(id){
      if(client)await client.query(`select id from ${tables[kind]} where id=$1 for update`,[id]);
      before=await tx.get(resource,id);if(!before)fail('NOT_FOUND','Record not found',404);
      if(Number(body.version)!==Number(before.version))fail('STALE_VERSION','Record changed. Reload before saving.',409);
      if(!admin&&before.ownerSubject!==principal.userId&&!command)fail('FORBIDDEN','Only the owner or administrator may edit',403);
      let patch;
      if(!command&&req.method==='PATCH'){
        if(!['DRAFT','RETURNED'].includes(before.status))fail('LOCKED_RECORD','Submitted and verified records are locked',409);
        patch=fields(kind,body);action='update';
      }else if(command&&req.method==='POST'){
        const expected=command==='submit'?['DRAFT','RETURNED']:['SUBMITTED'];
        if(!expected.includes(before.status))fail('INVALID_TRANSITION','This action is not allowed for the current status',409);
        if(command==='submit'&&!admin&&before.ownerSubject!==principal.userId)fail('FORBIDDEN','Only the owner or administrator may submit',403);
        if(command!=='submit'){
          if(!canReview)fail('FORBIDDEN','Reviewer role required',403);
          if(before.ownerSubject===principal.userId)fail('SELF_REVIEW_FORBIDDEN','A different staff member must review this record',403);
        }
        patch={status:command==='submit'?'SUBMITTED':command==='verify'?'VERIFIED':'RETURNED',reviewedBy:command==='submit'?null:principal.userId};action=command;
      }else fail('METHOD_NOT_ALLOWED','Unsupported action',405);
      data=await tx.update(resource,id,{...patch,version:Number(before.version)+1});
    }else fail('METHOD_NOT_ALLOWED','Unsupported action',405);
    await tx.audit({actorUserId:principal.userId,actionCode:`department.${kind}.${action}`,resourceType:resource,resourceId:data.id,correlationId:ids.correlationId,beforeData:before,afterData:data});
    await tx.enqueue({eventType:`department.${kind}.${action}.v1`,aggregateType:resource,aggregateId:data.id,correlationId:ids.correlationId,payload:{id:data.id,status:data.status,version:data.version}});
    if(client)await client.query('commit');
    sendJson(res,!id?201:200,{data,meta:{requestId:ids.requestId}},ids);return true;
  }catch(error){if(client)await client.query('rollback');throw error;}finally{client?.release();}
}
