import test from 'node:test';
import assert from 'node:assert/strict';
import {PostgresStore} from '../dist/core/postgres-store.js';
test('database transport rejects unsupported values and non-Neon hosts before connecting',async()=>{
 const previous=process.env.LVSP_PG_TRANSPORT;
 try{
  process.env.LVSP_PG_TRANSPORT='invalid';
  await assert.rejects(PostgresStore.create('postgresql://localhost/example'),/Unsupported/);
  process.env.LVSP_PG_TRANSPORT='neon-ws';
  await assert.rejects(PostgresStore.create('postgresql://localhost/example'),/Neon database hostname/);
 }finally{if(previous===undefined)delete process.env.LVSP_PG_TRANSPORT;else process.env.LVSP_PG_TRANSPORT=previous;}
});
