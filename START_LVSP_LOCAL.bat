@echo off
cd /d %~dp0
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js 22 or newer is required.
  pause
  exit /b 1
)
if not exist apps\api\runtime\lvsp-data.json node scripts\seed_demo.mjs
set LVSP_STORAGE=json
set AUTH_MODE=local
set LVSP_AUTH_SECRET=lvsp-local-development-secret
set LVSP_BOOTSTRAP_ADMIN_USER=admin
set LVSP_BOOTSTRAP_ADMIN_PASSWORD=lvsp-demo-change-me
set PORT=8787
echo LVSP local development: http://localhost:8787
echo Username: admin
echo Password: lvsp-demo-change-me
node apps\api\dist\server.js
pause
