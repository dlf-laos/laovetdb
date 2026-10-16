// Calculations are quantities supplied/imported, not proof of administration to animals.
export const amuClasses=['AMINOGLYC','AMPHENIC','ARSENIC','CEPH12','CEPH34','CEPHALL','FQ','GLYCOPEP','GLYCOPHOS','LINCOS','MACRO','NITROFUR','ORTHOSOM','QUINOTHER','PENIC','PLEURO','POLYPEP','QUINOXAL','STREPTOG','SULFA','TETRA','OTHERS'];
export const modes=['mg/ml','mg/g','mg/unit','% w/v','% w/w','IU/ml','IU/g','IU/unit','kg active'];
const error=(message:string)=>{throw Object.assign(new Error(message),{statusCode:400,code:'INVALID_AMU_DATA'})};
const text=(v:any,max=300)=>typeof v==='string'?v.trim().slice(0,max):'';
const number=(v:any)=>!(typeof v==='number'||(typeof v==='string'&&/^\d+(?:\.\d+)?$/.test(v.trim())))?null:Number.isFinite(Number(v))&&Number(v)>=0?Number(v):null;
export function calculateAmu(input:any){
 if(!input||typeof input!=='object'||Array.isArray(input))error('AMU record required');
 const date=text(input.arrivalDate,10);
 if(!/^\d{4}-\d{2}-\d{2}$/.test(date)||!Number.isFinite(Date.parse(date+'T00:00:00Z'))||new Date(date+'T00:00:00Z').toISOString().slice(0,10)!==date)error('Actual movement date required');
 if(!['IMPORT','EXPORT','RE_EXPORT','TRANSIT'].includes(input.movementType))error('Movement type required');
 if(!['UNREGISTERED','NOT_LINKED','REGISTERED'].includes(input.registrationBasis))error('Registration basis required');
 if(input.registrationBasis==='REGISTERED'&&(!input.productId||!input.packageId))error('Registered items require an exact product and presentation');
 const packCount=number(input.packCount),packSize=number(input.packSize);
 const packUnit=['ml','g','unit'].includes(input.packUnit)?input.packUnit:'';
 const components=Array.isArray(input.components)?input.components:[];
 if(components.length>30)error('Maximum 30 active ingredients');
 const issues:string[]=[];
 const needsPacks=components.some((c:any)=>c.excluded!==true&&c.mode!=='kg active');
 if(needsPacks&&packCount===null)issues.push('ACTUAL_PACK_COUNT_MISSING');
 if(needsPacks&&(packSize===null||packSize===0||!packUnit))issues.push('EXACT_PACK_SIZE_MISSING');
 if(!components.length)issues.push('COMPOSITION_MISSING');
 const ingredientNames=new Set<string>();
 const rows=components.map((raw:any)=>{
  const name=text(raw.name),classCode=text(raw.classCode,30),mode=text(raw.mode,30),strength=number(raw.strength),iuPerMg=number(raw.iuPerMg);
  const evidence=text(raw.evidence,2000),conversionEvidence=text(raw.conversionEvidence,2000);
  const basis=raw.massBasis==='ACTIVE_MOIETY'?'ACTIVE_MOIETY':raw.massBasis==='LABEL_COMPOUND'?'LABEL_COMPOUND':'';
  const excluded=raw.excluded===true,exclusionReason=text(raw.exclusionReason,1000);
  const factor=raw.activeEntityFactor===undefined||raw.activeEntityFactor===''?1:number(raw.activeEntityFactor);
  const flags:string[]=[];let kg:number|null=null;
  if(!name)flags.push('INGREDIENT_NAME_MISSING');
  const ingredientKey=name.normalize('NFKC').toLowerCase();if(ingredientNames.has(ingredientKey))flags.push('DUPLICATE_INGREDIENT');ingredientNames.add(ingredientKey);
  if(!evidence)flags.push('LABEL_OR_CERTIFICATE_EVIDENCE_MISSING');
  if(excluded){if(!exclusionReason)flags.push('EXCLUSION_REASON_REQUIRED');}
  else {
   if(!amuClasses.includes(classCode))flags.push('CLASS_NOT_MAPPED');
   if(!basis)flags.push('MASS_BASIS_REQUIRED');
   if(strength===null||!modes.includes(mode))flags.push('STRENGTH_OR_UNIT_MISSING');
   if(factor===null||factor<=0||factor>1)flags.push('INVALID_ACTIVE_ENTITY_FACTOR');
   if(factor!==1&&!conversionEvidence)flags.push('CONVERSION_EVIDENCE_REQUIRED');
   const expected=mode.includes('/ml')||mode==='% w/v'?'ml':mode.includes('/g')||mode==='% w/w'?'g':'unit';
   if(mode!=='kg active'&&packUnit!==expected)flags.push('INCOMPATIBLE_UNITS');
   if(mode.startsWith('IU')&&(!iuPerMg||!conversionEvidence))flags.push('SUBSTANCE_SPECIFIC_IU_FACTOR_REQUIRED');
   if(mode.startsWith('%')&&strength!==null&&strength>100)flags.push('PERCENT_EXCEEDS_100');
   if(!flags.length&&(mode==='kg active'||(packCount!==null&&packSize!==null&&packSize>0&&packUnit))&&strength!==null&&factor!==null){
    const amount=(packCount||0)*(packSize||0);
    kg=mode==='kg active'?strength:mode.startsWith('%')?amount*strength/100/1000:mode.startsWith('IU')?amount*strength/(iuPerMg!)/1e6:amount*strength/1e6;
    kg*=factor;
    if(!Number.isFinite(kg)||kg>1e9){kg=null;flags.push('QUANTITY_OUT_OF_RANGE');}
   }
  }
  issues.push(...flags.map(x=>`${name||'?'}: ${x}`));
  return {name,classCode,mode,strength,iuPerMg,evidence,conversionEvidence,massBasis:basis,activeEntityFactor:factor,excluded,exclusionReason,kg,flags};
 });
 const sourceRef=text(input.sourceRef),lineRef=text(input.lineRef,100),productName=text(input.productName);
 if(!sourceRef||!lineRef||!productName)error('Source document, source line and product name required');
 const data={sourceRef,lineRef,productName,arrivalDate:date,movementType:input.movementType,registrationBasis:input.registrationBasis,productId:text(input.productId,36)||null,packageId:text(input.packageId,36)||null,applicationItemId:text(input.applicationItemId,36)||null,companyName:text(input.companyName),packCount,packSize,packUnit,evidence:text(input.evidence,2000),route:text(input.route,80)||'NOT_SPECIFIED',animalGroup:text(input.animalGroup,80)||'NOT_SPECIFIED',useType:text(input.useType,80)||'NOT_SPECIFIED',components:rows};
 if(!data.evidence)issues.push('ACTUAL_CLEARANCE_EVIDENCE_MISSING');
 const totalKg=issues.length?null:rows.reduce((n,x)=>n+(x.kg||0),0);
 return {data,issues,totalKg,methodVersion:'LVSP-AMU-1',quantityMeaning:'ACTUAL_BORDER_MOVEMENT'};
}
export function summarizeAmu(records:any[]){
 const byClass:Record<string,number>={},byRegistration:Record<string,number>={};let importKg=0,reExportKg=0,exportKg=0,pending=0,excluded=0,transit=0,reviewed=0;
 for(const record of records){
  if(record.status==='VOID')continue;
  const c=calculateAmu(record.payload);
  if(record.status!=='REVIEWED'||c.issues.length){pending++;continue;}
  reviewed++;
  if(c.data.movementType==='TRANSIT'){transit++;continue;}
  for(const row of c.data.components){
   if(row.excluded){excluded++;continue;}
   const kg=row.kg!;
   if(c.data.movementType==='IMPORT'){importKg+=kg;byClass[row.classCode]=(byClass[row.classCode]||0)+kg;byRegistration[c.data.registrationBasis]=(byRegistration[c.data.registrationBasis]||0)+kg;}
   else if(c.data.movementType==='RE_EXPORT')reExportKg+=kg;
   else exportKg+=kg;
  }
 }
 return {importKg,reExportKg,exportKg,netImportKg:importKg-reExportKg,byClass,byRegistration,pending,excluded,transit,reviewed,recordCount:records.length,warning:reExportKg>importKg?'RE_EXPORT_EXCEEDS_IMPORTS':null,methodVersion:'LVSP-AMU-1',reportingBasis:'Reviewed actual border movements; imports minus re-exports. Sales and farm-use data are not added. Export origin and stocks require separate reconciliation.'};
}
