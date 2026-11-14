<#
.SYNOPSIS
    Reverts ICPC lab workstation back to the default university lab state.
.DESCRIPTION
    - Removes 'contestant' or any 'ICPCLK26_*' team account and deletes user profile folders.
    - Disables Windows AutoAdminLogon.
    - Resets Windows Firewall to default operating system state (restores Internet).
    - Removes temporary contest workspace directories.
#>

param(
    [string]$Username = "contestant"
)

Write-Host "==========================================" -ForegroundColor Red
Write-Host " [Cleanup] Restoring Workstation to Default" -ForegroundColor Red
Write-Host "==========================================" -ForegroundColor Red

# 1. Reset Windows Firewall to Default State
Write-Host "[INFO] Resetting Windows Firewall to factory default..." -ForegroundColor Yellow
try {
    netsh advfirewall reset | Out-Null
    Write-Host "[OK] Windows Firewall reset to default. Internet access restored." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to reset Windows Firewall: $_" -ForegroundColor Red
}

# 2. Disable AutoAdminLogon
Write-Host "[INFO] Disabling Windows Auto-Logon..." -ForegroundColor Yellow
$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
try {
    Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "0" -Type String -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
    Write-Host "[OK] Auto-Logon disabled." -ForegroundColor Green
} catch {
    Write-Host "[NOTE] Auto-Logon was already disabled or not present." -ForegroundColor Gray
}

# 3. Find and Remove Contestant Accounts (matches 'contestant' or 'ICPCLK26_*')
Write-Host "[INFO] Scanning for contest user accounts..." -ForegroundColor Yellow
$targetUsers = Get-LocalUser | Where-Object { $_.Name -eq $Username -or $_.Name -like "ICPCLK26_*" }

if ($targetUsers) {
    foreach ($user in $targetUsers) {
        $uName = $user.Name
        Write-Host "[INFO] Removing local user '$uName'..." -ForegroundColor Yellow
        try {
            Remove-LocalUser -Name $uName -ErrorAction Stop
            Write-Host "[OK] Local user '$uName' deleted." -ForegroundColor Green
        } catch {
            Write-Host "[WARNING] Could not delete user '$uName': $_" -ForegroundColor Yellow
        }

        # Remove profile directory
        $userProfilePath = "C:\Users\$uName"
        if (Test-Path $userProfilePath) {
            Write-Host "[INFO] Removing profile folder at $userProfilePath..." -ForegroundColor Yellow
            try {
                cmd.exe /c "rmdir /s /q `"$userProfilePath`"" 2>$null
                Write-Host "[OK] Profile directory '$userProfilePath' cleaned." -ForegroundColor Green
            } catch {
                Write-Host "[NOTE] Profile files may be cleared upon reboot." -ForegroundColor Gray
            }
        }
    }
} else {
    Write-Host "[NOTE] No contest users found to remove." -ForegroundColor Gray
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host " Workstation restored to normal lab state." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
