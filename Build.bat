@echo off
:: ----------------------------
:: Configuration
:: ----------------------------
set "JPACKAGE_EXE=C:\Program Files\Java\jdk-21\bin\jpackage.exe"
set "APP_NAME=PleaseTweakWindows"
set "APP_VERSION=1.0"
set "MAIN_JAR=PleaseTweakWindows-1.0-SNAPSHOT.jar"
set "MAIN_CLASS=com.zl.pleasetweakwindows.Main"
set "RUNTIME_IMAGE=C:\Users\User\Documents\PleaseTweakWindows\custom-runtime"
set "SCRIPTS_DIR=C:\Users\User\Documents\PleaseTweakWindows\scripts"
set "ICON_FILE=C:\Users\User\Documents\PleaseTweakWindows\daemonWindows.ico"
set "INPUT_DIR=C:\Users\User\Documents\PleaseTweakWindows\target"
set "APP_IMAGE_DIR=C:\Users\User\Documents\PleaseTweakWindows\build\AppImage"
set "INSTALLER_OUT=C:\Users\User\Documents\PleaseTweakWindows"
set "SEVEN_ZIP=C:\Program Files\7-Zip\7z.exe"

:: Replace spaces in APP_NAME with dashes (optional)
set "APP_NAME_NO_SPACE=%APP_NAME: =-%"

:: ----------------------------
:: STEP 0: Remove old folders
:: ----------------------------
echo Deleting old app-image folder if it exists...
:DELETE_APP_IMAGE
if exist "%APP_IMAGE_DIR%\%APP_NAME%" (
    rd /S /Q "%APP_IMAGE_DIR%\%APP_NAME%"
    if exist "%APP_IMAGE_DIR%\%APP_NAME%" (
        echo Failed to delete "%APP_IMAGE_DIR%\%APP_NAME%" because files are in use.
        echo Close any programs using these files, then press a key to try again...
        pause
        goto DELETE_APP_IMAGE
    )
)

echo Deleting old installer files from the project folder if they exist...
:: Delete previous installer EXE and ZIP files
del /Q "%INSTALLER_OUT%\%APP_NAME_NO_SPACE%-%APP_VERSION%-win-x64.zip" 2>nul
del /Q "%INSTALLER_OUT%\%APP_NAME_NO_SPACE%-%APP_VERSION%.exe" 2>nul
del /Q "%INSTALLER_OUT%\%APP_NAME%-%APP_VERSION%.exe" 2>nul

:: ----------------------------
:: STEP 1: Create app image
:: ----------------------------
echo ==== STEP 1: Creating app image ====
"%JPACKAGE_EXE%" ^
  --type app-image ^
  --name "%APP_NAME%" ^
  --input "%INPUT_DIR%" ^
  --main-jar "%MAIN_JAR%" ^
  --main-class "%MAIN_CLASS%" ^
  --runtime-image "%RUNTIME_IMAGE%" ^
  --dest "%APP_IMAGE_DIR%"

echo.
echo Copying script files outside the "app" folder...
xcopy "%SCRIPTS_DIR%\*" "%APP_IMAGE_DIR%\%APP_NAME%\scripts\" /E /I /Y

echo.
echo Scripts copied to:
echo   %APP_IMAGE_DIR%\%APP_NAME%\scripts
pause

:: ----------------------------
:: STEP 2: Create EXE installer
:: ----------------------------
echo ==== STEP 2: Creating EXE installer ====
"%JPACKAGE_EXE%" ^
  --type exe ^
  --app-image "%APP_IMAGE_DIR%\%APP_NAME%" ^
  --dest "%INSTALLER_OUT%" ^
  --win-shortcut ^
  --win-menu ^
  --icon "%ICON_FILE%" ^
  --win-upgrade-uuid "12345678-1234-1234-1234-123456789abc"

echo.
echo The EXE installer was created in:
echo   %INSTALLER_OUT%
pause

:: ----------------------------
:: STEP 3: Zip the installer with 7-Zip
:: ----------------------------
echo ==== STEP 3: Zipping the installer with 7-Zip ====
"%SEVEN_ZIP%" a "%INSTALLER_OUT%\%APP_NAME_NO_SPACE%-%APP_VERSION%-win-x64.zip" "%INSTALLER_OUT%\*"

echo.
echo The installer ZIP file was created at:
echo   %INSTALLER_OUT%\%APP_NAME_NO_SPACE%-%APP_VERSION%-win-x64.zip
pause

:: ----------------------------
:: STEP 4: Remove the standalone EXE
:: ----------------------------
echo ==== STEP 4: Removing the standalone EXE to keep only the ZIP ====
del /q "%INSTALLER_OUT%\%APP_NAME_NO_SPACE%-%APP_VERSION%.exe" 2>nul
del /q "%INSTALLER_OUT%\%APP_NAME%-%APP_VERSION%.exe" 2>nul

echo.
echo The EXE file(s) have been removed. The only file left should be the ZIP in:
echo   %INSTALLER_OUT%
pause
