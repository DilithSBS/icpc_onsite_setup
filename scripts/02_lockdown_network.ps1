<#
.SYNOPSIS
    Locks down network access on Windows workstations for an offline ICPC contest.
.DESCRIPTION
    - Turns ON Windows Firewall across all profiles (Domain, Private, Public).
    - Sets Default Outbound Action to BLOCK (stops all internet access).
    - Whitelists only:
        * Local Contest Subnet / Server IP (DOMjudge, PC^2, local printing server)
        * DHCP (Ports 67, 68 UDP) so the machine retains its IP address
        * ICMPv4 (Ping) to local subnet for diagnosis
        * Loopback (127.0.0.1) for local processes
.NOTES
    Modify $ContestSubnet and $ServerIP to match your lab's network plan.
#>

param(
    # The local subnet of the lab where the contest server is hosted
    [string]$ContestSubnet = "192.168.1.0/24",

    # Specific Contest Server IP (DOMjudge / PC^2 / Kattis Local)
    [string]$ServerIP = "192.168.1.100",

    # Optional printing server or secondary server IP if applicable
    [string]$PrintServerIP = ""
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Step 2] Applying Offline Network Lockdown" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Write-Host "[INFO] Local Lab Subnet: $ContestSubnet" -ForegroundColor Gray
Write-Host "[INFO] Contest Server IP: $ServerIP" -ForegroundColor Gray

# 1. Ensure Windows Firewall Service (MpsSvc) is running
$fwService = Get-Service -Name "mpssvc" -ErrorAction SilentlyContinue
if ($fwService.Status -ne "Running") {
    Write-Host "[INFO] Starting Windows Firewall service..." -ForegroundColor Yellow
    Set-Service -Name "mpssvc" -StartupType Automatic
    Start-Service -Name "mpssvc"
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

# Allow communication to Contest Subnet (Web, DOMjudge, SSH, Local printing)
Write-Host "[INFO] Adding Rule: Allow Contest Subnet ($ContestSubnet)..." -ForegroundColor Yellow
New-NetFirewallRule -DisplayName "ICPC-Allow-Subnet" `
                    -Direction Outbound `
                    -Action Allow `
                    -RemoteAddress $ContestSubnet `
                    -Description "ICPC: Communication with local contest network" | Out-Null

# Allow ICMP Echo Request (Ping) inside the subnet
Write-Host "[INFO] Adding Rule: Allow ICMP Echo (Ping) to Subnet..." -ForegroundColor Yellow
New-NetFirewallRule -DisplayName "ICPC-Allow-ICMP-Ping" `
                    -Direction Outbound `
                    -Action Allow `
                    -Protocol ICMPv4 `
                    -RemoteAddress $ContestSubnet `
                    -Description "ICPC: Ping server for diagnostics" | Out-Null

if (-not [string]::IsNullOrWhiteSpace($PrintServerIP)) {
    Write-Host "[INFO] Adding Rule: Allow Print Server ($PrintServerIP)..." -ForegroundColor Yellow
    New-NetFirewallRule -DisplayName "ICPC-Allow-PrintServer" `
                        -Direction Outbound `
                        -Action Allow `
                        -RemoteAddress $PrintServerIP `
                        -Description "ICPC: Print server communication" | Out-Null
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host " Network lockdown successfully applied!" -ForegroundColor Green
Write-Host " - All Internet and external WAN traffic is BLOCKED." -ForegroundColor Green
Write-Host " - Only traffic to $ContestSubnet is PERMITTED." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

