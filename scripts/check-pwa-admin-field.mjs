import pg from 'pg';
const cs=process.env.DATABASE_URL;if(!cs)throw new Error('DATABASE_URL is required');
const pool=new pg.Pool({connectionString:cs,max:1,application_name:'lvsp-v100-check'});
try{
  const q=async(sql,params=[])=>(await pool.query(sql,params)).rows;
  const [settings]=await q("select count(*)::int n from system.platform_setting where status='ACTIVE'");
  const [field]=await q("select count(*)::int n from information_schema.tables where table_schema='inspection' and table_name='field_capture_draft'");
  const [guided]=await q("select count(*)::int n from information_schema.tables where table_schema='casework' and table_name='service_draft'");
  const [migs]=await q("select count(*)::int n from system.schema_migration where filename in ('000740_guided_services_workflow.sql','000750_pwa_admin_field_foundation.sql')");
  if(settings.n<6||field.n!==1||guided.n!==1||migs.n<2)throw new Error(`v1.0 verification failed: settings=${settings.n}, fieldTable=${field.n}, guidedTable=${guided.n}, migrations=${migs.n}`);
  console.log('LVSP v1.0 Neon check PASS');
  console.log(`- platform settings: ${settings.n}`);
  console.log(`- guided service draft table: ${guided.n}`);
  console.log(`- field capture staging table: ${field.n}`);
  console.log(`- v0.9/v1.0 migrations recorded: ${migs.n}`);
} finally { await pool.end(); }
