// @ts-nocheck
import {calculateAmu,summarizeAmu,amuClasses,modes} from './amu-calculation.js';
import {sendJson} from './http.js';
const fail=(code,message,statusCode=400)=>{throw Object.assign(new Error(message),{code,statusCode})};
const uuid=v=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
export async function amuBody(req){let n=0;const chunks=[];for await(const chunk of req){n+=chunk.length;if(n>262144)fail('PAYLOAD_TOO_LARGE','Maximum 256 KiB',413);chunks.push(chunk)}try{return JSON.parse(Buffer.concat(chunks).toString('utf8'))}catch{fail('INVALID_JSON','Invalid JSON')}}
export async function handleAmuApi({req,res,url,store,ids,principal}){
 if(!url.pathname.startsWith('/api/v1/animuse/ledger'))return false;
 if(!principal.isAuthenticated)fail('UNAUTHENTICATED','Authentication required',401);
 if(!(principal.roles||[]).some(r=>['SYSTEM_ADMIN','SECURITY_ADMIN','DATA_STEWARD','REGISTRY_OFFICER','BORDER_OFFICER','CHECKPOINT_SUPERVISOR','TECHNICAL_REVIEWER','APPROVING_AUTHORITY'].includes(r)))fail('FORBIDDEN','Staff role required for antimicrobial trade records',403);
 if(principal.mustChangePassword)fail('PASSWORD_CHANGE_REQUIRED','Change password first',403);
 if(store.mode!=='postgres')fail('POSTGRES_REQUIRED','ANIMUSE requires PostgreSQL',501);
 const path=url.pathname.slice('/api/v1/animuse/ledger'.length),reply=(data,status=200)=>{sendJson(res,status,{data,meta:{requestId:ids.requestId}},ids);return true};
 const roles=principal.roles||[];
 if(req.method!=='GET'&&!roles.some(r=>['SYSTEM_ADMIN','REGISTRY_OFFICER','BORDER_OFFICER','CHECKPOINT_SUPERVISOR','TECHNICAL_REVIEWER','APPROVING_AUTHORITY'].includes(r)))fail('FORBIDDEN','Trade officer role required',403);
 if(path==='/reference'&&req.method==='GET'){const substances=(await store.pool.query('select substance_name_en,animuse_class_code,iu_per_mg,ionophore,source from analytics.amr_substance_reference order by substance_name_en limit 1000')).rows;return reply({classes:amuClasses,modes,substances});}
 if(path==='/calculate'&&req.method==='POST')return reply(calculateAmu(await amuBody(req)));
 if(path==='/trade-items'&&req.method==='GET'){
  const q=String(url.searchParams.get('q')||'').slice(0,120);
  const r=await store.pool.query(`select i.id,i.item_name as "productName",i.item_no as "lineRef",i.cleared_packs as "packCount",i.product_id as "productId",i.package_id as "packageId",a.import_type as "movementType",a.cleared_date as "arrivalDate",a.permit_no as "sourceRef",a.application_no as "applicationNo",a.status,c.legal_name_lo as "companyName" from trade.import_application_item i join trade.import_application a on a.id=i.application_id join master.company c on c.party_id=a.company_id where ($1='' or i.item_name ilike '%'||$1||'%' or a.permit_no ilike '%'||$1||'%') order by a.application_date desc,i.item_no limit 100`,[q]);return reply(r.rows);
 }
 if(path==='/presentations'&&req.method==='GET'){
  const q=String(url.searchParams.get('q')||'').trim().slice(0,120);
  const r=await store.pool.query(`select p.id as "productId",pk.id as "packageId",pr.registration_no as "registrationNo",pr.registration_status as "registrationStatus",pr.expiry_date as "expiryDate",pr.trade_name as "productName",pk.sub_code as "subCode",pv.basis_text as "basisText",pv.strength_text as "strengthText",pv.pack_description as "packSizeText",pv.pack_size as "packSize",pv.unit_code as "packUnit",coalesce((select jsonb_agg(jsonb_build_object('name',pc.ingredient_name,'quantity',pc.quantity_text,'unit',pc.unit_text)) from product.package_composition pc where pc.package_version_id=pv.id and pc.ingredient_role='ACTIVE'),'[]') as composition from product.product_regulatory_profile pr join product.product p on p.id=pr.product_id join product.package pk on pk.product_id=p.id left join lateral (select * from product.package_version where package_id=pk.id order by version_no desc limit 1) pv on true where ($1='' or pr.trade_name ilike '%'||$1||'%' or pr.registration_no ilike '%'||$1||'%') order by pr.registration_no,pk.sub_code limit 100`,[q]);
  return reply(r.rows);
 }
 if(path===''&&req.method==='GET'){
  const year=Number(url.searchParams.get('year')||new Date().getUTCFullYear());
  if(!Number.isInteger(year)||year<2000||year>2200)fail('INVALID_YEAR','Invalid reporting year');
  const records=(await store.pool.query('select * from analytics.amu_movement where movement_date >= $1::date and movement_date < $2::date order by movement_date desc,id',[`${year}-01-01`,`${year+1}-01-01`])).rows;
  return reply({year,records,summary:summarizeAmu(records)});
 }
 const match=path.match(/^\/([0-9a-f-]{36})(?:\/(review|void))?$/i);
 if(!(path===''&&req.method==='POST')&&!(match&&uuid(match[1])&&(['PATCH','POST'].includes(req.method))))fail('NOT_FOUND','ANIMUSE route not found',404);
 const input=await amuBody(req),client=await store.pool.connect();
 try{
  await client.query('begin');let before=null,data,action;
  if(match){before=(await client.query('select * from analytics.amu_movement where id=$1 for update',[match[1]])).rows[0];if(!before)fail('NOT_FOUND','Movement not found',404);if(input.version!==before.version)fail('STALE_VERSION','Reload this movement before saving',409);if(before.status==='VOID')fail('VOID_RECORD','Voided records cannot be edited',409);}
  if(match?.[2]){
   if(req.method!=='POST')fail('METHOD_NOT_ALLOWED','POST required',405);
   const note=typeof input.note==='string'?input.note.trim().slice(0,2000):'';
   if(!note)fail('REVIEW_NOTE_REQUIRED','Review or void reason required');
   if(match[2]==='review'){
    if(before.status!=='DRAFT')fail('ALREADY_REVIEWED','Already reviewed',409);
    if(!roles.some(r=>['SYSTEM_ADMIN','TECHNICAL_REVIEWER','APPROVING_AUTHORITY','CHECKPOINT_SUPERVISOR'].includes(r)))fail('FORBIDDEN','Reviewer role required',403);
    const c=calculateAmu(before.payload);if(c.issues.length)fail('INCOMPLETE_DATA','Resolve missing evidence, quantities and units before review');
   }
   const state=match[2]==='review'?'REVIEWED':'VOID';action=match[2];
   data=(await client.query('update analytics.amu_movement set status=$2,reviewed_by=$3,review_note=$4,version=version+1,updated_at=now() where id=$1 returning *',[before.id,state,principal.userId,note])).rows[0];
  }else{
   if((before&&req.method!=='PATCH')||(!before&&req.method!=='POST'))fail('METHOD_NOT_ALLOWED','Invalid method',405);
   const c=calculateAmu(input),p=c.data;
   for(const key of ['productId','packageId','applicationItemId'])if(p[key]&&!uuid(p[key]))fail('INVALID_ID','Invalid '+key);
   if(p.registrationBasis!=='REGISTERED'&&(p.productId||p.packageId))fail('INVALID_LINK','Choose a registered presentation or remove registry links');
   if(p.packageId){const linked=(await client.query(`select pr.registration_no,pr.registration_status,pr.expiry_date,pk.sub_code,(select jsonb_build_object('versionNo',pv.version_no,'basis',pv.basis_text,'pack',pv.pack_description,'strength',pv.strength_text) from product.package_version pv where pv.package_id=pk.id order by pv.version_no desc limit 1) as presentation from product.package pk join product.product_regulatory_profile pr on pr.product_id=pk.product_id where pk.id=$1 and pk.product_id=$2`,[p.packageId,p.productId])).rows[0];if(!linked)fail('INVALID_PRESENTATION','Presentation must belong to this registered product');p.registrySnapshot=linked;}
   if(p.applicationItemId){const item=(await client.query('select product_id,package_id from trade.import_application_item where id=$1',[p.applicationItemId])).rows[0];if(!item)fail('INVALID_TRADE_LINK','Trade item not found');if((item.product_id&&item.product_id!==p.productId)||(item.package_id&&item.package_id!==p.packageId))fail('INVALID_TRADE_LINK','Trade item and registry presentation do not match');}
   const sourceKey=JSON.stringify([p.sourceRef.normalize('NFKC').toUpperCase(),p.lineRef.normalize('NFKC').toUpperCase(),p.movementType]);
   const values=[sourceKey,p.arrivalDate,p.movementType,p.productId,p.packageId,p.applicationItemId,JSON.stringify(p),JSON.stringify(c),principal.userId];
   if(before){action='revise';data=(await client.query(`update analytics.amu_movement set source_key=$1,movement_date=$2,movement_type=$3,product_id=$4,package_id=$5,application_item_id=$6,payload=$7,calculation=$8,status='DRAFT',reviewed_by=null,review_note=null,version=version+1,updated_at=now() where id=$9 returning *`,[...values.slice(0,8),before.id])).rows[0];}
   else {action='create';data=(await client.query('insert into analytics.amu_movement(source_key,movement_date,movement_type,product_id,package_id,application_item_id,payload,calculation,created_by) values($1,$2,$3,$4,$5,$6,$7,$8,$9) returning *',values)).rows[0];}
  }
  await client.query('insert into audit.event(actor_user_id,action_code,resource_type,resource_id,before_data,after_data) values($1,$2,$3,$4,$5,$6)',[principal.userId,'amu.'+action,'amu_movement',data.id,before?JSON.stringify(before):null,JSON.stringify(data)]);
  await client.query('commit');return reply(data,before?200:201);
 }catch(e){await client.query('rollback');if(e.code==='23505')fail('DUPLICATE_MOVEMENT','This document / line / movement is already recorded; edit the existing row instead',409);throw e}finally{client.release()}
}
