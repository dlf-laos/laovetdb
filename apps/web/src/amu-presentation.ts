// Parse only explicit, dimensionally compatible labels; never infer a presentation.
export function presentationToAmu(p:any,references:any[]=[]){
 const scalar=(v:any)=>typeof v==='number'?v:typeof v==='string'&&/^\d+(?:\.\d+)?$/.test(v.trim())?Number(v):null;
 const size=scalar(p.packSize),unit=String(p.packUnit||'').toLowerCase();
 const unitMap:any={ml:['ml',1],l:['ml',1000],g:['g',1],kg:['g',1000],unit:['unit',1],tablet:['unit',1]};
 const sizeMatch=String(p.packSizeText||'').trim().match(/^(\d+(?:\.\d+)?)\s*(ml|l|g|kg|unit|tablet)$/i);
 const amount=size!==null&&unitMap[unit]?[size*unitMap[unit][1],unitMap[unit][0]]:sizeMatch?[Number(sizeMatch[1])*unitMap[sizeMatch[2].toLowerCase()][1],unitMap[sizeMatch[2].toLowerCase()][0]]:null;
 const basis=String(p.basisText||'').trim().match(/^(\d+(?:\.\d+)?)\s*(ml|g|unit|tablet)$/i);
 const components=(p.composition||[]).map((c:any)=>{
  const ref=references.find((r:any)=>String(r.substance_name_en).toLowerCase()===String(c.name).toLowerCase());
  const q=scalar(c.quantity),u=String(c.unit||'').trim().toLowerCase();
  const valid=q!==null&&basis&&Number(basis[1])>0&&['mg','g','mcg','µg','iu'].includes(u);
  const basisUnit=basis?.[2].toLowerCase()==='tablet'?'unit':basis?.[2].toLowerCase();
  const mult:any={mg:1,g:1000,mcg:0.001,'µg':0.001,iu:1};
  return {name:c.name,classCode:ref?.animuse_class_code||'',mode:valid?(u==='iu'?'IU':'mg')+'/'+basisUnit:'mg/ml',strength:valid?q!*mult[u]/Number(basis![1]):'',massBasis:'LABEL_COMPOUND',evidence:'',iuPerMg:ref?.iu_per_mg||'',conversionEvidence:'',excluded:false};
 });
 return {packCount:'',packSize:amount?.[0]??'',packUnit:amount?.[1]||'ml',components};
}
