# SPDX-License-Identifier: MIT
# Dependency trial: the Windows render prefix (OIDN, Cycles with CUDA) as in
# the runner trial: VS 2022's C++ tools (CUDA 12.9's cudafe++ crashes on
# VS 2026's headers), their environment, build-cycles.ps1 -Cuda.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$t0 = Get-Date
choco install visualstudio2022-workload-vctools -y --no-progress | Out-Null
"TRIAL| vs2022-tools | $([int]((Get-Date) - $t0).TotalSeconds) s"
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs22 = & $vswhere -products * -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1
"VS 2022: $vs22"
foreach ($v in 'INCLUDE', 'LIB', 'LIBPATH', 'EXTERNAL_INCLUDE', 'VSINSTALLDIR', 'VCINSTALLDIR', 'VCToolsInstallDir', 'VCToolsVersion',
               'VCToolsRedistDir', 'VSCMD_VER', 'VSCMD_ARG_app_plat', 'VSCMD_ARG_HOST_ARCH', 'VSCMD_ARG_TGT_ARCH', 'DevEnvDir',
               'VisualStudioVersion', 'VCIDEInstallDir', 'ExtensionSdkDir', 'UCRTVersion', 'UniversalCRTSdkDir', 'WindowsSdkDir',
               'WindowsSDKVersion', 'WindowsSdkBinPath', 'WindowsSdkVerBinPath', 'WindowsLibPath', 'WindowsSDKLibVersion',
               '__VSCMD_script_err_count', 'CMAKE_PREFIX_PATH') { Remove-Item "env:$v" -ErrorAction SilentlyContinue }
if ($env:__VSCMD_PREINIT_PATH) { $env:Path = $env:__VSCMD_PREINIT_PATH; Remove-Item env:__VSCMD_PREINIT_PATH }
if ($env:pythonLocation) { $env:Path = "$env:pythonLocation;$env:pythonLocation\Scripts;$env:Path" }
$out = cmd /c "`"$vs22\VC\Auxiliary\Build\vcvars64.bat`" && set"
$out | ForEach-Object { if ($_ -match '^([^=]+)=(.*)$' -and $Matches[1] -ne 'VCPKG_ROOT') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] } }
if (-not (Get-Command ninja.exe -ErrorAction SilentlyContinue)) { choco install ninja -y --no-progress | Out-Null; $env:Path += ';C:\ProgramData\chocolatey\bin' }
if ((Get-Command cl.exe).Source -notlike "$vs22*") { throw 'cl.exe is not VS 2022' }
& powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev-env/build-cycles.ps1 -Cuda
if ($LASTEXITCODE -ne 0) { Get-ChildItem "$env:MITCAD_RENDER_DEPS\*.log" | ForEach-Object { "== $($_.Name)"; Get-Content $_ -Tail 60 }; exit 1 }
