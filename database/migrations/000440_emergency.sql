CREATE TABLE disease.emergency_incident (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), incident_no VARCHAR(120) NOT NULL UNIQUE,
 outbreak_id UUID REFERENCES disease.outbreak(id) ON DELETE RESTRICT, incident_level VARCHAR(30), activated_at TIMESTAMPTZ NOT NULL,
 deactivated_at TIMESTAMPTZ, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', CONSTRAINT ck_incident_dates CHECK(deactivated_at IS NULL OR deactivated_at>=activated_at));
CREATE TABLE disease.emergency_team_assignment (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), incident_id UUID NOT NULL REFERENCES disease.emergency_incident(id) ON DELETE RESTRICT,
 user_id UUID NOT NULL REFERENCES security.app_user(id) ON DELETE RESTRICT, team_role VARCHAR(50) NOT NULL, assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(), released_at TIMESTAMPTZ);
CREATE TABLE disease.emergency_activity (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), incident_id UUID NOT NULL REFERENCES disease.emergency_incident(id) ON DELETE RESTRICT,
 activity_type VARCHAR(50) NOT NULL, activity_at TIMESTAMPTZ NOT NULL, organization_id UUID REFERENCES master.organization(id) ON DELETE RESTRICT,
 summary TEXT, document_id UUID REFERENCES document.document(id) ON DELETE RESTRICT);
