#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Build da imagem docker.io/jenkins-homelab:local..."
docker build -t docker.io/jenkins-homelab:local "$SCRIPT_DIR"

echo "==> Importando imagem para o containerd do k0s..."
docker save docker.io/jenkins-homelab:local | sudo k0s ctr images import -

echo ""
echo "Imagem docker.io/jenkins-homelab:local disponível no cluster."
echo "Rode de novo sempre que o Dockerfile mudar (Terraform/Ansible/versões)."
