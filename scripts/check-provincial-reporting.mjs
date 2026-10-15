const url=process.env.DATABASE_URL_DIRECT||process.env.DATABASE_MIGRATION_URL||process.env.DATABASE_URL;
if(!url)throw new Error('DATABASE_URL_DIRECT or DATABASE_URL is required');
const {Client}=await import('pg');
const c=new Client({connectionString:url,ssl:{rejectUnauthorized:false}});await c.connect();
try{
  const tables=await c.query(`select table_name from information_schema.tables where table_schema='reporting' order by table_name`);
  const provinces=await c.query(`select count(*)::int n from reporting.province_profile where status='ACTIVE'`);
  const regions=await c.query(`select region_code,name_lo,name_en from reporting.region where is_active=true order by display_order`);
  const metrics=await c.query(`select count(*)::int n from reporting.indicator_definition where is_active=true`);
  const setting=await c.query(`select value_json from system.platform_setting where setting_code='REPORTING_MODULE_ENABLED' and status='ACTIVE'`);
  const migration=await c.query(`select count(*)::int n from system.schema_migration where filename='000760_provincial_reporting_consolidation.sql'`);
  if(tables.rowCount<8||provinces.rows[0].n<18||regions.rowCount<3||metrics.rows[0].n<5||migration.rows[0].n!==1)throw new Error(`v1.1 reporting verification failed: tables=${tables.rowCount}, provinces=${provinces.rows[0].n}, regions=${regions.rowCount}, metrics=${metrics.rows[0].n}, migration=${migration.rows[0].n}`);
  console.log('LVSP v1.1 Provincial Reporting Neon check PASS');
  console.log(JSON.stringify({reportingTables:tables.rowCount,provinces:provinces.rows[0].n,regions:regions.rows,indicatorDefinitions:metrics.rows[0].n,moduleEnabled:setting.rows[0]?.value_json,migrationRecorded:migration.rows[0].n},null,2));
}finally{await c.end()}
