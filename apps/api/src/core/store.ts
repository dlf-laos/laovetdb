// LVSP local development store. Production uses the authoritative PostgreSQL schema.
// @ts-nocheck
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

export interface LVSPStore {
  mode: string;
  list(resource:string):Promise<any[]>;
  get(resource:string,id:string):Promise<any|undefined>;
  find(resource:string,predicate:(x:any)=>boolean):Promise<any|undefined>;
  create(resource:string,input:any):Promise<any>;
  update(resource:string,id:string,patch:any):Promise<any|undefined>;
  audit(event:any):Promise<void>;
  enqueue(event:any):Promise<void>;
  auditEvents():Promise<any[]>;
  outboxEvents():Promise<any[]>;
  reset?():Promise<void>;
  health?():Promise<any>;
  close?():Promise<void>;
}

export class JsonFileStore implements LVSPStore {
  mode='local-json';
  private filePath:string;
  private data:any;
  constructor(filePath:string){this.filePath=filePath;this.data=this.load();}
  private empty(){const now=new Date().toISOString();return {meta:{version:1,createdAt:now,updatedAt:now},resources:{},audit:[],outbox:[]};}
  private load(){try{if(fs.existsSync(this.filePath))return JSON.parse(fs.readFileSync(this.filePath,'utf8'));}catch(e){console.error('[store] failed to read local store',e)}const d=this.empty();this.persist(d);return d;}
  private persist(data=this.data){fs.mkdirSync(path.dirname(this.filePath),{recursive:true});data.meta.updatedAt=new Date().toISOString();const tmp=`${this.filePath}.${process.pid}.${crypto.randomUUID()}.tmp`;fs.writeFileSync(tmp,JSON.stringify(data,null,2));fs.renameSync(tmp,this.filePath);}
  async list(resource:string){return [...(this.data.resources[resource]||[])];}
  async get(resource:string,id:string){return (this.data.resources[resource]||[]).find((x:any)=>x.id===id);}
  async find(resource:string,predicate:any){return (this.data.resources[resource]||[]).find(predicate);}
  async create(resource:string,input:any){const now=new Date().toISOString();const record={id:input?.id||crypto.randomUUID(),...input,createdAt:input?.createdAt||now,updatedAt:now};if(!this.data.resources[resource])this.data.resources[resource]=[];this.data.resources[resource].push(record);this.persist();return record;}
  async update(resource:string,id:string,patch:any){const list=this.data.resources[resource]||[];const idx=list.findIndex((x:any)=>x.id===id);if(idx<0)return undefined;list[idx]={...list[idx],...patch,id,updatedAt:new Date().toISOString()};this.persist();return list[idx];}
  async audit(event:any){this.data.audit.push({id:crypto.randomUUID(),occurredAt:new Date().toISOString(),...event});this.persist();}
  async enqueue(event:any){this.data.outbox.push({id:crypto.randomUUID(),occurredAt:new Date().toISOString(),publishedAt:null,...event});this.persist();}
  async auditEvents(){return [...this.data.audit].reverse();}
  async outboxEvents(){return [...this.data.outbox].reverse();}
  async reset(){this.data=this.empty();this.persist();}
  async health(){return {ok:true,mode:this.mode};}
}
