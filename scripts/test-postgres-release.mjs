// Destructive test data is allowed only in a disposable database on loopback.
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
const url=new URL(process.env.DATABASE_URL||'');
if(!['127.0.0.1','localhost'].includes(url.hostname)||process.env.LVSP_DISPOSABLE_DB!=='1')throw new Error('Use an explicitly disposable local PostgreSQL database only.');
process.env.NODE_ENV='test';process.env.AUTH_MODE='database';process.env.LVSP_STORAGE='postgres';
process.env.LVSP_AUTH_SECRET=crypto.randomBytes(32).toString('hex');
const {server,store}=await import('../apps/api/dist/server.js');
const suffix=crypto.randomBytes(4).toString('hex');const password='Temporary-'+crypto.randomBytes(16).toString('hex');
let base;
async function request(path,method='GET',body,token){
 const response=await fetch(base+path,{method,headers:{'content-type':'application/json',...(token?{authorization:'Bearer '+token}:{})},body:body===undefined?undefined:JSON.stringify(body)});
 return {status:response.status,data:await response.json()};
}
try{
 await store.createAdminUser({username:'test-owner-'+suffix,password,roles:['SYSTEM_ADMIN'],mustChangePassword:false},null);
 await store.createAdminUser({username:'test-reviewer-'+suffix,password,roles:['TECHNICAL_REVIEWER'],mustChangePassword:false},null);
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});base='http://127.0.0.1:'+server.address().port;
 const login=await request('/api/v1/auth/login','POST',{username:'test-owner-'+suffix,password});assert.equal(login.status,200);const owner=login.data.data.token;
 const reviewLogin=await request('/api/v1/auth/login','POST',{username:'test-reviewer-'+suffix,password});assert.equal(reviewLogin.status,200);const reviewer=reviewLogin.data.data.token;
 const input={reportMonth:'2026-10',title:'Disposable test budget',plannedAmount:1000,actualAmount:100};
 const created=await request('/api/v1/department-operations/budget','POST',input,owner);assert.equal(created.status,201);const id=created.data.data.id;
 const concurrent=await Promise.all([200,300].map(actualAmount=>request('/api/v1/department-operations/budget/'+id,'PATCH',{...input,actualAmount,version:1},owner)));
 assert.deepEqual(concurrent.map(x=>x.status).sort(),[200,409]);
 const submitted=await request('/api/v1/department-operations/budget/'+id+'/submit','POST',{version:2},owner);assert.equal(submitted.status,200);
 const verified=await request('/api/v1/department-operations/budget/'+id+'/verify','POST',{version:3},reviewer);assert.equal(verified.status,200);
 assert.equal((await request('/api/v1/department-operations/budget/'+id,'PATCH',{...input,version:4},owner)).status,409);
 const audit=await store.pool.query('select count(*)::int n from audit.event where resource_id=$1',[id]);assert.equal(audit.rows[0].n,4);
 const outbox=await store.pool.query('select count(*)::int n from integration.outbox_event where aggregate_id=$1',[id]);assert.equal(outbox.rows[0].n,4);
 await assert.rejects(store.pool.query('update reporting.department_budget_entry set actual_amount=0 where id=$1',[id]),/immutable/i);
 await assert.rejects(store.pool.query('delete from reporting.department_budget_entry where id=$1',[id]),/Hard delete/i);
 const reportColumns=await store.pool.query("select count(*)::int n from information_schema.columns where table_schema='analytics' and table_name='v_veterinary_trade_permit_report'");assert.equal(reportColumns.rows[0].n,23);
 const summary=await request('/api/v1/reporting/monthly-summary?year=2026&month=10','GET',undefined,owner);assert.equal(summary.status,200);
 console.log(JSON.stringify({database:'disposable local PostgreSQL',login:'passed',budgetLifecycle:'passed',concurrentUpdates:'one committed, one rejected',auditAndOutbox:'atomic records verified',verifiedRecordDatabaseLock:'passed',hardDeleteGuard:'passed',tradeReportColumns:23,monthlySummary:'passed'},null,2));
}finally{if(server.listening)await new Promise(resolve=>server.close(resolve));await store.close();}
