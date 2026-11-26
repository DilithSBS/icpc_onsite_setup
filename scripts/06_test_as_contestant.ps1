<#
.SYNOPSIS
    Ensures Code Runner is installed for the contestant account, then verifies all
    compilers, 120 test cases (30 per language), VS Code extensions, and outbound
    internet isolation FROM INSIDE the contestant account.
#>

param(
    [int]$PcNumber = 0,
    [string]$Username = "contestant",
    [string]$ServerIP = "192.168.1.100",
    [int]$TimeoutMinutes = 10
)

. "$PSScriptRoot\common.ps1"

$acct = Resolve-ContestAccount -PcNumber $PcNumber -Username $Username
$Username = $acct.Username

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Contestant Verification: $Username" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if (-not (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Account '$Username' does not exist. Run RUN_SETUP.bat first." -ForegroundColor Red
    exit 1
}

try {
    $profilePath = Initialize-UserProfile $Username
} catch {
    Write-Host "[ERROR] Could not initialize profile for '$Username': $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# -------------------------------------------------------------
# 1. Ensure Code Runner (and required extensions) are installed
# -------------------------------------------------------------
Write-Host "`n[Step 1/2] Checking Code Runner & VS Code extensions for '$Username'..." -ForegroundColor Yellow
$contestantExt = Join-Path $profilePath '.vscode\extensions'
New-Item -ItemType Directory -Path $contestantExt -Force | Out-Null
New-Item -ItemType Directory -Path $script:IcpcExtCache -Force | Out-Null

$required = @(Get-RequiredExtensions)
if ($required -notcontains 'formulahendry.code-runner') {
    $required += 'formulahendry.code-runner'
}

# Seed cache from USB if available
if (Test-Path -LiteralPath (Join-Path $script:UsbExtSeed 'extensions.json')) {
    robocopy $script:UsbExtSeed $script:IcpcExtCache /E /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
    Repair-ExtensionsManifest $script:IcpcExtCache
}

# Install any missing extensions into shared cache if online
$missingInCache = @($required | Where-Object { -not (Test-ExtensionPresent $script:IcpcExtCache $_) })
if ($missingInCache.Count -gt 0) {
    $codeCli = Get-VSCodeCli
    if ($codeCli -and (Test-Online)) {
        foreach ($ext in $missingInCache) {
            Write-Host "  [INSTALLING] $ext..." -ForegroundColor Cyan
            & $codeCli --extensions-dir "$script:IcpcExtCache" --install-extension $ext --force 2>&1 |
                ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        }
        Repair-ExtensionsManifest $script:IcpcExtCache
    } else {
        Write-Host "  [WARNING] Offline or VS Code CLI missing; cannot download: $($missingInCache -join ', ')" -ForegroundColor Yellow
    }
}

# Sync shared cache into contestant's .vscode\extensions and fix manifest paths
if (Test-Path -LiteralPath (Join-Path $script:IcpcExtCache 'extensions.json')) {
    robocopy $script:IcpcExtCache $contestantExt /E /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
    Repair-ExtensionsManifest $contestantExt
}

if (Test-ExtensionPresent $contestantExt 'formulahendry.code-runner') {
    Write-Host "  [OK] formulahendry.code-runner is installed in '$Username'." -ForegroundColor Green
} else {
    Write-Host "  [FAIL] formulahendry.code-runner is still missing in '$Username'." -ForegroundColor Red
}

# -------------------------------------------------------------
# 2. Run 04_verify_env.bat (120 test cases + Code Runner + net_probe) AS contestant
# -------------------------------------------------------------
Write-Host "`n[Step 2/2] Running full test suite & internet isolation check AS '$Username'..." -ForegroundColor Yellow

$verifyRoot = Join-Path $profilePath 'AppData\Local\Temp\icpc_selftest'
Remove-Item -LiteralPath $verifyRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path (Join-Path $verifyRoot 'scripts') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $verifyRoot 'configs\vscode') -Force | Out-Null
foreach ($f in '04_verify_env.bat', 'run_30_tests.py', 'net_probe.ps1') {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $f) -Destination (Join-Path $verifyRoot 'scripts') -Force
}
Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'configs\test_programs') -Destination (Join-Path $verifyRoot 'configs') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'configs\vscode\extensions.txt') -Destination (Join-Path $verifyRoot 'configs\vscode') -Force

$seclogon = Get-Service -Name seclogon -ErrorAction SilentlyContinue
if ($seclogon -and $seclogon.StartType -eq 'Disabled') { Set-Service -Name seclogon -StartupType Manual }
Start-Service -Name seclogon -ErrorAction SilentlyContinue

$outFile = Join-Path $env:TEMP "icpc_contestant_verify_out.txt"
$errFile = Join-Path $env:TEMP "icpc_contestant_verify_err.txt"
Remove-Item -LiteralPath $outFile, $errFile -Force -ErrorAction SilentlyContinue

$bat = Join-Path $verifyRoot 'scripts\04_verify_env.bat'
$cred = New-Object System.Management.Automation.PSCredential($acct.Username, (ConvertTo-SecureString $acct.Password -AsPlainText -Force))

try {
    $p = Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" `
        -ArgumentList "/d /c `"`"$bat`" $ServerIP CONTESTANT`"" `
        -Credential $cred -LoadUserProfile -WorkingDirectory $profilePath `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile -PassThru -ErrorAction Stop
} catch {
    Write-Host "[ERROR] Could not launch verification as '$Username': $($_.Exception.Message)" -ForegroundColor Red
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
    Write-Host "`n[OK] Contestant account '$Username' passed all 120 tests, Code Runner, and internet isolation!" -ForegroundColor Green
    exit 0
}
Write-Host "`n[FAIL] Contestant account '$Username' failed one or more checks above." -ForegroundColor Red
exit 1

