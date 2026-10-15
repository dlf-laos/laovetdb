// Vercel owns the HTTP listener; retain the incoming path and request stream.
let initialization;
export default async function handler(req,res){
  if(process.env.AUTH_MODE!=='database'||process.env.LVSP_STORAGE!=='postgres'||!process.env.DATABASE_URL||String(process.env.LVSP_AUTH_SECRET||'').length<32){
    res.statusCode=503;res.setHeader('content-type','application/json');
    res.end(JSON.stringify({error:{code:'DEPLOYMENT_CONFIGURATION_REQUIRED',message:'Configure database authentication, PostgreSQL and signing secret.'}}));return;
  }
  process.env.VERCEL='1';
  initialization ||= import('../apps/api/dist/server.js');
  const {server}=await initialization;
  server.emit('request',req,res);
}
