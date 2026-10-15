export function required(value:unknown,name='value'){if(value===undefined||value===null||String(value).trim()==='')throw new Error(`${name} is required`);return value}
export function nonNegative(value:unknown,name='value'){const n=Number(value);if(!Number.isFinite(n)||n<0)throw new Error(`${name} must be non-negative`);return n}
export function isoDate(value:unknown,name='date'){const d=new Date(String(value));if(Number.isNaN(d.getTime()))throw new Error(`${name} must be a valid date`);return d.toISOString()}
export function oneOf<T extends string>(value:unknown,allowed:readonly T[],name='value'):T{if(!allowed.includes(value as T))throw new Error(`${name} is invalid`);return value as T}
