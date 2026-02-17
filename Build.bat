@echo off
title PleaseTweakWindows - Build Script
color 0C
setlocal

echo.
echo ========================================================================
echo  PleaseTweakWindows - Native Build Script
echo ========================================================================
echo.

:: ----------------------------
:: Configuration
:: ----------------------------
set "APP_NAME=PleaseTweakWindows"
set "OUTPUT_DIR=dist"
set "NATIVE_EXE=target\%APP_NAME%.exe"

:: ----------------------------
:: STEP 0: Check for dependencies
:: ----------------------------
echo [*] Checking dependencies...
echo.

:: Check for GraalVM native-image
where native-image > nul 2>&1
if %errorlevel% neq 0 (
    echo [-] ERROR: GraalVM native-image not found!
    echo.
    echo This project requires GraalVM 25+ with Native Image to build.
    echo Download from: https://www.graalvm.org/downloads/
    echo.
    echo [*] Installation steps:
    echo     1. Download GraalVM for JDK 21+ or Liberica NIK 21+ for Windows
    echo     2. Extract to C:\graalvm\
    echo     3. Add C:\graalvm\bin to your PATH
    echo.
    pause
    exit /b 1
) else (
    echo [+] GraalVM Native Image found
)

:: Check for Maven (requires 3.9.9+)
where mvn > nul 2>&1
if %errorlevel% neq 0 (
    echo [-] ERROR: Maven not found!
    echo.
    echo Please install Maven 3.9.9 or later and add it to your PATH.
    echo Download from: https://maven.apache.org/download.cgi
    echo.
    pause
    exit /b 1
) else (
    echo [+] Maven found
    echo [*] Note: Maven 3.9.9+ is required (check with: mvn -version)
)

echo.
echo [+] All dependencies found!
echo.

:: ----------------------------
:: STEP 1: Run tests
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
:: STEP 2: Compile Windows resources (icon + manifest)
:: ----------------------------
echo ========================================================================
echo [*] STEP 2: Compiling Windows resources (icon + manifest)
echo ========================================================================
echo.

set "RC_EXE="
for /f "delims=" %%R in ('where /r "C:\Program Files (x86)\Windows Kits\10\bin" rc.exe 2^>nul ^| findstr /i "x64" ^| sort /r') do (
    if not defined RC_EXE set "RC_EXE=%%R"
)

if defined RC_EXE (
    echo [+] Found rc.exe: %RC_EXE%
    pushd src\main\resources\native
    "%RC_EXE%" /nologo app.rc
    if %errorlevel% neq 0 (
        echo [-] ERROR: Resource compilation failed!
        popd
        pause
        exit /b 1
    )
    popd
    echo [+] app.res compiled successfully
) else (
    echo [!] WARNING: rc.exe not found — Windows SDK not installed.
    echo [!] The EXE will build without an embedded icon and manifest.
    echo [!] Install "Windows SDK" or "Build Tools for Visual Studio" to fix this.
)

echo.

:: ----------------------------
:: STEP 3: Clean and build native executable
:: ----------------------------
echo ========================================================================
echo [*] STEP 3: Building native executable with GraalVM
echo ========================================================================
echo [*] This will create a true native executable (no Java required)...
echo.

call mvn clean package -Pnative
if %errorlevel% neq 0 (
    echo.
    echo [-] ERROR: Maven build failed!
    echo [!] Check the output above for errors.
    echo.
    pause
    exit /b 1
)

echo.
echo [+] Native executable created successfully!
echo.

:: ----------------------------
:: STEP 4: Create distribution directory
:: ----------------------------
echo ========================================================================
echo [*] STEP 4: Creating distribution package
echo ========================================================================
echo.

:: Remove old distribution
if exist "%OUTPUT_DIR%" (
    echo [*] Removing old distribution directory...
    rd /S /Q "%OUTPUT_DIR%"
)

:: Create new distribution directory
echo [*] Creating new distribution directory...
mkdir "%OUTPUT_DIR%"

:: Copy native executable
if exist "%NATIVE_EXE%" (
    copy "%NATIVE_EXE%" "%OUTPUT_DIR%\%APP_NAME%.exe" > nul
    echo [+] Native executable copied to distribution
) else (
    echo [-] ERROR: Native executable not found at %NATIVE_EXE%
    pause
    exit /b 1
)

:: Copy scripts directory and remove unused revert scripts
if exist "src\main\resources\scripts" (
    xcopy "src\main\resources\scripts" "%OUTPUT_DIR%\scripts\" /E /I /Q > nul
    del /Q "%OUTPUT_DIR%\scripts\Gaming optimizations\revert-gaming.ps1" 2>nul
    del /Q "%OUTPUT_DIR%\scripts\General Tweaks\revert-general.ps1" 2>nul
    del /Q "%OUTPUT_DIR%\scripts\Network optimizations\revert-network.ps1" 2>nul
    del /Q "%OUTPUT_DIR%\scripts\Services management\revert-services.ps1" 2>nul
    echo [+] Scripts directory copied to distribution
)

:: Copy README.md
if exist "README.md" (
    copy "README.md" "%OUTPUT_DIR%\" > nul
    echo [+] README.md copied to distribution
)

:: Create logs directory with README
mkdir "%OUTPUT_DIR%\logs"
if exist "logs\README.txt" (
    copy "logs\README.txt" "%OUTPUT_DIR%\logs\" > nul
    echo [+] Logs directory created with README
)

:: ----------------------------
:: STEP 5: Create ZIP distribution
:: ----------------------------
echo ========================================================================
echo [*] STEP 5: Creating ZIP distribution
echo ========================================================================
echo.

set ZIP_NAME=%APP_NAME%.zip
powershell -Command "Compress-Archive -Path '%OUTPUT_DIR%\*' -DestinationPath '%ZIP_NAME%' -Force"

if %errorlevel% neq 0 (
    echo [-] ERROR: Failed to create ZIP archive.
    pause
    exit /b 1
)

echo [+] ZIP distribution created: %ZIP_NAME%
echo.

:: ----------------------------
:: STEP 6: Show results
:: ----------------------------
echo ========================================================================
echo [+] BUILD COMPLETED SUCCESSFULLY!
echo ========================================================================
echo.
echo [*] Distribution created in: %OUTPUT_DIR%\
echo [*] ZIP file: %ZIP_NAME%
echo.
echo [*] Native executable size:
for %%A in ("%OUTPUT_DIR%\%APP_NAME%.exe") do echo     %%~zA bytes
echo.
echo [+] This executable:
echo     - Requires NO Java installation
echo     - Starts in less than 1 second
echo     - Works on any Windows 10/11 system
echo     - Uses Windows PowerShell 5.1 (built-in)
echo.
echo [+] Ready for distribution!
echo.
pause
endlocal
