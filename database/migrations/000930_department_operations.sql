-- Internal departmental work and budget tracking, not a regulatory decision engine.
-- Amounts are whole Lao kip; no fees, exchange rates or issuing authority are inferred.
CREATE TABLE IF NOT EXISTS reporting.department_work_item (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 report_month varchar(7) NOT NULL CHECK (report_month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
 title varchar(300) NOT NULL, planned_result text NOT NULL DEFAULT '', actual_result text NOT NULL DEFAULT '',
 notes text NOT NULL DEFAULT '', owner_subject text NOT NULL,
 status varchar(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','SUBMITTED','VERIFIED','RETURNED')),
 version integer NOT NULL DEFAULT 1, reviewed_by text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS reporting.department_budget_entry (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 report_month varchar(7) NOT NULL CHECK (report_month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
 title varchar(300) NOT NULL, currency varchar(3) NOT NULL DEFAULT 'LAK' CHECK (currency='LAK'),
 planned_amount numeric(16,0) NOT NULL DEFAULT 0 CHECK (planned_amount>=0 AND planned_amount<=9007199254740991),
 actual_amount numeric(16,0) NOT NULL DEFAULT 0 CHECK (actual_amount>=0 AND actual_amount<=9007199254740991),
 notes text NOT NULL DEFAULT '', owner_subject text NOT NULL,
 status varchar(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','SUBMITTED','VERIFIED','RETURNED')),
 version integer NOT NULL DEFAULT 1, reviewed_by text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_department_work_month ON reporting.department_work_item(report_month,status);
CREATE INDEX IF NOT EXISTS ix_department_budget_month ON reporting.department_budget_entry(report_month,status);

CREATE TRIGGER department_work_no_delete BEFORE DELETE ON reporting.department_work_item FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER department_budget_no_delete BEFORE DELETE ON reporting.department_budget_entry FOR EACH ROW EXECUTE FUNCTION system.prevent_hard_delete();
CREATE TRIGGER department_work_verified_lock BEFORE UPDATE ON reporting.department_work_item FOR EACH ROW EXECUTE FUNCTION system.prevent_change_if_status('VERIFIED');
CREATE TRIGGER department_budget_verified_lock BEFORE UPDATE ON reporting.department_budget_entry FOR EACH ROW EXECUTE FUNCTION system.prevent_change_if_status('VERIFIED');
