<#
.SYNOPSIS
    Runs the full verification (04_verify_env.bat) INSIDE the contestant account.
.DESCRIPTION
    The old setup only verified as Administrator, so it reported "ALL PASSED" even when gcc,
    python or the extensions were missing for the contestant, or when the internet still worked.
    This starts the same checks as the contestant user (with its own PATH, profile and
    firewall view) and prints the result.
#>

param(
    [int]$PcNumber = 0,
    [string]$Username = "contestant",
    [string]$ServerIP = "192.168.1.100",
    [int]$TimeoutMinutes = 10
)

. "$PSScriptRoot\common.ps1"

$acct = Resolve-ContestAccount -PcNumber $PcNumber -Username $Username

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Step 7] Verifying INSIDE the account '$($acct.Username)'" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$profilePath = Get-UserProfilePath $acct.Username
if (-not $profilePath) {
    Write-Host "[ERROR] '$($acct.Username)' has no profile - step 2 failed." -ForegroundColor Red
    exit 1
}

# Copy the checks into the contestant's own temp folder (the USB stick / network share may not be
# readable by the contestant).
$verifyRoot = Join-Path $profilePath 'AppData\Local\Temp\icpc_selftest'
Remove-Item -LiteralPath $verifyRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path (Join-Path $verifyRoot 'scripts') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $verifyRoot 'configs\vscode') -Force | Out-Null
foreach ($f in '04_verify_env.bat', 'run_30_tests.py', 'net_probe.ps1') {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $f) -Destination (Join-Path $verifyRoot 'scripts') -Force
}
Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'configs\test_programs') -Destination (Join-Path $verifyRoot 'configs') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'configs\vscode\extensions.txt') -Destination (Join-Path $verifyRoot 'configs\vscode') -Force

# "Run as different user" needs the Secondary Logon service.
$seclogon = Get-Service -Name seclogon -ErrorAction SilentlyContinue
if ($seclogon -and $seclogon.StartType -eq 'Disabled') { Set-Service -Name seclogon -StartupType Manual }
Start-Service -Name seclogon -ErrorAction SilentlyContinue

$outFile = Join-Path $env:TEMP "icpc_contestant_verify_out.txt"
$errFile = Join-Path $env:TEMP "icpc_contestant_verify_err.txt"
Remove-Item -LiteralPath $outFile, $errFile -Force -ErrorAction SilentlyContinue

$bat = Join-Path $verifyRoot 'scripts\04_verify_env.bat'
$cred = New-Object System.Management.Automation.PSCredential($acct.Username, (ConvertTo-SecureString $acct.Password -AsPlainText -Force))

Write-Host "[INFO] Running the checks as '$($acct.Username)' (this takes 1-3 minutes)..." -ForegroundColor Yellow
try {
    $p = Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" `
        -ArgumentList "/d /c `"`"$bat`" $ServerIP CONTESTANT`"" `
        -Credential $cred -LoadUserProfile -WorkingDirectory $profilePath `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile -PassThru -ErrorAction Stop
} catch {
    Write-Host "[ERROR] Could not start a process as '$($acct.Username)': $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "        Log in as the contestant and run scripts\04_verify_env.bat manually instead." -ForegroundColor Red
    exit 1
}
if (-not $p.WaitForExit($TimeoutMinutes * 60 * 1000)) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    Write-Host "[ERROR] Verification timed out after $TimeoutMinutes minutes." -ForegroundColor Red
}

$output = if (Test-Path -LiteralPath $outFile) { Get-Content -LiteralPath $outFile } else { @() }
foreach ($line in $output) {
    $color = 'Gray'
    if ($line -match '\[(FAIL|LEAK|ERROR)\]|ISSUE') { $color = 'Red' }
    elseif ($line -match '\[WARNING\]|\[NOTE\]') { $color = 'Yellow' }
    elseif ($line -match '\[PASS\]|PASSED|\[OK\]') { $color = 'Green' }
    Write-Host $line -ForegroundColor $color
}
if (Test-Path -LiteralPath $errFile) {
    Get-Content -LiteralPath $errFile | Where-Object { $_.Trim() } | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
}

$passed = @(@($output) -match 'ALL CHECKS PASSED').Count -gt 0
Remove-Item -LiteralPath $verifyRoot -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $outFile, $errFile -Force -ErrorAction SilentlyContinue

if ($passed) {
    Write-Host "[OK] Contestant account '$($acct.Username)' is READY." -ForegroundColor Green
    exit 0
}
Write-Host "[ERROR] Contestant account '$($acct.Username)' is NOT ready - fix the FAIL/LEAK lines above." -ForegroundColor Red
exit 1
