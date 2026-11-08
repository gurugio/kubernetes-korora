#!/bin/sh
set -eu
KORORA_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
KORORA_KUBECONFIG="$KORORA_ROOT/.local/kubeconfig"
korora_local_guard() {
  test -f "$KORORA_KUBECONFIG" || { echo "먼저 ./scripts/setup.sh를 실행하세요." >&2; exit 1; }
  context="$(kubectl --kubeconfig="$KORORA_KUBECONFIG" config current-context)"
  test "$context" = k3d-korora || { echo "실습 Context 불일치: $context" >&2; exit 1; }
  server="$(kubectl --kubeconfig="$KORORA_KUBECONFIG" --context=k3d-korora config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
  case "$server" in https://127.0.0.1:*|https://localhost:*) ;; *) echo "로컬 API 서버만 허용합니다: $server" >&2; exit 1;; esac
}
korora_k() { kubectl --kubeconfig="$KORORA_KUBECONFIG" --context=k3d-korora --namespace=korora "$@"; }
korora_chapter() {
  case "$1" in [0-9]) num="0$1";; [0-9][0-9]) num="$1";; *) echo "장 번호는 01..16입니다." >&2; exit 1;; esac
  KORORA_CHAPTER_DIR=""
  for dir in "$KORORA_ROOT"/chapters/"$num"-*; do if test -d "$dir"; then KORORA_CHAPTER_DIR="$dir"; break; fi; done
  test -n "$KORORA_CHAPTER_DIR" || { echo "없는 장: $num" >&2; exit 1; }
}
