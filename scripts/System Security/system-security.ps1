# System Security Tweaks
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
        "security-filter-admin-token",
        "security-ntfs-8dot3-disable",
        "menu"
    )]
    [string]$Action = "Menu"
)

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
    Write-PTWLog "CommonFunctions.ps1 not found; refusing to continue" "ERROR"
    exit 1
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
    Write-Output "[!] WARNING: this is the 'Never notify' User Account Control level. Programs that request administrator rights elevate WITHOUT a prompt, so anything that gets admin can act unattended. EnableLUA stays ON (admin approval mode remains active); Restore Default restores the Windows prompt."
    # ConsentPromptBehaviorAdmin 0 = elevate without prompting; PromptOnSecureDesktop 0 = no dimmed secure desktop.
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'ConsentPromptBehaviorAdmin' -Type 'DWord' -Value 0
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'PromptOnSecureDesktop' -Type 'DWord' -Value 0
    Write-Output "[+] SUCCESS: administrator elevation set to silent (no prompt)"
}

# System-security hardening functions.

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
    # Enable command-line capture and the Process Creation audit subcategory.
    Set-RegDword -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' -Name 'ProcessCreationIncludeCmdLine_Enabled' -Value 1
    & auditpol.exe /set /subcategory:"{0CCE922B-69AE-11D9-BED3-505054503030}" /success:enable 2>&1 | Out-Null
    $auditpolRc = $LASTEXITCODE
    if ($auditpolRc -ne 0) {
        Write-Warning "[WARN] auditpol (Process Creation) returned $auditpolRc - command-line auditing may not be active"
        $script:PTWErrorCount++
    }
    # Always show .url/.lnk/.pif extensions (anti-phishing) by removing NeverShowExt.
    foreach ($k in @('InternetShortcut','lnkfile','piffile')) {
        Remove-RegValueSafe -Path "Registry::HKEY_CLASSES_ROOT\$k" -Name 'NeverShowExt'
    }
    if ($auditpolRc -eq 0) {
        Write-Output "[+] SUCCESS: binary integrity hardened"
    } else {
        Write-Output "[!] PARTIAL: binary integrity registry hardening applied, but enabling the Process Creation audit subcategory failed"
    }
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
    Write-Output "[*] Applying account lockout policy (3 bad attempts, 15-minute lockout + window)..."
    Write-Output "[!] WARNING: after 3 failed sign-ins an account (including a local admin) is locked for 15 minutes. Mistyping your password repeatedly will lock you out temporarily."
    # Threshold 3 satisfies both DISA STIG WN11-AC-000010 (<=3) and CIS L1 (<=5).
    & net.exe accounts /lockoutthreshold:3 /lockoutduration:15 /lockoutwindow:15 2>&1 | Out-Null
    $netRc = $LASTEXITCODE
    if ($netRc -ne 0) {
        Write-Warning "[WARN] net accounts returned $netRc"
        $script:PTWErrorCount++
        Write-Output "[-] FAILED: account lockout policy not applied (net accounts returned $netRc)"
        return
    }
    Write-Output "[+] SUCCESS: account lockout policy applied"
}

# Enable the CIS-aligned audit subcategories while excluding extreme-volume object-access events.
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
    # Remove pre-existing reparse points before securing the transcript directory.
    $existingTd = Get-Item -LiteralPath $transcriptDir -Force -ErrorAction SilentlyContinue
    if ($existingTd -and ($existingTd.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        Write-Output "[!] '$transcriptDir' is a reparse point — removing the link before locking it down."
        cmd /c rmdir "$transcriptDir" 2>&1 | Out-Null
        # Fail closed (mirrors debloat.ps1): if the link survived, do NOT fall through to icacls.
        if ((Test-Path -LiteralPath $transcriptDir) -or (Get-Item -LiteralPath $transcriptDir -Force -ErrorAction SilentlyContinue)) {
            Write-Output "[-] ERROR: could not remove the reparse point at $transcriptDir. Aborting to avoid an unsafe privileged icacls."
            $script:PTWErrorCount++
            return
        }
    }
    if (-not (Test-Path -LiteralPath $transcriptDir)) {
        New-Item -ItemType Directory -Path $transcriptDir -Force | Out-Null
    }
    # Recheck for a reparse point immediately before privileged ACL changes.
    $tdFinal = Get-Item -LiteralPath $transcriptDir -Force -ErrorAction SilentlyContinue
    if ((-not $tdFinal) -or ($tdFinal.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        Write-Output "[-] ERROR: '$transcriptDir' is missing or a reparse point right before lockdown. Aborting."
        $script:PTWErrorCount++
        return
    }
    # Lock the transcript directory to SYSTEM + Administrators only (transcripts can contain secrets).
    & icacls.exe "$transcriptDir" /inheritance:r /grant:r "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Output "[-] ERROR: could not secure the PowerShell transcript directory (icacls exit $LASTEXITCODE)"
        $script:PTWErrorCount++
        return
    }
    Write-Output "[+] SUCCESS: PowerShell audit logging enabled (transcripts in $transcriptDir)"
}

function Set-AdvancedAuditPolicy {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Apply advanced audit policy")) { return }
    Write-Output "[*] Applying advanced (subcategory) audit policy..."
    # Snapshot the current audit policy once for exact restoration.
    $auditBackup = Get-PTWStatePath 'audit-policy-backup.csv'
    if (-not (Test-Path -LiteralPath $auditBackup)) {
        & auditpol.exe /backup /file:"$auditBackup" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Output "[*] Saved audit-policy snapshot for a precise restore: $auditBackup"
        } else {
            Write-Output "[-] ERROR: could not save the current audit policy; refusing to apply a change without a precise rollback"
            $script:PTWErrorCount++
            return
        }
    }
    # Force subcategory audit settings to override the legacy category policy.
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'SCENoApplyLegacyAuditPolicy' -Value 1
    $auditFailures = 0
    foreach ($guid in $script:PtwAuditSubcategories) {
        & auditpol.exe /set /subcategory:"$guid" /success:enable /failure:enable 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { $auditFailures++ }
    }
    if ($auditFailures -gt 0) {
        $script:PTWErrorCount++
        Write-Output "[!] PARTIAL: advanced audit policy applied, but $auditFailures of $($script:PtwAuditSubcategories.Count) subcategories failed to set (success + failure)"
    } else {
        Write-Output "[+] SUCCESS: advanced audit policy applied ($($script:PtwAuditSubcategories.Count) subcategories, success + failure)"
    }
}

function Set-DisableCoInstaller {
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
    Write-Output "[!] WARNING: this blocks ALL .vbs / .js / .wsf script execution, which breaks legitimate logon scripts, some installers and admin tooling. Restore Default re-enables WSH."
    Set-RegDword -Path 'HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings' -Name 'Enabled' -Value 0
    Set-RegDword -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows Script Host\Settings' -Name 'Enabled' -Value 0
    Write-Output "[+] SUCCESS: Windows Script Host disabled"
}

function Set-FilterAdminToken {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Enable Admin Approval Mode for the built-in Administrator")) { return }
    Write-Output "[*] Forcing the built-in Administrator account through UAC (FilterAdministratorToken=1)..."
    Write-Output "[!] WARNING: the built-in Administrator account will now run with a filtered token and get UAC prompts like a normal admin, instead of running fully elevated silently. This is the hardening counterpart to the 'silent elevation' tweak."
    Set-RegDword -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'FilterAdministratorToken' -Value 1
    Write-Output "[+] SUCCESS: Admin Approval Mode enabled for the built-in Administrator"
}

function Set-Ntfs8Dot3Disable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable NTFS 8.3 short-name creation")) { return }
    Write-Output "[*] Disabling NTFS 8.3 short-name creation (NtfsDisable8dot3NameCreation=1)..."
    # Apply the per-volume default to new 8.3 aliases only.
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'NtfsDisable8dot3NameCreation' -Value 1
    Write-Output "[+] SUCCESS: NTFS 8.3 short-name creation disabled (applies to new files)"
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
            'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Cryptography\Wintrust\Config',
            'HKLM:\SOFTWARE\Microsoft\AMSI',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
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
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
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
        Set-DisableCoInstaller
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

    "security-filter-admin-token" {
        Backup-RegistryPath -Action $Action -Paths @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System')
        Set-FilterAdminToken
        Exit-PTW
    }

    "security-ntfs-8dot3-disable" {
        Backup-RegistryPath -Action $Action -Paths @('HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem')
        Set-Ntfs8Dot3Disable
        Exit-PTW
    }

    "menu" {
        Write-Output "[i] No interactive menu - use the PleaseTweakWindows app to select tweaks"
        Exit-PTW
    }

    default {
        Write-Error "Unknown action: $Action"
        exit 1
    }
}
