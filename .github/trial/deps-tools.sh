#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Dependency trial: the toolchain a vcpkg job needs on this runner, the same
# in every job of a platform (vcpkg's ABI hashes include the compiler and
# CMake), and vcpkg at the pinned commit. Run from the repo root with
# TRIAL_PLATFORM set (linux-x64, linux-arm64, windows-x64, macos-arm64).
# Writes VCPKG_ROOT, VCPKG_EXE, TRIAL_R and the binary-cache variables to
# GITHUB_ENV.
set -euo pipefail
. tools/dev-env/versions.sh
if [ "$TRIAL_PLATFORM" != windows-x64 ]; then
  # The export drops the executable bits.
  git ls-files '*.sh' | xargs chmod +x
  chmod +x packaging/linux/AppRun 2> /dev/null || true
  echo "REPO=$PWD" >> "$GITHUB_ENV"
  echo "PY=python3" >> "$GITHUB_ENV"
else
  echo "REPO=$(cygpath -m "$PWD")" >> "$GITHUB_ENV"
  echo "PY=python" >> "$GITHUB_ENV"
fi
case "$TRIAL_PLATFORM" in
  linux-*)
    R=$HOME/t
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      build-essential cmake ninja-build pkg-config git curl zip unzip tar \
      autoconf autoconf-archive automake libtool python3-venv \
      libgl1-mesa-dev libegl1-mesa-dev libx11-dev libxext-dev libxi-dev libxrandr-dev \
      libxcursor-dev libxinerama-dev libxkbcommon-dev libfontconfig1-dev libfreetype-dev > /dev/null
    echo "VCPKG_FORCE_SYSTEM_BINARIES=1" >> "$GITHUB_ENV"
    if [ "$TRIAL_PLATFORM" = linux-arm64 ]; then
      # Cycles' ARM branch needs sse2neon on Linux arm64 too (runner checkout only).
      sed -i 's/"platform": "osx & arm64"/"platform": "arm64"/' vcpkg.json
    fi
    ;;
  windows-x64)
    if [ -d /d ] && [ "$(df -Pk /d | awk 'NR==2 {print $4}')" -gt "$(df -Pk /c | awk 'NR==2 {print $4}')" ]; then
      R=/d/t
    else
      R=/c/t
    fi
    ;;
  macos-arm64)
    R=$HOME/t
    newest=$(ls -d /Applications/Xcode_*.app | grep -v -i beta | sort -V | tail -1)
    [ -n "$newest" ] && sudo xcode-select -s "$newest/Contents/Developer"
    xcodebuild -version | head -1
    mkdir -p "$HOME/.local/bin" "$HOME/.cache/dl"
    if ! cmake --version 2> /dev/null | head -n 1 | grep -q "$CMAKE_VERSION"; then
      curl -fsSL -o "$HOME/.cache/dl/cmake.tgz" \
        "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-macos-universal.tar.gz"
      echo "$CMAKE_MACOS_SHA256  $HOME/.cache/dl/cmake.tgz" | shasum -a 256 -c - > /dev/null
      tar -xzf "$HOME/.cache/dl/cmake.tgz" -C "$HOME/.local"
      for tool in cmake ctest cpack; do
        ln -sf "$HOME/.local/cmake-$CMAKE_VERSION-macos-universal/CMake.app/Contents/bin/$tool" "$HOME/.local/bin/$tool"
      done
    fi
    curl -fsSL -o "$HOME/.cache/dl/ninja.zip" \
      "https://github.com/ninja-build/ninja/releases/download/v$NINJA_VERSION/ninja-mac.zip"
    echo "$NINJA_MAC_SHA256  $HOME/.cache/dl/ninja.zip" | shasum -a 256 -c - > /dev/null
    unzip -q -o "$HOME/.cache/dl/ninja.zip" -d "$HOME/.local/bin"
    command -v pkg-config > /dev/null || brew install pkgconf > /dev/null
    echo "$HOME/.local/bin" >> "$GITHUB_PATH"
    export PATH=$HOME/.local/bin:$PATH
    cmake --version | head -1
    ;;
  *) echo "unknown TRIAL_PLATFORM $TRIAL_PLATFORM" >&2; exit 1 ;;
esac
mkdir -p "$R"
VCPKG_ROOT=$R/vcpkg
git clone --quiet https://github.com/microsoft/vcpkg "$VCPKG_ROOT"
git -C "$VCPKG_ROOT" checkout --quiet "$VCPKG_COMMIT"
if [ "$TRIAL_PLATFORM" = windows-x64 ]; then
  (cd "$VCPKG_ROOT" && cmd //c bootstrap-vcpkg.bat -disableMetrics > /dev/null)
  VCPKG_EXE=$VCPKG_ROOT/vcpkg.exe
  # vcpkg wants Windows paths in its variables.
  W=$(cygpath -m "$R")
  {
    echo "VCPKG_ROOT=$W/vcpkg"
    echo "TRIAL_R=$W"
    echo "VCPKG_EXE=$W/vcpkg/vcpkg.exe"
    echo "BINCACHE=$W/bc"
    echo "VCPKG_BINARY_SOURCES=clear;files,$W/bc,readwrite"
    echo "VCPKG_DOWNLOADS=$W/dl"
  } >> "$GITHUB_ENV"
else
  "$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics > /dev/null
  {
    echo "VCPKG_ROOT=$VCPKG_ROOT"
    echo "TRIAL_R=$R"
    echo "VCPKG_EXE=$VCPKG_ROOT/vcpkg"
    echo "BINCACHE=$R/bc"
    echo "VCPKG_BINARY_SOURCES=clear;files,$R/bc,readwrite"
    echo "VCPKG_DOWNLOADS=$R/dl"
  } >> "$GITHUB_ENV"
fi
mkdir -p "$R/bc" "$R/dl"
