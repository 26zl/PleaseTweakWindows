# Device Guard Tweaks
# Purpose: Non-interactive action dispatcher.
# Usage: powershell -File device-guard.ps1 -Action "<action-id>"
# Version: 2.1.0
# Last Updated: 2026-01-21
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "security-lsa-protection-enable",
        "security-hvci-enable",
        "security-credential-guard-enable",
        "security-vuln-driver-blocklist",
        "security-wdigest-disable",
        "security-hvci-mandatory",
        "security-secure-launch",
        "menu"
    )]
    [string]$Action = "Menu"
)

$script:ScriptVersion = "2.1.0"

function Write-PTWLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) { "INFO" { "[*]" } "SUCCESS" { "[+]" } "WARNING" { "[!]" } "ERROR" { "[-]" } default { "[*]" } }
    Write-Output "$timestamp $prefix $Message"
}

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

function Set-LsaProtection {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Enable LSA protection (RunAsPPL)")) { return }
    Write-Output "[*] Enabling LSA protection (RunAsPPL) to block credential theft from LSASS memory..."
    Write-Output "[!] WARNING: requires a REBOOT. Rare legacy authentication providers, smartcard middleware or SSO plugins that inject into LSASS may stop working; revert and reboot if so."
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RunAsPPL' -Value 1
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RunAsPPLBoot' -Value 1
    Write-Output "[+] SUCCESS: LSA protection enabled (reboot required)"
}

function Set-HvciEnable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Enable Memory Integrity (HVCI)")) { return }
    Write-Output "[*] Enabling Virtualization-Based Security + Memory Integrity (HVCI)..."
    Write-Output "[!] WARNING: requires a REBOOT and CPU virtualization/SLAT support. HVCI blocks unsigned and incompatible kernel drivers (some anti-cheat, old hardware drivers, virtualization tools). If a driver is incompatible it will be blocked. This is NOT Mandatory mode, so revert + reboot restores it."
    $dg = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
    Set-RegDword -Path $dg -Name 'EnableVirtualizationBasedSecurity' -Value 1
    Set-RegDword -Path $dg -Name 'RequirePlatformSecurityFeatures' -Value 1
    Set-RegDword -Path "$dg\Scenarios\HypervisorEnforcedCodeIntegrity" -Name 'Enabled' -Value 1
    # WasEnabledBy=2 keeps the Windows Security > Core Isolation > Memory Integrity toggle
    # user-controllable (0 greys it out as "managed by your administrator").
    Set-RegDword -Path "$dg\Scenarios\HypervisorEnforcedCodeIntegrity" -Name 'WasEnabledBy' -Value 2
    Write-Output "[+] SUCCESS: Memory Integrity (HVCI) enabled (reboot required)"
}

function Set-CredentialGuardEnable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Enable Credential Guard")) { return }
    Write-Output "[*] Enabling Credential Guard (isolated LSA via VBS)..."
    Write-Output "[!] WARNING: requires a REBOOT and CPU virtualization/SLAT support. Can break legacy SSO, some VPN/credential providers, and Wi-Fi/RADIUS using unsupported protocols. Configured WITHOUT a UEFI lock (LsaCfgFlags=1) so it stays reversible from Windows."
    $dg = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
    Set-RegDword -Path $dg -Name 'EnableVirtualizationBasedSecurity' -Value 1
    Set-RegDword -Path $dg -Name 'RequirePlatformSecurityFeatures' -Value 1
    Set-RegDword -Path "$dg\Scenarios\CredentialGuard" -Name 'Enabled' -Value 1
    # LsaCfgFlags: 1 = enabled without UEFI lock (reversible); 2 = with UEFI lock (hard to revert).
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'LsaCfgFlags' -Value 1
    Write-Output "[+] SUCCESS: Credential Guard enabled (reboot required)"
}

function Set-VulnDriverBlocklist {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Enable Microsoft Vulnerable Driver Blocklist")) { return }
    Write-Output "[*] Enabling Microsoft's vulnerable (BYOVD) driver blocklist..."
    Write-Output "[!] WARNING: requires a REBOOT. Blocks known-vulnerable drivers Microsoft ships in its block list; very rarely a flagged driver is still in legitimate use."
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config' -Name 'VulnerableDriverBlocklistEnable' -Value 1
    Write-Output "[+] SUCCESS: vulnerable driver blocklist enabled (reboot required)"
}

function Set-WDigestDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable WDigest credential caching")) { return }
    Write-Output "[*] Disabling WDigest credential caching (stops plaintext credentials in LSASS)..."
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' -Name 'UseLogonCredential' -Value 0
    Write-Output "[+] SUCCESS: WDigest plaintext credential caching disabled"
}

function Set-HvciMandatory {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Lock Memory Integrity (HVCI) as Mandatory (UEFI-locked)")) { return }
    Write-Output "[*] Locking Memory Integrity (HVCI) as Mandatory via UEFI lock..."
    Write-Output "[!] WARNING: this UEFI-LOCKS HVCI so it can no longer be turned off from Windows without physically clearing the lock in firmware. If an installed kernel driver is incompatible with HVCI, the machine can fail to boot (boot-brick risk). Only enable after HVCI has been on and stable across reboots."
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name 'Locked' -Value 1
    Write-Output "[+] SUCCESS: Memory Integrity locked as Mandatory (reboot required)"
}

function Set-SecureLaunch {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Enable System Guard Secure Launch (DRTM)")) { return }
    Write-Output "[*] Enabling System Guard Secure Launch (Dynamic Root of Trust for Measurement)..."
    Write-Output "[!] WARNING: requires a DRTM-capable CPU and firmware. On incompatible hardware this can prevent the machine from booting. Requires a REBOOT."
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SystemGuard' -Name 'Enabled' -Value 1
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Name 'ConfigureSystemGuardLaunch' -Value 1
    Write-Output "[+] SUCCESS: System Guard Secure Launch enabled (reboot required)"
}

switch ($Action.ToLowerInvariant()) {
    "security-lsa-protection-enable" {
        Backup-RegistryPath -Action $Action -Paths @('HKLM:\SYSTEM\CurrentControlSet\Control\Lsa')
        Set-LsaProtection
        Exit-PTW
    }

    "security-hvci-enable" {
        Backup-RegistryPath -Action $Action -Paths @('HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard')
        Set-HvciEnable
        Exit-PTW
    }

    "security-credential-guard-enable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard',
            'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
        )
        Set-CredentialGuardEnable
        Exit-PTW
    }

    "security-vuln-driver-blocklist" {
        Backup-RegistryPath -Action $Action -Paths @('HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config')
        Set-VulnDriverBlocklist
        Exit-PTW
    }

    "security-wdigest-disable" {
        Backup-RegistryPath -Action $Action -Paths @('HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest')
        Set-WDigestDisable
        Exit-PTW
    }

    "security-hvci-mandatory" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
        )
        Set-HvciMandatory
        Exit-PTW
    }

    "security-secure-launch" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
        )
        Set-SecureLaunch
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
