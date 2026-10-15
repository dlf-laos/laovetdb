// LVSP v1.4 Legacy Registration + Trade parity API.
// Persistent multi-registration internal memo, trade coordination checklist,
// and shared regulatory report-builder data sources.
// @ts-nocheck

function camel(s:string){return s.replace(/_([a-z])/g,(_:string,c:string)=>c.toUpperCase())}
function camelRow(row:any){return row?Object.fromEntries(Object.entries(row).map(([k,v])=>[camel(k),v])):row}
function rows(r:any){return (r?.rows||[]).map((x:any)=>camelRow(x))}
function isUuid(v:any){return typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v)}
function result(status:number,data:any,ids:any,meta:any={}){return {status,body:{data,meta:{requestId:ids?.requestId,...meta}}}}
function error(status:number,code:string,message:string,ids:any){return {status,body:{error:{code,message,requestId:ids?.requestId},meta:{requestId:ids?.requestId}}}}
function dbError(e:any){
  if(e?.statusCode)return e;
  if(e?.code==='23505')return Object.assign(e,{statusCode:409,code:'DUPLICATE_RECORD'});
  if(['23503','23514','23502','22P02'].includes(e?.code))return Object.assign(e,{statusCode:400,code:'INVALID_REFERENCE_OR_VALUE'});
  return e;
}
function text(v:any,max=4000){const s=String(v??'').trim();return s?s.slice(0,max):null}
function bool(v:any,def=false){return v===undefined||v===null?def:!!v}
function arr(v:any){return Array.isArray(v)?v:[]}
function obj(v:any){return v&&typeof v==='object'&&!Array.isArray(v)?v:{}}
function upper(v:any){return String(v??'').trim().toUpperCase()}
function hasRole(principal:any,allowed:string[]){return Array.isArray(principal?.roles)&&principal.roles.some((r:string)=>allowed.includes(r))}
const INTERNAL_READ_ROLES=['SYSTEM_ADMIN','SECURITY_ADMIN','DATA_STEWARD','REGISTRY_OFFICER','TECHNICAL_REVIEWER','APPROVING_AUTHORITY','MANAGEMENT_VIEWER','CERTIFICATE_SIGNATORY','QUARANTINE_OFFICER','BORDER_OFFICER','LICENSING_OFFICER'];
const INTERNAL_WRITE_ROLES=['SYSTEM_ADMIN','SECURITY_ADMIN','DATA_STEWARD','REGISTRY_OFFICER','TECHNICAL_REVIEWER','APPROVING_AUTHORITY','QUARANTINE_OFFICER','BORDER_OFFICER','LICENSING_OFFICER'];
const FINALIZE_ROLES=['SYSTEM_ADMIN','APPROVING_AUTHORITY','CERTIFICATE_SIGNATORY'];
function requireInternal(principal:any,write=false){const allowed=write?INTERNAL_WRITE_ROLES:INTERNAL_READ_ROLES;if(!hasRole(principal,allowed))throw Object.assign(new Error('Internal DLF staff role required'),{statusCode:403,code:'ACTION_FORBIDDEN'})}
function requireFinalize(principal:any,status:any){if(['SIGNED','ARCHIVED'].includes(upper(status))&&!hasRole(principal,FINALIZE_ROLES))throw Object.assign(new Error('Signed/archived status requires approving/signatory authority'),{statusCode:403,code:'FINALIZE_FORBIDDEN'})}

async function audit(client:any,ctx:any,actionCode:string,resourceType:string,resourceId:any,beforeData:any,afterData:any,metadata:any={}){
  const actor=isUuid(ctx.principal?.userId)?ctx.principal.userId:null;
  const rid=isUuid(resourceId)?resourceId:null;
  const requestId=isUuid(ctx.ids?.requestId)?ctx.ids.requestId:null;
  const correlationId=isUuid(ctx.ids?.correlationId)?ctx.ids.correlationId:null;
  await client.query(`insert into audit.event(actor_user_id,action_code,resource_type,resource_id,request_id,correlation_id,before_data,after_data,metadata)
    values($1,$2,$3,$4,$5,$6,$7,$8,$9)`,[actor,actionCode,resourceType,rid,requestId,correlationId,beforeData||null,afterData||null,metadata||{}]);
}
async function outbox(client:any,ctx:any,eventType:string,aggregateType:string,aggregateId:string,payload:any){
  if(!isUuid(aggregateId))return;
  const correlationId=isUuid(ctx.ids?.correlationId)?ctx.ids.correlationId:null;
  await client.query(`insert into integration.outbox_event(event_type,aggregate_type,aggregate_id,schema_version,correlation_id,payload)
    values($1,$2,$3,1,$4,$5)`,[eventType,aggregateType,aggregateId,correlationId,payload||{}]);
}

async function memoCandidates(pool:any,url:any){
  const q=String(url.searchParams.get('q')||'').trim();
  const status=String(url.searchParams.get('status')||'').trim();
  const category=String(url.searchParams.get('category')||'').trim();
  const company=String(url.searchParams.get('company')||'').trim();
  const params:any[]=[];const where:string[]=[];
  if(q){params.push('%'+q+'%');where.push(`(coalesce(pr.registration_no,'') ilike $${params.length} or coalesce(pr.trade_name,'') ilike $${params.length} or coalesce(pr.generic_name,'') ilike $${params.length} or coalesce(pr.active_ingredients,'') ilike $${params.length})`)}
  if(status){params.push(status);where.push(`upper(coalesce(pr.registration_status,''))=upper($${params.length})`)}
  if(category){params.push(category);where.push(`coalesce(pr.category,'')=$${params.length}`)}
  if(company){params.push(company);where.push(`(coalesce(h.legal_name_lo,h.legal_name_en,'')=$${params.length} or coalesce(i.legal_name_lo,i.legal_name_en,'')=$${params.length})`)}
  const profiles=await pool.query(`select pr.id regulatory_profile_id,pr.product_id,pr.registration_no,pr.trade_name,pr.generic_name,pr.active_ingredients,
      pr.category,pr.dosage_form,pr.registration_type,pr.registration_status,pr.dlf_no,pr.dlf_date,pr.issue_date,pr.expiry_date,
      coalesce(h.legal_name_lo,h.legal_name_en) registration_holder,coalesce(i.legal_name_lo,i.legal_name_en) importer,
      pr.manufacturer_name,pr.manufacturer_country
    from product.product_regulatory_profile pr
    left join master.company h on h.party_id=pr.holder_company_id
    left join master.company i on i.party_id=pr.importer_company_id
    ${where.length?'where '+where.join(' and '):''}
    order by pr.dlf_date desc nulls last,pr.issue_date desc nulls last,pr.updated_at desc limit 1500`,params);
  if(!profiles.rows.length)return [];
  const ids=profiles.rows.map((x:any)=>x.product_id);
  const pk=await pool.query(`select p.id package_id,p.product_id,p.package_code,p.sub_code,p.presentation_status,
      pv.id package_version_id,pv.pack_description,pv.strength_text,pv.target_text,pv.container_type
    from product.package p
    left join lateral (select * from product.package_version x where x.package_id=p.id order by x.version_no desc limit 1) pv on true
    where p.product_id=any($1::uuid[]) and coalesce(p.presentation_status,'ACTIVE')<>'INACTIVE'
    order by p.product_id,p.sub_code nulls first,p.created_at`,[ids]);
  const byProduct=new Map<string,any[]>();
  for(const x of rows(pk)){const k=String(x.productId);if(!byProduct.has(k))byProduct.set(k,[]);byProduct.get(k)!.push(x)}
  return profiles.rows.map((r:any)=>({...camelRow(r),presentations:byProduct.get(String(r.product_id))||[]}));
}

async function memoSnapshot(client:any,selection:any,sequenceNo:number){
  const profileId=String(selection.regulatoryProfileId||'');
  if(!isUuid(profileId))throw Object.assign(new Error('Each memo item requires a valid regulatoryProfileId'),{statusCode:400,code:'INVALID_MEMO_PROFILE'});
  const pr=(await client.query(`select pr.*,coalesce(h.legal_name_lo,h.legal_name_en) registration_holder,
      coalesce(i.legal_name_lo,i.legal_name_en) importer
    from product.product_regulatory_profile pr
    left join master.company h on h.party_id=pr.holder_company_id
    left join master.company i on i.party_id=pr.importer_company_id
    where pr.id=$1`,[profileId])).rows[0];
  if(!pr)throw Object.assign(new Error('Veterinary drug registration profile not found'),{statusCode:404,code:'DRUG_PROFILE_NOT_FOUND'});
  const requested=arr(selection.selectedPackageIds).filter(isUuid);
  const params:any[]=[pr.product_id];
  let packageFilter='';
  if(requested.length){params.push(requested);packageFilter=`and p.id=any($2::uuid[])`}
  const packages=(await client.query(`select p.id package_id,p.package_code,p.sub_code,p.presentation_status,
      pv.id package_version_id,pv.pack_description,pv.strength_text,pv.target_text,pv.container_type
    from product.package p
    left join lateral (select * from product.package_version x where x.package_id=p.id order by x.version_no desc limit 1) pv on true
    where p.product_id=$1 and coalesce(p.presentation_status,'ACTIVE')<>'INACTIVE' ${packageFilter}
    order by p.sub_code nulls first,p.created_at`,params)).rows;
  if(requested.length && packages.length!==new Set(requested).size)throw Object.assign(new Error('One or more selected presentations do not belong to this drug product'),{statusCode:400,code:'PRESENTATION_MISMATCH'});
  const activeCount=(await client.query(`select count(*)::int n from product.package p where p.product_id=$1 and coalesce(p.presentation_status,'ACTIVE')<>'INACTIVE'`,[pr.product_id])).rows[0]?.n||0;
  const presentations=packages.map((p:any,i:number)=>({
    packageId:p.package_id,packageVersionId:p.package_version_id,packageCode:p.package_code,subCode:p.sub_code,
    subRegistrationNo:pr.registration_no?(activeCount>1?`${pr.registration_no}-${p.sub_code||String(i+1).padStart(2,'0')}`:pr.registration_no):null,
    strengthText:p.strength_text,packDescription:p.pack_description,targetText:p.target_text,containerType:p.container_type
  }));
  const app=(await client.query(`select a.id,a.application_no,a.current_status,ar.registration_id
    from registration.veterinary_drug_application a
    left join registration.veterinary_drug_application_registration ar on ar.application_id=a.id
    where a.regulatory_profile_id=$1 order by a.created_at desc limit 1`,[profileId])).rows[0]||{};
  return {
    sequenceNo,regulatoryProfileId:profileId,applicationId:app.id||null,registrationId:app.registration_id||null,
    registrationNoSnapshot:pr.registration_no||null,tradeNameSnapshot:pr.trade_name,genericNameSnapshot:pr.generic_name||pr.active_ingredients||null,
    categorySnapshot:pr.category||null,dosageFormSnapshot:pr.dosage_form||null,holderSnapshot:pr.registration_holder||pr.importer||null,
    manufacturerSnapshot:[pr.manufacturer_name,pr.manufacturer_country].filter(Boolean).join(', ')||null,
    selectedPresentations:presentations,
    sourceSnapshot:{dlfNo:pr.dlf_no,dlfDate:pr.dlf_date,issueDate:pr.issue_date,expiryDate:pr.expiry_date,registrationType:pr.registration_type,registrationStatus:pr.registration_status,activeIngredients:pr.active_ingredients,applicationNo:app.application_no,currentApplicationStatus:app.current_status}
  };
}

function memoHeader(body:any,principal:any){
  const m=obj(body.memo||body);
  const purposes=arr(m.purposes).map((x:any)=>String(x)).filter(Boolean);
  return {
    memoNo:text(m.memoNo,120),memoSuffix:text(m.memoSuffix,40)||'ພສວພ',memoDate:text(m.memoDate,10),placeText:text(m.placeText,300)||'ນະຄອນຫຼວງວຽງຈັນ',
    organizationName:text(m.organizationName,500)||'ກົມລ້ຽງສັດ ແລະ ການປະມົງ',departmentName:text(m.departmentName,500)||'ພະແນກສັດຕະວະແພດ',
    recipient:text(m.recipient,1000)||'ຫົວໜ້າກົມລ້ຽງສັດ ແລະ ການປະມົງ',subjectText:text(m.subjectText,2000),leadText:text(m.leadText,4000),
    purposes:purposes.length?purposes:['approve'],companyAuto:bool(m.companyAuto,true),groupByCompany:bool(m.groupByCompany,true),showLao:bool(m.showLao,true),showSubRegistration:bool(m.showSubRegistration,true),showPack:bool(m.showPack,true),showCategory:bool(m.showCategory,true),
    staffLines:arr(m.staffLines).slice(0,20),signatoryNames:obj(m.signatoryNames),notes:text(m.notes,8000),status:['DRAFT','READY','SIGNED','ARCHIVED','CANCELLED'].includes(upper(m.status))?upper(m.status):'DRAFT',
    actor:isUuid(principal?.userId)?principal.userId:null
  };
}

async function insertMemo(client:any,ctx:any,body:any,existingId:string|null=null){
  const h=memoHeader(body,ctx.principal);const selections=arr(body.items);
  if(!selections.length)throw Object.assign(new Error('Select at least one veterinary drug registration for the memo'),{statusCode:400,code:'MEMO_ITEMS_REQUIRED'});
  let memo:any;let before:any=null;
  if(existingId){
    before=(await client.query('select * from registration.veterinary_drug_internal_memo where id=$1 for update',[existingId])).rows[0];
    if(!before)throw Object.assign(new Error('Registration memo not found'),{statusCode:404,code:'MEMO_NOT_FOUND'});
    if(['SIGNED','ARCHIVED'].includes(before.status))throw Object.assign(new Error('Signed/archived memo is immutable; create a new memo or variation'),{statusCode:409,code:'MEMO_IMMUTABLE'});
    memo=(await client.query(`update registration.veterinary_drug_internal_memo set
      memo_no=$1,memo_suffix=$2,memo_date=coalesce($3::date,memo_date),place_text=$4,organization_name=$5,department_name=$6,recipient=$7,subject_text=$8,lead_text=$9,
      purposes=$10::jsonb,company_auto=$11,group_by_company=$12,show_lao=$13,show_sub_registration=$14,show_pack=$15,show_category=$16,
      staff_lines=$17::jsonb,signatory_names=$18::jsonb,notes=$19,status=$20,updated_by=$21,updated_at=now() where id=$22 returning *`,[
      h.memoNo,h.memoSuffix,h.memoDate,h.placeText,h.organizationName,h.departmentName,h.recipient,h.subjectText,h.leadText,JSON.stringify(h.purposes),h.companyAuto,h.groupByCompany,h.showLao,h.showSubRegistration,h.showPack,h.showCategory,JSON.stringify(h.staffLines),JSON.stringify(h.signatoryNames),h.notes,h.status,h.actor,existingId])).rows[0];
    await client.query("update registration.veterinary_drug_internal_memo_item set record_status='SUPERSEDED',updated_at=now() where memo_id=$1 and record_status='ACTIVE'",[existingId]);
  }else{
    memo=(await client.query(`insert into registration.veterinary_drug_internal_memo(
      memo_no,memo_suffix,memo_date,place_text,organization_name,department_name,recipient,subject_text,lead_text,purposes,company_auto,group_by_company,show_lao,show_sub_registration,show_pack,show_category,staff_lines,signatory_names,notes,status,created_by,updated_by)
      values($1,$2,coalesce($3::date,current_date),$4,$5,$6,$7,$8,$9,$10::jsonb,$11,$12,$13,$14,$15,$16,$17::jsonb,$18::jsonb,$19,$20,$21,$21) returning *`,[
      h.memoNo,h.memoSuffix,h.memoDate,h.placeText,h.organizationName,h.departmentName,h.recipient,h.subjectText,h.leadText,JSON.stringify(h.purposes),h.companyAuto,h.groupByCompany,h.showLao,h.showSubRegistration,h.showPack,h.showCategory,JSON.stringify(h.staffLines),JSON.stringify(h.signatoryNames),h.notes,h.status,h.actor])).rows[0];
  }
  const seen=new Set<string>();let seq=0;
  for(const sel of selections){
    const pid=String(sel?.regulatoryProfileId||'');if(seen.has(pid))continue;seen.add(pid);seq++;
    const s=await memoSnapshot(client,sel,seq);
    await client.query(`insert into registration.veterinary_drug_internal_memo_item(
      memo_id,sequence_no,regulatory_profile_id,application_id,registration_id,registration_no_snapshot,trade_name_snapshot,generic_name_snapshot,category_snapshot,dosage_form_snapshot,holder_snapshot,manufacturer_snapshot,selected_presentations,source_snapshot)
      values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13::jsonb,$14::jsonb)`,[
      memo.id,s.sequenceNo,s.regulatoryProfileId,s.applicationId,s.registrationId,s.registrationNoSnapshot,s.tradeNameSnapshot,s.genericNameSnapshot,s.categorySnapshot,s.dosageFormSnapshot,s.holderSnapshot,s.manufacturerSnapshot,JSON.stringify(s.selectedPresentations),JSON.stringify(s.sourceSnapshot)]);
  }
  const after=camelRow(memo);
  await audit(client,ctx,existingId?'veterinary_drug.internal_memo.update':'veterinary_drug.internal_memo.create','veterinary_drug_internal_memo',memo.id,before?camelRow(before):null,after,{itemCount:seq});
  await outbox(client,ctx,existingId?'veterinary_drug.internal_memo.updated.v1':'veterinary_drug.internal_memo.created.v1','veterinary_drug_internal_memo',memo.id,{memoId:memo.id,itemCount:seq,status:memo.status});
  return memo.id;
}

async function memoComplete(pool:any,id:string){
  const memo=(await pool.query('select * from registration.veterinary_drug_internal_memo where id=$1',[id])).rows[0];if(!memo)return null;
  const items=await pool.query(`select * from registration.veterinary_drug_internal_memo_item where memo_id=$1 and record_status='ACTIVE' order by sequence_no`,[id]);
  return {memo:camelRow(memo),items:rows(items)};
}

async function coordinationComplete(pool:any,applicationId:string){
  const app=(await pool.query(`select ia.*,coalesce(c.legal_name_lo,c.legal_name_en) operator_name from trade.import_application ia left join master.company c on c.party_id=ia.company_id where ia.id=$1`,[applicationId])).rows[0];
  if(!app)return null;
  const sheet=(await pool.query('select * from trade.application_coordination_sheet where application_id=$1',[applicationId])).rows[0];
  let items:any[]=[];
  if(sheet){items=rows(await pool.query(`select i.*,r.label_lo,r.label_en from trade.application_coordination_item i join lookup.regulatory_coordination_requirement r on r.requirement_code=i.requirement_code where i.sheet_id=$1 and i.record_status='ACTIVE' order by i.sequence_no`,[sheet.id]));}
  else{items=rows(await pool.query(`select requirement_code,sequence_no,label_lo,label_en,'PENDING'::text presence_status,'PENDING'::text quality_status,null::text reference_no,null::text notes from lookup.regulatory_coordination_requirement where scope_code='VET_DRUG_DEVICE_TRADE' and is_active=true order by sequence_no`));}
  return {application:camelRow(app),sheet:sheet?camelRow(sheet):null,items};
}

async function saveCoordination(client:any,ctx:any,applicationId:string,body:any){
  const app=(await client.query('select * from trade.import_application where id=$1 for update',[applicationId])).rows[0];if(!app)throw Object.assign(new Error('Trade application not found'),{statusCode:404,code:'TRADE_APPLICATION_NOT_FOUND'});
  let sheet=(await client.query('select * from trade.application_coordination_sheet where application_id=$1 for update',[applicationId])).rows[0];const before=sheet?camelRow(sheet):null;
  if(sheet&&['SIGNED','ARCHIVED'].includes(sheet.status))throw Object.assign(new Error('Signed/archived coordination sheet is immutable'),{statusCode:409,code:'COORDINATION_IMMUTABLE'});
  const m=obj(body.sheet||body);const actor=isUuid(ctx.principal?.userId)?ctx.principal.userId:null;const status=['DRAFT','REVIEWED','READY','SIGNED','ARCHIVED','CANCELLED'].includes(upper(m.status))?upper(m.status):'DRAFT';
  if(sheet){
    sheet=(await client.query(`update trade.application_coordination_sheet set sheet_no=$1,sheet_date=coalesce($2::date,sheet_date),subject_text=$3,overall_comment=$4,reviewer_name=$5,reviewer_position=$6,head_section_name=$7,deputy_director_comment=$8,signatory_names=$9::jsonb,status=$10,updated_by=$11,updated_at=now() where id=$12 returning *`,[text(m.sheetNo,120),text(m.sheetDate,10),text(m.subjectText,2000),text(m.overallComment,8000),text(m.reviewerName,500),text(m.reviewerPosition,500),text(m.headSectionName,500),text(m.deputyDirectorComment,8000),JSON.stringify(obj(m.signatoryNames)),status,actor,sheet.id])).rows[0];
    await client.query("update trade.application_coordination_item set record_status='SUPERSEDED',updated_at=now() where sheet_id=$1 and record_status='ACTIVE'",[sheet.id]);
  }else{
    sheet=(await client.query(`insert into trade.application_coordination_sheet(application_id,sheet_no,sheet_date,subject_text,overall_comment,reviewer_name,reviewer_position,head_section_name,deputy_director_comment,signatory_names,status,created_by,updated_by) values($1,$2,coalesce($3::date,current_date),$4,$5,$6,$7,$8,$9,$10::jsonb,$11,$12,$12) returning *`,[applicationId,text(m.sheetNo,120),text(m.sheetDate,10),text(m.subjectText,2000),text(m.overallComment,8000),text(m.reviewerName,500),text(m.reviewerPosition,500),text(m.headSectionName,500),text(m.deputyDirectorComment,8000),JSON.stringify(obj(m.signatoryNames)),status,actor])).rows[0];
  }
  const defaults=(await client.query(`select requirement_code,sequence_no,label_lo from lookup.regulatory_coordination_requirement where scope_code='VET_DRUG_DEVICE_TRADE' and is_active=true order by sequence_no`)).rows;
  const inputByCode=new Map(arr(body.items).map((x:any)=>[String(x.requirementCode||''),x]));
  for(const d of defaults){const x:any=inputByCode.get(d.requirement_code)||{};const presence=['PENDING','PRESENT','MISSING','NOT_APPLICABLE'].includes(upper(x.presenceStatus))?upper(x.presenceStatus):'PENDING';const quality=['PENDING','CORRECT','INCORRECT','POLICY','NOT_APPLICABLE'].includes(upper(x.qualityStatus))?upper(x.qualityStatus):'PENDING';
    await client.query(`insert into trade.application_coordination_item(sheet_id,requirement_code,sequence_no,label_snapshot,presence_status,quality_status,reference_no,notes,document_id) values($1,$2,$3,$4,$5,$6,$7,$8,$9)`,[sheet.id,d.requirement_code,d.sequence_no,d.label_lo,presence,quality,text(x.referenceNo,2000),text(x.notes,4000),isUuid(x.documentId)?x.documentId:null]);}
  await audit(client,ctx,before?'trade.coordination_sheet.update':'trade.coordination_sheet.create','application_coordination_sheet',sheet.id,before,camelRow(sheet),{applicationId});
  await outbox(client,ctx,before?'trade.coordination_sheet.updated.v1':'trade.coordination_sheet.created.v1','trade_application',applicationId,{applicationId,sheetId:sheet.id,status:sheet.status});
  return sheet.id;
}

function dateRangeWhere(url:any,column:string,params:any[],where:string[]){const from=String(url.searchParams.get('from')||'').trim(),to=String(url.searchParams.get('to')||'').trim();if(from){params.push(from);where.push(`${column} >= $${params.length}::date`)}if(to){params.push(to);where.push(`${column} <= $${params.length}::date`)}}
async function drugReport(pool:any,url:any){
  const basis=upper(url.searchParams.get('dateBasis')||'DLF_DATE');const col=({DLF_DATE:'dlf_date',REGISTRATION_DATE:'issue_date',ISSUE_DATE:'issue_date',EXPIRY_DATE:'expiry_date',APPLICATION_DATE:'application_date'} as any)[basis]||'dlf_date';
  const params:any[]=[];const where:string[]=[];dateRangeWhere(url,col,params,where);
  for(const [key,field] of [['status','registration_status'],['category','category'],['registrationType','registration_type'],['company','registration_holder']] as any[]){const v=String(url.searchParams.get(key)||'').trim();if(v){params.push(v);where.push(`coalesce(${field},'')=$${params.length}`)}}
  const q=String(url.searchParams.get('q')||'').trim();if(q){params.push('%'+q+'%');where.push(`(coalesce(registration_no,'') ilike $${params.length} or coalesce(trade_name,'') ilike $${params.length} or coalesce(generic_name,'') ilike $${params.length} or coalesce(active_ingredients,'') ilike $${params.length})`)}
  const r=await pool.query(`select * from analytics.v_veterinary_drug_registry_report ${where.length?'where '+where.join(' and '):''} order by ${col} desc nulls last,trade_name limit 5000`,params);return {rows:rows(r),dateBasis:basis};
}
async function annualPlanOverview(pool:any,url:any){
  const year=Number(url.searchParams.get('year')||0)||null;const params:any[]=[];const where:string[]=[];if(year){params.push(year);where.push(`p.plan_year=$${params.length}`)}
  const r=await pool.query(`select p.id,p.plan_no,p.plan_year,p.application_date,p.approval_no,p.approval_date,p.status,
      coalesce(c.legal_name_lo,c.legal_name_en) operator_name,
      coalesce(pp.detail_level,'ITEM') detail_level,coalesce(pp.movement_type,'IMPORT') movement_type,coalesce(pp.service_type,'VET_DRUG_DEVICE') service_type,
      count(b.plan_item_id)::int item_count,
      count(b.plan_item_id) filter(where coalesce(b.actual_cleared_quantity,0)>0)::int used_item_count,
      coalesce(sum(b.clearance_count),0)::int clearance_count,
      count(b.plan_item_id) filter(where coalesce(b.remaining_quantity,0)<0)::int over_plan_item_count
    from trade.import_plan p
    left join master.company c on c.party_id=p.company_id
    left join trade.import_plan_profile pp on pp.import_plan_id=p.id
    left join analytics.v_import_plan_item_balance b on b.plan_id=p.id
    ${where.length?'where '+where.join(' and '):''}
    group by p.id,p.plan_no,p.plan_year,p.application_date,p.approval_no,p.approval_date,p.status,c.legal_name_lo,c.legal_name_en,pp.detail_level,pp.movement_type,pp.service_type
    order by p.plan_year desc,p.application_date desc nulls last,p.plan_no`,params);return rows(r)
}

async function tradeReport(pool:any,url:any){
  const basis=upper(url.searchParams.get('dateBasis')||'APPLICATION_DATE');const col=({APPLICATION_DATE:'application_date',DECISION_DATE:'decision_date',CLEARED_DATE:'cleared_date'} as any)[basis]||'application_date';
  const params:any[]=[];const where:string[]=[];dateRangeWhere(url,col,params,where);
  for(const [key,field] of [['status','status'],['movementType','movement_type'],['company','operator_name']] as any[]){const v=String(url.searchParams.get(key)||'').trim();if(v){params.push(v);where.push(`coalesce(${field},'')=$${params.length}`)}}
  const q=String(url.searchParams.get('q')||'').trim();if(q){params.push('%'+q+'%');where.push(`(coalesce(permit_no,'') ilike $${params.length} or coalesce(application_no,'') ilike $${params.length} or coalesce(operator_name,'') ilike $${params.length})`)}
  const r=await pool.query(`select * from analytics.v_veterinary_trade_permit_report ${where.length?'where '+where.join(' and '):''} order by ${col} desc nulls last,permit_no limit 5000`,params);return {rows:rows(r),dateBasis:basis};
}


function exactFilter(url:any,key:string,field:string,params:any[],where:string[],upperCompare=false){
  const v=String(url.searchParams.get(key)||'').trim();
  if(!v)return;
  params.push(v);
  where.push(upperCompare?`upper(coalesce(${field},''))=upper($${params.length})`:`coalesce(${field},'')=$${params.length}`);
}
async function importAnalytics(pool:any,url:any){
  const params:any[]=[];const where:string[]=[];
  const year=Number(url.searchParams.get('year')||0);
  if(year){params.push(year);where.push(`coalesce(d.plan_year,extract(year from d.application_date)::integer)=$${params.length}`)}
  const planId=String(url.searchParams.get('planId')||'').trim();if(planId&&isUuid(planId)){params.push(planId);where.push(`d.plan_id=$${params.length}::uuid`)}
  exactFilter(url,'movementType','d.movement_type',params,where,true);
  exactFilter(url,'status','d.application_status',params,where,true);
  for(const [key,field] of [['company','d.company_name'],['checkpoint','d.border_checkpoint'],['originCountry','d.origin_country']] as any[]){const v=String(url.searchParams.get(key)||'').trim();if(v){params.push('%'+v+'%');where.push(`coalesce(${field},'') ilike $${params.length}`)}}
  exactFilter(url,'category','d.category_code',params,where,false);
  const from=String(url.searchParams.get('from')||'').trim(),to=String(url.searchParams.get('to')||'').trim();
  if(from){params.push(from);where.push(`d.application_date >= $${params.length}::date`)}
  if(to){params.push(to);where.push(`d.application_date <= $${params.length}::date`)}
  const q=String(url.searchParams.get('q')||'').trim();
  if(q){params.push('%'+q+'%');where.push(`(
    coalesce(d.item_name,'') ilike $${params.length}
    or coalesce(d.registration_no,'') ilike $${params.length}
    or coalesce(d.plan_reference_name,'') ilike $${params.length}
    or coalesce(d.application_no,'') ilike $${params.length}
    or coalesce(d.permit_no,'') ilike $${params.length}
    or coalesce(d.company_name,'') ilike $${params.length}
  )`)}
  const wh=where.length?'where '+where.join(' and '):'';

  const summary=(await pool.query(`select
      count(distinct d.application_id)::int application_count,
      count(distinct case when upper(coalesce(d.application_status,'')) in ('APPROVED','CLEARED','CLOSED','COMPLETED') then d.application_id end)::int approval_count,
      count(distinct case when d.actual_cleared_value_usd>0 or d.cleared_quantity>0 or upper(coalesce(d.application_status,'')) in ('CLEARED','CLOSED','COMPLETED') then d.application_id end)::int import_count,
      count(distinct d.company_id)::int company_count,
      count(distinct d.actual_item_key)::int unique_item_count,
      count(*)::int line_count,
      coalesce(sum(d.approved_value_usd),0)::numeric(20,2) approved_value_usd,
      coalesce(sum(d.actual_cleared_value_usd),0)::numeric(20,2) actual_cleared_value_usd,
      coalesce(sum(d.active_substance_kg),0)::numeric(20,6) active_substance_kg,
      count(*) filter(where d.plan_item_id is null)::int unlinked_line_count,
      count(*) filter(where d.unit_compatible=false)::int unit_mismatch_line_count
    from analytics.v_import_transaction_detail d ${wh}`,params)).rows[0];

  const companies=await pool.query(`select d.company_id,d.company_name,
      count(distinct case when upper(coalesce(d.application_status,'')) in ('APPROVED','CLEARED','CLOSED','COMPLETED') then d.application_id end)::int approval_count,
      count(distinct case when d.actual_cleared_value_usd>0 or d.cleared_quantity>0 or upper(coalesce(d.application_status,'')) in ('CLEARED','CLOSED','COMPLETED') then d.application_id end)::int import_count,
      count(distinct d.actual_item_key)::int unique_item_count,
      count(*)::int line_count,
      coalesce(sum(d.approved_value_usd),0)::numeric(20,2) approved_value_usd,
      coalesce(sum(d.actual_cleared_value_usd),0)::numeric(20,2) actual_cleared_value_usd
    from analytics.v_import_transaction_detail d ${wh}
    group by d.company_id,d.company_name
    order by actual_cleared_value_usd desc,import_count desc,d.company_name
    limit 100`,params);

  const products=await pool.query(`select d.actual_item_key,d.item_name,d.registration_no,d.item_type,d.unit_code,
      count(distinct case when upper(coalesce(d.application_status,'')) in ('APPROVED','CLEARED','CLOSED','COMPLETED') then d.application_id end)::int approval_count,
      count(distinct case when d.actual_cleared_value_usd>0 or d.cleared_quantity>0 or upper(coalesce(d.application_status,'')) in ('CLEARED','CLOSED','COMPLETED') then d.application_id end)::int import_count,
      count(distinct d.company_id)::int company_count,
      coalesce(sum(d.requested_quantity),0)::numeric(20,3) requested_quantity,
      coalesce(sum(coalesce(d.approved_quantity,d.requested_quantity,0)),0)::numeric(20,3) approved_quantity,
      coalesce(sum(d.cleared_quantity),0)::numeric(20,3) actual_cleared_quantity,
      coalesce(sum(d.actual_cleared_value_usd),0)::numeric(20,2) actual_cleared_value_usd
    from analytics.v_import_transaction_detail d ${wh}
    group by d.actual_item_key,d.item_name,d.registration_no,d.item_type,d.unit_code
    order by actual_cleared_value_usd desc,import_count desc,d.item_name
    limit 150`,params);

  const checkpoints=await pool.query(`select coalesce(nullif(d.border_checkpoint,''),'—') border_checkpoint,
      count(distinct case when d.actual_cleared_value_usd>0 or d.cleared_quantity>0 or upper(coalesce(d.application_status,'')) in ('CLEARED','CLOSED','COMPLETED') then d.application_id end)::int import_count,
      count(distinct d.company_id)::int company_count,
      count(distinct d.actual_item_key)::int unique_item_count,
      coalesce(sum(d.actual_cleared_value_usd),0)::numeric(20,2) actual_cleared_value_usd
    from analytics.v_import_transaction_detail d ${wh}
    group by coalesce(nullif(d.border_checkpoint,''),'—')
    order by actual_cleared_value_usd desc,import_count desc
    limit 100`,params);

  const origins=await pool.query(`select coalesce(nullif(d.origin_country,''),'—') origin_country,
      count(distinct case when d.actual_cleared_value_usd>0 or d.cleared_quantity>0 or upper(coalesce(d.application_status,'')) in ('CLEARED','CLOSED','COMPLETED') then d.application_id end)::int import_count,
      count(distinct d.actual_item_key)::int unique_item_count,
      coalesce(sum(d.actual_cleared_value_usd),0)::numeric(20,2) actual_cleared_value_usd
    from analytics.v_import_transaction_detail d ${wh}
    group by coalesce(nullif(d.origin_country,''),'—')
    order by actual_cleared_value_usd desc,import_count desc
    limit 100`,params);

  const transactions=await pool.query(`select d.*
    from analytics.v_import_transaction_detail d ${wh}
    order by coalesce(d.cleared_date,d.decision_date,d.application_date) desc nulls last,d.application_no,d.application_item_no
    limit 1500`,params);

  const planParams:any[]=[];const planWhere:string[]=[];
  if(year){planParams.push(year);planWhere.push(`p.plan_year=$${planParams.length}`)}
  if(planId&&isUuid(planId)){planParams.push(planId);planWhere.push(`p.plan_id=$${planParams.length}::uuid`)}
  const company=String(url.searchParams.get('company')||'').trim();if(company){planParams.push('%'+company+'%');planWhere.push(`coalesce(p.company_name,'') ilike $${planParams.length}`)}
  const pq=String(url.searchParams.get('q')||'').trim();if(pq){planParams.push('%'+pq+'%');planWhere.push(`(coalesce(p.item_name,'') ilike $${planParams.length} or coalesce(p.registration_no,'') ilike $${planParams.length} or coalesce(p.company_name,'') ilike $${planParams.length})`)}
  const category=String(url.searchParams.get('category')||'').trim();if(category){planParams.push(category);planWhere.push(`coalesce(p.category_code,'')=$${planParams.length}`)}
  const planTracking=await pool.query(`select p.* from analytics.v_import_plan_tracking p
    ${planWhere.length?'where '+planWhere.join(' and '):''}
    order by p.plan_year desc,p.company_name,p.item_no
    limit 3000`,planParams);

  const overPlan=planTracking.rows.filter((x:any)=>String(x.tracking_status)==='OVER_PLAN').length;
  const unitMismatch=planTracking.rows.filter((x:any)=>String(x.tracking_status)==='UNIT_MISMATCH').length;
  return {
    summary:{...camelRow(summary),overPlanCount:overPlan,unitMismatchPlanCount:unitMismatch},
    companies:rows(companies),products:rows(products),checkpoints:rows(checkpoints),origins:rows(origins),
    transactions:rows(transactions),planTracking:rows(planTracking)
  };
}

async function planItemProfile(pool:any,planItemId:string){
  const r=await pool.query(`select pi.id plan_item_id,pi.plan_id,pi.item_no,pi.item_name,pi.line_mode,pi.group_code,pi.group_name,
      pi.planned_quantity,pi.planned_item_count,pi.unit_code,pi.planned_value,
      coalesce(p.scope_type,'ITEM') scope_type,p.category_code,
      coalesce(p.planned_value_usd,pi.planned_value) planned_value_usd,
      coalesce(p.planned_item_count,pi.planned_item_count) profile_planned_item_count,
      coalesce(p.tracking_basis,'QUANTITY') tracking_basis,
      coalesce(p.count_is_reference,true) count_is_reference,
      coalesce(p.allow_item_mapping,true) allow_item_mapping,p.notes profile_notes
    from trade.import_plan_item pi
    left join trade.import_plan_item_profile p on p.plan_item_id=pi.id
    where pi.id=$1`,[planItemId]);
  return r.rows[0]?camelRow(r.rows[0]):null;
}
async function savePlanItemProfile(client:any,ctx:any,planItemId:string,body:any){
  const b=obj(body);const allowed=['QUANTITY','VALUE','QUANTITY_VALUE','COUNT_VALUE','REFERENCE_ONLY'];
  let basis=allowed.includes(upper(b.trackingBasis))?upper(b.trackingBasis):'QUANTITY';
  const lineMode=upper(b.lineMode)==='SUMMARY_GROUP'?'SUMMARY_GROUP':'ITEM';
  if(lineMode==='SUMMARY_GROUP'&&['QUANTITY','QUANTITY_VALUE'].includes(basis))basis='COUNT_VALUE';
  const scope=['ITEM','CATEGORY','GROUP'].includes(upper(b.scopeType))?upper(b.scopeType):'ITEM';
  const plannedCount=b.plannedItemCount===null||b.plannedItemCount===''||b.plannedItemCount===undefined?null:Number(b.plannedItemCount);
  const plannedValue=b.plannedValueUsd===null||b.plannedValueUsd===''||b.plannedValueUsd===undefined?null:Number(b.plannedValueUsd);
  const before=(await client.query('select * from trade.import_plan_item_profile where plan_item_id=$1 for update',[planItemId])).rows[0]||null;
  const item=(await client.query('select * from trade.import_plan_item where id=$1 for update',[planItemId])).rows[0];
  if(!item)throw Object.assign(new Error('Annual-plan item not found'),{statusCode:404,code:'PLAN_ITEM_NOT_FOUND'});
  await client.query(`insert into trade.import_plan_item_profile
    (plan_item_id,scope_type,category_code,planned_value_usd,planned_item_count,tracking_basis,count_is_reference,allow_item_mapping,notes)
    values($1,$2,$3,$4,$5,$6,$7,$8,$9)
    on conflict(plan_item_id) do update set
      scope_type=excluded.scope_type,category_code=excluded.category_code,
      planned_value_usd=excluded.planned_value_usd,planned_item_count=excluded.planned_item_count,
      tracking_basis=excluded.tracking_basis,count_is_reference=excluded.count_is_reference,
      allow_item_mapping=excluded.allow_item_mapping,notes=excluded.notes,updated_at=now()`,
    [planItemId,scope,text(b.categoryCode,100),Number.isFinite(plannedValue)?plannedValue:null,Number.isFinite(plannedCount)?Math.max(0,Math.trunc(plannedCount)):null,basis,bool(b.countIsReference,true),bool(b.allowItemMapping,true),text(b.notes,4000)]);
  await client.query(`update trade.import_plan_item set
      line_mode=$1,
      planned_item_count=coalesce($2,planned_item_count),
      group_code=coalesce($3,group_code),
      group_name=coalesce($4,group_name)
    where id=$5`,[lineMode,Number.isFinite(plannedCount)?Math.max(0,Math.trunc(plannedCount)):null,text(b.categoryCode,60),text(b.groupName,1000),planItemId]);
  const after=(await client.query('select * from trade.import_plan_item_profile where plan_item_id=$1',[planItemId])).rows[0];
  await audit(client,ctx,before?'import_plan.item_profile.update':'import_plan.item_profile.create','import_plan_item',planItemId,before,after,{trackingBasis:basis});
}
export async function handleLegacyParityApi(ctx:any){
  const {req,url,store,principal,ids,readJson}=ctx;const root='/api/v1/legacy-parity';
  if(!url.pathname.startsWith(root))return null;
  if(!principal?.isAuthenticated)return error(401,'UNAUTHENTICATED','Authentication required',ids);
  if(store?.mode!=='postgres')return error(501,'POSTGRES_REQUIRED','Legacy parity operations require PostgreSQL/Supabase mode',ids);
  const pool=(store as any).pool;if(!pool)return error(501,'POSTGRES_POOL_REQUIRED','PostgreSQL pool is not available',ids);
  try{
    requireInternal(principal,false);
    if(url.pathname===root+'/registration-candidates'&&req.method==='GET')return result(200,await memoCandidates(pool,url),ids);
    if(url.pathname===root+'/registration-memos'&&req.method==='GET'){
      const r=await pool.query(`select m.*,coalesce(x.item_count,0)::int item_count from registration.veterinary_drug_internal_memo m left join lateral (select count(*)::int item_count from registration.veterinary_drug_internal_memo_item i where i.memo_id=m.id and i.record_status='ACTIVE') x on true order by m.memo_date desc,m.updated_at desc limit 500`);return result(200,rows(r),ids);
    }
    if(url.pathname===root+'/registration-memos'&&req.method==='POST'){
      requireInternal(principal,true);
      const body=await readJson(req);requireFinalize(principal,obj(body.memo||body).status);const client=await pool.connect();try{await client.query('begin');const id=await insertMemo(client,ctx,body,null);await client.query('commit');return result(201,await memoComplete(pool,id),ids)}catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}
    }
    const memoPath=url.pathname.match(/^\/api\/v1\/legacy-parity\/registration-memos\/([^/]+)$/);
    if(memoPath&&req.method==='GET'){const id=decodeURIComponent(memoPath[1]);if(!isUuid(id))return error(400,'INVALID_MEMO_ID','Invalid memo id',ids);const data=await memoComplete(pool,id);return data?result(200,data,ids):error(404,'MEMO_NOT_FOUND','Registration memo not found',ids)}
    if(memoPath&&req.method==='PATCH'){const id=decodeURIComponent(memoPath[1]);if(!isUuid(id))return error(400,'INVALID_MEMO_ID','Invalid memo id',ids);requireInternal(principal,true);const body=await readJson(req);requireFinalize(principal,obj(body.memo||body).status);const client=await pool.connect();try{await client.query('begin');await insertMemo(client,ctx,body,id);await client.query('commit');return result(200,await memoComplete(pool,id),ids)}catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}}

    const coord=url.pathname.match(/^\/api\/v1\/legacy-parity\/trade-coordination\/([^/]+)$/);
    if(coord&&req.method==='GET'){const appId=decodeURIComponent(coord[1]);if(!isUuid(appId))return error(400,'INVALID_APPLICATION_ID','Invalid trade application id',ids);const data=await coordinationComplete(pool,appId);return data?result(200,data,ids):error(404,'TRADE_APPLICATION_NOT_FOUND','Trade application not found',ids)}
    if(coord&&req.method==='PUT'){const appId=decodeURIComponent(coord[1]);if(!isUuid(appId))return error(400,'INVALID_APPLICATION_ID','Invalid trade application id',ids);requireInternal(principal,true);const body=await readJson(req);requireFinalize(principal,obj(body.sheet||body).status);const client=await pool.connect();try{await client.query('begin');await saveCoordination(client,ctx,appId,body);await client.query('commit');return result(200,await coordinationComplete(pool,appId),ids)}catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}}

    if(url.pathname===root+'/annual-plan-overview'&&req.method==='GET')return result(200,await annualPlanOverview(pool,url),ids);
    const planProfilePath=url.pathname.match(/^\/api\/v1\/legacy-parity\/import-plan-item-profile\/([^/]+)$/);
    if(planProfilePath&&req.method==='GET'){const id=decodeURIComponent(planProfilePath[1]);if(!isUuid(id))return error(400,'INVALID_PLAN_ITEM_ID','Invalid annual-plan item id',ids);const data=await planItemProfile(pool,id);return data?result(200,data,ids):error(404,'PLAN_ITEM_NOT_FOUND','Annual-plan item not found',ids)}
    if(planProfilePath&&req.method==='PUT'){const id=decodeURIComponent(planProfilePath[1]);if(!isUuid(id))return error(400,'INVALID_PLAN_ITEM_ID','Invalid annual-plan item id',ids);requireInternal(principal,true);const body=await readJson(req);const client=await pool.connect();try{await client.query('begin');await savePlanItemProfile(client,ctx,id,body);await client.query('commit');return result(200,await planItemProfile(pool,id),ids)}catch(e){try{await client.query('rollback')}catch{}throw e}finally{client.release()}}
    if(url.pathname===root+'/reports/import-analytics'&&req.method==='GET'){const d=await importAnalytics(pool,url);return result(200,d,ids,{source:'import-analytics'})}
    if(url.pathname===root+'/reports/drugs'&&req.method==='GET'){const d=await drugReport(pool,url);return result(200,d.rows,ids,{dateBasis:d.dateBasis,total:d.rows.length})}
    if(url.pathname===root+'/reports/trade'&&req.method==='GET'){const d=await tradeReport(pool,url);return result(200,d.rows,ids,{dateBasis:d.dateBasis,total:d.rows.length})}
    return error(404,'LEGACY_PARITY_ROUTE_NOT_FOUND','Legacy parity endpoint not found',ids);
  }catch(raw:any){const e=dbError(raw);return error(Number(e.statusCode||500),String(e.code||'LEGACY_PARITY_ERROR'),String(e.message||'Legacy parity operation failed'),ids)}
}
