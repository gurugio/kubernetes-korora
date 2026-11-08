#!/usr/bin/env python3
"""로컬 korora HTTP API, DB 권한과 미러링을 검증한다."""
import argparse
import json
from pathlib import Path
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
def k(*args):
    return subprocess.check_output([str(ROOT / "scripts/korora.sh"), "k", *args], text=True)
def request(path, method="GET", data=None, client="smoke", extra_headers=None):
    cmd = [str(ROOT / "scripts/http.sh"), path, "-X", method, "-w", "\n%{http_code}"]
    if client is not None:
        cmd += ["-H", "X-Korora-Client: " + client]
    for header in extra_headers or []:
        cmd += ["-H", header]
    if data is not None:
        cmd += ["-H", "Content-Type: application/json", "--data-binary", json.dumps(data)]
    response = subprocess.check_output(cmd, text=True)
    body, code = response.rsplit("\n", 1)
    return int(code), body
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-mirror", action="store_true")
    parser.add_argument("--restart-db", action="store_true")
    args = parser.parse_args()
    k("get", "namespace", "korora")
    assert request("/")[0] == 200
    assert request("/envoy-health", client=None)[0] == 200
    assert request("/query/measurements", client=None)[0] == 400
    assert request("/query/measurements", client="bad/value")[0] == 400
    assert request("/query/measurements", method="POST", data={})[0] == 405
    assert request("/ingest/measurements")[0] == 405
    debug_code, debug_body = request("/debug/", extra_headers=["X-Korora-Internal: forged"])
    assert debug_code == 200
    debug = json.loads(debug_body)
    assert debug["headers"]["x-korora-internal"] == "envoy", debug
    event = {"event_id": str(uuid.uuid4()), "device": "sensor-smoke", "metric": "temperature", "observed_at": "2026-01-01T00:00:00Z", "value": 22.3}
    write_trace = "write-" + uuid.uuid4().hex[:12]
    code, body = request("/ingest/measurements", method="POST", data=event, client=write_trace)
    assert code == 201, (code, body)
    assert request("/ingest/measurements", method="POST", data=event, client=write_trace)[0] == 409
    trace = "smoke-" + uuid.uuid4().hex[:12]
    path = "/query/measurements?event_id=eq." + event["event_id"]
    code, body = request(path, client=trace)
    assert code == 200, (code, body)
    rows = json.loads(body)
    assert len(rows) == 1 and rows[0]["value"] == 22.3, rows
    empty_code, empty_body = request("/query/measurements?event_id=eq." + str(uuid.uuid4()))
    assert empty_code == 200 and json.loads(empty_body) == []
    privileges = k("exec", "postgres-0", "--", "psql", "-U", "postgres", "-d", "korora", "-Atc",
        "SELECT has_table_privilege('korora_writer','api.measurements','INSERT'), has_table_privilege('korora_writer','api.measurements','SELECT'), has_table_privilege('korora_reader','api.measurements','SELECT'), has_table_privilege('korora_reader','api.measurements','INSERT')")
    assert privileges.strip() == "t|f|t|f", privileges
    if not args.no_mirror:
        for attempt in range(15):
            logs = k("logs", "deployment/shadow", "--since=2m")
            if trace in logs:
                break
            time.sleep(1)
        else:
            raise AssertionError("shadow did not receive query")
        assert write_trace not in logs, "write request was unexpectedly mirrored"
    else:
        time.sleep(1)
        logs = k("logs", "deployment/shadow", "--since=2m")
        assert trace not in logs, "query was mirrored while mirroring is disabled"
        assert write_trace not in logs, "write request was unexpectedly mirrored"
    if args.restart_db:
        k("delete", "pod", "postgres-0", "--wait=true")
        k("rollout", "status", "statefulset/postgres", "--timeout=180s")
        for attempt in range(45):
            code, body = request(path)
            if code == 200:
                break
            time.sleep(2)
        assert code == 200 and json.loads(body)[0]["event_id"] == event["event_id"]
    print("PASS: HTTPS, headers, routing, ingest/query, duplicate prevention, DB privileges" + (", mirroring" if not args.no_mirror else "") + (", persistence" if args.restart_db else ""))
if __name__ == "__main__":
    main()
