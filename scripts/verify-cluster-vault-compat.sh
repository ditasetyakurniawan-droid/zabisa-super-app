#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "[cluster-vault] ERROR: $*" >&2; exit 1; }
pass(){ echo "[cluster-vault] OK: $*"; }
KUBECTL_BIN="${KUBECTL:-kubectl}"
command -v "$KUBECTL_BIN" >/dev/null 2>&1 || fail 'kubectl required'

if command -v python3 >/dev/null 2>&1; then
  read -r client_minor server_minor < <("$KUBECTL_BIN" version -o json | python3 -c 'import json,sys; v=json.load(sys.stdin); print(int(v["clientVersion"]["minor"].rstrip("+")), int(v["serverVersion"]["minor"].rstrip("+")))')
  delta=$(( client_minor > server_minor ? client_minor-server_minor : server_minor-client_minor ))
  (( delta <= 1 )) || fail "unsupported kubectl/server minor skew: client=1.${client_minor}, server=1.${server_minor}; use kubectl 1.${server_minor} or adjacent minor before cluster mutation"
  pass "kubectl/server minor skew is supported (client=1.${client_minor}, server=1.${server_minor})"
fi

"$KUBECTL_BIN" get ns vault >/dev/null || fail 'vault namespace missing'
"$KUBECTL_BIN" -n vault get deploy vault-agent-injector >/dev/null || fail 'vault-agent-injector Deployment missing'
"$KUBECTL_BIN" get mutatingwebhookconfiguration vault-agent-injector-cfg >/dev/null || fail 'Vault injector webhook missing'
pass 'Vault Injector deployment + webhook exist'

ports="$("$KUBECTL_BIN" -n vault get svc vault -o jsonpath='{range .spec.ports[*]}{.port}{" "}{end}')"
[[ " $ports " == *' 8200 '* ]] || fail 'vault Service does not expose TCP/8200'
pass 'vault.vault.svc exposes 8200'

"$KUBECTL_BIN" -n kube-system get pods -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -q . || fail 'CoreDNS selector k8s-app=kube-dns not found'
pass 'CoreDNS labels match NetworkPolicy'

"$KUBECTL_BIN" -n ingress-nginx get pods -l 'app.kubernetes.io/component=controller,app.kubernetes.io/instance=ingress-nginx,app.kubernetes.io/name=ingress-nginx' --no-headers 2>/dev/null | grep -q . || fail 'ingress-nginx controller labels do not match NetworkPolicy'
pass 'ingress-nginx labels match NetworkPolicy'

"$KUBECTL_BIN" -n kube-system get ds calico-node >/dev/null 2>&1 || fail 'Calico daemonset not found'
pass 'Calico CNI detected'

echo '[cluster-vault] PASS: existing cluster topology matches Hotfix 0.3 selectors.'
