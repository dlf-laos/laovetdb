# Workflow Seed Manifest

## Baseline workflow families

- WF-001 Generic Registration
- WF-002 Generic Licensing
- WF-003 Product Registration
- WF-004 Factory Establishment
- WF-005 GMP / Technical Certification
- WF-006 Import / Export / Transit
- WF-007 Inspection & CAPA
- WF-008 Laboratory Testing
- WF-009 Disease Investigation & Outbreak
- WF-010 Animal Movement
- WF-011 Regulatory Enforcement
- WF-012 Master Data Change

## Generic regulatory state pattern

DRAFT → SUBMITTED → RECEIVED → ADMISSIBILITY_CHECK → TECHNICAL_REVIEW → READY_FOR_DECISION → DECISION → DOCUMENT_ISSUANCE → COMPLETED.

Optional branches: RETURNED_FOR_CORRECTION, INSPECTION_REQUIRED, LAB_REQUIRED, COMMITTEE_REQUIRED, ADDITIONAL_INFORMATION_REQUIRED, SUSPENDED, CANCELLED.

## Critical rule

A running workflow instance remains bound to the workflow version on which it started. New workflow versions apply to new cases unless a separately approved migration process exists.
