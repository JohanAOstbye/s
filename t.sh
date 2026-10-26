#!/usr/bin/env bash
# Sets kube-apiserver service-account-issuer to the Arc OIDC issuer on tosl-k8s-poc-002 control-plane nodes.
#
# Usage:
#   curl -sL raw.githubusercontent.com/JohanAOstbye/s/main/t.sh | bash -s -- --dry-run
#   curl -sL raw.githubusercontent.com/JohanAOstbye/s/main/t.sh | bash
#   curl -sL raw.githubusercontent.com/JohanAOstbye/s/main/t.sh | NODES="10.97.124.230" bash
#
# Afterwards restart pods using SA tokens (old issuer tokens are rejected):
#   for ns in kube-system azure-arc arc-workload-identity kubelet-serving-cert-approver; do
#     kubectl -n $ns rollout restart deploy,ds
#   done
set -euo pipefail

NODES="${NODES:-10.97.124.229 10.97.124.230 10.97.124.231}"
DRY=""
[ "${1:-}" = "--dry-run" ] && DRY="--dry-run"

PATCH=$(mktemp)
cat > "$PATCH" <<'EOF'
cluster:
  apiServer:
    extraArgs:
      service-account-issuer: https://europe.oic.prod-arc.azure.com/54475f80-1baa-4ea9-9185-c0de5cc603fe/0ee37886-a3bd-491d-8e89-ea3eebc59589/
      service-account-max-token-expiration: 24h
EOF

for n in $NODES; do
  echo "== $n"
  talosctl -n "$n" patch mc --patch @"$PATCH" $DRY
  [ -n "$DRY" ] && continue
  echo "Waiting for kube-apiserver on $n..."
  sleep 60
  talosctl -n "$n" get mc -o yaml | grep -A3 "extraArgs" || true
  read -rp "Continue to next node? [enter] " </dev/tty
done

rm -f "$PATCH"
