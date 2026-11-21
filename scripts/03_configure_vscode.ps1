<#
.SYNOPSIS
    Pre-configures VS Code and Desktop workspace for the contestant user.
.DESCRIPTION
    - Injects offline-optimized VS Code settings.json into Default profile & contestant profile.
    - Sets up 'C:\Users\<username>\Desktop\ICPC_Workspace' with pre-configured build tasks.
    - Creates a 1-click Desktop shortcut to open VS Code directly in the workspace.
#>

param(
    [int]$PcNumber = 0,
    [string]$Username = "contestant"
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$sourceSettings = Join-Path $repoRoot "configs\vscode\settings.json"
$csvPath = Join-Path $repoRoot "contestant_credentials.csv"

$teamDisplayName = "ICPC Contestant"

# If PcNumber is specified (1-60), lookup official team username
if ($PcNumber -ge 1 -and $PcNumber -le 60 -and (Test-Path $csvPath)) {
    $targetSeat = "PC-{0:D2}" -f $PcNumber
    $csvData = Import-Csv -Path $csvPath
    $matched = $csvData | Where-Object { $_.seat -eq $targetSeat } | Select-Object -First 1
    if ($null -ne $matched) {
        $Username = $matched.username
        $teamDisplayName = "$($matched.team_name) - $($matched.institution)"
    }
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Step 3] Configuring VS Code for: $Username" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if (-not (Test-Path $sourceSettings)) {
    Write-Host "[ERROR] Could not find settings template at: $sourceSettings" -ForegroundColor Red
    return
}

# 1. Target Paths
$defaultProfileUserCode = "C:\Users\Default\AppData\Roaming\Code\User"
$contestantProfileUserCode = "C:\Users\$Username\AppData\Roaming\Code\User"

# Copy to Default User (Ensures any newly created profile inherits these settings)
Write-Host "[INFO] Injecting VS Code settings into Default User profile..." -ForegroundColor Yellow
if (-not (Test-Path $defaultProfileUserCode)) {
    New-Item -ItemType Directory -Path $defaultProfileUserCode -Force | Out-Null
}
Copy-Item -Path $sourceSettings -Destination (Join-Path $defaultProfileUserCode "settings.json") -Force
Write-Host "[OK] Default User profile updated." -ForegroundColor Green

# Copy directly to contestant profile if already generated
$contestantHome = "C:\Users\$Username"
if (Test-Path $contestantHome) {
    Write-Host "[INFO] Injecting VS Code settings into '$Username' profile..." -ForegroundColor Yellow
    if (-not (Test-Path $contestantProfileUserCode)) {
        New-Item -ItemType Directory -Path $contestantProfileUserCode -Force | Out-Null
    }
    Copy-Item -Path $sourceSettings -Destination (Join-Path $contestantProfileUserCode "settings.json") -Force
    Write-Host "[OK] Contestant profile updated." -ForegroundColor Green
}

# 2. Create Desktop Workspace
$contestantDesktop = "C:\Users\$Username\Desktop"
if (Test-Path $contestantDesktop) {
    $workspaceDir = Join-Path $contestantDesktop "ICPC_Workspace"
    $dotVscode = Join-Path $workspaceDir ".vscode"
    
    Write-Host "[INFO] Setting up Contest Workspace at $workspaceDir..." -ForegroundColor Yellow
    if (-not (Test-Path $dotVscode)) {
        New-Item -ItemType Directory -Path $dotVscode -Force | Out-Null
    }

    # Create helpful tasks.json for C++ & C compilation
    $tasksJson = @'
{
    "version": "2.0.0",
    "tasks": [
        {
            "type": "shell",
            "label": "Compile C++ (g++)",
            "command": "g++",
            "args": [
                "-O2",
                "-std=c++17",
                "-Wall",
                "${file}",
                "-o",
                "${fileDirname}\\${fileBasenameNoExtension}.exe"
            ],
            "options": {
                "cwd": "${fileDirname}"
            },
            "problemMatcher": ["$gcc"],
            "group": {
                "kind": "build",
                "isDefault": true
            }
        },
        {
            "type": "shell",
            "label": "Compile C (gcc)",
            "command": "gcc",
            "args": [
                "-O2",
                "-std=c11",
                "-Wall",
                "${file}",
                "-o",
                "${fileDirname}\\${fileBasenameNoExtension}.exe"
            ],
            "options": {
                "cwd": "${fileDirname}"
            },
            "problemMatcher": ["$gcc"]
        }
    ]
}
'@
    Set-Content -Path (Join-Path $dotVscode "tasks.json") -Value $tasksJson -Encoding UTF8

    # Create a quick template main.cpp
    $templateCpp = @"
#include <iostream>
#include <vector>
#include <algorithm>

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
    if (-not (Test-Path $sampleFile)) {
        Set-Content -Path $sampleFile -Value $templateCpp -Encoding UTF8
    }

    # Create Desktop Shortcut to open workspace in VS Code
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $shortcutPath = Join-Path $contestantDesktop "Open ICPC Workspace.lnk"
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "cmd.exe"
        $shortcut.Arguments = "/c code `"$workspaceDir`""
        $shortcut.WorkingDirectory = $workspaceDir
        $shortcut.Description = "Open ICPC Workspace in VS Code"
        $shortcut.Save()
        Write-Host "[OK] Desktop shortcut created." -ForegroundColor Green
    }
    catch {
        Write-Host "[NOTE] Desktop shortcut skipped (user profile may not be fully initialized)." -ForegroundColor Gray
    }
}
else {
    Write-Host "[NOTE] '$Username' desktop will be configured on first login." -ForegroundColor Gray
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host " VS Code configuration completed." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
