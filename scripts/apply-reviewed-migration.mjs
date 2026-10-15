import fs from 'node:fs';
import crypto from 'node:crypto';
import pg from 'pg';
import {ledgerColumns} from './migration-ledger.mjs';
const filename=process.argv[2];
if(!['000920_trade_permit_report_validity_columns.sql','000930_department_operations.sql'].includes(filename))throw new Error('This command accepts only the reviewed 000920 or 000930 migration.');
const url=process.env.DATABASE_URL_DIRECT;
if(!url)throw new Error('Set DATABASE_URL_DIRECT for the intended staging database first.');
const sql=fs.readFileSync('database/migrations/'+filename,'utf8');
const checksum=crypto.createHash('sha256').update(sql).digest('hex');
const client=new pg.Client({connectionString:url});await client.connect();
try{
 const columns=await ledgerColumns(client);
 await client.query('begin');
 await client.query("select pg_advisory_xact_lock(hashtext('lvsp-reviewed-migration'))");
 const applied=await client.query(`select "${columns.checksum}" as checksum from system.schema_migration where "${columns.name}"=$1`,[filename]);
 if(applied.rows.length){
   if(applied.rows[0].checksum!==checksum)throw new Error('Applied migration checksum differs. Do not overwrite history.');
   console.log('Already applied with matching checksum: '+filename);
 }else{
   await client.query(sql);
   await client.query(`insert into system.schema_migration("${columns.name}","${columns.checksum}") values($1,$2)`,[filename,checksum]);
   console.log('Applied: '+filename);
 }
 await client.query('commit');
}catch(error){await client.query('rollback');throw error;}finally{await client.end();}
