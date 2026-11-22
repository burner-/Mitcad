# SPDX-License-Identifier: MIT
# Runner trial: one line per phase (see mark.sh), for Windows.
# $env:TRIAL_DRIVE names the build drive; $env:TRIAL_SIZES is name=path;...
param([Parameter(Mandatory = $true)][string]$Label)
$state = Join-Path $env:RUNNER_TEMP 'trial'
New-Item -ItemType Directory -Force $state | Out-Null
$now = [int][double]::Parse((Get-Date -UFormat %s))
$lastFile = Join-Path $state 'last'
$last = if (Test-Path $lastFile) { [int](Get-Content $lastFile) } else { $now }
Set-Content $lastFile $now
$drive = if ($env:TRIAL_DRIVE) { $env:TRIAL_DRIVE } else { 'C' }
$d = Get-PSDrive $drive
$peakDisk = if (Test-Path (Join-Path $state 'diskpeak')) { [int](Get-Content (Join-Path $state 'diskpeak')) } else { 0 }
$peakMem = if (Test-Path (Join-Path $state 'mempeak')) { Get-Content (Join-Path $state 'mempeak') } else { '?' }
$sizes = ''
if ($env:TRIAL_SIZES) {
  foreach ($entry in $env:TRIAL_SIZES.Split(';')) {
    if (-not $entry) { continue }
    $name, $path = $entry.Split('=', 2)
    if (Test-Path $path) {
      $bytes = (Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
      $sizes += (' {0}={1:N2}G' -f $name, ($bytes / 1GB))
    }
  }
}
'TRIAL| {0} | {1} s | {2}: used {3:N1}G free {4:N1}G | disk peak {5:N1}G | mem peak {6} MiB |{7}' -f `
  $Label, ($now - $last), $drive, ($d.Used / 1GB), ($d.Free / 1GB), ($peakDisk / 1024), $peakMem, $sizes
Get-PSDrive -PSProvider FileSystem | Format-Table -AutoSize | Out-String | Write-Host
