# Temporary canary policy only. It is created and deleted by run-vault-canary.sh.
path "kv/data/zabisa/dt/canary" {
  capabilities = ["read"]
}
