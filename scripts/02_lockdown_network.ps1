<#
.SYNOPSIS
    Prepares workstation networking for an internet-free ICPC contest.
.DESCRIPTION
    - Turns OFF Windows Firewall across all profiles (Domain, Private, Public) so local
      contest traffic (DOMjudge, printing, etc.) is never blocked by Windows Firewall.
    - Scans for and disables any Wireless / Wi-Fi network adapters to enforce wired LAN only.
    - Stops and disables Windows Update services and policies to prevent popups or reboots.
#>

param(
    [string]$ServerIP = "192.168.1.100"
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Network Lockdown] Configuring Lab PC" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "[INFO] Assigned DOMjudge Server IP: $ServerIP" -ForegroundColor Yellow

# 1. Clean up any older custom ICPC firewall rules
Write-Host "[INFO] Cleaning up any older ICPC firewall rules..." -ForegroundColor Yellow
Remove-NetFirewallRule -DisplayName "ICPC-*" -ErrorAction SilentlyContinue

# 2. Turn OFF Windows Firewall across all profiles
Write-Host "[INFO] Turning OFF Windows Firewall (Domain, Private, Public)..." -ForegroundColor Yellow
try {
    Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False -ErrorAction Stop
    Write-Host "  [OK] Windows Firewall is now OFF on all profiles." -ForegroundColor Green
} catch {
    Write-Host "  [WARNING] Failed via Set-NetFirewallProfile, trying netsh..." -ForegroundColor Yellow
    netsh advfirewall set allprofiles state off | Out-Null
    Write-Host "  [OK] Windows Firewall turned OFF via netsh." -ForegroundColor Green
}

# 3. Check and Disable Wireless (Wi-Fi) Network Adapters
Write-Host "[INFO] Scanning for Wireless / Wi-Fi network adapters..." -ForegroundColor Yellow
$wifiAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
    $_.PhysicalMediaType -match "Wireless|Native 802.11" -or
    $_.InterfaceDescription -match "Wireless|Wi-Fi|802.11|WLAN" -or
    $_.Name -match "Wi-Fi|Wireless|WLAN"
}

if ($wifiAdapters) {
    foreach ($adapter in $wifiAdapters) {
        Write-Host "  [DETECTED] Wireless Adapter: $($adapter.Name) ($($adapter.InterfaceDescription))" -ForegroundColor Red
        if ($adapter.Status -ne "Disabled") {
            try {
                Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
                Write-Host "  [DISABLED] $($adapter.Name) has been disabled to enforce wired LAN only." -ForegroundColor Green
            } catch {
                Write-Host "  [WARNING] Could not disable $($adapter.Name): $_" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [INFO] $($adapter.Name) is already disabled." -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  [OK] No Wi-Fi adapters detected (Wired Ethernet only)." -ForegroundColor Green
}

# 4. Stop and Disable Windows Updates during the contest
Write-Host "[INFO] Disabling Windows Update services and policies..." -ForegroundColor Yellow
$wuServices = @("wuauserv", "DoSvc", "UsoSvc", "WaaSMedicSvc")
foreach ($svc in $wuServices) {
    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
    Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
}
$wuPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (-not (Test-Path $wuPolicyPath)) {
    New-Item -Path $wuPolicyPath -Force | Out-Null
}
Set-ItemProperty -Path $wuPolicyPath -Name "NoAutoUpdate" -Value 1 -Type DWord
Set-ItemProperty -Path $wuPolicyPath -Name "AUOptions" -Value 2 -Type DWord
Write-Host "  [OK] Windows Update disabled." -ForegroundColor Green

Write-Host "==========================================" -ForegroundColor Green
Write-Host " Network lockdown completed!" -ForegroundColor Green
Write-Host " - Windows Firewall: OFF" -ForegroundColor Green
Write-Host " - Wi-Fi Adapters  : DISABLED" -ForegroundColor Green
Write-Host " - Windows Update  : DISABLED" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
