<#
.SYNOPSIS
    Reverts an ICPC lab workstation back to the normal university lab state.
.DESCRIPTION
    - Restores the firewall policy that existed before setup (from the backup made by step 3);
      falls back to a factory reset if no backup exists. Re-enables Wi-Fi.
    - Restores Windows Update services, scheduled tasks and policies exactly as they were.
    - Disables auto-logon.
    - Removes 'contestant' / 'ICPCLK26_*' accounts together with their profiles (properly, so a
      later setup does not end up with a broken "C:\Users\<name>.<PC>" profile).
    - Removes the ICPC cache/backup folder and the VS Code defaults injected into C:\Users\Default.
    Installed compilers / VS Code are left in place.
#>

param(
    [string]$Username = "contestant"
)

. "$PSScriptRoot\common.ps1"

Write-Host "==========================================" -ForegroundColor Red
Write-Host " [Cleanup] Restoring Workstation to Default" -ForegroundColor Red
Write-Host "==========================================" -ForegroundColor Red

# 1. Firewall ---------------------------------------------------
$fwBackup = Join-Path $script:IcpcBackupDir 'firewall.wfw'
if (Test-Path -LiteralPath $fwBackup) {
    Write-Host "[INFO] Restoring the original firewall policy from backup..." -ForegroundColor Yellow
    netsh advfirewall import "$fwBackup" | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "[OK] Firewall restored to its pre-contest state." -ForegroundColor Green }
    else { Write-Host "[WARNING] Import failed - resetting firewall to factory defaults instead." -ForegroundColor Yellow; netsh advfirewall reset | Out-Null }
} else {
    Write-Host "[INFO] No firewall backup found - resetting firewall to factory defaults..." -ForegroundColor Yellow
    netsh advfirewall reset | Out-Null
    Write-Host "[OK] Windows Firewall reset to default." -ForegroundColor Green
}
Remove-NetFirewallRule -DisplayName "ICPC-*" -ErrorAction SilentlyContinue

# 2. Windows Update ---------------------------------------------
Write-Host "[INFO] Restoring Windows Update..." -ForegroundColor Yellow
$manifestPath = Join-Path $script:IcpcBackupDir 'updates.json'
$defaults = [ordered]@{ wuauserv = 3; UsoSvc = 2; WaaSMedicSvc = 3; DoSvc = 2; uhssvc = 2 }
$svcStart = [ordered]@{}
$tasksToEnable = @()
if (Test-Path -LiteralPath $manifestPath) {
    $m = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    foreach ($p in $m.services.PSObject.Properties) { if ($null -ne $p.Value) { $svcStart[$p.Name] = [int]$p.Value } }
    $tasksToEnable = @($m.enabledTasks)
    foreach ($r in $m.registry.PSObject.Properties) {
        $info = $r.Value
        reg delete $info.key /f 2>$null | Out-Null
        if ($info.existed -and (Test-Path -LiteralPath $info.file)) { reg import $info.file 2>$null | Out-Null }
    }
    Write-Host "[OK] Update policies restored from backup." -ForegroundColor Green
} else {
    $svcStart = $defaults
    $tasksToEnable = @('\Microsoft\Windows\WindowsUpdate\|*', '\Microsoft\Windows\UpdateOrchestrator\|*', '\Microsoft\Windows\WaaSMedic\|*')
    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    foreach ($n in 'WUServer', 'WUStatusServer', 'UpdateServiceUrlAlternate', 'DoNotConnectToWindowsUpdateInternetLocations',
                   'SetDisableUXWUAccess', 'ExcludeWUDriversInQualityUpdate', 'SetActiveHours', 'ActiveHoursStart', 'ActiveHoursEnd') {
        Remove-ItemProperty -Path $wu -Name $n -ErrorAction SilentlyContinue
    }
    foreach ($n in 'UseWUServer', 'NoAutoUpdate', 'AUOptions', 'NoAutoRebootWithLoggedOnUsers') {
        Remove-ItemProperty -Path "$wu\AU" -Name $n -ErrorAction SilentlyContinue
    }
    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' -Name 'AutoDownload' -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\VSCode' -Name 'UpdateMode' -ErrorAction SilentlyContinue
    foreach ($n in 'PauseUpdatesStartTime', 'PauseUpdatesExpiryTime', 'PauseFeatureUpdatesStartTime', 'PauseFeatureUpdatesEndTime',
                   'PauseQualityUpdatesStartTime', 'PauseQualityUpdatesEndTime') {
        Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name $n -ErrorAction SilentlyContinue
    }
    Write-Host "[OK] Update policies removed (no backup found, Windows defaults used)." -ForegroundColor Green
}

$svcLines  = ($svcStart.Keys | ForEach-Object { "'$_'=$($svcStart[$_])" }) -join '; '
$taskLines = ($tasksToEnable | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ','
$sysScript = @"
`$svc = @{ $svcLines }
foreach (`$name in `$svc.Keys) {
    `$k = "HKLM:\SYSTEM\CurrentControlSet\Services\`$name"
    if (Test-Path `$k) {
        try { Set-ItemProperty -Path `$k -Name Start -Value ([int]`$svc[`$name]) -Type DWord -ErrorAction Stop; "SVC|OK|`$name" } catch { "SVC|FAIL|`$name" }
    }
}
foreach (`$entry in @($taskLines)) {
    if (-not `$entry) { continue }
    `$parts = `$entry.Split('|')
    foreach (`$t in @(Get-ScheduledTask -TaskPath `$parts[0] -TaskName `$parts[1] -ErrorAction SilentlyContinue)) {
        try { Enable-ScheduledTask -InputObject `$t -ErrorAction Stop | Out-Null } catch { }
    }
}
try { Start-Service -Name wuauserv -ErrorAction Stop } catch { }
"@
$out = Invoke-AsSystem -ScriptText $sysScript
$failed = @($out | Where-Object { "$_" -like 'SVC|FAIL|*' })
if ($failed.Count -eq 0) { Write-Host "[OK] Windows Update services and tasks restored." -ForegroundColor Green }
else { Write-Host "[WARNING] Some services could not be restored: $($failed -join ', ')" -ForegroundColor Yellow }

# 3. Auto-logon ---------------------------------------------------
Write-Host "[INFO] Disabling Windows Auto-Logon..." -ForegroundColor Yellow
$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "0" -Type String -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
Write-Host "[OK] Auto-Logon disabled." -ForegroundColor Green

# 4. Contest accounts + profiles ------------------------------------
Write-Host "[INFO] Scanning for contest user accounts..." -ForegroundColor Yellow
$targetUsers = @(Get-LocalUser | Where-Object { $_.Name -eq $Username -or $_.Name -like "ICPCLK26_*" })
if ($targetUsers.Count -eq 0) { Write-Host "[NOTE] No contest users found to remove." -ForegroundColor Gray }
foreach ($user in $targetUsers) {
    $uName = $user.Name
    $sid = $user.SID.Value
    $prof = Get-CimInstance -ClassName Win32_UserProfile -Filter "SID='$sid'" -ErrorAction SilentlyContinue
    if ($prof) {
        if ($prof.Loaded) {
            Write-Host "[WARNING] '$uName' is still logged in. Sign it out (or reboot) and run cleanup again." -ForegroundColor Yellow
            continue
        }
        try {
            Remove-CimInstance -InputObject $prof -ErrorAction Stop     # deletes folder + registry entry
            Write-Host "[OK] Profile '$($prof.LocalPath)' removed." -ForegroundColor Green
        } catch {
            Write-Host "[WARNING] Could not remove profile of '$uName': $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    try {
        Remove-LocalUser -Name $uName -ErrorAction Stop
        Write-Host "[OK] Local user '$uName' deleted." -ForegroundColor Green
    } catch {
        Write-Host "[WARNING] Could not delete user '$uName': $_" -ForegroundColor Yellow
    }
    $leftover = Join-Path $script:UsersRoot $uName
    if (Test-Path -LiteralPath $leftover) { cmd.exe /c "rmdir /s /q `"$leftover`"" 2>$null }
}
# Folders renamed by setup because they were orphaned
Get-ChildItem -LiteralPath $script:UsersRoot -Directory -Filter '*.stale-*' -ErrorAction SilentlyContinue | ForEach-Object {
    cmd.exe /c "rmdir /s /q `"$($_.FullName)`"" 2>$null
}

# 5. Wi-Fi ----------------------------------------------------------
Write-Host "[INFO] Re-enabling Wireless / Wi-Fi network adapters..." -ForegroundColor Yellow
$wifiAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
    $_.PhysicalMediaType -match "Wireless|Native 802.11" -or
    $_.InterfaceDescription -match "Wireless|Wi-Fi|802.11|WLAN" -or
    $_.Name -match "Wi-Fi|Wireless|WLAN"
}
foreach ($adapter in @($wifiAdapters)) {
    if (-not $adapter) { continue }
    try {
        Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
        Write-Host "[OK] Re-enabled Wi-Fi adapter: $($adapter.Name)" -ForegroundColor Green
    } catch {
        Write-Host "[NOTE] Could not re-enable $($adapter.Name): $_" -ForegroundColor Gray
    }
}

# 6. Leftover ICPC files ------------------------------------------
$defaultSettings = Join-Path $env:SystemDrive 'Users\Default\AppData\Roaming\Code\User\settings.json'
if ((Test-Path -LiteralPath $defaultSettings) -and ((Get-Content -LiteralPath $defaultSettings -Raw) -match 'code-runner\.runInTerminal')) {
    Remove-Item -LiteralPath $defaultSettings -Force -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath $script:IcpcDataDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[OK] ICPC cache and backups removed." -ForegroundColor Green

Write-Host "==========================================" -ForegroundColor Green
Write-Host " Workstation restored to normal lab state." -ForegroundColor Green
Write-Host " Restart the PC to finish restoring all services." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
