<#
.SYNOPSIS
    Creates and locks down a standard contestant user account for ICPC, and builds its profile.
.DESCRIPTION
    - If -PcNumber (1-60) is provided, looks up the official team username, password, team name
      and university from 'contestant_credentials.csv'. Otherwise uses the generic 'contestant'.
    - Standard User only (removed from Administrators). Password never expires / cannot be changed.
    - Creates the Windows profile (C:\Users\<name>) NOW instead of at first logon, so the next steps
      can put VS Code settings, extensions and the desktop workspace directly into the account.
    - Optional Windows Auto-Login.
#>

param(
    [int]$PcNumber = 0,
    [string]$Username = "contestant",
    [string]$Password = "ICPC2026!UoP",
    [bool]$EnableAutoLogin = $false
)

. "$PSScriptRoot\common.ps1"

$acct = Resolve-ContestAccount -PcNumber $PcNumber -Username $Username -Password $Password
$Username = $acct.Username
$Password = $acct.Password
$fullName = $acct.FullName
if ($acct.Seat) { Write-Host "[INFO] Mapped to $($acct.Seat) : $Username | $fullName" -ForegroundColor Magenta }

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Step 2] Managing Contestant Account: $Username" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$secPassword = ConvertTo-SecureString $Password -AsPlainText -Force

# 1. Create or update user account
$existingUser = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
try {
    if ($null -ne $existingUser) {
        Write-Host "[INFO] User '$Username' already exists. Updating password..." -ForegroundColor Yellow
        Set-LocalUser -Name $Username -Password $secPassword -PasswordNeverExpires $true -UserMayChangePassword $false -ErrorAction Stop
        Enable-LocalUser -Name $Username -ErrorAction SilentlyContinue
        Write-Host "[OK] Existing user '$Username' updated." -ForegroundColor Green
    }
    else {
        Write-Host "[INFO] Creating new local user '$Username'..." -ForegroundColor Yellow
        New-LocalUser -Name $Username `
            -Password $secPassword `
            -FullName $fullName `
            -Description "Official contestant account for ICPC 2026" `
            -PasswordNeverExpires `
            -UserMayNotChangePassword -ErrorAction Stop | Out-Null
        Write-Host "[OK] User '$Username' created successfully." -ForegroundColor Green
    }
}
catch {
    Write-Host "[ERROR] Could not create/update '$Username': $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 2. Enforce Group Membership (Standard User only)
Write-Host "[INFO] Enforcing standard user permissions..." -ForegroundColor Yellow
# Use the well-known SIDs so this also works on non-English Windows (group names are localized).
$usersGroup = Get-LocalGroup -SID 'S-1-5-32-545'
$adminGroup = Get-LocalGroup -SID 'S-1-5-32-544'
Add-LocalGroupMember -Group $usersGroup -Member $Username -ErrorAction SilentlyContinue
try {
    # Throws "MemberNotFound" when the account is not an admin - that is the normal case.
    Remove-LocalGroupMember -Group $adminGroup -Member $Username -ErrorAction Stop
    Write-Host "[OK] Removed '$Username' from Administrators group." -ForegroundColor Green
} catch {
    Write-Host "[OK] '$Username' is a Standard User (not an Administrator)." -ForegroundColor Green
}

# 3. Build the user profile now (C:\Users\<name>)
Write-Host "[INFO] Creating the Windows profile for '$Username'..." -ForegroundColor Yellow
try {
    $profilePath = Initialize-UserProfile $Username
    Write-Host "[OK] Profile ready: $profilePath" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Could not create the profile: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "        Log in once as '$Username', log out, then run RUN_SETUP.bat again." -ForegroundColor Red
    exit 1
}

# 4. Optional Auto-Logon Configuration
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
    Write-Host "[INFO] Auto-Logon is disabled. (Set -EnableAutoLogin `$true to enable)." -ForegroundColor Gray
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Account setup completed for : $Username" -ForegroundColor Green
Write-Host " Full Name / Team Name       : $fullName" -ForegroundColor Green
Write-Host " Password                    : $Password" -ForegroundColor Green
Write-Host " Profile folder              : $profilePath" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
exit 0
