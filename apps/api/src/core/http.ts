// @ts-nocheck
import crypto from 'node:crypto';

export async function readJson(req:any) {
  const chunks:any[] = [];
  for await (const chunk of req) chunks.push(chunk);
  if (!chunks.length) return {};
  const raw = Buffer.concat(chunks).toString('utf8');
  if (!raw.trim()) return {};
  try { return JSON.parse(raw); }
  catch { throw Object.assign(new Error('Invalid JSON body'), { statusCode: 400, code: 'INVALID_JSON' }); }
}

export function requestIds(req:any) {
  return {
    requestId: String(req.headers['x-request-id'] || crypto.randomUUID()),
    correlationId: String(req.headers['x-correlation-id'] || crypto.randomUUID()),
  };
}

export function sendJson(res:any, status:number, payload:any, ids?:any) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    'content-type':'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(body),
    'x-request-id': ids?.requestId || '',
    'x-correlation-id': ids?.correlationId || '',
    'access-control-allow-origin':'*',
    'access-control-allow-headers':'content-type,x-lvsp-user,x-lvsp-role,x-request-id,x-correlation-id,idempotency-key',
    'access-control-allow-methods':'GET,POST,OPTIONS',
  });
  res.end(body);
}

export function success(data:any, meta:any={}) { return { data, meta }; }
export function failure(code:string, message:string, ids:any, details:any[]=[]){
  return { error: { code, message, details, requestId: ids.requestId } };
}
