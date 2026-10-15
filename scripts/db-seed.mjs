import fs from 'node:fs';
const url=process.env.DATABASE_URL_DIRECT||process.env.DATABASE_MIGRATION_URL||process.env.DATABASE_URL;
if(!url) throw new Error('DATABASE_URL_DIRECT or DATABASE_URL is required');
const {Client}=await import('pg'); const c=new Client({connectionString:url});await c.connect();
try{await c.query('begin');await c.query(fs.readFileSync('database/LVSP_FULL_SEEDS.sql','utf8'));await c.query('commit');console.log('Seeds complete');}catch(e){await c.query('rollback');throw e;}finally{await c.end();}
