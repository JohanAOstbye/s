#!/usr/bin/env bash
# Restarts workloads on tosl-k8s-poc-002 after the service-account-issuer change (t.sh).
#
# Usage:
#   curl -sL raw.githubusercontent.com/JohanAOstbye/s/main/r.sh | bash
set -euo pipefail

NAMESPACES="${NAMESPACES:-azure-arc kube-system arc-workload-identity kubelet-serving-cert-approver}"

KC=$(mktemp)
trap 'rm -f "$KC"' EXIT
talosctl -n 10.97.124.229 kubeconfig "$KC" --force
export KUBECONFIG="$KC"

echo "== service-account-issuer per apiserver"
for p in $(kubectl -n kube-system get pods -o name | grep kube-apiserver); do
  echo "$p $(kubectl -n kube-system get "$p" -o yaml | grep -o 'service-account-issuer=[^"]*')"
done

for ns in $NAMESPACES; do
  echo "== restart $ns"
  kubectl -n "$ns" rollout restart deploy,ds 2>&1 || true
done

for ns in $NAMESPACES; do
  echo "== wait $ns"
  for r in $(kubectl -n "$ns" get deploy,ds -o name); do
    kubectl -n "$ns" rollout status "$r" --timeout=300s || true
  done
done

echo "== pods not Running/Completed"
kubectl get pods -A | grep -Ev "Running|Completed" || echo "none"
