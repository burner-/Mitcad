# SPDX-License-Identifier: MIT
"""Dependency trial: a manifest of the given packages for one job, with the
repo manifest's baseline, overrides and overlay ports, every package with
exactly the features of the whole manifest's plan (so that the ABI hashes are
the ones the whole manifest's install looks for).

Usage: deps-manifest.py <repo root> <out dir> <spec>..."""
import json
import os
import re
import sys

repo, out = sys.argv[1], sys.argv[2]
specs = " ".join(sys.argv[3:]).split()
src = json.load(open(os.path.join(repo, "vcpkg.json")))
deps = []
for s in specs:
    m = re.match(r"^([a-z0-9-]+)(?:\[([^\]]*)\])?$", s)
    if not m:
        raise SystemExit(f"bad spec {s}")
    feats = [f for f in (m.group(2) or "").split(",") if f]
    d = {"name": m.group(1), "default-features": False}
    if feats:
        d["features"] = feats
    deps.append(d)
man = {
    "name": "mitcad-deps-job",
    "version": "0",
    "builtin-baseline": src["builtin-baseline"],
    "vcpkg-configuration": {"overlay-ports": [os.path.join(repo, "third_party", "vcpkg-ports").replace("\\", "/")]},
    "dependencies": deps,
}
if "overrides" in src:
    man["overrides"] = src["overrides"]
os.makedirs(out, exist_ok=True)
json.dump(man, open(os.path.join(out, "vcpkg.json"), "w"), indent=2)
print(json.dumps(man, indent=2))
