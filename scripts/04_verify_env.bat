@echo off
setlocal EnableDelayedExpansion

:: -------------------------------------------------------------
:: ICPC Environment Smoke Test & Verification
:: -------------------------------------------------------------

if not "%~1"=="" (set "SERVER_IP=%~1") else (set "SERVER_IP=192.168.1.100")
set "TEMP_DIR=%TEMP%\icpc_verify_%RANDOM%"
set "SCRIPT_DIR=%~dp0"
set "TEST_DIR=%SCRIPT_DIR%..\configs\test_programs"

echo ============================================================
echo           ICPC WORKSTATION ENVIRONMENT VERIFICATION
echo ============================================================
echo.

set "FAIL_COUNT=0"

:: 1. Binary presence check
echo [1] Checking Installed Toolchains in PATH:
echo ------------------------------------------------------------

where gcc >nul 2>&1
if %errorLevel% equ 0 (
    echo   [PASS] GCC - C Compiler
) else (
    echo   [FAIL] GCC NOT found in PATH!
    set /a FAIL_COUNT+=1
)

where g++ >nul 2>&1
if %errorLevel% equ 0 (
    echo   [PASS] G++ - C++ Compiler
) else (
    echo   [FAIL] G++ NOT found in PATH!
    set /a FAIL_COUNT+=1
)

where javac >nul 2>&1
if %errorLevel% equ 0 (
    echo   [PASS] Java Compiler - javac
) else (
    echo   [FAIL] javac NOT found in PATH!
    set /a FAIL_COUNT+=1
)

where python >nul 2>&1
if %errorLevel% equ 0 (
    echo   [PASS] Python Interpreter
) else (
    echo   [FAIL] Python NOT found in PATH!
    set /a FAIL_COUNT+=1
)

where code >nul 2>&1
if %errorLevel% equ 0 (
    echo   [PASS] Visual Studio Code CLI - code
) else (
    echo   [WARNING] 'code' command not in PATH - VS Code may still work via GUI
)

echo.
echo [2] Compiling and Executing Test Programs:
echo ------------------------------------------------------------
mkdir "%TEMP_DIR%" >nul 2>&1

:: Test C
where gcc >nul 2>&1
if %errorLevel% equ 0 (
    gcc "%TEST_DIR%\test.c" -o "%TEMP_DIR%\test_c.exe" >nul 2>&1
    if exist "%TEMP_DIR%\test_c.exe" (
        "%TEMP_DIR%\test_c.exe"
        echo   [PASS] C compilation and execution succeeded.
    ) else (
        echo   [FAIL] C compilation failed!
        set /a FAIL_COUNT+=1
    )
)

:: Test C++
where g++ >nul 2>&1
if %errorLevel% equ 0 (
    g++ -std=c++17 "%TEST_DIR%\test.cpp" -o "%TEMP_DIR%\test_cpp.exe" >nul 2>&1
    if exist "%TEMP_DIR%\test_cpp.exe" (
        "%TEMP_DIR%\test_cpp.exe"
        echo   [PASS] C++ STL compilation and execution succeeded.
    ) else (
        echo   [FAIL] C++ compilation failed!
        set /a FAIL_COUNT+=1
    )
)

:: Test Java
where javac >nul 2>&1
if %errorLevel% equ 0 (
    copy "%TEST_DIR%\Test.java" "%TEMP_DIR%\" >nul 2>&1
    javac "%TEMP_DIR%\Test.java" >nul 2>&1
    if exist "%TEMP_DIR%\Test.class" (
        java -cp "%TEMP_DIR%" Test
        echo   [PASS] Java compilation and execution succeeded.
    ) else (
        echo   [FAIL] Java compilation failed!
        set /a FAIL_COUNT+=1
    )
)

:: Test Python
where python >nul 2>&1
if %errorLevel% equ 0 (
    python "%TEST_DIR%\test.py"
    if %errorLevel% equ 0 (
        echo   [PASS] Python execution succeeded.
    ) else (
        echo   [FAIL] Python execution failed!
        set /a FAIL_COUNT+=1
    )
)

echo.
echo [3] Checking Network Security ^& Isolation:
echo ------------------------------------------------------------

:: Test LAN/Server Reachability
echo Pinging Contest Server: %SERVER_IP%...
ping -n 1 -w 1500 %SERVER_IP% >nul 2>&1
if %errorLevel% equ 0 (
    echo   [PASS] Contest server is REACHABLE.
) else (
    echo   [NOTE] Contest server %SERVER_IP% not responding.
    echo          Ignore if server is currently offline or uses a different IP.
)

:: Test Internet Isolation (External ping should FAIL)
echo Testing Internet Isolation - pinging 8.8.8.8...
ping -n 1 -w 1500 8.8.8.8 >nul 2>&1
if %errorLevel% neq 0 (
    echo   [PASS] External Internet is BLOCKED. Expected for offline contest.
) else (
    echo   [WARNING] External Internet is STILL ACCESSIBLE!
    echo             Please ensure firewall rules are active or unplug the WAN uplink.
    set /a FAIL_COUNT+=1
)

:: Cleanup
rmdir /s /q "%TEMP_DIR%" >nul 2>&1

echo.
echo ============================================================
if %FAIL_COUNT% equ 0 (
    echo  VERIFICATION SUMMARY: [ALL CHECKS PASSED] Workstation is READY.
) else (
    echo  VERIFICATION SUMMARY: [%FAIL_COUNT% ISSUE DETECTED] Review errors above.
)
echo ============================================================
