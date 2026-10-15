// LVSP authentication primitives.
// Demo/local mode remains available for isolated development only.
// Database mode uses individual security.app_user credentials.
// @ts-nocheck
import crypto from 'node:crypto';

export type SessionPayload={
  sub:string;
  roles:string[];
  username?:string;
  mustChangePassword?:boolean;
  iat:number;
  exp:number
};

function secret(){
  const configured=String(process.env.LVSP_AUTH_SECRET||'');
  const production=String(process.env.NODE_ENV||'development').toLowerCase()==='production';
  if(production && configured.length<32) throw new Error('LVSP_AUTH_SECRET must be at least 32 characters in production');
  return configured || 'lvsp-development-secret-change-me';
}
function b64url(v:Buffer|string){return Buffer.from(v).toString('base64url');}
function sign(data:string){return crypto.createHmac('sha256',secret()).update(data).digest('base64url');}

export function issueToken(userId:string,roles:string[],ttlSeconds=8*60*60,extra:any={}){
  const now=Math.floor(Date.now()/1000);
  const payload:SessionPayload={
    sub:userId,
    roles:Array.from(new Set((roles||[]).map(String))),
    username:extra.username?String(extra.username):undefined,
    mustChangePassword:Boolean(extra.mustChangePassword),
    iat:now,
    exp:now+ttlSeconds
  };
  const body=b64url(JSON.stringify(payload));
  return `${body}.${sign(body)}`;
}

export function verifyToken(token:string):SessionPayload|null{
  try{
    const [body,sig]=String(token||'').split('.');
    if(!body||!sig)return null;
    const expected=sign(body);
    const a=Buffer.from(sig); const b=Buffer.from(expected);
    if(a.length!==b.length||!crypto.timingSafeEqual(a,b))return null;
    const payload=JSON.parse(Buffer.from(body,'base64url').toString('utf8'));
    if(!payload?.sub||!Array.isArray(payload.roles)||Number(payload.exp)<Math.floor(Date.now()/1000))return null;
    return payload;
  }catch{return null;}
}

const SCRYPT_N=32768;
const SCRYPT_R=8;
const SCRYPT_P=1;
const SCRYPT_KEYLEN=64;
const SCRYPT_MAXMEM=128*1024*1024;

export function validatePasswordPolicy(password:string){
  const v=String(password||'');
  if(v.length<12)return {ok:false,message:'Password must contain at least 12 characters'};
  if(!/[A-Za-z]/.test(v)||!/[0-9]/.test(v))return {ok:false,message:'Password must contain letters and numbers'};
  return {ok:true,message:''};
}

export function hashPassword(password:string){
  const policy=validatePasswordPolicy(password);
  if(!policy.ok)throw Object.assign(new Error(policy.message),{statusCode:400,code:'WEAK_PASSWORD'});
  const salt=crypto.randomBytes(16);
  const key=crypto.scryptSync(String(password),salt,SCRYPT_KEYLEN,{N:SCRYPT_N,r:SCRYPT_R,p:SCRYPT_P,maxmem:SCRYPT_MAXMEM});
  return `scrypt$${SCRYPT_N}$${SCRYPT_R}$${SCRYPT_P}$${salt.toString('base64url')}$${key.toString('base64url')}`;
}

export function verifyPassword(password:string,encoded:string){
  try{
    const [kind,nRaw,rRaw,pRaw,saltRaw,keyRaw]=String(encoded||'').split('$');
    if(kind!=='scrypt'||!nRaw||!rRaw||!pRaw||!saltRaw||!keyRaw)return false;
    const expected=Buffer.from(keyRaw,'base64url');
    const actual=crypto.scryptSync(String(password),Buffer.from(saltRaw,'base64url'),expected.length,{
      N:Number(nRaw),r:Number(rRaw),p:Number(pRaw),maxmem:SCRYPT_MAXMEM
    });
    return actual.length===expected.length&&crypto.timingSafeEqual(actual,expected);
  }catch{return false;}
}

export function authenticateLocal(username:string,password:string){
  const expectedUser=process.env.LVSP_BOOTSTRAP_ADMIN_USER || 'admin';
  const expectedPassword=process.env.LVSP_BOOTSTRAP_ADMIN_PASSWORD || 'lvsp-demo-change-me';
  const ub=Buffer.from(String(username)); const eu=Buffer.from(expectedUser);
  const pb=Buffer.from(String(password)); const ep=Buffer.from(expectedPassword);
  const userOk=ub.length===eu.length&&crypto.timingSafeEqual(ub,eu);
  const passOk=pb.length===ep.length&&crypto.timingSafeEqual(pb,ep);
  if(!userOk||!passOk)return null;
  return {userId:expectedUser,username:expectedUser,roles:['SYSTEM_ADMIN'],mustChangePassword:false};
}
