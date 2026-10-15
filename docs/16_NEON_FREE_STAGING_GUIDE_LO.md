# LVSP — Neon Free/Staging ວິທີເລີ່ມທີ່ງ່າຍສຸດ

## ທາງເລືອກ A — ລອງຟຣີກ່ອນ

ສຳລັບ Mac ໃຫ້ double-click `SETUP_NEON_FREE.command`.

Script ຈະ:
1. ກວດ Node.js.
2. ຕິດຕັ້ງ dependencies.
3. ສ້າງ Neon New/Claimable PostgreSQL staging database.
4. ຂຽນ pooled/direct connection strings ໃສ່ `.env.neon`.
5. ສ້າງ staging login secret ແລະ password.
6. ລັນ migrations 000001–000680.
7. ລັນ seed data.
8. ກວດ database connection/table count.

Neon New database ທີ່ຍັງບໍ່ claim ເປັນ temporary. ເປີດ Claim URL ທີ່ script ສະແດງເພື່ອນຳໄປເກັບໃນ Neon account ຂອງທ່ານ.

ຫຼັງ setup ໃຫ້ double-click `START_LVSP_NEON.command`, ແລ້ວເປີດ `http://localhost:8787`.

## ທາງເລືອກ B — ມີ Neon project ຢູ່ແລ້ວ

Copy `.env.example` ເປັນ `.env.neon` ແລ້ວໃສ່:
- `DATABASE_URL` = pooled connection string
- `DATABASE_URL_DIRECT` = direct connection string
- `LVSP_STORAGE=postgres`
- `AUTH_MODE=local` ສຳລັບ staging ເທົ່ານັ້ນ

ຈາກນັ້ນ:

```bash
npm install
node --env-file=.env.neon scripts/db-migrate.mjs
node --env-file=.env.neon scripts/db-seed.mjs
node --env-file=.env.neon scripts/db-check.mjs
npm run build
node --env-file=.env.neon apps/api/dist/server.js
```

## ຄວາມປອດໄພ

- `.env.neon` ຖືກ ignore ຈາກ Git.
- Local/staging authentication ແມ່ນສຳລັບ development/pilot; Production ຕ້ອງປ່ຽນເປັນ OIDC/SSO.
- ຫ້າມໃສ່ production passwords/connection strings ໃນ source code.
