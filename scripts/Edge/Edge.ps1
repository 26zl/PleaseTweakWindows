# Microsoft Edge Hardening
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "edge-harden",
        "edge-harden-revert",
        "edge-hardcore",
        "edge-hardcore-revert",
        "menu"
    )]
    [string]$Action = "Menu"
)

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
    Write-PTWLog "CommonFunctions.ps1 not found; refusing to continue" "ERROR"
    exit 1
}

$EdgePolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'

# Baseline DWORD policies (security, break nothing in normal browsing).
$script:EdgeBaselineDword = @{
    SmartScreenEnabled                        = 1
    SmartScreenPuaEnabled                     = 1
    SmartScreenForTrustedDownloadsEnabled     = 1
    PreventSmartScreenPromptOverride          = 1
    PreventSmartScreenPromptOverrideForFiles  = 1
    TyposquattingCheckerEnabled               = 1
    SSLErrorOverrideAllowed                   = 0
    DownloadRestrictions                      = 1
    AudioSandboxEnabled                       = 1
    SitePerProcess                            = 1
    EncryptedClientHelloEnabled               = 1
    BasicAuthOverHttpEnabled                  = 0
    BlockThirdPartyCookies                    = 1
    PaymentMethodQueryEnabled                 = 0
}
# HardCore DWORD policies (performance / compatibility cost).
$script:EdgeHardcoreDword = @{
    EnhanceSecurityMode                       = 2
    TrackingPrevention                        = 3
    InsecurePrivateNetworkRequestsAllowed     = 0
    SharedArrayBufferUnrestrictedAccessAllowed = 0
}

#region Action Dispatcher
switch ($Action.ToLowerInvariant()) {

    "edge-harden" {
        Write-Output "[*] Applying Microsoft Edge security baseline..."
        Backup-RegistryPath -Action $Action -Paths @($EdgePolicy)
        foreach ($name in $script:EdgeBaselineDword.Keys) {
            Set-RegDword -Path $EdgePolicy -Name $name -Value $script:EdgeBaselineDword[$name]
        }
        # Secure DNS (DoH) over Edge's own resolver — REG_SZ.
        Set-RegSz -Path $EdgePolicy -Name 'DnsOverHttpsMode' -Value 'automatic'
        Write-Output "[+] SUCCESS: Edge security baseline applied (restart Edge to take effect)"
        Exit-PTW
    }

    "edge-harden-revert" {
        Write-Output "[*] Reverting Microsoft Edge security baseline..."
        foreach ($name in $script:EdgeBaselineDword.Keys) {
            Remove-RegValueSafe -Path $EdgePolicy -Name $name
        }
        Remove-RegValueSafe -Path $EdgePolicy -Name 'DnsOverHttpsMode'
        Write-Output "[+] SUCCESS: Edge security baseline reverted"
        Exit-PTW
    }

    "edge-hardcore" {
        Write-Output "[*] Applying Microsoft Edge HardCore hardening..."
        Write-Output "[!] WARNING: Enhanced Security Mode (Strict, disables JIT) and Strict tracking prevention can slow or break some sites; blocking insecure private-network requests can break some intranet/IoT web UIs."
        Backup-RegistryPath -Action $Action -Paths @($EdgePolicy)
        foreach ($name in $script:EdgeHardcoreDword.Keys) {
            Set-RegDword -Path $EdgePolicy -Name $name -Value $script:EdgeHardcoreDword[$name]
        }
        Write-Output "[+] SUCCESS: Edge HardCore hardening applied (restart Edge to take effect)"
        Exit-PTW
    }

    "edge-hardcore-revert" {
        Write-Output "[*] Reverting Microsoft Edge HardCore hardening..."
        foreach ($name in $script:EdgeHardcoreDword.Keys) {
            Remove-RegValueSafe -Path $EdgePolicy -Name $name
        }
        Write-Output "[+] SUCCESS: Edge HardCore hardening reverted"
        Exit-PTW
    }

    "menu" {
        Write-Output "[i] No interactive menu - use the GUI to select tweaks"
        Exit-PTW
    }

    default {
        Write-Error "Unknown action: $Action"
        exit 1
    }
}
#endregion
