# DT5–DT8 Controlled Migration and Internal Rollout

## Decision and scope

Phase 3.9.1 is accepted at application revision
`f1ba18854af2a2a965090af41eb8bfc40a637cb1`. Further UI development may resume
later from that checkpoint. The next product objective is to migrate the seven
DT schemas and prove the application on Kubernetes without inventing a public
hostname or bypassing the existing runbook.

The first exposure is **internal only**:

- Backoffice uses a localhost `kubectl port-forward`;
- the physical Android app keeps its existing local API URL and reaches the DT
  API Gateway through `adb reverse`;
- public DNS, TLS certificates and Ingress are a later explicit phase.

## Immutable execution order

| Gate | Mutation | Required proof | Failure behavior |
|---|---|---|---|
| Source/Jenkins | New secure-login image revision | GitHub gate, Sonar, Trivy, SBOM, nine Harbor digests and GitOps read-back | Stop before DB |
| DT5 | Encrypted snapshot only | Seven schemas, binlog coordinates, SHA-256, isolated networkless restore and matching inventory | Stop before migration |
| DT6 canary | `content_db` migrations | Exact rendered image, `backoffLimit: 0`, completion, expected migration count and checksum column | Stop before ArgoCD |
| DT7 | Exact-revision ArgoCD sync | Manual confirmation tied to GitOps SHA; operation Succeeded, Synced and Healthy | Stop; retain Argo evidence |
| DT8 | Initial admin and acceptance | Nine Ready deployments, Vault boundary, seven migration inventories, API login, Backoffice and Android review | Do not claim deployed |

The content canary and ArgoCD sync use separate confirmations. An earlier broad
approval never substitutes for either exact target.

## Recovery design

`scripts/run-zabisa-dt5-backup-restore.sh`:

1. reads the existing mode-`0600` operator environment and password file;
2. requires MySQL `VERIFY_CA` and enabled binary logging;
3. creates a consistent dump of only the seven Zabisa schemas;
4. encrypts it with AES-256-CBC/PBKDF2 and records byte size/SHA-256;
5. restores it into an ephemeral MySQL container with `--network none`;
6. compares database, table and migration inventories;
7. removes the isolated restore container and retains the encrypted archive and
   sanitized evidence.

The backup passphrase lives at
`~/.config/zabisa/dt-backup-passphrase` by default and must be copied to the
approved independent secret store. It never enters Git or logs.

## Migration and GitOps design

`scripts/run-zabisa-dt5-dt8-rollout.sh` accepts only three known DB states:

- completely empty;
- content-canary-only;
- fully migrated with every expected checksum row.

Any partial or ambiguous state stops the run. This also makes a safe resume
possible after a terminal or post-canary failure without blindly rerunning
earlier mutations.

The exact GitOps commit is passed in the ArgoCD operation request. Automatic
sync and pruning remain disabled. PreSync waves remain:

1. content `-70`;
2. identity `-60`;
3. student `-50`;
4. tahfidz `-40`;
5. academic `-30`;
6. donation `-20`;
7. notification `-10`.

## Initial administrator

The DT environment never runs local development seeds. The one-time bootstrap:

- prompts on `/dev/tty` for email, display name and a strong password;
- hashes the password with the application Argon2id implementation;
- refuses to run when an active SUPER_ADMIN already exists;
- inserts the account and a bootstrap audit event in one transaction;
- writes the operator copy only to mode-`0600` files under
  `~/.config/zabisa/` for immediate acceptance;
- never prints the credential or stores it in Git.

The production Backoffice login form starts empty and contains no demo email,
password or seed hint.

## Execution

Plan-only:

```bash
./scripts/run-zabisa-dt5-dt8-rollout.sh --plan
```

The packaged installer performs source validation, commit/push, GitHub Quality
Gate, controlled Jenkins publication and GitOps read-back before invoking live
rollout. During live execution the operator must enter the exact canary, sync
and final acceptance confirmations shown on screen.

## Post-deploy internal access

For a later development/acceptance session with one authorized Android device:

```bash
./scripts/open-zabisa-dt-internal-access.sh
```

This exposes Backoffice at `http://127.0.0.1:13001/login` and maps the mobile
app's device port `8088` to the DT API Gateway. Pressing Enter removes both
port-forwards and the ADB reverse mapping.

## Evidence and completion rule

Live evidence is written below
`~/Downloads/zabisa-dt58-evidence-<UTC timestamp>/`. It contains no credentials.
DT5–DT8 may be marked complete only when `RESULT.env` says `status=PASS` and
records matching application, GitOps and ArgoCD revisions. Until then, the
correct status is **READY FOR CONTROLLED EXECUTION**, not deployed.

## Rollback boundary

- Before ArgoCD sync: no application workloads are changed; stop and inspect.
- After content canary: its migration is forward-only and idempotently tracked;
  use the tested DT5 recovery point only under a separate restore incident
  approval.
- After sync: rollback means syncing a reviewed earlier GitOps revision whose
  schema compatibility is explicitly proven. Never downgrade schema by merely
  changing an image tag.
- Restoring DT, deleting data, rotating credentials or pruning Argo resources is
  not authorized by this runbook.
