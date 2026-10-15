import fs from 'node:fs';
fs.mkdirSync('public',{recursive:true});
fs.cpSync('apps/web/public','public',{recursive:true});
fs.cpSync('apps/field/public','public/field',{recursive:true});
fs.copyFileSync('openapi/lvsp-openapi.yaml','public/openapi.yaml');
