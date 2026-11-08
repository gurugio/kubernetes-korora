#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"
action="${1:-help}"
test "$#" -eq 0 || shift
case "$action" in
  render)
    korora_chapter "${1:?장 번호가 필요합니다}"
    kustomize build "$KORORA_CHAPTER_DIR"
    ;;
  k)
    korora_local_guard
    korora_k "$@"
    ;;
  apply|fault)
    korora_local_guard
    korora_chapter "${1:?장 번호가 필요합니다}"
    current="$(cat "$KORORA_ROOT/.local/current-chapter" 2>/dev/null || printf '00')"
    if test "$num" -lt "$current"; then
      echo "낮은 장으로 되돌리면 뒤 장의 리소스가 남습니다. 같은 장을 복구하거나 별도 실습 클러스터에서 시작하세요." >&2
      exit 1
    fi
    selected="$KORORA_CHAPTER_DIR"
    if test "$action" = fault; then
      test "$num" -eq "$current" || { echo "먼저 같은 장의 정상 구성을 적용하세요." >&2; exit 1; }
      scenario="${2:?시나리오 이름이 필요합니다}"
      case "$scenario" in *[!a-z0-9-]*|'') echo "잘못된 시나리오 이름" >&2; exit 1;; esac
      selected="$KORORA_ROOT/faults/$(basename "$KORORA_CHAPTER_DIR")/$scenario"
      test -f "$selected/kustomization.yaml" || { echo "없는 시나리오: $scenario" >&2; exit 1; }
    fi
    kustomize build "$selected" > "$KORORA_ROOT/.local/current.yaml"
    korora_k apply -f "$KORORA_ROOT/.local/current.yaml"
    if test "$action" = fault; then
      echo "고장 주입 완료. 복구: ./scripts/korora.sh apply $num"
      exit 0
    fi
    printf '%s\n' "$num" > "$KORORA_ROOT/.local/current-chapter"
    if test "$num" -ge 10; then korora_k rollout status statefulset/postgres --timeout=300s; fi
    if test "$num" -ge 11; then korora_k wait --for=condition=complete job/korora-schema-v1 --timeout=300s; fi
    for deployment in $(korora_k get deployment -o jsonpath='{.items[*].metadata.name}'); do
      korora_k rollout status "deployment/$deployment" --timeout=300s
    done
    echo "$num 장 정상 구성 적용 완료"
    ;;
  *)
    echo "사용법: $0 render NN | apply NN | fault NN NAME | k KUBECTL_ARGS..."
    ;;
esac
