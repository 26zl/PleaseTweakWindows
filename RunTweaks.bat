@echo off
title PleaseTweakWindows
color 0F

REM Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo [ERROR] Administrator privileges required!
    echo.
    echo Please right-click this file and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)

cls
echo.
echo ================================================================================
echo                           PleaseTweakWindows
echo                        Windows Optimization Tool
echo ================================================================================
echo.
echo  Starting PowerShell Interface...
echo.
echo  For the best experience, we recommend installing:
echo  - Windows Terminal (for modern terminal experience)
echo  - PowerShell 7+ (for better performance and features)
echo.
echo  Download from: https://aka.ms/terminal
echo.
echo ================================================================================
echo.

REM Try PowerShell 7+ first (pwsh.exe)
where pwsh.exe >nul 2>&1
if %errorLevel% equ 0 (
    echo [SUCCESS] Using PowerShell 7+ with Windows Terminal
    echo.
    pwsh.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0PleaseTweakWindowsPScript.ps1"
    goto end
)

REM Fallback to Windows PowerShell 5.1
echo [INFO] PowerShell 7+ not found, using Windows PowerShell 5.1
echo [NOTE] For better experience, install PowerShell 7+ and Windows Terminal
echo.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0PleaseTweakWindowsPScript.ps1"
goto end


:end
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] An error occurred during execution.
    echo.
    echo Press any key to exit...
    pause >nul
)
exit /b %errorlevel%