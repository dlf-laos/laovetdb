// Spreadsheet bulk import for annual plans and import applications.
// Supports CSV and standard .xlsx using only Node + the system unzip command (present on macOS/Linux).
// @ts-nocheck
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';

const xmlDecode=(s:string)=>String(s||'').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&').replace(/&quot;/g,'"').replace(/&#39;/g,"'");
function csvRows(text:string){const out:any[]=[];let row:any[]=[],cell='',q=false;for(let i=0;i<text.length;i++){const c=text[i];if(q){if(c==='"'&&text[i+1]==='"'){cell+='"';i++}else if(c==='"')q=false;else cell+=c}else{if(c==='"')q=true;else if(c===','){row.push(cell);cell=''}else if(c==='\n'){row.push(cell.replace(/\r$/,''));out.push(row);row=[];cell=''}else cell+=c}}if(cell||row.length){row.push(cell);out.push(row)}return out}
function colIndex(ref:string){const m=String(ref).match(/^([A-Z]+)/i);if(!m)return 0;let n=0;for(const ch of m[1].toUpperCase())n=n*26+(ch.charCodeAt(0)-64);return n-1}
function parseXlsx(buf:Buffer){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'lvsp-xlsx-'));const f=path.join(dir,'upload.xlsx');fs.writeFileSync(f,buf);try{let shared:string[]=[];try{const x=execFileSync('unzip',['-p',f,'xl/sharedStrings.xml'],{encoding:'utf8'});shared=[...x.matchAll(/<si[^>]*>([\s\S]*?)<\/si>/g)].map(m=>xmlDecode([...m[1].matchAll(/<(?:x:)?t[^>]*>([\s\S]*?)<\/(?:x:)?t>/g)].map(z=>z[1]).join('')))}catch{}
 const sheet=execFileSync('unzip',['-p',f,'xl/worksheets/sheet1.xml'],{encoding:'utf8'});const matrix:any[][]=[];for(const rm of sheet.matchAll(/<(?:x:)?row[^>]*>([\s\S]*?)<\/(?:x:)?row>/g)){const arr:any[]=[];for(const cm of rm[1].matchAll(/<(?:x:)?c\b([^>]*)>([\s\S]*?)<\/(?:x:)?c>/g)){const attrs=cm[1],body=cm[2],ref=(attrs.match(/\br="([^"]+)"/)||[])[1]||'',t=(attrs.match(/\bt="([^"]+)"/)||[])[1]||'',v=(body.match(/<(?:x:)?v>([\s\S]*?)<\/(?:x:)?v>/)||[])[1]??'',inline=[...body.matchAll(/<(?:x:)?t[^>]*>([\s\S]*?)<\/(?:x:)?t>/g)].map(z=>z[1]).join('');let val:any=t==='s'?shared[Number(v)]??'':t==='inlineStr'?xmlDecode(inline):xmlDecode(v);arr[colIndex(ref)]=val}matrix.push(arr)}return matrix}finally{fs.rmSync(dir,{recursive:true,force:true})}}
function matrixToObjects(matrix:any[][]){const clean=matrix.filter(r=>r.some(v=>String(v??'').trim()!==''));if(!clean.length)return[];let hi=clean.findIndex(r=>r.some(v=>['ປະເພດ','ໝວດໝູ່','Item Type','Type','ເລກທີໃບອະນຸມັດ','ປີແຜນ'].includes(String(v??'').trim())));if(hi<0)hi=0;const heads=clean[hi].map(v=>String(v??'').trim());return clean.slice(hi+1).map(r=>Object.fromEntries(heads.map((h,i)=>[h,r[i]??'']))).filter(o=>Object.values(o).some(v=>String(v??'').trim()!==''))}
const pick=(r:any,names:string[])=>{for(const n of names){if(r[n]!==undefined&&r[n]!==null&&String(r[n]).trim()!=='')return r[n]}return ''};
const num=(v:any)=>{const n=Number(String(v??'').replace(/,/g,''));return Number.isFinite(n)?n:0};
const kind=(v:any)=>{const s=String(v||'').trim().toLowerCase();if(/vaccine|ວັກ/.test(s))return'VACCINE';if(/biolog|ຊີວະ/.test(s))return'BIOLOGICAL';if(/device|equipment|ອຸປະກອນ/.test(s))return'VETERINARY_DEVICE';if(/diagnostic|kit|ຊຸດກວດ/.test(s))return'DIAGNOSTIC_KIT';if(/medicine|drug|ຢາ/.test(s))return'MEDICINE';return'OTHER_VETERINARY_PRODUCT'};
export function parseSpreadsheet(base64:string,filename='upload.xlsx'){
 const buf=Buffer.from(base64,'base64');const ext=path.extname(filename).toLowerCase();const matrix=(ext==='.csv'||ext==='.txt')?csvRows(buf.toString('utf8').replace(/^\uFEFF/,'')):parseXlsx(buf);const raw=matrixToObjects(matrix);
 const rows=raw.map((r:any,i:number)=>{
  const sourceCategory=String(pick(r,['ໝວດໝູ່','ປະເພດ','Category','Item Type','Type','type'])).trim();
  const itemName=String(pick(r,['ຊື່ສິນຄ້າຕົວຈິງນຳເຂົ້າ (ພິມເອງ✏️)','ຊື່ລາຍການ ຫຼື ໝວດແຜນ','ຊື່ (ລາວ)','ລາຍການ','Item Name','Description of goods','Name','name'])).trim();
  const planReferenceName=String(pick(r,['ຊື່ອ້າງອີງຕາມແຜນ (ກົດເລືອກ👇)','Plan Reference','Plan Item','Reference Plan Item'])).trim();
  const approvedQuantitySource=Object.prototype.hasOwnProperty.call(r,'ຈຳນວນທີ່ອະນຸມັດ')&&String(r['ຈຳນວນທີ່ອະນຸມັດ']??'').trim()!=='';
  const quantity=num(pick(r,['ຈຳນວນທີ່ອະນຸມັດ','ຈຳນວນແຜນ','ຈຳນວນ','Quantity','Qty','qty']));
  const quantityMeaning=approvedQuantitySource?'APPROVED':'REQUESTED_OR_PLAN';
  const unitCode=String(pick(r,['ຫົວໜ່ວຍ (ເລືອກ)','ໜ່ວຍ','Unit','unit'])).trim();
  const value=num(pick(r,['ມູນຄ່າແຜນ ($)','ມູນຄ່າ ($)','ມູນຄ່າ USD','ມູນຄ່າ','Amount','Value','value']));
  const summary=/ແຜນລວມ|ລວມໝວດ|summary|category plan/i.test(itemName)||['ລາຍການ','item','items'].includes(unitCode.toLowerCase());
  return {rowNo:i+2,itemType:kind(sourceCategory),sourceCategory,itemName,itemNameEn:String(pick(r,['ຊື່ (English)','English Name','Name EN'])).trim(),planReferenceName,registrationNo:String(pick(r,['ເລກທະບຽນ','Registration No','Registration Number','regNo'])).trim(),packageDescription:String(pick(r,['ຂະໜາດບັນຈຸ','Packaging','Pack Size','Package','pack'])).trim(),quantity,unitCode,value,currencyCode:String(pick(r,['Currency','ສະກຸນເງິນ'])).trim()||'USD',batchLotNo:String(pick(r,['Batch','Lot','Batch/Lot'])).trim(),manufactureDate:String(pick(r,['ວັນຜະລິດ (ປປປປ-ດດ-ວວ)','Manufacture Date','MFG Date'])).trim(),expiryDate:String(pick(r,['ວັນໝົດອາຍຸ (ປປປປ-ດດ-ວວ)','Expiry Date','EXP Date'])).trim(),manufacturerName:String(pick(r,['ຜູ້ຜະລິດ','Manufacturer'])).trim(),manufacturerCountry:String(pick(r,['ປະເທດຜະລິດ','Country','Manufacturer Country'])).trim(),permitNo:String(pick(r,['ເລກທີໃບອະນຸມັດ','Permit No.','Permit No','Approval No.'])).trim(),approvalDate:String(pick(r,['ວັນທີອະນຸມັດ','Approval Date','Permit Date'])).trim(),companyName:String(pick(r,['ຊື່ບໍລິສັດນຳເຂົ້າ (ເລືອກ)','ຊື່ບໍລິສັດນຳເຂົ້າ','Company','Importer'])).trim(),originCountry:String(pick(r,['ປະເທດຕົ້ນທາງ (ເລືອກ)','Origin Country','Country of Origin'])).trim(),sourceName:String(pick(r,['ແຫຼ່ງທີ່ມາ (ບໍລິສັດ/ບຸກຄົນ)','Source','Supplier'])).trim(),checkpoint:String(pick(r,['ດ່ານນຳເຂົ້າ (ເລືອກ)','Checkpoint','Entry Checkpoint'])).trim(),planYear:num(pick(r,['ປີແຜນ','Plan Year','Year'])),quantityMeaning,lineMode:summary?'SUMMARY_GROUP':'ITEM',trackingBasis:summary?'COUNT_VALUE':(value>0?'QUANTITY_VALUE':'QUANTITY'),plannedItemCount:summary?Math.max(0,Math.trunc(quantity)):null,plannedValueUsd:value||null,raw:r};
 });return {filename,sheetName:'Sheet1',rows};
}
const norm=(v:any)=>String(v??'').trim().toLowerCase().replace(/\s+/g,' ');
export async function enrichRows(store:any,rows:any[],target:'plan'|'application',context:any={}){
 const regs=await store.list('drug_registrations');const devs=await store.list('veterinary_devices');
 const packages=await store.list('product_packages');const packageVersions=await store.list('package_versions');
 const latestPackVersion=new Map<string,any>();
 for(const v of packageVersions){const k=String(v.packageId||'');const cur=latestPackVersion.get(k);if(!cur||Number(v.versionNo||0)>Number(cur.versionNo||0))latestPackVersion.set(k,v)}
 let planItems:any[]=[];
 if(target==='application'&&context?.planId){
   try{planItems=(await store.list('import_plan_items')).filter((x:any)=>String(x.planId||'')===String(context.planId));}catch{}
 }
 const results=[];for(const r of rows){const errors:string[]=[];const warnings:string[]=[];if(!r.itemName)errors.push('Missing item name');if(r.quantity<0)errors.push('Quantity must be >= 0');let productId=null,deviceId=null,packageId=null,eligibilityStatus='PENDING',eligibilityMessage='';if(['MEDICINE','VACCINE','BIOLOGICAL'].includes(r.itemType)){const reg=regs.find((x:any)=>r.registrationNo&&norm(x.registrationNo)===norm(r.registrationNo))||regs.find((x:any)=>[x.tradeName,x.genericName].some((z:any)=>z&&norm(z)===norm(r.itemName)));if(reg){productId=reg.productId;const exp=reg.expiryDate?new Date(reg.expiryDate):null;const active=['ACTIVE','VALID','APPROVED'].includes(String(reg.registrationStatus||'').toUpperCase());const expired=!!(exp&&exp.getTime()<Date.now());eligibilityStatus=active&&!expired?'ELIGIBLE':'BLOCKED';eligibilityMessage=active&&!expired?'Registration valid':'Registration inactive or expired';r.registrationNo=r.registrationNo||reg.registrationNo||'';
   const pp=packages.filter((x:any)=>String(x.productId||'')===String(productId));
   if(r.packageDescription&&pp.length){const want=norm(r.packageDescription);const hit=pp.find((x:any)=>{const v=latestPackVersion.get(String(x.id));return [x.packageCode,x.subCode,v?.packDescription,v?.strengthText].some(z=>z&&norm(z)===want)||(v?.packDescription&&norm(v.packDescription).includes(want))});if(hit)packageId=hit.id;else{warnings.push('Registered product matched, but packaging/presentation did not match registry');if(eligibilityStatus==='ELIGIBLE')eligibilityStatus='REVIEW_REQUIRED'}}
  }else{eligibilityStatus='REVIEW_REQUIRED';eligibilityMessage='Not matched to drug registry — manual/unregistered item retained for review';warnings.push(eligibilityMessage)}}else if(r.itemType==='VETERINARY_DEVICE'){const d=devs.find((x:any)=>r.registrationNo&&norm(x.registrationNo)===norm(r.registrationNo))||devs.find((x:any)=>[x.deviceName,x.brand,x.model].some((z:any)=>z&&norm(z)===norm(r.itemName)));if(d){deviceId=d.id;const active=['ACTIVE','VALID','APPROVED','AUTHORIZED'].includes(String(d.authorizationStatus||'').toUpperCase());eligibilityStatus=active?'ELIGIBLE':'REVIEW_REQUIRED';eligibilityMessage=active?'Device authorization valid':'Device requires regulatory review'}else{eligibilityStatus='REVIEW_REQUIRED';eligibilityMessage='Device not matched to master registry — retained for review';warnings.push(eligibilityMessage)}}else{eligibilityStatus='REVIEW_REQUIRED';eligibilityMessage='Non-drug/device item retained for regulatory review'}let planItemId=null,planMatchMethod='',planMatchMessage='';
 if(target==='application'&&planItems.length){
   const byRef=r.planReferenceName?planItems.filter((x:any)=>[x.itemName,x.groupName,x.itemCode].some((z:any)=>z&&norm(z)===norm(r.planReferenceName))):[];
   const byReg=r.registrationNo?planItems.filter((x:any)=>x.registrationNo&&norm(x.registrationNo)===norm(r.registrationNo)):[];
   const byProduct=productId?planItems.filter((x:any)=>String(x.productId||'')===String(productId)):[];
   const byDevice=deviceId?planItems.filter((x:any)=>String(x.deviceId||'')===String(deviceId)):[];
   const byName=r.itemName?planItems.filter((x:any)=>x.itemName&&norm(x.itemName)===norm(r.itemName)):[];
   const summary=planItems.filter((x:any)=>String(x.lineMode||'').toUpperCase()==='SUMMARY_GROUP'&&String(x.itemType||'')===String(r.itemType));
   const candidates=byRef.length?byRef:byReg.length?byReg:byProduct.length?byProduct:byDevice.length?byDevice:byName.length?byName:summary.length===1?summary:[];
   if(candidates.length===1){planItemId=candidates[0].id;planMatchMethod=byRef.length?'REFERENCE_NAME':byReg.length?'REGISTRATION_NO':byProduct.length?'PRODUCT':byDevice.length?'DEVICE':byName.length?'ITEM_NAME':'SUMMARY_TYPE';planMatchMessage=`Plan item matched by ${planMatchMethod}`;}
   else if(candidates.length>1){warnings.push('Multiple annual-plan items match this row — select plan item manually');planMatchMessage='Multiple plan matches';}
   else{warnings.push('No annual-plan item matched — item will not reduce Plan vs Actual until linked');planMatchMessage='No plan match';}
 }
 results.push({...r,productId,deviceId,packageId,planItemId,planMatchMethod,planMatchMessage,eligibilityStatus,eligibilityMessage,validationStatus:errors.length?'ERROR':warnings.length?'WARNING':'VALID',errors,warnings})}return results;
}
