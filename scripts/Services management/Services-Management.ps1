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
    Write-Output "[-] Administrator privileges required"
    exit 1
}

# Unblock scripts
Get-ChildItem -Path $PSScriptRoot -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

#region Action Dispatcher
switch ($Action.ToLowerInvariant()) {

    "services-disable" {
        Write-Output "[*] Applying Services Optimization (Minimal)..."
        Write-Output "[!] NOTE: Wi-Fi and Bluetooth may not work with minimal services"
        Write-Output "[!] WARNING: This aggressive service set will also:"
        Write-Output "[!]   - DISABLE PRINTING. The Print Spooler is turned off, so all local and"
        Write-Output "[!]     network printing will stop working until services are restored."
        Write-Output "[!]   - STOP FILE/PRINTER SHARING HOSTING. LanmanServer (the 'Server' service)"
        Write-Output "[!]     is disabled, so this PC can no longer host shared folders/printers,"
        Write-Output "[!]     and admin shares (C`$) used by some backup/management tools will break."
        Write-Output "[!]   - AFFECT VISUAL STYLES. The Themes service is disabled, which can revert"
        Write-Output "[!]     the desktop to a classic appearance and break Settings > Personalization."
        Write-Output "[!] Use 'Restore Default Services' to undo all of these changes."
        $regPath = Join-Path $PSScriptRoot "regs\servicesTweaked.reg"
        $defaultRegPath = Join-Path $PSScriptRoot "regs\servicesDefault.reg"
        if (Test-Path $regPath) {
            try {
                $proc = Start-Process -FilePath "regedit.exe" -ArgumentList "/s", "`"$regPath`"" -Wait -PassThru -NoNewWindow
                if ($proc.ExitCode -ne 0) {
                    throw "regedit.exe exited with code $($proc.ExitCode)"
                }
                Start-Sleep -Seconds 2
                # regedit.exe /s can return 0 even on a partial/access-denied import,
                # so spot-check a service this tweak is supposed to DISABLE (Spooler -> Start=4).
                $spoolerStart = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Spooler" -Name "Start" -ErrorAction SilentlyContinue).Start
                if ($null -ne $spoolerStart -and $spoolerStart -ne 4) {
                    Write-Output "[!] WARNING: Verification failed - Spooler Start is '$spoolerStart' (expected 4)."
                    Write-Output "[!] The services import may have been partially blocked. Review with care."
                }
                Write-Output "[+] SUCCESS: Services optimization applied (restart required)"
            } catch {
                Write-Output "[-] ERROR during services optimization: $($_.Exception.Message)"
                Write-Output "[!] Attempting rollback with default services registry..."
                if (Test-Path $defaultRegPath) {
                    $rb = Start-Process -FilePath "regedit.exe" -ArgumentList "/s", "`"$defaultRegPath`"" -Wait -PassThru -NoNewWindow
                    if ($rb.ExitCode -ne 0) {
                        Write-Output "[-] Rollback FAILED (regedit exit code $($rb.ExitCode)). Services may remain disabled - run 'Restore Default Services'."
                    } else {
                        Write-Output "[+] Rollback applied. Restart to restore defaults."
                    }
                } else {
                    Write-Output "[-] Rollback file not found: $defaultRegPath"
                }
                exit 1
            }
        } else {
            Write-Output "[-] ERROR: Registry file not found: $regPath"
            exit 1
        }
        Exit-PTW
    }

    "services-restore" {
        Write-Output "[*] Restoring Services to Default..."
        $regPath = Join-Path $PSScriptRoot "regs\servicesDefault.reg"
        if (Test-Path $regPath) {
            $proc = Start-Process -FilePath "regedit.exe" -ArgumentList "/s", "`"$regPath`"" -Wait -PassThru -NoNewWindow
            Start-Sleep -Seconds 2
            # regedit.exe /s can report exit 0 even on a partial/blocked import, so
            # re-validate a couple of key services actually returned to their defaults
            # (Spooler -> 2 / Automatic, Themes -> 2 / Automatic).
            $spoolerStart = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Spooler" -Name "Start" -ErrorAction SilentlyContinue).Start
            $themesStart = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Themes" -Name "Start" -ErrorAction SilentlyContinue).Start
            if (($proc.ExitCode -ne 0) -or ($spoolerStart -ne 2) -or ($themesStart -ne 2)) {
                Write-Output "[-] ERROR: Services restore did not fully apply (regedit exit $($proc.ExitCode); Spooler Start='$spoolerStart', Themes Start='$themesStart', expected 2)."
                Write-Output "[!] Some services may still be disabled. Try running 'Restore Default Services' again as Administrator."
                exit 1
            }
            Write-Output "[+] SUCCESS: Services restored to default (restart required)"
        } else {
            Write-Output "[-] ERROR: Registry file not found: $regPath"
            exit 1
        }
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
