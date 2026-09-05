#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[[ "${1:-}" == '--run' && -n "${2:-}" ]] || {
  echo 'usage: record-dt58-completion.sh --run EVIDENCE_DIR' >&2
  exit 64
}
evidence_dir="$2"
result="$evidence_dir/RESULT.env"
[[ -r "$result" ]] || { echo "ERROR: missing $result" >&2; exit 1; }
[[ -z "$(git status --porcelain=v1)" ]] || { echo 'ERROR: repository must be clean before recording completion' >&2; exit 1; }

python3 - "$result" "$evidence_dir" <<'PY'
from pathlib import Path
import re
import sys

result_path = Path(sys.argv[1])
evidence_dir = sys.argv[2]
values = {}
for line in result_path.read_text(encoding="utf-8").splitlines():
    key, separator, value = line.partition("=")
    if separator:
        values[key] = value

required = {
    "status",
    "finished_at",
    "application_revision",
    "gitops_revision",
    "argocd_revision",
    "namespace",
    "exposure",
}
missing = required - values.keys()
if missing:
    raise SystemExit(f"missing result keys: {sorted(missing)}")
if values["status"] != "PASS":
    raise SystemExit("DT5-DT8 result is not PASS")
for key in ("application_revision", "gitops_revision", "argocd_revision"):
    if not re.fullmatch(r"[0-9a-f]{40}", values[key]):
        raise SystemExit(f"invalid {key}")
if values["gitops_revision"] != values["argocd_revision"]:
    raise SystemExit("GitOps and ArgoCD revisions differ")

app = values["application_revision"]
gitops = values["gitops_revision"]
finished = values["finished_at"]

evidence = Path("docs/deployment/PHASE-DT5-DT8-LIVE-EVIDENCE.md")
evidence.write_text(
    f"""# DT5–DT8 Live Completion Evidence

Status: **PASS**

| Evidence | Value |
|---|---|
| Finished (UTC) | `{finished}` |
| Application/image revision | `{app}` |
| GitOps revision | `{gitops}` |
| ArgoCD synced revision | `{gitops}` |
| Namespace | `zabisa-app` |
| Exposure | Internal port-forward / ADB reverse only |
| Local evidence directory | `{evidence_dir}` |

The controlled run proved an encrypted seven-schema backup, MySQL binary-log
coordinates, network-isolated restore, runtime/migrator credential canaries,
the content-only migration canary, every expected migration checksum, an exact
GitOps-revision ArgoCD sync, nine Ready workloads, the reviewed Vault boundary,
SUPER_ADMIN API login, Backoffice rendering and physical Android acceptance.

No public DNS, TLS certificate or Ingress was configured. No database restore,
credential rotation, ArgoCD prune or schema downgrade was performed.
""",
    encoding="utf-8",
)

def replace(path, old, new):
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one occurrence, found {count}: {old!r}")
    file.write_text(text.replace(old, new), encoding="utf-8")

replace(
    "docs/deployment/CURRENT-STATE-AND-ROADMAP.md",
    "**PHASE 3.9.1 COMPLETE / DT5-DT8 READY FOR CONTROLLED EXECUTION**",
    "**DT5-DT8 COMPLETE / INTERNALLY DEPLOYED**",
)
replace(
    "docs/deployment/CURRENT-STATE-AND-ROADMAP.md",
    "| Backup and isolated restore proof | NOT PROVEN | Mandatory before any database mutation |",
    f"| Backup and isolated restore proof | PASS | Encrypted recovery point and isolated restore verified at `{finished}` |",
)
replace(
    "docs/deployment/CURRENT-STATE-AND-ROADMAP.md",
    "| Cluster Harbor pull | UNPROVEN | First content canary and ArgoCD rollout will prove public-project pull from each rendered image |",
    "| Cluster Harbor pull | PASS | Content canary and all nine Ready workloads proved worker image pulls |",
)
replace(
    "docs/deployment/CURRENT-STATE-AND-ROADMAP.md",
    "| Database migration | NOT RUN | Blocked by image, backup/restore and operator approval gates |",
    "| Database migration | PASS | Content canary and all seven checksum inventories verified |",
)
replace(
    "docs/deployment/CURRENT-STATE-AND-ROADMAP.md",
    "| Application deployment | NOT DEPLOYED | Blocked until migration and render gates pass |",
    f"| Application deployment | PASS / INTERNAL | Nine Ready workloads at `{app[:12]}` |",
)
replace(
    "docs/deployment/CURRENT-STATE-AND-ROADMAP.md",
    "| ArgoCD sync | NOT RUN | Automated sync disabled; explicit operator approval required |",
    f"| ArgoCD sync | PASS / MANUAL | Exact GitOps revision `{gitops[:12]}` synced; automation remains disabled |",
)
for before in (
    "Status: **READY FOR CONTROLLED EXECUTION / EVIDENCE REQUIRED**",
    "Status: **READY AFTER DT5 PASS / EXACT OPERATOR APPROVAL REQUIRED**",
    "Status: **READY AFTER DT6 CANARY / EXACT OPERATOR APPROVAL REQUIRED**",
    "Status: **READY AFTER DT7 / INTERNAL-FIRST ACCEPTANCE**",
):
    replace("docs/deployment/CURRENT-STATE-AND-ROADMAP.md", before, "Status: **COMPLETE / LIVE EVIDENCE RECORDED**")
for before, after in (
    ("Cluster image pull: NOT PROVEN", "Cluster image pull: PASS through content canary and full rollout"),
    ("Migration: NOT RUN", "Migration: PASS; seven checksum inventories verified"),
    ("Application: NOT DEPLOYED", f"Application: PASS / internal at {app[:12]}"),
    ("ArgoCD sync: NOT RUN", f"ArgoCD sync: PASS / manual at {gitops[:12]}"),
):
    replace("docs/deployment/CURRENT-STATE-AND-ROADMAP.md", before, after)

replace(
    "docs/PROJECT_STATE.md",
    "# Project State — Phase 3.9.1 Complete / DT5–DT8 Ready",
    "# Project State — DT5–DT8 Complete / Internally Deployed",
)
replace(
    "docs/PROJECT_STATE.md",
    "Not run:\n\n- worker/containerd image-pull proof;\n- database backup/isolated restore drill or migration;\n- application Deployment or ArgoCD sync.",
    f"Live DT5–DT8 proof:\n\n- encrypted backup and network-isolated restore: PASS;\n- content canary and all seven migration checksum inventories: PASS;\n- ArgoCD exact revision `{gitops[:12]}`: Succeeded, Synced and Healthy;\n- nine application Deployments: Ready;\n- internal API, Backoffice and physical Android acceptance: PASS.",
)
replace(
    "docs/INDEX.md",
    "**Next deployment checkpoint:** DT5–DT8 — controlled migration and internal rollout",
    f"**Current deployment checkpoint:** DT5–DT8 COMPLETE — `{app[:12]}` internally deployed",
)
replace(
    "docs/KNOWN_LIMITATIONS.md",
    "DT5–DT8 source controls are ready, but cluster image pulling,\ndatabase migration, deployment and ArgoCD reconciliation remain unproven until\nthe controlled run produces `RESULT.env` with `status=PASS`.",
    "DT5–DT8 internally proved cluster image pulling, database migration,\ndeployment and exact-revision ArgoCD reconciliation. Public DNS/TLS/Ingress,\nHA and production release operations remain separate future gates.",
)
replace(
    "docs/NEXT_SESSION_START_HERE.md",
    "**DT5–DT8 — controlled migration and internal rollout**",
    "**DT5–DT8 COMPLETE — internal deployment and acceptance**",
)

for path in ("docs/PROJECT_STATE.md", "docs/NEXT_SESSION_START_HERE.md", "docs/PHASE_HISTORY.md"):
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    text += f"""

## DT5–DT8 live completion — {finished}

Application/image revision `{app}` and GitOps/ArgoCD revision `{gitops}` passed
the encrypted recovery drill, controlled migrations and internal Backoffice/API/
Android acceptance. See `docs/deployment/PHASE-DT5-DT8-LIVE-EVIDENCE.md`.
Public DNS/TLS/Ingress remains a separate future phase.
"""
    file.write_text(text, encoding="utf-8")

index = Path("docs/INDEX.md")
text = index.read_text(encoding="utf-8")
anchor = "| `deployment/PHASE-DT5-DT8-CONTROLLED-ROLLOUT.md` | Encrypted recovery proof, canary migration, exact ArgoCD sync, secure admin and internal acceptance |"
entry = "| `deployment/PHASE-DT5-DT8-LIVE-EVIDENCE.md` | Sanitized revisions and proof recorded by the successful live rollout |"
if entry not in text:
    text = text.replace(anchor, anchor + "\n" + entry)
index.write_text(text, encoding="utf-8")
PY

./scripts/verify-dt58-source.sh
git diff --check
echo '[dt58-docs] PASS: live completion evidence and handoff documentation updated.'
