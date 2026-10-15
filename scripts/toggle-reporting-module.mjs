const mode=String(process.argv[2]||'').toLowerCase();
if(!['on','off'].includes(mode))throw new Error('Usage: node scripts/toggle-reporting-module.mjs on|off');
const url=process.env.DATABASE_URL_DIRECT||process.env.DATABASE_MIGRATION_URL||process.env.DATABASE_URL;
if(!url)throw new Error('DATABASE_URL_DIRECT or DATABASE_URL is required');
const {Client}=await import('pg');const c=new Client({connectionString:url,ssl:{rejectUnauthorized:false}});await c.connect();
try{
  const enabled=mode==='on';
  const r=await c.query(`update system.platform_setting set value_json=$1::jsonb,updated_at=now() where setting_code='REPORTING_MODULE_ENABLED' and status='ACTIVE' returning setting_code,value_json`,[JSON.stringify(enabled)]);
  if(!r.rowCount)throw new Error('REPORTING_MODULE_ENABLED setting not found. Apply migration 000760 first.');
  console.log(`Provincial Reporting module is now ${enabled?'ENABLED':'DISABLED'}. Data and schema were not deleted.`);
}finally{await c.end()}
