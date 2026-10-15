-- Create version 1 as DRAFT for every workflow family. Domain/legal review must publish a workflow before use.
INSERT INTO workflow.definition_version(definition_id,version_no,effective_from,status)
SELECT id,1,now(),'DRAFT' FROM workflow.definition
ON CONFLICT(definition_id,version_no) DO NOTHING;

-- Seed the generic regulatory pattern for WF-001 only. Other workflow families remain DRAFT for domain-specific configuration.
WITH v AS (
 SELECT dv.id FROM workflow.definition_version dv JOIN workflow.definition d ON d.id=dv.definition_id
 WHERE d.workflow_code='WF-001' AND dv.version_no=1
)
INSERT INTO workflow.step(workflow_version_id,step_code,name_lo,name_en,step_type,sequence_no)
SELECT v.id,x.code,x.lo,x.en,'HUMAN_TASK',x.seq FROM v CROSS JOIN (VALUES
 ('DRAFT','ຮ່າງ','Draft',10),('SUBMITTED','ຍື່ນແລ້ວ','Submitted',20),('RECEIVED','ຮັບແລ້ວ','Received',30),
 ('ADMISSIBILITY_CHECK','ກວດຄວາມຄົບຖ້ວນ','Admissibility Check',40),('TECHNICAL_REVIEW','ກວດດ້ານວິຊາການ','Technical Review',50),
 ('READY_FOR_DECISION','ພ້ອມພິຈາລະນາ','Ready for Decision',60),('DECISION','ການຕັດສິນ','Decision',70),
 ('DOCUMENT_ISSUANCE','ອອກເອກະສານ','Document Issuance',80),('COMPLETED','ສຳເລັດ','Completed',90)
) AS x(code,lo,en,seq)
ON CONFLICT(workflow_version_id,step_code) DO NOTHING;
