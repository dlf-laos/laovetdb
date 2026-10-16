export type ConnectionStatus = {state:'connected'|'offline'|'unavailable';storage?:string};

export async function probeConnection(online:boolean,fetcher:typeof fetch=fetch,timeoutMs=8000):Promise<ConnectionStatus>{
 if(!online)return {state:'offline'};
 try{
  const response=await fetcher('/ready',{cache:'no-store',signal:AbortSignal.timeout(timeoutMs)});
  if(!response.ok)return {state:'unavailable'};
  const result=await response.json();
  if(result?.status!=='ready'||result?.details?.ok!==true)return {state:'unavailable'};
  return {state:'connected',storage:result.storage};
 }catch{return {state:'unavailable'};}
}
