// LVSP v1.3 Veterinary Drug Registration operational API.
// Connects migration 000800 to the staff application without changing DB schema.
// @ts-nocheck

function camel(s:string){return s.replace(/_([a-z])/g,(_:string,c:string)=>c.toUpperCase())}
function camelRow(row:any){return row?Object.fromEntries(Object.entries(row).map(([k,v])=>[camel(k),v])):row}
function rows(r:any){return (r?.rows||[]).map((x:any)=>camelRow(x))}
function isUuid(v:any){return typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v)}
function result(status:number,data:any,ids:any){return {status,body:{data,meta:{requestId:ids?.requestId}}}}
function error(status:number,code:string,message:string,ids:any){return {status,body:{error:{code,message,requestId:ids?.requestId},meta:{requestId:ids?.requestId}}}}
function hasRole(principal:any,allowed:string[]){return Array.isArray(principal?.roles)&&principal.roles.some((r:string)=>allowed.includes(r))}
function requireRoles(principal:any,allowed:string[]){if(!hasRole(principal,allowed))throw Object.assign(new Error('This action requires a competent veterinary-drug review/approval role'),{statusCode:403,code:'ACTION_FORBIDDEN'})}
function decorateDbError(e:any){
  if(e?.statusCode)return e;
  if(e?.code==='23505')return Object.assign(e,{statusCode:409,code:'DUPLICATE_RECORD'});
  if(['23503','23514','22P02','23502'].includes(e?.code))return Object.assign(e,{statusCode:400,code:'INVALID_REFERENCE_OR_VALUE'});
  if(e?.code==='P0001')return Object.assign(e,{statusCode:409,code:'INVALID_STATE_TRANSITION'});
  return e;
}

const REVIEW_ROLES=['SYSTEM_ADMIN','SECURITY_ADMIN','TECHNICAL_REVIEWER','APPROVING_AUTHORITY'];
const APPROVAL_ROLES=['SYSTEM_ADMIN','APPROVING_AUTHORITY'];
const HIGH_IMPACT=new Set(['APPROVE','REJECT','REGISTER']);
const REVIEW_ACTIONS=new Set(['RETURN_TO_DRAFT','START_SCREENING','START_TECHNICAL_REVIEW','REQUEST_CORRECTION','RECOMMEND_APPROVAL','RECOMMEND_REJECTION']);

async function audit(client:any,ctx:any,actionCode:string,resourceType:string,resourceId:any,beforeData:any,afterData:any,metadata:any={}){
  const actor=isUuid(ctx.principal?.userId)?ctx.principal.userId:null;
  const rid=isUuid(resourceId)?resourceId:null;
  const requestId=isUuid(ctx.ids?.requestId)?ctx.ids.requestId:null;
  const correlationId=isUuid(ctx.ids?.correlationId)?ctx.ids.correlationId:null;
  await client.query(`insert into audit.event(actor_user_id,action_code,resource_type,resource_id,request_id,correlation_id,before_data,after_data,metadata)
    values($1,$2,$3,$4,$5,$6,$7,$8,$9)`,[actor,actionCode,resourceType,rid,requestId,correlationId,beforeData||null,afterData||null,metadata||{}]);
}
async function outbox(client:any,ctx:any,eventType:string,applicationId:string,payload:any){
  if(!isUuid(applicationId))return;
  const correlationId=isUuid(ctx.ids?.correlationId)?ctx.ids.correlationId:null;
  await client.query(`insert into integration.outbox_event(event_type,aggregate_type,aggregate_id,schema_version,correlation_id,payload)
    values($1,'veterinary_drug_application',$2,1,$3,$4)`,[eventType,applicationId,correlationId,payload||{}]);
}

async function complete(pool:any,id:string){
  const app=(await pool.query('select * from registration.veterinary_drug_application where id=$1',[id])).rows[0];
  if(!app)return null;
  const [workspace,parties,presentations,documents,reviews,actions,regLink,presRegs,certs,transitions]=await Promise.all([
    pool.query('select * from analytics.v_veterinary_drug_registration_workspace where application_id=$1',[id]),
    pool.query(`select ap.*,c.legal_name_lo company_name_lo,c.legal_name_en company_name_en,
      f.name_lo facility_name_lo,f.name_en facility_name_en,f.address_text_lo facility_address_lo,f.address_text_en facility_address_en
      from registration.veterinary_drug_application_party ap
      left join master.company c on c.party_id=ap.party_id
      left join master.facility f on f.id=ap.facility_id
      where ap.application_id=$1 order by ap.role_code,ap.is_primary desc,ap.created_at`,[id]),
    pool.query(`select x.*,p.package_code,p.sub_code,p.status package_master_status,p.presentation_status,
      pv.pack_size,pv.unit_code,pv.container_type,pv.pack_description,pv.strength_text,pv.basis_text,pv.target_text,pv.total_weight_text,pv.is_kit
      from registration.veterinary_drug_application_presentation x
      join product.package p on p.id=x.package_id
      left join product.package_version pv on pv.id=x.package_version_id
      where x.application_id=$1 order by x.sequence_no`,[id]),
    pool.query(`select x.*,d.document_type,d.title document_title,d.status document_status,
      f.original_filename,f.mime_type,f.size_bytes
      from registration.veterinary_drug_application_document x
      left join document.document d on d.id=x.document_id
      left join lateral (select * from document.file z where z.document_id=d.id order by z.uploaded_at desc limit 1) f on true
      where x.application_id=$1 order by x.created_at,x.requirement_code`,[id]),
    pool.query('select * from registration.veterinary_drug_review where application_id=$1 order by review_round,review_type,created_at',[id]),
    pool.query('select * from registration.veterinary_drug_application_action where application_id=$1 order by performed_at desc',[id]),
    pool.query(`select l.*,r.registration_no,r.issue_date,r.expiry_date,r.status registration_status
      from registration.veterinary_drug_application_registration l join registration.registration r on r.id=l.registration_id where l.application_id=$1`,[id]),
    pool.query(`select l.*,r.registration_no,prp.registration_package_no
      from registration.veterinary_drug_presentation_registration l
      join registration.registration r on r.id=l.registration_id
      left join registration.product_registration_package prp on prp.registration_id=l.registration_id and prp.package_id=l.package_id
      join registration.veterinary_drug_application_presentation ap on ap.id=l.application_presentation_id
      where ap.application_id=$1 order by ap.sequence_no`,[id]),
    pool.query(`select x.*,c.certificate_no,c.certificate_type,c.issued_at,c.valid_from,c.valid_to,c.status certificate_status,c.verification_token,
      ap.sequence_no
      from registration.veterinary_drug_presentation_certificate x
      join registration.veterinary_drug_application_presentation ap on ap.id=x.application_presentation_id
      join document.certificate c on c.id=x.certificate_id
      where ap.application_id=$1 order by ap.sequence_no`,[id]),
    pool.query(`select r.action_code,r.to_status,r.configuration_status,r.notes
      from registration.veterinary_drug_transition_rule r
      join registration.veterinary_drug_application a on a.id=$1 and a.current_status=r.from_status
      where r.is_active=true order by r.action_code`,[id])
  ]);
  return {
    application:camelRow(app),
    workspace:workspace.rows[0]?camelRow(workspace.rows[0]):null,
    parties:rows(parties),presentations:rows(presentations),documents:rows(documents),reviews:rows(reviews),actions:rows(actions),
    registrationLink:regLink.rows[0]?camelRow(regLink.rows[0]):null,
    presentationRegistrations:rows(presRegs),presentationCertificates:rows(certs),allowedTransitions:rows(transitions)
  };
}

async function referenceData(pool:any,profileId:string){
  const pr=await pool.query(`select pr.*,p.trade_name,p.generic_name,p.product_code,p.lifecycle_status,
      h.legal_name_lo holder_name_lo,h.legal_name_en holder_name_en,hs.address_text_lo holder_site_address_lo,hs.address_text_en holder_site_address_en,
      i.legal_name_lo importer_name_lo,i.legal_name_en importer_name_en,ims.address_text_lo importer_site_address_lo,ims.address_text_en importer_site_address_en,
      m.legal_name_lo manufacturer_company_name_lo,m.legal_name_en manufacturer_company_name_en,ms.address_text_lo manufacturer_site_address_lo,ms.address_text_en manufacturer_site_address_en,
      d.legal_name_lo distributor_company_name_lo,d.legal_name_en distributor_company_name_en,ds.address_text_lo distributor_site_address_lo,ds.address_text_en distributor_site_address_en
      from product.product_regulatory_profile pr join product.product p on p.id=pr.product_id
      left join master.company h on h.party_id=pr.holder_company_id left join master.facility hs on hs.id=pr.holder_site_id
      left join master.company i on i.party_id=pr.importer_company_id left join master.facility ims on ims.id=pr.importer_site_id
      left join master.company m on m.party_id=pr.manufacturer_company_id left join master.facility ms on ms.id=pr.manufacturer_site_id
      left join master.company d on d.party_id=pr.distributor_company_id left join master.facility ds on ds.id=pr.distributor_site_id
      where pr.id=$1`,[profileId]);
  if(!pr.rows[0])return null;
  const productId=pr.rows[0].product_id;
  const [packages,companies,companySites,docs,registrations]=await Promise.all([
    pool.query(`select p.*,pv.id package_version_id,pv.version_no,pv.pack_size,pv.unit_code,pv.container_type,pv.pack_description,pv.strength_text,pv.basis_text,pv.target_text,pv.total_weight_text,pv.is_kit
      from product.package p left join lateral (select * from product.package_version x where x.package_id=p.id order by x.version_no desc limit 1) pv on true
      where p.product_id=$1 and coalesce(p.presentation_status,'ACTIVE')<>'INACTIVE' order by p.sub_code nulls first,p.created_at`,[productId]),
    pool.query(`select c.party_id,c.legal_name_lo,c.legal_name_en,c.enterprise_no,c.phone,c.email,c.status from master.company c where c.status='ACTIVE' order by c.legal_name_lo limit 1000`),
    pool.query(`select cs.id company_site_id,cs.company_id,cs.facility_id,cs.site_role_code,cs.is_primary,cs.status,
      f.facility_no,f.name_lo facility_name_lo,f.name_en facility_name_en,f.address_text_lo,f.address_text_en,f.status facility_status
      from master.company_site cs join master.facility f on f.id=cs.facility_id where cs.status='ACTIVE' order by cs.company_id,cs.is_primary desc,cs.site_role_code,f.name_lo`),
    pool.query(`select d.id,d.document_type,d.title,d.status,d.created_at,f.original_filename,f.mime_type
      from document.document d left join lateral (select * from document.file x where x.document_id=d.id order by x.uploaded_at desc limit 1) f on true
      where d.status='ACTIVE' and d.business_entity_type is distinct from 'DOCUMENT_INTAKE' order by d.created_at desc limit 250`),
    pool.query(`select r.id,r.registration_no,r.issue_date,r.expiry_date,r.status
      from registration.product_registration prg join registration.registration r on r.id=prg.registration_id
      where prg.product_id=$1 order by r.issue_date desc,r.created_at desc`,[productId])
  ]);
  return {profile:camelRow(pr.rows[0]),packages:rows(packages),companies:rows(companies),companySites:rows(companySites),documents:rows(docs),registrations:rows(registrations)};
}

async function validatePartySite(client:any,partyId:any,facilityId:any){
  if(!facilityId)return;
  if(!partyId)throw Object.assign(new Error('A selected facility/site requires a Company Master party'),{statusCode:400,code:'COMPANY_REQUIRED_FOR_SITE'});
  const ok=await client.query("select 1 from master.company_site where company_id=$1 and facility_id=$2 and status='ACTIVE' limit 1",[partyId,facilityId]);
  if(!ok.rows[0])throw Object.assign(new Error('Selected facility/site does not belong to the selected company'),{statusCode:400,code:'COMPANY_SITE_MISMATCH'});
}

export async function handleVetDrugOperationalApi(ctx:any){
  const {req,url,store,principal,ids,readJson}=ctx;
  const root='/api/v1/veterinary-drug-applications';
  if(!url.pathname.startsWith(root))return null;
  if(!principal?.isAuthenticated)return error(401,'UNAUTHENTICATED','Authentication required',ids);
  if(store?.mode!=='postgres')return error(501,'POSTGRES_REQUIRED','Veterinary drug operational workflow requires PostgreSQL/Supabase mode',ids);
  const pool=(store as any).pool;if(!pool)return error(501,'POSTGRES_POOL_REQUIRED','PostgreSQL pool is not available',ids);
  const localCtx={...ctx,principal,ids};
  try{
    if(url.pathname===root+'/reference' && req.method==='GET'){
      const profileId=String(url.searchParams.get('regulatoryProfileId')||'');
      if(!isUuid(profileId))return error(400,'PROFILE_ID_REQUIRED','A valid regulatoryProfileId is required',ids);
      const data=await referenceData(pool,profileId);
      return data?result(200,data,ids):error(404,'DRUG_PROFILE_NOT_FOUND','Veterinary drug profile not found',ids);
    }
    if(url.pathname===root && req.method==='GET'){
      const profileId=String(url.searchParams.get('regulatoryProfileId')||'');
      const status=String(url.searchParams.get('status')||'');
      const params:any[]=[];const where:string[]=[];
      if(profileId){if(!isUuid(profileId))return error(400,'INVALID_PROFILE_ID','Invalid regulatoryProfileId',ids);params.push(profileId);where.push(`regulatory_profile_id=$${params.length}`)}
      if(status){params.push(status.toUpperCase());where.push(`current_status=$${params.length}`)}
      const r=await pool.query(`select * from analytics.v_veterinary_drug_registration_workspace ${where.length?'where '+where.join(' and '):''} order by updated_at desc limit 500`,params);
      return result(200,rows(r),ids);
    }
    if(url.pathname===root && req.method==='POST'){
      const body=await readJson(req);const profileId=String(body.regulatoryProfileId||'');
      if(!isUuid(profileId))return error(400,'PROFILE_ID_REQUIRED','A valid regulatoryProfileId is required',ids);
      const client=await pool.connect();
      try{
        await client.query('begin');
        const profile=(await client.query('select * from product.product_regulatory_profile where id=$1 for share',[profileId])).rows[0];
        if(!profile)throw Object.assign(new Error('Veterinary drug profile not found'),{statusCode:404,code:'DRUG_PROFILE_NOT_FOUND'});
        const app=(await client.query(`insert into registration.veterinary_drug_application(
          regulatory_profile_id,product_id,application_no,application_date,registration_type,applicant_party_id,applicant_site_id,prior_registration_id,application_kind,notes)
          values($1,$2,nullif(btrim($3),''),$4,$5,$6,$7,$8,$9,$10) returning *`,[
          profileId,profile.product_id,String(body.applicationNo||''),body.applicationDate||null,String(body.registrationType||profile.registration_type||'IMPORT').toUpperCase(),
          isUuid(body.applicantPartyId)?body.applicantPartyId:null,isUuid(body.applicantSiteId)?body.applicantSiteId:null,isUuid(body.priorRegistrationId)?body.priorRegistrationId:null,
          String(body.applicationKind||'NEW').toUpperCase(),body.notes||null
        ])).rows[0];
        if(body.applicantSiteId)await validatePartySite(client,body.applicantPartyId,body.applicantSiteId);

        // Seed the current official parties/sites as application snapshots; no legal rule is inferred.
        const seed:any[]=[
          ['REGISTRATION_HOLDER',profile.holder_company_id,profile.holder_site_id,profile.holder_name_snapshot,null,null],
          ['IMPORTER',profile.importer_company_id,profile.importer_site_id,profile.importer_name_snapshot,null,null],
          ['MANUFACTURER',profile.manufacturer_company_id,profile.manufacturer_site_id,profile.manufacturer_name,profile.manufacturer_address,profile.manufacturer_country],
          ['DISTRIBUTOR',profile.distributor_company_id,profile.distributor_site_id,profile.distributor_name,profile.distributor_address,profile.distributor_country]
        ];
        for(const [role,partyId,facilityId,name0,address0,country0] of seed){
          let name=name0,address=address0;
          if(partyId&&!name){const c=(await client.query('select legal_name_lo,legal_name_en from master.company where party_id=$1',[partyId])).rows[0];name=c?.legal_name_lo||c?.legal_name_en||null}
          if(facilityId&&!address){const f=(await client.query('select address_text_lo,address_text_en from master.facility where id=$1',[facilityId])).rows[0];address=f?.address_text_lo||f?.address_text_en||null}
          if(partyId||name)await client.query(`insert into registration.veterinary_drug_application_party(application_id,role_code,party_id,facility_id,name_snapshot,address_snapshot,country_snapshot,is_primary,status)
            values($1,$2,$3,$4,$5,$6,$7,true,'ACTIVE')`,[app.id,role,partyId||null,facilityId||null,name||null,address||null,country0||null]);
        }
        if(body.includeAllPresentations!==false){
          const ps=await client.query(`select p.id,p.sub_code,pv.id package_version_id
            from product.package p left join lateral (select * from product.package_version x where x.package_id=p.id order by x.version_no desc limit 1) pv on true
            where p.product_id=$1 and coalesce(p.presentation_status,'ACTIVE')<>'INACTIVE' order by p.sub_code nulls first,p.created_at`,[profile.product_id]);
          let seq=1;for(const p of ps.rows){await client.query(`insert into registration.veterinary_drug_application_presentation(application_id,package_id,package_version_id,sequence_no,requested_sub_code,separate_certificate,separate_qr,status)
            values($1,$2,$3,$4,$5,true,true,'DRAFT')`,[app.id,p.id,p.package_version_id||null,seq++,p.sub_code||null])}
        }
        await audit(client,localCtx,'veterinary_drug.application.create','veterinary_drug_application',app.id,null,camelRow(app),{regulatoryProfileId:profileId});
        await outbox(client,localCtx,'veterinary_drug_application.created.v1',app.id,{applicationId:app.id,regulatoryProfileId:profileId});
        await client.query('commit');return result(201,await complete(pool,app.id),ids);
      }catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
    }

    const one=url.pathname.match(/^\/api\/v1\/veterinary-drug-applications\/([^/]+)$/);
    if(one&&req.method==='GET'){
      const id=decodeURIComponent(one[1]);if(!isUuid(id))return error(400,'INVALID_APPLICATION_ID','Invalid application id',ids);
      const data=await complete(pool,id);return data?result(200,data,ids):error(404,'VET_DRUG_APPLICATION_NOT_FOUND','Veterinary drug application not found',ids);
    }

    const parties=url.pathname.match(/^\/api\/v1\/veterinary-drug-applications\/([^/]+)\/parties$/);
    if(parties&&req.method==='POST'){
      const id=decodeURIComponent(parties[1]);const body=await readJson(req);const role=String(body.roleCode||'').toUpperCase();
      if(!isUuid(id))return error(400,'INVALID_APPLICATION_ID','Invalid application id',ids);
      if(!role)return error(400,'ROLE_REQUIRED','roleCode is required',ids);
      if(!isUuid(body.partyId)&&!String(body.nameSnapshot||'').trim())return error(400,'PARTY_IDENTITY_REQUIRED','Select a company/person or provide a snapshot name',ids);
      const client=await pool.connect();try{await client.query('begin');await validatePartySite(client,body.partyId,body.facilityId);
        if(body.isPrimary!==false)await client.query("update registration.veterinary_drug_application_party set is_primary=false,status=case when status='ACTIVE' then 'SUPERSEDED' else status end where application_id=$1 and role_code=$2 and is_primary=true and status='ACTIVE'",[id,role]);
        let name=String(body.nameSnapshot||'').trim()||null,address=String(body.addressSnapshot||'').trim()||null;
        if(isUuid(body.partyId)&&!name){const c=(await client.query('select legal_name_lo,legal_name_en from master.company where party_id=$1',[body.partyId])).rows[0];name=c?.legal_name_lo||c?.legal_name_en||null}
        if(isUuid(body.facilityId)&&!address){const f=(await client.query('select address_text_lo,address_text_en from master.facility where id=$1',[body.facilityId])).rows[0];address=f?.address_text_lo||f?.address_text_en||null}
        const row=(await client.query(`insert into registration.veterinary_drug_application_party(application_id,role_code,party_id,facility_id,name_snapshot,address_snapshot,country_snapshot,contact_snapshot,is_primary,valid_from,valid_to,status)
          values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'ACTIVE') returning *`,[id,role,isUuid(body.partyId)?body.partyId:null,isUuid(body.facilityId)?body.facilityId:null,name,address,body.countrySnapshot||null,body.contactSnapshot||null,body.isPrimary!==false,body.validFrom||null,body.validTo||null])).rows[0];
        await audit(client,localCtx,'veterinary_drug.party.create','veterinary_drug_application',id,null,camelRow(row),{partyRowId:row.id,roleCode:role});await outbox(client,localCtx,'veterinary_drug_application.party_changed.v1',id,{partyRowId:row.id,roleCode:role});await client.query('commit');return result(201,await complete(pool,id),ids);
      }catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
    }
    const partyRow=url.pathname.match(/^\/api\/v1\/veterinary-drug-applications\/([^/]+)\/parties\/([^/]+)$/);
    if(partyRow&&req.method==='PATCH'){
      const id=decodeURIComponent(partyRow[1]),rowId=decodeURIComponent(partyRow[2]);if(!isUuid(id)||!isUuid(rowId))return error(400,'INVALID_ID','Invalid application/party id',ids);
      const body=await readJson(req);const status=String(body.status||'').toUpperCase();if(!['SUPERSEDED','CANCELLED'].includes(status))return error(400,'INVALID_PARTY_STATUS','Only SUPERSEDED or CANCELLED is allowed',ids);
      const client=await pool.connect();try{await client.query('begin');const before=(await client.query('select * from registration.veterinary_drug_application_party where id=$1 and application_id=$2 for update',[rowId,id])).rows[0];if(!before)throw Object.assign(new Error('Party row not found'),{statusCode:404,code:'PARTY_ROW_NOT_FOUND'});
        const after=(await client.query('update registration.veterinary_drug_application_party set status=$1,is_primary=false where id=$2 returning *',[status,rowId])).rows[0];await audit(client,localCtx,'veterinary_drug.party.status','veterinary_drug_application',id,camelRow(before),camelRow(after),{partyRowId:rowId});await outbox(client,localCtx,'veterinary_drug_application.party_changed.v1',id,{partyRowId:rowId,status});await client.query('commit');return result(200,await complete(pool,id),ids);
      }catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
    }

    const presentations=url.pathname.match(/^\/api\/v1\/veterinary-drug-applications\/([^/]+)\/presentations$/);
    if(presentations&&req.method==='POST'){
      const id=decodeURIComponent(presentations[1]);const body=await readJson(req);if(!isUuid(id)||!isUuid(body.packageId))return error(400,'PACKAGE_REQUIRED','Valid application id and packageId are required',ids);
      const client=await pool.connect();try{await client.query('begin');const app=(await client.query('select product_id from registration.veterinary_drug_application where id=$1',[id])).rows[0];if(!app)throw Object.assign(new Error('Application not found'),{statusCode:404,code:'VET_DRUG_APPLICATION_NOT_FOUND'});
        const pkg=(await client.query('select * from product.package where id=$1 and product_id=$2',[body.packageId,app.product_id])).rows[0];if(!pkg)throw Object.assign(new Error('Package does not belong to application product'),{statusCode:400,code:'PACKAGE_PRODUCT_MISMATCH'});
        let pv=isUuid(body.packageVersionId)?body.packageVersionId:null;if(!pv){pv=(await client.query('select id from product.package_version where package_id=$1 order by version_no desc limit 1',[body.packageId])).rows[0]?.id||null}
        const seq=Number(body.sequenceNo||((await client.query('select coalesce(max(sequence_no),0)+1 n from registration.veterinary_drug_application_presentation where application_id=$1',[id])).rows[0].n));
        const row=(await client.query(`insert into registration.veterinary_drug_application_presentation(application_id,package_id,package_version_id,sequence_no,requested_sub_code,proposed_registration_package_no,separate_certificate,separate_qr,status,notes)
          values($1,$2,$3,$4,$5,$6,$7,$8,'DRAFT',$9) returning *`,[id,body.packageId,pv,seq,body.requestedSubCode||pkg.sub_code||null,body.proposedRegistrationPackageNo||null,body.separateCertificate!==false,body.separateQr!==false,body.notes||null])).rows[0];
        await audit(client,localCtx,'veterinary_drug.presentation.create','veterinary_drug_application',id,null,camelRow(row),{presentationId:row.id});await outbox(client,localCtx,'veterinary_drug_application.presentation_changed.v1',id,{presentationId:row.id});await client.query('commit');return result(201,await complete(pool,id),ids);
      }catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
    }
    const presentationRow=url.pathname.match(/^\/api\/v1\/veterinary-drug-applications\/([^/]+)\/presentations\/([^/]+)$/);
    if(presentationRow&&req.method==='PATCH'){
      const id=decodeURIComponent(presentationRow[1]),rowId=decodeURIComponent(presentationRow[2]);if(!isUuid(id)||!isUuid(rowId))return error(400,'INVALID_ID','Invalid application/presentation id',ids);const body=await readJson(req);
      const client=await pool.connect();try{await client.query('begin');const before=(await client.query('select * from registration.veterinary_drug_application_presentation where id=$1 and application_id=$2 for update',[rowId,id])).rows[0];if(!before)throw Object.assign(new Error('Presentation not found'),{statusCode:404,code:'PRESENTATION_NOT_FOUND'});
        const status=body.status===undefined?before.status:String(body.status).toUpperCase();if(!['DRAFT','SUBMITTED','APPROVED','REGISTERED','SUPERSEDED','CANCELLED'].includes(status))throw Object.assign(new Error('Invalid presentation status'),{statusCode:400,code:'INVALID_PRESENTATION_STATUS'});
        if(status!==before.status){if(['APPROVED','REGISTERED'].includes(status))requireRoles(principal,APPROVAL_ROLES);else requireRoles(principal,REVIEW_ROLES)}
        const after=(await client.query(`update registration.veterinary_drug_application_presentation set requested_sub_code=$1,proposed_registration_package_no=$2,separate_certificate=$3,separate_qr=$4,status=$5,notes=$6 where id=$7 returning *`,[
          body.requestedSubCode===undefined?before.requested_sub_code:(body.requestedSubCode||null),body.proposedRegistrationPackageNo===undefined?before.proposed_registration_package_no:(body.proposedRegistrationPackageNo||null),body.separateCertificate===undefined?before.separate_certificate:!!body.separateCertificate,body.separateQr===undefined?before.separate_qr:!!body.separateQr,status,body.notes===undefined?before.notes:(body.notes||null),rowId])).rows[0];
        await audit(client,localCtx,'veterinary_drug.presentation.update','veterinary_drug_application',id,camelRow(before),camelRow(after),{presentationId:rowId});await outbox(client,localCtx,'veterinary_drug_application.presentation_changed.v1',id,{presentationId:rowId,status});await client.query('commit');return result(200,await complete(pool,id),ids);
      }catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
    }

    const documents=url.pathname.match(/^\/api\/v1\/veterinary-drug-applications\/([^/]+)\/documents$/);
    if(documents&&req.method==='POST'){
      const id=decodeURIComponent(documents[1]);const body=await readJson(req);const code=String(body.requirementCode||'').trim().toUpperCase();if(!isUuid(id)||!code)return error(400,'REQUIREMENT_CODE_REQUIRED','Valid application id and requirementCode are required',ids);
      const requestedVerification=String(body.verificationStatus||'PENDING').toUpperCase();if(!['PENDING','RECEIVED'].includes(requestedVerification))requireRoles(principal,REVIEW_ROLES);
      const client=await pool.connect();try{await client.query('begin');const row=(await client.query(`insert into registration.veterinary_drug_application_document(application_id,requirement_code,requirement_label,document_id,is_required,requirement_source,legal_reference,verification_status,notes)
        values($1,$2,$3,$4,$5,$6,$7,$8,$9) returning *`,[id,code,body.requirementLabel||null,isUuid(body.documentId)?body.documentId:null,!!body.isRequired,body.requirementSource||'PENDING_LEGAL_VERIFICATION',body.legalReference||null,requestedVerification,body.notes||null])).rows[0];
        await audit(client,localCtx,'veterinary_drug.dossier_document.create','veterinary_drug_application',id,null,camelRow(row),{documentRowId:row.id});await outbox(client,localCtx,'veterinary_drug_application.dossier_changed.v1',id,{documentRowId:row.id});await client.query('commit');return result(201,await complete(pool,id),ids);
      }catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
    }
    const documentRow=url.pathname.match(/^\/api\/v1\/veterinary-drug-applications\/([^/]+)\/documents\/([^/]+)$/);
    if(documentRow&&req.method==='PATCH'){
      const id=decodeURIComponent(documentRow[1]),rowId=decodeURIComponent(documentRow[2]);if(!isUuid(id)||!isUuid(rowId))return error(400,'INVALID_ID','Invalid application/document id',ids);const body=await readJson(req);
      if(body.verificationStatus!==undefined)requireRoles(principal,REVIEW_ROLES);
      const client=await pool.connect();try{await client.query('begin');const before=(await client.query('select * from registration.veterinary_drug_application_document where id=$1 and application_id=$2 for update',[rowId,id])).rows[0];if(!before)throw Object.assign(new Error('Dossier row not found'),{statusCode:404,code:'DOSSIER_ROW_NOT_FOUND'});
        const verification=body.verificationStatus===undefined?before.verification_status:String(body.verificationStatus).toUpperCase();const checkedBy=body.verificationStatus===undefined?before.checked_by:(isUuid(principal.userId)?principal.userId:null);const checkedAt=body.verificationStatus===undefined?before.checked_at:new Date();
        const after=(await client.query(`update registration.veterinary_drug_application_document set requirement_label=$1,document_id=$2,is_required=$3,requirement_source=$4,legal_reference=$5,verification_status=$6,checked_by=$7,checked_at=$8,notes=$9 where id=$10 returning *`,[
          body.requirementLabel===undefined?before.requirement_label:(body.requirementLabel||null),body.documentId===undefined?before.document_id:(isUuid(body.documentId)?body.documentId:null),body.isRequired===undefined?before.is_required:!!body.isRequired,body.requirementSource===undefined?before.requirement_source:(body.requirementSource||'PENDING_LEGAL_VERIFICATION'),body.legalReference===undefined?before.legal_reference:(body.legalReference||null),verification,checkedBy,checkedAt,body.notes===undefined?before.notes:(body.notes||null),rowId])).rows[0];
        await audit(client,localCtx,'veterinary_drug.dossier_document.update','veterinary_drug_application',id,camelRow(before),camelRow(after),{documentRowId:rowId});await outbox(client,localCtx,'veterinary_drug_application.dossier_changed.v1',id,{documentRowId:rowId,verificationStatus:verification});await client.query('commit');return result(200,await complete(pool,id),ids);
      }catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
    }

    const reviews=url.pathname.match(/^\/api\/v1\/veterinary-drug-applications\/([^/]+)\/reviews$/);
    if(reviews&&req.method==='POST'){
      requireRoles(principal,REVIEW_ROLES);const id=decodeURIComponent(reviews[1]);const body=await readJson(req);if(!isUuid(id))return error(400,'INVALID_APPLICATION_ID','Invalid application id',ids);
      const reviewType=String(body.reviewType||'TECHNICAL').toUpperCase(),outcome=String(body.outcome||'PENDING').toUpperCase();const client=await pool.connect();try{await client.query('begin');
        const round=Number(body.reviewRound||((await client.query('select coalesce(max(review_round),0)+1 n from registration.veterinary_drug_review where application_id=$1 and review_type=$2',[id,reviewType])).rows[0].n));
        const reviewerRole=(principal.roles||[]).find((x:string)=>REVIEW_ROLES.includes(x))||null;
        const row=(await client.query(`insert into registration.veterinary_drug_review(application_id,review_type,review_round,reviewer_user_id,reviewer_role_code,outcome,findings,recommendation,internal_notes,completed_at)
          values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) returning *`,[id,reviewType,round,isUuid(principal.userId)?principal.userId:null,reviewerRole,outcome,body.findings||null,body.recommendation||null,body.internalNotes||null,outcome==='PENDING'?null:new Date()])).rows[0];
        await audit(client,localCtx,'veterinary_drug.review.create','veterinary_drug_application',id,null,camelRow(row),{reviewId:row.id,reviewType});await outbox(client,localCtx,'veterinary_drug_application.review_recorded.v1',id,{reviewId:row.id,reviewType,outcome});await client.query('commit');return result(201,await complete(pool,id),ids);
      }catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
    }

    const regLink=url.pathname.match(/^\/api\/v1\/veterinary-drug-applications\/([^/]+)\/registration-link$/);
    if(regLink&&req.method==='POST'){
      requireRoles(principal,APPROVAL_ROLES);const id=decodeURIComponent(regLink[1]);const body=await readJson(req),registrationId=String(body.registrationId||'');if(!isUuid(id)||!isUuid(registrationId))return error(400,'REGISTRATION_REQUIRED','Valid application id and registrationId are required',ids);
      const client=await pool.connect();try{await client.query('begin');const app=(await client.query('select * from registration.veterinary_drug_application where id=$1 for update',[id])).rows[0];if(!app)throw Object.assign(new Error('Application not found'),{statusCode:404,code:'VET_DRUG_APPLICATION_NOT_FOUND'});
        if(app.current_status!=='APPROVED')throw Object.assign(new Error('Official registration can be linked only after the application is APPROVED'),{statusCode:409,code:'APPLICATION_NOT_APPROVED'});
        const reg=(await client.query(`select r.* from registration.registration r join registration.product_registration pr on pr.registration_id=r.id where r.id=$1 and pr.product_id=$2`,[registrationId,app.product_id])).rows[0];if(!reg)throw Object.assign(new Error('Selected official registration is not linked to this product'),{statusCode:400,code:'REGISTRATION_PRODUCT_MISMATCH'});
        const existing=(await client.query('select * from registration.veterinary_drug_application_registration where application_id=$1',[id])).rows[0];if(existing&&existing.registration_id!==registrationId)throw Object.assign(new Error('Application is already linked to another official registration'),{statusCode:409,code:'APPLICATION_REGISTRATION_ALREADY_LINKED'});
        await client.query(`insert into registration.veterinary_drug_application_registration(application_id,registration_id,linked_by,notes) values($1,$2,$3,$4) on conflict(application_id) do nothing`,[id,registrationId,isUuid(principal.userId)?principal.userId:null,body.notes||null]);
        const pres=await client.query("select * from registration.veterinary_drug_application_presentation where application_id=$1 and status<>'CANCELLED' order by sequence_no",[id]);
        for(const p of pres.rows){
          await client.query(`insert into registration.product_registration_package(registration_id,package_id,registration_package_no,status) values($1,$2,$3,'ACTIVE')
            on conflict(registration_id,package_id) do update set registration_package_no=coalesce(excluded.registration_package_no,registration.product_registration_package.registration_package_no),status='ACTIVE'`,[registrationId,p.package_id,p.proposed_registration_package_no||null]);
          await client.query(`insert into registration.veterinary_drug_presentation_registration(application_presentation_id,registration_id,package_id,linked_by,notes)
            values($1,$2,$3,$4,$5) on conflict(application_presentation_id) do nothing`,[p.id,registrationId,p.package_id,isUuid(principal.userId)?principal.userId:null,body.notes||null]);
        }
        await audit(client,localCtx,'veterinary_drug.registration.link','veterinary_drug_application',id,existing?camelRow(existing):null,{registrationId},{registrationId});await outbox(client,localCtx,'veterinary_drug_application.registration_linked.v1',id,{registrationId});await client.query('commit');return result(200,await complete(pool,id),ids);
      }catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
    }

    const transition=url.pathname.match(/^\/api\/v1\/veterinary-drug-applications\/([^/]+)\/transition$/);
    if(transition&&req.method==='POST'){
      const id=decodeURIComponent(transition[1]);const body=await readJson(req),action=String(body.actionCode||'').trim().toUpperCase();if(!isUuid(id)||!action)return error(400,'ACTION_REQUIRED','Valid application id and actionCode are required',ids);
      if(HIGH_IMPACT.has(action))requireRoles(principal,APPROVAL_ROLES);else if(REVIEW_ACTIONS.has(action))requireRoles(principal,REVIEW_ROLES);
      const client=await pool.connect();try{await client.query('begin');const before=(await client.query('select * from registration.veterinary_drug_application where id=$1 for update',[id])).rows[0];if(!before)throw Object.assign(new Error('Application not found'),{statusCode:404,code:'VET_DRUG_APPLICATION_NOT_FOUND'});
        if(action==='REGISTER'){
          const link=(await client.query('select registration_id from registration.veterinary_drug_application_registration where application_id=$1',[id])).rows[0];if(!link)throw Object.assign(new Error('Link the approved application to an official registration before REGISTER'),{statusCode:409,code:'OFFICIAL_REGISTRATION_LINK_REQUIRED'});
          const missing=(await client.query(`select count(*)::int n from registration.veterinary_drug_application_presentation p left join registration.veterinary_drug_presentation_registration l on l.application_presentation_id=p.id where p.application_id=$1 and p.status<>'CANCELLED' and l.application_presentation_id is null`,[id])).rows[0].n;if(Number(missing)>0)throw Object.assign(new Error('All active presentations must be linked to the official registration before REGISTER'),{statusCode:409,code:'PRESENTATION_REGISTRATION_LINK_REQUIRED'});
        }
        const actor=isUuid(principal.userId)?principal.userId:null;
        const after=(await client.query('select * from registration.transition_veterinary_drug_application($1,$2,$3,$4)',[id,action,actor,body.comment||null])).rows[0];
        await audit(client,localCtx,'veterinary_drug.transition','veterinary_drug_application',id,camelRow(before),camelRow(after),{actionCode:action});await outbox(client,localCtx,'veterinary_drug_application.transitioned.v1',id,{actionCode:action,fromStatus:before.current_status,toStatus:after.current_status});await client.query('commit');return result(200,await complete(pool,id),ids);
      }catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
    }

    return error(404,'ROUTE_NOT_FOUND','Veterinary drug operational API route not found',ids);
  }catch(e:any){throw decorateDbError(e)}
}
