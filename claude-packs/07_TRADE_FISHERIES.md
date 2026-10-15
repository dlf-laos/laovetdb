# Development Pack 07 — Trade, Border Quarantine, e-Certificate & Fisheries/Aquaculture

## Goal
Implement import/export/transit, border controls, electronic certificates and aquaculture foundations.

## Database scope
Migrations `000500`–`000552`.

## Trade rules
- Trade Operator references Party; do not duplicate Company.
- Permit ≠ Shipment ≠ Border Declaration ≠ Inspection ≠ Quarantine ≠ Clearance ≠ Health Certificate.
- Border inspection reuses Enterprise Inspection Engine.
- Laboratory testing reuses LIMS.
- Risk assessment is decision support only.
- Certificates use shared Certificate Engine and preserve structured machine-readable issuance snapshot.
- e-Certificate integrations live behind adapters/partner profiles; never assume a partner interface exists without configuration/agreement.

## Fisheries rules
- Aquaculture Facility reuses Facility master.
- Aquatic health reuses Disease/LIMS/Inspection/Trade engines.
- Stock/production/harvest data remains domain-specific without duplicating shared registries.

## Acceptance
A shipment can be traced from operator/permit through declaration, inspection/lab/quarantine, authorized clearance and certificate while all objects retain separate identities/history.
