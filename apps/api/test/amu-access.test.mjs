import test from 'node:test';import assert from 'node:assert/strict';
import {handleAmuApi} from '../dist/core/amu-api.js';
test('trade-surveillance API denies anonymous users, applicants and users requiring password change before database access',async()=>{
 const ctx={req:{method:'GET'},res:{},url:new URL('https://example.test/api/v1/animuse/ledger'),store:{mode:'postgres',get pool(){throw Error('Database must not be accessed')}},ids:{}};
 await assert.rejects(handleAmuApi({...ctx,principal:{isAuthenticated:false}}),e=>e.statusCode===401);
 await assert.rejects(handleAmuApi({...ctx,principal:{isAuthenticated:true,roles:['APPLICANT']}}),e=>e.statusCode===403);
 await assert.rejects(handleAmuApi({...ctx,principal:{isAuthenticated:true,roles:['REGISTRY_OFFICER'],mustChangePassword:true}}),e=>e.code==='PASSWORD_CHANGE_REQUIRED');
});
