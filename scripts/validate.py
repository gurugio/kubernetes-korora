#!/usr/bin/env python3
"""클러스터에 접속하지 않고 정상/고장 구성의 렌더링과 참조를 검증한다."""
import json
from pathlib import Path
import subprocess
import sys
import yaml

ROOT = Path(__file__).resolve().parents[1]
class UniqueLoader(yaml.SafeLoader):
    pass
def unique_mapping(loader, node, deep=False):
    pairs = loader.construct_pairs(node, deep=deep)
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate YAML key: {key}")
        result[key] = value
    return result
UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping)

def load_all(text):
    return [d for d in yaml.load_all(text, Loader=UniqueLoader) if d is not None]

def check(docs, path):
    identities = set()
    for d in docs:
        assert isinstance(d, dict) and d.get("apiVersion") and d.get("kind"), path
        key = (d["apiVersion"], d["kind"], d.get("metadata", {}).get("namespace", ""), d["metadata"]["name"])
        assert key not in identities, (path, key)
        identities.add(key)
        assert "$patch" not in json.dumps(d), (path, "unresolved patch")
    if not docs:
        return
    configs = {d["metadata"]["name"]: d for d in docs if d["kind"] in ("ConfigMap", "Secret")}
    for d in docs:
        if d["kind"] not in ("Deployment", "StatefulSet"):
            continue
        pod = d["spec"]["template"]["spec"]
        for v in pod.get("volumes", []):
            if "configMap" in v:
                name = v["configMap"]["name"]
                # Intentional missing references are covered by schema validation, not healthy-reference checks.
                if "faults" not in path.parts:
                    assert name in configs, (path, name)
        for c in pod["containers"]:
            assert ":" in c["image"] and not c["image"].endswith(":latest"), (path, c["image"])
            for e in c.get("env", []):
                ref = e.get("valueFrom", {}).get("secretKeyRef")
                if ref and "faults" not in path.parts:
                    assert ref["name"] in configs, (path, ref)
                    secret = configs[ref["name"]]
                    assert ref["key"] in {**secret.get("data", {}), **secret.get("stringData", {})}, (path, ref)

def main():
    for p in ROOT.rglob("*.yaml"):
        if ".local" not in p.parts:
            load_all(p.read_text())
    targets = sorted(ROOT.glob("chapters/*/kustomization.yaml"))
    targets += sorted(ROOT.glob("faults/*/*/kustomization.yaml"))
    targets += sorted(ROOT.glob("overlays/*/kustomization.yaml"))
    targets += [ROOT / "kustomization.yaml"]
    out = ROOT / ".local" / "rendered"
    out.mkdir(parents=True, exist_ok=True)
    for target in targets:
        relative = target.parent.relative_to(ROOT)
        output = subprocess.check_output(["kustomize", "build", str(target.parent)], text=True)
        docs = load_all(output)
        check(docs, relative)
        name = str(relative).replace("/", "__") if str(relative) != "." else "root"
        (out / f"{name}.yaml").write_text(output)
        print(f"OK {relative}: {len(docs)} resources")
    report = {"rendered_targets": len(targets), "status": "passed", "runtime_tested": False}
    (ROOT / ".local" / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))

if __name__ == "__main__":
    main()
