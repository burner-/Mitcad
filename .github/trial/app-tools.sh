#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Dependency trial: the app build's and the tests' toolchain beside vcpkg
# (deps-tools.sh): system packages, Rust, Qt, CEF. Linux and macOS.
# Writes QT_ROOT_DIR, MITCAD_CEF_ROOT and MITCAD_RENDER_DEPS to GITHUB_ENV.
set -euo pipefail
. tools/dev-env/versions.sh
RUST=$(sed -n 's/^channel *= *"\(.*\)"/\1/p' rust-toolchain.toml)
echo "MITCAD_RENDER_DEPS=$TRIAL_R/rd" >> "$GITHUB_ENV"
export MITCAD_RENDER_DEPS=$TRIAL_R/rd
case "$TRIAL_PLATFORM" in
  linux-*)
    sudo bash tools/dev-env/install-packages.sh > /dev/null
    if [ "$TRIAL_PLATFORM" = linux-arm64 ]; then
      bash .github/trial/patch-linux-arm64.sh
      qt_host=linux_arm64 qt_arch=linux_gcc_arm64 qt_dir=gcc_arm64
    else
      qt_host=linux qt_arch=linux_gcc_64 qt_dir=gcc_64
    fi
    command -v rustup > /dev/null || {
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain none
      echo "$HOME/.cargo/bin" >> "$GITHUB_PATH"
      . "$HOME/.cargo/env"
    }
    rustup toolchain install "$RUST" --profile minimal --component clippy,rustfmt --no-self-update > /dev/null
    python3 -m venv "$TRIAL_R/aqt"
    "$TRIAL_R/aqt/bin/pip" install --quiet "$AQT_SPEC"
    (cd "$RUNNER_TEMP" && "$TRIAL_R/aqt/bin/aqt" install-qt "$qt_host" desktop "$QT_VERSION" "$qt_arch" -O "$TRIAL_R/Qt" > /dev/null)
    echo "QT_ROOT_DIR=$TRIAL_R/Qt/$QT_VERSION/$qt_dir" >> "$GITHUB_ENV"
    echo "MITCAD_CEF_ROOT=$(tools/dev-env/fetch-cef.sh | tail -1)" >> "$GITHUB_ENV"
    ;;
  macos-arm64)
    # setup-macos.sh without cargo-deny and the render libraries (as in the
    # runner trial); its vcpkg is the same commit as deps-tools.sh's.
    sed -i '' -e 's|^  cargo "+$RUST_TOOLCHAIN" install cargo-deny .*|  : cargo-deny not needed for the trial|' \
      -e 's|^"$SCRIPT_DIR/build-cycles-macos.sh"$|: the render libraries come from the deps job|' tools/dev-env/setup-macos.sh
    bash tools/dev-env/setup-macos.sh > "$RUNNER_TEMP/setup-macos.log" 2>&1 || { tail -60 "$RUNNER_TEMP/setup-macos.log"; exit 1; }
    echo "$HOME/.cargo/bin" >> "$GITHUB_PATH"
    {
      echo "VCPKG_ROOT=$HOME/vcpkg"
      echo "QT_ROOT_DIR=$HOME/Qt/$QT_VERSION/macos"
      echo "MITCAD_CEF_ROOT=$(tools/dev-env/fetch-cef.sh --print-root)"
    } >> "$GITHUB_ENV"
    ;;
esac
