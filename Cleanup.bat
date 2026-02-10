@echo off
title PleaseTweakWindows - Cleanup
color 0C
setlocal

echo.
echo ========================================================================
echo  PleaseTweakWindows - Cleanup Script
echo ========================================================================
echo.

echo [*] Removing build artifacts...
if exist "target" rd /S /Q "target"
if exist "dist" rd /S /Q "dist"
if exist "PleaseTweakWindows.zip" del /Q "PleaseTweakWindows.zip"
if exist "dependency-reduced-pom.xml" del /Q "dependency-reduced-pom.xml"

echo [*] Removing log files...
if exist "logs" (
    del /Q "logs\*.log" 2>nul
    del /Q "logs\*.tmp" 2>nul
)

echo [*] Removing temp script folders...
for /d %%D in ("%TEMP%\pleasetweakwindows-scripts*") do rd /S /Q "%%D"

echo.
echo [+] Cleanup complete.
echo.
pause
endlocal
