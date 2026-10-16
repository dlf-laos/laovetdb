// PostgreSQL/Neon persistence adapter for the approved LVSP physical schema.
// Activated only when LVSP_STORAGE=postgres. Requires the free open-source `pg` package.
// @ts-nocheck
import crypto from 'node:crypto';
import {hashPassword,verifyPassword,validatePasswordPolicy} from './auth.js';

const TABLES:any={
 users:{table:'security.app_user'}, organizations:{table:'master.organization'}, admin_units:{table:'master.admin_unit'},
 persons:{table:'master.person',pk:'party_id'}, companies:{table:'master.company',pk:'party_id'}, facilities:{table:'master.facility'},
 services:{table:'system.service_definition'}, workflows:{table:'workflow.definition'}, tasks:{table:'workflow.task'}, documents:{table:'document.document'},
 applications:{table:'casework.application'}, cases:{table:'casework.regulatory_case'}, decisions:{table:'casework.regulatory_decision'},
 registrations:{table:'registration.registration'}, licenses:{table:'licensing.license'}, certificates:{table:'document.certificate'},
 products:{table:'product.product'}, feed:{table:'feed.feed_profile',pk:'product_id'}, farms:{table:'farm.farm',pk:'facility_id'}, animals:{table:'animal.animal'}, movements:{table:'animal.movement'},
 diseases:{table:'disease.disease'}, disease_cases:{table:'disease.disease_case'}, outbreaks:{table:'disease.outbreak'}, vaccination_campaigns:{table:'disease.vaccination_campaign'},
 inspections:{table:'inspection.inspection_case'}, findings:{table:'inspection.finding'}, capa:{table:'compliance.capa'}, enforcement_cases:{table:'enforcement.enforcement_case'},
 laboratory_samples:{table:'laboratory.sample'}, laboratory_test_requests:{table:'laboratory.test_request'}, laboratory_results:{table:'laboratory.result'},
 trade_operators:{table:'trade.operator'}, trade_permits:{table:'trade.permit'}, trade_shipments:{table:'trade.shipment'},
 drug_registrations:{table:'product.product_regulatory_profile'}, veterinary_devices:{table:'product.veterinary_device'},
 import_plans:{table:'trade.import_plan'}, import_plan_items:{table:'trade.import_plan_item'}, import_applications:{table:'trade.import_application'}, import_application_items:{table:'trade.import_application_item'},
 aquaculture_facilities:{table:'fisheries.aquaculture_facility',pk:'facility_id'}, aquaculture_stock_batches:{table:'fisheries.stock_batch'},
 gis_layers:{table:'gis.layer'}, integrations:{table:'integration.system'}, reports:{table:'analytics.dashboard_definition'},
 information_requests:{table:'casework.information_request'},
 facility_establishment_applications:{table:'facility.establishment_application'}, production_lines:{table:'facility.production_line'}, gmp_assessments:{table:'facility.gmp_assessment'},
 product_versions:{table:'product.product_version'}, product_packages:{table:'product.package'}, package_versions:{table:'product.package_version'}, package_compositions:{table:'product.package_composition'}, product_batches:{table:'product.batch'}, feed_formulas:{table:'feed.formula'},
 inspection_visits:{table:'inspection.visit'}, sample_custody_events:{table:'laboratory.sample_custody_event'}, disease_investigations:{table:'disease.investigation'},
 outbreak_zones:{table:'disease.zone'}, outbreak_control_measures:{table:'disease.control_measure'}, enforcement_actions:{table:'enforcement.action'}, enforcement_appeals:{table:'enforcement.appeal'},
 aquaculture_production:{table:'fisheries.production_record'}, aquaculture_harvest:{table:'fisheries.harvest'},
 department_work_items:{table:'reporting.department_work_item'},department_budget_entries:{table:'reporting.department_budget_entry'},
 provincial_reports:{table:'reporting.report_submission'},
 export_application_details:{table:'trade.export_application_detail'}, export_application_items:{table:'trade.export_application_item'}
};

function snake(s:string){return s.replace(/[A-Z]/g,m=>'_'+m.toLowerCase())}
function camel(s:string){return s.replace(/_([a-z])/g,(_,c)=>c.toUpperCase())}
function camelRow(row:any){return Object.fromEntries(Object.entries(row).map(([k,v])=>[camel(k),v]))}
function normalized(row:any,pk='id'){const r=camelRow(row);const pkc=camel(pk);if(!r.id&&r[pkc])r.id=r[pkc];return r}
function quoteIdent(x:string){if(!/^[a-z_][a-z0-9_]*$/i.test(x))throw new Error('Unsafe identifier');return `"${x}"`}
function tableSql(full:string){const [s,t]=full.split('.');return `${quoteIdent(s)}.${quoteIdent(t)}`}
function isUuid(v:any){return typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v)}

export class PostgresStore {
  mode='postgres'; pool:any; columns=new Map();
  static async create(connectionString:string){
    const transport=process.env.LVSP_PG_TRANSPORT||'tcp';
    if(!['tcp','neon-ws'].includes(transport))throw new Error('Unsupported LVSP_PG_TRANSPORT');
    let mod:any;
    if(transport==='neon-ws'){
      const url=new URL(connectionString);
      if(!url.hostname.endsWith('.neon.tech'))throw new Error('neon-ws requires a Neon database hostname');
      mod=await import('@neondatabase/serverless');
      mod.neonConfig.webSocketConstructor=WebSocket;
    }else mod=await import('pg');
    const pool=new mod.Pool({connectionString,max:Number(process.env.DB_POOL_MAX||10),application_name:'lvsp-api',connectionTimeoutMillis:10000});
    pool.on('error',(error:any)=>console.error('LVSP idle database connection error:',error.code||'CONNECTION_ERROR'));
    try{await pool.query('select 1');return new PostgresStore(pool)}catch(error){await pool.end().catch(()=>{});throw error}
  }
  constructor(pool:any){this.pool=pool}
  info(resource:string){const i=TABLES[resource];if(!i)throw Object.assign(new Error(`PostgreSQL mapping not configured for ${resource}`),{statusCode:501,code:'POSTGRES_MAPPING_MISSING'});return {...i,pk:i.pk||'id'}}
  async getColumns(full:string){if(this.columns.has(full))return this.columns.get(full);const [schema,table]=full.split('.');const r=await this.pool.query('select column_name from information_schema.columns where table_schema=$1 and table_name=$2',[schema,table]);const set=new Set(r.rows.map((x:any)=>x.column_name));this.columns.set(full,set);return set}
  async list(resource:string){const i=this.info(resource);const cols=await this.getColumns(i.table);const order=cols.has('created_at')?' order by created_at desc':' ';const r=await this.pool.query(`select * from ${tableSql(i.table)}${order} limit 500`);return r.rows.map((x:any)=>normalized(x,i.pk))}
  async get(resource:string,id:string){const i=this.info(resource);const r=await this.pool.query(`select * from ${tableSql(i.table)} where ${quoteIdent(i.pk)}=$1 limit 1`,[id]);return r.rows[0]?normalized(r.rows[0],i.pk):undefined}
  async find(resource:string,predicate:any){const rows=await this.list(resource);return rows.find(predicate)}
  async create(resource:string,input:any){
    // Party subtypes need a transaction so FK integrity is preserved.
    if(resource==='companies'||resource==='persons'){
      const client=await this.pool.connect();
      try{
        await client.query('begin');
        const kind=resource==='companies'?'COMPANY':'PERSON';
        const display=resource==='companies'?(input.legalNameLo||input.legalNameEn||input.displayName||'Company'):[input.firstNameLo,input.lastNameLo].filter(Boolean).join(' ')||input.displayName||'Person';
        const pr=await client.query('insert into master.party(party_kind,display_name,status) values($1,$2,$3) returning id',[kind,display,input.status||'ACTIVE']);
        const partyId=pr.rows[0].id;
        const i=this.info(resource);const cols=await this.getColumns(i.table);
        const data={...input,partyId};
        const entries=Object.entries(data).map(([k,v])=>[snake(k),v]).filter(([k])=>cols.has(k));
        const names=entries.map(([k])=>quoteIdent(k)).join(',');const values=entries.map((_,idx)=>`$${idx+1}`).join(',');
        const r=await client.query(`insert into ${tableSql(i.table)} (${names}) values (${values}) returning *`,entries.map(([,v])=>v));
        await client.query('commit');return normalized(r.rows[0],i.pk);
      }catch(e){await client.query('rollback');throw e}finally{client.release()}
    }
    if(resource==='products'){
      const i=this.info(resource); const cols=await this.getColumns(i.table);
      let productTypeId=input?.productTypeId;
      if(!productTypeId){
        const code=String(input?.productTypeCode||'VETERINARY_PHARMACEUTICAL');
        const tr=await this.pool.query('select id from product.product_type where code=$1 and is_active=true limit 1',[code]);
        if(!tr.rows[0]) throw Object.assign(new Error(`Unknown product type: ${code}`),{statusCode:400,code:'INVALID_PRODUCT_TYPE'});
        productTypeId=tr.rows[0].id;
      }
      const data={...input,productTypeId}; delete data.productTypeCode;
      const entries=Object.entries(data||{}).map(([k,v])=>[snake(k),v]).filter(([k])=>cols.has(k));
      const names=entries.map(([k])=>quoteIdent(k)).join(','); const values=entries.map((_,idx)=>`$${idx+1}`).join(',');
      const r=await this.pool.query(`insert into ${tableSql(i.table)} (${names}) values (${values}) returning *`,entries.map(([,v])=>v));
      return normalized(r.rows[0],i.pk);
    }
    if((resource==='import_plans'||resource==='import_applications') && input?.companySiteId){
      const ok=await this.pool.query("select 1 from master.company_site where company_id=$1 and facility_id=$2 and status='ACTIVE' limit 1",[input.companyId,input.companySiteId]);
      if(!ok.rows[0])throw Object.assign(new Error('Selected company site does not belong to the selected company'),{statusCode:400,code:'COMPANY_SITE_MISMATCH'});
    }
    const i=this.info(resource);const cols=await this.getColumns(i.table);const entries=Object.entries(input||{}).map(([k,v])=>[snake(k),v]).filter(([k])=>cols.has(k));if(!entries.length){const r=await this.pool.query(`insert into ${tableSql(i.table)} default values returning *`);return normalized(r.rows[0],i.pk)}const names=entries.map(([k])=>quoteIdent(k)).join(',');const values=entries.map((_,idx)=>`$${idx+1}`).join(',');const r=await this.pool.query(`insert into ${tableSql(i.table)} (${names}) values (${values}) returning *`,entries.map(([,v])=>v));return normalized(r.rows[0],i.pk)}
  async update(resource:string,id:string,patch:any){
    if(resource==='companies'){
      const client=await this.pool.connect();
      try{await client.query('begin');const i=this.info(resource);const cols=await this.getColumns(i.table);const entries=Object.entries(patch||{}).map(([k,v])=>[snake(k),v]).filter(([k])=>cols.has(k)&&k!==i.pk);let row:any=await this.get(resource,id);if(entries.length){const set=entries.map(([k],idx)=>`${quoteIdent(k)}=$${idx+1}`).join(',');const r=await client.query(`update ${tableSql(i.table)} set ${set} where ${quoteIdent(i.pk)}=$${entries.length+1} returning *`,[...entries.map(([,v])=>v),id]);row=r.rows[0]?normalized(r.rows[0],i.pk):undefined;}const display=patch?.legalNameLo||patch?.legalNameEn;if(display)await client.query('update master.party set display_name=$1,updated_at=now() where id=$2',[display,id]);await client.query('commit');return row;}catch(e){await client.query('rollback');throw e}finally{client.release()}
    }
    const i=this.info(resource);const cols=await this.getColumns(i.table);const entries=Object.entries(patch||{}).map(([k,v])=>[snake(k),v]).filter(([k])=>cols.has(k)&&k!==i.pk);if(!entries.length)return this.get(resource,id);const set=entries.map(([k],idx)=>`${quoteIdent(k)}=$${idx+1}`).join(',');const r=await this.pool.query(`update ${tableSql(i.table)} set ${set} where ${quoteIdent(i.pk)}=$${entries.length+1} returning *`,[...entries.map(([,v])=>v),id]);return r.rows[0]?normalized(r.rows[0],i.pk):undefined}
  async audit(event:any){const actor=isUuid(event.actorUserId)?event.actorUserId:null;await this.pool.query(`insert into audit.event(actor_user_id,action_code,resource_type,resource_id,correlation_id,before_data,after_data,metadata) values($1,$2,$3,$4,$5,$6,$7,$8)`,[actor,event.actionCode,event.resourceType,isUuid(event.resourceId)?event.resourceId:null,isUuid(event.correlationId)?event.correlationId:null,event.beforeData||null,event.afterData||null,{...event,actorUserId:event.actorUserId}])}
  async enqueue(event:any){if(!isUuid(event.aggregateId))return;await this.pool.query(`insert into integration.outbox_event(event_type,aggregate_type,aggregate_id,schema_version,correlation_id,payload) values($1,$2,$3,$4,$5,$6)`,[event.eventType,event.aggregateType,event.aggregateId,1,isUuid(event.correlationId)?event.correlationId:null,event.payload||{}])}
  async auditEvents(){const r=await this.pool.query('select * from audit.event order by occurred_at desc limit 500');return r.rows.map((x:any)=>normalized(x,'id'))}
  async outboxEvents(){const r=await this.pool.query('select * from integration.outbox_event order by occurred_at desc limit 500');return r.rows.map((x:any)=>normalized(x,'id'))}

  async normalizeDrugPartyLinks(input:any){
    const p={...(input||{})};
    const resolveCompany=async(id:any)=>{if(!id)return null;const r=await this.pool.query('select legal_name_lo,legal_name_en from master.company where party_id=$1',[id]);return r.rows[0]||null};
    const resolveSite=async(id:any)=>{if(!id)return null;const r=await this.pool.query('select address_text_lo,address_text_en from master.facility where id=$1',[id]);return r.rows[0]||null};
    const assertSite=async(companyId:any,siteId:any,label:string)=>{if(!siteId)return; if(!companyId)throw Object.assign(new Error(`${label} site requires a company`),{statusCode:400,code:'COMPANY_REQUIRED_FOR_SITE'}); const r=await this.pool.query("select 1 from master.company_site where company_id=$1 and facility_id=$2 and status='ACTIVE' limit 1",[companyId,siteId]); if(!r.rows[0])throw Object.assign(new Error(`${label} site does not belong to the selected company`),{statusCode:400,code:'COMPANY_SITE_MISMATCH'});};
    await assertSite(p.holderCompanyId,p.holderSiteId,'Holder'); await assertSite(p.importerCompanyId,p.importerSiteId,'Importer'); await assertSite(p.manufacturerCompanyId,p.manufacturerSiteId,'Manufacturer'); await assertSite(p.distributorCompanyId,p.distributorSiteId,'Distributor');
    const h=await resolveCompany(p.holderCompanyId), hs=await resolveSite(p.holderSiteId);
    const i=await resolveCompany(p.importerCompanyId), ims=await resolveSite(p.importerSiteId);
    const m=await resolveCompany(p.manufacturerCompanyId), ms=await resolveSite(p.manufacturerSiteId);
    const d=await resolveCompany(p.distributorCompanyId), ds=await resolveSite(p.distributorSiteId);
    if(h){p.holderNameSnapshot=p.holderNameSnapshot||h.legal_name_lo||h.legal_name_en||null;}
    if(hs){p.holderAddressSnapshot=p.holderAddressSnapshot||hs.address_text_lo||hs.address_text_en||null;}
    if(i){p.importerNameSnapshot=p.importerNameSnapshot||i.legal_name_lo||i.legal_name_en||null;}
    if(ims){p.importerAddressSnapshot=p.importerAddressSnapshot||ims.address_text_lo||ims.address_text_en||null;}
    if(m){p.manufacturerName=p.manufacturerName||m.legal_name_lo||m.legal_name_en||null;}
    if(ms){p.manufacturerAddress=p.manufacturerAddress||ms.address_text_lo||ms.address_text_en||null;}
    if(d){p.distributorName=p.distributorName||d.legal_name_lo||d.legal_name_en||null;}
    if(ds){p.distributorAddress=p.distributorAddress||ds.address_text_lo||ds.address_text_en||null;}
    return p;
  }
  drugRegistrationPrefix(registrationType:any){const t=String(registrationType||'IMPORT').toUpperCase();return t==='DOMESTIC'?'L':t==='REPACK'?'R':'F'}
  async veterinaryDrugReferenceData(){
    const r=await this.pool.query(`select domain_code,code,parent_code,value_text,name_lo,name_en,sort_order,source_system,source_reference,metadata
      from lookup.veterinary_drug_reference_term where is_active=true order by domain_code,sort_order,code`);
    const out:any={categories:[],dosageGroups:[],dosageForms:[],distributions:[],routes:[],atcvet:[],registrationTypes:[
      {code:'IMPORT',prefix:'F',nameLo:'ນຳເຂົ້າ',nameEn:'Imported'},
      {code:'DOMESTIC',prefix:'L',nameLo:'ຜະລິດພາຍໃນ',nameEn:'Domestic'},
      {code:'REPACK',prefix:'R',nameLo:'ນຳເຂົ້າມາບັນຈຸ/ແບ່ງບັນຈຸພາຍໃນ',nameEn:'Repacked'}]};
    const key:any={CATEGORY:'categories',DOSAGE_GROUP:'dosageGroups',DOSAGE_FORM:'dosageForms',DISTRIBUTION:'distributions',ROUTE:'routes',ATCVET:'atcvet'};
    for(const row of r.rows){const k=key[row.domain_code];if(k)out[k].push(camelRow(row));}
    return out;
  }
  async previewDrugRegistrationNo(registrationType:any){
    const prefix=this.drugRegistrationPrefix(registrationType);const floor=prefix==='F'?200:0;
    const q=await this.pool.query(`select coalesce(max((regexp_match(registration_no,'-([0-9]{3,4})$'))[1]::int),0) n
      from product.product_regulatory_profile where registration_no like $1`,[`ຢສ-${prefix}%`]);
    const seq=await this.pool.query('select coalesce(max(last_no),0) n from product.veterinary_registration_number_sequence where prefix=$1',[prefix]);
    const next=Math.max(floor,Number(q.rows[0]?.n||0),Number(seq.rows[0]?.n||0))+1;
    const d=new Date();const ym=String(d.getUTCFullYear())+String(d.getUTCMonth()+1).padStart(2,'0');
    return {registrationType:String(registrationType||'IMPORT').toUpperCase(),prefix,registrationNo:`ຢສ-${prefix}-${ym}-${String(next).padStart(4,'0')}`,sequenceNo:next,yearMonth:ym};
  }
  async allocateDrugRegistrationNo(registrationType:any){
    const prefix=this.drugRegistrationPrefix(registrationType);const floor=prefix==='F'?200:0;const d=new Date();const ym=String(d.getUTCFullYear())+String(d.getUTCMonth()+1).padStart(2,'0');
    const client=await this.pool.connect();
    try{
      await client.query('begin');
      await client.query(`insert into product.veterinary_registration_number_sequence(prefix,year_month,last_no) values($1,$2,0) on conflict(prefix,year_month) do nothing`,[prefix,ym]);
      const row=(await client.query('select last_no from product.veterinary_registration_number_sequence where prefix=$1 and year_month=$2 for update',[prefix,ym])).rows[0];
      const q=await client.query(`select coalesce(max((regexp_match(registration_no,'-([0-9]{3,4})$'))[1]::int),0) n from product.product_regulatory_profile where registration_no like $1`,[`ຢສ-${prefix}%`]);
      const next=Math.max(floor,Number(row?.last_no||0),Number(q.rows[0]?.n||0))+1;
      await client.query('update product.veterinary_registration_number_sequence set last_no=$1,updated_at=now() where prefix=$2 and year_month=$3',[next,prefix,ym]);
      await client.query('commit');return `ຢສ-${prefix}-${ym}-${String(next).padStart(4,'0')}`;
    }catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
  }
  async assertDrugRegistrationNoAvailable(registrationNo:any,excludeId:any=null){
    if(!registrationNo)return;
    const r=excludeId?await this.pool.query('select id from product.product_regulatory_profile where registration_no=$1 and id<>$2 limit 1',[registrationNo,excludeId]):await this.pool.query('select id from product.product_regulatory_profile where registration_no=$1 limit 1',[registrationNo]);
    if(r.rows[0])throw Object.assign(new Error('Registration number already exists'),{statusCode:409,code:'DUPLICATE_REGISTRATION_NO'});
  }
  calculateDrugExpiry(issueDate:any,validYears:any){
    if(!issueDate||validYears===null||validYears===undefined||validYears===''||Number(validYears)<=0)return null;
    const m=String(issueDate).slice(0,10).match(/^(\d{4})-(\d{2})-(\d{2})$/);if(!m)return null;
    const year=Number(m[1])+Number(validYears),month=Number(m[2]),day=Number(m[3]);
    const last=new Date(Date.UTC(year,month,0)).getUTCDate();return `${year}-${String(month).padStart(2,'0')}-${String(Math.min(day,last)).padStart(2,'0')}`;
  }
  async prepareDrugRegulatoryProfile(input:any,opts:any={}){
    const p={...(input||{})};p.registrationType=String(p.registrationType||'IMPORT').toUpperCase();
    const source=String(p.registrationNumberSource||opts.registrationNumberSource||'').toUpperCase();
    if(opts.create && (source==='AUTO'||!p.registrationNo)){p.registrationNo=await this.allocateDrugRegistrationNo(p.registrationType);p.registrationNumberSource='AUTO';}
    else {p.registrationNumberSource=source==='MANUAL'?'MANUAL':(p.registrationNumberSource||'LEGACY');await this.assertDrugRegistrationNoAvailable(p.registrationNo,opts.excludeId||null);}
    if(p.dlfDate){p.issueDate=String(p.dlfDate).slice(0,10);}
    if(Object.prototype.hasOwnProperty.call(p,'validYears')||p.dlfDate||p.issueDate){
      if(p.validYears===null||p.validYears===''||Number(p.validYears)<=0){p.validYears=null;p.expiryDate=null;}
      else {p.validYears=Number(p.validYears);p.expiryDate=this.calculateDrugExpiry(p.issueDate||p.dlfDate,p.validYears);}
    }
    delete p.registrationNoMode;delete p._registrationNoMode;
    return p;
  }
  async drugRegistrationComplete(id:string){
    const pr=await this.pool.query(`select pr.*,
      h.legal_name_lo holder_name_lo,h.legal_name_en holder_name_en,
      i.legal_name_lo importer_name_lo,i.legal_name_en importer_name_en,
      m.legal_name_lo manufacturer_company_name_lo,m.legal_name_en manufacturer_company_name_en,
      d.legal_name_lo distributor_company_name_lo,d.legal_name_en distributor_company_name_en,
      hs.address_text_lo holder_site_address_lo,hs.address_text_en holder_site_address_en,
      ims.address_text_lo importer_site_address_lo,ims.address_text_en importer_site_address_en,
      ms.address_text_lo manufacturer_site_address_lo,ms.address_text_en manufacturer_site_address_en,
      ds.address_text_lo distributor_site_address_lo,ds.address_text_en distributor_site_address_en
      from product.product_regulatory_profile pr
      left join master.company h on h.party_id=pr.holder_company_id
      left join master.company i on i.party_id=pr.importer_company_id
      left join master.company m on m.party_id=pr.manufacturer_company_id
      left join master.company d on d.party_id=pr.distributor_company_id
      left join master.facility hs on hs.id=pr.holder_site_id
      left join master.facility ims on ims.id=pr.importer_site_id
      left join master.facility ms on ms.id=pr.manufacturer_site_id
      left join master.facility ds on ds.id=pr.distributor_site_id
      where pr.id=$1`,[id]);
    if(!pr.rows[0]) return undefined;
    const profile=normalized(pr.rows[0],'id');
    profile.holderCompanyName=pr.rows[0].holder_name_snapshot||pr.rows[0].holder_name_lo||pr.rows[0].holder_name_en||null;
    profile.holderAddress=pr.rows[0].holder_address_snapshot||pr.rows[0].holder_site_address_lo||pr.rows[0].holder_site_address_en||null;
    profile.importerCompanyName=pr.rows[0].importer_name_snapshot||pr.rows[0].importer_name_lo||pr.rows[0].importer_name_en||null;
    profile.importerAddress=pr.rows[0].importer_address_snapshot||pr.rows[0].importer_site_address_lo||pr.rows[0].importer_site_address_en||null;
    profile.manufacturerCompanyName=pr.rows[0].manufacturer_company_name_lo||pr.rows[0].manufacturer_company_name_en||pr.rows[0].manufacturer_name||null;
    profile.manufacturerSiteAddress=pr.rows[0].manufacturer_site_address_lo||pr.rows[0].manufacturer_site_address_en||pr.rows[0].manufacturer_address||null;
    profile.distributorCompanyName=pr.rows[0].distributor_company_name_lo||pr.rows[0].distributor_company_name_en||pr.rows[0].distributor_name||null;
    profile.distributorSiteAddress=pr.rows[0].distributor_site_address_lo||pr.rows[0].distributor_site_address_en||pr.rows[0].distributor_address||null;
    const productId=pr.rows[0].product_id;
    const pk=await this.pool.query(`select p.*,pv.id package_version_id,pv.version_no,pv.pack_description,pv.container_type,pv.strength_text,pv.basis_text,pv.target_text,pv.total_weight_text,pv.is_kit
      from product.package p
      left join lateral (select * from product.package_version where package_id=p.id order by version_no desc limit 1) pv on true
      where p.product_id=$1 and coalesce(p.presentation_status,'ACTIVE')<>'INACTIVE'
      order by p.sub_code nulls first,p.created_at`,[productId]);
    const presentations=[];
    for(const r of pk.rows){const c=r.package_version_id?(await this.pool.query('select * from product.package_composition where package_version_id=$1 order by sequence_no',[r.package_version_id])).rows:[];presentations.push({...normalized(r,'id'),composition:c.map((x:any)=>normalized(x,'id'))});}
    return {profile,presentations};
  }
  async updateDrugRegistrationComplete(id:string,payload:any){
    const client=await this.pool.connect();
    try{
      await client.query('begin');
      const current=(await client.query('select * from product.product_regulatory_profile where id=$1 for update',[id])).rows[0];
      if(!current){await client.query('rollback');return undefined;}
      let profile=await this.prepareDrugRegulatoryProfile(payload?.profile||{},{create:false,excludeId:id}); profile=await this.normalizeDrugPartyLinks(profile); const presentations=Array.isArray(payload?.presentations)?payload.presentations:[];
      if(!profile.tradeName||!presentations.length) throw Object.assign(new Error('Trade name and at least one presentation are required'),{statusCode:400,code:'INVALID_DRUG_REGISTRATION'});
      const pcols=await this.getColumns('product.product_regulatory_profile');
      const pentries=Object.entries(profile).map(([k,v])=>[snake(k),v]).filter(([k])=>pcols.has(k)&&!['id','product_id','created_at'].includes(k));
      if(pentries.length){const set=pentries.map(([k],n)=>`${quoteIdent(k)}=$${n+1}`).join(',');await client.query(`update product.product_regulatory_profile set ${set},updated_at=now() where id=$${pentries.length+1}`,[...pentries.map(([,v])=>v),id]);}
      const productStatus=String(profile.registrationStatus||current.registration_status||'DRAFT').toUpperCase()==='ACTIVE'?'ACTIVE':'DRAFT';
      await client.query('update product.product set trade_name=$1,generic_name=$2,product_code=coalesce($3,product_code),lifecycle_status=$4 where id=$5',[profile.tradeName,profile.genericName||null,profile.registrationNo||null,productStatus,current.product_id]);
      const kept:string[]=[];
      for(let idx=0;idx<presentations.length;idx++){
        const p=presentations[idx]||{}; const sub=String(p.subCode||String(idx+1).padStart(2,'0')).trim();
        let pkg=(await client.query('select * from product.package where product_id=$1 and sub_code=$2 limit 1',[current.product_id,sub])).rows[0];
        const packageCode=(profile.registrationNo?profile.registrationNo+'-':'')+sub;
        if(!pkg){pkg=(await client.query(`insert into product.package(product_id,package_code,status,sub_code,presentation_status) values($1,$2,'ACTIVE',$3,'ACTIVE') returning *`,[current.product_id,packageCode,sub])).rows[0];}
        else await client.query(`update product.package set package_code=$1,status='ACTIVE',presentation_status='ACTIVE' where id=$2`,[packageCode,pkg.id]);
        kept.push(pkg.id);
        const vn=Number((await client.query('select coalesce(max(version_no),0)+1 n from product.package_version where package_id=$1',[pkg.id])).rows[0].n);
        const pv=(await client.query(`insert into product.package_version(package_id,version_no,pack_description,container_type,status,strength_text,basis_text,target_text,total_weight_text,is_kit,effective_from)
          values($1,$2,$3,$4,'ACTIVE',$5,$6,$7,$8,$9,current_date) returning id`,[pkg.id,vn,p.packDescription||null,p.containerType||null,p.strengthText||null,p.basisText||null,p.targetText||null,p.totalWeightText||null,!!p.isKit])).rows[0];
        for(let j=0;j<(p.composition||[]).length;j++){const c=p.composition[j]||{};if(!c.ingredientName)continue;await client.query(`insert into product.package_composition(package_version_id,sequence_no,ingredient_name,ingredient_role,quantity_text,unit_text,part_text,equivalence_text) values($1,$2,$3,$4,$5,$6,$7,$8)`,[pv.id,j+1,c.ingredientName,c.ingredientRole||'ACTIVE',c.quantityText||null,c.unitText||null,c.partText||null,c.equivalenceText||null]);}
      }
      if(kept.length)await client.query(`update product.package set presentation_status='INACTIVE' where product_id=$1 and not (id=any($2::uuid[]))`,[current.product_id,kept]);
      await client.query('commit'); return this.drugRegistrationComplete(id);
    }catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
  }
  async importPlanComplete(id:string){
    const a=await this.pool.query(`select ip.*,pp.detail_level,pp.movement_type,pp.service_type,c.legal_name_lo,c.legal_name_en,c.phone,c.email,s.name_lo company_site_name_lo,s.name_en company_site_name_en,s.address_text_lo company_site_address_lo,s.address_text_en company_site_address_en from trade.import_plan ip join master.company c on c.party_id=ip.company_id left join trade.import_plan_profile pp on pp.import_plan_id=ip.id left join master.facility s on s.id=ip.company_site_id where ip.id=$1`,[id]);
    if(!a.rows[0]) return undefined;
    const items=await this.pool.query('select * from trade.import_plan_item where plan_id=$1 order by item_no',[id]);
    return {plan:normalized(a.rows[0],'id'),items:items.rows.map((x:any)=>normalized(x,'id'))};
  }
  async importApplicationComplete(id:string){
    const a=await this.pool.query(`select ia.*,c.legal_name_lo,c.legal_name_en,c.phone,c.email,s.name_lo company_site_name_lo,s.name_en company_site_name_en,s.address_text_lo company_site_address_lo,s.address_text_en company_site_address_en from trade.import_application ia join master.company c on c.party_id=ia.company_id left join master.facility s on s.id=ia.company_site_id where ia.id=$1`,[id]);
    if(!a.rows[0]) return undefined;
    const items=await this.pool.query('select * from trade.import_application_item where application_id=$1 order by item_no',[id]);
    return {application:normalized(a.rows[0],'id'),items:items.rows.map((x:any)=>normalized(x,'id'))};
  }
  async animuseSummary(year?:number){
    const params:any[]=[]; let wh=''; if(year){params.push(year);wh='where extract(year from ia.application_date)=$1';}
    const q=await this.pool.query(`select coalesce(iai.legacy_kind,iai.item_type) kind,count(*)::int item_count,coalesce(sum(iai.cleared_quantity),0) cleared_quantity,coalesce(sum(iai.item_value),0) value_usd,coalesce(sum(iai.gross_weight_kg),0) gross_weight_kg from trade.import_application_item iai join trade.import_application ia on ia.id=iai.application_id ${wh} group by 1 order by 1`,params);
    const r=await this.pool.query('select animuse_class_code,count(*)::int substances from analytics.amr_substance_reference group by animuse_class_code order by animuse_class_code');
    return {year:year||null,importSummary:q.rows.map((x:any)=>camelRow(x)),substanceReference:r.rows.map((x:any)=>camelRow(x))};
  }

  async companyRoleTypes(){const r=await this.pool.query("select code,name_lo,name_en from master.party_role_type where is_active=true and (allowed_party_kind is null or allowed_party_kind='COMPANY') order by name_en nulls last,code");return r.rows.map((x:any)=>camelRow(x));}
  async setCompanyRoles(companyId:string,codes:any[]){
    const desired=[...new Set((codes||[]).map(x=>String(x||'').toUpperCase()).filter(Boolean))];const client=await this.pool.connect();
    try{await client.query('begin');const c=await client.query('select 1 from master.company where party_id=$1',[companyId]);if(!c.rows[0])throw Object.assign(new Error('Company not found'),{statusCode:404,code:'COMPANY_NOT_FOUND'});
      const types=await client.query("select id,code from master.party_role_type where is_active=true and (allowed_party_kind is null or allowed_party_kind='COMPANY')");const byCode=new Map(types.rows.map((x:any)=>[x.code,x.id]));for(const code of desired)if(!byCode.has(code))throw Object.assign(new Error(`Invalid company role: ${code}`),{statusCode:400,code:'INVALID_COMPANY_ROLE'});
      const active=await client.query("select pra.id,prt.code from master.party_role_assignment pra join master.party_role_type prt on prt.id=pra.role_type_id where pra.party_id=$1 and pra.status='ACTIVE' and pra.valid_to is null",[companyId]);
      for(const x of active.rows)if(!desired.includes(x.code))await client.query("update master.party_role_assignment set status='INACTIVE',valid_to=current_date where id=$1",[x.id]);
      const activeCodes=new Set(active.rows.map((x:any)=>x.code));for(const code of desired)if(!activeCodes.has(code))await client.query("insert into master.party_role_assignment(party_id,role_type_id,valid_from,status) values($1,$2,current_date,'ACTIVE')",[companyId,byCode.get(code)]);
      await client.query('commit');return this.companyComplete(companyId);
    }catch(e){await client.query('rollback');throw e}finally{client.release()}
  }
  async countries(){const r=await this.pool.query('select id,iso2_code,iso3_code,name_lo,name_en from lookup.country where is_active=true order by name_en nulls last,name_lo');return r.rows.map((x:any)=>normalized(x,'id'));}
  async species(){const r=await this.pool.query('select id,code,name_lo,name_en from lookup.species where is_active=true order by name_lo');return r.rows.map((x:any)=>normalized(x,'id'));}
  async unitsOfMeasure(){const r=await this.pool.query('select id,code,name_lo,name_en from lookup.unit_of_measure where is_active=true order by name_en nulls last,name_lo');return r.rows.map((x:any)=>normalized(x,'id'));}
  async companyComplete(id:string){
    const c=await this.pool.query(`select c.*,p.display_name from master.company c join master.party p on p.id=c.party_id where c.party_id=$1`,[id]);
    if(!c.rows[0])return undefined;
    const sites=await this.pool.query(`select cs.*,f.facility_no,f.name_lo,f.name_en,f.admin_unit_id,f.address_text_lo,f.address_text_en,f.status facility_status,
      r.name_lo site_role_name_lo,r.name_en site_role_name_en
      from master.company_site cs join master.facility f on f.id=cs.facility_id join lookup.company_site_role r on r.code=cs.site_role_code
      where cs.company_id=$1 order by cs.is_primary desc,cs.site_role_code,f.name_lo`,[id]);
    const siteRows=[];
    for(const x of sites.rows){const contacts=await this.pool.query(`select * from master.facility_contact where facility_id=$1 and status='ACTIVE' order by is_primary desc,contact_type`,[x.facility_id]);siteRows.push({...normalized(x,'id'),contacts:contacts.rows.map((z:any)=>normalized(z,'id'))});}
    const regs=await this.pool.query('select * from master.company_external_registration where company_id=$1 order by created_at desc',[id]);
    const aliases=await this.pool.query("select * from master.company_alias where company_id=$1 and status='ACTIVE' order by alias_name",[id]);
    const roles=await this.pool.query(`select prt.code,prt.name_lo,prt.name_en,pra.valid_from,pra.valid_to,pra.status from master.party_role_assignment pra join master.party_role_type prt on prt.id=pra.role_type_id where pra.party_id=$1 order by prt.code`,[id]);
    const related=await this.pool.query(`select
      (select count(*)::int from product.product_regulatory_profile where holder_company_id=$1) holder_products,
      (select count(*)::int from product.product_regulatory_profile where importer_company_id=$1) importer_products,
      (select count(*)::int from product.product_regulatory_profile where manufacturer_company_id=$1) manufacturer_products,
      (select count(*)::int from trade.import_application where company_id=$1) import_applications,
      (select count(*)::int from trade.import_plan where company_id=$1) import_plans`,[id]);
    return {company:normalized(c.rows[0],'party_id'),sites:siteRows,registrations:regs.rows.map((x:any)=>normalized(x,'id')),aliases:aliases.rows.map((x:any)=>normalized(x,'id')),roles:roles.rows.map((x:any)=>camelRow(x)),related:camelRow(related.rows[0]||{})};
  }
  async companySites(companyId?:string){
    const params:any[]=[];let wh="where cs.status='ACTIVE'";if(companyId){params.push(companyId);wh+=' and cs.company_id=$1';}
    const r=await this.pool.query(`select cs.*,c.legal_name_lo,c.legal_name_en,f.facility_no,f.name_lo facility_name_lo,f.name_en facility_name_en,f.address_text_lo,f.address_text_en,
      sr.name_lo site_role_name_lo,sr.name_en site_role_name_en from master.company_site cs join master.company c on c.party_id=cs.company_id join master.facility f on f.id=cs.facility_id join lookup.company_site_role sr on sr.code=cs.site_role_code ${wh} order by c.legal_name_lo,cs.is_primary desc,cs.site_role_code`,params);
    return r.rows.map((x:any)=>normalized(x,'id'));
  }
  async createCompanySite(companyId:string,input:any){
    const client=await this.pool.connect();
    try{await client.query('begin');const c=(await client.query('select * from master.company where party_id=$1',[companyId])).rows[0];if(!c)throw Object.assign(new Error('Company not found'),{statusCode:404,code:'COMPANY_NOT_FOUND'});const role=String(input.siteRoleCode||'BUSINESS_SITE').toUpperCase();const rr=await client.query('select code from lookup.company_site_role where code=$1 and is_active=true',[role]);if(!rr.rows[0])throw Object.assign(new Error('Invalid site role'),{statusCode:400,code:'INVALID_SITE_ROLE'});
      const nameLo=input.nameLo||`${c.legal_name_lo||c.legal_name_en} — ${role.replaceAll('_',' ')}`;const f=(await client.query(`insert into master.facility(facility_no,name_lo,name_en,admin_unit_id,address_text_lo,address_text_en,status,established_date) values($1,$2,$3,$4,$5,$6,$7,$8) returning *`,[input.facilityNo||null,nameLo,input.nameEn||null,input.adminUnitId||null,input.addressTextLo||null,input.addressTextEn||null,input.facilityStatus||'ACTIVE',input.establishedDate||null])).rows[0];
      if(input.isPrimary)await client.query("update master.company_site set is_primary=false where company_id=$1 and site_role_code=$2 and status='ACTIVE'",[companyId,role]);
      const cs=(await client.query(`insert into master.company_site(company_id,facility_id,site_role_code,is_primary,valid_from,valid_to,status,notes) values($1,$2,$3,$4,coalesce($5,current_date),$6,$7,$8) returning *`,[companyId,f.id,role,!!input.isPrimary,input.validFrom||null,input.validTo||null,input.status||'ACTIVE',input.notes||null])).rows[0];
      const ft=await client.query('select id from lookup.facility_type where code=$1 limit 1',[role]);if(ft.rows[0])await client.query(`insert into master.facility_type_assignment(facility_id,facility_type_id,status) values($1,$2,'ACTIVE') on conflict do nothing`,[f.id,ft.rows[0].id]);
      for(const [type,key] of [['PHONE','phone'],['EMAIL','email'],['WEBSITE','website'],['FAX','fax']])if(input[key])await client.query(`insert into master.facility_contact(facility_id,contact_type,contact_value,is_primary,status) values($1,$2,$3,true,'ACTIVE')`,[f.id,type,input[key]]);
      await client.query('commit');return {site:normalized(cs,'id'),facility:normalized(f,'id')};
    }catch(e){await client.query('rollback');throw e}finally{client.release()}
  }
  async updateCompanySite(siteId:string,input:any){
    const client=await this.pool.connect();
    try{await client.query('begin');const site=(await client.query('select * from master.company_site where id=$1 for update',[siteId])).rows[0];if(!site)throw Object.assign(new Error('Company site not found'),{statusCode:404,code:'COMPANY_SITE_NOT_FOUND'});const role=input.siteRoleCode?String(input.siteRoleCode).toUpperCase():site.site_role_code;if(input.siteRoleCode){const rr=await client.query('select code from lookup.company_site_role where code=$1 and is_active=true',[role]);if(!rr.rows[0])throw Object.assign(new Error('Invalid site role'),{statusCode:400,code:'INVALID_SITE_ROLE'});}
      if(input.isPrimary===true)await client.query("update master.company_site set is_primary=false where company_id=$1 and site_role_code=$2 and id<>$3 and status='ACTIVE'",[site.company_id,role,siteId]);
      await client.query(`update master.company_site set site_role_code=$1,is_primary=coalesce($2,is_primary),valid_from=coalesce($3,valid_from),valid_to=$4,status=coalesce($5,status),notes=coalesce($6,notes) where id=$7`,[role,input.isPrimary===undefined?null:!!input.isPrimary,input.validFrom||null,input.validTo||null,input.status||null,input.notes===undefined?null:input.notes,siteId]);
      const fields:any={facility_no:input.facilityNo,name_lo:input.nameLo,name_en:input.nameEn,admin_unit_id:input.adminUnitId,address_text_lo:input.addressTextLo,address_text_en:input.addressTextEn,status:input.facilityStatus,established_date:input.establishedDate};const es=Object.entries(fields).filter(([,v])=>v!==undefined);if(es.length){const set=es.map(([k],i)=>`${quoteIdent(k)}=$${i+1}`).join(',');await client.query(`update master.facility set ${set},updated_at=now() where id=$${es.length+1}`,[...es.map(([,v])=>v||null),site.facility_id]);}
      for(const [type,key] of [['PHONE','phone'],['EMAIL','email'],['WEBSITE','website'],['FAX','fax']])if(input[key]!==undefined){await client.query("update master.facility_contact set status='INACTIVE',valid_to=current_date where facility_id=$1 and contact_type=$2 and status='ACTIVE'",[site.facility_id,type]);if(input[key])await client.query(`insert into master.facility_contact(facility_id,contact_type,contact_value,is_primary,status) values($1,$2,$3,true,'ACTIVE')`,[site.facility_id,type,input[key]]);}
      await client.query('commit');return this.companyComplete(site.company_id);
    }catch(e){await client.query('rollback');throw e}finally{client.release()}
  }
  async createCompanyExternalRegistration(companyId:string,input:any){
    if(input.facilityId){const ok=await this.pool.query("select 1 from master.company_site where company_id=$1 and facility_id=$2 and status='ACTIVE' limit 1",[companyId,input.facilityId]);if(!ok.rows[0])throw Object.assign(new Error('Related site does not belong to this company'),{statusCode:400,code:'COMPANY_SITE_MISMATCH'});}
    const r=await this.pool.query(`insert into master.company_external_registration(company_id,registration_type,registration_no,facility_id,issuing_authority,issue_date,expiry_date,status,notes,source_system) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) returning *`,[companyId,String(input.registrationType||'BUSINESS_LICENSE').toUpperCase(),input.registrationNo,input.facilityId||null,input.issuingAuthority||null,input.issueDate||null,input.expiryDate||null,input.status||'ACTIVE',input.notes||null,input.sourceSystem||'LVSP']);return normalized(r.rows[0],'id');
  }

  async companyDuplicateCandidates(){
    const rows=await this.list('companies');
    const normName=(v:any)=>String(v||'').toLowerCase().replace(/[.,()\-_/\\]+/g,' ').replace(/\b(company|co|ltd|limited|sole)\b/g,' ').replace(/\s+/g,' ').trim();
    const groups:any[]=[];const seen=new Set();
    for(let i=0;i<rows.length;i++)for(let j=i+1;j<rows.length;j++){
      const a=rows[i],b=rows[j];const reasons=[];
      const an=normName(a.legalNameLo||a.legalNameEn),bn=normName(b.legalNameLo||b.legalNameEn);
      if(an&&bn&&an===bn)reasons.push('NORMALIZED_NAME');
      if(a.enterpriseNo&&b.enterpriseNo&&String(a.enterpriseNo).trim()===String(b.enterpriseNo).trim())reasons.push('ENTERPRISE_NO');
      if(a.phone&&b.phone&&String(a.phone).replace(/\D/g,'')===String(b.phone).replace(/\D/g,''))reasons.push('PHONE');
      if(!reasons.length)continue;const k=[a.id,b.id].sort().join(':');if(seen.has(k))continue;seen.add(k);groups.push({companyA:a,companyB:b,reasons,reviewStatus:'REVIEW_REQUIRED'});
    }
    return groups;
  }
  async guidedServiceCatalog(publicOnly=true){
    const r=await this.pool.query(`
      select sd.id service_id,sd.service_code,sd.domain_code,sd.name_lo,sd.name_en,sd.description,sd.applicant_type,sd.is_public,
        sv.id service_version_id,sv.version_no,sv.workflow_code,sv.status service_version_status,
        sg.category_code,sg.icon,sg.display_order,sg.overview_lo,sg.overview_en,sg.eligibility_lo,sg.eligibility_en,
        sg.preparation_lo,sg.preparation_en,sg.processing_lo,sg.processing_en,sg.launch_module_key,sg.launch_action,
        sg.allow_public_browse,sg.requires_authentication,sg.configuration_notice_lo,sg.configuration_notice_en,sg.status guide_status,
        (select count(*)::int from system.service_step ss where ss.service_version_id=sv.id and ss.status='ACTIVE') step_count,
        (select count(*)::int from system.service_requirement sr where sr.service_version_id=sv.id and sr.status='ACTIVE') requirement_count
      from system.service_definition sd
      join lateral (select x.* from system.service_version x where x.service_id=sd.id order by x.version_no desc limit 1) sv on true
      left join system.service_guide sg on sg.service_version_id=sv.id
      where sd.is_active=true and ($1::boolean=false or (sd.is_public=true and coalesce(sg.allow_public_browse,true)=true))
      order by coalesce(sg.display_order,999),sd.domain_code,sd.service_code`,[!!publicOnly]);
    return r.rows.map((x:any)=>camelRow(x));
  }
  async guidedServiceGuide(serviceCode:string){
    const h=await this.pool.query(`
      select sd.id service_id,sd.service_code,sd.domain_code,sd.name_lo,sd.name_en,sd.description,sd.applicant_type,sd.is_public,
        sv.id service_version_id,sv.version_no,sv.workflow_code,sv.status service_version_status,
        sg.category_code,sg.icon,sg.display_order,sg.overview_lo,sg.overview_en,sg.eligibility_lo,sg.eligibility_en,
        sg.preparation_lo,sg.preparation_en,sg.processing_lo,sg.processing_en,sg.launch_module_key,sg.launch_action,
        sg.allow_public_browse,sg.requires_authentication,sg.configuration_notice_lo,sg.configuration_notice_en,sg.status guide_status
      from system.service_definition sd
      join lateral (select x.* from system.service_version x where x.service_id=sd.id order by x.version_no desc limit 1) sv on true
      left join system.service_guide sg on sg.service_version_id=sv.id
      where sd.service_code=$1 and sd.is_active=true limit 1`,[serviceCode]);
    if(!h.rows[0])return undefined;
    const header=camelRow(h.rows[0]);const versionId=h.rows[0].service_version_id;
    const [steps,requirements,outputs]=await Promise.all([
      this.pool.query("select * from system.service_step where service_version_id=$1 and status='ACTIVE' order by sequence_no",[versionId]),
      this.pool.query("select * from system.service_requirement where service_version_id=$1 and status='ACTIVE' order by sequence_no",[versionId]),
      this.pool.query("select * from system.service_output where service_version_id=$1 and status='ACTIVE' order by sequence_no",[versionId])
    ]);
    return {service:header,steps:steps.rows.map((x:any)=>camelRow(x)),requirements:requirements.rows.map((x:any)=>camelRow(x)),outputs:outputs.rows.map((x:any)=>camelRow(x))};
  }
  async createServiceDraft(serviceCode:string,startedBy:string,input:any={}){
    const guide=await this.guidedServiceGuide(serviceCode);if(!guide)throw Object.assign(new Error('Guided service not found'),{statusCode:404,code:'SERVICE_NOT_FOUND'});
    if(input.companyId){const c=await this.pool.query('select 1 from master.company where party_id=$1',[input.companyId]);if(!c.rows[0])throw Object.assign(new Error('Company not found'),{statusCode:400,code:'COMPANY_NOT_FOUND'});}
    const client=await this.pool.connect();
    try{await client.query('begin');
      const d=(await client.query(`insert into casework.service_draft(service_version_id,service_code_snapshot,applicant_party_id,company_id,started_by_subject,status,current_step_code,draft_payload)
        values($1,$2,$3,$4,$5,'IN_PROGRESS',$6,$7::jsonb) returning *`,[guide.service.serviceVersionId,serviceCode,input.applicantPartyId||null,input.companyId||null,startedBy,guide.steps[0]?.stepCode||null,JSON.stringify(input.payload||{})])).rows[0];
      await client.query(`insert into casework.service_draft_step(draft_id,step_code,sequence_no,status)
        select $1,step_code,sequence_no,case when sequence_no=(select min(sequence_no) from system.service_step where service_version_id=$2 and status='ACTIVE') then 'IN_PROGRESS' else 'NOT_STARTED' end
        from system.service_step where service_version_id=$2 and status='ACTIVE' order by sequence_no`,[d.id,guide.service.serviceVersionId]);
      await client.query(`insert into casework.service_draft_requirement(draft_id,requirement_id,status)
        select $1,id,'PENDING' from system.service_requirement where service_version_id=$2 and status='ACTIVE'`,[d.id,guide.service.serviceVersionId]);
      await client.query('commit');return this.serviceDraftComplete(d.id,startedBy,true);
    }catch(e){await client.query('rollback');throw e}finally{client.release()}
  }
  async serviceDrafts(startedBy:string,isAdmin=false){
    const params:any[]=[];let where='where 1=1';if(!isAdmin){params.push(startedBy);where+=' and d.started_by_subject=$1';}
    const r=await this.pool.query(`select d.*,sd.name_lo service_name_lo,sd.name_en service_name_en,sg.icon,sg.launch_module_key,
      (select count(*)::int from casework.service_draft_step x where x.draft_id=d.id and x.status='COMPLETED') completed_steps,
      (select count(*)::int from casework.service_draft_step x where x.draft_id=d.id) total_steps
      from casework.service_draft d join system.service_version sv on sv.id=d.service_version_id join system.service_definition sd on sd.id=sv.service_id
      left join system.service_guide sg on sg.service_version_id=sv.id ${where} order by d.updated_at desc limit 200`,params);
    return r.rows.map((x:any)=>normalized(x,'id'));
  }
  async serviceDraftComplete(id:string,startedBy:string,isAdmin=false){
    const params:any[]=[id];let ownership='';if(!isAdmin){params.push(startedBy);ownership=' and d.started_by_subject=$2';}
    const d=await this.pool.query(`select d.*,sd.name_lo service_name_lo,sd.name_en service_name_en,sg.icon,sg.launch_module_key,sg.configuration_notice_lo,sg.configuration_notice_en
      from casework.service_draft d join system.service_version sv on sv.id=d.service_version_id join system.service_definition sd on sd.id=sv.service_id
      left join system.service_guide sg on sg.service_version_id=sv.id where d.id=$1${ownership} limit 1`,params);
    if(!d.rows[0])return undefined;
    const [steps,requirements]=await Promise.all([
      this.pool.query(`select ds.*,ss.name_lo,ss.name_en,ss.description_lo,ss.description_en,ss.step_type,ss.actor_scope,ss.configuration
        from casework.service_draft_step ds join casework.service_draft d on d.id=ds.draft_id join system.service_step ss on ss.service_version_id=d.service_version_id and ss.step_code=ds.step_code
        where ds.draft_id=$1 order by ds.sequence_no`,[id]),
      this.pool.query(`select dr.*,sr.requirement_code,sr.requirement_type,sr.name_lo,sr.name_en,sr.description_lo,sr.description_en,sr.is_required
        from casework.service_draft_requirement dr join system.service_requirement sr on sr.id=dr.requirement_id where dr.draft_id=$1 order by sr.sequence_no`,[id])
    ]);
    return {draft:normalized(d.rows[0],'id'),steps:steps.rows.map((x:any)=>normalized(x,'id')),requirements:requirements.rows.map((x:any)=>normalized(x,'id'))};
  }
  async saveServiceDraftStep(id:string,startedBy:string,input:any,isAdmin=false){
    const client=await this.pool.connect();
    try{await client.query('begin');const d=(await client.query('select * from casework.service_draft where id=$1 for update',[id])).rows[0];if(!d)throw Object.assign(new Error('Service draft not found'),{statusCode:404,code:'SERVICE_DRAFT_NOT_FOUND'});if(!isAdmin&&String(d.started_by_subject)!==String(startedBy))throw Object.assign(new Error('Not allowed to access this draft'),{statusCode:403,code:'FORBIDDEN'});
      const stepCode=String(input.stepCode||d.current_step_code||'');const step=(await client.query('select * from casework.service_draft_step where draft_id=$1 and step_code=$2',[id,stepCode])).rows[0];if(!step)throw Object.assign(new Error('Unknown service step'),{statusCode:400,code:'INVALID_SERVICE_STEP'});
      const payload=input.payload&&typeof input.payload==='object'?input.payload:{};const completed=input.completed!==false;
      await client.query(`update casework.service_draft_step set status=$1::text,step_payload=step_payload||$2::jsonb,completed_at=case when $1::text='COMPLETED' then coalesce(completed_at,now()) else null end,updated_at=now() where id=$3`,[completed?'COMPLETED':'IN_PROGRESS',JSON.stringify(payload),step.id]);
      if(input.requirements&&typeof input.requirements==='object')for(const [code,status] of Object.entries(input.requirements)){await client.query(`update casework.service_draft_requirement dr set status=$1,checked_at=now(),updated_at=now() from system.service_requirement sr where dr.requirement_id=sr.id and dr.draft_id=$2 and sr.requirement_code=$3`,[String(status),id,code]);}
      const next=(await client.query("select step_code from casework.service_draft_step where draft_id=$1 and status<>'COMPLETED' order by sequence_no limit 1",[id])).rows[0];
      await client.query(`update casework.service_draft set current_step_code=$1,draft_payload=draft_payload||$2::jsonb,last_saved_at=now(),status=$3 where id=$4`,[next?.step_code||stepCode,JSON.stringify(payload),next?'IN_PROGRESS':'GUIDE_COMPLETED',id]);
      await client.query('commit');return this.serviceDraftComplete(id,startedBy,true);
    }catch(e){await client.query('rollback');throw e}finally{client.release()}
  }
  async linkServiceDraft(id:string,startedBy:string,targetResource:string,targetId:string,isAdmin=false){
    const d=await this.pool.query('select * from casework.service_draft where id=$1',[id]);if(!d.rows[0])throw Object.assign(new Error('Service draft not found'),{statusCode:404,code:'SERVICE_DRAFT_NOT_FOUND'});if(!isAdmin&&String(d.rows[0].started_by_subject)!==String(startedBy))throw Object.assign(new Error('Not allowed'),{statusCode:403,code:'FORBIDDEN'});
    const r=await this.pool.query(`update casework.service_draft set target_resource=$1,target_id=$2,status='DOMAIN_DRAFT_CREATED',completed_at=coalesce(completed_at,now()),last_saved_at=now() where id=$3 returning *`,[targetResource,targetId,id]);return normalized(r.rows[0],'id');
  }
  async allocateExportCaseNo(){
    const client=await this.pool.connect();
    try{
      await client.query('begin');
      const year=new Date().getUTCFullYear();
      await client.query(`insert into system.number_sequence(sequence_code,organization_id,year_value,prefix,next_value,padding_length,reset_rule,is_active) values('EXPORT_CASE',null,$1,'EXP',1,6,'YEARLY',true) on conflict (sequence_code,coalesce(organization_id,'00000000-0000-0000-0000-000000000000'::uuid),coalesce(year_value,-1)) do nothing`,[year]);
      const row=(await client.query(`select id,next_value,padding_length,prefix from system.number_sequence where sequence_code='EXPORT_CASE' and organization_id is null and year_value=$1 for update`,[year])).rows[0];
      const next=Number(row.next_value);
      await client.query('update system.number_sequence set next_value=next_value+1 where id=$1',[row.id]);
      await client.query('commit');
      return `${row.prefix}-${year}-${String(next).padStart(Number(row.padding_length)||6,'0')}`;
    }catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
  }
  async createExportApplication(input:any,startedBy:string){
    const companyId=input?.companyId;
    if(!companyId)throw Object.assign(new Error('Company is required'),{statusCode:400,code:'COMPANY_REQUIRED'});
    const c=await this.pool.query('select 1 from master.company where party_id=$1',[companyId]);
    if(!c.rows[0])throw Object.assign(new Error('Company not found'),{statusCode:400,code:'COMPANY_NOT_FOUND'});
    const serviceType=String(input?.serviceType||'').toUpperCase();
    const st=await this.pool.query('select allowed_movements from trade.annual_plan_service_type where service_type=$1',[serviceType]);
    if(!st.rows[0])throw Object.assign(new Error('Unknown service type'),{statusCode:400,code:'INVALID_SERVICE_TYPE'});
    const allowedMovements=Array.isArray(st.rows[0].allowed_movements)?st.rows[0].allowed_movements:[];
    if(!allowedMovements.includes('EXPORT'))throw Object.assign(new Error('EXPORT is not configured for this work area'),{statusCode:400,code:'MOVEMENT_NOT_ALLOWED'});
    const destinationCountryId=input?.destinationCountryId||null;
    if(destinationCountryId){const co=await this.pool.query('select 1 from lookup.country where id=$1',[destinationCountryId]);if(!co.rows[0])throw Object.assign(new Error('Unknown destination country'),{statusCode:400,code:'INVALID_COUNTRY'});}
    const items=Array.isArray(input?.items)?input.items:[];
    if(!items.length)throw Object.assign(new Error('At least one item is required'),{statusCode:400,code:'ITEMS_REQUIRED'});
    const guide=await this.guidedServiceGuide('TR-2001');
    if(!guide)throw Object.assign(new Error('Export service is not configured'),{statusCode:500,code:'SERVICE_NOT_CONFIGURED'});
    const serviceVersionId=guide.service.serviceVersionId;
    const caseNo=await this.allocateExportCaseNo();
    const client=await this.pool.connect();
    try{
      await client.query('begin');
      const caseRow=(await client.query(`insert into casework.regulatory_case(case_no,service_version_id,applicant_party_id,status,source_channel,submitted_at,created_by) values($1,$2,$3,'SUBMITTED','ONLINE',now(),$4) returning id`,[caseNo,serviceVersionId,companyId,isUuid(startedBy)?startedBy:null])).rows[0];
      const appRow=(await client.query(`insert into casework.application(case_id,application_type,declaration_accepted,declaration_at,submitted_payload) values($1,'EXPORT',true,now(),$2::jsonb) returning id`,[caseRow.id,JSON.stringify(input||{})])).rows[0];
      await client.query(`insert into trade.export_application_detail(application_id,service_type,destination_country_id,intended_shipment_from,intended_shipment_to,notes) values($1,$2,$3,$4,$5,$6)`,[appRow.id,serviceType,destinationCountryId,input?.shipmentFrom||null,input?.shipmentTo||null,input?.notes||null]);
      for(let i=0;i<items.length;i++){
        const it=items[i]||{};
        const quantity=it.quantity===undefined||it.quantity===null||it.quantity===''?null:Number(it.quantity);
        if(quantity!==null&&(!Number.isFinite(quantity)||quantity<0))throw Object.assign(new Error('Item quantity must be a non-negative number'),{statusCode:400,code:'INVALID_ITEM_QUANTITY'});
        await client.query(`insert into trade.export_application_item(application_id,item_no,commodity_class,species_id,product_id,item_description,hs_ahtn_code,quantity,unit_id,notes) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
          [appRow.id,i+1,it.commodityClass||null,it.speciesId||null,it.productId||null,it.itemDescription||it.itemName||null,it.hsAhtnCode||null,quantity,it.unitId||null,it.notes||null]);
      }
      await client.query('commit');
      return this.exportApplicationComplete(appRow.id);
    }catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
  }
  async exportApplicationComplete(id:string){
    const a=await this.pool.query(`select app.*,rc.case_no,rc.status case_status,rc.submitted_at,rc.applicant_party_id,
      c.legal_name_lo,c.legal_name_en,
      d.service_type,d.destination_country_id,d.intended_shipment_from,d.intended_shipment_to,d.notes detail_notes,
      co.name_lo destination_country_name_lo,co.name_en destination_country_name_en
      from casework.application app
      join casework.regulatory_case rc on rc.id=app.case_id
      left join master.company c on c.party_id=rc.applicant_party_id
      left join trade.export_application_detail d on d.application_id=app.id
      left join lookup.country co on co.id=d.destination_country_id
      where app.id=$1`,[id]);
    if(!a.rows[0])return undefined;
    const items=await this.pool.query(`select it.*,sp.name_lo species_name_lo,sp.name_en species_name_en,u.name_lo unit_name_lo,u.name_en unit_name_en,u.code unit_code
      from trade.export_application_item it
      left join lookup.species sp on sp.id=it.species_id
      left join lookup.unit_of_measure u on u.id=it.unit_id
      where it.application_id=$1 order by it.item_no`,[id]);
    return {application:normalized(a.rows[0],'id'),items:items.rows.map((x:any)=>normalized(x,'id'))};
  }
  async exportApplications(){
    const r=await this.pool.query(`select app.id,rc.case_no,rc.status,rc.submitted_at,d.service_type,
      coalesce(co.name_lo,co.name_en) destination_country,
      c.legal_name_lo,c.legal_name_en
      from casework.application app
      join casework.regulatory_case rc on rc.id=app.case_id
      left join trade.export_application_detail d on d.application_id=app.id
      left join lookup.country co on co.id=d.destination_country_id
      left join master.company c on c.party_id=rc.applicant_party_id
      where app.application_type='EXPORT'
      order by rc.submitted_at desc nulls last,app.created_at desc limit 500`);
    return r.rows.map((x:any)=>normalized(x,'id'));
  }
  async myWorkQueue(userId:string,isAdmin=false){
    let tasks:any[]=[];
    if(isAdmin){const r=await this.pool.query(`select t.id,t.status,t.due_at,null::text priority,s.step_code,s.name_lo step_name_lo,s.name_en step_name_en,i.business_entity_type,i.business_entity_id,i.status workflow_status
      from workflow.task t join workflow.instance i on i.id=t.workflow_instance_id join workflow.step s on s.id=t.step_id where t.status in ('OPEN','ASSIGNED','IN_PROGRESS') order by t.due_at nulls last,t.created_at desc limit 100`);tasks=r.rows.map((x:any)=>camelRow(x));}
    else if(isUuid(userId)){const r=await this.pool.query(`select t.id,t.status,t.due_at,null::text priority,s.step_code,s.name_lo step_name_lo,s.name_en step_name_en,i.business_entity_type,i.business_entity_id,i.status workflow_status
      from workflow.task t join workflow.instance i on i.id=t.workflow_instance_id join workflow.step s on s.id=t.step_id where t.assigned_user_id=$1 and t.status in ('OPEN','ASSIGNED','IN_PROGRESS') order by t.due_at nulls last,t.created_at desc limit 100`,[userId]);tasks=r.rows.map((x:any)=>camelRow(x));}
    const q=await this.pool.query(`select 'IMPORT_APPLICATION' queue_type,status,count(*)::int item_count from trade.import_application group by status
      union all select 'DRUG_REGISTRATION',registration_status,count(*)::int from product.product_regulatory_profile group by registration_status
      union all select 'ANNUAL_PLAN',status,count(*)::int from trade.import_plan group by status
      union all select 'PROVINCIAL_REPORT',status,count(*)::int from reporting.report_submission group by status order by 1,2`);
    const draftStats=await this.pool.query(`select status,count(*)::int item_count from casework.service_draft group by status order by status`);
    return {tasks,domainQueues:q.rows.map((x:any)=>camelRow(x)),guidedDrafts:draftStats.rows.map((x:any)=>camelRow(x))};
  }

  async authenticateAppUser(username:string,password:string){
    const login=String(username||'').trim();
    if(!login)return null;
    const r=await this.pool.query(`select u.id,u.username,u.email,u.status,u.password_hash,u.failed_login_count,u.locked_until,u.must_change_password,
      coalesce(array_remove(array_agg(distinct ro.code),null),'{}') roles
      from security.app_user u
      left join security.user_role_assignment ura on ura.user_id=u.id and ura.status='ACTIVE' and ura.valid_from<=now() and (ura.valid_to is null or ura.valid_to>now())
      left join security.role ro on ro.id=ura.role_id and ro.is_active=true
      where lower(u.username::text)=lower($1) or lower(coalesce(u.email::text,''))=lower($1)
      group by u.id limit 1`,[login]);
    const row=r.rows[0];
    if(!row){
      // A valid-format dummy hash reduces account-enumeration timing differences.
      verifyPassword(String(password||''),'scrypt$32768$8$1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
      return null;
    }
    if(String(row.status||'').toUpperCase()!=='ACTIVE')return null;
    if(row.locked_until && new Date(row.locked_until).getTime()>Date.now())return null;
    const ok=verifyPassword(String(password||''),String(row.password_hash||''));
    if(!ok){
      await this.pool.query(`update security.app_user set failed_login_count=failed_login_count+1,
        locked_until=case when failed_login_count+1>=5 then now()+interval '15 minutes' else locked_until end,
        updated_at=now() where id=$1`,[row.id]);
      return null;
    }
    await this.pool.query(`update security.app_user set failed_login_count=0,locked_until=null,last_login_at=now(),updated_at=now() where id=$1`,[row.id]);
    return {userId:String(row.id),username:String(row.username),roles:Array.isArray(row.roles)?row.roles.map(String):[],mustChangePassword:Boolean(row.must_change_password)};
  }

  async changeOwnPassword(userId:string,currentPassword:string,newPassword:string){
    if(!isUuid(userId))throw Object.assign(new Error('Invalid user ID'),{statusCode:400,code:'INVALID_USER_ID'});
    const row=(await this.pool.query(`select id,username,password_hash from security.app_user where id=$1 and status='ACTIVE'`,[userId])).rows[0];
    if(!row||!verifyPassword(String(currentPassword||''),String(row.password_hash||'')))throw Object.assign(new Error('Current password is incorrect'),{statusCode:401,code:'INVALID_CURRENT_PASSWORD'});
    const policy=validatePasswordPolicy(String(newPassword||''));if(!policy.ok)throw Object.assign(new Error(policy.message),{statusCode:400,code:'WEAK_PASSWORD'});
    const passwordHash=hashPassword(String(newPassword));
    await this.pool.query(`update security.app_user set password_hash=$1,password_changed_at=now(),must_change_password=false,failed_login_count=0,locked_until=null,updated_at=now() where id=$2`,[passwordHash,userId]);
    return {id:String(row.id),username:String(row.username),mustChangePassword:false};
  }

  async createAdminUser(input:any,actorUserId:any){
    const username=String(input.username||'').trim();
    const email=input.email?String(input.email).trim():null;
    const password=String(input.password||'');
    const roleCodes=Array.isArray(input.roles)?Array.from(new Set(input.roles.map((x:any)=>String(x).trim()).filter(Boolean))):[];
    if(!username||username.length<3)throw Object.assign(new Error('Username must contain at least 3 characters'),{statusCode:400,code:'INVALID_USERNAME'});
    const policy=validatePasswordPolicy(password);if(!policy.ok)throw Object.assign(new Error(policy.message),{statusCode:400,code:'WEAK_PASSWORD'});
    const passwordHash=hashPassword(password);
    const client=await this.pool.connect();
    try{
      await client.query('begin');
      const u=(await client.query(`insert into security.app_user(username,email,status,password_hash,password_changed_at,must_change_password,failed_login_count,created_at,updated_at)
        values($1,$2,'ACTIVE',$3,now(),$4,0,now(),now()) returning id,username,email,status,must_change_password,created_at`,
        [username,email,passwordHash,input.mustChangePassword!==false])).rows[0];
      if(roleCodes.length){
        const roles=await client.query(`select id,code from security.role where code::text=any($1::text[]) and is_active=true`,[roleCodes]);
        if(roles.rows.length!==roleCodes.length){
          const found=new Set(roles.rows.map((x:any)=>x.code));const missing=roleCodes.filter((x:any)=>!found.has(x));
          throw Object.assign(new Error(`Unknown/inactive roles: ${missing.join(', ')}`),{statusCode:400,code:'INVALID_ROLE'});
        }
        for(const role of roles.rows)await client.query(`insert into security.user_role_assignment(user_id,role_id,valid_from,assigned_by,status) values($1,$2,now(),$3,'ACTIVE')`,
          [u.id,role.id,isUuid(actorUserId)?actorUserId:null]);
      }
      await client.query('commit');
      return camelRow({...u,roles:roleCodes});
    }catch(e){await client.query('rollback');throw e}finally{client.release()}
  }

  async updateAdminUser(userId:string,input:any){
    if(!isUuid(userId))throw Object.assign(new Error('Invalid user ID'),{statusCode:400,code:'INVALID_USER_ID'});
    const sets:string[]=[];const vals:any[]=[];
    if(input.email!==undefined){vals.push(input.email?String(input.email).trim():null);sets.push(`email=$${vals.length}`)}
    if(input.status!==undefined){
      const status=String(input.status).toUpperCase();
      if(!['ACTIVE','INACTIVE','SUSPENDED','LOCKED'].includes(status))throw Object.assign(new Error('Invalid account status'),{statusCode:400,code:'INVALID_USER_STATUS'});
      vals.push(status);sets.push(`status=$${vals.length}`);
    }
    if(!sets.length)return (await this.adminUsers()).find((x:any)=>String(x.id)===String(userId));
    vals.push(userId);const r=await this.pool.query(`update security.app_user set ${sets.join(',')},updated_at=now() where id=$${vals.length} returning id,username,email,status,must_change_password,last_login_at,created_at`,vals);
    if(!r.rows[0])throw Object.assign(new Error('User not found'),{statusCode:404,code:'USER_NOT_FOUND'});
    return camelRow(r.rows[0]);
  }

  async resetAdminUserPassword(userId:string,newPassword:string,mustChangePassword=true){
    if(!isUuid(userId))throw Object.assign(new Error('Invalid user ID'),{statusCode:400,code:'INVALID_USER_ID'});
    const policy=validatePasswordPolicy(String(newPassword||''));if(!policy.ok)throw Object.assign(new Error(policy.message),{statusCode:400,code:'WEAK_PASSWORD'});
    const r=await this.pool.query(`update security.app_user set password_hash=$1,password_changed_at=now(),must_change_password=$2,failed_login_count=0,locked_until=null,updated_at=now()
      where id=$3 returning id,username,email,status,must_change_password`,[hashPassword(String(newPassword)),Boolean(mustChangePassword),userId]);
    if(!r.rows[0])throw Object.assign(new Error('User not found'),{statusCode:404,code:'USER_NOT_FOUND'});
    return camelRow(r.rows[0]);
  }

  async setAdminUserRoles(userId:string,roleCodes:any[],actorUserId:any){
    if(!isUuid(userId))throw Object.assign(new Error('Invalid user ID'),{statusCode:400,code:'INVALID_USER_ID'});
    const desired=Array.from(new Set((roleCodes||[]).map((x:any)=>String(x).trim()).filter(Boolean)));
    const client=await this.pool.connect();
    try{
      await client.query('begin');
      const exists=(await client.query(`select 1 from security.app_user where id=$1`,[userId])).rows[0];
      if(!exists)throw Object.assign(new Error('User not found'),{statusCode:404,code:'USER_NOT_FOUND'});
      const roles=desired.length?await client.query(`select id,code from security.role where code::text=any($1::text[]) and is_active=true`,[desired]):{rows:[]};
      if(roles.rows.length!==desired.length){
        const found=new Set(roles.rows.map((x:any)=>x.code));const missing=desired.filter((x:any)=>!found.has(x));
        throw Object.assign(new Error(`Unknown/inactive roles: ${missing.join(', ')}`),{statusCode:400,code:'INVALID_ROLE'});
      }
      await client.query(`update security.user_role_assignment set status='INACTIVE',valid_to=coalesce(valid_to,now()) where user_id=$1 and status='ACTIVE'`,[userId]);
      for(const role of roles.rows)await client.query(`insert into security.user_role_assignment(user_id,role_id,valid_from,assigned_by,status) values($1,$2,now(),$3,'ACTIVE')`,
        [userId,role.id,isUuid(actorUserId)?actorUserId:null]);
      await client.query('commit');
      return (await this.adminUsers()).find((x:any)=>String(x.id)===String(userId));
    }catch(e){await client.query('rollback');throw e}finally{client.release()}
  }

  async publicModuleCatalog(publicOnly=true){
    const r=await this.pool.query(`select module_code,module_key,name_lo,name_en,description_lo,description_en,icon,delivery_status,public_visible,login_required,public_data_mode,display_order,status
      from system.module_catalog where status='ACTIVE' ${publicOnly?'and public_visible=true':''} order by display_order,module_code`);
    return r.rows.map((x:any)=>camelRow(x));
  }

  async adminAccessFoundation(){
    const [organizations,adminUnits,facilities,scopes,modules]=await Promise.all([
      this.pool.query(`select o.id,o.parent_id,o.organization_code,o.organization_type,o.name_lo,o.name_en,o.admin_unit_id,o.status,
        au.official_code admin_unit_code,au.name_lo admin_unit_name_lo,au.name_en admin_unit_name_en
        from master.organization o left join master.admin_unit au on au.id=o.admin_unit_id
        where o.status='ACTIVE' order by o.organization_type,o.name_lo`),
      this.pool.query(`select au.id,au.parent_id,au.official_code,au.name_lo,au.name_en,au.status,aut.code unit_type_code,aut.level_no
        from master.admin_unit au join lookup.admin_unit_type aut on aut.id=au.admin_unit_type_id
        where au.status='ACTIVE' order by aut.level_no,au.name_lo`),
      this.pool.query(`select f.id,f.facility_no,f.name_lo,f.name_en,f.admin_unit_id,f.status,
        coalesce(array_remove(array_agg(distinct ft.code),null),'{}') facility_types
        from master.facility f left join master.facility_type_assignment fta on fta.facility_id=f.id and fta.status='ACTIVE'
        left join lookup.facility_type ft on ft.id=fta.facility_type_id
        where f.status in ('ACTIVE','PROPOSED') group by f.id order by f.name_lo`),
      this.pool.query(`select s.id,s.scope_name,s.scope_type,s.is_global,s.domain_code,s.organization_id,s.admin_unit_id,s.facility_id,
        o.name_lo organization_name_lo,o.name_en organization_name_en,au.name_lo admin_unit_name_lo,au.name_en admin_unit_name_en,
        f.name_lo facility_name_lo,f.name_en facility_name_en
        from security.access_scope s left join master.organization o on o.id=s.organization_id
        left join master.admin_unit au on au.id=s.admin_unit_id left join master.facility f on f.id=s.facility_id
        order by s.created_at,s.scope_name nulls last`),
      this.pool.query(`select module_code,module_key,name_lo,name_en,icon,delivery_status,public_visible,login_required,public_data_mode,display_order,status
        from system.module_catalog order by display_order,module_code`)
    ]);
    return {organizations:organizations.rows.map(camelRow),adminUnits:adminUnits.rows.map(camelRow),facilities:facilities.rows.map(camelRow),scopes:scopes.rows.map(camelRow),modules:modules.rows.map(camelRow)};
  }

  async createAdminOrganization(input:any){
    const code=input.organizationCode?String(input.organizationCode).trim():null;
    const type=String(input.organizationType||'OTHER').trim().toUpperCase();
    const nameLo=String(input.nameLo||'').trim();
    if(!nameLo)throw Object.assign(new Error('Lao organization name is required'),{statusCode:400,code:'ORGANIZATION_NAME_REQUIRED'});
    const parentId=input.parentId||null,adminUnitId=input.adminUnitId||null;
    const r=await this.pool.query(`insert into master.organization(parent_id,organization_code,organization_type,name_lo,name_en,admin_unit_id,status,valid_from)
      values($1,$2,$3,$4,$5,$6,'ACTIVE',current_date) returning *`,[parentId,code,type,nameLo,input.nameEn?String(input.nameEn).trim():null,adminUnitId]);
    return camelRow(r.rows[0]);
  }

  async createAdminAccessScope(input:any){
    const scopeType=String(input.scopeType||'CUSTOM').toUpperCase();
    const allowed=['GLOBAL','CENTRAL','PROVINCE','DISTRICT','CHECKPOINT','ORGANIZATION','DOMAIN','CUSTOM'];
    if(!allowed.includes(scopeType))throw Object.assign(new Error('Invalid access scope type'),{statusCode:400,code:'INVALID_SCOPE_TYPE'});
    const isGlobal=scopeType==='GLOBAL'||Boolean(input.isGlobal);
    const organizationId=input.organizationId||null,adminUnitId=input.adminUnitId||null,facilityId=input.facilityId||null,domainCode=input.domainCode?String(input.domainCode).trim():null;
    if(!isGlobal&&!organizationId&&!adminUnitId&&!facilityId&&!domainCode)throw Object.assign(new Error('Scope target is required'),{statusCode:400,code:'SCOPE_TARGET_REQUIRED'});
    const r=await this.pool.query(`insert into security.access_scope(scope_name,scope_type,organization_id,admin_unit_id,facility_id,domain_code,is_global)
      values($1,$2,$3,$4,$5,$6,$7) returning *`,[input.scopeName?String(input.scopeName).trim():null,scopeType,organizationId,adminUnitId,facilityId,domainCode,isGlobal]);
    return camelRow(r.rows[0]);
  }

  async addAdminUserAssignment(userId:string,input:any,actorUserId:any){
    if(!isUuid(userId))throw Object.assign(new Error('Invalid user ID'),{statusCode:400,code:'INVALID_USER_ID'});
    const roleCode=String(input.roleCode||'').trim();if(!roleCode)throw Object.assign(new Error('Role is required'),{statusCode:400,code:'ROLE_REQUIRED'});
    const scopeId=input.accessScopeId||null;
    const role=(await this.pool.query(`select id from security.role where code=$1 and is_active=true`,[roleCode])).rows[0];
    if(!role)throw Object.assign(new Error('Unknown/inactive role'),{statusCode:400,code:'INVALID_ROLE'});
    if(scopeId&&!isUuid(scopeId))throw Object.assign(new Error('Invalid access scope ID'),{statusCode:400,code:'INVALID_SCOPE_ID'});
    if(scopeId){const ok=(await this.pool.query(`select 1 from security.access_scope where id=$1`,[scopeId])).rows[0];if(!ok)throw Object.assign(new Error('Access scope not found'),{statusCode:404,code:'SCOPE_NOT_FOUND'});}
    const duplicate=(await this.pool.query(`select id from security.user_role_assignment where user_id=$1 and role_id=$2 and access_scope_id is not distinct from $3::uuid and status='ACTIVE' and (valid_to is null or valid_to>now())`,[userId,role.id,scopeId])).rows[0];
    if(duplicate)return {id:String(duplicate.id),duplicate:true};
    const r=await this.pool.query(`insert into security.user_role_assignment(user_id,role_id,access_scope_id,valid_from,assigned_by,status)
      values($1,$2,$3,now(),$4,'ACTIVE') returning *`,[userId,role.id,scopeId,isUuid(actorUserId)?actorUserId:null]);
    return camelRow(r.rows[0]);
  }

  async deactivateAdminUserAssignment(assignmentId:string){
    if(!isUuid(assignmentId))throw Object.assign(new Error('Invalid assignment ID'),{statusCode:400,code:'INVALID_ASSIGNMENT_ID'});
    const r=await this.pool.query(`update security.user_role_assignment set status='INACTIVE',valid_to=coalesce(valid_to,now()) where id=$1 returning *`,[assignmentId]);
    if(!r.rows[0])throw Object.assign(new Error('Assignment not found'),{statusCode:404,code:'ASSIGNMENT_NOT_FOUND'});
    return camelRow(r.rows[0]);
  }

  async adminAccessMatrix(){
    const r=await this.pool.query(`select * from analytics.v_user_access_matrix where assignment_status='ACTIVE' and (valid_to is null or valid_to>now()) order by username,role_code,scope_type nulls last`);
    return r.rows.map((x:any)=>camelRow(x));
  }

  async updateAdminModule(moduleCode:string,input:any){
    const fields:string[]=[];const vals:any[]=[];
    if(input.deliveryStatus!==undefined){const v=String(input.deliveryStatus).toUpperCase();if(!['ACTIVE','IN_DEVELOPMENT','PLANNED','PAUSED','RETIRED'].includes(v))throw Object.assign(new Error('Invalid module delivery status'),{statusCode:400,code:'INVALID_MODULE_STATUS'});vals.push(v);fields.push(`delivery_status=$${vals.length}`)}
    for(const [col,key] of [['public_visible','publicVisible'],['login_required','loginRequired']] as any[]){if(input[key]!==undefined){vals.push(Boolean(input[key]));fields.push(`${col}=$${vals.length}`)}}
    if(input.publicDataMode!==undefined){const v=String(input.publicDataMode).toUpperCase();if(!['NONE','CATALOG_ONLY','READ_ONLY'].includes(v))throw Object.assign(new Error('Invalid public data mode'),{statusCode:400,code:'INVALID_PUBLIC_MODE'});vals.push(v);fields.push(`public_data_mode=$${vals.length}`)}
    if(!fields.length)return (await this.publicModuleCatalog(false)).find((x:any)=>x.moduleCode===moduleCode);
    vals.push(moduleCode);const r=await this.pool.query(`update system.module_catalog set ${fields.join(',')},updated_at=now() where module_code=$${vals.length} returning *`,vals);
    if(!r.rows[0])throw Object.assign(new Error('Module not found'),{statusCode:404,code:'MODULE_NOT_FOUND'});
    return camelRow(r.rows[0]);
  }

  async publicOverview(){
    const r=await this.pool.query(`select
      (select count(*)::int from analytics.v_veterinary_drug_registry_report where upper(coalesce(registration_status,'')) in ('ACTIVE','VALID','APPROVED') and (expiry_date is null or expiry_date>=current_date)) active_drug_registrations,
      (select count(*)::int from master.company c join master.party p on p.id=c.party_id where p.status='ACTIVE') active_companies,
      (select count(*)::int from analytics.v_veterinary_trade_permit_report where upper(coalesce(status,'')) in ('APPROVED','CLEARED','COMPLETED')) completed_trade_records`);
    return camelRow(r.rows[0]||{});
  }

  async publicDrugRegistry(q:string='',limit=100){
    const search=String(q||'').trim();const safeLimit=Math.max(1,Math.min(200,Number(limit)||100));
    const r=await this.pool.query(`select regulatory_profile_id,registration_no,trade_name,generic_name,category,dosage_form,registration_holder,importer,manufacturer_name,manufacturer_country,issue_date,expiry_date,registration_status,presentation_count
      from analytics.v_veterinary_drug_registry_report
      where upper(coalesce(registration_status,'')) in ('ACTIVE','VALID','APPROVED')
        and (expiry_date is null or expiry_date>=current_date)
        and ($1='' or coalesce(registration_no,'') ilike '%'||$1||'%' or coalesce(trade_name,'') ilike '%'||$1||'%' or coalesce(generic_name,'') ilike '%'||$1||'%')
      order by trade_name nulls last,registration_no nulls last limit $2`,[search,safeLimit]);
    return r.rows.map((x:any)=>camelRow(x));
  }


  async publicSearch(q:string='',limit=60){
    const search=String(q||'').trim();
    if(search.length<2)return [];
    const safeLimit=Math.max(5,Math.min(100,Number(limit)||60));
    const each=Math.max(5,Math.ceil(safeLimit/3));
    const like=`%${search}%`;
    const [drug,docs,mods]=await Promise.all([
      this.pool.query(`select regulatory_profile_id,registration_no,trade_name,generic_name,manufacturer_name,manufacturer_country,issue_date,expiry_date,registration_status
        from analytics.v_veterinary_drug_registry_report
        where upper(coalesce(registration_status,'')) in ('ACTIVE','VALID','APPROVED')
          and (expiry_date is null or expiry_date>=current_date)
          and concat_ws(' ',coalesce(registration_no,''),coalesce(trade_name,''),coalesce(generic_name,''),coalesce(manufacturer_name,''),'Veterinary Drug Registration','Drug Registration','ໃບທະບຽນຢາສັດ','ທະບຽນຢາສັດ') ilike $1
        order by case when lower(coalesce(registration_no,''))=lower($2) then 0 else 1 end,trade_name nulls last
        limit $3`,[like,search,each]),
      this.pool.query(`select application_no,permit_no,decision_no,import_type,status,application_date,decision_date,permit_valid_to,
          case upper(coalesce(import_type,'IMPORT'))
            when 'EXPORT' then 'Export Notification Letter / Export Permit / ໃບແຈ້ງອະນຸຍາດສົ່ງອອກ'
            when 'TRANSIT' then 'Transit Notification Letter / Transit Permit / ໃບແຈ້ງອະນຸຍາດສົ່ງຜ່ານ'
            else 'Import Notification Letter / Import Permit / ໃບແຈ້ງອະນຸຍາດນຳເຂົ້າ'
          end document_title
        from trade.import_application
        where upper(coalesce(status,'')) in ('APPROVED','CLEARED','COMPLETED')
          and concat_ws(' ',coalesce(application_no,''),coalesce(permit_no,''),coalesce(decision_no,''),coalesce(import_type,''),coalesce(status,''),
            case upper(coalesce(import_type,'IMPORT'))
              when 'EXPORT' then 'Export Notification Letter Export Permit ໃບແຈ້ງອະນຸຍາດສົ່ງອອກ'
              when 'TRANSIT' then 'Transit Notification Letter Transit Permit ໃບແຈ້ງອະນຸຍາດສົ່ງຜ່ານ'
              else 'Import Notification Letter Import Permit ໃບແຈ້ງອະນຸຍາດນຳເຂົ້າ'
            end) ilike $1
        order by coalesce(decision_date,application_date) desc nulls last
        limit $2`,[like,each]),
      this.pool.query(`select module_code,name_lo,name_en,description_lo,description_en,delivery_status,public_data_mode,login_required,icon,display_order
        from system.module_catalog
        where public_visible=true
          and concat_ws(' ',coalesce(module_code,''),coalesce(name_lo,''),coalesce(name_en,''),coalesce(description_lo,''),coalesce(description_en,'')) ilike $1
        order by display_order,module_code
        limit $2`,[like,each])
    ]);
    const results:any[]=[];
    for(const row of drug.rows){const x=camelRow(row);results.push({kind:'DRUG_REGISTRATION',typeLabelLo:'ທະບຽນຢາສັດ',typeLabelEn:'Veterinary Drug Registration',referenceNo:x.registrationNo,titleLo:x.tradeName,titleEn:x.tradeName,subtitleLo:x.genericName||x.manufacturerName||'',subtitleEn:x.genericName||x.manufacturerName||'',status:x.registrationStatus,issueDate:x.issueDate,validTo:x.expiryDate,meta:{manufacturerName:x.manufacturerName,manufacturerCountry:x.manufacturerCountry,regulatoryProfileId:x.regulatoryProfileId}})}
    for(const row of docs.rows){const x=camelRow(row);const movement=String(x.importType||'IMPORT').toUpperCase();const titleLo=movement==='EXPORT'?'ໃບແຈ້ງອະນຸຍາດສົ່ງອອກ':movement==='TRANSIT'?'ໃບແຈ້ງອະນຸຍາດສົ່ງຜ່ານ':'ໃບແຈ້ງອະນຸຍາດນຳເຂົ້າ';const titleEn=movement==='EXPORT'?'Export Notification Letter':movement==='TRANSIT'?'Transit Notification Letter':'Import Notification Letter';results.push({kind:'TRADE_DOCUMENT',typeLabelLo:'ເອກະສານອະນຸຍາດ',typeLabelEn:'Permit / Notification Letter',referenceNo:x.permitNo||x.decisionNo||x.applicationNo,titleLo,titleEn,subtitleLo:[x.permitNo&&`Permit: ${x.permitNo}`,x.decisionNo&&`Decision: ${x.decisionNo}`,x.applicationNo&&`Application: ${x.applicationNo}`].filter(Boolean).join(' · '),subtitleEn:[x.permitNo&&`Permit: ${x.permitNo}`,x.decisionNo&&`Decision: ${x.decisionNo}`,x.applicationNo&&`Application: ${x.applicationNo}`].filter(Boolean).join(' · '),status:x.status,issueDate:x.decisionDate||x.applicationDate,validTo:x.permitValidTo,meta:{movementType:movement,applicationNo:x.applicationNo,permitNo:x.permitNo,decisionNo:x.decisionNo}})}
    for(const row of mods.rows){const x=camelRow(row);results.push({kind:'MODULE',typeLabelLo:'ໜ້າວຽກ / Module',typeLabelEn:'Service / Module',referenceNo:x.moduleCode,titleLo:x.nameLo||x.nameEn,titleEn:x.nameEn||x.nameLo,subtitleLo:x.descriptionLo||x.descriptionEn||'',subtitleEn:x.descriptionEn||x.descriptionLo||'',status:x.deliveryStatus,meta:{moduleCode:x.moduleCode,publicDataMode:x.publicDataMode,loginRequired:x.loginRequired,icon:x.icon}})}
    const rank=(x:any)=>{const ref=String(x.referenceNo||'').toLowerCase(),title=String(x.titleEn||x.titleLo||'').toLowerCase(),needle=search.toLowerCase();return ref===needle?0:ref.includes(needle)?1:title.startsWith(needle)?2:title.includes(needle)?3:4};
    return results.sort((a,b)=>rank(a)-rank(b)).slice(0,safeLimit);
  }

  async adminOverview(){
    const r=await this.pool.query(`select
      (select count(*)::int from security.app_user) users,
      (select count(*)::int from security.role where is_active=true) roles,
      (select count(*)::int from system.service_definition where is_active=true) active_services,
      (select count(*)::int from workflow.definition where is_active=true) workflows,
      (select count(*)::int from workflow.task where status in ('OPEN','ASSIGNED','IN_PROGRESS')) open_tasks,
      (select count(*)::int from inspection.field_capture_draft where sync_status in ('RECEIVED','PENDING_REVIEW')) field_captures,
      (select count(*)::int from audit.event where occurred_at>=date_trunc('day',now())) audit_today`);
    const counts=camelRow(r.rows[0]||{});const h=await this.health();return {counts,runtime:h};
  }
  async adminUsers(){
    const r=await this.pool.query(`select u.id,u.username,u.email,u.status,u.last_login_at,u.created_at,u.must_change_password,
      coalesce(jsonb_agg(distinct jsonb_build_object('code',ro.code,'nameLo',ro.name_lo,'nameEn',ro.name_en)) filter(where ro.id is not null),'[]'::jsonb) roles,
      coalesce(jsonb_agg(distinct jsonb_build_object('assignmentId',ura.id,'roleCode',ro.code,'accessScopeId',sc.id,'scopeName',sc.scope_name,'scopeType',sc.scope_type,'isGlobal',sc.is_global)) filter(where ura.id is not null),'[]'::jsonb) assignments
      from security.app_user u left join security.user_role_assignment ura on ura.user_id=u.id and ura.status='ACTIVE' and (ura.valid_to is null or ura.valid_to>now())
      left join security.role ro on ro.id=ura.role_id left join security.access_scope sc on sc.id=ura.access_scope_id group by u.id order by u.created_at desc limit 500`);
    return r.rows.map((x:any)=>camelRow(x));
  }
  async adminRoles(){
    const r=await this.pool.query(`select r.id,r.code,r.name_lo,r.name_en,r.is_system_role,r.is_active,count(rp.permission_id)::int permission_count
      from security.role r left join security.role_permission rp on rp.role_id=r.id group by r.id order by r.code`);
    return r.rows.map((x:any)=>camelRow(x));
  }
  async adminServices(){
    const r=await this.pool.query(`select sd.id,sd.service_code,sd.domain_code,sd.name_lo,sd.name_en,sd.applicant_type,sd.is_public,sd.is_active,
      sv.version_no,sv.status version_status,sv.effective_from,sg.status guide_status,sg.allow_public_browse,sg.requires_authentication,sg.launch_module_key,sg.display_order
      from system.service_definition sd
      left join lateral (select x.* from system.service_version x where x.service_id=sd.id order by x.version_no desc limit 1) sv on true
      left join system.service_guide sg on sg.service_version_id=sv.id order by coalesce(sg.display_order,9999),sd.service_code`);
    return r.rows.map((x:any)=>camelRow(x));
  }
  async updateAdminService(serviceCode:string,input:any){
    const client=await this.pool.connect();
    try{await client.query('begin');const fields:any[]=[];const vals:any[]=[];
      for(const [col,key] of [['is_active','isActive'],['is_public','isPublic']] as any[]){if(input[key]!==undefined){vals.push(Boolean(input[key]));fields.push(`${col}=$${vals.length}`)}}
      if(fields.length){vals.push(serviceCode);await client.query(`update system.service_definition set ${fields.join(',')},updated_at=now() where service_code=$${vals.length}`,vals);}
      const guideFields:any[]=[];const guideVals:any[]=[];
      if(input.allowPublicBrowse!==undefined){guideVals.push(Boolean(input.allowPublicBrowse));guideFields.push(`allow_public_browse=$${guideVals.length}`)}
      if(input.guideStatus!==undefined){guideVals.push(String(input.guideStatus).slice(0,30));guideFields.push(`status=$${guideVals.length}`)}
      if(guideFields.length){guideVals.push(serviceCode);await client.query(`update system.service_guide sg set ${guideFields.join(',')},updated_at=now() from system.service_version sv join system.service_definition sd on sd.id=sv.service_id where sg.service_version_id=sv.id and sd.service_code=$${guideVals.length} and sv.version_no=(select max(x.version_no) from system.service_version x where x.service_id=sd.id)`,guideVals);}
      await client.query('commit');const rows=await this.adminServices();return rows.find((x:any)=>x.serviceCode===serviceCode);
    }catch(e){await client.query('rollback');throw e}finally{client.release()}
  }
  async platformSettings(publicOnly=false){
    const r=await this.pool.query(`select setting_code,category_code,name_lo,name_en,value_json,value_type,is_public,is_editable,status,updated_at from system.platform_setting where status='ACTIVE' ${publicOnly?'and is_public=true':''} order by category_code,setting_code`);
    return r.rows.map((x:any)=>camelRow(x));
  }
  async updatePlatformSetting(code:string,value:any,actorUserId:any){
    const row=(await this.pool.query(`select * from system.platform_setting where setting_code=$1 and status='ACTIVE'`,[code])).rows[0];
    if(!row)throw Object.assign(new Error('Platform setting not found'),{statusCode:404,code:'SETTING_NOT_FOUND'});
    if(!row.is_editable||row.is_secret)throw Object.assign(new Error('Setting is not editable'),{statusCode:403,code:'SETTING_NOT_EDITABLE'});
    let v=value;if(row.value_type==='BOOLEAN')v=Boolean(value);else if(row.value_type==='NUMBER'){v=Number(value);if(!Number.isFinite(v))throw Object.assign(new Error('Invalid numeric value'),{statusCode:400,code:'INVALID_SETTING_VALUE'});}else if(row.value_type==='TEXT')v=String(value??'');
    const actor=isUuid(actorUserId)?actorUserId:null;const r=await this.pool.query(`update system.platform_setting set value_json=$1::jsonb,updated_at=now(),updated_by=$2 where setting_code=$3 returning setting_code,category_code,name_lo,name_en,value_json,value_type,is_public,is_editable,status,updated_at`,[JSON.stringify(v),actor,code]);return camelRow(r.rows[0]);
  }
  async fieldCaptureSync(userId:string,input:any){
    const localId=String(input.localCaptureId||input.id||'').trim();if(!localId)throw Object.assign(new Error('localCaptureId is required'),{statusCode:400,code:'LOCAL_CAPTURE_ID_REQUIRED'});
    const lat=input.latitude===undefined||input.latitude===null||input.latitude===''?null:Number(input.latitude);const lon=input.longitude===undefined||input.longitude===null||input.longitude===''?null:Number(input.longitude);
    const payload=input.payload&&typeof input.payload==='object'?input.payload:{finding:input.finding||'',gps:input.gps||''};
    const actor=isUuid(userId)?userId:null;const r=await this.pool.query(`insert into inspection.field_capture_draft(local_capture_id,submitted_by_subject,submitted_by_user_id,capture_type,facility_text,latitude,longitude,captured_at,payload,sync_status)
      values($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb,'RECEIVED') on conflict(submitted_by_subject,local_capture_id) do update set facility_text=excluded.facility_text,latitude=excluded.latitude,longitude=excluded.longitude,captured_at=excluded.captured_at,payload=excluded.payload returning *`,[localId,userId,actor,input.captureType||'FIELD_NOTE',input.facility||input.facilityText||null,lat,lon,input.capturedAt||input.createdAt||new Date().toISOString(),JSON.stringify(payload)]);return normalized(r.rows[0],'id');
  }
  async fieldCaptures(){const r=await this.pool.query(`select * from inspection.field_capture_draft order by received_at desc limit 500`);return r.rows.map((x:any)=>normalized(x,'id'));}

  async reportingConfig(){
    const [regions,provinces,assignments,metrics]=await Promise.all([
      this.pool.query(`select * from reporting.region where is_active=true order by display_order,region_code`),
      this.pool.query(`select p.*,r.name_lo region_name_lo,r.name_en region_name_en from reporting.province_profile p left join reporting.region r on r.region_code=p.region_code where p.status='ACTIVE' order by p.display_order,p.name_lo`),
      this.pool.query(`select a.*,r.name_lo region_name_lo,r.name_en region_name_en from reporting.region_staff_assignment a join reporting.region r on r.region_code=a.region_code where a.status='ACTIVE' and (a.effective_to is null or a.effective_to>=current_date) order by r.display_order,a.assignment_role,a.staff_subject`),
      this.pool.query(`select * from reporting.indicator_definition where is_active=true order by section_code,display_order,metric_code`)
    ]);
    return {regions:regions.rows.map(camelRow),provinces:provinces.rows.map(camelRow),assignments:assignments.rows.map((x:any)=>normalized(x,'id')),metrics:metrics.rows.map(camelRow)};
  }
  async reportingSubjectRegions(subject:string){
    const r=await this.pool.query(`select distinct region_code from reporting.region_staff_assignment where staff_subject=$1 and status='ACTIVE' and effective_from<=current_date and (effective_to is null or effective_to>=current_date)`,[subject]);
    return r.rows.map((x:any)=>x.region_code);
  }
  async reportingCanAccessProvince(provinceCode:string,subject:string,isAdmin=false){
    if(isAdmin)return true;const regions=await this.reportingSubjectRegions(subject);if(!regions.length)return false;
    const r=await this.pool.query(`select 1 from reporting.province_profile where province_code=$1 and region_code=any($2::varchar[]) and status='ACTIVE' limit 1`,[provinceCode,regions]);return !!r.rows[0];
  }
  async reportingSubmissions(filters:any={},subject='',isAdmin=false){
    const vals:any[]=[];const where=[`1=1`];
    if(filters.year){vals.push(Number(filters.year));where.push(`extract(year from r.period_end)=$${vals.length}`)}
    if(filters.month){vals.push(Number(filters.month));where.push(`extract(month from r.period_end)=$${vals.length}`)}
    if(filters.provinceCode){vals.push(String(filters.provinceCode));where.push(`r.province_code=$${vals.length}`)}
    if(filters.status){vals.push(String(filters.status));where.push(`r.status=$${vals.length}`)}
    if(!isAdmin){const regions=await this.reportingSubjectRegions(subject);if(!regions.length)return[];vals.push(regions);where.push(`p.region_code=any($${vals.length}::varchar[])`)}
    const q=await this.pool.query(`select r.*,p.name_lo province_name_lo,p.name_en province_name_en,p.region_code,rg.name_lo region_name_lo,rg.name_en region_name_en,
      (select count(*)::int from reporting.indicator_value iv where iv.report_id=r.id) indicator_count,
      (select count(*)::int from reporting.trade_stat ts where ts.report_id=r.id and ts.status='ACTIVE') trade_count,
      (select count(*)::int from reporting.activity_note an where an.report_id=r.id and an.status='ACTIVE') note_count
      from reporting.report_submission r join reporting.province_profile p on p.province_code=r.province_code left join reporting.region rg on rg.region_code=p.region_code
      where ${where.join(' and ')} order by r.period_end desc,p.display_order,r.received_at desc limit 500`,vals);
    return q.rows.map((x:any)=>normalized(x,'id'));
  }
  async createReportingSubmission(input:any,subject:string,isAdmin=false){
    const provinceCode=String(input.provinceCode||'').trim();if(!provinceCode)throw Object.assign(new Error('provinceCode is required'),{statusCode:400,code:'PROVINCE_REQUIRED'});
    if(!(await this.reportingCanAccessProvince(provinceCode,subject,isAdmin)))throw Object.assign(new Error('You are not assigned to this province/region'),{statusCode:403,code:'REPORTING_SCOPE_DENIED'});
    const p=(await this.pool.query(`select * from reporting.province_profile where province_code=$1 and status='ACTIVE'`,[provinceCode])).rows[0];if(!p)throw Object.assign(new Error('Unknown reporting province'),{statusCode:400,code:'INVALID_PROVINCE'});
    const start=String(input.periodStart||'');const end=String(input.periodEnd||'');if(!start||!end)throw Object.assign(new Error('Reporting period is required'),{statusCode:400,code:'REPORT_PERIOD_REQUIRED'});
    const reportType=String(input.reportType||'WEEKLY').toUpperCase();
    const existing=await this.pool.query(`select coalesce(max(revision_no),0)::int max_revision from reporting.report_submission where province_code=$1 and report_type=$2 and period_start=$3::date and period_end=$4::date`,[provinceCode,reportType,start,end]);
    const revision=Number(input.revisionNo||0)||Number(existing.rows[0]?.max_revision||0)+1;
    const r=await this.pool.query(`insert into reporting.report_submission(province_code,report_type,period_start,period_end,revision_no,source_channel,source_format,source_filename,source_reference,received_by_subject,assigned_region_code,assigned_to_subject,status,include_in_consolidation,summary_note,data_entry_note)
      values($1,$2,$3::date,$4::date,$5,$6,$7,$8,$9,$10,$11,$12,'RECEIVED',$13,$14,$15) returning *`,[provinceCode,reportType,start,end,revision,String(input.sourceChannel||'DOCUMENT').toUpperCase(),input.sourceFormat||null,input.sourceFilename||null,input.sourceReference||null,subject,p.region_code,input.assignedToSubject||null,input.includeInConsolidation!==false,input.summaryNote||null,input.dataEntryNote||null]);
    return normalized(r.rows[0],'id');
  }
  async reportingSubmissionComplete(id:string,subject:string,isAdmin=false){
    const d=(await this.pool.query(`select r.*,p.name_lo province_name_lo,p.name_en province_name_en,p.region_code,rg.name_lo region_name_lo,rg.name_en region_name_en from reporting.report_submission r join reporting.province_profile p on p.province_code=r.province_code left join reporting.region rg on rg.region_code=p.region_code where r.id=$1 limit 1`,[id])).rows[0];
    if(!d)return undefined;if(!(await this.reportingCanAccessProvince(d.province_code,subject,isAdmin)))throw Object.assign(new Error('You are not assigned to this report region'),{statusCode:403,code:'REPORTING_SCOPE_DENIED'});
    const [iv,ts,notes]=await Promise.all([
      this.pool.query(`select v.*,d.name_lo metric_name_lo,d.name_en metric_name_en,d.section_code from reporting.indicator_value v join reporting.indicator_definition d on d.metric_code=v.metric_code where v.report_id=$1 order by d.display_order,v.species_code,v.dimension_key`,[id]),
      this.pool.query(`select * from reporting.trade_stat where report_id=$1 and status='ACTIVE' order by created_at,id`,[id]),
      this.pool.query(`select * from reporting.activity_note where report_id=$1 and status='ACTIVE' order by created_at,id`,[id])
    ]);
    return {report:normalized(d,'id'),indicators:iv.rows.map((x:any)=>normalized(x,'id')),tradeStats:ts.rows.map((x:any)=>normalized(x,'id')),notes:notes.rows.map((x:any)=>normalized(x,'id'))};
  }
  async updateReportingSubmission(id:string,input:any,subject:string,isAdmin=false){
    const cur=(await this.pool.query(`select * from reporting.report_submission where id=$1`,[id])).rows[0];if(!cur)throw Object.assign(new Error('Report not found'),{statusCode:404,code:'REPORT_NOT_FOUND'});
    if(!(await this.reportingCanAccessProvince(cur.province_code,subject,isAdmin)))throw Object.assign(new Error('Not assigned to this report region'),{statusCode:403,code:'REPORTING_SCOPE_DENIED'});
    if(cur.status==='VERIFIED'&&!isAdmin)throw Object.assign(new Error('Verified report metadata is locked'),{statusCode:409,code:'REPORT_LOCKED'});
    const allowed:any={sourceChannel:'source_channel',sourceFormat:'source_format',sourceFilename:'source_filename',sourceReference:'source_reference',assignedToSubject:'assigned_to_subject',includeInConsolidation:'include_in_consolidation',summaryNote:'summary_note',dataEntryNote:'data_entry_note'};
    const sets=[] as string[],vals=[] as any[];for(const [k,col] of Object.entries(allowed)){if(input[k]!==undefined){vals.push(input[k]);sets.push(`${col}=$${vals.length}`)}}if(!sets.length)return normalized(cur,'id');vals.push(id);
    const r=await this.pool.query(`update reporting.report_submission set ${sets.join(',')},updated_at=now() where id=$${vals.length} returning *`,vals);return normalized(r.rows[0],'id');
  }
  async upsertReportingIndicators(reportId:string,rows:any[],subject:string,isAdmin=false){
    const complete=await this.reportingSubmissionComplete(reportId,subject,isAdmin);if(!complete)throw Object.assign(new Error('Report not found'),{statusCode:404,code:'REPORT_NOT_FOUND'});if(complete.report.status==='VERIFIED'&&!isAdmin)throw Object.assign(new Error('Verified report is locked'),{statusCode:409,code:'REPORT_LOCKED'});
    const client=await this.pool.connect();try{await client.query('begin');for(const x of rows){const code=String(x.metricCode||'').trim();if(!code)continue;const exists=(await client.query(`select 1 from reporting.indicator_definition where metric_code=$1 and is_active=true`,[code])).rows[0];if(!exists)throw Object.assign(new Error(`Unknown indicator: ${code}`),{statusCode:400,code:'INVALID_INDICATOR'});const species=String(x.speciesCode||'ALL').toUpperCase();const key=String(x.dimensionKey||'');const value=Number(x.valueNumeric??x.value??0);if(!Number.isFinite(value)||value<0)throw Object.assign(new Error('Indicator value must be a non-negative number'),{statusCode:400,code:'INVALID_INDICATOR_VALUE'});await client.query(`insert into reporting.indicator_value(report_id,metric_code,species_code,dimension_key,dimensions,value_numeric,unit_code,source_note) values($1,$2,$3,$4,$5::jsonb,$6,$7,$8)
      on conflict(report_id,metric_code,species_code,dimension_key) do update set dimensions=excluded.dimensions,value_numeric=excluded.value_numeric,unit_code=excluded.unit_code,source_note=excluded.source_note,updated_at=now()`,[reportId,code,species,key,JSON.stringify(x.dimensions||{}),value,x.unitCode||null,x.sourceNote||null]);}
      await client.query(`update reporting.report_submission set status=case when status='RECEIVED' then 'DATA_ENTRY' else status end,updated_at=now() where id=$1`,[reportId]);await client.query('commit');return this.reportingSubmissionComplete(reportId,subject,true);
    }catch(e){await client.query('rollback');throw e}finally{client.release()}
  }
  async createReportingTradeStat(reportId:string,input:any,subject:string,isAdmin=false){
    const complete=await this.reportingSubmissionComplete(reportId,subject,isAdmin);if(!complete)throw Object.assign(new Error('Report not found'),{statusCode:404,code:'REPORT_NOT_FOUND'});if(complete.report.status==='VERIFIED'&&!isAdmin)throw Object.assign(new Error('Verified report is locked'),{statusCode:409,code:'REPORT_LOCKED'});
    const n=(v:any)=>v===undefined||v===null||v===''?null:Number(v);const qty=n(input.quantity),weight=n(input.weightTon),amount=n(input.valueAmount);for(const v of [qty,weight,amount])if(v!==null&&(!Number.isFinite(v)||v<0))throw Object.assign(new Error('Trade numeric values must be non-negative'),{statusCode:400,code:'INVALID_TRADE_VALUE'});
    const r=await this.pool.query(`insert into reporting.trade_stat(report_id,movement_type,commodity_class,purpose_code,item_name,species_code,checkpoint_in,checkpoint_out,origin_text,destination_text,company_name,transport_mode,quantity,unit_code,weight_ton,value_amount,currency_code,source_note)
      values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18) returning *`,[reportId,String(input.movementType||'IMPORT').toUpperCase(),String(input.commodityClass||'LIVE_ANIMAL').toUpperCase(),input.purposeCode||null,input.itemName||null,input.speciesCode?String(input.speciesCode).toUpperCase():null,input.checkpointIn||null,input.checkpointOut||null,input.originText||null,input.destinationText||null,input.companyName||null,input.transportMode||null,qty,input.unitCode||null,weight,amount,String(input.currencyCode||'USD').toUpperCase(),input.sourceNote||null]);
    await this.pool.query(`update reporting.report_submission set status=case when status='RECEIVED' then 'DATA_ENTRY' else status end,updated_at=now() where id=$1`,[reportId]);return normalized(r.rows[0],'id');
  }
  async addReportingActivityNote(reportId:string,input:any,subject:string,isAdmin=false){
    const complete=await this.reportingSubmissionComplete(reportId,subject,isAdmin);if(!complete)throw Object.assign(new Error('Report not found'),{statusCode:404,code:'REPORT_NOT_FOUND'});if(complete.report.status==='VERIFIED'&&!isAdmin)throw Object.assign(new Error('Verified report is locked'),{statusCode:409,code:'REPORT_LOCKED'});if(!String(input.description||'').trim())throw Object.assign(new Error('Description is required'),{statusCode:400,code:'REPORT_NOTE_REQUIRED'});
    const r=await this.pool.query(`insert into reporting.activity_note(report_id,note_type,category_code,title,description,result_text,is_next_period_plan) values($1,$2,$3,$4,$5,$6,$7) returning *`,[reportId,String(input.noteType||'ACTIVITY').toUpperCase(),input.categoryCode||null,input.title||null,String(input.description),input.resultText||null,Boolean(input.isNextPeriodPlan)]);await this.pool.query(`update reporting.report_submission set status=case when status='RECEIVED' then 'DATA_ENTRY' else status end,updated_at=now() where id=$1`,[reportId]);return normalized(r.rows[0],'id');
  }
  async setReportingStatus(reportId:string,nextStatus:string,subject:string,isAdmin=false){
    const cur=(await this.pool.query(`select * from reporting.report_submission where id=$1`,[reportId])).rows[0];if(!cur)throw Object.assign(new Error('Report not found'),{statusCode:404,code:'REPORT_NOT_FOUND'});if(!(await this.reportingCanAccessProvince(cur.province_code,subject,isAdmin)))throw Object.assign(new Error('Not assigned to this report region'),{statusCode:403,code:'REPORTING_SCOPE_DENIED'});
    const next=String(nextStatus||'').toUpperCase();const allowed:any={RECEIVED:['DATA_ENTRY','REJECTED'],DATA_ENTRY:['READY_FOR_REVIEW','RECEIVED'],READY_FOR_REVIEW:['VERIFIED','DATA_ENTRY','REJECTED'],VERIFIED:['SUPERSEDED'],REJECTED:['DATA_ENTRY'],SUPERSEDED:[]};if(!isAdmin&&!(allowed[cur.status]||[]).includes(next))throw Object.assign(new Error(`Invalid reporting transition ${cur.status} -> ${next}`),{statusCode:409,code:'INVALID_REPORT_STATUS'});
    const client=await this.pool.connect();try{await client.query('begin');
      if(next==='VERIFIED'&&cur.report_type==='MONTHLY'&&cur.include_in_consolidation){
        await client.query(`update reporting.report_submission set include_in_consolidation=false,updated_at=now() where province_code=$1 and id<>$2 and report_type='WEEKLY' and status='VERIFIED' and include_in_consolidation=true and period_start<=$4::date and period_end>=$3::date`,[cur.province_code,reportId,cur.period_start,cur.period_end]);
      }
      let includeOnVerify=Boolean(cur.include_in_consolidation);
      if(next==='VERIFIED'&&cur.report_type==='WEEKLY'&&includeOnVerify){
        const monthly=(await client.query(`select 1 from reporting.report_submission where province_code=$1 and id<>$2 and report_type='MONTHLY' and status='VERIFIED' and include_in_consolidation=true and period_start<=$4::date and period_end>=$3::date limit 1`,[cur.province_code,reportId,cur.period_start,cur.period_end])).rows[0];
        if(monthly)includeOnVerify=false;
      }
      const r=await client.query(`update reporting.report_submission set status=$1,include_in_consolidation=case when $1='SUPERSEDED' then false when $1='VERIFIED' then $4 else include_in_consolidation end,ready_for_review_at=case when $1='READY_FOR_REVIEW' then now() else ready_for_review_at end,verified_at=case when $1='VERIFIED' then now() else verified_at end,verified_by_subject=case when $1='VERIFIED' then $2 else verified_by_subject end,updated_at=now() where id=$3 returning *`,[next,subject,reportId,includeOnVerify]);await client.query('commit');return normalized(r.rows[0],'id');
    }catch(e){await client.query('rollback');throw e}finally{client.release()}
  }
  async reportingMonthlySummary(year:number,month:number,subject:string,isAdmin=false){
    const start=`${year}-${String(month).padStart(2,'0')}-01`;const end=new Date(Date.UTC(year,month,0)).toISOString().slice(0,10);let scopeSql='';const vals:any[]=[start,end];if(!isAdmin){const regions=await this.reportingSubjectRegions(subject);if(!regions.length)return {year,month,totalProvinces:0,receivedProvinces:0,verifiedProvinces:0,provinceCoverage:[],indicators:[],trade:[],notes:[],suggestedNarrativeLo:'ຍັງບໍ່ໄດ້ກຳນົດພາກຮັບຜິດຊອບໃຫ້ຜູ້ໃຊ້ນີ້.'};vals.push(regions);scopeSql=` and p.region_code=any($3::varchar[])`;}
    const [coverage,indicators,trade,notes]=await Promise.all([
      this.pool.query(`select p.province_code,p.name_lo,p.name_en,p.region_code,rg.name_lo region_name_lo,
        (select count(*)::int from reporting.report_submission r where r.province_code=p.province_code and r.period_start<=$2::date and r.period_end>=$1::date and r.status not in ('REJECTED','SUPERSEDED')) received_count,
        (select count(*)::int from reporting.report_submission r where r.province_code=p.province_code and r.period_start<=$2::date and r.period_end>=$1::date and r.status='VERIFIED' and r.include_in_consolidation=true) verified_count,
        (select r.report_type from reporting.report_submission r where r.province_code=p.province_code and r.period_start<=$2::date and r.period_end>=$1::date and r.status='VERIFIED' and r.include_in_consolidation=true order by case r.report_type when 'MONTHLY' then 1 when 'WEEKLY' then 2 else 3 end,r.period_end desc limit 1) consolidation_source
        from reporting.province_profile p left join reporting.region rg on rg.region_code=p.region_code where p.status='ACTIVE'${scopeSql} order by p.display_order`,vals),
      this.pool.query(`select d.section_code,v.metric_code,d.name_lo,d.name_en,v.species_code,coalesce(v.unit_code,d.default_unit_code) unit_code,sum(v.value_numeric)::numeric value_numeric
        from reporting.indicator_value v join reporting.indicator_definition d on d.metric_code=v.metric_code join reporting.report_submission r on r.id=v.report_id join reporting.province_profile p on p.province_code=r.province_code
        where r.status='VERIFIED' and r.include_in_consolidation=true and r.period_start<=$2::date and r.period_end>=$1::date${scopeSql} group by d.section_code,v.metric_code,d.name_lo,d.name_en,v.species_code,coalesce(v.unit_code,d.default_unit_code) order by d.section_code,v.metric_code,v.species_code`,vals),
      this.pool.query(`select t.movement_type,t.commodity_class,t.currency_code,count(*)::int row_count,coalesce(sum(t.quantity),0)::numeric quantity,coalesce(sum(t.weight_ton),0)::numeric weight_ton,coalesce(sum(t.value_amount),0)::numeric value_amount
        from reporting.trade_stat t join reporting.report_submission r on r.id=t.report_id join reporting.province_profile p on p.province_code=r.province_code where t.status='ACTIVE' and r.status='VERIFIED' and r.include_in_consolidation=true and r.period_start<=$2::date and r.period_end>=$1::date${scopeSql} group by t.movement_type,t.commodity_class,t.currency_code order by t.movement_type,t.commodity_class,t.currency_code`,vals),
      this.pool.query(`select n.note_type,n.category_code,n.title,n.description,n.result_text,n.is_next_period_plan,p.name_lo province_name_lo from reporting.activity_note n join reporting.report_submission r on r.id=n.report_id join reporting.province_profile p on p.province_code=r.province_code where n.status='ACTIVE' and r.status='VERIFIED' and r.include_in_consolidation=true and r.period_start<=$2::date and r.period_end>=$1::date${scopeSql} order by n.is_next_period_plan,n.note_type,p.display_order,n.created_at`,vals)
    ]);
    const cov=coverage.rows.map(camelRow);const received=cov.filter((x:any)=>Number(x.receivedCount)>0).length;const verified=cov.filter((x:any)=>Number(x.verifiedCount)>0).length;const total=cov.length;const missing=cov.filter((x:any)=>Number(x.receivedCount)===0).map((x:any)=>x.nameLo);
    const suggestedNarrativeLo=`ໃນເດືອນ ${month}/${year} ພະແນກສັດຕະວະແພດ ໄດ້ຮັບບົດລາຍງານຈາກ ${received} ໃນ ${total} ແຂວງ/ນະຄອນຫຼວງ ແລະ ມີຂໍ້ມູນທີ່ກວດຢືນຢັນແລ້ວ ${verified} ແຂວງ. ${missing.length?`ຍັງບໍ່ໄດ້ຮັບລາຍງານຈາກ: ${missing.join(', ')}.`:'ໄດ້ຮັບລາຍງານຄົບຕາມຂອບເຂດທີ່ກຳນົດ.'} ຕົວເລກໃນສ່ວນສະຖິຕິແມ່ນສັງລວມຈາກບົດລາຍງານທີ່ມີສະຖານະ VERIFIED ແລະເລືອກໃຫ້ລວມເຂົ້າການສັງລວມເທົ່ານັ້ນ.`;
    return {year,month,totalProvinces:total,receivedProvinces:received,verifiedProvinces:verified,provinceCoverage:cov,indicators:indicators.rows.map(camelRow),trade:trade.rows.map(camelRow),notes:notes.rows.map(camelRow),suggestedNarrativeLo};
  }
  async reportingDashboard(year:number,month:number,subject:string,isAdmin=false){
    const summary=await this.reportingMonthlySummary(year,month,subject,isAdmin);const submissions=await this.reportingSubmissions({year,month},subject,isAdmin);const statusCounts:any={};for(const r of submissions)statusCounts[r.status]=(statusCounts[r.status]||0)+1;return {summary,statusCounts,submissions:submissions.slice(0,80)};
  }
  async upsertReportingRegionAssignment(regionCode:string,input:any,actorSubject:string){
    const subject=String(input.staffSubject||'').trim();if(!subject)throw Object.assign(new Error('staffSubject is required'),{statusCode:400,code:'STAFF_SUBJECT_REQUIRED'});const role=String(input.assignmentRole||'DATA_ENTRY').toUpperCase();
    const user=isUuid(subject)?subject:null;if(user){const ok=(await this.pool.query(`select 1 from security.app_user where id=$1`,[user])).rows[0];if(!ok)throw Object.assign(new Error('User ID not found'),{statusCode:400,code:'USER_NOT_FOUND'});}
    const r=await this.pool.query(`insert into reporting.region_staff_assignment(region_code,staff_subject,staff_user_id,assignment_role,effective_from,status) values($1,$2,$3,$4,coalesce($5::date,current_date),'ACTIVE') on conflict(region_code,staff_subject,assignment_role) where status='ACTIVE' and effective_to is null do update set staff_user_id=excluded.staff_user_id,effective_from=excluded.effective_from,status='ACTIVE' returning *`,[regionCode,subject,user,role,input.effectiveFrom||null]);return normalized(r.rows[0],'id');
  }
  async health(){const r=await this.pool.query('select current_database() db, now() server_time');return {ok:true,mode:this.mode,database:r.rows[0].db,serverTime:r.rows[0].server_time};}
  async close(){await this.pool.end()}
}
