#!/usr/bin/env bash
set -euo pipefail
ROOT=${1:-apps/admin-web}
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re, sys
root=Path(sys.argv[1])
violations=[]
for base in ('app','components','lib'):
    d=root/base
    if not d.exists(): continue
    for p in d.rglob('*'):
        if p.suffix not in {'.ts','.tsx'}: continue
        text=p.read_text(errors='ignore')
        if p.name != 'session.ts':
            if re.search(r'queryKey\s*:\s*\[\s*["\']auth["\']\s*,\s*["\']session["\']\s*\]', text):
                violations.append(str(p))
if violations:
    print('FAIL conflicting auth/session TanStack Query key outside lib/session.ts:')
    for v in violations: print(' -',v)
    raise SystemExit(1)
required=[root/'lib/session.ts', root/'components/AppShell.tsx', root/'app/(protected)/access/page.tsx']
for p in required:
    if not p.exists(): raise SystemExit(f'FAIL missing {p}')
if 'useSessionUser' not in (root/'components/AppShell.tsx').read_text():
    raise SystemExit('FAIL AppShell must use centralized useSessionUser')
if 'useSessionUser' not in (root/'app/(protected)/access/page.tsx').read_text():
    raise SystemExit('FAIL User & Access must use centralized useSessionUser')
print('PASS centralized auth/session query cache shape')
PY
