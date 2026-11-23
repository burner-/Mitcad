# SPDX-License-Identifier: MIT
# Dependency trial: the Windows app build's and the tests' toolchain beside
# vcpkg (deps-tools.sh): the MSVC environment, Rust, Qt, CEF.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$R = $env:TRIAL_R
"MITCAD_RENDER_DEPS=$R/rd" | Out-File -Append -Encoding utf8 $env:GITHUB_ENV
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
"Visual Studio: $vs"
cmd /c "`"$vs\VC\Auxiliary\Build\vcvars64.bat`" >nul && set" | ForEach-Object {
  if ($_ -match '^([^=]+)=(.*)$' -and $Matches[1] -notin 'VCPKG_ROOT', 'TRIAL_PLATFORM', 'Platform') { "$($Matches[1])=$($Matches[2])" | Out-File -Append -Encoding utf8 $env:GITHUB_ENV }
}
$rust = (Select-String -Path rust-toolchain.toml -Pattern '^channel *= *"(.*)"').Matches[0].Groups[1].Value
rustup toolchain install $rust --profile minimal --component clippy,rustfmt --no-self-update | Out-Null
$pins = @{}
foreach ($line in Get-Content tools/dev-env/versions.sh) { if ($line -match '^([A-Z0-9_]+)="?([^"]*)"?$') { $pins[$Matches[1]] = $Matches[2] } }
python -m venv "$R\aqt"
& "$R\aqt\Scripts\pip.exe" install --quiet $pins.AQT_SPEC
Push-Location $env:RUNNER_TEMP
& "$R\aqt\Scripts\aqt.exe" install-qt windows desktop $pins.QT_VERSION win64_msvc2022_64 -O "$R\Qt" | Out-Null
Pop-Location
"QT_ROOT_DIR=$R/Qt/$($pins.QT_VERSION)/msvc2022_64" | Out-File -Append -Encoding utf8 $env:GITHUB_ENV
$cef = & powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev-env/fetch-cef.ps1 -Root "$R\cef" | Select-Object -Last 1
"MITCAD_CEF_ROOT=$cef" | Out-File -Append -Encoding utf8 $env:GITHUB_ENV
