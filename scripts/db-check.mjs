const url=process.env.DATABASE_URL_DIRECT||process.env.DATABASE_MIGRATION_URL||process.env.DATABASE_URL;
if(!url) throw new Error('DATABASE_URL_DIRECT or DATABASE_URL is required');
const {Client}=await import('pg'); const c=new Client({connectionString:url});await c.connect();
try{
 const v=await c.query('select current_database() db, current_user usr, version() version');
 const t=await c.query("select count(*)::int count from information_schema.tables where table_schema not in ('pg_catalog','information_schema')");
 const s=await c.query("select count(*)::int count from information_schema.schemata where schema_name in ('system','master','security','workflow','document','casework','registration','licensing','facility','product','feed','farm','animal','disease','laboratory','trade','fisheries','inspection','compliance','enforcement','integration','analytics','gis','audit')");
 console.log(JSON.stringify({connection:true,database:v.rows[0].db,user:v.rows[0].usr,tables:t.rows[0].count,coreSchemas:s.rows[0].count},null,2));
}finally{await c.end();}
