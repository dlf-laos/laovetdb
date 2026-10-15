/** Provider-neutral extraction boundary. No network calls or official-record writes. */
export const documentTypes = ['APPLICATION','GMP','COA','MSDS','REGISTRATION_CERTIFICATE','LABEL','PACKAGE_INSERT','MANUFACTURING','COMPOSITION','OTHER'] as const;
export const intakeFields = ['productName','genericName','dosageForm','activeIngredients','strength','packSize','manufacturerName','manufacturingSite','manufacturingCountry','applicantName','importerName','targetSpecies','indications','dosageAdministration','withdrawalPeriod','storageConditions','shelfLife','originRegistrationNumber','originRegistrationIssueDate','originRegistrationExpiryDate','gmpNumber','gmpIssuer','gmpExpiryDate'] as const;
type FieldKey = typeof intakeFields[number];
type Source = {documentId:string;page:number|null;location:string|null;quote:string};
type Field = {key:FieldKey;status:'FOUND'|'NOT_FOUND'|'CONFLICT';value:string|null;confidence:number|null;sources:Source[]};
export type IntakeExtraction = {schemaVersion:'lvsp.document-intake.v1';fields:Field[]};
export interface DocumentExtractionProvider {
  /** Implement server-side only, using authorized document content, never client keys. */
  extract(input:{caseId:string;documentIds:readonly string[]}):Promise<unknown>;
}
function invalid(message:string):never {throw Object.assign(new Error(message),{code:'INVALID_EXTRACTION',statusCode:422});}
function object(value:unknown):Record<string,unknown> {
  if(!value||typeof value!=='object'||Array.isArray(value))invalid('Expected an object');
  return value as Record<string,unknown>;
}
function keys(value:Record<string,unknown>,expected:string[]) {
  if(Object.keys(value).length!==expected.length||expected.some(key=>!Object.hasOwn(value,key)))invalid('Unexpected or missing extraction properties');
}
function boundedString(value:unknown,max:number):string {
  if(typeof value!=='string'||!value.trim()||value.length>max)invalid('Invalid text value');
  return value;
}
/** Caller must obtain allowed document IDs from an authorized, case-scoped DB lookup. */
export function validateIntakeExtraction(input:unknown,allowedDocumentIds:ReadonlySet<string>):IntakeExtraction {
  const root=object(input);keys(root,['schemaVersion','fields']);
  if(root.schemaVersion!=='lvsp.document-intake.v1'||!Array.isArray(root.fields)||root.fields.length>intakeFields.length)invalid('Unsupported extraction schema');
  const seen=new Set<string>();
  const fields:Field[]=root.fields.map(raw=>{
    const field=object(raw);keys(field,['key','status','value','confidence','sources']);
    if(!intakeFields.includes(field.key as FieldKey)||seen.has(String(field.key)))invalid('Unknown or duplicate field');
    seen.add(String(field.key));
    if(!['FOUND','NOT_FOUND','CONFLICT'].includes(String(field.status))||!Array.isArray(field.sources)||field.sources.length>20)invalid('Invalid field status or sources');
    const sources:Source[]=field.sources.map(rawSource=>{
      const source=object(rawSource);keys(source,['documentId','page','location','quote']);
      if(typeof source.documentId!=='string'||!allowedDocumentIds.has(source.documentId))invalid('Source is outside the authorized dossier');
      if(source.page!==null&&(!Number.isSafeInteger(source.page)||Number(source.page)<1))invalid('Invalid source page');
      if(source.location!==null)boundedString(source.location,500);
      if(source.page===null&&source.location===null)invalid('Source page or location is required');
      return {documentId:source.documentId,page:source.page as number|null,location:source.location as string|null,quote:boundedString(source.quote,4000)};
    });
    if(field.status==='NOT_FOUND'){
      if(field.value!==null||field.confidence!==null||sources.length)invalid('Missing information must not contain guessed values');
    }else{
      if(typeof field.confidence!=='number'||!Number.isFinite(field.confidence)||field.confidence<0||field.confidence>1)invalid('Invalid confidence');
      boundedString(field.value,10000);
      if(sources.length<(field.status==='CONFLICT'?2:1))invalid('Evidence is required');
    }
    return {key:field.key as FieldKey,status:field.status as Field['status'],value:field.value as string|null,confidence:field.confidence as number|null,sources};
  });
  // Omitted fields stay explicitly missing, never inferred from another field.
  for(const key of intakeFields)if(!seen.has(key))fields.push({key,status:'NOT_FOUND',value:null,confidence:null,sources:[]});
  return {schemaVersion:'lvsp.document-intake.v1',fields};
}
export function prepareIntakeReview(extraction:IntakeExtraction) {
  return {officialWriteAllowed:false as const,fields:extraction.fields.map(field=>({...field,requiresReview:true as const,flag:field.status==='NOT_FOUND'?'NOT_FOUND':field.status==='CONFLICT'?'CONFLICT':(field.confidence??0)<0.8?'LOW_CONFIDENCE':'REVIEW_REQUIRED'}))};
}
