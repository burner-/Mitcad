# SPDX-License-Identifier: MIT
"""Dependency trial: packs or unpacks a folder as an uncompressed tar with its
absolute path kept (build trees name their own paths), leaving out what a
later job does not need.

  pack.py pack <dir> <tar> [<exclude glob>...]   a glob matches a path below
                                                  <dir> or a file's name
  pack.py unpack <tar>"""
import fnmatch
import os
import sys
import tarfile

if sys.argv[1] == "pack":
    root = os.path.abspath(sys.argv[2]).replace("\\", "/")
    out, excludes = sys.argv[3], sys.argv[4:]
    # Below the root ("home/runner/t/b"), or the drive ("t/b"; tarfile drops it).
    arc = os.path.splitdrive(root)[1].lstrip("/")
    count = [0, 0]

    def keep(info):
        rel = info.name[len(arc) + 1:] if info.name.startswith(arc + "/") else ""
        if rel:
            for g in excludes:
                if fnmatch.fnmatch(rel, g) or fnmatch.fnmatch(rel.rsplit("/", 1)[-1], g):
                    return None
        count[0] += 1
        count[1] += info.size
        return info

    with tarfile.open(out, "w", format=tarfile.PAX_FORMAT) as t:
        t.add(root, arcname=arc, filter=keep)
    print(f"packed {root}: {count[0]} entries, {count[1] / 2**30:.2f} GiB")
elif sys.argv[1] == "unpack":
    with tarfile.open(sys.argv[2]) as t:
        members = t.getmembers()
        # Windows: at the root of TRIAL_R's drive, where the tree was packed.
        dest = os.environ["TRIAL_R"][:2] + "/" if os.name == "nt" else "/"
        t.extractall(dest, members=members, filter="fully_trusted")
    print(f"unpacked {len(members)} entries")
else:
    raise SystemExit("pack or unpack")
