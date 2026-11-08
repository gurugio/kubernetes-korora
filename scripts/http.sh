#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"
request_path="${1:-/}"
test "$#" -eq 0 || shift
case "$request_path" in /*) ;; *) echo "경로는 /로 시작해야 합니다." >&2; exit 1;; esac
exec curl --noproxy '*' --silent --show-error --connect-timeout 3 --max-time 15 \
  --cacert "$KORORA_ROOT/components/ingress/tls.crt" \
  --resolve korora.test:8443:127.0.0.1 "$@" "https://korora.test:8443$request_path"
