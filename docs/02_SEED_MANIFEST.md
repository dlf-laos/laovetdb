# Seed Manifest

## System seeds

- data classifications: PUBLIC, INTERNAL, RESTRICTED, CONFIDENTIAL, HIGHLY_CONFIDENTIAL
- core role families
- core permission catalog
- workflow status catalog
- document types
- service domain codes: VM, LS, AH, LAB, TR, FI, AF, VF, IN, RC

## Reference seeds

- countries (ISO codes)
- administrative unit types: COUNTRY, PROVINCE, DISTRICT, COMMUNE, VILLAGE
- species and breed catalog (curated import, not hard-coded assumptions)
- facility types
- party role types
- product types
- licence types
- registration types
- inspection trigger types
- sample types / test method categories
- commodity classes
- units of measure

## Lao geography

Load Lao administrative units from a curated, approved dataset. Preserve `official_code`, `parent_id`, `valid_from`, `valid_to`, and change history. Never seed geography by embedding province/district/village constants throughout application code.

## Included SQL seed files in v2.0

The package now includes executable baseline seeds `001` through `012`. Workflow and service versions are seeded as `DRAFT` where legal/domain review is still required; this avoids treating unverified regulatory configuration as active law.
