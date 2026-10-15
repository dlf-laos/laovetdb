# Final Migration Manifest

## Wave 1 — Platform foundation

- 000001_extensions.sql
- 000002_schemas.sql
- 000003_common_functions.sql
- 000010_system_numbering.sql
- 000011_system_legal.sql
- 000012_system_services.sql
- 000020_lookup_country.sql
- 000021_lookup_admin_unit_type.sql
- 000022_lookup_species.sql
- 000023_lookup_facility_type.sql

## Wave 2 — Enterprise master registries

- 000030_master_geography.sql
- 000031_master_party.sql
- 000032_master_person.sql
- 000033_master_company.sql
- 000034_master_party_roles.sql
- 000035_master_organization.sql
- 000036_master_facility.sql
- 000037_master_facility_components.sql

## Wave 3 — IAM, workflow, document, case, registration, licensing

- 000040_security_users.sql
- 000041_security_roles_permissions.sql
- 000042_security_scope_delegation.sql
- 000050_workflow_definition.sql
- 000051_workflow_runtime.sql
- 000060_document_storage.sql
- 000061_document_templates.sql
- 000070_audit.sql
- 000080_integration_outbox_inbox.sql
- 000100_casework.sql
- 000110_registration.sql
- 000120_licensing.sql
- 000130_certificate_foundation.sql

## Wave 4 — Facility, product, feed

- 000140_facility_establishment.sql
- 000141_factory_profile.sql
- 000142_production_line.sql
- 000143_gmp.sql
- 000150_product_reference.sql
- 000151_product_master.sql
- 000152_product_versions.sql
- 000153_product_composition.sql
- 000154_product_packages.sql
- 000155_product_labels.sql
- 000156_product_manufacturers.sql
- 000157_product_registration_packages.sql
- 000158_product_batch.sql
- 000170_feed_profile_formula.sql
- 000171_feed_raw_material_traceability.sql

## Wave 5 — Inspection, compliance, enforcement, LIMS

- 000200_inspection_program.sql
- 000201_inspection_checklist.sql
- 000202_inspection_runtime.sql
- 000203_inspection_evidence_findings.sql
- 000220_compliance.sql
- 000230_enforcement.sql
- 000240_laboratory_profile.sql
- 000241_laboratory_sample_custody.sql
- 000243_laboratory_test_method.sql
- 000244_laboratory_work_order.sql
- 000246_laboratory_result.sql
- 000248_laboratory_equipment_quality.sql

## Wave 6 — Farm, animal, movement, disease

- 000300_species_breed.sql
- 000310_farm.sql
- 000320_animal_identity.sql
- 000323_animal_history.sql
- 000330_movement.sql
- 000340_animal_lifecycle_event.sql
- 000400_disease_catalog.sql
- 000401_surveillance.sql
- 000410_disease_case_investigation.sql
- 000420_outbreak_zone_control.sql
- 000430_vaccination.sql
- 000440_emergency.sql
- 000450_amr.sql

## Wave 7 — Trade, border, fisheries

- 000500_trade_operator_permit.sql
- 000510_shipment.sql
- 000513_border_declaration.sql
- 000520_trade_risk.sql
- 000521_border_inspection.sql
- 000522_quarantine_clearance.sql
- 000530_trade_health_certificate.sql
- 000531_ecertificate.sql
- 000550_aquaculture.sql
- 000552_aquatic_stock_production.sql

## Wave 8 — Platform hardening

- 000600_integration_registry.sql
- 000610_notifications.sql
- 000620_gis_layer_registry.sql
- 000630_analytics_kpi.sql
- 000640_scheduler.sql
- 000650_data_quality.sql
- 000660_retention_archive.sql
- 000670_reporting_views.sql
- 000680_final_indexes.sql

## Wave 9 — Priority operational veterinary services

- 000700_priority_veterinary_products_trade.sql
- 000710_priority_veterinary_products_complete.sql
- 000720_legacy_trade_print_animuse.sql
- 000730_company_master_multisite.sql

## Wave 10 – Cumulative v1.0–v1.2 additions

- 000740_guided_services_workflow.sql
- 000750_pwa_admin_field_foundation.sql
- 000760_provincial_reporting_consolidation.sql
- 000770_vet_drug_reference_automation.sql
- 000780_annual_import_plan_operational.sql





## Wave 11 — Current additive operational migrations

- 000790_flexible_annual_import_plan.sql
- 000800_vet_drug_registration_operational.sql
- 000810_legacy_registration_trade_parity.sql

## Wave 12 — Online access and operational extensions

- 000820_online_auth_public_access.sql
- 000830_national_access_foundation.sql
- 000840_import_plan_analytics.sql
- 000850_national_ecert_verification_foundation.sql
- 000860_annual_trade_plan_ecert_bridge.sql
- 000870_batch_ops_botanical_hs_codes.sql
- 000880_export_pathway_foundation.sql
- 000890_export_reference_data_seed.sql
- 000900_tr2001_service_registration.sql
- 000910_vetdrug_combined_herbal_amr.sql
- 000920_trade_permit_report_validity_columns.sql

## Department operations

- 000930_department_operations.sql

## Document intake pilot

- 000940_document_intake_pilot.sql

## Migration policy

Applied migrations are immutable. Corrections are new migrations. Official/legal records use `ON DELETE RESTRICT` by default. `CASCADE` is limited to truly dependent configuration/junction records.
