#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Runner trial: adapts the x86-64-only Linux build scripts to aarch64 in the
# runner's checkout only (nothing is committed). Run from the repo root.
set -euo pipefail
. tools/dev-env/versions.sh
PREFIX=${MITCAD_RENDER_DEPS:?}

# vcpkg: sse2neon also on Linux arm64 (Cycles' ARM branch needs it).
sed -i 's/"platform": "osx & arm64"/"platform": "arm64"/' vcpkg.json

# build-cycles.sh: the arm64 triplet, no x86-64 check, sse2neon for Cycles.
sed -i 's/\[ "$(uname -m)" != x86_64 \]/false/' tools/dev-env/build-cycles.sh
sed -i 's/^TRIPLET=x64-linux-dynamic/TRIPLET=arm64-linux-dynamic/' tools/dev-env/build-cycles.sh
sed -i 's|-DZSTD_ROOT_DIR="$DEPS" -DPUGIXML_ROOT_DIR="$DEPS"|-DZSTD_ROOT_DIR="$DEPS" -DPUGIXML_ROOT_DIR="$DEPS" -DSSE2NEON_INCLUDE_DIR="$DEPS/include/sse2neon"|' \
  tools/dev-env/build-cycles.sh
grep -q SSE2NEON_INCLUDE_DIR tools/dev-env/build-cycles.sh

# ISPC: the aarch64 release under the x86-64 archive's name, its digest as
# the pin, unpacked where build-cycles.sh looks for it.
mkdir -p "$PREFIX/downloads" "$PREFIX/src/ispc-v$ISPC_VERSION-linux"
archive=$PREFIX/downloads/ispc-v$ISPC_VERSION-linux.tar.gz
if [ ! -f "$archive" ]; then
  curl -fsSL --retry 3 -o "$archive" \
    "https://github.com/ispc/ispc/releases/download/v$ISPC_VERSION/ispc-v$ISPC_VERSION-linux.aarch64.tar.gz"
fi
sha=$(sha256sum "$archive" | cut -d' ' -f1)
sed -i "s/^ISPC_LINUX_SHA256=.*/ISPC_LINUX_SHA256=$sha/" tools/dev-env/versions.sh
tar -xzf "$archive" -C "$PREFIX/src/ispc-v$ISPC_VERSION-linux" --strip-components=1
"$PREFIX/src/ispc-v$ISPC_VERSION-linux/bin/ispc" --version

# CEF: the published linuxarm64 distribution, checked against its published SHA-1.
sed -i 's/^  Linux-x86_64) platform=linux64 pin=$CEF_LINUX64_SHA1 ;;/  Linux-x86_64) platform=linux64 pin=$CEF_LINUX64_SHA1 ;;\n  Linux-aarch64) platform=linuxarm64 pin= ;;/' \
  tools/dev-env/fetch-cef.sh
grep -q linuxarm64 tools/dev-env/fetch-cef.sh

# AppImage tools: the aarch64 builds of the same releases (no pins for them).
sed -i 's/-x86_64\.AppImage$/-aarch64.AppImage/' tools/dev-env/install-appimage-tools.sh
sed -i 's/if \[ "$actual" != "$sha256" \]; then/if false; then/' tools/dev-env/install-appimage-tools.sh
sed -i 's/^ARCH=x86_64 appimagetool/ARCH=aarch64 appimagetool/' packaging/linux/make-appimage.sh
sed -i 's/-x86_64\.AppImage")/-aarch64.AppImage")/' cmake/AppImage.cmake
git --no-pager diff --stat
