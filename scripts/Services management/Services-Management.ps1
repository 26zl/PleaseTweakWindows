# Services Management
# Purpose: Non-interactive action dispatcher.
# Usage: powershell -File Services-Management.ps1 -Action "<action-id>"
# Version: 2.1.0
# Last Updated: 2026-01-18
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "services-disable",
        "services-restore",
        "menu"
    )]
    [string]$Action = "Menu"
)

$script:ScriptVersion = "2.1.0"

# Dot-source common functions
$scriptsRoot = Split-Path $PSScriptRoot -Parent
$commonFunctionsPath = Join-Path $scriptsRoot "CommonFunctions.ps1"
if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
} else {
    Write-Output "[!] CommonFunctions.ps1 not found - some features may not work"
}

# Admin check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-PTWLog "Administrator privileges required" "ERROR"
    exit 1
}

# Unblock scripts
Get-ChildItem -Path $PSScriptRoot -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

#region Action Dispatcher
switch ($Action.ToLowerInvariant()) {

    "services-disable" {
        Write-Output "[*] Applying Services Optimization (Minimal)..."
        Write-Output "[!] NOTE: Wi-Fi and Bluetooth may not work with minimal services"
        $regPath = Join-Path $PSScriptRoot "regs\servicesTweaked.reg"
        $defaultRegPath = Join-Path $PSScriptRoot "regs\servicesDefault.reg"
        if (Test-Path $regPath) {
            try {
                $proc = Start-Process -FilePath "regedit.exe" -ArgumentList "/s", "`"$regPath`"" -Wait -PassThru -NoNewWindow
                if ($proc.ExitCode -ne 0) {
                    throw "regedit.exe exited with code $($proc.ExitCode)"
                }
                Start-Sleep -Seconds 2
                Write-Output "[+] SUCCESS: Services optimization applied (restart required)"
            } catch {
                Write-Output "[-] ERROR during services optimization: $($_.Exception.Message)"
                Write-Output "[!] Attempting rollback with default services registry..."
                if (Test-Path $defaultRegPath) {
                    Start-Process -FilePath "regedit.exe" -ArgumentList "/s", "`"$defaultRegPath`"" -Wait -NoNewWindow
                    Write-Output "[+] Rollback applied. Restart to restore defaults."
                } else {
                    Write-Output "[-] Rollback file not found: $defaultRegPath"
                }
                exit 1
            }
        } else {
            Write-Output "[-] ERROR: Registry file not found: $regPath"
            exit 1
        }
        exit 0
    }

    "services-restore" {
        Write-Output "[*] Restoring Services to Default..."
        $regPath = Join-Path $PSScriptRoot "regs\servicesDefault.reg"
        if (Test-Path $regPath) {
            Start-Process -FilePath "regedit.exe" -ArgumentList "/s", "`"$regPath`"" -Wait -NoNewWindow
            Start-Sleep -Seconds 2
            Write-Output "[+] SUCCESS: Services restored to default (restart required)"
        } else {
            Write-Output "[-] ERROR: Registry file not found: $regPath"
            exit 1
        }
        exit 0
    }

    "menu" {
        Write-Output "[i] No interactive menu - use JavaFX GUI to select tweaks"
        exit 0
    }

    default {
        Write-Error "Unknown action: $Action"
        exit 1
    }
}
#endregion
