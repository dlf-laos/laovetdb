import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const auth=fs.readFileSync(new URL('../src/core/auth.ts',import.meta.url),'utf8');
const security=fs.readFileSync(new URL('../src/core/security.ts',import.meta.url),'utf8');
const server=fs.readFileSync(new URL('../src/server.ts',import.meta.url),'utf8');
const store=fs.readFileSync(new URL('../src/core/postgres-store.ts',import.meta.url),'utf8');
const web=fs.readFileSync(new URL('../../web/src/app.ts',import.meta.url),'utf8');
const html=fs.readFileSync(new URL('../../web/public/index.html',import.meta.url),'utf8');
const migration=fs.readFileSync(new URL('../../../database/migrations/000820_online_auth_public_access.sql',import.meta.url),'utf8');

test('v1.7 database authentication uses individual users and scrypt password hashing',()=>{
  assert.match(auth,/scryptSync/);
  assert.match(auth,/validatePasswordPolicy/);
  assert.match(store,/authenticateAppUser/);
  assert.match(store,/security\.app_user/);
  assert.match(server,/AUTH_MODE=database/);
});

test('v1.7 production refuses demo auth and requires a strong signing secret',()=>{
  assert.match(server,/Production requires AUTH_MODE=database or oidc/);
  assert.match(server,/LVSP_AUTH_SECRET must be at least 32 characters in production/);
});

test('v1.7 exposes only explicit public read-only endpoints without a token',()=>{
  assert.match(security,/apiPath\.startsWith\('\/public\/'\)/);
  assert.match(server,/\/api\/v1\/public\/overview/);
  assert.match(server,/\/api\/v1\/public\/drug-registry/);
  assert.match(web,/renderPublicOverview/);
  assert.match(html,/browse-public-btn/);
});

test('v1.7 protects write operations by module role families',()=>{
  assert.match(security,/DRUG_WRITE_ROLES/);
  assert.match(security,/TRADE_WRITE_ROLES/);
  assert.match(security,/MASTER_WRITE_ROLES/);
  assert.match(security,/PASSWORD_CHANGE_REQUIRED/);
});

test('v1.7 adds admin user provisioning, password reset and role assignment APIs',()=>{
  assert.match(server,/createAdminUser/);
  assert.match(server,/resetAdminUserPassword/);
  assert.match(server,/setAdminUserRoles/);
  assert.match(store,/must_change_password/);
});

test('v1.7 migration is additive and seeds controlled roles and permissions',()=>{
  assert.match(migration,/ADD COLUMN IF NOT EXISTS password_hash/);
  assert.match(migration,/SYSTEM_ADMIN/);
  assert.match(migration,/REGISTRY_OFFICER/);
  assert.match(migration,/TECHNICAL_REVIEWER/);
  assert.match(migration,/APPROVING_AUTHORITY/);
  assert.match(migration,/security\.role_permission/);
});
