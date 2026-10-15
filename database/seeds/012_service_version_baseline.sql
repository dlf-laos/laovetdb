-- Initial service versions are DRAFT until legal/workflow configuration is reviewed and published.
INSERT INTO system.service_version(service_id,version_no,effective_from,workflow_code,status)
SELECT id,1,now(),
 CASE domain_code
  WHEN 'VM' THEN 'WF-003' WHEN 'VF' THEN 'WF-004' WHEN 'IN' THEN 'WF-007' WHEN 'LAB' THEN 'WF-008'
  WHEN 'AH' THEN 'WF-009' WHEN 'TR' THEN 'WF-006' WHEN 'FI' THEN 'WF-002' WHEN 'AF' THEN 'WF-003'
  ELSE 'WF-001' END,
 'DRAFT'
FROM system.service_definition
ON CONFLICT(service_id,version_no) DO NOTHING;
