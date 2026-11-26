<#
.SYNOPSIS
    Configures VS Code (settings + language extensions) and the desktop workspace INSIDE the
    contestant account.
.DESCRIPTION
    - Writes the offline settings.json into the contestant profile (and C:\Users\Default for any
      account created later), filled in with the real compiler / Python paths of this PC.
    - Copies the language extensions (Code Runner, C/C++, Python, Java - see
      configs\vscode\extensions.txt) from the shared cache made in step 1 into
      C:\Users\<contestant>\.vscode\extensions and fixes VS Code's extensions.json so the paths
      point at the contestant's own folder (the old script copied the Administrator's list, whose
      paths the contestant cannot read, so VS Code showed no extensions).
    - Creates Desktop\ICPC_Workspace with build tasks, a sample file and a desktop shortcut.
    Works fully offline (it runs after the network lockdown).
#>

param(
    [int]$PcNumber = 0,
    [string]$Username = "contestant"
)

. "$PSScriptRoot\common.ps1"

$acct = Resolve-ContestAccount -PcNumber $PcNumber -Username $Username
$Username = $acct.Username
$teamDisplayName = $acct.TeamDisplay
$problems = 0

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Step 5] Configuring VS Code for: $Username" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$sourceSettings = Join-Path $script:RepoRoot "configs\vscode\settings.json"
if (-not (Test-Path -LiteralPath $sourceSettings)) {
    Write-Host "[ERROR] Could not find settings template at: $sourceSettings" -ForegroundColor Red
    exit 1
}
if (-not (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Account '$Username' does not exist - run step 2 (01_create_user.ps1) first." -ForegroundColor Red
    exit 1
}
try { $contestantHome = Initialize-UserProfile $Username }
catch {
    Write-Host "[ERROR] No profile for '$Username': $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host "[INFO] Contestant profile: $contestantHome" -ForegroundColor Gray

# -------------------------------------------------------------
# 1. settings.json (template + paths detected on this PC)
# -------------------------------------------------------------
$settings = Get-Content -LiteralPath $sourceSettings -Raw | ConvertFrom-Json
function Set-Setting([string]$Name, $Value) {
    $settings | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
}
$gpp = Find-SharedExe 'g++.exe'
if ($gpp) { Set-Setting 'C_Cpp.default.compilerPath' $gpp }
$py = Find-SharedExe 'python.exe'
if ($py) { Set-Setting 'python.defaultInterpreterPath' $py }
$javac = Find-SharedExe 'javac.exe'
if ($javac) {
    # The Java extension's language server needs JDK 21+. Older JDKs: let it use its bundled JRE.
    $jdkHome = Split-Path -Parent (Split-Path -Parent $javac)
    $release = Join-Path $jdkHome 'release'
    if ((Test-Path -LiteralPath $release) -and
        ((Get-Content -LiteralPath $release -Raw) -match 'JAVA_VERSION="(\d+)') -and [int]$Matches[1] -ge 21) {
        Set-Setting 'java.jdt.ls.java.home' $jdkHome
    }
}
$settingsJson = $settings | ConvertTo-Json -Depth 10
$utf8 = New-Object System.Text.UTF8Encoding($false)

$targets = @(
    (Join-Path $env:SystemDrive 'Users\Default\AppData\Roaming\Code\User'),   # accounts created later
    (Join-Path $contestantHome 'AppData\Roaming\Code\User')
)
foreach ($t in $targets) {
    New-Item -ItemType Directory -Path $t -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $t 'settings.json'), $settingsJson, $utf8)
}
Write-Host "[OK] settings.json written (compiler: $gpp | python: $py)" -ForegroundColor Green

# -------------------------------------------------------------
# 2. Language extensions -> contestant profile
# -------------------------------------------------------------
$required = Get-RequiredExtensions
$contestantExt = Join-Path $contestantHome '.vscode\extensions'

# The old version copied the Administrator's extensions (with a broken extensions.json) into the
# Default profile, which then got copied into every new account. Remove that stale copy.
$staleDefault = Join-Path $env:SystemDrive 'Users\Default\.vscode\extensions'
if (Test-Path -LiteralPath $staleDefault) {
    Remove-Item -LiteralPath $staleDefault -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[FIXED] Removed stale extension copy from the Default profile." -ForegroundColor Yellow
}

if (Test-Path -LiteralPath $script:IcpcExtCache) {
    Write-Host "[INFO] Installing VS Code extensions into '$Username'..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $contestantExt -Force | Out-Null
    robocopy $script:IcpcExtCache $contestantExt /E /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
    Repair-ExtensionsManifest $contestantExt
} else {
    Write-Host "[ERROR] Extension cache $script:IcpcExtCache not found - step 1 could not download extensions." -ForegroundColor Red
}
foreach ($ext in $required) {
    if (Test-ExtensionPresent $contestantExt $ext) { Write-Host "  [OK] $ext" -ForegroundColor Green }
    else { Write-Host "  [MISSING] $ext" -ForegroundColor Red; $problems++ }
}

# -------------------------------------------------------------
# 3. Desktop workspace
# -------------------------------------------------------------
$contestantDesktop = Join-Path $contestantHome 'Desktop'
New-Item -ItemType Directory -Path $contestantDesktop -Force | Out-Null
$workspaceDir = Join-Path $contestantDesktop "ICPC_Workspace"
$dotVscode = Join-Path $workspaceDir ".vscode"
Write-Host "[INFO] Setting up Contest Workspace at $workspaceDir..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $dotVscode -Force | Out-Null

$tasksJson = @'
{
    "version": "2.0.0",
    "tasks": [
        {
            "type": "shell",
            "label": "Compile C++ (g++)",
            "command": "g++",
            "args": ["-O2", "-std=c++17", "-Wall", "${file}", "-o", "${fileDirname}\\${fileBasenameNoExtension}.exe"],
            "options": { "cwd": "${fileDirname}" },
            "problemMatcher": ["$gcc"],
            "group": { "kind": "build", "isDefault": true }
        },
        {
            "type": "shell",
            "label": "Compile C (gcc)",
            "command": "gcc",
            "args": ["-O2", "-std=c11", "-Wall", "${file}", "-o", "${fileDirname}\\${fileBasenameNoExtension}.exe"],
            "options": { "cwd": "${fileDirname}" },
            "problemMatcher": ["$gcc"]
        },
        {
            "type": "shell",
            "label": "Compile Java (javac)",
            "command": "javac",
            "args": ["${file}"],
            "options": { "cwd": "${fileDirname}" },
            "problemMatcher": []
        }
    ]
}
'@
[IO.File]::WriteAllText((Join-Path $dotVscode "tasks.json"), $tasksJson, $utf8)

$templateCpp = @"
#include <bits/stdc++.h>
using namespace std;

// Team: $teamDisplayName

int main() {
    ios_base::sync_with_stdio(false);
    cin.tie(NULL);

    cout << "ICPC 2026 Ready!" << "\n";
    return 0;
}
"@
$sampleFile = Join-Path $workspaceDir "sample.cpp"
if (-not (Test-Path -LiteralPath $sampleFile)) { [IO.File]::WriteAllText($sampleFile, $templateCpp, $utf8) }

# Desktop shortcut straight to Code.exe (no flashing cmd window)
$codeExe = Get-VSCodeSystemExe
try {
    $WshShell = New-Object -ComObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut((Join-Path $contestantDesktop "Open ICPC Workspace.lnk"))
    if ($codeExe) {
        $shortcut.TargetPath = $codeExe
        $shortcut.Arguments = "`"$workspaceDir`""
        $shortcut.IconLocation = "$codeExe,0"
    } else {
        $shortcut.TargetPath = "cmd.exe"
        $shortcut.Arguments = "/c code `"$workspaceDir`""
    }
    $shortcut.WorkingDirectory = $workspaceDir
    $shortcut.Description = "Open ICPC Workspace in VS Code"
    $shortcut.Save()
    Write-Host "[OK] Desktop shortcut created." -ForegroundColor Green
}
catch {
    Write-Host "[WARNING] Desktop shortcut could not be created: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "==========================================" -ForegroundColor Green
if ($problems -eq 0) { Write-Host " VS Code configuration completed for '$Username'." -ForegroundColor Green }
else { Write-Host " VS Code configured with $problems missing extension(s) - see above." -ForegroundColor Red }
Write-Host "==========================================" -ForegroundColor Green
exit $problems
