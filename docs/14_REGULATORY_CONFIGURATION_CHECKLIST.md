# Regulatory Configuration Checklist

The database/application architecture is complete without fabricating legal values. Before a service is moved from `DRAFT` to active/published status, the responsible DLF/legal/domain owner must verify and configure the applicable items below.

## Per service / legal instrument

- Official legal instrument number, title, issuing authority, issue/effective dates and source.
- Competent authority and delegation level for review, approval, signature, suspension, revocation and appeal.
- Applicant eligibility and regulated subject types.
- Required documents and document validity rules.
- Application/renewal/variation/appeal workflow steps.
- Statutory or management SLA, including working-day calendar where applicable.
- Fees/payment rules and official collection mechanism where applicable.
- Inspection requirement, checklist version, sampling conditions and follow-up rules.
- Laboratory test/method/acceptance requirements where applicable.
- Licence/registration/certificate validity periods where legally specified.
- Renewal windows, amendment/variation conditions and late/expiry treatment.
- Enforcement measures, severity/violation mapping, appeal/review rules and competent authority.
- Official certificate/licence/permit wording, numbering, signatory/seal and verification policy.
- Public vs internal/confidential data exposure.
- Retention/archive/disposal requirements.

## Domain-specific verification still required

### Veterinary products / feed
Product classes, dossier requirements, GMP/quality evidence, labeling rules, formulation/variation requirements, batch/QC obligations, withdrawal/storage rules, market surveillance and recall authority.

### Facilities / factories / professional services
Facility-specific establishment conditions, site/plan approvals, pre-opening inspection requirements, operating licence scopes, responsible technical-person qualifications and facility-specific renewal/closure rules.

### Animal health
Official notifiable disease lists, case definitions, disease-specific surveillance protocols, movement restrictions/zoning/control measures, vaccination policy and competent outbreak-declaration authority.

### Laboratory / AMR
Approved methods, test interpretation standards, validation/approval authority, quality-system rules, reference breakpoints and reporting obligations.

### Trade / border / e-Certificate
Commodity/document requirements, permit conditions, border routes/checkpoints, quarantine/testing rules, destination-country certificate profiles and official external interface agreements.

### Fisheries / aquaculture
Facility/production authorizations, aquatic disease requirements, movement/import/export rules and fisheries-specific conservation/compliance rules.

## Publishing rule

A configuration item with unresolved legal basis must remain `DRAFT`, `PENDING`, or equivalent and must not silently become a production regulatory rule through code defaults.
