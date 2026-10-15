# Test Matrix

## Database

- rebuild from migration 000001 on empty database
- upgrade from prior release
- FK / unique / check constraints
- rollback or forward-fix procedure tested
- seed idempotency where designed
- index presence on critical search/FK paths

## Security

- unauthenticated access denied where required
- role permission matrix
- organization scope
- geographic scope
- delegation expiry
- separation of duties
- applicant cannot read internal notes
- public verification reveals only approved public fields

## Critical E2E journeys

1. Company/Party setup
2. Facility establishment application → decision
3. Operating licence issuance
4. Veterinary product registration → certificate
5. Inspection → Finding → CAPA → close
6. Sample → LIMS → validate → approve result
7. Farm + animal registration → movement
8. Disease case → sample → outbreak decision → restriction
9. Trade permit → shipment → border inspection/quarantine → clearance → certificate
10. Certificate QR verification/revocation

## Resilience

- duplicate command/idempotency
- external integration outage
- outbox retry
- background job retry
- object storage failure
- database fail/reconnect
- backup restore rehearsal

No production release if critical journeys, permission tests, migration tests or restore tests fail.
