@echo off
setlocal EnableDelayedExpansion
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

:: -------------------------------------------------------------
:: ICPC Lab Workstation - Contestant Verification & Code Runner Fix
:: -------------------------------------------------------------

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Administrative permissions required. Requesting elevation...
    "%PS%" -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

if not exist "%~dp0config.bat" (
    echo [ERROR] config.bat not found!
    pause
    exit /b 1
)
call "%~dp0config.bat"

cls
echo ============================================================
echo     ICPC CONTESTANT VERIFICATION AND CODE RUNNER CHECK
echo ============================================================
echo.
echo This will run FROM INSIDE the contestant account:
echo   1. Install Code Runner (if missing) into the contestant profile
echo   2. Run all 120 test cases (30 each: C, C++, Java, Python)
echo   3. Verify VS Code extensions (Code Runner, C/C++, Java, Python)
echo   4. Verify outbound Internet is OFF and DOMserver is reachable
echo.

set "SAVED_LAB="
if exist "C:\ProgramData\icpc_lab_config.bat" (
    call "C:\ProgramData\icpc_lab_config.bat"
    echo [DETECTED] Saved Lab: Lab !SAVED_LAB! ^(!DOMSERVER_IP!^)
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
    echo [ERROR] Invalid lab selection "%LAB_CHOICE%".
    pause
    exit /b 1
)

set "PC_NUM="
set /p PC_NUM="Enter Lab PC Number (1-60) for assigned team, or press ENTER for 'contestant': "
if "%PC_NUM%"=="" (
    set "PC_ARG="
) else (
    set "PC_ARG=-PcNumber %PC_NUM%"
)

echo.
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\06_test_as_contestant.ps1" %PC_ARG% -ServerIP "%DOMSERVER_IP%"
echo.
pause

