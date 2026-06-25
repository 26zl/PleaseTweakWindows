# System Security Revert Script
# Purpose: Reverts the changes made by system-security.ps1 (v2.1.0) back to Windows defaults where possible.
# Usage:
#   powershell -File revert-system-security.ps1 -Mode <Revert|Repair|RevertAndRepair> [-Action "<action-id>"]
# Notes:
#   - Revert: removes policy/override registry values created by the security hardening actions (returns to "not configured"/defaults).
#   - Repair: re-enables optional features/capabilities/services that the hardening actions may have disabled/removed.

#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Revert','Repair','RevertAndRepair')]
    [string]$Mode = 'RevertAndRepair',

    [Parameter(Mandatory=$false)]
    [string]$Action = ''
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

# Admin check (kept explicit for nicer message)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-PTWLog "Administrator privileges required" "ERROR"
    exit 1
}

function Restore-ClipboardDataDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert clipboard data collection policies")) { return }

    foreach ($x in @(
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='AllowCrossDeviceClipboard' },
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='AllowClipboardHistory' },
        @{ Path='HKCU:\Software\Microsoft\Clipboard'; Name='CloudClipboardAutomaticUpload' },
        @{ Path='HKCU:\Software\Microsoft\Clipboard'; Name='EnableClipboardHistory' }
    )) {
        Remove-RegValueSafe -Path $x.Path -Name $x.Name
    }

    Write-PTWLog "Reverted clipboard policy overrides (where present)" "SUCCESS"
}

function Repair-ClipboardDataDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("cbdhsvc", "Re-enable clipboard service")) { return }

    # cbdhsvc is usually Demand/Manual and starts when needed
    Enable-ServiceSafe -Names @('cbdhsvc') -StartupType 'Manual'

    # Also handle per-user cbdhsvc_* instances
    try {
        Get-Service -Name 'cbdhsvc_*' -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Set-Service -Name $_.Name -StartupType Manual -ErrorAction SilentlyContinue
                if ($_.Status -ne 'Running') { Start-Service -Name $_.Name -ErrorAction SilentlyContinue }
            } catch {
                Write-Verbose "Failed to reset clipboard service $($_.Name)."
            }
        }
    } catch {
        Write-Verbose "Failed to enumerate per-user clipboard services."
    }

    Write-PTWLog "Repair attempted: clipboard services set back to Manual" "SUCCESS"
}

function Restore-AutorunDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert AutoPlay/AutoRun overrides")) { return }

    foreach ($x in @(
        @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='NoDriveTypeAutoRun' },
        @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='NoAutorun' },
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name='NoAutoplayfornonVolume' }
    )) {
        Remove-RegValueSafe -Path $x.Path -Name $x.Name
    }

    Write-PTWLog "Reverted AutoPlay/AutoRun overrides (where present)" "SUCCESS"
}

function Restore-LockScreenCameraDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert lock screen camera override")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Name 'NoLockScreenCamera'
    Write-PTWLog "Reverted lock screen camera override (where present)" "SUCCESS"
}

function Restore-LmHashDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert LM hash storage override")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'NoLMHash'
    Write-PTWLog "Reverted LM hash storage override (where present)" "SUCCESS"
}

function Restore-AlwaysInstallElevatedDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert AlwaysInstallElevated override")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer' -Name 'AlwaysInstallElevated'
    Write-PTWLog "Reverted AlwaysInstallElevated override (where present)" "SUCCESS"
}

function Repair-PowerShellV2Disable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Windows Features", "Re-enable PowerShell 2.0 optional features")) { return }
    Enable-OptionalFeaturesSafe -Names @(
        'MicrosoftWindowsPowerShellV2',
        'MicrosoftWindowsPowerShellV2Root'
    )
    Write-PTWLog "Repair attempted: PowerShell 2.0 optional features enabled (where available)" "SUCCESS"
}

function Restore-WcnDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert Windows Connect Now policy overrides")) { return }

    foreach ($x in @(
        @{ Path='HKLM:\Software\Policies\Microsoft\Windows\WCN\UI'; Name='DisableWcnUi' },
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WCN\Registrars'; Name='DisableFlashConfigRegistrar' },
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WCN\Registrars'; Name='DisableInBand802DOT11Registrar' },
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WCN\Registrars'; Name='DisableUPnPRegistrar' },
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WCN\Registrars'; Name='DisableWPDRegistrar' },
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WCN\Registrars'; Name='EnableRegistrars' }
    )) {
        Remove-RegValueSafe -Path $x.Path -Name $x.Name
    }

    Write-PTWLog "Reverted Windows Connect Now overrides (where present)" "SUCCESS"
}

function Restore-UacSilentElevation {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Restore default administrator consent prompt")) { return }
    # Windows defaults: ConsentPromptBehaviorAdmin=5 (prompt for consent), PromptOnSecureDesktop=1 (dimmed prompt).
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'ConsentPromptBehaviorAdmin' -Type 'DWord' -Value 5
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'PromptOnSecureDesktop' -Type 'DWord' -Value 1
    Write-PTWLog "Restored default administrator consent prompt (Notify level)" "SUCCESS"
}

# ---------------------------------------------------------------------------
# Reverts for the system-security hardening functions.
# ---------------------------------------------------------------------------

function Restore-BinaryIntegrityHardening {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert binary-integrity hardening")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Cryptography\Wintrust\Config' -Name 'EnableCertPaddingCheck'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Cryptography\Wintrust\Config' -Name 'EnableCertPaddingCheck'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\AMSI' -Name 'FeatureBits'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' -Name 'ProcessCreationIncludeCmdLine_Enabled'
    & auditpol.exe /set /subcategory:"{0CCE922B-69AE-11D9-BED3-505054503030}" /success:disable 2>&1 | Out-Null
    # Restore the Windows default: these shortcut types carry an empty NeverShowExt value.
    foreach ($k in @('InternetShortcut','lnkfile','piffile')) {
        Set-RegValueSafe -Path "Registry::HKEY_CLASSES_ROOT\$k" -Name 'NeverShowExt' -Type 'String' -Value ''
    }
    Write-PTWLog "Reverted binary-integrity hardening" "SUCCESS"
}

function Restore-SvchostMitigation {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert svchost mitigation policy")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SCMConfig' -Name 'EnableSvchostMitigationPolicy'
    Write-PTWLog "Reverted svchost mitigation policy" "SUCCESS"
}

function Restore-SmartScreenEnforce {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert SmartScreen enforcement")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'EnableSmartScreen'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'ShellSmartScreenLevel'
    Write-PTWLog "Reverted SmartScreen enforcement (policy overrides removed)" "SUCCESS"
}

function Restore-LockScreenHardening {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert lock screen hardening")) { return }
    $sysPol = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    foreach ($n in @('DontDisplayLastUserName','DontDisplayLockedUserId','DisableCAD','InactivityTimeoutSecs')) {
        Remove-RegValueSafe -Path $sysPol -Name $n
    }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'DontDisplayNetworkSelectionUI'
    Write-PTWLog "Reverted lock screen / interactive-logon hardening" "SUCCESS"
}

function Restore-AccountLockoutPolicy {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert account lockout policy")) { return }
    & net.exe accounts /lockoutthreshold:0 2>&1 | Out-Null
    Write-PTWLog "Reverted account lockout policy (threshold 0 = no lockout)" "SUCCESS"
}

# Advanced audit subcategory GUIDs (must mirror system-security.ps1's Set-AdvancedAuditPolicy).
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

function Restore-PowerShellAuditLogging {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert PowerShell audit logging")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' -Name 'EnableScriptBlockLogging'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ScriptBlockLogging' -Name 'EnableScriptBlockLogging'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging' -Name 'EnableModuleLogging'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames' -Name '*'
    Remove-RegKeySafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription' -Name 'EnableTranscripting'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription' -Name 'EnableInvocationHeader'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription' -Name 'OutputDirectory'
    Write-PTWLog "Reverted PowerShell audit logging (policy overrides removed)" "SUCCESS"
}

function Restore-AdvancedAuditPolicy {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert advanced audit policy")) { return }
    foreach ($guid in $script:PtwAuditSubcategories) {
        & auditpol.exe /set /subcategory:"$guid" /success:disable /failure:disable 2>&1 | Out-Null
    }
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'SCENoApplyLegacyAuditPolicy'
    Write-PTWLog "Reverted advanced audit policy (subcategories disabled; SCENoApplyLegacyAuditPolicy removed)" "SUCCESS"
}

function Restore-DisableCoInstallers {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert driver co-installer disable")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'DisableCoInstallers'
    Write-PTWLog "Reverted driver co-installer disable (override removed)" "SUCCESS"
}

function Restore-WindowsScriptHost {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Re-enable Windows Script Host")) { return }
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings' -Name 'Enabled' -Type 'DWord' -Value 1
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows Script Host\Settings' -Name 'Enabled' -Type 'DWord' -Value 1
    Write-PTWLog "Re-enabled Windows Script Host (Enabled=1)" "SUCCESS"
}

$actionMap = @{
    'security-clipboard-data-disable'       = @{ Revert = { Restore-ClipboardDataDisable } ; Repair = { Repair-ClipboardDataDisable } }
    'security-autorun-disable'              = @{ Revert = { Restore-AutorunDisable } ; Repair = { } }
    'security-lock-screen-camera-disable'   = @{ Revert = { Restore-LockScreenCameraDisable } ; Repair = { } }
    'security-lm-hash-disable'              = @{ Revert = { Restore-LmHashDisable } ; Repair = { } }
    'security-always-install-elevated-disable' = @{ Revert = { Restore-AlwaysInstallElevatedDisable } ; Repair = { } }
    'security-ps2-downgrade-protection-enable' = @{ Revert = { } ; Repair = { Repair-PowerShellV2Disable } }
    'security-wcn-disable'                  = @{ Revert = { Restore-WcnDisable } ; Repair = { } }
    'security-uac-silent-elevation'         = @{ Revert = { Restore-UacSilentElevation } ; Repair = { } }
    'security-binary-integrity-harden'      = @{ Revert = { Restore-BinaryIntegrityHardening } ; Repair = { } }
    'security-svchost-mitigation-enable'    = @{ Revert = { Restore-SvchostMitigation } ; Repair = { } }
    'security-smartscreen-enforce'          = @{ Revert = { Restore-SmartScreenEnforce } ; Repair = { } }
    'security-lock-screen-harden'           = @{ Revert = { Restore-LockScreenHardening } ; Repair = { } }
    'security-account-lockout'              = @{ Revert = { Restore-AccountLockoutPolicy } ; Repair = { } }
    'security-powershell-audit'             = @{ Revert = { Restore-PowerShellAuditLogging } ; Repair = { } }
    'security-audit-policy'                 = @{ Revert = { Restore-AdvancedAuditPolicy } ; Repair = { } }
    'security-disable-coinstallers'         = @{ Revert = { Restore-DisableCoInstallers } ; Repair = { } }
    'security-wsh-disable'                  = @{ Revert = { Restore-WindowsScriptHost } ; Repair = { } }

    # Alias keys: the GUI (TweakRegistry.cs) sends revert IDs for these toggles WITHOUT
    # the apply verb (e.g. 'security-clipboard-data-revert'), which strip to the base ID below.
    # Map each base ID to the SAME scriptblocks as its '-disable'/'-enable' counterpart so the
    # revert resolves instead of hitting the unknown-action branch.
    'security-clipboard-data'               = @{ Revert = { Restore-ClipboardDataDisable } ; Repair = { Repair-ClipboardDataDisable } }
    'security-autorun'                      = @{ Revert = { Restore-AutorunDisable } ; Repair = { } }
    'security-lock-screen-camera'           = @{ Revert = { Restore-LockScreenCameraDisable } ; Repair = { } }
    'security-lm-hash'                      = @{ Revert = { Restore-LmHashDisable } ; Repair = { } }
    'security-always-install-elevated'      = @{ Revert = { Restore-AlwaysInstallElevatedDisable } ; Repair = { } }
    'security-ps2-downgrade-protection'     = @{ Revert = { } ; Repair = { Repair-PowerShellV2Disable } }
    'security-wcn'                          = @{ Revert = { Restore-WcnDisable } ; Repair = { } }
}

function Invoke-Mode {
    param([scriptblock]$RevertBlock, [scriptblock]$RepairBlock)

    $m = $Mode.ToLowerInvariant()
    if ($m -eq 'revert' -or $m -eq 'revertandrepair') {
        if ($RevertBlock) { & $RevertBlock }
    }
    if ($m -eq 'repair' -or $m -eq 'revertandrepair') {
        if ($RepairBlock) { & $RepairBlock }
    }
}

Write-PTWLog "Note: revert restores Windows DEFAULTS, not any prior custom/hardened values you may have had on shared SYSTEM keys (e.g. LmCompatibilityLevel, restrictanonymous, AutoShareWks, NetbiosOptions). Original values are captured in the registry-backup .reg files under the registry-backups folder of PTW_LOG_DIR if you need to restore them manually." "INFO"

if ([string]::IsNullOrWhiteSpace($Action)) {
    Write-PTWLog "No -Action provided; running Mode=$Mode for all security revert actions." "INFO"

    # Run in a sensible order (policy/registry first, then repair)
    Invoke-Mode -RevertBlock { Restore-ClipboardDataDisable } -RepairBlock { Repair-ClipboardDataDisable }
    Invoke-Mode -RevertBlock { Restore-AutorunDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-LockScreenCameraDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-LmHashDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-AlwaysInstallElevatedDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { } -RepairBlock { Repair-PowerShellV2Disable }
    Invoke-Mode -RevertBlock { Restore-WcnDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-UacSilentElevation } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-BinaryIntegrityHardening } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-SvchostMitigation } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-SmartScreenEnforce } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-LockScreenHardening } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-AccountLockoutPolicy } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-PowerShellAuditLogging } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-AdvancedAuditPolicy } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-DisableCoInstallers } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-WindowsScriptHost } -RepairBlock { }

    Write-PTWLog "Done. A restart may be required for some changes to fully take effect." "SUCCESS"
    Exit-PTW
}

# Strip -revert suffix: Java sends revert action IDs like 'security-improve-network-revert'
# but actionMap keys use the base apply IDs like 'security-improve-network'
$k = $Action.ToLowerInvariant().Trim() -replace '-revert$', ''
if (-not $actionMap.ContainsKey($k)) {
    Write-PTWLog "Unknown action: $Action" "ERROR"
    Write-Output "Known actions: $($actionMap.Keys | Sort-Object | ForEach-Object { $_ } | Out-String)"
    exit 1
}

Write-PTWLog "Running Mode=$Mode for Action=$k" "INFO"
Invoke-Mode -RevertBlock $actionMap[$k].Revert -RepairBlock $actionMap[$k].Repair
Write-PTWLog "Done." "SUCCESS"
Exit-PTW
