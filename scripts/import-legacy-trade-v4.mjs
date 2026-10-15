import fs from 'node:fs';
import pg from 'pg';
const db=process.env.DATABASE_URL||process.env.DATABASE_MIGRATION_URL;
if(!db) throw new Error('DATABASE_URL is required');
const file=process.argv[2]||new URL('./legacy_vet_suite_export.json', import.meta.url).pathname;
const data=JSON.parse(fs.readFileSync(file,'utf8'));
const pool=new pg.Pool({connectionString:db,max:2,application_name:'lvsp-legacy-import-v6'});
const client=await pool.connect();
const norm=s=>String(s||'').toLowerCase().replace(/[^a-z0-9\u0E80-\u0EFF]+/g,'').trim();
const kindMap={DRUG:'MEDICINE',VACCINE:'VACCINE',DEVICE:'VETERINARY_DEVICE',FEEDADD:'OTHER_VETERINARY_PRODUCT'};
let companies=0,apps=0,items=0,amr=0;
try{
 await client.query('begin');
 const companyMap=new Map();
 for(const o of data.operator||[]){
   let partyId=null;
   const candidates=await client.query(`select party_id,legal_name_lo,legal_name_en from master.company`);
   for(const r of candidates.rows){ if([r.legal_name_lo,r.legal_name_en].some(x=>x&&[o.nameLo,o.nameEn].some(y=>norm(x)===norm(y)))){partyId=r.party_id;break;} }
   if(!partyId){
     const p=await client.query(`insert into master.party(party_kind,display_name,status) values('COMPANY',$1,'ACTIVE') returning id`,[o.nameLo||o.nameEn||'Legacy company']);
     partyId=p.rows[0].id;
     await client.query(`insert into master.company(party_id,legal_name_lo,legal_name_en,phone,email,enterprise_no,status) values($1,$2,$3,$4,$5,$6,'ACTIVE')`,[partyId,o.nameLo||null,o.nameEn||null,o.phone||null,o.email||null,o.licenseNo||null]);
     companies++;
   }
   companyMap.set(o.id,partyId);
 }
 const appMap=new Map();
 for(const p of data.permit||[]){
   const companyId=companyMap.get(p.operatorId); if(!companyId) continue;
   let row=(await client.query(`select id from trade.import_application where legacy_source_id=$1`,[p.id])).rows[0];
   if(!row){
     const appNo=`LEGACY-${p.id}`;
     const q=await client.query(`insert into trade.import_application(application_no,company_id,application_date,import_type,border_checkpoint,invoice_no,origin_country,transport_information,status,decision_no,decision_date,permit_no,permit_valid_to,notes,legacy_source_id,legacy_source,signed_by,purpose,valid_from,cleared_date,destination_country,checkpoint_out,transport_mode) values($1,$2,$3,'IMPORT',$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22) returning id`,[
       appNo,companyId,p.appDate||p.validFrom||new Date().toISOString().slice(0,10),p.checkpointIn||null,p.invoiceNo||null,p.originCountry||null,p.transport||null,String(p.status||'CLEARED').toUpperCase(),p.permitNo||null,p.decisionDate||null,p.permitNo||null,p.validTo||null,p.decisionNote||null,p.id,p.source||'legacy',p.signedBy||null,p.purpose||null,p.validFrom||null,p.clearedDate||null,p.destCountry||null,p.checkpointOut||null,p.transport||null]);
     row=q.rows[0]; apps++;
   }
   appMap.set(p.id,row.id);
 }
 for(const x of data.permit_item||[]){
   const applicationId=appMap.get(x.permitId); if(!applicationId) continue;
   const exists=(await client.query(`select 1 from trade.import_application_item where legacy_source_id=$1`,[x.id])).rowCount; if(exists) continue;
   const itemType=kindMap[x.kind]||'OTHER_VETERINARY_PRODUCT';
   await client.query(`insert into trade.import_application_item(application_id,item_no,item_type,item_name,registration_no,package_description,requested_quantity,approved_quantity,cleared_quantity,unit_code,item_value,currency_code,eligibility_status,eligibility_message,notes,legacy_source_id,legacy_kind,sub_code,gross_weight_kg,cleared_packs,amr_use,amr_group,amr_route,kg_override,batch_lot_no,manufacture_date,expiry_date) values($1,$2,$3,$4,$5,$6,$7,$7,$8,$9,$10,'USD','REVIEW_REQUIRED','Migrated from legacy DLF Vet Suite; verify product/registration linkage before regulatory reuse',$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23)`,[
     applicationId,Number(x.lineNo||1),itemType,x.name||x.nameEn||'Legacy item',x.regNo||null,x.packDesc||null,Number(x.packs||0),Number(x.packsCleared??x.packs??0),null,Number(x.valueUsd||0),`Legacy ${x.kind||''}`,x.id,x.kind||null,x.subCode||null,Number(x._kgGross||0),Number(x.packsCleared??0),x.amUse||null,x.amGroup||null,x.amRoute||null,x.kgOverride||{},x.batchNo||null,x.mfgDate||null,x.expDate||null]);
   items++;
 }
 for(const a of data.amr_substance||[]){
   const q=await client.query(`insert into analytics.amr_substance_reference(substance_key,substance_name_en,animuse_class_code,iu_per_mg,ionophore,source,legacy_source_id) values($1,$2,$3,$4,$5,$6,$7) on conflict(substance_key) do update set animuse_class_code=excluded.animuse_class_code,iu_per_mg=excluded.iu_per_mg,ionophore=excluded.ionophore,source=excluded.source,legacy_source_id=coalesce(analytics.amr_substance_reference.legacy_source_id,excluded.legacy_source_id) returning id`,[a.skey,a.nameEn||a.skey,a.classK||null,a.iuPerMg??null,!!a.ionophore,a.source||'legacy',a.id]);
   if(q.rowCount) amr++;
 }
 await client.query('commit');
 console.log(JSON.stringify({ok:true,companiesCreated:companies,applicationsCreated:apps,itemsCreated:items,amrReferencesUpserted:amr,sourceMeta:data._meta},null,2));
}catch(e){await client.query('rollback');throw e}finally{client.release();await pool.end()}
