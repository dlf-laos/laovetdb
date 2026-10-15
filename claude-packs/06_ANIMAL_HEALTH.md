# Development Pack 06 — Surveillance, Disease, Vaccination, Emergency & AMR

## Goal
Implement terrestrial/aquatic-compatible animal-health workflows using shared Farm/Animal/LIMS/GIS foundations.

## Database scope
Migrations `000400`–`000450`.

## Rules
- Disease Case ≠ Outbreak; one Outbreak can link many Cases.
- Surveillance Programs are versioned and configurable.
- Disease samples use shared LIMS.
- Disease zones/restrictions are effective-dated spatial regulatory records.
- Movement authorization must check applicable active restrictions through a domain service.
- Vaccination events can target individual animals, groups or farms and reference Product/Batch.
- AMR extends laboratory samples/results; do not build a duplicate lab system.
- AI/risk analytics can prioritize/inform only; outbreak confirmation/control actions require competent human/regulatory authority.

## Acceptance
- Suspected case → investigation → sample/LIMS → confirmation → outbreak/control workflow is testable end to end.
- Disease restriction blocks movement only through configured/legal rules and authorized decisions.
- Historical zones/control measures remain queryable.
