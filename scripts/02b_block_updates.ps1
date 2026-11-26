<#
.SYNOPSIS
    Freezes Windows Update (and app auto-updates) for the contest.
.DESCRIPTION
    Why the old version did not work:
      - It lived inside 02_lockdown_network.ps1, which never ran (see that file).
      - Even when run, Set-Service cannot touch WaaSMedicSvc / DoSvc / UsoSvc as Administrator
        (they are protected), the errors were hidden, and the Update Medic service turns
        wuauserv back on.
    Layers applied now (any one of them is usually enough; together they are reliable):
      1. Group-Policy registry settings: no automatic updates, no auto-restart while someone is
         logged on, no "Check for updates" for users, Windows Update pointed at a dead local
         server, Store app auto-update off, VS Code update check off.
      2. Updates paused for -PauseDays days (Settings > Windows Update shows "Paused").
      3. Update services disabled and their scheduled tasks disabled - done as SYSTEM, because
         Administrators are not allowed to change them.
      4. A warning if an update is already waiting for a restart (restart BEFORE the contest).
    Everything is backed up once to C:\ProgramData\ICPC\backup and restored by RUN_CLEANUP.bat.
#>

param([int]$PauseDays = 7)

. "$PSScriptRoot\common.ps1"

$PauseDays = [math]::Max(1, [math]::Min(35, $PauseDays))
$problems = 0

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Step 4] Freezing Windows Update" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$services  = @('wuauserv', 'UsoSvc', 'WaaSMedicSvc', 'DoSvc', 'uhssvc')
$taskPaths = @('\Microsoft\Windows\WindowsUpdate\', '\Microsoft\Windows\UpdateOrchestrator\', '\Microsoft\Windows\WaaSMedic\')
$regKeys = [ordered]@{
    'wu_policy'     = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    'store_policy'  = 'HKLM\SOFTWARE\Policies\Microsoft\WindowsStore'
    'vscode_policy' = 'HKLM\SOFTWARE\Policies\Microsoft\VSCode'
    'wu_ux'         = 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
}

# -------------------------------------------------------------
# 0. Backup (only the first time, so a re-run never overwrites the real original state)
# -------------------------------------------------------------
New-Item -ItemType Directory -Path $script:IcpcBackupDir -Force | Out-Null
$manifestPath = Join-Path $script:IcpcBackupDir 'updates.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    $svcState = [ordered]@{}
    foreach ($s in $services) {
        $k = "HKLM:\SYSTEM\CurrentControlSet\Services\$s"
        if (Test-Path $k) { $svcState[$s] = (Get-ItemProperty -Path $k -Name Start -ErrorAction SilentlyContinue).Start }
    }
    $enabledTasks = @()
    foreach ($tp in $taskPaths) {
        $enabledTasks += @(Get-ScheduledTask -TaskPath $tp -ErrorAction SilentlyContinue |
            Where-Object { $_.State -ne 'Disabled' } | ForEach-Object { "$($_.TaskPath)|$($_.TaskName)" })
    }
    $keyState = [ordered]@{}
    foreach ($name in $regKeys.Keys) {
        $file = Join-Path $script:IcpcBackupDir "$name.reg"
        reg query $regKeys[$name] 2>$null | Out-Null
        $exists = ($LASTEXITCODE -eq 0)
        if ($exists) { reg export $regKeys[$name] $file /y 2>$null | Out-Null }
        $keyState[$name] = [ordered]@{ key = $regKeys[$name]; existed = $exists; file = $file }
    }
    $manifest = [ordered]@{ created = (Get-Date).ToString('s'); services = $svcState; enabledTasks = $enabledTasks; registry = $keyState }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Write-Host "[OK] Original Windows Update state backed up." -ForegroundColor Green
} else {
    Write-Host "[INFO] Windows Update backup already exists (kept from the first run)." -ForegroundColor Gray
}

# -------------------------------------------------------------
# 1. Policies
# -------------------------------------------------------------
function Set-Reg([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord') {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}
Write-Host "[INFO] Applying update policies..." -ForegroundColor Yellow
try {
    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $au = "$wu\AU"
    $deadServer = 'http://127.0.0.1:8530'
    Set-Reg $wu 'WUServer' $deadServer 'String'
    Set-Reg $wu 'WUStatusServer' $deadServer 'String'
    Set-Reg $wu 'UpdateServiceUrlAlternate' $deadServer 'String'
    Set-Reg $wu 'DoNotConnectToWindowsUpdateInternetLocations' 1
    Set-Reg $wu 'SetDisableUXWUAccess' 1                 # hides "Check for updates" from users
    Set-Reg $wu 'ExcludeWUDriversInQualityUpdate' 1
    Set-Reg $wu 'SetActiveHours' 1
    Set-Reg $wu 'ActiveHoursStart' 6
    Set-Reg $wu 'ActiveHoursEnd' 23
    Set-Reg $au 'UseWUServer' 1
    Set-Reg $au 'NoAutoUpdate' 1
    Set-Reg $au 'AUOptions' 2
    Set-Reg $au 'NoAutoRebootWithLoggedOnUsers' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' 'AutoDownload' 2
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\VSCode' 'UpdateMode' 'none' 'String'

    # Pause (same as Settings > Windows Update > Pause)
    $ux = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
    $now = (Get-Date).ToUniversalTime()
    $start = $now.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $end = $now.AddDays($PauseDays).ToString('yyyy-MM-ddTHH:mm:ssZ')
    Set-Reg $ux 'PauseUpdatesStartTime' $start 'String'
    Set-Reg $ux 'PauseUpdatesExpiryTime' $end 'String'
    Set-Reg $ux 'PauseFeatureUpdatesStartTime' $start 'String'
    Set-Reg $ux 'PauseFeatureUpdatesEndTime' $end 'String'
    Set-Reg $ux 'PauseQualityUpdatesStartTime' $start 'String'
    Set-Reg $ux 'PauseQualityUpdatesEndTime' $end 'String'
    Write-Host "[OK] Policies applied; updates paused until $($now.AddDays($PauseDays).ToLocalTime().ToString('yyyy-MM-dd HH:mm'))." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Could not write update policies: $($_.Exception.Message)" -ForegroundColor Red
    $problems++
}

# -------------------------------------------------------------
# 2. Services + scheduled tasks (as SYSTEM)
# -------------------------------------------------------------
Write-Host "[INFO] Disabling update services and tasks (running as SYSTEM)..." -ForegroundColor Yellow
$sysScript = @'
foreach ($s in @('wuauserv','UsoSvc','WaaSMedicSvc','DoSvc','uhssvc')) {
    $k = "HKLM:\SYSTEM\CurrentControlSet\Services\$s"
    if (-not (Test-Path $k)) { continue }
    try { Stop-Service -Name $s -Force -ErrorAction Stop } catch { }
    try { Set-ItemProperty -Path $k -Name Start -Value 4 -Type DWord -ErrorAction Stop; "SVC|OK|$s" }
    catch { "SVC|FAIL|$s|$($_.Exception.Message)" }
}
foreach ($tp in @('\Microsoft\Windows\WindowsUpdate\','\Microsoft\Windows\UpdateOrchestrator\','\Microsoft\Windows\WaaSMedic\')) {
    foreach ($t in @(Get-ScheduledTask -TaskPath $tp -ErrorAction SilentlyContinue)) {
        if ($t.State -eq 'Disabled') { continue }
        try { Disable-ScheduledTask -InputObject $t -ErrorAction Stop | Out-Null; "TASK|OK|$($t.TaskPath)$($t.TaskName)" }
        catch { "TASK|FAIL|$($t.TaskPath)$($t.TaskName)" }
    }
}
'@
$out = Invoke-AsSystem -ScriptText $sysScript
if ($out.Count -eq 0) {
    Write-Host "  [ERROR] The SYSTEM helper task did not run (Task Scheduler disabled?)." -ForegroundColor Red
    $problems++
}
$taskOk = 0; $taskFail = 0
foreach ($line in $out) {
    $f = "$line".Split('|')
    if ($f[0] -eq 'SVC' -and $f[1] -eq 'OK') { Write-Host "  [OK] Service disabled: $($f[2])" -ForegroundColor Green }
    elseif ($f[0] -eq 'SVC') {
        if ($f[2] -eq 'WaaSMedicSvc') {
            Write-Host "  [NOTE] WaaSMedicSvc is protected by Windows and stays on. That is fine: update policies + firewall leave it nothing to download." -ForegroundColor Gray
        } else {
            Write-Host "  [WARNING] Could not disable $($f[2]): $($f[3])" -ForegroundColor Yellow
        }
    }
    elseif ($f[0] -eq 'TASK' -and $f[1] -eq 'OK') { $taskOk++ }
    elseif ($f[0] -eq 'TASK') { $taskFail++ }
}
Write-Host "  [OK] Update scheduled tasks disabled: $taskOk$(if ($taskFail) { " ($taskFail protected by Windows, left as is)" })" -ForegroundColor Green

# -------------------------------------------------------------
# 3. Verify
# -------------------------------------------------------------
$wuSvc = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
if ($wuSvc -and $wuSvc.StartType -eq 'Disabled') {
    Write-Host "[OK] Windows Update service (wuauserv): Disabled / $($wuSvc.Status)" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Windows Update service is still '$($wuSvc.StartType)'." -ForegroundColor Red
    $problems++
}

$pending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
           (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
if ($pending) {
    Write-Host ""
    Write-Host "[WARNING] An update is ALREADY downloaded and waiting for a restart on this PC." -ForegroundColor Red
    Write-Host "          Restart the PC now (before the contest), let it finish, then run RUN_SETUP.bat again." -ForegroundColor Red
    $problems++
}

Write-Host "==========================================" -ForegroundColor Green
if ($problems -eq 0) { Write-Host " Windows Update frozen." -ForegroundColor Green }
else { Write-Host " Windows Update freeze finished with $problems problem(s) - see above." -ForegroundColor Red }
Write-Host "==========================================" -ForegroundColor Green
exit $problems
