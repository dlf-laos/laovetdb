# LVSP v1.11 — National e-Cert & Verification Foundation

This phase upgrades LVSP toward a national veterinary regulatory data + e-certificate platform.

Principles: structured-data-first; public-safe verification; acknowledgement lifecycle; replacement/rejection/cancellation; central/province/district/checkpoint scope; paper fallback; UN/CEFACT e-CERT-ready JSON/XML fields; G2G/API readiness; legal issuing authority remains configurable and is not hard-coded.

Migration 000850 adds schema `certification` with: ecert_document, ecert_status_history, ecert_acknowledgement, ecert_exchange_message, ecert_verification_event, ecert_module_policy, public verification/exchange views, and verify_public_ecert(text).

`/verify.html` is a transition page. Before API wiring it uses the existing safe `/api/v1/public/search` endpoint. Existing LVSP records remain authoritative until each module is mapped and approved.

