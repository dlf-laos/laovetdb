import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const release=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const target=process.argv[2]&&path.resolve(process.argv[2]);
if(!target||!fs.existsSync(path.join(target,'.git')))throw new Error('Select an existing local clone of laovetdb.');
if(target===release)throw new Error('Use a separate existing Git clone.');
function run(args){const result=spawnSync('git',args,{cwd:target,encoding:'utf8'});if(result.status!==0)throw new Error(result.stderr||'Git failed');return result.stdout.trim();}
const remote=run(['remote','get-url','origin']);
if(!/(?:\/|:)laovetdb(?:\.git)?$/.test(remote))throw new Error('Origin must point to the laovetdb repository.');
if(run(['status','--porcelain']))throw new Error('The Git clone has unsaved changes. Save them first.');
const branch='lvsp-release-20261004-'+Date.now();
run(['checkout','-b',branch]);
const items=['.github','apps','packages','api','database','docs','openapi','scripts','package.json','package-lock.json','VERSION','vercel.json','.gitignore','.vercelignore','.env.example','.env.production.example','README.md','README_RELEASE_LO.md','START_REVIEW.command','CHECK_RELEASE.command','UPDATE_GITHUB.command','IMPLEMENTATION_STATE.json','requirements-validation.txt'];
function filter(source){const name=path.basename(source);return !['admin4_legacy_records.json','legacy_vet_suite_export.json'].includes(name)&&name!=='node_modules'&&name!=='dist'&&name!=='.DS_Store'&&!name.endsWith('.log')&&!name.endsWith('.tmp')&&!name.includes('.bak.')&&!name.includes('.before_')&&!(source.includes(path.sep+'runtime'+path.sep)&&name!=='routes.json')&&!(name.startsWith('.env')&&!name.endsWith('.example'));}
for(const item of items)if(fs.existsSync(path.join(release,item)))fs.cpSync(path.join(release,item),path.join(target,item),{recursive:true,filter});
run(['add','--',...items.filter(x=>fs.existsSync(path.join(target,x)))]);
run(['commit','-m','Prepare LVSP departmental release with monthly work and budget tracking']);
run(['push','-u','origin',branch]);
console.log('Uploaded review branch: '+branch+'\nOpen a pull request in GitHub. After review and merge, the connected Vercel project deploys.');
