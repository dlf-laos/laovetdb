import fs from 'node:fs';
import pg from 'pg';

const cs=process.env.DATABASE_URL_DIRECT||process.env.DATABASE_URL;
if(!cs){console.log('Company/site enrichment skipped: DATABASE_URL is not set');process.exit(0)}
const pool=new pg.Pool({connectionString:cs,max:2,application_name:'lvsp-company-multisite-enrichment'});
const trade=JSON.parse(fs.readFileSync(new URL('./legacy_vet_suite_export.json',import.meta.url),'utf8'));
const drugs=JSON.parse(fs.readFileSync(new URL('./admin4_legacy_records.json',import.meta.url),'utf8'));

function clean(v){return String(v||'').trim()}
function norm(v){return clean(v).toLowerCase().replace(/[.,()\-_/\\]+/g,' ').replace(/\b(company|co|ltd|limited|sole)\b/g,' ').replace(/\s+/g,' ').trim()}
async function countryId(client,c){
 const s=clean(c); if(!s)return null;
 const aliases={la:'LA','lao pdr':'LA','laos':'LA','thailand':'TH','china':'CN','p.r. china':'CN','pr china':'CN','vietnam':'VN','viet nam':'VN','hong kong':'HK','india':'IN','korea':'KR','south korea':'KR','usa':'US','u.s.a.':'US'};
 const code=aliases[s.toLowerCase()]||(/^[A-Za-z]{2}$/.test(s)?s.toUpperCase():null);
 let q=code?await client.query('select id from lookup.country where iso2_code=$1 limit 1',[code]):{rows:[]};
 if(q.rows[0])return q.rows[0].id;
 q=await client.query('select id from lookup.country where lower(name_en)=lower($1) or lower(name_lo)=lower($1) limit 1',[s]);
 return q.rows[0]?.id||null;
}
async function companyByEnterpriseOrName(client,o){
 if(clean(o.licenseNo)){
  const q=await client.query('select * from master.company where enterprise_no=$1 limit 1',[clean(o.licenseNo)]);if(q.rows[0])return q.rows[0];
 }
 for(const n of [o.nameLo,o.nameEn].map(clean).filter(Boolean)){
  const q=await client.query('select * from master.company where lower(legal_name_lo)=lower($1) or lower(coalesce(legal_name_en,\'\'))=lower($1) limit 1',[n]);if(q.rows[0])return q.rows[0];
 }
 return null;
}
async function ensureCompany(client,name,country='',alias=''){
 const n=clean(name); if(!n)return null;
 let q=await client.query('select * from master.company where lower(legal_name_lo)=lower($1) or lower(coalesce(legal_name_en,\'\'))=lower($1) limit 1',[n]);
 if(!q.rows[0]){
  const all=await client.query('select * from master.company');
  q.rows=all.rows.filter(x=>norm(x.legal_name_lo)===norm(n)||norm(x.legal_name_en)===norm(n)).slice(0,1);
 }
 if(q.rows[0])return q.rows[0];
 const cid=await countryId(client,country);
 const p=await client.query("insert into master.party(party_kind,display_name,status) values('COMPANY',$1,'ACTIVE') returning id",[n]);
 const looksEnglish=/^[\x00-\x7F\s.,&()'\-/]+$/.test(n);
 const r=await client.query('insert into master.company(party_id,legal_name_lo,legal_name_en,country_id,status) values($1,$2,$3,$4,\'ACTIVE\') returning *',[p.rows[0].id,n,looksEnglish?n:null,cid]);
 if(alias&&clean(alias)&&clean(alias)!==n)await client.query("insert into master.company_alias(company_id,alias_name,alias_type,source_system) values($1,$2,'LEGACY_NAME','admin4') on conflict do nothing",[r.rows[0].party_id,clean(alias)]);
 return r.rows[0];
}
async function ensureRole(client,companyId,code){
 const r=await client.query('select id from master.party_role_type where code=$1 and is_active=true limit 1',[code]);if(!r.rows[0])return;
 await client.query(`insert into master.party_role_assignment(party_id,role_type_id,valid_from,status)
  select $1,$2,current_date,'ACTIVE' where not exists(select 1 from master.party_role_assignment where party_id=$1 and role_type_id=$2 and status='ACTIVE')`,[companyId,r.rows[0].id]);
}
async function ensureSite(client,company,role,address,{phone='',email='',website='',country='',label=''}={}){
 const a=clean(address); if(!company?.party_id||!a)return null;
 let q=await client.query(`select cs.id,cs.facility_id from master.company_site cs join master.facility f on f.id=cs.facility_id
   where cs.company_id=$1 and cs.site_role_code=$2 and lower(coalesce(f.address_text_lo,''))=lower($3) limit 1`,[company.party_id,role,a]);
 if(q.rows[0])return q.rows[0].facility_id;
 const base=company.legal_name_lo||company.legal_name_en||'Company';
 const siteLabel=label||role.replaceAll('_',' ');
 const f=await client.query(`insert into master.facility(name_lo,name_en,address_text_lo,address_text_en,status)
   values($1,$2,$3,$4,'ACTIVE') returning id`,[`${base} — ${siteLabel}`,company.legal_name_en?`${company.legal_name_en} — ${siteLabel}`:null,a,a]);
 let makePrimary=['REGISTERED_OFFICE','HEAD_OFFICE','BUSINESS_SITE'].includes(role);
 if(makePrimary){const px=await client.query("select 1 from master.company_site where company_id=$1 and site_role_code=$2 and is_primary=true and status='ACTIVE' limit 1",[company.party_id,role]);makePrimary=!px.rows[0];}
 await client.query(`insert into master.company_site(company_id,facility_id,site_role_code,is_primary,status,source_system)
  values($1,$2,$3,$4,'ACTIVE','legacy-enrichment') on conflict do nothing`,[company.party_id,f.rows[0].id,role,makePrimary]);
 const ft=await client.query('select id from lookup.facility_type where code=$1 limit 1',[role]);
 if(ft.rows[0])await client.query(`insert into master.facility_type_assignment(facility_id,facility_type_id,status)
  select $1,$2,'ACTIVE' where not exists(select 1 from master.facility_type_assignment where facility_id=$1 and facility_type_id=$2 and status='ACTIVE')`,[f.rows[0].id,ft.rows[0].id]);
 for(const [type,value] of [['PHONE',phone],['EMAIL',email],['WEBSITE',website]])if(clean(value))await client.query(`insert into master.facility_contact(facility_id,contact_type,contact_value,is_primary,status) values($1,$2,$3,true,'ACTIVE')`,[f.rows[0].id,type,clean(value)]);
 return f.rows[0].id;
}
async function externalReg(client,companyId,type,no,expiry=''){
 if(!companyId||!clean(no))return;
 await client.query(`insert into master.company_external_registration(company_id,registration_type,registration_no,expiry_date,status,source_system)
  values($1,$2,$3,$4,'ACTIVE','DLF-Import-v28') on conflict do nothing`,[companyId,type,clean(no),clean(expiry)||null]);
}

const client=await pool.connect();
let legacySites=0,drugLinks=0,manufacturers=0;
try{
 await client.query('begin');
 // Legacy trade operators: preserve old address as a physical business site; never make a second company solely because address differs.
 for(const o of trade.operator||[]){
  const c=await companyByEnterpriseOrName(client,o); if(!c)continue;
  if(clean(o.address)){const before=await client.query('select count(*)::int n from master.company_site where company_id=$1',[c.party_id]);await ensureSite(client,c,'BUSINESS_SITE',o.address,{phone:o.phone,email:o.email,label:'Business Site'});const after=await client.query('select count(*)::int n from master.company_site where company_id=$1',[c.party_id]);if(after.rows[0].n>before.rows[0].n)legacySites++;}
  await externalReg(client,c.party_id,'BUSINESS_LICENSE',o.licenseNo,o.licenseExpiry);
  await ensureRole(client,c.party_id,'IMPORTER');
  for(const a of [o.nameLo,o.nameEn].map(clean).filter(Boolean))await client.query("insert into master.company_alias(company_id,alias_name,alias_type,source_system) values($1,$2,'LEGACY_NAME','DLF-Import-v28') on conflict do nothing",[c.party_id,a]);
 }
 // Drug registry legacy: link legal companies to distinct holder/importer/manufacturer/distributor sites.
 for(const x of drugs){
  if(!clean(x.regNo))continue;
  const pr=(await client.query('select * from product.product_regulatory_profile where registration_no=$1 limit 1',[x.regNo])).rows[0];
  if(!pr)continue;
  let holderSite=null, importerSite=null, manufacturerCompany=null, manufacturerSite=null, distributorCompany=null, distributorSite=null;
  if(pr.holder_company_id){const c=(await client.query('select * from master.company where party_id=$1',[pr.holder_company_id])).rows[0];if(c&&clean(x.mahAddr)){holderSite=await ensureSite(client,c,'REGISTRATION_HOLDER_OFFICE',x.mahAddr,{phone:x.mahPhone,email:x.mahEmail,website:x.mahWeb,label:'Registration Holder Office'});await ensureRole(client,c.party_id,'REGISTRATION_HOLDER');}}
  if(pr.importer_company_id){const c=(await client.query('select * from master.company where party_id=$1',[pr.importer_company_id])).rows[0];if(c&&clean(x.impAddr)){importerSite=await ensureSite(client,c,'IMPORTER_OFFICE',x.impAddr,{phone:x.impPhone,email:x.impEmail,website:x.impWeb,label:'Importer Office'});await ensureRole(client,c.party_id,'IMPORTER');}}
  if(clean(x.manufacturer)){
   manufacturerCompany=await ensureCompany(client,x.manufacturer,x.mfgCountry,x.manufacturer);if(manufacturerCompany){await ensureRole(client,manufacturerCompany.party_id,'MANUFACTURER');manufacturerSite=await ensureSite(client,manufacturerCompany,'MANUFACTURING_SITE',x.mfgAddr,{phone:x.mfgPhone,email:x.mfgEmail,website:x.mfgWeb,country:x.mfgCountry,label:'Manufacturing Site'});manufacturers++;}
  }
  if(clean(x.distributorName)){
   distributorCompany=await ensureCompany(client,x.distributorName,x.distributorCountry,x.distributorName);if(distributorCompany){await ensureRole(client,distributorCompany.party_id,'DISTRIBUTOR');distributorSite=await ensureSite(client,distributorCompany,'DISTRIBUTION_SITE',x.distributorAddress,{phone:x.distributorPhone,email:x.distributorEmail,website:x.distributorWeb,label:'Distribution Site'});}
  }
  await client.query(`update product.product_regulatory_profile set holder_site_id=coalesce($2,holder_site_id), importer_site_id=coalesce($3,importer_site_id),
    manufacturer_company_id=coalesce($4,manufacturer_company_id), manufacturer_site_id=coalesce($5,manufacturer_site_id),
    distributor_company_id=coalesce($6,distributor_company_id), distributor_site_id=coalesce($7,distributor_site_id),
    holder_name_snapshot=coalesce(holder_name_snapshot,$8), holder_address_snapshot=coalesce(holder_address_snapshot,$9),
    importer_name_snapshot=coalesce(importer_name_snapshot,$10), importer_address_snapshot=coalesce(importer_address_snapshot,$11)
    where id=$1`,
    [pr.id,holderSite,importerSite,manufacturerCompany?.party_id||null,manufacturerSite,distributorCompany?.party_id||null,distributorSite,
     clean(x.mah)||clean(x.importer)||null,clean(x.mahAddr)||clean(x.impAddr)||null,clean(x.importer)||clean(x.mah)||null,clean(x.impAddr)||clean(x.mahAddr)||null]);
  drugLinks++;
 }
 await client.query('commit');
 console.log(JSON.stringify({ok:true,legacyBusinessSitesAdded:legacySites,drugProfilesEnriched:drugLinks,manufacturerLinksProcessed:manufacturers},null,2));
}catch(e){await client.query('rollback');console.error(e);process.exitCode=1}
finally{client.release();await pool.end()}
