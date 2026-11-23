# SPDX-License-Identifier: MIT
"""Dependency trial: what the app build's time went to, from .ninja_log: the
wall time, the slowest edges, and the cargo (Rust) edges against the rest.

Usage: ninja-stats.py <build dir>"""
import os
import sys

log = os.path.join(sys.argv[1], ".ninja_log")
edges = {}
for line in open(log, encoding="utf-8", errors="replace"):
    if line.startswith("#"):
        continue
    p = line.rstrip("\n").split("\t")
    if len(p) < 4:
        continue
    start, end, out = int(p[0]), int(p[1]), p[3]
    edges[out] = (start, end)  # the last run of an output wins
if not edges:
    raise SystemExit("empty .ninja_log")
t0 = min(s for s, _ in edges.values())
t1 = max(e for _, e in edges.values())


def is_cargo(out):
    o = out.lower()
    return "cargo" in o or "corrosion" in o or "_cargo-build" in o


cargo = [(e - s, o, s, e) for o, (s, e) in edges.items() if is_cargo(o)]
other = [(e - s, o, s, e) for o, (s, e) in edges.items() if not is_cargo(o)]
print(f"ninja wall {(t1 - t0) / 60000:.1f} min, {len(edges)} edges, "
      f"sum of edge times {sum(d for d, *_ in other + cargo) / 60000:.1f} min")
if cargo:
    cs, ce = min(c[2] for c in cargo), max(c[3] for c in cargo)
    print(f"cargo edges: {len(cargo)}, from {(cs - t0) / 60000:.1f} to {(ce - t0) / 60000:.1f} min, "
          f"longest {max(cargo)[0] / 60000:.1f} min ({max(cargo)[1]})")
last_obj = max((e for d, o, s, e in other if o.endswith((".o", ".obj"))), default=t0)
print(f"last C/C++ object done at {(last_obj - t0) / 60000:.1f} min; C/C++ compile sum "
      f"{sum(d for d, o, *_ in other if o.endswith(('.o', '.obj'))) / 60000:.1f} min")
links = [(d, o) for d, o, *_ in other if o.endswith((".exe", ".dll", ".so", ".dylib")) or "/" not in o and "." not in o]
print("slowest edges:")
for d, o, s, e in sorted(other + cargo, reverse=True)[:15]:
    print(f"  {d / 60000:6.1f} min  {(s - t0) / 60000:6.1f}-{(e - t0) / 60000:6.1f}  {o}")
