const url=process.env.DATABASE_URL_DIRECT||process.env.DATABASE_MIGRATION_URL||process.env.DATABASE_URL;
if(!url)throw new Error('DATABASE_URL_DIRECT or DATABASE_URL is required');
const {Client}=await import('pg');
const client=new Client({connectionString:url,ssl:{rejectUnauthorized:false}});
await client.connect();
try{
  const tables=await client.query(`select table_schema,table_name from information_schema.tables where (table_schema,table_name) in (('system','service_guide'),('system','service_step'),('system','service_requirement'),('system','service_output'),('casework','service_draft'),('casework','service_draft_step'),('casework','service_draft_requirement')) order by 1,2`);
  const guides=await client.query(`select sd.service_code,sd.name_en,sg.status,sg.launch_module_key,(select count(*) from system.service_step ss where ss.service_version_id=sv.id and ss.status='ACTIVE') step_count,(select count(*) from system.service_requirement sr where sr.service_version_id=sv.id and sr.status='ACTIVE') requirement_count from system.service_definition sd join system.service_version sv on sv.service_id=sd.id and sv.version_no=1 join system.service_guide sg on sg.service_version_id=sv.id where sd.service_code in ('VM-1003','TR-1021','TR-1007') order by sg.display_order`);
  const missing=['VM-1003','TR-1021','TR-1007'].filter(code=>!guides.rows.some(x=>x.service_code===code));
  if(tables.rowCount<7)throw new Error(`Guided-service schema incomplete: ${tables.rowCount}/7 core tables found`);
  if(missing.length)throw new Error('Missing guided services: '+missing.join(', '));
  console.log(JSON.stringify({connection:true,coreTables:tables.rowCount,guidedServices:guides.rows},null,2));
}finally{await client.end();}
