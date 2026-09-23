#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

NODE="${NODE:-diegofnunesbr@192.168.0.4}"
KCTL="kubectl --context=Default"
SEALED=secrets/jenkins-admin-secret.sealed.yaml

read -rsp "Nova senha do admin do Jenkins: " PW; echo
read -rsp "Confirme a senha: " PW2; echo
[ -n "$PW" ] && [ "$PW" = "$PW2" ] || { echo "Senhas vazias ou diferentes."; exit 1; }

git pull --ff-only

CERT=$(mktemp)
trap 'rm -f "$CERT"' EXIT
ssh "$NODE" "kubeseal --fetch-cert --controller-name sealed-secrets --controller-namespace kube-system" > "$CERT"

cat <<EOF | kubeseal --cert "$CERT" --scope cluster-wide --format yaml > "$SEALED"
apiVersion: v1
kind: Secret
metadata:
  name: jenkins-admin-secret
  namespace: jenkins
type: Opaque
data:
  jenkins-admin-user: $(printf '%s' admin | base64 -w0)
  jenkins-admin-password: $(printf '%s' "$PW" | base64 -w0)
EOF

git add "$SEALED"
git commit -m "rotate jenkins admin password"
git push

REV=$(git rev-parse HEAD)
ssh "$NODE" "$KCTL -n argocd annotate application jenkins argocd.argoproj.io/refresh=hard --overwrite" >/dev/null
echo "Aguardando o Argo CD sincronizar $REV..."
for _ in $(seq 1 60); do
  STATUS=$(ssh "$NODE" "$KCTL -n argocd get application jenkins -o jsonpath='{.status.sync.status} {.status.sync.revisions}'")
  [[ "$STATUS" == Synced*"$REV"* ]] && break
  sleep 5
done
[[ "$STATUS" == Synced*"$REV"* ]] || { echo "Timeout esperando o sync. Rode o restart manualmente depois."; exit 1; }

sleep 5
ssh "$NODE" "$KCTL -n jenkins rollout restart statefulset/jenkins && $KCTL -n jenkins rollout status statefulset/jenkins --timeout=600s"
echo "Pronto. Login: admin + senha nova em https://jenkins.diegofnunesbr.com"
