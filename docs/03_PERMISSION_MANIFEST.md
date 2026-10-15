# Permission Manifest

Naming convention: `<domain>.<resource>.<action>`.

## Core platform

- master.person.read / create / update / merge
- master.company.read / create / update / merge
- master.facility.read / create / update
- master.reference.read / manage / approve
- security.user.read / manage
- security.role.read / manage
- security.delegation.create / revoke
- workflow.definition.read / manage / publish
- workflow.task.read / claim / assign / complete
- document.read / upload / classify / generate
- audit.read / export

## Regulatory

- case.application.create / submit / withdraw / read
- case.review.read / review / request_information / complete
- case.decision.create / approve / reject / amend
- registration.read / issue / renew / vary / suspend / revoke
- licensing.license.read / issue / renew / amend / suspend / restore / revoke
- certificate.read / issue / revoke / verify

## Domain permissions

- facility.establishment.review / approve
- facility.gmp.assess / approve
- product.registration.read / review / approve
- product.variation.review / approve
- feed.registration.read / review / approve
- inspection.case.create / assign / perform / close
- inspection.finding.record
- compliance.capa.review / verify
- enforcement.case.read / act / decide / appeal_review
- laboratory.sample.receive
- laboratory.result.enter / validate / approve / amend
- animal.register / identify / transfer
- movement.review / authorize / complete
- disease.case.create / investigate / confirm
- outbreak.declare / close
- vaccination.record
- trade.permit.review / approve
- trade.shipment.inspect / quarantine / clear
- trade.certificate.issue
- fisheries.aquaculture.manage

## Role families

SYSTEM_ADMIN, SECURITY_ADMIN, DATA_STEWARD, MASTER_DATA_APPROVER, REGISTRY_OFFICER, TECHNICAL_REVIEWER, INSPECTOR, SENIOR_INSPECTOR, LAB_ANALYST, LAB_VALIDATOR, LAB_APPROVER, EPIDEMIOLOGIST, QUARANTINE_OFFICER, BORDER_OFFICER, LICENSING_OFFICER, APPROVING_AUTHORITY, CERTIFICATE_SIGNATORY, AUDITOR, MANAGEMENT_VIEWER, COMPANY_ADMIN, COMPANY_USER, FARM_OPERATOR, PUBLIC_USER.

Roles do not replace scopes. Authorization is RBAC + ABAC + organization/geographic scope + record relationship + data classification.
