@echo off
color b
echo ===============================
echo   PleaseTweakWindows Installer
echo ===============================
echo.

:: ----------------------------
:: Configuration
:: ----------------------------
set "JPACKAGE_EXE=C:\Program Files\Java\jdk-21\bin\jpackage.exe"
set "APP_NAME=PleaseTweakWindows"
set "APP_VERSION=1.0"
set "MAIN_JAR=PleaseTweakWindows-1.0-SNAPSHOT.jar"
set "MAIN_CLASS=com.zl.pleasetweakwindows.Main"
set "RUNTIME_IMAGE=C:\Users\user\Documents\PleaseTweakWindows\custom-runtime"
set "SCRIPTS_DIR=C:\Users\user\Documents\PleaseTweakWindows\scripts"
set "ICON_FILE=C:\Users\user\Documents\PleaseTweakWindows\daemonWindows.ico"
set "INPUT_DIR=C:\Users\user\Documents\PleaseTweakWindows\target"
set "APP_IMAGE_DIR=C:\Users\user\Documents\PleaseTweakWindows\build\AppImage"
set "INSTALLER_OUT=C:\Users\user\Documents\PleaseTweakWindows\installerOutput"

:: Replace spaces in APP_NAME with dashes (optional)
set "APP_NAME_NO_SPACE=%APP_NAME: =-%"

:: ----------------------------
:: STEP 0: Check for dependencies
:: ----------------------------
echo Checking dependencies...
if not exist "%JPACKAGE_EXE%" (
    echo ERROR: jpackage.exe not found in "%JPACKAGE_EXE%".
    echo Make sure you have JDK 21 installed and jpackage is available.
    pause
    exit /b 1
)
echo Dependencies found!
echo.

:: ----------------------------
:: STEP 1: Remove old folders
:: ----------------------------
echo Removing old app-image folder...
if exist "%APP_IMAGE_DIR%\%APP_NAME%" (
    rd /S /Q "%APP_IMAGE_DIR%\%APP_NAME%" || (
        echo ERROR: Failed to delete "%APP_IMAGE_DIR%\%APP_NAME%".
        echo Close any programs using these files, then press a key to try again...
        pause
        goto STEP_1
    )
)

echo Removing old installer output folder...
if exist "%INSTALLER_OUT%" (
    rd /S /Q "%INSTALLER_OUT%" || (
        echo ERROR: Failed to delete "%INSTALLER_OUT%".
        echo Close any programs using these files, then press a key to try again...
        pause
        goto STEP_1
    )
)

:STEP_1
:: ----------------------------
:: STEP 2: Create app image
:: ----------------------------
echo ==== STEP 2: Creating app image ====
"%JPACKAGE_EXE%" ^
  --type app-image ^
  --name "%APP_NAME%" ^
  --input "%INPUT_DIR%" ^
  --main-jar "%MAIN_JAR%" ^
  --main-class "%MAIN_CLASS%" ^
  --runtime-image "%RUNTIME_IMAGE%" ^
  --dest "%APP_IMAGE_DIR%" || (
    echo ERROR: Failed to create app image.
    pause
    exit /b 1
)
echo App image created successfully.

echo Copying script files...
xcopy "%SCRIPTS_DIR%\*" "%APP_IMAGE_DIR%\%APP_NAME%\scripts\" /E /I /Y > nul
if %errorlevel% neq 0 (
    echo ERROR: Failed to copy scripts.
    pause
    exit /b 1
)
echo Scripts copied successfully.
echo.

:: ----------------------------
:: STEP 3: Create EXE installer
:: ----------------------------
echo ==== STEP 3: Creating EXE installer ====
"%JPACKAGE_EXE%" ^
  --type exe ^
  --app-image "%APP_IMAGE_DIR%\%APP_NAME%" ^
  --dest "%INSTALLER_OUT%" ^
  --win-shortcut ^
  --win-menu ^
  --icon "%ICON_FILE%" ^
  --win-upgrade-uuid "12345678-1234-1234-1234-123456789abc" || (
    echo ERROR: Failed to create EXE installer.
    pause
    exit /b 1
)
echo The EXE installer was created in:
echo   %INSTALLER_OUT%
echo.

:: ----------------------------
:: STEP 4: Zip the installer using Windows PowerShell
:: ----------------------------
echo ==== STEP 4: Zipping the installer with Windows PowerShell ====
powershell -Command "Compress-Archive -Path '%INSTALLER_OUT%\%APP_NAME_NO_SPACE%-%APP_VERSION%.exe' -DestinationPath 'C:\Users\user\Documents\PleaseTweakWindows\%APP_NAME_NO_SPACE%-%APP_VERSION%-win-x64.zip' -Force"

if %errorlevel% neq 0 (
    echo ERROR: Failed to create ZIP archive.
    pause
    exit /b 1
)
echo The installer ZIP file was created at:
echo   C:\Users\user\Documents\PleaseTweakWindows\%APP_NAME_NO_SPACE%-%APP_VERSION%-win-x64.zip
echo.

:: ----------------------------
:: STEP 5: Remove the standalone EXE
:: ----------------------------
echo ==== STEP 5: Removing the standalone EXE to keep only the ZIP ====
del /q "%INSTALLER_OUT%\%APP_NAME_NO_SPACE%-%APP_VERSION%.exe" 2>nul
del /q "%INSTALLER_OUT%\%APP_NAME%-%APP_VERSION%.exe" 2>nul

if exist "%INSTALLER_OUT%\%APP_NAME_NO_SPACE%-%APP_VERSION%.exe" (
    echo WARNING: Failed to delete the EXE file. You may need to delete it manually.
) else (
    echo EXE file(s) removed successfully.
)

echo.
echo Process completed successfully!
pause