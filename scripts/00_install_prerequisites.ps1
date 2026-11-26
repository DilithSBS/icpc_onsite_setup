<#
.SYNOPSIS
    Checks and installs the contest toolchains (VS Code, GCC/G++, Java JDK, Python) MACHINE-WIDE,
    and downloads the VS Code language extensions into a shared offline cache.
.DESCRIPTION
    Why "machine-wide" matters:
      A tool installed for the Administrator only (e.g. winget's default per-user install of WinLibs
      GCC, or a "Just for me" Python) lives under C:\Users\Administrator\... . The contestant account
      cannot read that folder, so gcc / g++ / python "work in admin but not in the contestant account".
      This script ignores any copy inside a user profile and makes sure a shared copy exists:
        - VS Code  : C:\Program Files\Microsoft VS Code         (System installer)
        - GCC/G++  : C:\mingw64\bin  or  C:\Program Files\WinGet\Packages\...\mingw64\bin
        - Java     : C:\Program Files\Eclipse Adoptium\jdk-21...\bin
        - Python   : C:\Program Files\Python312
      and that the folder is on the SYSTEM PATH (which every account gets at logon).

    Offline support (optional, put on the USB stick next to RUN_SETUP.bat):
        installers\winlibs*.zip            WinLibs GCC zip (extracted to C:\mingw64)
        installers\vscode-extensions\      extension cache (auto-created after the first online PC)
#>

. "$PSScriptRoot\common.ps1"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Step 1] Checking & Installing Prerequisites (machine-wide)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$problems = 0
$installersDir = Join-Path $script:RepoRoot 'installers'
New-Item -ItemType Directory -Path $script:IcpcDataDir -Force | Out-Null

function Get-Winget {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    # Elevated sessions sometimes do not see the per-user App Installer alias.
    $pkg = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
    if ($pkg) { return $pkg.FullName }
    return $null
}

function Invoke-WingetInstall([string]$Id, [string[]]$Extra = @()) {
    $wgArgs = @('install', '--id', $Id, '-e', '--source', 'winget', '--scope', 'machine', '--silent',
              '--accept-package-agreements', '--accept-source-agreements') + $Extra
    Write-Host "  [DOWNLOADING] winget install $Id (machine scope)..." -ForegroundColor Cyan
    & $script:Winget @wgArgs
    Update-SessionPath
}

# Remove PATH entries that point into someone's profile (left by older versions of this toolkit).
Remove-UserProfileDirsFromMachinePath
Update-SessionPath

$script:Winget = Get-Winget
Write-Host "[INFO] Checking Internet connectivity..." -ForegroundColor Gray
$hasInternet = Test-Online
if ($hasInternet) { Write-Host "  [ONLINE] Internet connection detected." -ForegroundColor Green }
else { Write-Host "  [OFFLINE] No Internet connection detected (only offline sources can be used)." -ForegroundColor Yellow }
if (-not $script:Winget) { Write-Host "  [NOTE] winget was not found - automatic downloads are disabled." -ForegroundColor Yellow }
$canDownload = $hasInternet -and $script:Winget

# -------------------------------------------------------------
# 1. Visual Studio Code (System installer only)
# -------------------------------------------------------------
Write-Host "`n[1/5] Checking Visual Studio Code (System install)..." -ForegroundColor Yellow
$codeExe = Get-VSCodeSystemExe
if (-not $codeExe) {
    $userCopy = Get-ChildItem -Path "$script:UsersRoot\*\AppData\Local\Programs\Microsoft VS Code\Code.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($userCopy) {
        Write-Host "  [NOTE] Found a per-user VS Code at $($userCopy.FullName) - the contestant cannot use it." -ForegroundColor Yellow
    }
    if ($canDownload) {
        Invoke-WingetInstall 'Microsoft.VisualStudioCode' @('--override', '/VERYSILENT /NORESTART /MERGETASKS=!runcode,addtopath')
        $codeExe = Get-VSCodeSystemExe
    }
}
if ($codeExe) {
    Add-ToMachinePath (Join-Path (Split-Path -Parent $codeExe) 'bin')
    Write-Host "  [OK] VS Code (System): $codeExe" -ForegroundColor Green
} else {
    Write-Host "  [ACTION REQUIRED] Install the VS Code *System Installer* (not the User Installer)." -ForegroundColor Red
    $problems++
}

# -------------------------------------------------------------
# 2. C / C++ (GCC & G++)
# -------------------------------------------------------------
Write-Host "`n[2/5] Checking C/C++ compilers (GCC & G++)..." -ForegroundColor Yellow
$gccDirs = @('C:\mingw64\bin', 'C:\winlibs\mingw64\bin', 'C:\msys64\ucrt64\bin', 'C:\msys64\mingw64\bin',
             'C:\MinGW\bin', 'C:\winlibs\bin', 'D:\msys64\ucrt64\bin', 'D:\MinGW\bin',
             "$env:ProgramFiles\WinGet\Packages\BrechtSanders.WinLibs*\mingw64\bin")

function Find-SharedGpp { Find-SharedExe 'g++.exe' $gccDirs }

$gpp = Find-SharedGpp
if (-not $gpp) {
    # (a) A copy exists but only inside a user profile (winget per-user install) -> copy it to C:\mingw64
    $private = Get-ChildItem -Path "$script:UsersRoot\*\AppData\Local\Microsoft\WinGet\Packages\BrechtSanders.WinLibs*\mingw64\bin\g++.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($private) {
        $root = Split-Path -Parent (Split-Path -Parent $private.FullName)    # ...\mingw64
        Write-Host "  [FIX] GCC found only inside a user profile: $root" -ForegroundColor Yellow
        Write-Host "        Copying it to C:\mingw64 so every account can use it (1-2 minutes)..." -ForegroundColor Yellow
        robocopy $root 'C:\mingw64' /E /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
        $gpp = Find-SharedGpp
    }
}
if (-not $gpp) {
    # (b) Offline zip on the USB stick
    $zip = Get-ChildItem -Path (Join-Path $installersDir 'winlibs*.zip') -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($zip) {
        Write-Host "  [OFFLINE] Extracting $($zip.Name) to C:\ ..." -ForegroundColor Cyan
        Expand-Archive -LiteralPath $zip.FullName -DestinationPath 'C:\' -Force
        $gpp = Find-SharedGpp
    }
}
if (-not $gpp -and $canDownload) {
    # (c) Download - machine scope puts it in C:\Program Files\WinGet\Packages (readable by everyone)
    Invoke-WingetInstall 'BrechtSanders.WinLibs.POSIX.UCRT'
    $gpp = Find-SharedGpp
    if (-not $gpp) {
        # Some winget versions ignore --scope for zip packages and install per-user anyway.
        $private = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\BrechtSanders.WinLibs*\mingw64\bin\g++.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($private) {
            $root = Split-Path -Parent (Split-Path -Parent $private.FullName)
            Write-Host "  [FIX] winget installed GCC per-user; copying to C:\mingw64..." -ForegroundColor Yellow
            robocopy $root 'C:\mingw64' /E /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
            $gpp = Find-SharedGpp
        }
    }
}
if ($gpp) {
    # Put the real bin folder BEFORE winget's "Links" folder: GCC cannot find cc1/cc1plus when
    # started through winget's symlinks.
    Add-ToMachinePath (Split-Path -Parent $gpp) -BeforePattern '\\WinGet\\Links$'
    Write-Host "  [OK] g++: $gpp" -ForegroundColor Green
} else {
    Write-Host "  [ACTION REQUIRED] Install MinGW-w64/WinLibs to C:\mingw64 (or put winlibs*.zip in installers\)." -ForegroundColor Red
    $problems++
}

# -------------------------------------------------------------
# 3. Java Development Kit
# -------------------------------------------------------------
Write-Host "`n[3/5] Checking Java JDK (javac & java)..." -ForegroundColor Yellow
$jdkDirs = @("$env:ProgramFiles\Eclipse Adoptium\jdk-*\bin", "$env:ProgramFiles\Java\jdk*\bin", "$env:ProgramFiles\Microsoft\jdk-*\bin")
$javac = Find-SharedExe 'javac.exe' $jdkDirs
if (-not $javac -and $canDownload) {
    Invoke-WingetInstall 'EclipseAdoptium.Temurin.21.JDK'
    $javac = Find-SharedExe 'javac.exe' $jdkDirs
}
if ($javac) {
    Add-ToMachinePath (Split-Path -Parent $javac)
    Write-Host "  [OK] javac: $javac" -ForegroundColor Green
} else {
    Write-Host "  [ACTION REQUIRED] Install a JDK (e.g. Temurin 21) for all users." -ForegroundColor Red
    $problems++
}

# -------------------------------------------------------------
# 4. Python (all-users install, never the Microsoft Store stub)
# -------------------------------------------------------------
Write-Host "`n[4/5] Checking Python (all-users install)..." -ForegroundColor Yellow
$pyDirs = @("$env:ProgramFiles\Python3*", 'C:\Python3*')
$python = Find-SharedExe 'python.exe' $pyDirs
if (-not $python) {
    $private = Get-ChildItem -Path "$script:UsersRoot\*\AppData\Local\Programs\Python\Python3*\python.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($private) { Write-Host "  [NOTE] Found a per-user Python at $($private.FullName) - the contestant cannot use it." -ForegroundColor Yellow }
}
if (-not $python -and $canDownload) {
    # If 3.12 is already installed "just for me", the 3.12 installer refuses to add an all-users
    # copy, so fall back to the next version.
    foreach ($pyId in @('Python.Python.3.12', 'Python.Python.3.13')) {
        Invoke-WingetInstall $pyId @('--override', '/quiet InstallAllUsers=1 PrependPath=1 Include_launcher=1 Include_test=0')
        $python = Find-SharedExe 'python.exe' $pyDirs
        if ($python) { break }
    }
}
if ($python) {
    $pyHome = Split-Path -Parent $python
    Add-ToMachinePath $pyHome
    Add-ToMachinePath (Join-Path $pyHome 'Scripts')
    Write-Host "  [OK] python: $python" -ForegroundColor Green
} else {
    Write-Host "  [ACTION REQUIRED] Install Python 3.10+ with 'Install for all users' ticked." -ForegroundColor Red
    $problems++
}

# -------------------------------------------------------------
# 5. VS Code extensions -> shared offline cache
# -------------------------------------------------------------
Write-Host "`n[5/5] Preparing VS Code language extensions (offline cache)..." -ForegroundColor Yellow
$required = Get-RequiredExtensions
New-Item -ItemType Directory -Path $script:IcpcExtCache -Force | Out-Null

# Seed from the USB stick if an earlier PC already downloaded them
if (Test-Path -LiteralPath (Join-Path $script:UsbExtSeed 'extensions.json')) {
    Write-Host "  [OFFLINE] Copying extensions from USB cache ($script:UsbExtSeed)..." -ForegroundColor Cyan
    robocopy $script:UsbExtSeed $script:IcpcExtCache /E /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
    Repair-ExtensionsManifest $script:IcpcExtCache
}

$missing = @($required | Where-Object { -not (Test-ExtensionPresent $script:IcpcExtCache $_) })
$codeCli = Get-VSCodeCli
if ($missing.Count -gt 0 -and $hasInternet -and $codeCli) {
    foreach ($ext in $missing) {
        Write-Host "  [DOWNLOADING] $ext" -ForegroundColor Cyan
        & $codeCli --extensions-dir "$script:IcpcExtCache" --install-extension $ext --force 2>&1 |
            ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
    }
    Repair-ExtensionsManifest $script:IcpcExtCache
    $missing = @($required | Where-Object { -not (Test-ExtensionPresent $script:IcpcExtCache $_) })

    # Save to the USB stick so the remaining PCs do not need internet for this step
    if ($missing.Count -eq 0 -and -not (Test-Path -LiteralPath $script:UsbExtSeed)) {
        try {
            New-Item -ItemType Directory -Path $script:UsbExtSeed -Force -ErrorAction Stop | Out-Null
            robocopy $script:IcpcExtCache $script:UsbExtSeed /E /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
            Write-Host "  [OK] Extension cache saved to USB: $script:UsbExtSeed" -ForegroundColor Green
        } catch {
            Write-Host "  [NOTE] Could not save extension cache to the USB stick (read-only?)." -ForegroundColor Gray
        }
    }
}
foreach ($ext in $required) {
    if (Test-ExtensionPresent $script:IcpcExtCache $ext) { Write-Host "  [OK] $ext" -ForegroundColor Green }
    else { Write-Host "  [MISSING] $ext" -ForegroundColor Red }
}
if ($missing.Count -gt 0) {
    Write-Host "  [ACTION REQUIRED] Missing extensions: $($missing -join ', ')." -ForegroundColor Red
    Write-Host "                    Run setup once on a PC WITH internet; the cache is then copied to the USB stick." -ForegroundColor Red
    $problems++
}

Update-SessionPath
Write-Host "`n==========================================" -ForegroundColor Green
if ($problems -eq 0) { Write-Host " Prerequisites OK - all tools are installed for ALL accounts." -ForegroundColor Green }
else { Write-Host " Prerequisites finished with $problems problem(s) - see ACTION REQUIRED above." -ForegroundColor Red }
Write-Host "==========================================" -ForegroundColor Green
exit $problems
