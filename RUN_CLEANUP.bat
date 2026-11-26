@echo off
setlocal

:: -------------------------------------------------------------
:: ICPC Lab Workstation Teardown / Cleanup Launcher
:: -------------------------------------------------------------

:: Check for Administrative Privileges and Auto-Elevate
net session >nul 2>&1
if errorlevel 1 (
    echo [INFO] Administrative permissions required. Requesting elevation...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

cls
echo ============================================================
echo         ICPC LAB TEARDOWN ^& RECOVERY SCRIPT
echo ============================================================
echo.
echo WARNING: This script will:
echo   1. Remove the contestant / team accounts and their profiles
echo   2. Restore the firewall exactly as it was before setup
echo   3. Restore normal Internet, LAN and Wi-Fi access
echo   4. Restore Windows Update services, tasks and policies
echo   5. Disable automatic contestant login
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
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\99_cleanup_lab.ps1"

echo.
echo ============================================================
echo               CLEANUP FINISHED
echo ============================================================
echo The PC has been restored to the default university lab state.
echo Restart the PC to finish re-enabling Windows Update.
echo.
pause

