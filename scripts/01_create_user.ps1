<#
.SYNOPSIS
    Creates and locks down a standard contestant user account for ICPC.
.DESCRIPTION
    - If -PcNumber (1-60) is provided, automatically looks up the official team username,
      password, team name, and university from 'contestant_credentials.csv'.
    - If -PcNumber is omitted, defaults to a universal 'contestant' account.
    - Ensures user is NOT an administrator (Standard User only).
    - Sets password to never expire and prevents user from changing password.
    - Configures optional Windows Auto-Login for seamless contest morning startup.
#>

param(
    [int]$PcNumber = 0,
    [string]$Username = "contestant",
    [string]$Password = "ICPC2026!UoP",
    [bool]$EnableAutoLogin = $false
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$csvPath = Join-Path $repoRoot "contestant_credentials.csv"

$fullName = "ICPC Contestant"

# If PcNumber is specified (1-60), lookup official team credentials
if ($PcNumber -ge 1 -and $PcNumber -le 60 -and (Test-Path $csvPath)) {
    $targetSeat = "PC-{0:D2}" -f $PcNumber
    $csvData = Import-Csv -Path $csvPath
    $matched = $csvData | Where-Object { $_.seat -eq $targetSeat } | Select-Object -First 1

    if ($null -ne $matched) {
        $Username = $matched.username
        $Password = $matched.password
        $fullName = "$($matched.team_name) ($($matched.institution))"
        Write-Host "[INFO] Mapped to $targetSeat : $Username | $($matched.team_name)" -ForegroundColor Magenta
    }
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Step 1] Managing Contestant Account: $Username" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$secPassword = ConvertTo-SecureString $Password -AsPlainText -Force

# 1. Create or update user account
$existingUser = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue

if ($null -ne $existingUser) {
    Write-Host "[INFO] User '$Username' already exists. Updating password..." -ForegroundColor Yellow
    Set-LocalUser -Name $Username -Password $secPassword
    Set-LocalUser -Name $Username -PasswordNeverExpires $true -UserMayNotChangePassword $true
    Write-Host "[OK] Existing user '$Username' password updated." -ForegroundColor Green
}
else {
    Write-Host "[INFO] Creating new local user '$Username'..." -ForegroundColor Yellow
    New-LocalUser -Name $Username `
        -Password $secPassword `
        -FullName $fullName `
        -Description "Official contestant account for ICPC 2026" `
        -PasswordNeverExpires `
        -UserMayNotChangePassword
    Write-Host "[OK] User '$Username' created successfully." -ForegroundColor Green
}

# 2. Enforce Group Membership (Standard User only)
Write-Host "[INFO] Enforcing standard user permissions..." -ForegroundColor Yellow

# Ensure added to Users group
try {
    Add-LocalGroupMember -Group "Users" -Member $Username -ErrorAction SilentlyContinue
}
catch {
    # Ignored if already member
}

# Strictly remove from Administrators group if present
try {
    $adminMembers = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue
    if ($adminMembers.Name -contains $Username -or $adminMembers.PrincipalSource -contains $Username) {
        Remove-LocalGroupMember -Group "Administrators" -Member $Username -ErrorAction SilentlyContinue
        Write-Host "[OK] Removed '$Username' from Administrators group." -ForegroundColor Green
    }
}
catch {
    Write-Host "[NOTE] '$Username' is not an Administrator." -ForegroundColor Gray
}

# 3. Optional Auto-Logon Configuration
if ($EnableAutoLogin) {
    Write-Host "[INFO] Configuring Windows Auto-Logon for '$Username'..." -ForegroundColor Yellow
    $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    
    Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "1" -Type String
    Set-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -Value $Username -Type String
    Set-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -Value $Password -Type String
    Set-ItemProperty -Path $winlogonPath -Name "DefaultDomainName" -Value $env:COMPUTERNAME -Type String
    
    Write-Host "[OK] Auto-Logon enabled. Machine will log directly into '$Username' on reboot." -ForegroundColor Green
}
else {
    Write-Host "[INFO] Auto-Logon is currently disabled. (Set -EnableAutoLogin `$true to enable)." -ForegroundColor Gray
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Account setup completed for : $Username" -ForegroundColor Green
Write-Host " Full Name / Team Name       : $fullName" -ForegroundColor Green
Write-Host " Password                    : $Password" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
