@echo off
setlocal

:: =============================================================
:: CONFIGURATION: Set your DOMjudge / Contest Server IP below:
:: =============================================================
set "DOMSERVER_IP=192.168.1.100"
:: =============================================================

:: 1. Check for Administrative Privileges and Auto-Elevate
net session >nul 2>&1
if errorlevel 1 (
    echo [INFO] Administrative permissions required. Requesting elevation...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: 2. Set working directory to script location
cd /d "%~dp0"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass -File"
set "FAILED_STEPS="

cls
echo ============================================================
echo         ICPC WORKSTATION AUTOMATION ^& LOCKDOWN
echo ============================================================
echo.
echo Target DOMserver IP : %DOMSERVER_IP%
echo.
echo This script will configure this PC for the ICPC competition:
echo   1. Install missing tools for ALL accounts (VS Code, GCC/G++, Java, Python)
echo      and download the VS Code language extensions
echo   2. Create/Reset the contestant account (Generic or Official Team) and its profile
echo   3. Lock down the network (block internet, allow ONLY %DOMSERVER_IP%)
echo   4. Freeze Windows Update
echo   5. Configure VS Code + extensions + desktop workspace in the contestant account
echo   6. Verify as Administrator
echo   7. Verify INSIDE the contestant account
echo.
echo NOTE: Step 1 needs internet on the FIRST PC (later PCs reuse the USB cache).
echo ============================================================
echo.

set /p CONFIRM="Proceed with setup on this workstation? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo [ABORTED] Setup cancelled by user.
    pause
    exit /b 0
)

:ask_pc
echo.
set "PC_NUM="
set /p PC_NUM="Enter Lab PC Number (1-60) for assigned team, or press ENTER for standard 'contestant': "
if "%PC_NUM%"=="" (
    set "PC_ARG="
    echo [INFO] Using generic 'contestant' profile.
    goto :pc_done
)
echo %PC_NUM%| findstr /r "^[1-9][0-9]*$" >nul
if errorlevel 1 goto :pc_bad
if %PC_NUM% GTR 60 goto :pc_bad
set "PC_ARG=-PcNumber %PC_NUM%"
echo [INFO] Provisioning for Lab PC #%PC_NUM%...
goto :pc_done
:pc_bad
echo [ERROR] "%PC_NUM%" is not a number from 1 to 60. Try again.
goto :ask_pc
:pc_done

echo.
echo [1/7] Checking and installing toolchains + VS Code extensions...
%PS% "%~dp0scripts\00_install_prerequisites.ps1"
if errorlevel 1 set "FAILED_STEPS=%FAILED_STEPS% [1-Toolchains]"

:: Refresh PATH from the registry for this window (System PATH only - that is what the contestant sees)
for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do call set "PATH=%%B"

echo.
echo [2/7] Creating the contestant account and profile...
%PS% "%~dp0scripts\01_create_user.ps1" %PC_ARG%
if errorlevel 1 set "FAILED_STEPS=%FAILED_STEPS% [2-Account]"

echo.
echo [3/7] Applying network lockdown and firewall rules...
%PS% "%~dp0scripts\02_lockdown_network.ps1" -ServerIP "%DOMSERVER_IP%"
if errorlevel 1 set "FAILED_STEPS=%FAILED_STEPS% [3-Network]"

echo.
echo [4/7] Freezing Windows Update...
%PS% "%~dp0scripts\02b_block_updates.ps1"
if errorlevel 1 set "FAILED_STEPS=%FAILED_STEPS% [4-Updates]"

echo.
echo [5/7] Configuring VS Code in the contestant account...
%PS% "%~dp0scripts\03_configure_vscode.ps1" %PC_ARG%
if errorlevel 1 set "FAILED_STEPS=%FAILED_STEPS% [5-VSCode]"

echo.
echo [6/7] Verifying as Administrator...
call "%~dp0scripts\04_verify_env.bat" "%DOMSERVER_IP%"
if errorlevel 1 set "FAILED_STEPS=%FAILED_STEPS% [6-Verify-Admin]"

echo.
echo [7/7] Verifying inside the contestant account...
%PS% "%~dp0scripts\05_verify_as_contestant.ps1" %PC_ARG% -ServerIP "%DOMSERVER_IP%"
if errorlevel 1 set "FAILED_STEPS=%FAILED_STEPS% [7-Verify-Contestant]"

echo.
echo ============================================================
if "%FAILED_STEPS%"=="" (
    echo   SETUP FINISHED - ALL STEPS OK. This PC is ready.
) else (
    echo   SETUP FINISHED WITH PROBLEMS IN:%FAILED_STEPS%
    echo   Scroll up, fix the red lines, and run RUN_SETUP.bat again.
)
echo ============================================================
echo.
pause
