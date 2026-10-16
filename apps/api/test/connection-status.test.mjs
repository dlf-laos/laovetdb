import test from 'node:test';
import assert from 'node:assert/strict';
import {probeConnection} from '../../web/public/connection-status.js';
test('Wi-Fi connectivity alone does not report a healthy backend',async()=>{
 assert.deepEqual(await probeConnection(true,async()=>new Response('Sign into Vercel',{status:200})),{state:'unavailable'});
 assert.deepEqual(await probeConnection(true,async()=>new Response(JSON.stringify({status:'ready',details:{ok:false}}))),{state:'unavailable'});
 assert.deepEqual(await probeConnection(true,async()=>new Response('',{status:503})),{state:'unavailable'});
});
test('database readiness is required and offline checks do not send requests',async()=>{
 let calls=0;const fetcher=async()=>{calls++;return new Response(JSON.stringify({status:'ready',storage:'postgres',details:{ok:true}}));};
 assert.deepEqual(await probeConnection(false,fetcher),{state:'offline'});assert.equal(calls,0);
 assert.deepEqual(await probeConnection(true,fetcher),{state:'connected',storage:'postgres'});
});
test('a stalled connection is cancelled and shown as unavailable',async()=>{
 const keepAlive=setTimeout(()=>{},1000);
 try{assert.deepEqual(await probeConnection(true,async(_url,{signal})=>new Promise((_resolve,reject)=>signal.addEventListener('abort',()=>reject(signal.reason))),30),{state:'unavailable'});}finally{clearTimeout(keepAlive);}
});
