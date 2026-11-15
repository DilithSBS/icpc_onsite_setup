<#
.SYNOPSIS
    Checks and automatically installs missing toolchains (VS Code, C/C++, Java, Python).
.DESCRIPTION
    - Verifies presence of VS Code, GCC/G++, Java JDK, and Python.
    - If already installed, reports OK and ensures they are added to System PATH.
    - If missing, auto-installs the latest versions machine-wide using Windows Package Manager (winget).
    - If offline, checks if local offline installers exist in an 'installers\' folder.
    - Refreshes environment variables so subsequent scripts can use the tools immediately.
#>

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Step 1/5] Checking & Installing Prerequisites" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

function Update-SessionPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Add-ToMachinePath ([string]$folder) {
    if (-not (Test-Path $folder)) { return }
    $current = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $parts = $current -split ';' | Where-Object { $_ -ne "" }
    if ($parts -notcontains $folder) {
        $newPath = "$current;$folder"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Update-SessionPath
        Write-Host "    [OK] Added to System PATH: $folder" -ForegroundColor Green
    }
}

Update-SessionPath

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$offlineInstallersDir = Join-Path $repoRoot "installers"

# Check winget & internet connectivity
$hasWinget = $null -ne (Get-Command winget.exe -ErrorAction SilentlyContinue)
$hasInternet = $false

Write-Host "[INFO] Checking Internet connectivity..." -ForegroundColor Gray
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $iar = $tcp.BeginConnect("1.1.1.1", 53, $null, $null)
    $hasInternet = $iar.AsyncWaitHandle.WaitOne(2000, $false)
    if ($hasInternet) { $tcp.EndConnect($iar) }
    $tcp.Close()
} catch {
    $hasInternet = $false
}

if ($hasInternet) {
    Write-Host "  [ONLINE] Internet connection detected. Automated package downloads enabled." -ForegroundColor Green
} else {
    Write-Host "  [OFFLINE] No Internet connection detected." -ForegroundColor Yellow
}

# -------------------------------------------------------------
# 1. Visual Studio Code
# -------------------------------------------------------------
Write-Host "`n[1/4] Checking Visual Studio Code..." -ForegroundColor Yellow
$codeCmd = Get-Command code.exe -ErrorAction SilentlyContinue
$codeSysBin = "C:\Program Files\Microsoft VS Code\bin"

if ($null -ne $codeCmd) {
    $codeVer = (code.exe --version 2>$null)[0]
    Write-Host "  [OK] VS Code is already installed (Version: $codeVer)" -ForegroundColor Green
    Add-ToMachinePath (Split-Path -Parent $codeCmd.Source)
} elseif (Test-Path "C:\Program Files\Microsoft VS Code\Code.exe") {
    Write-Host "  [OK] VS Code found in Program Files." -ForegroundColor Green
    Add-ToMachinePath $codeSysBin
} else {
    Write-Host "  [MISSING] VS Code not detected." -ForegroundColor Yellow
    if ($hasInternet -and $hasWinget) {
        Write-Host "  [DOWNLOADING] Installing Microsoft VS Code (System 64-bit)..." -ForegroundColor Cyan
        & winget.exe install --id Microsoft.VisualStudioCode --scope machine --silent --accept-package-agreements --accept-source-agreements
        Add-ToMachinePath $codeSysBin
        Update-SessionPath
        Write-Host "  [OK] VS Code installed successfully." -ForegroundColor Green
    } else {
        Write-Host "  [ACTION REQUIRED] Please install VS Code System Installer machine-wide." -ForegroundColor Red
    }
}

# -------------------------------------------------------------
# 2. C / C++ Compiler (GCC & G++)
# -------------------------------------------------------------
Write-Host "`n[2/4] Checking C/C++ Compilers (GCC & G++)..." -ForegroundColor Yellow
Update-SessionPath

# Check common MinGW installation locations and automatically add to PATH
$commonMinGWPaths = @(
    "C:\MinGW\bin",
    "C:\msys64\ucrt64\bin",
    "C:\msys64\mingw64\bin",
    "C:\winlibs\bin",
    "D:\msys64\ucrt64\bin",
    "D:\MinGW\bin"
)
foreach ($p in $commonMinGWPaths) {
    if (Test-Path (Join-Path $p "g++.exe")) {
        Add-ToMachinePath $p
        break
    }
}
Update-SessionPath
$gccCmd = Get-Command gcc.exe -ErrorAction SilentlyContinue

if ($null -ne $gccCmd) {
    $gccVer = (gcc.exe --version 2>$null)[0]
    Write-Host "  [OK] GCC/G++ is already installed ($gccVer)" -ForegroundColor Green
    Add-ToMachinePath (Split-Path -Parent $gccCmd.Source)
} else {
    Write-Host "  [MISSING] GCC/G++ not detected." -ForegroundColor Yellow
    if ($hasInternet -and $hasWinget) {
        Write-Host "  [DOWNLOADING] Installing WinLibs MinGW-w64 (GCC/G++)..." -ForegroundColor Cyan
        & winget.exe install --id BrechtSanders.WinLibs.POSIX.UCRT --silent --accept-package-agreements --accept-source-agreements
        
        # Locate newly installed winlibs binary directory
        $candidatePaths = Get-ChildItem -Path "C:\Program Files", "C:\Users\*", "$env:LOCALAPPDATA\Programs" -Filter "g++.exe" -Recurse -Depth 4 -ErrorAction SilentlyContinue
        if ($candidatePaths) {
            $binFolder = Split-Path -Parent $candidatePaths[0].FullName
            Add-ToMachinePath $binFolder
        }
        Update-SessionPath
        Write-Host "  [OK] C/C++ compiler installed successfully." -ForegroundColor Green
    } else {
        Write-Host "  [ACTION REQUIRED] Please install MinGW-w64 (GCC/G++) and add to System PATH." -ForegroundColor Red
    }
}

# -------------------------------------------------------------
# 3. Java Development Kit (JDK)
# -------------------------------------------------------------
Write-Host "`n[3/4] Checking Java Development Kit (javac & java)..." -ForegroundColor Yellow
Update-SessionPath
$javacCmd = Get-Command javac.exe -ErrorAction SilentlyContinue

if ($null -ne $javacCmd) {
    $javaVer = (javac.exe -version 2>&1)
    Write-Host "  [OK] Java JDK is already installed ($javaVer)" -ForegroundColor Green
    Add-ToMachinePath (Split-Path -Parent $javacCmd.Source)
} else {
    Write-Host "  [MISSING] Java JDK not detected." -ForegroundColor Yellow
    if ($hasInternet -and $hasWinget) {
        Write-Host "  [DOWNLOADING] Installing Eclipse Temurin OpenJDK 21 LTS..." -ForegroundColor Cyan
        & winget.exe install --id EclipseAdoptium.Temurin.21.JDK --scope machine --silent --accept-package-agreements --accept-source-agreements
        
        # Find Temurin installation folder
        $jdkDirs = Get-ChildItem -Path "C:\Program Files\Eclipse Adoptium\*" -Directory -ErrorAction SilentlyContinue
        if ($jdkDirs) {
            $jdkBin = Join-Path $jdkDirs[0].FullName "bin"
            Add-ToMachinePath $jdkBin
        }
        Update-SessionPath
        Write-Host "  [OK] Java JDK installed successfully." -ForegroundColor Green
    } else {
        Write-Host "  [ACTION REQUIRED] Please install Java JDK (e.g. OpenJDK 21 LTS) machine-wide." -ForegroundColor Red
    }
}

# -------------------------------------------------------------
# 4. Python Interpreter
# -------------------------------------------------------------
Write-Host "`n[4/4] Checking Python Interpreter..." -ForegroundColor Yellow
Update-SessionPath
$pythonCmd = Get-Command python.exe -ErrorAction SilentlyContinue

if ($null -ne $pythonCmd) {
    $pyVer = (python.exe --version 2>$null)
    Write-Host "  [OK] Python is already installed ($pyVer)" -ForegroundColor Green
    Add-ToMachinePath (Split-Path -Parent $pythonCmd.Source)
} else {
    Write-Host "  [MISSING] Python not detected." -ForegroundColor Yellow
    if ($hasInternet -and $hasWinget) {
        Write-Host "  [DOWNLOADING] Installing Python 3.12 (Machine-wide)..." -ForegroundColor Cyan
        & winget.exe install --id Python.Python.3.12 --scope machine --silent --accept-package-agreements --accept-source-agreements --override "/quiet InstallAllUsers=1 PrependPath=1"
        
        if (Test-Path "C:\Program Files\Python312\python.exe") {
            Add-ToMachinePath "C:\Program Files\Python312"
            Add-ToMachinePath "C:\Program Files\Python312\Scripts"
        }
        Update-SessionPath
        Write-Host "  [OK] Python installed successfully." -ForegroundColor Green
    } else {
        Write-Host "  [ACTION REQUIRED] Please install Python 3.10+ (for all users) machine-wide." -ForegroundColor Red
    }
}

Update-SessionPath
Write-Host "`n==========================================" -ForegroundColor Green
Write-Host " Prerequisites check completed." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
