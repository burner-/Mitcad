#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Dependency trial: the render prefix (OIDN, Cycles) on Linux and macOS, as
# in the runner trial: CUDA on Linux x64 (as the releases), none on arm64,
# Metal on macOS.
set -euo pipefail
export MITCAD_RENDER_DEPS=$TRIAL_R/rd
case "$TRIAL_PLATFORM" in
  linux-x64) bash tools/dev-env/build-cycles.sh --cuda ;;
  linux-arm64) bash .github/trial/patch-linux-arm64.sh > /dev/null && bash tools/dev-env/build-cycles.sh ;;
  macos-arm64)
    if ! xcrun --sdk macosx metal --version > /dev/null 2>&1; then
      xcodebuild -downloadComponent MetalToolchain > /dev/null
    fi
    bash tools/dev-env/build-cycles-macos.sh ;;
esac || { for f in "$MITCAD_RENDER_DEPS"/*.log; do echo "== $f"; tail -60 "$f"; done; exit 1; }
du -sh "$MITCAD_RENDER_DEPS"/* || true
