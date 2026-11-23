# SPDX-License-Identifier: MIT
"""Dependency trial: splits vcpkg's install plan of the manifest into levels of
jobs. A package's level is one more than the highest level of the packages it
needs (host tools excepted: each job builds the few it needs). The heavy ports
get a job of their own, the other packages of a level share one.

Usage: deps-plan.py <dry-run.txt> <depend-info-list.txt> <target triplet> <levels>
Writes l0..l<levels-1> (JSON lists of {"name", "specs"}) and "packages" to
GITHUB_OUTPUT, and the plan to stdout."""
import json
import os
import re
import sys

HEAVY = {
    "opencascade", "openimageio", "opencolorio", "openexr", "embree", "tbb", "libheif",
    "libde265", "openssl", "fontconfig", "freetype",
}

dry, info, triplet, nlevels = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])

features = {}
for line in open(dry, encoding="utf-8", errors="replace"):
    m = re.match(r"^\s+\*?\s*([a-z0-9-]+)(?:\[([^\]]*)\])?:([a-z0-9-]+)@", line)
    if not m:
        continue
    name, feats, trip = m.group(1), m.group(2), m.group(3)
    if trip != triplet or name.startswith("vcpkg-"):
        continue  # a host tool
    features[name] = sorted(f for f in (feats or "").split(",") if f and f != "core")
if not features:
    raise SystemExit("no packages in the dry run")

deps = {}
for line in open(info, encoding="utf-8", errors="replace"):
    m = re.match(r"^(?:\(\d+\))?([a-z0-9-]+)(?:\[[^\]]*\])?:\s*(.*)$", line.strip())
    if not m or m.group(1) not in features:
        continue
    deps[m.group(1)] = [d.strip() for d in m.group(2).split(",") if d.strip() in features]
missing = [n for n in features if n not in deps]
if missing:
    raise SystemExit(f"no dependency line for {missing}")

level = {}


def lvl(n, stack=()):
    if n in level:
        return level[n]
    if n in stack:
        raise SystemExit(f"cycle at {n}")
    level[n] = 0 if not deps[n] else 1 + max(lvl(d, stack + (n,)) for d in deps[n])
    return level[n]


for n in features:
    lvl(n)
top = max(level.values())
if top >= nlevels:
    raise SystemExit(f"{top + 1} levels, the workflow has {nlevels}")


def spec(n):
    return n + ("[" + ",".join(features[n]) + "]" if features[n] else "")


def closure(names):
    seen, todo = set(), list(names)
    while todo:
        n = todo.pop()
        if n not in seen:
            seen.add(n)
            todo.extend(deps[n])
    return " ".join(spec(n) for n in sorted(seen))


out = {}
if len(sys.argv) > 5 and sys.argv[5] == "flat":
    # One level: each big port builds its whole closure in its own job from the
    # start (the small packages it shares are built more than once); the
    # packages no big port needs share one job.
    FLAT = ["opencascade", "openimageio", "embree", "libheif"]
    jobs, covered = [], set()
    for n in FLAT:
        if n in features:
            jobs.append({"name": n, "specs": spec(n), "all": closure([n])})
            covered |= set(closure([n]).split())
    rest = [n for n in sorted(features) if spec(n) not in covered]
    if rest:
        jobs.append({"name": "misc", "specs": " ".join(spec(n) for n in rest), "all": closure(rest)})
    for j in jobs:
        print(f"flat job {j['name']}: {j['all']}")
    with open(os.environ["GITHUB_OUTPUT"], "a") as f:
        f.write(f"l0={json.dumps(jobs)}\n")
        for i in range(1, nlevels):
            f.write(f"l{i}=[]\n")
        f.write(f"packages={len(features)}\n")
    raise SystemExit(0)
for i in range(nlevels):
    names = sorted(n for n in features if level[n] == i)
    jobs = [{"name": n, "specs": spec(n), "all": closure([n])} for n in names if n in HEAVY]
    rest = [n for n in names if n not in HEAVY]
    if rest:
        jobs.append({"name": f"misc{i}", "specs": " ".join(spec(n) for n in rest), "all": closure(rest)})
    out[f"l{i}"] = jobs
    print(f"level {i}: " + "; ".join(f"{j['name']} = {j['specs']}" for j in jobs))
for n in sorted(features, key=lambda n: (level[n], n)):
    print(f"  L{level[n]} {n} <- {', '.join(deps[n]) or '-'}")
with open(os.environ["GITHUB_OUTPUT"], "a") as f:
    for k, v in out.items():
        f.write(f"{k}={json.dumps(v)}\n")
    f.write(f"packages={len(features)}\n")
