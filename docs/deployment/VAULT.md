# Vault integration

Use existing Vault Kubernetes Auth with one role per Zabisa namespace/service. Runtime secrets include MySQL user/password, JWT signing key, internal-service key, FCM credentials, payment provider credentials, SMTP and S3 keys. Do not commit Kubernetes Secret manifests with plaintext values.

Recommended DT integration: External Secrets Operator or Vault CSI if already installed. The manifests reference a runtime Secret name, but that Secret must be materialized from Vault, not Git. Validate the existing cluster integration before applying.
