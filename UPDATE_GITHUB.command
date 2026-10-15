#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
git --version >/dev/null || { echo "Install Apple Command Line Tools, then retry."; exit 1; }
bash CHECK_RELEASE.command
printf "Path to your existing local laovetdb Git clone: "
IFS= read -r repository_path
node scripts/push-update.mjs "$repository_path"
