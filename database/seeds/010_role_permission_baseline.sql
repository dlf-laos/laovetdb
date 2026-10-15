-- Conservative starter mapping. Review against official delegation/organization rules before production.
INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r CROSS JOIN security.permission p
WHERE r.code='SYSTEM_ADMIN'
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code LIKE 'security.%'
WHERE r.code='SECURITY_ADMIN' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code LIKE 'master.%'
WHERE r.code='DATA_STEWARD' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('master.reference.read','master.reference.approve')
WHERE r.code='MASTER_DATA_APPROVER' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code LIKE 'inspection.%'
WHERE r.code IN ('INSPECTOR','SENIOR_INSPECTOR') ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON
 (r.code='LAB_ANALYST' AND p.code IN ('laboratory.sample.receive','laboratory.result.enter')) OR
 (r.code='LAB_VALIDATOR' AND p.code='laboratory.result.validate') OR
 (r.code='LAB_APPROVER' AND p.code='laboratory.result.approve')
ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code LIKE 'disease.%' OR p.code LIKE 'outbreak.%' OR p.code='vaccination.record'
WHERE r.code='EPIDEMIOLOGIST' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code IN ('audit.read','audit.export')
WHERE r.code='AUDITOR' ON CONFLICT DO NOTHING;

INSERT INTO security.role_permission(role_id,permission_id)
SELECT r.id,p.id FROM security.role r JOIN security.permission p ON p.code='certificate.verify'
WHERE r.code='PUBLIC_USER' ON CONFLICT DO NOTHING;
