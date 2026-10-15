#!/usr/bin/env python3
import json
from pathlib import Path
p = Path(__file__).resolve().parents[1] / 'IMPLEMENTATION_STATE.json'
s = json.loads(p.read_text())
for i in range(1, 9):
    st = s.get('packs', {}).get(str(i), 'not_started')
    if st != 'complete':
        print(f'NEXT: Pack {i:02d} ({st})')
        break
else:
    print('NEXT: final release-hardening / staging-UAT-production gates')
