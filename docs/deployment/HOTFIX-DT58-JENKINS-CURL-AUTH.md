# DT5–DT8 Jenkins curl authentication hotfix

## Failure checkpoint

The first DT5–DT8 controlled delivery attempt completed source validation and
the GitHub Engineering Quality Gate. It stopped at Jenkins `whoAmI` before a
readiness or delivery build was requested:

```text
curl: (26) .netrc error: syntax error
Readiness : not-started
Delivery  : not-started
```

The Jenkins parent remained DISABLED. Kubernetes, MySQL migration and ArgoCD
sync were not requested.

## Root cause

The delivery runner wrote the operator-provided username and API token into an
unquoted netrc file. A value rejected by curl's netrc lexer caused a local parse
failure before Jenkins could authenticate it. This was not an HTTP 401/403 from
Jenkins.

## Correction

The runner now:

- requires a constrained Jenkins username and an alphanumeric API token;
- writes `user = "username:token"` to a temporary curl configuration file;
- sets that file to mode `0600`;
- passes only the temporary config path to curl;
- retains `set +x`, hidden token entry, cleanup and parent-disable traps;
- deletes the temporary directory at exit.

The API token is never committed, printed or written to the rollout evidence.

## Resume boundary

The correction is committed and must pass the GitHub Engineering Quality Gate
before Jenkins delivery is retried. The retry still performs the default-off
readiness build before the explicit build/scan/SBOM/Harbor/GitOps build. DT5
backup, DT6 migration, DT7 ArgoCD sync and DT8 acceptance remain blocked until
delivery and GitOps read-back both pass.
