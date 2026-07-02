# System Security Revert Script

#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Revert','Repair','RevertAndRepair')]
    [string]$Mode = 'RevertAndRepair',

    [Parameter(Mandatory=$false)]
    [string]$Action = ''
)

# Dot-source common functions
$scriptsRoot = Split-Path $PSScriptRoot -Parent
$commonFunctionsPath = Join-Path $scriptsRoot "CommonFunctions.ps1"
if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
} else {
    Write-Output "[-] CommonFunctions.ps1 not found; refusing to continue"
    exit 1
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
                Set-Service -Name $_.Name -StartupType Manual -ErrorAction Stop
                if ($_.Status -ne 'Running') { Start-Service -Name $_.Name -ErrorAction Stop }
            } catch {
                Write-PTWWarning "Failed to reset clipboard service $($_.Name): $($_.Exception.Message)"
                $script:PTWErrorCount++
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

# Reverts for the system-security hardening functions.

function Restore-BinaryIntegrityHardening {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert binary-integrity hardening")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Cryptography\Wintrust\Config' -Name 'EnableCertPaddingCheck'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Cryptography\Wintrust\Config' -Name 'EnableCertPaddingCheck'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\AMSI' -Name 'FeatureBits'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' -Name 'ProcessCreationIncludeCmdLine_Enabled'
    & auditpol.exe /set /subcategory:"{0CCE922B-69AE-11D9-BED3-505054503030}" /success:disable 2>&1 | Out-Null
    $auditpolRc = $LASTEXITCODE
    if ($auditpolRc -ne 0) {
        Write-PTWWarning "Could not restore the Process Creation audit subcategory (auditpol exit $auditpolRc)"
        $script:PTWErrorCount++
    }
    # Restore the Windows default: these shortcut types carry an empty NeverShowExt value.
    foreach ($k in @('InternetShortcut','lnkfile','piffile')) {
        Set-RegValueSafe -Path "Registry::HKEY_CLASSES_ROOT\$k" -Name 'NeverShowExt' -Type 'String' -Value ''
    }
    if ($auditpolRc -eq 0) {
        Write-PTWLog "Reverted binary-integrity hardening" "SUCCESS"
    }
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
    # Restore the Windows 11 account-lockout defaults.
    & net.exe accounts /lockoutthreshold:10 /lockoutduration:10 /lockoutwindow:10 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-PTWWarning "Could not restore account lockout policy (net.exe exit $LASTEXITCODE)"
        $script:PTWErrorCount++
        return
    }
    Write-PTWLog "Restored account lockout policy to the Windows 11 default (threshold 10)" "SUCCESS"
}

# Advanced audit subcategory GUIDs (must mirror system-security.ps1's Set-AdvancedAuditPolicy).
$script:PtwAuditSubcategories = @(
    # System
    '{0CCE9210-69AE-11D9-BED3-505054503030}',  # Security State Change
    '{0CCE9211-69AE-11D9-BED3-505054503030}',  # Security System Extension
    '{0CCE9212-69AE-11D9-BED3-505054503030}',  # System Integrity
    '{0CCE9213-69AE-11D9-BED3-505054503030}',  # IPsec Driver
    '{0CCE9214-69AE-11D9-BED3-505054503030}',  # Other System Events
    # Logon/Logoff
    '{0CCE9215-69AE-11D9-BED3-505054503030}',  # Logon
    '{0CCE9216-69AE-11D9-BED3-505054503030}',  # Logoff
    '{0CCE9217-69AE-11D9-BED3-505054503030}',  # Account Lockout
    '{0CCE921B-69AE-11D9-BED3-505054503030}',  # Special Logon
    '{0CCE921C-69AE-11D9-BED3-505054503030}',  # Other Logon/Logoff Events
    '{0CCE9249-69AE-11D9-BED3-505054503030}',  # Group Membership
    # Object Access (volume-safe subset)
    '{0CCE9224-69AE-11D9-BED3-505054503030}',  # File Share
    '{0CCE9227-69AE-11D9-BED3-505054503030}',  # Other Object Access Events
    '{0CCE9245-69AE-11D9-BED3-505054503030}',  # Removable Storage
    # Privilege Use
    '{0CCE9228-69AE-11D9-BED3-505054503030}',  # Sensitive Privilege Use
    # Detailed Tracking
    '{0CCE922B-69AE-11D9-BED3-505054503030}',  # Process Creation
    '{0CCE9248-69AE-11D9-BED3-505054503030}',  # Plug and Play Events
    # Policy Change
    '{0CCE922F-69AE-11D9-BED3-505054503030}',  # Audit Policy Change
    '{0CCE9230-69AE-11D9-BED3-505054503030}',  # Authentication Policy Change
    '{0CCE9231-69AE-11D9-BED3-505054503030}',  # Authorization Policy Change
    '{0CCE9232-69AE-11D9-BED3-505054503030}',  # MPSSVC Rule-Level Policy Change
    # Account Management
    '{0CCE9235-69AE-11D9-BED3-505054503030}',  # User Account Management
    '{0CCE9236-69AE-11D9-BED3-505054503030}',  # Computer Account Management
    '{0CCE9237-69AE-11D9-BED3-505054503030}',  # Security Group Management
    '{0CCE923A-69AE-11D9-BED3-505054503030}',  # Other Account Management Events
    # Account Logon
    '{0CCE923F-69AE-11D9-BED3-505054503030}'   # Credential Validation
)

# Use Windows 11 audit defaults only when no Apply-time snapshot exists.
$script:PtwAuditDefaultsOn = @{
    '{0CCE9210-69AE-11D9-BED3-505054503030}' = @('/success:enable','/failure:disable')  # Security State Change
    '{0CCE9212-69AE-11D9-BED3-505054503030}' = @('/success:enable','/failure:enable')   # System Integrity
    '{0CCE9214-69AE-11D9-BED3-505054503030}' = @('/success:enable','/failure:enable')   # Other System Events
    '{0CCE9215-69AE-11D9-BED3-505054503030}' = @('/success:enable','/failure:enable')   # Logon
    '{0CCE9216-69AE-11D9-BED3-505054503030}' = @('/success:enable','/failure:disable')  # Logoff
    '{0CCE9217-69AE-11D9-BED3-505054503030}' = @('/success:enable','/failure:enable')   # Account Lockout
    '{0CCE921B-69AE-11D9-BED3-505054503030}' = @('/success:enable','/failure:disable')  # Special Logon
    '{0CCE9235-69AE-11D9-BED3-505054503030}' = @('/success:enable','/failure:enable')   # User Account Management
    '{0CCE9237-69AE-11D9-BED3-505054503030}' = @('/success:enable','/failure:disable')  # Security Group Management
    '{0CCE922F-69AE-11D9-BED3-505054503030}' = @('/success:enable','/failure:disable')  # Audit Policy Change
    '{0CCE9230-69AE-11D9-BED3-505054503030}' = @('/success:enable','/failure:disable')  # Authentication Policy Change
}

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

    # Remove protected transcript data after disabling the policy.
    $transcriptDir = Join-Path $env:ProgramData 'PleaseTweakWindows\PSTranscripts'
    try {
        $existing = Get-Item -LiteralPath $transcriptDir -Force -ErrorAction SilentlyContinue
        if ($existing -and ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            cmd /c rmdir "$transcriptDir" 2>&1 | Out-Null
        } elseif ($existing) {
            Remove-Item -LiteralPath $transcriptDir -Recurse -Force -ErrorAction Stop
        }
        if (Test-Path -LiteralPath $transcriptDir) {
            throw 'The transcript directory still exists after deletion.'
        }
    } catch {
        Write-PTWWarning "PowerShell audit policies were removed, but transcript cleanup failed: $($_.Exception.Message)"
        $script:PTWErrorCount++
        return
    }

    Write-PTWLog "Reverted PowerShell audit logging and removed stored transcripts" "SUCCESS"
}

function Restore-AdvancedAuditPolicy {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert advanced audit policy")) { return }
    # Restore the Apply-time audit snapshot when available.
    $auditBackup = Get-PTWStatePath 'audit-policy-backup.csv'
    if (Test-Path -LiteralPath $auditBackup) {
        & auditpol.exe /restore /file:"$auditBackup" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'SCENoApplyLegacyAuditPolicy'
            Remove-Item -LiteralPath $auditBackup -Force -ErrorAction SilentlyContinue
            Write-PTWLog "Restored audit policy from the apply-time snapshot (exact pre-tweak state)" "SUCCESS"
            return
        }
        Write-PTWWarning "auditpol /restore failed (exit $LASTEXITCODE) — falling back to the Windows default baseline"
    }
    # Without a snapshot, restore the documented Windows client baseline.
    $auditFailures = 0
    foreach ($guid in $script:PtwAuditSubcategories) {
        if ($script:PtwAuditDefaultsOn.ContainsKey($guid)) {
            $flags = $script:PtwAuditDefaultsOn[$guid]
            & auditpol.exe /set /subcategory:"$guid" @flags 2>&1 | Out-Null
        } else {
            & auditpol.exe /set /subcategory:"$guid" /success:disable /failure:disable 2>&1 | Out-Null
        }
        if ($LASTEXITCODE -ne 0) { $auditFailures++ }
    }
    if ($auditFailures -gt 0) {
        Write-PTWWarning "$auditFailures audit subcategory defaults could not be restored"
        $script:PTWErrorCount += $auditFailures
        return
    }
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'SCENoApplyLegacyAuditPolicy'
    Write-PTWLog "Reverted advanced audit policy toward Windows defaults (no snapshot found; default-on subcategories preserved). Verify on a clean Win11 if exact parity matters." "SUCCESS"
}

function Restore-DisableCoInstaller {
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

function Restore-FilterAdminToken {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert Admin Approval Mode for built-in Administrator")) { return }
    # Remove the value to restore its absent Windows default.
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'FilterAdministratorToken'
    Write-PTWLog "Reverted FilterAdministratorToken (override removed)" "SUCCESS"
}

function Restore-Ntfs8Dot3Disable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert NTFS 8.3 short-name creation")) { return }
    # The Windows default is 2 (per-volume), NOT absent — write 2 rather than remove.
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'NtfsDisable8dot3NameCreation' -Type 'DWord' -Value 2
    Write-PTWLog "Reverted NTFS 8.3 short-name creation to Windows default (2)" "SUCCESS"
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
    'security-disable-coinstallers'         = @{ Revert = { Restore-DisableCoInstaller } ; Repair = { } }
    'security-wsh-disable'                  = @{ Revert = { Restore-WindowsScriptHost } ; Repair = { } }
    'security-filter-admin-token'           = @{ Revert = { Restore-FilterAdminToken } ; Repair = { } }
    'security-ntfs-8dot3-disable'           = @{ Revert = { Restore-Ntfs8Dot3Disable } ; Repair = { } }

    # Map shortened GUI restore IDs to their Apply counterparts.
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

Write-PTWLog "Restore Default applies Windows defaults; it does not reconstruct prior custom or organization-managed values." "INFO"

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
    Invoke-Mode -RevertBlock { Restore-DisableCoInstaller } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-WindowsScriptHost } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-FilterAdminToken } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-Ntfs8Dot3Disable } -RepairBlock { }

    Write-PTWLog "Done. A restart may be required for some changes to fully take effect." "SUCCESS"
    Exit-PTW
}

# Strip the -revert suffix before action-map lookup.
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
