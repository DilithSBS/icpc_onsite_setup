@echo off
setlocal EnableDelayedExpansion

:: -------------------------------------------------------------
:: ICPC Lab Workstation Teardown / Cleanup Launcher
:: -------------------------------------------------------------

set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

:: Check for Administrative Privileges and Auto-Elevate
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Administrative permissions required. Requesting elevation...
    "%PS%" -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

cls
echo ============================================================
echo         ICPC LAB TEARDOWN AND RECOVERY SCRIPT
echo ============================================================
echo.
echo WARNING: This script will:
echo   1. Remove the contestant user account and files
echo   2. Reset Windows Firewall to default operating system state
echo   3. Restore normal Internet and LAN access
echo   4. Re-enable Wi-Fi network adapters
echo   5. Re-enable Windows Update services
echo   6. Disable automatic contestant login
echo.
echo ============================================================
echo.

set /p CONFIRM="Are you sure you want to revert this PC to default lab state? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo [ABORTED] Cleanup cancelled by user.
    pause
    exit /b 0
)

echo.
echo Running cleanup script...
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\99_cleanup_lab.ps1"

echo.
echo ============================================================
echo               CLEANUP COMPLETED SUCCESSFULLY
echo ============================================================
echo The PC has been restored to default university lab state.
echo.
pause
