// Read-only. Never imports a browser backup directly into operational tables.
import fs from 'node:fs';import crypto from 'node:crypto';
const file=process.argv[2];if(!file)throw Error('Usage: node scripts/audit-v31-export.mjs /path/to/browser-backup.json');
const bytes=fs.readFileSync(file);if(bytes.length>50*1024*1024)throw Error('Backup exceeds 50 MiB');
const data=JSON.parse(bytes.toString('utf8'));
const arrays=Object.fromEntries(Object.entries(data).filter(([,v])=>Array.isArray(v)).map(([k,v])=>[k,v.length]));
const permits=Array.isArray(data.permit)?data.permit:[],items=Array.isArray(data.permit_item)?data.permit_item:[];
const ids=new Set(permits.map(p=>p.id));
const result={sha256:crypto.createHash('sha256').update(bytes).digest('hex'),arrays,missingParentItems:items.filter(x=>!ids.has(x.permitId)).length,itemsWithoutActualClearedPacks:items.filter(x=>x.packsCleared==null||x.packsCleared==='').length,unlinkedTradeItems:items.filter(x=>!x.productId).length,permitsWithoutActualClearanceDate:permits.filter(x=>!x.clearedDate).length,movements:Object.fromEntries(['IMPORT','EXPORT','RE_EXPORT','TRANSIT','UNKNOWN'].map(k=>[k,permits.filter(p=>(p.type||'UNKNOWN')===k).length])),next:'Reconcile source counts, registration/presentation mapping, actual clearances and duplicates before importing. No database connection or writes were made.'};
console.log(JSON.stringify(result,null,2));
