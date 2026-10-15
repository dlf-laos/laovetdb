// LVSP request principal + coarse module-level RBAC.
// Database user/role assignments are resolved at login and signed into the short-lived token.
// @ts-nocheck
import {verifyToken} from './auth.js';

export type Principal = {
  userId:string;
  username?:string;
  roles:string[];
  isAuthenticated:boolean;
  mustChangePassword?:boolean;
};

const PUBLIC_EXACT=new Set(['/health','/ready','/auth/login']);
const ADMIN_ROLES=new Set(['SYSTEM_ADMIN','SECURITY_ADMIN']);
const ALL_WRITE_ROLES=new Set([
  'SYSTEM_ADMIN','SECURITY_ADMIN','DATA_STEWARD','REGISTRY_OFFICER','TECHNICAL_REVIEWER',
  'INSPECTOR','SENIOR_INSPECTOR','LAB_ANALYST','LAB_VALIDATOR','LAB_APPROVER','EPIDEMIOLOGIST',
  'QUARANTINE_OFFICER','BORDER_OFFICER','LICENSING_OFFICER','APPROVING_AUTHORITY',
  'CERTIFICATE_SIGNATORY','COMPANY_ADMIN','COMPANY_USER','FARM_OPERATOR','PROVINCIAL_ADMIN',
  'PROVINCIAL_LICENSING_OFFICER','DISTRICT_LICENSING_OFFICER','DISTRICT_INSPECTOR','CHECKPOINT_SUPERVISOR'
]);
const DRUG_WRITE_ROLES=new Set(['SYSTEM_ADMIN','SECURITY_ADMIN','REGISTRY_OFFICER','TECHNICAL_REVIEWER','APPROVING_AUTHORITY']);
const TRADE_WRITE_ROLES=new Set(['SYSTEM_ADMIN','SECURITY_ADMIN','REGISTRY_OFFICER','BORDER_OFFICER','QUARANTINE_OFFICER','CHECKPOINT_SUPERVISOR','TECHNICAL_REVIEWER','APPROVING_AUTHORITY','CERTIFICATE_SIGNATORY']);
const MASTER_WRITE_ROLES=new Set(['SYSTEM_ADMIN','SECURITY_ADMIN','DATA_STEWARD']);
const REPORT_WRITE_ROLES=new Set(['SYSTEM_ADMIN','SECURITY_ADMIN','TECHNICAL_REVIEWER','APPROVING_AUTHORITY']);

function hasAny(principal:Principal,allowed:Set<string>){return principal.roles.some(r=>allowed.has(String(r)));}

export function getPrincipal(req:any):Principal{
  const authMode=String(process.env.AUTH_MODE||'demo').toLowerCase();
  const header=String(req.headers?.authorization||'');
  if(header.startsWith('Bearer ')){
    const payload=verifyToken(header.slice(7));
    if(payload)return {
      userId:payload.sub,
      username:payload.username,
      roles:payload.roles,
      isAuthenticated:true,
      mustChangePassword:Boolean(payload.mustChangePassword)
    };
  }
  // Header impersonation is intentionally allowed only in demo/test mode.
  if(authMode==='demo'){
    const userId=String(req.headers['x-lvsp-user']||'demo-admin');
    const roles=String(req.headers['x-lvsp-role']||'SYSTEM_ADMIN').split(',').map((x:string)=>x.trim()).filter(Boolean);
    return {userId,username:userId,roles,isAuthenticated:Boolean(userId),mustChangePassword:false};
  }
  return {userId:'',roles:[],isAuthenticated:false,mustChangePassword:false};
}

function isPublicPath(apiPath:string){
  return PUBLIC_EXACT.has(apiPath)||apiPath.startsWith('/public/')||apiPath.startsWith('/certificates/verify/');
}
function writeRolesFor(apiPath:string){
  if(apiPath.startsWith('/admin/'))return ADMIN_ROLES;
  if(
    apiPath.startsWith('/document-intake')||
    apiPath.startsWith('/drug-registrations')||
    apiPath.startsWith('/veterinary-drug-')||
    apiPath.startsWith('/legacy-parity/registration-')
  )return DRUG_WRITE_ROLES;
  if(
    apiPath.startsWith('/import-')||apiPath.startsWith('/export-')||
    apiPath.startsWith('/trade/')||
    apiPath.startsWith('/legacy-parity/trade-')||
    apiPath.startsWith('/animuse')
  )return TRADE_WRITE_ROLES;
  if(apiPath.startsWith('/companies')||apiPath.startsWith('/products')||apiPath.startsWith('/persons')||apiPath.startsWith('/facilities'))return MASTER_WRITE_ROLES;
  if(apiPath.startsWith('/reporting/')||apiPath.startsWith('/department-operations/'))return REPORT_WRITE_ROLES;
  return ALL_WRITE_ROLES;
}

export function authorize(principal:Principal,method:string,apiPath:string){
  if(isPublicPath(apiPath) && (method==='GET'||method==='HEAD'||(apiPath==='/auth/login' && method==='POST')))return {ok:true};
  if(!principal.isAuthenticated)return {ok:false,code:'UNAUTHENTICATED'};
  if(principal.mustChangePassword && !['/auth/me','/auth/change-password'].includes(apiPath))return {ok:false,code:'PASSWORD_CHANGE_REQUIRED'};
  if(method==='GET'||method==='HEAD')return {ok:true};
  const allowed=writeRolesFor(apiPath);
  if(hasAny(principal,allowed))return {ok:true};
  return {ok:false,code:'FORBIDDEN'};
}
