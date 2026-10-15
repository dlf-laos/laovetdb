import pg from 'pg';
const cs=process.env.DATABASE_URL_DIRECT||process.env.DATABASE_URL;
if(!cs){console.log(JSON.stringify({connection:false,message:'DATABASE_URL not set'},null,2));process.exit(1)}
const pool=new pg.Pool({connectionString:cs,max:2,application_name:'lvsp-company-multisite-check'});
try{
 const one=async(sql)=>Number((await pool.query(sql)).rows[0]?.n||0);
 const result={
  connection:true,
  companies:await one('select count(*) n from master.company'),
  companySites:await one("select count(*) n from master.company_site where status='ACTIVE'"),
  companiesWithMultipleSites:await one("select count(*) n from (select company_id from master.company_site where status='ACTIVE' group by company_id having count(*)>1) x"),
  companyRoleAssignments:await one("select count(*) n from master.party_role_assignment where status='ACTIVE'"),
  externalRegistrations:await one("select count(*) n from master.company_external_registration where status='ACTIVE'"),
  drugProfilesWithHolderSite:await one('select count(*) n from product.product_regulatory_profile where holder_site_id is not null'),
  drugProfilesWithImporterSite:await one('select count(*) n from product.product_regulatory_profile where importer_site_id is not null'),
  drugProfilesWithManufacturerSite:await one('select count(*) n from product.product_regulatory_profile where manufacturer_site_id is not null')
 };
 console.log(JSON.stringify(result,null,2));
} finally {await pool.end()}
