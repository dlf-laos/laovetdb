import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {server,store} from '../dist/server.js';

let base;
const routes=JSON.parse(fs.readFileSync(new URL('../runtime/routes.json',import.meta.url),'utf8'));
test.before(async()=>{await store.reset();await new Promise(r=>server.listen(0,'127.0.0.1',r));base=`http://127.0.0.1:${server.address().port}`});
test.after(async()=>{await new Promise(r=>server.close(r));});
async function call(path,method='GET',body={}){const isPublic=path==='/health'||path==='/ready';const u=isPublic?path:'/api/v1'+path;const r=await fetch(base+u,{method,headers:{'content-type':'application/json','x-lvsp-role':'SYSTEM_ADMIN'},body:method==='GET'?undefined:JSON.stringify(body)});let b;try{b=await r.json()}catch{b={}}return {r,b}}
async function ensureBase(prefix){const c=await call(prefix,'POST',{name:'Contract test',status:'DRAFT',caseNo:'CT-'+Math.random().toString(36).slice(2,8)});assert.ok(c.r.status<500,`${prefix} create returned ${c.r.status}`);return c.b.data?.id}

test('all approved OpenAPI routes are recognized by executable server',async()=>{
  let tested=0;
  for(const route of routes){
    let p=route.path;
    if(p==='/certificates/verify/{token}'){
      const c=await call('/certificates','POST',{certificateNo:'CT-CERT-'+tested,status:'VALID',verificationToken:'ct-token-'+tested});
      const x=await call(`/certificates/verify/${c.b.data.verificationToken}`,'GET');assert.ok(x.r.status<500);tested++;continue;
    }
    if(p.includes('{id}')){
      const prefix=p.slice(0,p.indexOf('/{id}'));
      const id=await ensureBase(prefix);
      p=p.replace('{id}',id);
    }
    const x=await call(p,route.method,route.method==='POST'?{status:'DRAFT',note:'contract test'}:{});
    assert.notEqual(x.r.status,404,`${route.method} ${route.path} was not recognized`);
    assert.ok(x.r.status<500,`${route.method} ${route.path} returned ${x.r.status}`);
    tested++;
  }
  assert.equal(tested,routes.length);
});
