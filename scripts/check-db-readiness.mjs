// Read-only. No DDL, migrations, seeds or record writes.
import fs from 'node:fs';
import crypto from 'node:crypto';
import pg from 'pg';
import {ledgerColumns} from './migration-ledger.mjs';
const url=process.env.DATABASE_URL_DIRECT||process.env.DATABASE_URL;
if(!url)throw new Error('DATABASE_URL_DIRECT or DATABASE_URL is required.');
const client=new pg.Client({connectionString:url});
await client.connect();
try{
 await client.query('BEGIN READ ONLY');
 const relation=await client.query("select to_regclass('system.schema_migration') is not null as present");
 const columns=relation.rows[0].present?await ledgerColumns(client):null;
 const rows=columns?(await client.query(`select "${columns.name}" as filename,"${columns.checksum}" as checksum from system.schema_migration`)).rows:[];
 const applied=new Map(rows.map(x=>[x.filename,x.checksum]));
 const files=fs.readdirSync('database/migrations').filter(x=>x.endsWith('.sql')).sort();
 const pending=[],mismatched=[];
 for(const file of files){const checksum=crypto.createHash('sha256').update(fs.readFileSync('database/migrations/'+file)).digest('hex');if(!applied.has(file))pending.push(file);else if(applied.get(file)!==checksum)mismatched.push(file);}
 console.log(JSON.stringify({trackingTablePresent:relation.rows[0].present,tracked:rows.length,pending,mismatched,note:'Missing tracking entries do not prove that database objects are absent. Review existing migrations before applying.'},null,2));
 await client.query('ROLLBACK');
 if(pending.length||mismatched.length)process.exitCode=2;
}finally{await client.end();}
