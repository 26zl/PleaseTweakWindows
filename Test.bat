@echo off
title PleaseTweakWindows - Local Testing
color 0A
setlocal

echo.
echo ========================================================================
echo  PleaseTweakWindows - Local Testing Script
echo ========================================================================
echo.

:: ----------------------------
:: Check for dependencies
:: ----------------------------
echo [*] Checking dependencies...
echo.

:: Check for Java
where java > nul 2>&1
if %errorlevel% neq 0 (
    echo [-] ERROR: Java not found!
    echo.
    echo Please install Java 21 or later and add it to your PATH.
    echo Download from: https://adoptium.net/
    echo.
    pause
    exit /b 1
) else (
    echo [+] Java found
    java -version
)

echo.

:: Check for Maven
where mvn > nul 2>&1
if %errorlevel% neq 0 (
    echo [-] ERROR: Maven not found!
    echo.
    echo Please install Maven 3.9+ and add it to your PATH.
    echo Download from: https://maven.apache.org/download.cgi
    echo.
    pause
    exit /b 1
) else (
    echo [+] Maven found
    call mvn -version
)

echo.
echo [+] All dependencies found!
echo.

:: ----------------------------
:: STEP 1: Run unit tests
:: ----------------------------
echo ========================================================================
echo [*] STEP 1: Running unit tests
echo ========================================================================
echo.

call mvn test
if %errorlevel% neq 0 (
    echo.
    echo [-] ERROR: Tests failed!
    echo [!] Check the output above for errors.
    echo.
    pause
    exit /b 1
)

echo.
echo [+] All tests passed!
echo.

:: ----------------------------
:: STEP 2: Ask user if they want to run the application
:: ----------------------------
echo ========================================================================
echo [*] STEP 2: Run application in development mode?
echo ========================================================================
echo.
echo Do you want to run the application now? (Y/N)
set /p RUN_APP="Enter choice: "

if /i "%RUN_APP%"=="Y" (
    echo.
    echo [*] Starting application...
    echo [!] Note: Application requires Administrator privileges for full functionality
    echo.
    call mvn javafx:run
    if %errorlevel% neq 0 (
        echo.
        echo [-] ERROR: Failed to start application!
        echo [!] Check the output above for errors.
        echo.
        pause
        exit /b 1
    )
) else (
    echo.
    echo [*] Skipping application run.
    echo [*] To run manually, use: mvn javafx:run
    echo.
)

:: ----------------------------
:: Summary
:: ----------------------------
echo.
echo ========================================================================
echo [+] TESTING COMPLETED!
echo ========================================================================
echo.
echo [*] Summary:
echo     - Unit tests: PASSED
if /i "%RUN_APP%"=="Y" (
    echo     - Application: RUN
) else (
    echo     - Application: SKIPPED
)
echo.
echo [*] Next steps:
echo     - If everything works, you can build native executable with: Build.bat
echo     - Or manually: mvn clean package -Pnative
echo.
pause
endlocal
