import fs from 'node:fs';
import pg from 'pg';
const cs=process.env.DATABASE_URL_DIRECT||process.env.DATABASE_URL;
if(!cs){console.log('Legacy import skipped: DATABASE_URL is not set');process.exit(0)}
const pool=new pg.Pool({connectionString:cs,max:2,application_name:'lvsp-admin4-legacy-import'});
const rows=JSON.parse(fs.readFileSync(new URL('./admin4_legacy_records.json',import.meta.url),'utf8'));
async function company(client,name,nameEn=''){
 if(!name) return null;
 let r=await client.query('select party_id from master.company where lower(legal_name_lo)=lower($1) or lower(coalesce(legal_name_en,\'\'))=lower($1) limit 1',[name]);
 if(r.rows[0]) return r.rows[0].party_id;
 const p=await client.query("insert into master.party(party_kind,display_name,status) values('COMPANY',$1,'ACTIVE') returning id",[name]);
 await client.query('insert into master.company(party_id,legal_name_lo,legal_name_en,status) values($1,$2,$3,\'ACTIVE\')',[p.rows[0].id,name,nameEn||null]);
 return p.rows[0].id;
}
let imported=0, skipped=0;
const client=await pool.connect();
try{
 for(const x of rows){
  if(x.regNo){const ex=await client.query('select 1 from product.product_regulatory_profile where registration_no=$1',[x.regNo]);if(ex.rowCount){skipped++;continue}}
  await client.query('begin');
  try{
   let type=await client.query("select id from product.product_type where code in ('VETERINARY_PHARMACEUTICAL','VETERINARY_MEDICINE','VETERINARY_PRODUCT') order by case code when 'VETERINARY_PHARMACEUTICAL' then 1 else 2 end limit 1");
   if(!type.rows[0]) type=await client.query("insert into product.product_type(code,name_lo,name_en,is_active) values('VETERINARY_PHARMACEUTICAL','ຢາສັດຕະວະແພດ','Veterinary Pharmaceutical',true) returning id");
   const pr=await client.query('insert into product.product(product_type_id,trade_name,generic_name,lifecycle_status) values($1,$2,$3,$4) returning id',[type.rows[0].id,x.tradeEn||x.tradeLo||'Legacy product',(x.actives||[]).map(a=>a.inn).filter(Boolean).join(' + ')||null,String(x.status||'DRAFT').toUpperCase()]);
   const holder=await company(client,x.mah||x.importer||'',x.mah||'');
   const importer=await company(client,x.importer||x.mah||'',x.importer||'');
   await client.query(`insert into product.product_regulatory_profile(
    product_id,registration_no,registration_type,trade_name,generic_name,category,dosage_form,registration_status,
    application_no,application_date,dlf_no,dlf_date,issue_date,expiry_date,holder_company_id,importer_company_id,
    manufacturer_name,manufacturer_country,manufacturer_address,target_species,active_ingredients,route,contraindications,warnings,gmp_reference,cpp_reference,notes,
    dosage_group,atcvet,distribution_classification,shelf_life,storage_conditions,indications,dosage_administration,
    withdrawal_meat,withdrawal_milk,withdrawal_eggs,withdrawal_honey,withdrawal_aquatic,applicant_name,applicant_nationality,applicant_id_no,business_license_no,business_license_date,distributor_name,distributor_country,distributor_address,valid_years)
    values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$40,$41,$42,$43,$44,$45,$46,$47,$48)`,[
    pr.rows[0].id,x.regNo||null,String(x.regType||'import').toUpperCase(),x.tradeEn||x.tradeLo,x.tradeEn||null,x.category||null,x.form||null,String(x.status||'draft').toUpperCase(),
    x.appNo||null,x.appDate||null,x.dlfNo||null,x.dlfDate||null,x.regDate||x.dlfDate||null,x.regExpiry||null,holder,importer,x.manufacturer||null,x.mfgCountry||null,x.mfgAddr||null,(x.species||[]).join(', '),(x.actives||[]).map(a=>[a.inn,a.strength,a.unit].filter(Boolean).join(' ')).join('; '),x.route||null,x.contra||null,x.warn||null,x.gmp||null,x.cpp||null,x.notes||null,
    x.dosageGroup||null,x.atcvet||null,x.dist||null,x.shelf||null,x.storage||null,x.indications||null,x.dosage||null,x.withdrawal?.meat||null,x.withdrawal?.milk||null,x.withdrawal?.eggs||null,x.withdrawal?.honey||null,x.withdrawal?.aqua||null,x.appName||null,x.appNationality||null,x.appIdNo||null,x.bizLicNo||null,x.bizLicDate||null,x.distributorName||null,x.distributorCountry||null,x.distributorAddress||null,Number(x.validYears)||null]);
   let pres=x.presentations||[];
   if(!pres.length && (x.pack||x.actives?.length)) pres=[{subCode:'01',strength:'',unit:'',basis:'',pack:x.pack||'',target:'',totalWeight:'',isKit:false,composition:(x.actives||[]).map(a=>({name:a.inn,role:'active',qty:a.strength||'',unit:a.unit||'',part:'',eq:''}))}];
   for(let i=0;i<pres.length;i++){
    const p=pres[i]; const sub=p.subCode||String(i+1).padStart(2,'0');
    const pk=await client.query('insert into product.package(product_id,package_code,sub_code,status,presentation_status) values($1,$2,$3,\'ACTIVE\',\'ACTIVE\') returning id',[pr.rows[0].id,(x.regNo?x.regNo+'-':'')+sub,sub]);
    const pv=await client.query(`insert into product.package_version(package_id,version_no,pack_description,status,strength_text,basis_text,target_text,total_weight_text,is_kit) values($1,1,$2,'ACTIVE',$3,$4,$5,$6,$7) returning id`,[pk.rows[0].id,p.pack||x.pack||null,[p.strength,p.unit].filter(Boolean).join(' ')||null,p.basis||null,p.target||null,p.totalWeight||null,!!p.isKit]);
    const comps=[...(p.composition||[]),...(x.commonComposition||[])];
    for(let j=0;j<comps.length;j++){const c=comps[j];if(!c.name)continue;await client.query('insert into product.package_composition(package_version_id,sequence_no,ingredient_name,ingredient_role,quantity_text,unit_text,part_text,equivalence_text) values($1,$2,$3,$4,$5,$6,$7,$8)',[pv.rows[0].id,j+1,c.name,String(c.role||'active').toUpperCase(),c.qty||null,c.unit||null,c.part||null,c.eq||null]);}
   }
   await client.query('commit'); imported++;
  }catch(e){await client.query('rollback');console.error('Legacy row failed',x.regNo,x.tradeEn,e.message);throw e}
 }
 console.log(`Legacy admin(4) migration complete: imported=${imported}, skipped_existing=${skipped}, source_records=${rows.length}`);
}finally{client.release();await pool.end()}
