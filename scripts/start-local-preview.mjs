// Run the existing LVSP app against the separately provisioned Preview database.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const file=path.join(root,'.env.preview.private');
if(!fs.existsSync(file))throw new Error('Private Preview configuration is missing. Ask the system administrator to configure it; do not put credentials in source code.');
const config=JSON.parse(fs.readFileSync(file,'utf8'));
if(new URL(config.DATABASE_URL).pathname!=='/lvsp_preview_20261015')throw new Error('This launcher accepts the isolated Preview database only.');
Object.assign(process.env,config,{LVSP_PG_TRANSPORT:'neon-ws',NODE_ENV:'production',VERCEL:'1'});
const {server,store}=await import('../apps/api/dist/server.js');
server.once('error',async error=>{console.error(error.code==='EADDRINUSE'?'LVSP is already using port 8793. Open http://127.0.0.1:8793/admin.html':error.message);await store.close();process.exitCode=1;});
server.listen(8793,'127.0.0.1',()=>console.log('LVSP Preview: http://127.0.0.1:8793/admin.html\nThis address works on this computer only. It uses the isolated Neon Preview database.\nGemini is available locally only if a server-side key is configured locally; the Vercel Secret is not copied here.'));
for(const signal of ['SIGINT','SIGTERM'])process.once(signal,()=>server.close(async()=>{await store.close();process.exit(0);}));
