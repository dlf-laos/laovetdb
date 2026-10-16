// Policy primitives for wiring into the existing trade/workflow transactions.
// Inputs must come from authenticated, server-verified records, never client assertions.
// These functions do not approve a case, sign a document or send an external message.
const failure=(message:string)=>{throw Object.assign(new Error(message),{code:'INVALID_TRADE_POLICY_INPUT',statusCode:400})};
const SCALE=1000000n;
function qty(value:any):bigint{
 const s=String(value??'');if(!/^\d{1,12}(?:\.\d{1,6})?$/.test(s))failure('Quantity must be a non-negative decimal with at most six decimal places');
 const [whole,fraction='']=s.split('.');return BigInt(whole)*SCALE+BigInt(fraction.padEnd(6,'0'));
}
function decimal(value:bigint){const whole=value/SCALE,part=(value%SCALE).toString().padStart(6,'0').replace(/0+$/,'');return whole.toString()+(part?'.'+part:'');}
function date(value:any){if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value)||!Number.isFinite(Date.parse(value))||new Date(value+'T00:00:00Z').toISOString().slice(0,10)!==value)failure('Valid business date required');return value;}
function inPeriod(record:any,on:string){return (!record.validFrom||date(record.validFrom)<=on)&&(!record.validTo||date(record.validTo)>=on);}
function scopedDecision(d:any,c:any,on:string,kind:string){return d?.status==='APPROVED'&&d.authorityVerified===true&&d.kind===kind&&d.companyId===c.companyId&&d.serviceCode===c.serviceCode&&d.caseId===c.caseId&&d.policyVersion===c.policy.version&&typeof d.id==='string'&&d.id.length>0&&typeof d.reason==='string'&&d.reason.trim().length>0&&typeof d.authorityReference==='string'&&d.authorityReference.trim().length>0&&inPeriod(d,on);}
export function evaluateTradeApproval(c:any){
 const on=date(c.businessDate),blocked:string[]=[],exceptionsUsed:string[]=[];
 if(!c.companyId||!c.serviceCode||!c.caseId)failure('Company, service and case scope required');
 if(c.policy?.status!=='APPROVED'||!c.policy.version||typeof c.policy.annualPlanRequired!=='boolean'||!Array.isArray(c.policy.requirements))return {canApprove:false,blocked:['SERVICE_POLICY_NOT_APPROVED'],exceptionsUsed};
 for(const requirement of c.policy.requirements){
  if(!requirement.required)continue;
  const versions=(c.documents||[]).filter((d:any)=>d.code===requirement.code&&d.companyId===c.companyId&&d.status==='APPROVED'&&(requirement.scope!=='CASE'||d.caseId===c.caseId));
  const valid=versions.some((d:any)=>inPeriod(d,on)&&(!requirement.expiryRequired||!!d.validTo));
  if(valid)continue;
  const expired=versions.some((d:any)=>d.validTo&&date(d.validTo)<on);
  const exception=expired&&requirement.expiryWaivable===true&&(c.exceptions||[]).find((d:any)=>d.requirementCode===requirement.code&&scopedDecision(d,c,on,'DOCUMENT_EXPIRY'));
  if(exception)exceptionsUsed.push(exception.id);else blocked.push((expired?'DOCUMENT_EXPIRED:':'DOCUMENT_MISSING_OR_UNVERIFIED:')+requirement.code);
 }
 const requested=qty(c.requestedQuantity);if(requested===0n)blocked.push('POSITIVE_REQUESTED_QUANTITY_REQUIRED');
 let available:bigint|null=null,excess=0n;
 if(c.policy.annualPlanRequired){
  const p=c.plan;
  if(!p||!p.id||p.status!=='APPROVED'||p.companyId!==c.companyId||p.serviceCode!==c.serviceCode||!inPeriod(p,on))blocked.push('APPROVED_PLAN_REQUIRED');
  else if(!p.unitCode||p.unitCode!==c.unitCode||!p.itemKey||p.itemKey!==c.itemKey)blocked.push('PLAN_ITEM_OR_UNIT_MISMATCH');
  else{
   const cap=qty(p.approvedQuantity),used=qty(p.actualClearedQuantity),reserved=qty(p.reservedQuantity);
   if(used+reserved>cap)blocked.push('PLAN_BALANCE_REQUIRES_RECONCILIATION');
   available=cap-used-reserved;if(available<0n)available=0n;
   excess=requested>available?requested-available:0n;
   if(excess>0n){
    const exception=c.policy.overPlanWaivable===true&&(c.exceptions||[]).find((d:any)=>scopedDecision(d,c,on,'OVER_PLAN')&&d.planId===p.id&&d.itemKey===c.itemKey&&d.unitCode===c.unitCode&&qty(d.additionalQuantity)>=excess);
    if(exception)exceptionsUsed.push(exception.id);else blocked.push('OVER_PLAN_APPROVAL_REQUIRED');
   }
  }
 }
 return {canApprove:blocked.length===0,blocked,exceptionsUsed,availableToReserve:available===null?null:decimal(available),excessApprovalRequired:decimal(excess),reserveQuantity:blocked.length?null:decimal(requested),policyVersion:c.policy.version};
}
export function settleTradeClearance(c:any){
 const on=date(c.businessDate);
 if(typeof c.idempotencyKey!=='string'||!c.idempotencyKey.trim()||typeof c.payloadHash!=='string'||!/^[0-9a-f]{64}$/.test(c.payloadHash))failure('Idempotency key and canonical payload hash required');
 if(c.priorEvent){if(c.priorEvent.idempotencyKey===c.idempotencyKey&&c.priorEvent.payloadHash===c.payloadHash)return {replay:true,mutate:false};failure('Duplicate event key has a different payload');}
 if(c.permit?.status!=='ISSUED'||c.permit.published!==true||!inPeriod(c.permit,on)||!c.permit.validTo)failure('An issued, published and valid permit is required');
 if(c.companyId!==c.permit.companyId||c.unitCode!==c.permit.unitCode||c.itemKey!==c.permit.itemKey)failure('Permit company, item and unit must match');
 if(c.plan?.id!==c.permit.planId||c.plan?.companyId!==c.companyId||c.plan?.unitCode!==c.unitCode||c.plan?.itemKey!==c.itemKey)failure('Plan identity and quantity scope must match the permit');
 const actual=qty(c.actualQuantity),remaining=qty(c.permit.remainingQuantity),used=qty(c.plan.actualClearedQuantity),reserved=qty(c.plan.reservedQuantity),cap=qty(c.plan.approvedQuantity);
 if(used+reserved>cap)failure('Plan balance requires reconciliation before clearance');
 if(actual===0n||actual>remaining||actual>reserved)failure('Actual clearance exceeds permit or reserved quantity');
 return {replay:false,mutate:true,actualClearedQuantity:decimal(used+actual),reservedQuantity:decimal(reserved-actual),permitRemainingQuantity:decimal(remaining-actual),movementQuantity:decimal(actual)};
}
export function requireExternalConnectorApproval(config:any){
 if(config?.enabled!==true||config.configurationStatus!=='APPROVED'||!config.partnerSpecificationVersion||!config.mappingVersion||!config.authenticationVerified||!config.partnerAcceptanceTestPassed||config.endpointAllowlisted!==true||config.dataSharingApproved!==true)failure('Single Window connector remains disabled until specification, mapping, authentication and partner acceptance are approved');
 const endpoint=new URL(config.baseUrl);if(endpoint.protocol!=='https:'||endpoint.username||endpoint.password)failure('Approved HTTPS endpoint required');
 return {canPrepare:true,canTransmit:false,reason:'Transport adapter and partner authorization must be implemented separately'};
}
