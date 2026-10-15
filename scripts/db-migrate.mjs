import fs from 'node:fs';
import path from 'node:path';
import {ledgerColumns} from './migration-ledger.mjs';
const url=process.env.DATABASE_URL_DIRECT||process.env.DATABASE_MIGRATION_URL||process.env.DATABASE_URL;
if(!url) throw new Error('DATABASE_URL_DIRECT or DATABASE_URL is required');
const {Client}=await import('pg');
const client=new Client({connectionString:url});
await client.connect();
try{
  const dir=path.resolve('database/migrations');
  const files=fs.readdirSync(dir).filter(x=>x.endsWith('.sql')).sort();
  await client.query(`create schema if not exists system; create table if not exists system.schema_migration(filename text primary key, checksum text not null, applied_at timestamptz not null default now())`);
  const columns=await ledgerColumns(client);
  const crypto=await import('node:crypto');
  for(const f of files){
    const sql=fs.readFileSync(path.join(dir,f),'utf8');
    const checksum=crypto.createHash('sha256').update(sql).digest('hex');
    const q=await client.query(`select "${columns.checksum}" as checksum from system.schema_migration where "${columns.name}"=$1`,[f]);
    if(q.rowCount){if(q.rows[0].checksum!==checksum)throw new Error(`Applied migration changed: ${f}`);continue;}
    console.log('Applying',f);
    await client.query('begin');
    try{await client.query(sql);await client.query(`insert into system.schema_migration("${columns.name}","${columns.checksum}") values($1,$2)`,[f,checksum]);await client.query('commit');}
    catch(e){await client.query('rollback');throw e;}
  }
  console.log(`Migrations complete: ${files.length}`);
}finally{await client.end();}
