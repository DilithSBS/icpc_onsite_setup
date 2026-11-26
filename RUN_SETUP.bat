@echo off
setlocal EnableDelayedExpansion

:: -------------------------------------------------------------
:: ICPC Lab Workstation Setup Launcher (Phase 1 - Accounts & Tools)
:: -------------------------------------------------------------

:: 1. Check for Administrative Privileges and Auto-Elevate
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Administrative permissions required. Requesting elevation...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: 2. Set working directory to script location
cd /d "%~dp0"

:: 3. Load Lab DOMserver IPs from config.bat
if not exist "%~dp0config.bat" (
    echo [ERROR] config.bat not found! Please create config.bat with your 3 lab DOMserver IPs.
    pause
    exit /b 1
)
call "%~dp0config.bat"

cls
echo ============================================================
echo         ICPC WORKSTATION SETUP (PHASE 1: ACCOUNTS AND TOOLS)
echo ============================================================
echo.
echo Available Labs from config.bat:
echo   [1] %LAB1_NAME% - DOMserver IP: %LAB1_DOMSERVER_IP%
echo   [2] %LAB2_NAME% - DOMserver IP: %LAB2_DOMSERVER_IP%
echo   [3] %LAB3_NAME% - DOMserver IP: %LAB3_DOMSERVER_IP%
echo.
echo This script will configure this PC for the ICPC competition:
echo   1. Check and Auto-Install missing tools (VS Code, GCC, Java, Python)
echo   2. Create/Reset contestant user account (Generic or Official Team)
echo   3. Pre-configure VS Code (offline mode, disable telemetry, Code Runner)
echo   4. Run compiler and environment verification (without network lockdown)
echo.
echo NOTE: Run RUN_LOCKDOWN.bat later when ready to lock down the network.
echo ============================================================
echo.

set /p CONFIRM="Proceed with setup on this workstation? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo [ABORTED] Setup cancelled by user.
    pause
    exit /b 0
)

echo.
set "LAB_CHOICE="
set /p LAB_CHOICE="Which Lab is this PC in? (1, 2, or 3): "

if "%LAB_CHOICE%"=="1" (
    set "DOMSERVER_IP=%LAB1_DOMSERVER_IP%"
) else if "%LAB_CHOICE%"=="2" (
    set "DOMSERVER_IP=%LAB2_DOMSERVER_IP%"
) else if "%LAB_CHOICE%"=="3" (
    set "DOMSERVER_IP=%LAB3_DOMSERVER_IP%"
) else (
    echo [ERROR] Invalid lab selection "%LAB_CHOICE%". Please choose 1, 2, or 3.
    pause
    exit /b 1
)

:: Save selected Lab & DOMserver IP for Phase 2 (RUN_LOCKDOWN.bat)
(
    echo set "SAVED_LAB=%LAB_CHOICE%"
    echo set "DOMSERVER_IP=%DOMSERVER_IP%"
) > "C:\ProgramData\icpc_lab_config.bat"
echo [INFO] Selected Lab %LAB_CHOICE% - DOMserver IP: %DOMSERVER_IP%

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
echo [1/4] Checking and installing missing toolchains...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\00_install_prerequisites.ps1"
if %errorLevel% neq 0 (
    echo [WARNING] Prerequisites check encountered an issue.
)

:: Refresh PATH from Registry in current session
for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%B"
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USER_PATH=%%B"
set "PATH=%SYS_PATH%;%USER_PATH%"

echo.
echo [2/4] Running user account creation...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\01_create_user.ps1" %PC_ARG%
if %errorLevel% neq 0 (
    echo [WARNING] User creation step encountered an issue.
)

echo.
echo [3/4] Configuring VS Code environment...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\03_configure_vscode.ps1" %PC_ARG%
if %errorLevel% neq 0 (
    echo [WARNING] VS Code configuration encountered an issue.
)

echo.
echo [4/4] Verifying compiler and toolchain readiness...
call "%~dp0scripts\04_verify_env.bat" "%DOMSERVER_IP%" skip_network

echo.
echo ============================================================
echo                SETUP WORKFLOW FINISHED
echo ============================================================
echo Compilers and user account are ready.
echo Remember to run RUN_LOCKDOWN.bat before the contest starts!
echo.
pause
