# System Security Tweaks
# Purpose: Non-interactive action dispatcher.
# Usage: powershell -File system-security.ps1 -Action "<action-id>"
# Version: 2.1.0
# Last Updated: 2026-01-21
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "security-clipboard-data-disable",
        "security-autorun-disable",
        "security-lock-screen-camera-disable",
        "security-lm-hash-disable",
        "security-always-install-elevated-disable",
        "security-ps2-downgrade-protection-enable",
        "security-wcn-disable",
        "security-uac-silent-elevation",
        "security-binary-integrity-harden",
        "security-svchost-mitigation-enable",
        "security-smartscreen-enforce",
        "security-lock-screen-harden",
        "security-account-lockout",
        "security-powershell-audit",
        "security-audit-policy",
        "security-disable-coinstallers",
        "security-wsh-disable",
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

function Set-ClipboardDataCollectionDisabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable clipboard data collection")) { return }
    Write-Output "[*] Disabling clipboard data collection..."

    $regSets = @(
        # Disable Cloud Clipboard (breaks clipboard sync).
        [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'AllowCrossDeviceClipboard'; Type = 'DWord'; Value = 0 },
        # Disable Cloud Clipboard automatic upload.
        [pscustomobject]@{ Path = 'HKCU:\Software\Microsoft\Clipboard'; Name = 'CloudClipboardAutomaticUpload'; Type = 'DWord'; Value = 0 },
        # Disable clipboard history.
        [pscustomobject]@{ Path = 'HKCU:\Software\Microsoft\Clipboard'; Name = 'EnableClipboardHistory'; Type = 'DWord'; Value = 0 },
        # Disable clipboard history via policy.
        [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'AllowClipboardHistory'; Type = 'DWord'; Value = 0 }
    )

    foreach ($r in $regSets) {
        Set-RegValueSafe -Path $r.Path -Name $r.Name -Type $r.Type -Value $r.Value
    }

    # Disable background clipboard data collection (cbdhsvc).
    Disable-ClipboardService

    Write-Output "[+] SUCCESS: clipboard data collection disabled"
}

function Set-AutoPlayAutoRunDisabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable AutoPlay and AutoRun")) { return }
    Write-Output "[*] Disabling AutoPlay and AutoRun..."

    # Disable AutoRun on all drives.
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDriveTypeAutoRun' -Type 'DWord' -Value 255
    # Disable AutoRun.
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoAutorun' -Type 'DWord' -Value 1
    # Disable AutoPlay for non-volume devices.
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'NoAutoplayfornonVolume' -Type 'DWord' -Value 1

    Write-Output "[+] SUCCESS: AutoPlay/AutoRun disabled"
}

function Set-LockScreenCameraDisabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable lock screen camera access")) { return }
    Write-Output "[*] Disabling lock screen camera access..."

    # Disable lock screen camera access.
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Name 'NoLockScreenCamera' -Type 'DWord' -Value 1

    Write-Output "[+] SUCCESS: lock screen camera access disabled"
}

function Set-LmHashStorageDisabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable LM hash storage")) { return }
    Write-Output "[*] Disabling LM password hash storage..."

    # Disable storage of LAN Manager password hashes.
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'NoLMHash' -Type 'DWord' -Value 1

    Write-Output "[+] SUCCESS: LM hash storage disabled"
}

function Set-AlwaysInstallElevatedDisabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable AlwaysInstallElevated")) { return }
    Write-Output "[*] Disabling AlwaysInstallElevated..."

    # Disable AlwaysInstallElevated (prevents MSI privilege escalation).
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer' -Name 'AlwaysInstallElevated' -Type 'DWord' -Value 0

    Write-Output "[+] SUCCESS: AlwaysInstallElevated disabled"
}

function Set-PowerShellV2DowngradeProtection {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable PowerShell 2.0 features")) { return }
    Write-Output "[*] Disabling PowerShell 2.0 features..."

    # Disable PowerShell 2.0 (downgrade protection).
    Disable-OptionalFeaturesSafe -Names @(
        'MicrosoftWindowsPowerShellV2',
        'MicrosoftWindowsPowerShellV2Root'
    )

    Write-Output "[+] SUCCESS: PowerShell 2.0 features disabled"
}

function Set-WindowsConnectNowDisabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable Windows Connect Now wizard")) { return }
    Write-Output "[*] Disabling Windows Connect Now wizard..."

    # Disable Windows Connect Now UI.
    Set-RegValueSafe -Path 'HKLM:\Software\Policies\Microsoft\Windows\WCN\UI' -Name 'DisableWcnUi' -Type 'DWord' -Value 1
    # Disable WCN registrars.
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WCN\Registrars' -Name 'DisableFlashConfigRegistrar' -Type 'DWord' -Value 1
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WCN\Registrars' -Name 'DisableInBand802DOT11Registrar' -Type 'DWord' -Value 1
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WCN\Registrars' -Name 'DisableUPnPRegistrar' -Type 'DWord' -Value 1
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WCN\Registrars' -Name 'DisableWPDRegistrar' -Type 'DWord' -Value 1
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WCN\Registrars' -Name 'EnableRegistrars' -Type 'DWord' -Value 0

    Write-Output "[+] SUCCESS: Windows Connect Now disabled"
}

function Set-UacSilentElevation {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Set administrator consent prompt to silent elevation")) { return }
    Write-Output "[*] Setting administrator elevation to silent (no consent prompt)..."
    Write-Output "[!] WARNING: this is the 'Never notify' User Account Control level. Programs that request administrator rights elevate WITHOUT a prompt, so anything that gets admin can act unattended. EnableLUA stays ON (admin approval mode remains active); the Revert button restores the Windows default prompt."
    # ConsentPromptBehaviorAdmin 0 = elevate without prompting; PromptOnSecureDesktop 0 = no dimmed secure desktop.
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'ConsentPromptBehaviorAdmin' -Type 'DWord' -Value 0
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'PromptOnSecureDesktop' -Type 'DWord' -Value 0
    Write-Output "[+] SUCCESS: administrator elevation set to silent (no prompt)"
}

# ---------------------------------------------------------------------------
# System-security hardening functions.
# ---------------------------------------------------------------------------

function Set-BinaryIntegrityHardening {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Harden binary integrity")) { return }
    Write-Output "[*] Hardening binary integrity (certificate padding check, AMSI, command-line auditing, always-show shortcut extensions)..."
    # CVE-2013-3900: enforce WinVerifyTrust certificate padding check (REG_SZ '1', native + WoW64).
    Set-RegSz -Path 'HKLM:\SOFTWARE\Microsoft\Cryptography\Wintrust\Config' -Name 'EnableCertPaddingCheck' -Value '1'
    Set-RegSz -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Cryptography\Wintrust\Config' -Name 'EnableCertPaddingCheck' -Value '1'
    # Require signed AMSI providers only.
    Set-RegDword -Path 'HKLM:\SOFTWARE\Microsoft\AMSI' -Name 'FeatureBits' -Value 2
    # Audit full command lines in 4688 process-creation events. The registry value alone is
    # necessary-but-not-sufficient: the Process Creation audit subcategory must also be on
    # (GUID used instead of the localized name).
    Set-RegDword -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' -Name 'ProcessCreationIncludeCmdLine_Enabled' -Value 1
    & auditpol.exe /set /subcategory:"{0CCE922B-69AE-11D9-BED3-505054503030}" /success:enable 2>&1 | Out-Null
    # Always show .url/.lnk/.pif extensions (anti-phishing) by removing NeverShowExt.
    foreach ($k in @('InternetShortcut','lnkfile','piffile')) {
        Remove-RegValueSafe -Path "Registry::HKEY_CLASSES_ROOT\$k" -Name 'NeverShowExt'
    }
    Write-Output "[+] SUCCESS: binary integrity hardened"
}

function Set-SvchostMitigation {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Enable svchost mitigation policy")) { return }
    Write-Output "[*] Forcing Microsoft-signed-only, mitigated svchost.exe child processes..."
    Write-Output "[!] WARNING: requires a Business SKU and can break third-party services that inject unsigned DLLs into svchost."
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SCMConfig' -Name 'EnableSvchostMitigationPolicy' -Value 1
    Write-Output "[+] SUCCESS: svchost mitigation policy enabled"
}

function Set-SmartScreenEnforce {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Enforce SmartScreen")) { return }
    Write-Output "[*] Enforcing Microsoft Defender SmartScreen for apps and files (set to Block)..."
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'EnableSmartScreen' -Value 1
    Set-RegSz -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'ShellSmartScreenLevel' -Value 'Block'
    Write-Output "[+] SUCCESS: SmartScreen enforced (Block level)"
}

function Set-LockScreenHardening {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Harden lock screen / interactive logon")) { return }
    Write-Output "[*] Hardening lock screen and interactive logon..."
    Write-Output "[!] WARNING: the sign-in screen will require Ctrl+Alt+Del and will no longer pre-fill the last user name."
    $sysPol = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    Set-RegDword -Path $sysPol -Name 'DontDisplayLastUserName' -Value 1
    Set-RegDword -Path $sysPol -Name 'DontDisplayLockedUserId' -Value 3
    Set-RegDword -Path $sysPol -Name 'DisableCAD' -Value 0
    Set-RegDword -Path $sysPol -Name 'InactivityTimeoutSecs' -Value 120
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'DontDisplayNetworkSelectionUI' -Value 1
    Write-Output "[+] SUCCESS: lock screen hardened"
}

function Set-AccountLockoutPolicy {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Apply account lockout policy")) { return }
    Write-Output "[*] Applying account lockout policy (10 bad attempts, 15-minute lockout + window)..."
    Write-Output "[!] WARNING: after 10 failed sign-ins an account (including a local admin) is locked for 15 minutes. Mistyping your password repeatedly will lock you out temporarily."
    & net.exe accounts /lockoutthreshold:10 /lockoutduration:15 /lockoutwindow:15 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "[WARN] net accounts returned $LASTEXITCODE"
    }
    Write-Output "[+] SUCCESS: account lockout policy applied"
}

# Advanced audit subcategory GUIDs enabled by Set-AdvancedAuditPolicy (success+failure).
$script:PtwAuditSubcategories = @(
    '{0CCE923F-69AE-11D9-BED3-505054503030}',  # Credential Validation
    '{0CCE9215-69AE-11D9-BED3-505054503030}',  # Logon
    '{0CCE921B-69AE-11D9-BED3-505054503030}',  # Special Logon
    '{0CCE922B-69AE-11D9-BED3-505054503030}',  # Process Creation
    '{0CCE9245-69AE-11D9-BED3-505054503030}',  # Removable Storage
    '{0CCE9237-69AE-11D9-BED3-505054503030}',  # Security Group Management
    '{0CCE9217-69AE-11D9-BED3-505054503030}',  # Account Lockout
    '{0CCE9228-69AE-11D9-BED3-505054503030}'   # Sensitive Privilege Use
)

function Set-PowerShellAuditLogging {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Enable PowerShell audit logging")) { return }
    Write-Output "[*] Enabling PowerShell script-block / module / transcription logging..."
    # Script-block logging for both Windows PowerShell and PowerShell 7+ (PowerShellCore).
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' -Name 'EnableScriptBlockLogging' -Value 1
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ScriptBlockLogging' -Name 'EnableScriptBlockLogging' -Value 1
    # Module logging for all modules.
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging' -Name 'EnableModuleLogging' -Value 1
    Set-RegSz -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames' -Name '*' -Value '*'
    # Transcription to an admin-only directory.
    $transcriptDir = Join-Path $env:ProgramData "PleaseTweakWindows\PSTranscripts"
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription' -Name 'EnableTranscripting' -Value 1
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription' -Name 'EnableInvocationHeader' -Value 1
    Set-RegSz -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription' -Name 'OutputDirectory' -Value $transcriptDir
    if (-not (Test-Path -LiteralPath $transcriptDir)) {
        New-Item -ItemType Directory -Path $transcriptDir -Force | Out-Null
    }
    # Lock the transcript directory to SYSTEM + Administrators only (transcripts can contain secrets).
    & icacls.exe "$transcriptDir" /inheritance:r /grant:r "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" 2>&1 | Out-Null
    Write-Output "[+] SUCCESS: PowerShell audit logging enabled (transcripts in $transcriptDir)"
}

function Set-AdvancedAuditPolicy {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Apply advanced audit policy")) { return }
    Write-Output "[*] Applying advanced (subcategory) audit policy..."
    # Force subcategory audit settings to override the legacy category policy.
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'SCENoApplyLegacyAuditPolicy' -Value 1
    foreach ($guid in $script:PtwAuditSubcategories) {
        & auditpol.exe /set /subcategory:"$guid" /success:enable /failure:enable 2>&1 | Out-Null
    }
    Write-Output "[+] SUCCESS: advanced audit policy applied (8 subcategories, success + failure)"
}

function Set-DisableCoInstallers {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable driver co-installers")) { return }
    Write-Output "[*] Disabling driver co-installers..."
    Set-RegDword -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'DisableCoInstallers' -Value 1
    Write-Output "[+] SUCCESS: driver co-installers disabled"
}

function Set-WindowsScriptHostDisabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable Windows Script Host")) { return }
    Write-Output "[*] Disabling Windows Script Host (blocks .vbs/.js execution)..."
    Write-Output "[!] WARNING: this blocks ALL .vbs / .js / .wsf script execution, which breaks legitimate logon scripts, some installers and admin tooling. Revert re-enables WSH."
    Set-RegDword -Path 'HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings' -Name 'Enabled' -Value 0
    Set-RegDword -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows Script Host\Settings' -Name 'Enabled' -Value 0
    Write-Output "[+] SUCCESS: Windows Script Host disabled"
}

switch ($Action.ToLowerInvariant()) {
    "security-clipboard-data-disable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System',
            'HKCU:\Software\Microsoft\Clipboard'
        )
        Set-ClipboardDataCollectionDisabled
        Exit-PTW
    }

    "security-autorun-disable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
        )
        Set-AutoPlayAutoRunDisabled
        Exit-PTW
    }

    "security-lock-screen-camera-disable" {
        Set-LockScreenCameraDisabled
        Exit-PTW
    }

    "security-lm-hash-disable" {
        Set-LmHashStorageDisabled
        Exit-PTW
    }

    "security-always-install-elevated-disable" {
        Set-AlwaysInstallElevatedDisabled
        Exit-PTW
    }

    "security-ps2-downgrade-protection-enable" {
        Set-PowerShellV2DowngradeProtection
        Exit-PTW
    }

    "security-wcn-disable" {
        Set-WindowsConnectNowDisabled
        Exit-PTW
    }

    "security-uac-silent-elevation" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        )
        Set-UacSilentElevation
        Exit-PTW
    }

    "security-binary-integrity-harden" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Microsoft\Cryptography\Wintrust\Config',
            'HKLM:\SOFTWARE\Microsoft\AMSI'
        )
        Set-BinaryIntegrityHardening
        Exit-PTW
    }

    "security-svchost-mitigation-enable" {
        Backup-RegistryPath -Action $Action -Paths @('HKLM:\SYSTEM\CurrentControlSet\Control\SCMConfig')
        Set-SvchostMitigation
        Exit-PTW
    }

    "security-smartscreen-enforce" {
        Backup-RegistryPath -Action $Action -Paths @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\System')
        Set-SmartScreenEnforce
        Exit-PTW
    }

    "security-lock-screen-harden" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        )
        Set-LockScreenHardening
        Exit-PTW
    }

    "security-account-lockout" {
        Set-AccountLockoutPolicy
        Exit-PTW
    }

    "security-powershell-audit" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell',
            'HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore'
        )
        Set-PowerShellAuditLogging
        Exit-PTW
    }

    "security-audit-policy" {
        Backup-RegistryPath -Action $Action -Paths @('HKLM:\SYSTEM\CurrentControlSet\Control\Lsa')
        Set-AdvancedAuditPolicy
        Exit-PTW
    }

    "security-disable-coinstallers" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
        )
        Set-DisableCoInstallers
        Exit-PTW
    }

    "security-wsh-disable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings',
            'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows Script Host\Settings'
        )
        Set-WindowsScriptHostDisabled
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
