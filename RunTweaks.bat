@echo off
:: Check if running as administrator
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit
)

:: Run PowerShell script with bypass policy
powershell.exe -ExecutionPolicy Bypass -File "%~dp0PleaseTweakWindowsPScript.ps1"