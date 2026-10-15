# Development Pack 03 — Facility Establishment, Factory/GMP, Product & Feed

## Goal
Implement regulated facilities/factories and the veterinary product/feed master lifecycles.

## Database scope
Migrations `000140`–`000171` in the migration manifest.

## Frozen domain rules
- A proposed Facility gets a permanent UUID before official number assignment.
- Establishment Approval, Operating Licence and GMP/technical certification are distinct lifecycles.
- One Facility can have multiple types/activities/components.
- Product is independent from Registration.
- Manufacturer is a Company Party; manufacturing site is a Facility.
- Product information, package and label changes preserve versions.
- Feed reuses `product.product`; feed-specific data lives in feed extensions.
- Feed formula versions are immutable history.
- Production Batch identity supports later QC/LIMS/distribution/recall.

## Do not implement here
Do not create separate inspection or laboratory engines. Use Pack 04 services once available.

## Acceptance
- Facility establishment workflow can end in establishment approval without automatically issuing operating licence/GMP.
- Product 360 data can show manufacturer, packages, versions and registration links without copying master data.
- Feed formula history and raw-material-to-batch trace foundation work.
