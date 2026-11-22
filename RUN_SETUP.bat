@echo off
setlocal EnableDelayedExpansion

:: =============================================================
:: CONFIGURATION: Set your DOMjudge / Contest Server IP below:
:: =============================================================
set "DOMSERVER_IP=192.168.1.100"
:: =============================================================

:: 1. Check for Administrative Privileges and Auto-Elevate
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Administrative permissions required. Requesting elevation...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: 2. Set working directory to script location
cd /d "%~dp0"

cls
echo ============================================================
echo         ICPC WORKSTATION AUTOMATION AND LOCKDOWN
echo ============================================================
echo.
echo Target DOMserver IP : %DOMSERVER_IP%
echo.
echo This script will configure this PC for the ICPC competition:
echo   1. Check and Auto-Install missing tools (VS Code, GCC, Java, Python)
echo   2. Create/Reset contestant user account (Generic or Official Team)
echo   3. Lockdown network (block internet, allow ONLY DOMserver: %DOMSERVER_IP%)
echo   4. Pre-configure VS Code (offline mode, disable telemetry, Code Runner)
echo   5. Run compiler and network environment smoke test
echo.
echo ============================================================
echo.

set /p CONFIRM="Proceed with setup on this workstation? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo [ABORTED] Setup cancelled by user.
    pause
    exit /b 0
)

echo.
set "PC_NUM="
set /p PC_NUM="Enter Lab PC Number (1-60) for assigned team, or press ENTER for standard 'contestant': "

if "%PC_NUM%"=="" (
    set "PC_ARG="
    echo [INFO] Using generic 'contestant' profile.
) else (
    set "PC_ARG=-PcNumber %PC_NUM%"
    echo [INFO] Provisioning for Lab PC #%PC_NUM%...
)

echo.
echo [1/5] Checking and installing missing toolchains...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\00_install_prerequisites.ps1"
if %errorLevel% neq 0 (
    echo [WARNING] Prerequisites check encountered an issue.
)

:: Refresh PATH from Registry in current session
for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%B"
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USER_PATH=%%B"
set "PATH=%SYS_PATH%;%USER_PATH%"

echo.
echo [2/5] Running user account creation...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\01_create_user.ps1" %PC_ARG%
if %errorLevel% neq 0 (
    echo [WARNING] User creation step encountered an issue.
)

echo.
echo [3/5] Applying network lockdown and firewall rules...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\02_lockdown_network.ps1" -ServerIP "%DOMSERVER_IP%" -StrictServerOnly $true
if %errorLevel% neq 0 (
    echo [WARNING] Network lockdown encountered an issue.
)

echo.
echo [4/5] Configuring VS Code environment...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\03_configure_vscode.ps1" %PC_ARG%
if %errorLevel% neq 0 (
    echo [WARNING] VS Code configuration encountered an issue.
)

echo.
echo [5/5] Verifying compiler and network readiness...
call "%~dp0scripts\04_verify_env.bat" "%DOMSERVER_IP%"

echo.
echo ============================================================
echo                SETUP WORKFLOW FINISHED
echo ============================================================
echo If all verification checks passed, restart the machine or
echo log in to test the contestant view.
echo.
pause
