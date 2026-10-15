# LVSP — Lao Veterinary Services Platform

ສະບັບນີ້ແມ່ນ **Development/Pilot Build 01–08** ທີ່ສ້າງຕໍ່ຈາກ LVSP Blueprint ແລະ Physical Database Specification.

## ລອງໃຊ້ໂດຍບໍ່ເສຍເງິນ

Mac: double-click `START_LVSP_LOCAL.command`.

ເປີດ browser: `http://localhost:8787`

Local login:
- Username: `admin`
- Password: `lvsp-demo-change-me`

ຂໍ້ມູນ local ຢູ່ `apps/api/runtime/lvsp-data.json`.

## ຕໍ່ Neon Free/Staging

Mac: double-click `SETUP_NEON_FREE.command`, ຈາກນັ້ນ `START_LVSP_NEON.command`.

ອ່ານລາຍລະອຽດ: `docs/16_NEON_FREE_STAGING_GUIDE_LO.md`.

## ກວດລະບົບ

```bash
npm test
python3 scripts/validate_package.py
```

## ສະຖານະ

Build 01–08 ຖືກສ້າງໃນລະດັບ development/pilot ແລະຜ່ານ local automated test gates. Production ຍັງຕ້ອງມີ persistent Neon, official OIDC/SSO, legal/reference configuration, external government integrations, UAT, security/performance review ແລະ deployment approval.
