# SPDX-License-Identifier: MIT
# Runner trial: samples memory and the build drive's use every 5 s and keeps
# the peaks (MiB) in $env:RUNNER_TEMP\trial\mempeak and diskpeak.
param([string]$Drive = 'C')
$state = Join-Path $env:RUNNER_TEMP 'trial'
New-Item -ItemType Directory -Force $state | Out-Null
$pm = 0; $pd = 0
while ($true) {
  $os = Get-CimInstance Win32_OperatingSystem
  $m = [int](($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1024)
  $d = [int]((Get-PSDrive $Drive).Used / 1MB)
  if ($m -gt $pm) { $pm = $m; Set-Content (Join-Path $state 'mempeak') $pm }
  if ($d -gt $pd) { $pd = $d; Set-Content (Join-Path $state 'diskpeak') $pd }
  Start-Sleep 5
}
