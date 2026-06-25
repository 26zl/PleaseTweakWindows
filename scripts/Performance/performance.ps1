# Performance & Power
# Purpose: Non-interactive action dispatcher.
# Usage: powershell -File performance.ps1 -Action "<action-id>"
# Version: 2.1.0
# Last Updated: 2026-01-18
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "power-plan-on",
        "power-plan-default",
        "registry-apply",
        "scaling-fix",
        "scaling-default",
        "hdcp-disable",
        "hdcp-enable",
        "menu"
    )]
    [string]$Action = "Menu"
)

$script:ScriptVersion = "2.1.0"

#region Logging
function Write-PTWLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) { "INFO" { "[*]" } "SUCCESS" { "[+]" } "WARNING" { "[!]" } "ERROR" { "[-]" } default { "[*]" } }
    Write-Output "$timestamp $prefix $Message"
}
#endregion

# Admin check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-PTWLog "Administrator privileges required" "ERROR"
    exit 1
}

# Unblock scripts
Get-ChildItem -Path $PSScriptRoot -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

# Dot-source common functions
$scriptsRoot = Split-Path $PSScriptRoot -Parent
$commonFunctionsPath = Join-Path $scriptsRoot "CommonFunctions.ps1"
if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
} else {
    Write-PTWLog "CommonFunctions.ps1 not found - some features may not work" "WARNING"
}

function Import-LocalRegistryFile {
    param([string]$FileName)
    $regPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "regs") -ChildPath $FileName
    if (Test-Path $regPath) {
        # reg.exe import (via Import-RegistryFile) returns a real failure code; regedit /s does not.
        if (-not (Import-RegistryFile -RegFile $regPath)) {
            Write-Output "[-] WARNING: Registry import failed for $FileName"
        }
    }
}

function Test-PowerSchemeExists {
    param([Parameter(Mandatory=$true)][string]$SchemeId)
    $list = powercfg /list 2>$null
    return ($list -match [regex]::Escape($SchemeId))
}

function Get-ActivePowerSchemeId {
    $active = powercfg /getactivescheme 2>$null
    if ($active -match '([0-9A-Fa-f-]{36})') {
        return $Matches[1]
    }
    return $null
}

#region Action Dispatcher
switch ($Action.ToLowerInvariant()) {

    "power-plan-on" {
        Write-Output "[*] Applying Ultimate Power Plan..."
        $schemeId = "99999999-9999-9999-9999-999999999999"
        if (-not (Test-PowerSchemeExists -SchemeId $schemeId)) {
            cmd /c "powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 $schemeId >nul 2>&1"
        }
        if ((Get-ActivePowerSchemeId) -ne $schemeId) {
            cmd /c "powercfg /SETACTIVE $schemeId >nul 2>&1"
        }
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" -Name "ValueMax" -Value 0
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Value 1
        Write-Output "[+] SUCCESS: Ultimate Power Plan applied (restart required)"
        Exit-PTW
    }

    "power-plan-default" {
        Write-Output "[*] Restoring default power plan..."
        cmd /c "powercfg /restoredefaultschemes >nul 2>&1"
        cmd /c "powercfg /delete 99999999-9999-9999-9999-999999999999 >nul 2>&1"
        Remove-RegValue -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff"
        Write-Output "[+] SUCCESS: Default power plan restored (restart required)"
        Exit-PTW
    }

    "registry-apply" {
        $markerPath = "HKCU:\Software\PleaseTweakWindows"
        if (Get-ItemProperty -Path $markerPath -Name "RegistryOptimized" -ErrorAction SilentlyContinue) {
            Write-Output "[!] Registry tweaks already applied. Skipping to prevent corruption."
            Exit-PTW
        }

        Write-Output "[*] Applying Registry Tweaks..."
        # Back up the top-level hives that Registry-Optimize.reg touches so users can
        # restore individual values without a full System Restore rollback.
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies',
            'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced',
            'HKCU:\Control Panel\Desktop'
        )
        try {
            powercfg -setacvalueindex SCHEME_CURRENT SUB_PCIE EXPRESS 0
            Import-LocalRegistryFile -FileName "Registry-Optimize.reg"

            if (!(Test-Path $markerPath)) { New-Item -Path $markerPath -Force | Out-Null }
            Set-ItemProperty -Path $markerPath -Name "RegistryOptimized" -Value 1
            Write-Output "[+] SUCCESS: Registry tweaks applied (restart required)"
        } catch {
            Write-Output "[-] ERROR during registry tweaks: $($_.Exception.Message)"
            Write-Output "[!] Attempting rollback with default registry settings..."
            Import-LocalRegistryFile -FileName "Registry-Defaults.reg"
            Remove-ItemProperty -Path $markerPath -Name "RegistryOptimized" -ErrorAction SilentlyContinue
            Write-Output "[+] Rollback applied. Restart to restore defaults."
            exit 1
        }
        Exit-PTW
    }

    "scaling-fix" {
        Write-Output "[*] Applying 100% scaling fix..."
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseSensitivity" -Value "10"
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseSpeed" -Value "0"
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0"
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0"
        Set-RegDword -Path "Registry::HKCU\Control Panel\Desktop" -Name "Win8DpiScaling" -Value 1
        Set-RegDword -Path "Registry::HKCU\Control Panel\Desktop" -Name "LogPixels" -Value 96
        Set-RegDword -Path "Registry::HKCU\Control Panel\Desktop" -Name "EnablePerProcessSystemDPI" -Value 0
        Write-Output "[+] SUCCESS: Scaling fix applied (restart required)"
        Exit-PTW
    }

    "scaling-default" {
        Write-Output "[*] Restoring default scaling..."
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseSensitivity" -Value "10"
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseSpeed" -Value "1"
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseThreshold1" -Value "6"
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseThreshold2" -Value "10"
        Remove-RegValue -Path "Registry::HKCU\Control Panel\Desktop" -Name "Win8DpiScaling"
        Remove-RegValue -Path "Registry::HKCU\Control Panel\Desktop" -Name "LogPixels"
        Remove-RegValue -Path "Registry::HKCU\Control Panel\Desktop" -Name "EnablePerProcessSystemDPI"
        Write-Output "[+] SUCCESS: Default scaling restored (restart required)"
        Exit-PTW
    }

    "hdcp-disable" {
        Write-Output "[*] Disabling HDCP..."
        $subkeys = (Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue).Name
        foreach ($key in $subkeys) {
            if ($key -notlike '*Configuration') {
                Set-RegDword -Path "$key" -Name "RMHdcpKeyglobZero" -Value 1
            }
        }
        Write-Output "[+] SUCCESS: HDCP disabled (restart required)"
        Exit-PTW
    }

    "hdcp-enable" {
        Write-Output "[*] Enabling HDCP..."
        $subkeys = (Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue).Name
        foreach ($key in $subkeys) {
            if ($key -notlike '*Configuration') {
                Remove-RegValue -Path "$key" -Name "RMHdcpKeyglobZero"
            }
        }
        Write-Output "[+] SUCCESS: HDCP enabled (restart required)"
        Exit-PTW
    }

    "menu" {
        Write-Output "[i] No interactive menu - use JavaFX GUI to select tweaks"
        Exit-PTW
    }

    default {
        Write-Error "Unknown action: $Action"
        exit 1
    }
}
#endregion
