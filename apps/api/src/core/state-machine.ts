// Regulatory command guard. It prevents arbitrary status mutation through command endpoints.
// Exact legal workflows remain versioned configuration; these are safe technical lifecycle guards.
// @ts-nocheck
const ANY='*';
const RULES:any={
 applications:{submit:['DRAFT','RETURNED_FOR_CORRECTION'],withdraw:['SUBMITTED','RECEIVED','TECHNICAL_REVIEW'], 'request-information':[ANY], 'respond-information':[ANY]},
 registrations:{renew:['ACTIVE','VALID'],vary:['ACTIVE','VALID'],suspend:['ACTIVE','VALID'],revoke:['ACTIVE','VALID','SUSPENDED']},
 licenses:{renew:['ACTIVE','VALID'],amend:['ACTIVE','VALID'],suspend:['ACTIVE','VALID'],restore:['SUSPENDED'],revoke:['ACTIVE','VALID','SUSPENDED']},
 certificates:{revoke:['VALID','ISSUED','ACTIVE']},
 laboratory_results:{validate:['DRAFT'],approve:['VALIDATED'],amend:['APPROVED']},
 movements:{authorize:['DRAFT','SUBMITTED','REVIEW'],depart:['AUTHORIZED','PERMIT_ISSUED'],arrive:['IN_TRANSIT'],complete:['ARRIVED']},
 disease_cases:{confirm:['OPEN','SUSPECTED','UNDER_INVESTIGATION','DRAFT']},
 outbreaks:{close:['ACTIVE','OPEN','DRAFT']},
 trade_shipments:{declare:['DRAFT','PERMIT_ISSUED','DECLARED'], 'risk-assess':['DECLARED','DRAFT'], inspection:[ANY],quarantine:[ANY],clearance:[ANY]},
 capa:{submit:['REQUESTED','DRAFT','OPEN'],verify:['SUBMITTED','UNDER_VERIFICATION','DRAFT']},
 inspections:{complete:['IN_PROGRESS','OPEN','PLANNED','DRAFT']}
};
const ROLE_RULES:any={
 'laboratory_results.validate':['LAB_VALIDATOR','LAB_APPROVER','SYSTEM_ADMIN'],
 'laboratory_results.approve':['LAB_APPROVER','SYSTEM_ADMIN'],
 'licenses.revoke':['APPROVING_AUTHORITY','SYSTEM_ADMIN'],
 'certificates.revoke':['CERTIFICATE_SIGNATORY','APPROVING_AUTHORITY','SYSTEM_ADMIN'],
 'disease_cases.confirm':['EPIDEMIOLOGIST','APPROVING_AUTHORITY','SYSTEM_ADMIN'],
 'trade_shipments.clearance':['QUARANTINE_OFFICER','BORDER_OFFICER','APPROVING_AUTHORITY','SYSTEM_ADMIN']
};
export function assertCommandAllowed(resource:string,action:string,target:any,principal:any){
 const roles=ROLE_RULES[`${resource}.${action}`];
 if(roles && !principal.roles?.some((r:string)=>roles.includes(r))) throw Object.assign(new Error('This action requires a competent role'),{statusCode:403,code:'ACTION_FORBIDDEN'});
 const allowed=RULES[resource]?.[action];
 if(!allowed || allowed.includes(ANY)) return;
 const current=String(target.status||target.lifecycleStatus||'DRAFT').toUpperCase();
 if(!allowed.includes(current)) throw Object.assign(new Error(`Action ${action} is not allowed from status ${current}`),{statusCode:409,code:'INVALID_STATE_TRANSITION'});
}
