@echo off
setlocal EnableDelayedExpansion

:: -------------------------------------------------------------
:: ICPC Lab Workstation - Network Lockdown Launcher (Phase 2)
:: -------------------------------------------------------------

set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

:: 1. Check for Administrative Privileges and Auto-Elevate
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Administrative permissions required. Requesting elevation...
    "%PS%" -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

:: 2. Load Lab DOMserver IPs from config.bat
if not exist "%~dp0config.bat" (
    echo [ERROR] config.bat not found!
    pause
    exit /b 1
)
call "%~dp0config.bat"

cls
echo ============================================================
echo         ICPC WORKSTATION NETWORK LOCKDOWN (PHASE 2)
echo ============================================================
echo.
echo Available Labs from config.bat:
echo   [1] %LAB1_NAME% - DOMserver IP: %LAB1_DOMSERVER_IP%
echo   [2] %LAB2_NAME% - DOMserver IP: %LAB2_DOMSERVER_IP%
echo   [3] %LAB3_NAME% - DOMserver IP: %LAB3_DOMSERVER_IP%
echo.

:: Check if Lab was already saved during RUN_SETUP.bat
set "SAVED_LAB="
if exist "C:\ProgramData\icpc_lab_config.bat" (
    call "C:\ProgramData\icpc_lab_config.bat"
    echo [DETECTED] Previously selected during setup: Lab !SAVED_LAB! (!DOMSERVER_IP!)
)

set "LAB_CHOICE="
if defined SAVED_LAB (
    set /p LAB_CHOICE="Select Lab (1, 2, or 3) [Press ENTER for Lab %SAVED_LAB%]: "
    if "!LAB_CHOICE!"=="" set "LAB_CHOICE=%SAVED_LAB%"
) else (
    set /p LAB_CHOICE="Select Lab (1, 2, or 3): "
)

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

echo.
echo [INFO] Target DOMserver IP: %DOMSERVER_IP%
echo.
echo This will:
echo   1. Turn OFF Windows Firewall on all profiles (Domain, Private, Public)
echo   2. Scan and disable any Wi-Fi / Wireless adapters
echo   3. Disable Windows Update services
echo   4. Verify DOMserver reachability and offline isolation
echo.

set /p CONFIRM="Proceed with network lockdown? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo [ABORTED] Lockdown cancelled by user.
    pause
    exit /b 0
)

echo.
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\02_lockdown_network.ps1" -ServerIP "%DOMSERVER_IP%"
if %errorLevel% neq 0 (
    echo [WARNING] Network lockdown encountered an issue.
)

echo.
echo ============================================================
echo           NETWORK LOCKDOWN VERIFICATION
echo ============================================================
echo Pinging DOMserver (%DOMSERVER_IP%)...
ping -n 1 -w 1500 %DOMSERVER_IP% >nul 2>&1
if %errorLevel% equ 0 (
    echo   [PASS] DOMserver %DOMSERVER_IP% is REACHABLE.
) else (
    echo   [NOTE] DOMserver %DOMSERVER_IP% not responding.
    echo          Ignore if server is currently offline.
)

echo Testing Internet Isolation - pinging 8.8.8.8...
ping -n 1 -w 1500 8.8.8.8 >nul 2>&1
if %errorLevel% neq 0 (
    echo   [PASS] External Internet is BLOCKED / UNREACHABLE.
) else (
    echo   [WARNING] External Internet is STILL ACCESSIBLE!
    echo             Ensure the lab switch WAN uplink is unplugged.
)
echo ============================================================
echo.
pause

