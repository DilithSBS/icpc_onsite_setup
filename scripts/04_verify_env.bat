@echo off
setlocal

:: -------------------------------------------------------------
:: ICPC Environment Smoke Test & Verification
::   04_verify_env.bat [DOMSERVER_IP] [CONTESTANT]
:: RUN_SETUP.bat runs it twice: as Administrator, and then INSIDE the contestant
:: account (second argument CONTESTANT) - which is what really matters.
:: Exit code = number of failed checks.
:: -------------------------------------------------------------

if not "%~1"=="" (set "SERVER_IP=%~1") else (set "SERVER_IP=192.168.1.100")
set "MODE=%~2"
set "TEMP_DIR=%TEMP%\icpc_verify_%RANDOM%"
set "SCRIPT_DIR=%~dp0"
set "TEST_DIR=%SCRIPT_DIR%..\configs\test_programs"
set "EXT_FILE=%SCRIPT_DIR%..\configs\vscode\extensions.txt"
set "FAIL_COUNT=0"

echo ============================================================
echo           ICPC WORKSTATION ENVIRONMENT VERIFICATION
echo           Account: %USERNAME%
echo ============================================================
echo.

:: 1. Binary presence check
echo [1] Checking Installed Toolchains in PATH:
echo ------------------------------------------------------------
for %%T in (gcc g++ javac java python code) do call :check_tool %%T

mkdir "%TEMP_DIR%" >nul 2>&1

echo.
echo [2] Compiling and Executing Test Programs:
echo ------------------------------------------------------------

:: C
where gcc >nul 2>&1
if errorlevel 1 goto :skip_c
gcc "%TEST_DIR%\test.c" -o "%TEMP_DIR%\test_c.exe" >nul 2>&1
if exist "%TEMP_DIR%\test_c.exe" (
    "%TEMP_DIR%\test_c.exe"
    echo   [PASS] C compilation and execution succeeded.
) else (
    echo   [FAIL] C compilation failed.
    set /a FAIL_COUNT+=1
)
:skip_c

:: C++
where g++ >nul 2>&1
if errorlevel 1 goto :skip_cpp
g++ -std=c++17 "%TEST_DIR%\test.cpp" -o "%TEMP_DIR%\test_cpp.exe" >nul 2>&1
if exist "%TEMP_DIR%\test_cpp.exe" (
    "%TEMP_DIR%\test_cpp.exe"
    echo   [PASS] C++ STL compilation and execution succeeded.
) else (
    echo   [FAIL] C++ compilation failed.
    set /a FAIL_COUNT+=1
)
:skip_cpp

:: Java
where javac >nul 2>&1
if errorlevel 1 goto :skip_java
copy "%TEST_DIR%\Test.java" "%TEMP_DIR%\" >nul 2>&1
javac "%TEMP_DIR%\Test.java" >nul 2>&1
if exist "%TEMP_DIR%\Test.class" (
    java -cp "%TEMP_DIR%" Test
    echo   [PASS] Java compilation and execution succeeded.
) else (
    echo   [FAIL] Java compilation failed.
    set /a FAIL_COUNT+=1
)
:skip_java

:: Python
where python >nul 2>&1
if errorlevel 1 goto :skip_py
python "%TEST_DIR%\test.py" >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] Python execution failed - only the Microsoft Store stub may be installed.
    set /a FAIL_COUNT+=1
) else (
    python "%TEST_DIR%\test.py"
    echo   [PASS] Python execution succeeded.
)
:skip_py

echo.
echo [3] Running 30-Test-Case Comprehensive Suite (C, C++, Java, Python):
echo ------------------------------------------------------------
where python >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] Python not available - cannot run the 30-test suite.
    set /a FAIL_COUNT+=1
    goto :skip_suite
)
python "%SCRIPT_DIR%run_30_tests.py"
if errorlevel 1 set /a FAIL_COUNT+=1
:skip_suite

if /i not "%MODE%"=="CONTESTANT" goto :skip_ext
echo.
echo [4] Checking VS Code language extensions for %USERNAME%:
echo ------------------------------------------------------------
call code --list-extensions > "%TEMP_DIR%\ext.txt" 2>nul
for /f "usebackq eol=# tokens=*" %%E in ("%EXT_FILE%") do call :check_ext %%E
:skip_ext

if /i "%~2"=="skip_network" (
    echo.
    echo [5] Network Security ^& Isolation: SKIPPED ^(run RUN_LOCKDOWN.bat later^).
    goto skip_net
)

echo.
echo [5] Checking Network Security ^& Isolation:
echo ------------------------------------------------------------
echo Pinging Contest Server: %SERVER_IP%...
ping -n 1 -w 1500 %SERVER_IP% | find "TTL=" >nul
if errorlevel 1 (
    echo   [NOTE] Contest server %SERVER_IP% not responding.
    echo          Ignore if the server is currently offline.
) else (
    echo   [PASS] Contest server is REACHABLE.
)

echo Testing Internet isolation - ping, TCP, HTTPS, DNS and proxy...
ping -n 1 -w 1500 8.8.8.8 | find "TTL=" >nul
if not errorlevel 1 (
    echo   [FAIL] Ping to 8.8.8.8 succeeded.
    set /a FAIL_COUNT+=1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%net_probe.ps1" -ServerIP %SERVER_IP%
if errorlevel 1 (
    echo   [FAIL] The INTERNET IS STILL REACHABLE from this account - see LEAK lines above.
    set /a FAIL_COUNT+=1
) else (
    echo   [PASS] Internet is BLOCKED - no outside connection possible.
)

:skip_net
:: Cleanup
rmdir /s /q "%TEMP_DIR%" >nul 2>&1

echo.
echo ============================================================
if "%FAIL_COUNT%"=="0" (
    echo  VERIFICATION SUMMARY [%USERNAME%]: ALL CHECKS PASSED - Workstation is READY.
) else (
    echo  VERIFICATION SUMMARY [%USERNAME%]: %FAIL_COUNT% ISSUE^(S^) DETECTED - review errors above.
)
echo ============================================================
exit /b %FAIL_COUNT%


:check_tool
where %1 >nul 2>&1
if errorlevel 1 (
    if /i "%1"=="code" (
        echo   [WARNING] 'code' command not in PATH - VS Code may still work via the GUI.
    ) else (
        echo   [FAIL] %1 NOT found in PATH.
        set /a FAIL_COUNT+=1
    )
) else (
    echo   [PASS] %1
)
exit /b 0

:check_ext
findstr /i /x /c:"%~1" "%TEMP_DIR%\ext.txt" >nul
if errorlevel 1 (
    echo   [FAIL] VS Code extension missing: %~1
    set /a FAIL_COUNT+=1
) else (
    echo   [PASS] VS Code extension: %~1
)
exit /b 0
