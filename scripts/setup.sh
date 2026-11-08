#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"
PATH="$KORORA_ROOT/.local/bin:$PATH"
export PATH
for tool in docker k3d kubectl kustomize; do command -v "$tool" >/dev/null || { echo "$tool 설치가 필요합니다." >&2; exit 1; }; done
docker_context="${KORORA_DOCKER_CONTEXT:-$(docker context show)}"
docker_endpoint="$(docker context inspect "$docker_context" --format '{{.Endpoints.docker.Host}}')"
case "$docker_endpoint" in unix://*) ;; *) echo "로컬 Docker unix socket만 허용합니다." >&2; exit 1;; esac
export DOCKER_HOST="$docker_endpoint"
docker info >/dev/null
mkdir -p "$KORORA_ROOT/.local"
if ! k3d cluster get korora >/dev/null 2>&1; then
  k3d cluster create --config "$KORORA_ROOT/chapters/02-local-cluster/k3d.yaml" --wait
fi
k3d kubeconfig get korora > "$KORORA_KUBECONFIG"
chmod 600 "$KORORA_KUBECONFIG"
korora_local_guard
korora_k get nodes
echo "준비 완료. ./scripts/korora.sh apply 03 또는 apply 16"
