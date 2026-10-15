// Local development numbering only. Production uses system.number_sequence in PostgreSQL.
// All generated local identifiers are clearly prefixed DEV to avoid being mistaken for official regulatory numbers.
// @ts-nocheck
const NUMBER_FIELDS:any={
 facilities:['facilityNo','FAC'], applications:['caseNo','APP'], cases:['caseNo','CASE'], decisions:['decisionNo','DEC'],
 registrations:['registrationNo','REG'], licenses:['licenseNo','LIC'], certificates:['certificateNo','CERT'],
 inspections:['inspectionNo','IN'], laboratory_samples:['sampleNo','SMP'], laboratory_test_requests:['requestNo','LABREQ'],
 movements:['movementNo','MOV'], disease_cases:['caseNo','AH'], outbreaks:['outbreakNo','OUT'], vaccination_campaigns:['campaignNo','VAC'],
 trade_operators:['operatorNo','TRD'], trade_permits:['permitNo','PERMIT'], trade_shipments:['shipmentNo','SHP'],
 aquaculture_stock_batches:['batchNo','AQ'], animals:['animalNo','AN'], product_batches:['batchNo','PBAT']
};
export async function applyDevelopmentNumber(store:any,resource:string,input:any){
 const def=NUMBER_FIELDS[resource]; if(!def)return input; const [field,prefix]=def;if(input[field])return input;
 const year=new Date().getUTCFullYear(); const rows=await store.list(resource); const n=rows.length+1;
 return {...input,[field]:`DEV-${prefix}-${year}-${String(n).padStart(6,'0')}`};
}
