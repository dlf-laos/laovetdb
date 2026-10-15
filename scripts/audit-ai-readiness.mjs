// Read-only schema inventory. Never print credentials or regulatory records.
import pg from 'pg';
const client=new pg.Client({connectionString:process.env.DATABASE_URL_DIRECT||process.env.DATABASE_URL,connectionTimeoutMillis:5000});
const tables=['master.company','product.product','product.product_regulatory_profile','product.product_common_composition','registration.veterinary_drug_application','document.document','document.file'];
await client.connect();
try {
 await client.query('BEGIN READ ONLY');
 await client.query("SET LOCAL statement_timeout='10s'");
 const inventory=[];
 for(const table of tables){
  const present=(await client.query('select to_regclass($1) is not null as present',[table])).rows[0].present;
  const [schema,name]=table.split('.');
  const columns=present?(await client.query('select column_name,data_type from information_schema.columns where table_schema=$1 and table_name=$2 order by ordinal_position',[schema,name])).rows:[];
  // Identifiers are fixed constants above, never user input.
  const count=present?(await client.query(`select count(*)::text as count from ${table}`)).rows[0].count:null;
  inventory.push({table,present,count,columns});
 }
 console.log(JSON.stringify({checkedAt:new Date().toISOString(),scope:'Configured local Neon connection; Vercel environment not verified',readOnly:true,inventory},null,2));
 await client.query('ROLLBACK');
} finally {await client.end();}
