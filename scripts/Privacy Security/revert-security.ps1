# Security Revert Script
# Purpose: Reverts the changes made by security.ps1 (v2.1.0) back to Windows defaults where possible.
# Usage:
#   powershell -File revert-security.ps1 -Mode <Revert|Repair|RevertAndRepair> [-Action "<action-id>"]
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

function Enable-ServiceSafe {
    param([string[]]$Names, [ValidateSet('Automatic','Manual')][string]$StartupType = 'Manual')
    foreach ($name in $Names) {
        try {
            $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
            if ($svc) {
                Set-Service -Name $name -StartupType $StartupType -ErrorAction SilentlyContinue
                if ($svc.Status -ne 'Running') {
                    Start-Service -Name $name -ErrorAction SilentlyContinue
                }
            }
        } catch {
            Write-PTWLog "Failed to enable/start service ${name}: $($_.Exception.Message)" "WARNING"
        }
    }
}

function Enable-OptionalFeaturesSafe {
    param([string[]]$Names)
    foreach ($f in $Names) {
        try {
            $feat = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue
            if ($feat -and $feat.State -ne 'Enabled') {
                Enable-WindowsOptionalFeature -Online -FeatureName $f -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
            }
        } catch {
            Write-PTWLog "Optional feature op failed for ${f}: $($_.Exception.Message)" "WARNING"
        }
    }
}

function Add-WindowsCapabilitiesSafe {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([string[]]$Patterns)

    foreach ($capPattern in $Patterns) {
        try {
            Get-WindowsCapability -Online -Name $capPattern -ErrorAction SilentlyContinue |
                Where-Object { $_.State -eq 'NotPresent' } |
                ForEach-Object {
                    if ($PSCmdlet.ShouldProcess($_.Name, "Add Windows capability")) {
                        Add-WindowsCapability -Online -Name $_.Name -ErrorAction SilentlyContinue | Out-Null
                    }
                }
        } catch {
            Write-PTWLog "Capability op failed for pattern ${capPattern}: $($_.Exception.Message)" "WARNING"
        }
    }
}

# Admin check (kept explicit for nicer message)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-PTWLog "Administrator privileges required" "ERROR"
    exit 1
}

function Restore-FirewallBaseline {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Windows Firewall Policy", "Revert firewall baseline policy values")) { return }

    $base = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall'
    foreach ($fwProfile in @('DomainProfile','PrivateProfile','PublicProfile')) {
        $p = "$base\$fwProfile"
        $log = "$p\Logging"

        foreach ($name in @('EnableFirewall','DefaultOutboundAction','DefaultInboundAction')) {
            Remove-RegValueSafe -Path $p -Name $name
        }
        foreach ($name in @('LogDroppedPackets','LogSuccessfulConnections')) {
            Remove-RegValueSafe -Path $log -Name $name
        }
    }

    # If the policy key is now empty, remove it (best-effort).
    # (We do NOT touch non-empty keys to avoid deleting unrelated admin policy settings.)
    try {
        if (Test-Path $base) {
            $sub = Get-ChildItem -Path $base -ErrorAction SilentlyContinue
            $props = (Get-ItemProperty -Path $base -ErrorAction SilentlyContinue).PSObject.Properties |
                Where-Object { $_.Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') }
            if ((-not $sub) -and (-not $props)) {
                Remove-RegKeySafe -Path $base
            }
        }
    } catch {
        Write-Verbose "Failed to evaluate firewall policy key for cleanup."
    }
    Write-PTWLog "Reverted Firewall baseline policy overrides (where present)" "SUCCESS"
}

function Restore-TlsHardening {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("SCHANNEL/.NET", "Revert TLS hardening registry overrides")) { return }

    # Core SCHANNEL overrides set by security.ps1
    $toRemove = @(
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\Diffie-Hellman'; Names=@('ServerMinKeyBitLength','ClientMinKeyBitLength') },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\PKCS'; Names=@('ServerMinKeyBitLength','ClientMinKeyBitLength') },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL'; Names=@('AllowInsecureRenegoClients','AllowInsecureRenegoServers','DisableRenegoOnServer','DisableRenegoOnClient','UseScsvForTls') },

        # .NET strong crypto / system default TLS versions
        @{ Path='HKLM:\SOFTWARE\Microsoft\.NETFramework\v2.0.50727'; Names=@('SchUseStrongCrypto','SystemDefaultTlsVersions') },
        @{ Path='HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v2.0.50727'; Names=@('SchUseStrongCrypto','SystemDefaultTlsVersions') },
        @{ Path='HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'; Names=@('SchUseStrongCrypto','SystemDefaultTlsVersions') },
        @{ Path='HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319'; Names=@('SchUseStrongCrypto','SystemDefaultTlsVersions') }
    )

    foreach ($item in $toRemove) {
        foreach ($n in $item.Names) { Remove-RegValueSafe -Path $item.Path -Name $n }
    }

    # Protocol enable/disable overrides: remove Enabled/DisabledByDefault where present.
    $protoRoots = @(
        'SSL 2.0','SSL 3.0','TLS 1.0','TLS 1.1','TLS 1.2','TLS 1.3','DTLS 1.0','DTLS 1.2'
    )
    $protoBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
    foreach ($proto in $protoRoots) {
        foreach ($side in @('Client','Server')) {
            $p = "$protoBase\$proto\$side"
            Remove-RegValueSafe -Path $p -Name 'Enabled'
            Remove-RegValueSafe -Path $p -Name 'DisabledByDefault'
        }
    }

    # Cipher/hash overrides: remove Enabled value (security.ps1 created these keys for weak ciphers/hashes).
    $cipherBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers'
    foreach ($cipher in @('RC2 40/128','RC2 56/128','RC2 128/128','RC4 128/128','RC4 64/128','RC4 56/128','RC4 40/128','DES 56/56','Triple DES 168','Triple DES 168/168','NULL')) {
        Remove-RegValueSafe -Path "$cipherBase\$cipher" -Name 'Enabled'
    }

    $hashBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Hashes'
    foreach ($hash in @('MD5','SHA')) {
        Remove-RegValueSafe -Path "$hashBase\$hash" -Name 'Enabled'
    }

    Write-PTWLog "Reverted TLS/.NET hardening overrides (where present)" "SUCCESS"
}

function Restore-ImproveNetworkSecurity {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert network security hardening")) { return }

    $regRemovals = @(
        @{ Path='HKLM:\Software\Policies\Microsoft\Windows\LanmanServer'; Name='MinSmb2Dialect' },
        @{ Path='HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient'; Name='EnableNetbios' },
        @{ Path='HKLM:\Software\Policies\Microsoft\Windows NT\Printers'; Name='DisableHTTPPrinting' },
        @{ Path='HKLM:\Software\Policies\Microsoft\Windows NT\Printers'; Name='DisableWebPnPDownload' },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'; Name='SMB1' },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'; Name='SMBv1' },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name='LmCompatibilityLevel' },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name='restrictanonymoussam' },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters'; Name='restrictnullsessaccess' },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'; Name='AutoShareWks' },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\LSA'; Name='restrictanonymous' },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance'; Name='fAllowToGetHelp' },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance'; Name='fAllowFullControl' },
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client'; Name='AllowBasic' },
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name='AllowBasic' }
    )

    foreach ($r in $regRemovals) { Remove-RegValueSafe -Path $r.Path -Name $r.Name }

    # Revert NetBIOS over TCP/IP for all interfaces: 0 = default.
    try {
        $netbt = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces'
        if (Test-Path $netbt) {
            Get-ChildItem -Path $netbt -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Set-ItemProperty -Path $_.PSPath -Name 'NetbiosOptions' -Type DWord -Value 0 -Force -ErrorAction Stop | Out-Null
                } catch {
                    Write-PTWLog "Failed NetBIOS revert on $($_.PSChildName): $($_.Exception.Message)" "WARNING"
                }
            }
        }
    } catch {
        Write-PTWLog "NetBIOS revert failed: $($_.Exception.Message)" "WARNING"
    }

    # Restore LanmanWorkstation dependency list (includes SMB1 driver again).
    try {
        $sc = Get-Command sc.exe -ErrorAction SilentlyContinue
        if ($sc) {
            & $sc.Path config lanmanworkstation depend= bowser/mrxsmb10/mrxsmb20/nsi | Out-Null
        }
    } catch {
        Write-PTWLog "Failed to restore LanmanWorkstation dependencies: $($_.Exception.Message)" "WARNING"
    }

    Write-PTWLog "Reverted network security hardening (policies/overrides)" "SUCCESS"
}

function Repair-ImproveNetworkSecurity {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Windows Features/Capabilities", "Repair removed/disabled networking components")) { return }

    # Re-enable optional features that security.ps1 disabled
    Enable-OptionalFeaturesSafe -Names @(
        'SMB1Protocol',
        'SMB1Protocol-Client',
        'SMB1Protocol-Server',
        'TelnetClient',
        'WCF-TCP-PortSharing45',
        'SmbDirect',
        'TFTP'
    )

    # Re-add capabilities that security.ps1 may have removed
    Add-WindowsCapabilitiesSafe -Patterns @(
        'RasCMAK.Client*',
        'RIP.Listener*',
        'SNMP.Client*',
        'WMI-SNMP-Provider.Client*'
    )

    # Re-enable SMB1 driver service start type back to default (3 = Manual) if it was forced to Disabled (4).
    try {
        $mrxKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb10'
        if (Test-Path $mrxKey) {
            Set-RegValueSafe -Path $mrxKey -Name 'Start' -Type 'DWord' -Value 3
        }
    } catch {
        Write-PTWLog "Failed to repair mrxsmb10 Start: $($_.Exception.Message)" "WARNING"
    }

    Write-PTWLog "Repair attempted: optional features/capabilities restored where available" "SUCCESS"
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

function Restore-SpectreMeltdownEnable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert Spectre/Meltdown overrides")) { return }

    foreach ($x in @(
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'; Name='FeatureSettingsOverrideMask' },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'; Name='FeatureSettingsOverride' },
        @{ Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization'; Name='MinVmVersionForCpuBasedMitigations' }
    )) {
        Remove-RegValueSafe -Path $x.Path -Name $x.Name
    }

    Write-PTWLog "Reverted Spectre/Meltdown overrides (where present)" "SUCCESS"
}

function Restore-DepEnable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert DEP policy overrides")) { return }

    foreach ($x in @(
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name='NoDataExecutionPrevention' },
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='DisableHHDEP' }
    )) {
        Remove-RegValueSafe -Path $x.Path -Name $x.Name
    }

    Write-PTWLog "Reverted DEP policy overrides (where present)" "SUCCESS"
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

function Restore-SehopEnable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert SEHOP override")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' -Name 'DisableExceptionChainValidation'
    Write-PTWLog "Reverted SEHOP override (where present)" "SUCCESS"
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

function Restore-LlmnrDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert LLMNR disable")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Name 'EnableMulticast'
    Write-PTWLog "LLMNR policy override removed" "SUCCESS"
}

function Restore-SmartNameResolutionDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert smart name resolution disable")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Name 'DisableSmartNameResolution'
    Write-PTWLog "Smart name resolution override removed" "SUCCESS"
}

function Restore-SmbModernEnforce {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert SMB 3.1.1 minimum enforcement")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name 'Smb2DialectMin'
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Name 'Smb2DialectMin'
    try {
        Set-SmbServerConfiguration -EncryptData $false -Confirm:$false -ErrorAction Stop | Out-Null
        Set-SmbClientConfiguration -RequireSecuritySignature $false -Confirm:$false -ErrorAction Stop | Out-Null
    } catch {
        Write-PTWLog "SMB cmdlet revert failed: $($_.Exception.Message)" "WARNING"
    }
    Write-PTWLog "SMB modern enforcement reverted" "SUCCESS"
}

function Restore-SmbCipherSuiteOrder {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert SMB cipher suite order")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name 'EncryptionCiphers'
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Name 'EncryptionCiphers'
    Write-PTWLog "SMB cipher suite order reverted" "SUCCESS"
}

function Restore-FirewallLoggingEnable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Windows Firewall", "Revert per-profile logging")) { return }
    try {
        Set-NetFirewallProfile -Profile Domain,Private,Public `
            -LogFileName 'NotConfigured' `
            -LogMaxSizeKilobytes 4096 `
            -LogAllowed NotConfigured `
            -LogBlocked NotConfigured `
            -ErrorAction Stop
    } catch {
        Write-PTWLog "Set-NetFirewallProfile revert failed: $($_.Exception.Message)" "WARNING"
    }
    Write-PTWLog "Firewall logging reverted to defaults" "SUCCESS"
}

function Restore-DefenderControlledFolderAccess {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Disable Controlled Folder Access")) { return }
    try {
        Set-MpPreference -EnableControlledFolderAccess Disabled -ErrorAction Stop
    } catch {
        Write-PTWLog "CFA disable failed: $($_.Exception.Message)" "WARNING"
    }
    Write-PTWLog "Controlled Folder Access disabled" "SUCCESS"
}

function Restore-DefenderNetworkProtection {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Disable Network Protection")) { return }
    try {
        Set-MpPreference -EnableNetworkProtection Disabled -ErrorAction Stop
    } catch {
        Write-PTWLog "Network Protection disable failed: $($_.Exception.Message)" "WARNING"
    }
    Write-PTWLog "Network Protection disabled" "SUCCESS"
}

function Restore-DefenderPua {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Restore PUA protection to Windows default")) { return }
    # PUA protection is Enabled by default on modern Windows 11. Revert to the OEM default
    # (Enabled) rather than blindly Disabled so we do not leave the machine below its default.
    try {
        Set-MpPreference -PUAProtection Enabled -ErrorAction Stop
    } catch {
        Write-PTWLog "PUA restore-to-default failed: $($_.Exception.Message)" "WARNING"
    }
    Write-PTWLog "PUA protection restored to Windows default (Enabled)" "SUCCESS"
}

function Restore-DefenderCloudTune {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Revert cloud protection tuning")) { return }
    # Reset to Windows defaults.
    try {
        Set-MpPreference -MAPSReporting Basic -ErrorAction SilentlyContinue
        Set-MpPreference -SubmitSamplesConsent SendSafeSamples -ErrorAction SilentlyContinue
        Set-MpPreference -DisableBlockAtFirstSeen $false -ErrorAction SilentlyContinue
        Set-MpPreference -CloudBlockLevel Default -ErrorAction SilentlyContinue
        Set-MpPreference -CloudExtendedTimeout 0 -ErrorAction SilentlyContinue
    } catch {
        Write-PTWLog "Defender cloud revert failed: $($_.Exception.Message)" "WARNING"
    }
    Write-PTWLog "Defender cloud protection reset to defaults" "SUCCESS"
}

function Restore-DefenderSandbox {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Remove Defender sandbox env var")) { return }
    [System.Environment]::SetEnvironmentVariable('MP_FORCE_USE_SANDBOX', $null, 'Machine')
    Write-PTWLog "Defender sandbox env var removed (reboot required)" "SUCCESS"
}

function Restore-AslrSystemEnable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable system-wide mandatory ASLR")) { return }
    try {
        Set-ProcessMitigation -System -Disable ForceRelocateImages -ErrorAction Stop
    } catch {
        Write-PTWLog "ASLR system-wide disable failed: $($_.Exception.Message)" "WARNING"
    }
    Write-PTWLog "System-wide mandatory ASLR disabled" "SUCCESS"
}

function Restore-TlsCipherOrder {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert TLS cipher + ECC curve order")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002' -Name 'Functions'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010003' -Name 'EccCurves'
    Write-PTWLog "TLS cipher + ECC curve order reverted to defaults" "SUCCESS"
}

function Restore-BlockNtlmIncoming {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Allow incoming NTLM again")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0' -Name 'RestrictReceivingNTLMTraffic'
    Write-PTWLog "Incoming NTLM restriction removed" "SUCCESS"
}

function Restore-BlockNtlmOutgoing {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Allow outgoing NTLM again")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0' -Name 'RestrictSendingNTLMTraffic'
    Write-PTWLog "Outgoing NTLM restriction removed" "SUCCESS"
}

function Restore-AslrDevToolExclusions {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Remove dev-tool ASLR exclusions")) { return }
    $exes = @('GitHubDesktop.exe','github.exe','bash.exe','mintty.exe','msys-2.0.dll','sh.exe')
    foreach ($exe in $exes) {
        try {
            Set-ProcessMitigation -Name $exe -Remove -ErrorAction SilentlyContinue
        } catch {
            Write-PTWLog "Could not remove mitigation for ${exe}: $($_.Exception.Message)" "WARNING"
        }
    }
    Write-PTWLog "Developer tool ASLR exclusions removed" "SUCCESS"
}

$actionMap = @{
    'firewall-hardening'                    = @{ Revert = { Restore-FirewallBaseline } ; Repair = { } }
    'tls-hardening'                         = @{ Revert = { Restore-TlsHardening } ; Repair = { } }
    'security-improve-network'              = @{ Revert = { Restore-ImproveNetworkSecurity } ; Repair = { Repair-ImproveNetworkSecurity } }
    'security-clipboard-data-disable'       = @{ Revert = { Restore-ClipboardDataDisable } ; Repair = { Repair-ClipboardDataDisable } }
    'security-spectre-meltdown-enable'      = @{ Revert = { Restore-SpectreMeltdownEnable } ; Repair = { } }
    'security-dep-enable'                   = @{ Revert = { Restore-DepEnable } ; Repair = { } }
    'security-autorun-disable'              = @{ Revert = { Restore-AutorunDisable } ; Repair = { } }
    'security-lock-screen-camera-disable'   = @{ Revert = { Restore-LockScreenCameraDisable } ; Repair = { } }
    'security-lm-hash-disable'              = @{ Revert = { Restore-LmHashDisable } ; Repair = { } }
    'security-always-install-elevated-disable' = @{ Revert = { Restore-AlwaysInstallElevatedDisable } ; Repair = { } }
    'security-sehop-enable'                 = @{ Revert = { Restore-SehopEnable } ; Repair = { } }
    'security-ps2-downgrade-protection-enable' = @{ Revert = { } ; Repair = { Repair-PowerShellV2Disable } }
    'security-wcn-disable'                  = @{ Revert = { Restore-WcnDisable } ; Repair = { } }
    'security-llmnr-disable'                = @{ Revert = { Restore-LlmnrDisable } ; Repair = { } }
    'security-smart-name-resolution-disable' = @{ Revert = { Restore-SmartNameResolutionDisable } ; Repair = { } }
    'security-smb-modern-enforce'           = @{ Revert = { Restore-SmbModernEnforce } ; Repair = { } }
    'security-smb-cipher-suite-order'       = @{ Revert = { Restore-SmbCipherSuiteOrder } ; Repair = { } }
    'security-firewall-logging-enable'      = @{ Revert = { Restore-FirewallLoggingEnable } ; Repair = { } }
    'security-defender-cfa-enable'          = @{ Revert = { Restore-DefenderControlledFolderAccess } ; Repair = { } }
    'security-defender-network-protection-enable' = @{ Revert = { Restore-DefenderNetworkProtection } ; Repair = { } }
    'security-defender-pua-enable'          = @{ Revert = { Restore-DefenderPua } ; Repair = { } }
    'security-defender-cloud-tune'          = @{ Revert = { Restore-DefenderCloudTune } ; Repair = { } }
    'security-defender-sandbox-enable'      = @{ Revert = { Restore-DefenderSandbox } ; Repair = { } }
    'security-aslr-system-enable'           = @{ Revert = { Restore-AslrSystemEnable } ; Repair = { } }
    'security-tls-cipher-order'             = @{ Revert = { Restore-TlsCipherOrder } ; Repair = { } }
    'security-block-ntlm-incoming'          = @{ Revert = { Restore-BlockNtlmIncoming } ; Repair = { } }
    'security-block-ntlm-outgoing'          = @{ Revert = { Restore-BlockNtlmOutgoing } ; Repair = { } }
    'security-aslr-exclude-dev-tools'       = @{ Revert = { Restore-AslrDevToolExclusions } ; Repair = { } }

    # Alias keys: the GUI (TweakRegistry.cs) sends revert IDs for these 10 toggles WITHOUT
    # the apply verb (e.g. 'security-clipboard-data-revert'), which strip to the base ID below.
    # Map each base ID to the SAME scriptblocks as its '-disable'/'-enable' counterpart so the
    # revert resolves instead of hitting the unknown-action branch.
    'security-clipboard-data'               = @{ Revert = { Restore-ClipboardDataDisable } ; Repair = { Repair-ClipboardDataDisable } }
    'security-spectre-meltdown'             = @{ Revert = { Restore-SpectreMeltdownEnable } ; Repair = { } }
    'security-dep'                          = @{ Revert = { Restore-DepEnable } ; Repair = { } }
    'security-autorun'                      = @{ Revert = { Restore-AutorunDisable } ; Repair = { } }
    'security-lock-screen-camera'           = @{ Revert = { Restore-LockScreenCameraDisable } ; Repair = { } }
    'security-lm-hash'                      = @{ Revert = { Restore-LmHashDisable } ; Repair = { } }
    'security-always-install-elevated'      = @{ Revert = { Restore-AlwaysInstallElevatedDisable } ; Repair = { } }
    'security-sehop'                        = @{ Revert = { Restore-SehopEnable } ; Repair = { } }
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
    Invoke-Mode -RevertBlock { Restore-FirewallBaseline } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-TlsHardening } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-ImproveNetworkSecurity } -RepairBlock { Repair-ImproveNetworkSecurity }
    Invoke-Mode -RevertBlock { Restore-ClipboardDataDisable } -RepairBlock { Repair-ClipboardDataDisable }
    Invoke-Mode -RevertBlock { Restore-SpectreMeltdownEnable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-DepEnable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-AutorunDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-LockScreenCameraDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-LmHashDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-AlwaysInstallElevatedDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-SehopEnable } -RepairBlock { }
    Invoke-Mode -RevertBlock { } -RepairBlock { Repair-PowerShellV2Disable }
    Invoke-Mode -RevertBlock { Restore-WcnDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-LlmnrDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-SmartNameResolutionDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-SmbModernEnforce } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-SmbCipherSuiteOrder } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-FirewallLoggingEnable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-DefenderControlledFolderAccess } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-DefenderNetworkProtection } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-DefenderPua } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-DefenderCloudTune } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-DefenderSandbox } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-AslrSystemEnable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-TlsCipherOrder } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-BlockNtlmIncoming } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-BlockNtlmOutgoing } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-AslrDevToolExclusions } -RepairBlock { }

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
