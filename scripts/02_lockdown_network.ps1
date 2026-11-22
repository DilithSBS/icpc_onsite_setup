<#
.SYNOPSIS
    Locks down network access on Windows workstations for an offline ICPC contest.
.DESCRIPTION
    - Turns ON Windows Firewall across all profiles (Domain, Private, Public).
    - Sets Default Outbound Action to BLOCK (stops all internet access).
    - Whitelists ONLY:
        * The specific DOMjudge / Contest Server IP address (HTTP/HTTPS/API)
        * DHCP (Ports 67, 68 UDP) so the machine retains its IP address from the router/switch
        * ICMPv4 (Ping) ONLY to the DOMjudge server for connectivity diagnostics
        * Loopback (127.0.0.1) for local processes
    - By restricting traffic exclusively to $ServerIP, contestant PCs cannot even talk to each
      other across the local LAN, preventing inter-team cheating.
.NOTES
    Set $ServerIP to match your DOMjudge server's exact IP address.
#>

param(
    # The exact IP address of your DOMjudge / Contest Server
    [string]$ServerIP = "192.168.1.100",

    # Set to $true to restrict traffic ONLY to $ServerIP (Highest Security).
    # Set to $false to allow the entire local subnet.
    [bool]$StrictServerOnly = $true,

    # Local subnet (only used if $StrictServerOnly is $false)
    [string]$ContestSubnet = "192.168.1.0/24",

    # Optional printing server IP if your lab has a network printer queue
    [string]$PrintServerIP = ""
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Step 2] Applying Offline Network Lockdown" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Write-Host "[INFO] Target DOMjudge Server IP : $ServerIP" -ForegroundColor Yellow
if ($StrictServerOnly) {
    Write-Host "[INFO] Security Mode            : STRICT (DOMjudge Server ONLY - No other LAN/PCs allowed)" -ForegroundColor Magenta
} else {
    Write-Host "[INFO] Security Mode            : SUBNET ($ContestSubnet)" -ForegroundColor Gray
}

# 1. Ensure Windows Firewall Service (MpsSvc) is running
$fwService = Get-Service -Name "mpssvc" -ErrorAction SilentlyContinue
if ($fwService.Status -ne "Running") {
    Write-Host "[INFO] Starting Windows Firewall service..." -ForegroundColor Yellow
    Set-Service -Name "mpssvc" -StartupType Automatic
    Start-Service -Name "mpssvc"
}

# 1.1 Check and Disable Wireless (Wi-Fi) Network Adapters
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

# 2. Clean up any existing ICPC rules
Write-Host "[INFO] Cleaning up older ICPC firewall rules..." -ForegroundColor Yellow
Remove-NetFirewallRule -DisplayName "ICPC-*" -ErrorAction SilentlyContinue

# 3. Enable Firewall for all network profiles
Write-Host "[INFO] Enabling Windows Firewall on Domain, Private, and Public profiles..." -ForegroundColor Yellow
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True

# 4. Set default policies: Block Outbound, Block Inbound
Write-Host "[INFO] Setting Outbound Default Policy to BLOCK..." -ForegroundColor Yellow
Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Block -DefaultInboundAction Block

# Disable built-in outbound Echo Request rules to prevent external ping leaks
Write-Host "[INFO] Disabling built-in outbound ICMP rules..." -ForegroundColor Yellow
Get-NetFirewallRule | Where-Object { $_.Direction -eq "Outbound" -and $_.DisplayName -like "*Echo Request*" } | Disable-NetFirewallRule -ErrorAction SilentlyContinue

# 5. Add Whitelist Rules

# Allow DHCP so workstation maintains LAN IP from local router/switch
Write-Host "[INFO] Adding Rule: Allow DHCP (UDP 67/68)..." -ForegroundColor Yellow
New-NetFirewallRule -DisplayName "ICPC-Allow-DHCP" `
                    -Direction Outbound `
                    -Action Allow `
                    -Protocol UDP `
                    -LocalPort 68 `
                    -RemotePort 67 `
                    -Description "ICPC: Retain DHCP lease" | Out-Null

# Allow Loopback (127.0.0.1)
Write-Host "[INFO] Adding Rule: Allow Localhost Loopback..." -ForegroundColor Yellow
New-NetFirewallRule -DisplayName "ICPC-Allow-Loopback" `
                    -Direction Outbound `
                    -Action Allow `
                    -RemoteAddress "127.0.0.1" `
                    -Description "ICPC: Localhost processes" | Out-Null

if ($StrictServerOnly) {
    # Highest security: Allow outbound communication ONLY to the specific DOMserver IP
    Write-Host "[INFO] Adding Rule: Allow Traffic ONLY to DOMjudge Server ($ServerIP)..." -ForegroundColor Green
    New-NetFirewallRule -DisplayName "ICPC-Allow-DOMServer" `
                        -Direction Outbound `
                        -Action Allow `
                        -RemoteAddress $ServerIP `
                        -Description "ICPC: Allow traffic exclusively to DOMjudge server" | Out-Null

    # Allow ICMP Echo (Ping) ONLY to DOMjudge server for test diagnostics
    Write-Host "[INFO] Adding Rule: Allow Ping ONLY to DOMjudge Server ($ServerIP)..." -ForegroundColor Green
    New-NetFirewallRule -DisplayName "ICPC-Allow-ICMP-DOMServer" `
                        -Direction Outbound `
                        -Action Allow `
                        -Protocol ICMPv4 `
                        -RemoteAddress $ServerIP `
                        -Description "ICPC: Ping DOMjudge server for diagnostics" | Out-Null
} else {
    # Subnet mode: Allow communication to the entire subnet
    Write-Host "[INFO] Adding Rule: Allow Entire Subnet ($ContestSubnet)..." -ForegroundColor Yellow
    New-NetFirewallRule -DisplayName "ICPC-Allow-Subnet" `
                        -Direction Outbound `
                        -Action Allow `
                        -RemoteAddress $ContestSubnet `
                        -Description "ICPC: Communication with local contest network" | Out-Null

    New-NetFirewallRule -DisplayName "ICPC-Allow-ICMP-Ping" `
                        -Direction Outbound `
                        -Action Allow `
                        -Protocol ICMPv4 `
                        -RemoteAddress $ContestSubnet `
                        -Description "ICPC: Ping subnet for diagnostics" | Out-Null
}

# Optional Print Server rule
if (-not [string]::IsNullOrWhiteSpace($PrintServerIP)) {
    Write-Host "[INFO] Adding Rule: Allow Print Server ($PrintServerIP)..." -ForegroundColor Yellow
    New-NetFirewallRule -DisplayName "ICPC-Allow-PrintServer" `
                        -Direction Outbound `
                        -Action Allow `
                        -RemoteAddress $PrintServerIP `
                        -Description "ICPC: Print server communication" | Out-Null
}

# 6. Stop and Disable Windows Updates during the contest
Write-Host "[INFO] Disabling Windows Update services & policies..." -ForegroundColor Yellow
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
Write-Host "[OK] Windows Update disabled." -ForegroundColor Green

Write-Host "==========================================" -ForegroundColor Green
Write-Host " Network lockdown successfully applied!" -ForegroundColor Green
Write-Host " - All Internet, WAN, and peer PC communication is BLOCKED." -ForegroundColor Green
Write-Host " - Outbound traffic is PERMITTED ONLY to DOMserver: $ServerIP" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
