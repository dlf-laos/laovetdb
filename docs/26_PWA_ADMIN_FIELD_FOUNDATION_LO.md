# LVSP v1.0 — Installable PWA + Central Admin + Field Offline Foundation

## ເປົ້າໝາຍ

v1.0 ປ່ຽນ LVSP ຈາກການເບິ່ງເປັນ “website ຢ່າງດຽວ” ໄປເປັນ platform ທີ່ມີ interface ຫຼາຍແບບແຕ່ໃຊ້ Core/API/Database ດຽວກັນ.

- Staff Web App / PWA — ຕິດຕັ້ງ icon ໃນ desktop/start menu ໄດ້, ແຕ່ update ຈາກ server ສູນກາງ.
- Field PWA — `/field/`, ເກັບ draft ໜ້າວຽກເມື່ອ offline ແລະ sync ເມື່ອ online.
- Admin Center — ສຳລັບ SYSTEM_ADMIN / SECURITY_ADMIN ເພື່ອເບິ່ງ platform, users/roles, service visibility, non-secret settings, audit ແລະ field sync.

## Central update model

ພະນັກງານບໍ່ຄວນ apply patch ໃນຄອມໃຜລາວໃນ Production. Developer/IT deploy version ໃໝ່ຂຶ້ນ server ຄັ້ງດຽວ; Web/PWA ຈະກວດພົບ version ໃໝ່ ແລະ update ຈາກ server. Local `.command` patch workflow ແມ່ນສຳລັບ Development/Staging ໃນຂັ້ນປັດຈຸບັນ.

## Security boundary

`system.platform_setting` ຖືກອອກແບບສຳລັບ non-secret configuration ເທົ່ານັ້ນ. Password, database URL, API key, OIDC secret, signing key ແລະ private key ຕ້ອງຢູ່ deployment secret manager/environment ເທົ່ານັ້ນ.

## Field data boundary

Offline field records sync ເຂົ້າ `inspection.field_capture_draft` ເປັນ staging draft. ມັນບໍ່ຖືກສ້າງເປັນ official `inspection.finding` ອັດຕະໂນມັດ. ຕ້ອງ review/link ເຂົ້າ Inspection Case ຕາມ workflow ກ່ອນ.

## Production items still required

v1.0 ບໍ່ແມ່ນ production release. ຍັງຕ້ອງມີ HTTPS/domain/hosting, OIDC/SSO, official user/role assignment, object storage, notifications, PKI/e-signature, backup/DR, security/performance testing, UAT ແລະ institutional approval.
