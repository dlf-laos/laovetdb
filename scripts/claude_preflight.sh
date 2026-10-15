#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
python scripts/validate_package.py
bash -n scripts/run_all_migrations.sh
bash -n scripts/run_all_seeds.sh
bash -n scripts/run_post_deploy_checks.sh
python -c "import json; json.load(open('IMPLEMENTATION_STATE.json')); print('IMPLEMENTATION_STATE.json: OK')"
echo "LVSP Claude handoff preflight: PASSED"
