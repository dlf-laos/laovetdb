# Resume Prompts if Claude Stops Because of Context/Time

Use only the prompt matching the last completed checkpoint. Claude must first read `IMPLEMENTATION_STATE.json` and existing `PACK_*_COMPLETION_REPORT.md` files.

## Resume Step 1 — Packs 01–02
```text
Resume LVSP from the current repository state. Read CLAUDE.md and IMPLEMENTATION_STATE.json. Complete Packs 01 and 02 in order, fixing all tests before advancing. Do not redesign the frozen model. Update state and completion reports after each Pack. Continue without routine confirmation.
```

## Resume Step 2 — Packs 03–04
```text
Resume LVSP after Pack 02. Verify prior tests remain green, then implement Packs 03 and 04 in order. Preserve Facility/Product/Registration boundaries and use the shared Inspection/LIMS engines. Update state and completion reports after each Pack. Continue without routine confirmation.
```

## Resume Step 3 — Packs 05–06
```text
Resume LVSP after Pack 04. Verify regression tests, then implement Packs 05 and 06. Preserve append-oriented animal history, individual/group traceability, Case vs Outbreak separation, and service-based movement restriction checks. Update state and completion reports after each Pack.
```

## Resume Step 4 — Pack 07
```text
Resume LVSP after Pack 06. Implement Pack 07. Keep Operator, Permit, Shipment, Border Declaration, Inspection, Quarantine, Clearance and Certificate separate. Reuse Inspection, LIMS and Disease engines. Use mock/provider-neutral e-Certificate integration if partner credentials are absent. Update state and completion report.
```

## Resume Step 5 — Pack 08 + release gate
```text
Resume LVSP after Pack 07. Implement Pack 08 and run the complete release-hardening gate. Do not claim production readiness without runtime evidence. Produce FINAL_IMPLEMENTATION_REPORT.md with tests, remaining legal/external configuration, and exact staging/UAT/production steps.
```
