# Development Pack 05 — Farm, Animal Identification, Movement & Traceability

## Goal
Implement livestock holdings, individual/group animal identity and movement history.

## Database scope
Migrations `000300`–`000340`.

## Rules
- Farm is an extension of Facility; do not duplicate facility name/address/GIS/owner.
- Species/breed are controlled reference data.
- Support both individual and group/batch traceability; species policy is configurable.
- Multiple identifiers can exist per animal (ear tag/RFID/microchip/etc.).
- Ownership/location histories are effective-dated and never replaced by only a `current_*` value.
- Lifecycle history is append-oriented.
- Movement authorization and actual movement are distinct lifecycle concepts.
- Movement supports individual animals and groups.

## Integration points
Prepare explicit service interfaces for Disease movement restrictions, Laboratory sampling, Inspection, Slaughter and Trade/Export.

## Acceptance
Trace any registered subject across identity, owner, location and movement history without loss of prior state. Tests must prove current projections can be rebuilt from history where designed.
