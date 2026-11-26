<#
.SYNOPSIS
    Locks down network access for the offline ICPC contest (applies to EVERY account on the PC,
    including the contestant account).
.DESCRIPTION
    Why the old version did not block anything:
      1. RUN_SETUP.bat called this script with  -StrictServerOnly $true . With "powershell -File"
         that arrives as the TEXT "$true", which a [bool] parameter rejects, so the script stopped
         before running a single line (and Windows Update blocking, which lived here, never ran).
      2. It relied only on "default outbound = Block". In Windows Firewall any enabled ALLOW rule
         (built-in Windows rules, rules added by installed apps, or rules from Group Policy) still
         lets traffic out, so browsers could still reach the internet.
    Now:
      - Default inbound/outbound = Block on all profiles.
      - Explicit BLOCK rules for TCP, UDP and ICMP to every address except the DOMjudge server
        (and loopback). Block rules beat allow rules, so other rules can no longer open a hole.
      - Allow rules only for: DOMjudge server, DHCP (keeps the IP lease), loopback.
      - Wi-Fi adapters are disabled.
      - The original firewall policy is exported once to C:\ProgramData\ICPC\backup so
        RUN_CLEANUP.bat can restore it exactly.
      - Warns if Group Policy overrides the local firewall settings.
#>

param(
    # The exact IPv4 address of your DOMjudge / Contest Server
    [string]$ServerIP = "192.168.1.100",

    # "true" (default) = traffic ONLY to $ServerIP. "false" = allow the whole $ContestSubnet.
    # (String on purpose: it is passed from a .bat file, where real booleans do not exist.)
    [string]$StrictServerOnly = "true",

    # Local subnet (only used when StrictServerOnly is false)
    [string]$ContestSubnet = "192.168.1.0/24",

    # Optional print server IPv4 address
    [string]$PrintServerIP = ""
)

. "$PSScriptRoot\common.ps1"

$strict = $StrictServerOnly -notmatch '^(0|false|\$false|no|n)$'
$errors = 0

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Step 3] Applying Offline Network Lockdown" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# ---------- validate input ----------
function Test-IPv4([string]$s) {
    $ip = $null
    return ([ipaddress]::TryParse($s, [ref]$ip) -and $ip.AddressFamily -eq 'InterNetwork' -and $s -match '^\d+\.\d+\.\d+\.\d+$')
}
if (-not (Test-IPv4 $ServerIP)) {
    Write-Host "[ERROR] '$ServerIP' is not a valid IPv4 address. Fix DOMSERVER_IP in RUN_SETUP.bat." -ForegroundColor Red
    exit 1
}
if ($PrintServerIP -and -not (Test-IPv4 $PrintServerIP)) {
    Write-Host "[ERROR] PrintServerIP '$PrintServerIP' is not a valid IPv4 address." -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Target DOMjudge Server IP : $ServerIP" -ForegroundColor Yellow
if ($strict) { Write-Host "[INFO] Security Mode            : STRICT (DOMjudge server only - no internet, no other PCs)" -ForegroundColor Magenta }
else { Write-Host "[INFO] Security Mode            : SUBNET ($ContestSubnet)" -ForegroundColor Gray }

# ---------- address maths: everything EXCEPT the allowed IPv4 ranges ----------
function ConvertTo-IPNum([string]$ip) {
    $b = ([ipaddress]$ip).GetAddressBytes()
    return ([uint64]$b[0] * 16777216) + ([uint64]$b[1] * 65536) + ([uint64]$b[2] * 256) + [uint64]$b[3]
}
function ConvertFrom-IPNum([uint64]$n) {
    return '{0}.{1}.{2}.{3}' -f [math]::Floor($n / 16777216), ([math]::Floor($n / 65536) % 256), ([math]::Floor($n / 256) % 256), ($n % 256)
}
function Get-IPv4Interval([string]$spec) {
    if ($spec -match '^(\d+\.\d+\.\d+\.\d+)/(\d+)$') {
        $len = [int]$Matches[2]
        $size = [uint64][math]::Pow(2, 32 - $len)
        $start = [uint64]([math]::Floor((ConvertTo-IPNum $Matches[1]) / $size) * $size)
        return , @($start, ($start + $size - 1))
    }
    $n = ConvertTo-IPNum $spec
    return , @($n, $n)
}
function Get-IPv4Complement([string[]]$AllowedSpecs) {
    $iv = @(@($AllowedSpecs | ForEach-Object { , (Get-IPv4Interval $_) }) | Sort-Object { $_[0] })
    $result = @()
    [uint64]$cursor = 0
    foreach ($i in $iv) {
        if ($i[0] -gt $cursor) {
            $a = ConvertFrom-IPNum $cursor; $b = ConvertFrom-IPNum ($i[0] - 1)
            $result += $(if ($a -eq $b) { $a } else { "$a-$b" })
        }
        if ($i[1] + 1 -gt $cursor) { $cursor = $i[1] + 1 }
    }
    if ($cursor -le 4294967295) { $result += "$(ConvertFrom-IPNum $cursor)-255.255.255.255" }
    return $result
}

$allowedV4 = @('0.0.0.0/8', '127.0.0.0/8')   # 0.x is unroutable; 127.x is this PC
if ($strict) { $allowedV4 += $ServerIP } else { $allowedV4 += $ContestSubnet; $allowedV4 += $ServerIP }
if ($PrintServerIP) { $allowedV4 += $PrintServerIP }
$blockV4 = @(Get-IPv4Complement $allowedV4)
$blockV6 = @('::2-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff')   # all IPv6 except :: and ::1 (loopback)
Write-Host "[INFO] Blocked IPv4 ranges: $($blockV4 -join ', ')" -ForegroundColor Gray

# ---------- 1. firewall service ----------
$fwService = Get-Service -Name "mpssvc" -ErrorAction SilentlyContinue
if ($fwService -and $fwService.Status -ne "Running") {
    Write-Host "[INFO] Starting Windows Firewall service..." -ForegroundColor Yellow
    Set-Service -Name "mpssvc" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name "mpssvc" -ErrorAction SilentlyContinue
}

# ---------- 2. back up the original firewall policy (once) ----------
New-Item -ItemType Directory -Path $script:IcpcBackupDir -Force | Out-Null
$fwBackup = Join-Path $script:IcpcBackupDir 'firewall.wfw'
if (-not (Test-Path -LiteralPath $fwBackup)) {
    netsh advfirewall export "$fwBackup" | Out-Null
    if (Test-Path -LiteralPath $fwBackup) { Write-Host "[OK] Original firewall policy backed up to $fwBackup" -ForegroundColor Green }
    else { Write-Host "[WARNING] Could not back up the firewall policy; cleanup will fall back to a factory reset." -ForegroundColor Yellow }
} else {
    Write-Host "[INFO] Firewall backup already exists (kept from the first run)." -ForegroundColor Gray
}

# ---------- 3. Wi-Fi ----------
Write-Host "[INFO] Scanning for Wireless / Wi-Fi network adapters..." -ForegroundColor Yellow
$wifiAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
    $_.PhysicalMediaType -match "Wireless|Native 802.11" -or
    $_.InterfaceDescription -match "Wireless|Wi-Fi|802.11|WLAN" -or
    $_.Name -match "Wi-Fi|Wireless|WLAN"
}
if ($wifiAdapters) {
    foreach ($adapter in $wifiAdapters) {
        if ($adapter.Status -ne "Disabled") {
            try {
                Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
                Write-Host "  [DISABLED] $($adapter.Name) ($($adapter.InterfaceDescription))" -ForegroundColor Green
            } catch {
                Write-Host "  [WARNING] Could not disable $($adapter.Name): $_" -ForegroundColor Yellow
                $errors++
            }
        } else {
            Write-Host "  [INFO] $($adapter.Name) is already disabled." -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  [OK] No Wi-Fi adapters detected." -ForegroundColor Green
}

# ---------- 4. profiles ----------
Write-Host "[INFO] Removing older ICPC rules..." -ForegroundColor Yellow
Remove-NetFirewallRule -DisplayName "ICPC-*" -ErrorAction SilentlyContinue

Write-Host "[INFO] Firewall ON, default inbound + outbound = BLOCK on all profiles..." -ForegroundColor Yellow
Set-NetFirewallProfile -Profile Domain, Private, Public -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Block

# ---------- 5. rules ----------
function Add-IcpcRule([hashtable]$p) {
    try {
        New-NetFirewallRule @p -Profile Any -Enabled True -ErrorAction Stop | Out-Null
        Write-Host "  [OK] $($p.DisplayName)" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] $($p.DisplayName): $($_.Exception.Message)" -ForegroundColor Red
        $script:errors++
    }
}

Write-Host "[INFO] Adding BLOCK rules (these override any other allow rule on the PC)..." -ForegroundColor Yellow
Add-IcpcRule @{ DisplayName = 'ICPC-Block-TCP';    Direction = 'Outbound'; Action = 'Block'; Protocol = 'TCP';    RemoteAddress = ($blockV4 + $blockV6); Description = 'ICPC: block all TCP except contest server' }
Add-IcpcRule @{ DisplayName = 'ICPC-Block-UDP';    Direction = 'Outbound'; Action = 'Block'; Protocol = 'UDP';    RemoteAddress = ($blockV4 + $blockV6); RemotePort = @('1-66', '68-65535'); Description = 'ICPC: block all UDP (incl. DNS) except DHCP and contest server' }
Add-IcpcRule @{ DisplayName = 'ICPC-Block-ICMPv4'; Direction = 'Outbound'; Action = 'Block'; Protocol = 'ICMPv4'; RemoteAddress = $blockV4; Description = 'ICPC: block ping except contest server' }
Add-IcpcRule @{ DisplayName = 'ICPC-Block-ICMPv6'; Direction = 'Outbound'; Action = 'Block'; Protocol = 'ICMPv6'; RemoteAddress = $blockV6; Description = 'ICPC: block IPv6 ping' }

Write-Host "[INFO] Adding ALLOW rules..." -ForegroundColor Yellow
Add-IcpcRule @{ DisplayName = 'ICPC-Allow-DHCP';     Direction = 'Outbound'; Action = 'Allow'; Protocol = 'UDP'; LocalPort = 68; RemotePort = 67; Description = 'ICPC: keep DHCP lease' }
Add-IcpcRule @{ DisplayName = 'ICPC-Allow-Loopback'; Direction = 'Outbound'; Action = 'Allow'; RemoteAddress = @('127.0.0.0/8', '::1'); Description = 'ICPC: localhost' }
if ($strict) {
    Add-IcpcRule @{ DisplayName = 'ICPC-Allow-DOMServer'; Direction = 'Outbound'; Action = 'Allow'; RemoteAddress = $ServerIP; Description = 'ICPC: DOMjudge server (all protocols incl. ping)' }
} else {
    Add-IcpcRule @{ DisplayName = 'ICPC-Allow-Subnet'; Direction = 'Outbound'; Action = 'Allow'; RemoteAddress = @($ContestSubnet, $ServerIP); Description = 'ICPC: contest subnet' }
}
if ($PrintServerIP) {
    Add-IcpcRule @{ DisplayName = 'ICPC-Allow-PrintServer'; Direction = 'Outbound'; Action = 'Allow'; RemoteAddress = $PrintServerIP; Description = 'ICPC: print server' }
}

# ---------- 6. is Group Policy overriding us? ----------
Write-Host "[INFO] Checking the EFFECTIVE firewall policy (incl. Group Policy)..." -ForegroundColor Yellow
foreach ($prof in Get-NetFirewallProfile -PolicyStore ActiveStore -ErrorAction SilentlyContinue) {
    if ($prof.Enabled -ne 'True') {
        Write-Host "  [ERROR] $($prof.Name) profile: firewall is OFF in the effective policy (Group Policy?)." -ForegroundColor Red; $errors++
    }
    if ($prof.DefaultOutboundAction -ne 'Block') {
        Write-Host "  [WARNING] $($prof.Name) profile: effective default outbound is '$($prof.DefaultOutboundAction)' (Group Policy). The ICPC block rules still apply." -ForegroundColor Yellow
    }
    if ($prof.AllowLocalFirewallRules -eq 'False') {
        Write-Host "  [ERROR] $($prof.Name) profile: Group Policy ignores local firewall rules - the lockdown CANNOT work. Ask IT to exclude the lab PCs or unplug the internet uplink." -ForegroundColor Red; $errors++
    }
}
$activeBlock = @(Get-NetFirewallRule -PolicyStore ActiveStore -DisplayName 'ICPC-Block-*' -ErrorAction SilentlyContinue).Count
if ($activeBlock -lt 4) { Write-Host "  [ERROR] Only $activeBlock of 4 ICPC block rules are active." -ForegroundColor Red; $errors++ }
else { Write-Host "  [OK] All ICPC block rules are active." -ForegroundColor Green }

Write-Host "==========================================" -ForegroundColor Green
if ($errors -eq 0) {
    Write-Host " Network lockdown applied (all accounts on this PC)." -ForegroundColor Green
    Write-Host " - Internet, DNS and other lab PCs: BLOCKED" -ForegroundColor Green
    Write-Host " - Allowed: DOMjudge server $ServerIP, DHCP, localhost" -ForegroundColor Green
} else {
    Write-Host " Network lockdown finished with $errors ERROR(S) - see above." -ForegroundColor Red
}
Write-Host "==========================================" -ForegroundColor Green
exit $errors
