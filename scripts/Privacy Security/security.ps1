# Security Tweaks
# Purpose: Non-interactive action dispatcher.
# Usage: powershell -File security.ps1 -Action "<action-id>"
# Version: 2.1.0
# Last Updated: 2026-01-21
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "firewall-hardening",
        "tls-hardening",
        "security-improve-network",
        "security-clipboard-data-disable",
        "security-spectre-meltdown-enable",
        "security-dep-enable",
        "security-autorun-disable",
        "security-lock-screen-camera-disable",
        "security-lm-hash-disable",
        "security-always-install-elevated-disable",
        "security-sehop-enable",
        "security-ps2-downgrade-protection-enable",
        "security-wcn-disable",
        "security-llmnr-disable",
        "security-smart-name-resolution-disable",
        "security-smb-modern-enforce",
        "security-smb-cipher-suite-order",
        "security-firewall-logging-enable",
        "security-defender-cfa-enable",
        "security-defender-network-protection-enable",
        "security-defender-pua-enable",
        "security-defender-cloud-tune",
        "security-defender-sandbox-enable",
        "security-aslr-system-enable",
        "security-tls-cipher-order",
        "security-block-ntlm-incoming",
        "security-block-ntlm-outgoing",
        "security-aslr-exclude-dev-tools",
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

function Get-OsBuildNumber {
    try {
        return [Environment]::OSVersion.Version.Build
    } catch {
        return 0
    }
}

function Test-DefenderTamperProtected {
    # Returns $true if Microsoft Defender Tamper Protection is ON. When it is on,
    # Set-MpPreference changes to protection state are silently ignored/reverted by
    # the Defender service, so the GUI must NOT report success.
    try {
        return [bool](Get-MpComputerStatus -ErrorAction Stop).IsTamperProtected
    } catch {
        return $false
    }
}

function Disable-ClipboardService {
    foreach ($svcName in @('cbdhsvc')) {
        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc) {
                if ($svc.Status -ne 'Stopped') {
                    Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                }
                Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Warning "[WARN] Service disable failed for ${svcName}: $($_.Exception.Message)"
        }
    }

    try {
        Get-Service -Name 'cbdhsvc_*' -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                if ($_.Status -ne 'Stopped') {
                    Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue
                }
                Set-Service -Name $_.Name -StartupType Disabled -ErrorAction SilentlyContinue
            } catch { Write-Verbose "Failed to disable service $($_.Name): $($_.Exception.Message)" }
        }
    } catch { Write-Verbose "Failed to enumerate cbdhsvc_* services: $($_.Exception.Message)" }
}

function Disable-OptionalFeaturesSafe {
    param([string[]]$Names)
    foreach ($f in $Names) {
        try {
            $feat = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue
            if ($feat -and $feat.State -ne 'Disabled') {
                Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -ErrorAction SilentlyContinue | Out-Null
            }
        } catch {
            Write-Warning "[WARN] Optional feature op failed for ${f}: $($_.Exception.Message)"
        }
    }
}

function Remove-WindowsCapabilitiesSafe {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([string[]]$Patterns)
    foreach ($capPattern in $Patterns) {
        try {
            Get-WindowsCapability -Online -Name $capPattern -ErrorAction SilentlyContinue |
                Where-Object { $_.State -ne 'NotPresent' } |
                ForEach-Object {
                    if ($PSCmdlet.ShouldProcess($_.Name, "Remove Windows capability")) {
                        Remove-WindowsCapability -Online -Name $_.Name -ErrorAction SilentlyContinue | Out-Null
                    }
                }
        } catch {
            Write-Warning "[WARN] Capability remove failed for ${capPattern}: $($_.Exception.Message)"
        }
    }
}

# Firewall hardening
function Set-FirewallBaseline {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Windows Firewall", "Apply firewall baseline")) { return }
    $basePath = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall'
    New-Item -Path $basePath -Force | Out-Null
    foreach ($fwProfile in @('DomainProfile','PrivateProfile','PublicProfile')) {
        New-Item -Path "$basePath\$fwProfile" -Force | Out-Null
        New-Item -Path "$basePath\$fwProfile\Logging" -Force | Out-Null
        Set-ItemProperty -Path "$basePath\$fwProfile" -Name 'EnableFirewall' -Type DWord -Value 1
        Set-ItemProperty -Path "$basePath\$fwProfile" -Name 'DefaultOutboundAction' -Type DWord -Value 0
        Set-ItemProperty -Path "$basePath\$fwProfile" -Name 'DefaultInboundAction' -Type DWord -Value 1
        Set-ItemProperty -Path "$basePath\$fwProfile\Logging" -Name 'LogDroppedPackets' -Type DWord -Value 1
        Set-ItemProperty -Path "$basePath\$fwProfile\Logging" -Name 'LogSuccessfulConnections' -Type DWord -Value 1
    }
}

function Set-ImproveNetworkSecurity {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Apply network security hardening")) { return }
    Write-Output "[*] Improving network security..."

    $regSets = @(
        # Enforce SMBv2 minimum dialect (disables SMB1).
        [pscustomobject]@{ Path = 'HKLM:\Software\Policies\Microsoft\Windows\LanmanServer'; Name = 'MinSmb2Dialect'; Type = 'DWord'; Value = 528 },
        # Disable NetBIOS over TCP/IP via policy.
        [pscustomobject]@{ Path = 'HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient'; Name = 'EnableNetbios'; Type = 'DWord'; Value = 0 },
        # Disable HTTP printing.
        [pscustomobject]@{ Path = 'HKLM:\Software\Policies\Microsoft\Windows NT\Printers'; Name = 'DisableHTTPPrinting'; Type = 'DWord'; Value = 1 },
        # Disable WebPnP printer downloads.
        [pscustomobject]@{ Path = 'HKLM:\Software\Policies\Microsoft\Windows NT\Printers'; Name = 'DisableWebPnPDownload'; Type = 'DWord'; Value = 1 },
        # Disable SMBv1 protocol. The correct server-side value is "SMB1" (not "SMBv1",
        # which was a no-op). The real SMB1 removal still happens via the optional-feature
        # uninstall below — this reg key just disables the server-side SMB1 negotiator.
        [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'; Name = 'SMB1'; Type = 'DWord'; Value = 0 },
        # Enforce NTLMv2 only (LM/NTLMv1 disabled).
        [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'LmCompatibilityLevel'; Type = 'DWord'; Value = 5 },
        # Disable anonymous SAM enumeration.
        [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'restrictanonymoussam'; Type = 'DWord'; Value = 1 },
        # Disable anonymous access to named pipes/shares.
        [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters'; Name = 'restrictnullsessaccess'; Type = 'DWord'; Value = 1 },
        # Disable administrative shares (breaks some remote management).
        [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'; Name = 'AutoShareWks'; Type = 'DWord'; Value = 0 },
        # Disable anonymous enumeration of shares.
        [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\LSA'; Name = 'restrictanonymous'; Type = 'DWord'; Value = 1 },
        # Disable Remote Assistance (Get Help).
        [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance'; Name = 'fAllowToGetHelp'; Type = 'DWord'; Value = 0 },
        # Disable Remote Assistance full control.
        [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance'; Name = 'fAllowFullControl'; Type = 'DWord'; Value = 0 },
        # Disable basic authentication in WinRM.
        [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client'; Name = 'AllowBasic'; Type = 'DWord'; Value = 0 },
        # Disable basic authentication in RDP (Terminal Services).
        [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name = 'AllowBasic'; Type = 'DWord'; Value = 0 }
    )

    foreach ($r in $regSets) {
        Set-RegValueSafe -Path $r.Path -Name $r.Name -Type $r.Type -Value $r.Value
    }

    # Disable NetBIOS over TCP/IP for all interfaces.
    try {
        $netbt = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces'
        if (Test-Path $netbt) {
            Get-ChildItem -Path $netbt -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Set-ItemProperty -Path $_.PSPath -Name 'NetbiosOptions' -Type DWord -Value 2 -Force -ErrorAction Stop | Out-Null
                } catch {
                    Write-Warning "[WARN] Failed NetBIOS disable on $($_.PSChildName): $($_.Exception.Message)"
                }
            }
        }
    } catch {
        Write-Warning "[WARN] NetBIOS disable failed: $($_.Exception.Message)"
    }

    # Disable legacy / insecure Windows optional features.
    Disable-OptionalFeaturesSafe -Names @(
        'SMB1Protocol',
        'SMB1Protocol-Client',
        'SMB1Protocol-Server',
        'TelnetClient',
        'WCF-TCP-PortSharing45',
        'SmbDirect',
        'TFTP'
    )

    # Disable SMB1 driver service (mrxsmb10).
    try {
        $mrxKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb10'
        if (Test-Path $mrxKey) {
            Set-RegDword -Path $mrxKey -Name 'Start' -Value 4
        }
    } catch {
        Write-Warning "[WARN] Failed to disable mrxsmb10: $($_.Exception.Message)"
    }

    # Remove SMB1 dependency from LanmanWorkstation.
    try {
        $sc = Get-Command sc.exe -ErrorAction SilentlyContinue
        if ($sc) {
            & $sc.Path config lanmanworkstation depend= bowser/mrxsmb20/nsi | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "[WARN] LanmanWorkstation dependency update failed (code: $LASTEXITCODE)"
            }
        }
    } catch {
        Write-Warning "[WARN] Failed to update LanmanWorkstation dependencies: $($_.Exception.Message)"
    }

    # Remove non-essential networking capabilities.
    Remove-WindowsCapabilitiesSafe -Patterns @(
        'RasCMAK.Client*',
        'RIP.Listener*',
        'SNMP.Client*',
        'WMI-SNMP-Provider.Client*'
    )

    Write-Output "[+] SUCCESS: network security improved (restart recommended)"
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

function Set-SpectreMeltdownProtection {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Enable Spectre/Meltdown protection")) { return }
    Write-Output "[*] Enabling Spectre/Meltdown protection..."

    # Mitigate Spectre/Meltdown in host OS.
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'FeatureSettingsOverrideMask' -Type 'DWord' -Value 3
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'FeatureSettingsOverride' -Type 'DWord' -Value 64
    # Mitigate Spectre/Meltdown in Hyper-V.
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization' -Name 'MinVmVersionForCpuBasedMitigations' -Type 'String' -Value '1.0'

    Write-Output "[!] WARNING: This only forces the default mitigations on; it is largely redundant on modern (microcode-patched) CPUs which already enable them, and some override bits are ignored on AMD - so this may be a partial no-op. It can also add a small CPU latency/performance cost, which matters for gaming."
    Write-Output "[+] SUCCESS: Spectre/Meltdown default mitigations enabled (only matters on unpatched/older CPUs)"
}

function Set-DepProtection {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Enable DEP protection")) { return }
    Write-Output "[*] Enabling Data Execution Prevention (DEP)..."

    # Enable DEP for Explorer policies.
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'NoDataExecutionPrevention' -Type 'DWord' -Value 0
    # Enable DEP for HTML Help (HHDEP).
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'DisableHHDEP' -Type 'DWord' -Value 0

    Write-Output "[+] SUCCESS: DEP enabled"
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

function Set-SehopEnabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Enable SEHOP")) { return }
    Write-Output "[*] Enabling SEHOP..."

    # Enable Structured Exception Handling Overwrite Protection (SEHOP).
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' -Name 'DisableExceptionChainValidation' -Type 'DWord' -Value 0

    Write-Output "[+] SUCCESS: SEHOP enabled"
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

function Set-TlsHardening {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Apply TLS hardening")) { return }

    Start-PTWTransaction
    try {
        $regSets = @(
            # Require strong Diffie-Hellman keys (2048-bit).
            [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\Diffie-Hellman'; Name = 'ServerMinKeyBitLength'; Type = 'DWord'; Value = 2048 },
            # Require strong Diffie-Hellman keys (client).
            [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\Diffie-Hellman'; Name = 'ClientMinKeyBitLength'; Type = 'DWord'; Value = 2048 },
            # Require strong RSA keys (PKCS, breaks Hyper-V VMs).
            [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\PKCS'; Name = 'ServerMinKeyBitLength'; Type = 'DWord'; Value = 2048 },
            # Require strong RSA keys (client).
            [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\PKCS'; Name = 'ClientMinKeyBitLength'; Type = 'DWord'; Value = 2048 },
            # Disable insecure renegotiation (clients).
            [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL'; Name = 'AllowInsecureRenegoClients'; Type = 'DWord'; Value = 0 },
            # Disable insecure renegotiation (servers).
            [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL'; Name = 'AllowInsecureRenegoServers'; Type = 'DWord'; Value = 0 },
            # Disable renegotiation on server.
            [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL'; Name = 'DisableRenegoOnServer'; Type = 'DWord'; Value = 1 },
            # Disable renegotiation on client.
            [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL'; Name = 'DisableRenegoOnClient'; Type = 'DWord'; Value = 1 },
            # Enable TLS SCSV protection.
            [pscustomobject]@{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL'; Name = 'UseScsvForTls'; Type = 'DWord'; Value = 1 },
            # Disable insecure connections from .NET apps (v2).
            [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v2.0.50727'; Name = 'SchUseStrongCrypto'; Type = 'DWord'; Value = 1 },
            # Disable insecure connections from .NET apps (v2, 32-bit).
            [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v2.0.50727'; Name = 'SchUseStrongCrypto'; Type = 'DWord'; Value = 1 },
            # Disable insecure connections from .NET apps (v4).
            [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'; Name = 'SchUseStrongCrypto'; Type = 'DWord'; Value = 1 },
            # Disable insecure connections from .NET apps (v4, 32-bit).
            [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319'; Name = 'SchUseStrongCrypto'; Type = 'DWord'; Value = 1 },
            # Enable secure defaults for legacy .NET apps (v2).
            [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v2.0.50727'; Name = 'SystemDefaultTlsVersions'; Type = 'DWord'; Value = 1 },
            # Enable secure defaults for legacy .NET apps (v2, 32-bit).
            [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v2.0.50727'; Name = 'SystemDefaultTlsVersions'; Type = 'DWord'; Value = 1 },
            # Enable secure defaults for legacy .NET apps (v4).
            [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'; Name = 'SystemDefaultTlsVersions'; Type = 'DWord'; Value = 1 },
            # Enable secure defaults for legacy .NET apps (v4, 32-bit).
            [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319'; Name = 'SystemDefaultTlsVersions'; Type = 'DWord'; Value = 1 }
        )

        foreach ($r in $regSets) {
            Set-RegValueSafeTx -Path $r.Path -Name $r.Name -Type $r.Type -Value $r.Value
        }

        # Disable insecure ciphers.
        $ciphers = @(
            'RC2 40/128',
            'RC2 56/128',
            'RC2 128/128',
            'RC4 128/128',
            'RC4 64/128',
            'RC4 56/128',
            'RC4 40/128',
            'DES 56/56',
            'Triple DES 168',
            'Triple DES 168/168',
            'NULL'
        )
        foreach ($cipher in $ciphers) {
            Set-RegValueSafeTx -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\$cipher" -Name 'Enabled' -Type 'DWord' -Value 0
        }

        # Disable insecure hashes. Note: 'SHA' (SHA-1) is intentionally NOT disabled here
        # because killing the Schannel SHA-1 provider can break TLS 1.2 CBC-SHA handshakes
        # to legacy servers/appliances; only MD5 is disabled.
        $hashes = @('MD5')
        foreach ($hash in $hashes) {
            Set-RegValueSafeTx -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Hashes\$hash" -Name 'Enabled' -Type 'DWord' -Value 0
        }

        $protocols = @(
            # Disable SSL 2.0 (server).
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server'; Enabled = 0; DisabledByDefault = 1 },
            # Disable SSL 2.0 (client).
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client'; Enabled = 0; DisabledByDefault = 1 },
            # Disable SSL 3.0 (server).
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server'; Enabled = 0; DisabledByDefault = 1 },
            # Disable SSL 3.0 (client).
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client'; Enabled = 0; DisabledByDefault = 1 },
            # Disable TLS 1.0 (server).
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server'; Enabled = 0; DisabledByDefault = 1 },
            # Disable TLS 1.0 (client).
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client'; Enabled = 0; DisabledByDefault = 1 },
            # Disable TLS 1.1 (server).
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server'; Enabled = 0; DisabledByDefault = 1 },
            # Disable TLS 1.1 (client).
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client'; Enabled = 0; DisabledByDefault = 1 },
            # Disable DTLS 1.0 (server).
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\DTLS 1.0\Server'; Enabled = 0; DisabledByDefault = 1 },
            # Disable DTLS 1.0 (client).
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\DTLS 1.0\Client'; Enabled = 0; DisabledByDefault = 1 },
            # Explicitly enable TLS 1.2 (server).
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'; Enabled = 1; DisabledByDefault = 0 },
            # Explicitly enable TLS 1.2 (client).
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'; Enabled = 1; DisabledByDefault = 0 }
        )

        $build = Get-OsBuildNumber
        if ($build -ge 14393) {
            # Enable DTLS 1.2 (server).
            $protocols += @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\DTLS 1.2\Server'; Enabled = 1; DisabledByDefault = 0 }
            # Enable DTLS 1.2 (client).
            $protocols += @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\DTLS 1.2\Client'; Enabled = 1; DisabledByDefault = 0 }
        } else {
            Write-Output "[i] Skipping DTLS 1.2 enable (build $build < 14393)"
        }

        if ($build -ge 20348) {
            # Enable TLS 1.3 (server).
            $protocols += @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server'; Enabled = 1; DisabledByDefault = 0 }
            # Enable TLS 1.3 (client).
            $protocols += @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client'; Enabled = 1; DisabledByDefault = 0 }
        } else {
            Write-Output "[i] Skipping TLS 1.3 enable (build $build < 20348)"
        }

        foreach ($proto in $protocols) {
            Set-RegValueSafeTx -Path $proto.Path -Name 'Enabled' -Type 'DWord' -Value $proto.Enabled
            Set-RegValueSafeTx -Path $proto.Path -Name 'DisabledByDefault' -Type 'DWord' -Value $proto.DisabledByDefault
        }
    } catch {
        Write-Output "[-] ERROR during TLS hardening: $($_.Exception.Message)"
        Undo-PTWTransaction
        throw
    } finally {
        Stop-PTWTransaction
    }
}

function Set-LlmnrDisabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable LLMNR multicast name resolution")) { return }
    Write-Output "[*] Disabling LLMNR multicast name resolution..."
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Name 'EnableMulticast' -Type 'DWord' -Value 0
    Write-Output "[+] SUCCESS: LLMNR disabled (closes Responder-style attack vector)"
}

function Set-SmartNameResolutionDisabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable smart multihomed name resolution")) { return }
    Write-Output "[*] Disabling smart multihomed name resolution..."
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Name 'DisableSmartNameResolution' -Type 'DWord' -Value 1
    Write-Output "[+] SUCCESS: Smart name resolution disabled (prevents DNS leaks on multi-interface systems)"
}

function Set-SmbModernEnforced {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Enforce SMB 3.1.1 minimum + encryption")) { return }
    Write-Output "[*] Enforcing SMB 3.1.1 minimum + encryption..."
    Write-Output "[!] WARNING: Setting the SMB CLIENT minimum dialect to 3.1.1 will block this PC from connecting to any share that only speaks SMB 2.x/3.0 - this includes many NAS units (older Synology/QNAP firmware), network printers/scanners, Samba < 4.11, and Windows 7/8/Server 2012 shares. You may lose access to those devices until you revert."
    Write-Output "[!] WARNING: Requiring SMB server-side encryption (EncryptData) will block non-SMB3 clients (Windows 7, scan-to-folder printers, older media players/TVs) from reaching shares hosted on THIS machine."
    # Dialect values: 0x0202=2.0.2, 0x0210=2.1, 0x0300=3.0, 0x0302=3.0.2, 0x0311=3.1.1
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name 'Smb2DialectMin' -Type 'DWord' -Value 0x0311
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Name 'Smb2DialectMin' -Type 'DWord' -Value 0x0311
    try {
        Set-SmbServerConfiguration -EncryptData $true -RejectUnencryptedAccess $false -Confirm:$false -ErrorAction Stop | Out-Null
        Set-SmbClientConfiguration -RequireSecuritySignature $true -EnableSecuritySignature $true -Confirm:$false -ErrorAction Stop | Out-Null
    } catch {
        Write-Warning "[WARN] SMB cmdlet config failed: $($_.Exception.Message)"
    }
    Write-Output "[+] SUCCESS: SMB 3.1.1 minimum enforced, server encryption required"
}

function Set-SmbCipherSuiteOrder {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Set secure SMB cipher suite order")) { return }
    Write-Output "[*] Configuring SMB cipher suite order (AES-256-GCM first)..."
    $order = @('AES_256_GCM','AES_128_GCM','AES_256_CCM','AES_128_CCM')
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name 'EncryptionCiphers' -Type 'MultiString' -Value $order
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Name 'EncryptionCiphers' -Type 'MultiString' -Value $order
    Write-Output "[+] SUCCESS: SMB cipher suite order configured"
}

function Set-FirewallLoggingEnabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Windows Firewall", "Enable per-profile logging")) { return }
    Write-Output "[*] Enabling per-profile firewall logging..."
    try {
        Set-NetFirewallProfile -Profile Domain,Private,Public `
            -LogFileName '%systemroot%\system32\LogFiles\Firewall\pfirewall.log' `
            -LogMaxSizeKilobytes 32767 `
            -LogAllowed True `
            -LogBlocked True `
            -ErrorAction Stop
        Write-Output "[+] SUCCESS: Firewall logging enabled (Domain, Private, Public)"
    } catch {
        Write-Warning "[WARN] Set-NetFirewallProfile failed: $($_.Exception.Message). Falling back to netsh."
        foreach ($p in @('domain','private','public')) {
            netsh advfirewall set "$p" logging filename '%systemroot%\system32\LogFiles\Firewall\pfirewall.log' 2>&1 | Out-Null
            netsh advfirewall set "$p" logging maxfilesize 32767 2>&1 | Out-Null
            netsh advfirewall set "$p" logging droppedconnections enable 2>&1 | Out-Null
            netsh advfirewall set "$p" logging allowedconnections enable 2>&1 | Out-Null
        }
        Write-Output "[+] SUCCESS: Firewall logging enabled via netsh"
    }
}

function Set-DefenderControlledFolderAccessEnabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Enable Controlled Folder Access")) { return }
    Write-Output "[*] Enabling Controlled Folder Access (ransomware protection)..."
    if (Test-DefenderTamperProtected) {
        Write-Warning "[WARN] Tamper Protection is ON; this change will not persist - disable Tamper Protection in Windows Security > Virus & threat protection first"
        exit 1
    }
    try {
        Set-MpPreference -EnableControlledFolderAccess Enabled -ErrorAction Stop
        Write-Output "[+] SUCCESS: Controlled Folder Access enabled"
    } catch {
        Write-Warning "[WARN] Set-MpPreference failed: $($_.Exception.Message)"
        exit 1
    }
}

function Set-DefenderNetworkProtectionEnabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Enable Network Protection")) { return }
    Write-Output "[*] Enabling Defender Network Protection..."
    if (Test-DefenderTamperProtected) {
        Write-Warning "[WARN] Tamper Protection is ON; this change will not persist - disable Tamper Protection in Windows Security > Virus & threat protection first"
        exit 1
    }
    try {
        Set-MpPreference -EnableNetworkProtection Enabled -ErrorAction Stop
        Write-Output "[+] SUCCESS: Network Protection enabled"
    } catch {
        Write-Warning "[WARN] Set-MpPreference failed: $($_.Exception.Message)"
        exit 1
    }
}

function Set-DefenderPuaEnabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Enable PUA Protection")) { return }
    Write-Output "[*] Enabling Potentially Unwanted App (PUA) protection..."
    if (Test-DefenderTamperProtected) {
        Write-Warning "[WARN] Tamper Protection is ON; this change will not persist - disable Tamper Protection in Windows Security > Virus & threat protection first"
        exit 1
    }
    try {
        Set-MpPreference -PUAProtection Enabled -ErrorAction Stop
        Write-Output "[+] SUCCESS: PUA protection enabled"
    } catch {
        Write-Warning "[WARN] Set-MpPreference failed: $($_.Exception.Message)"
        exit 1
    }
}

function Set-DefenderCloudTuned {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Tune Defender cloud protection")) { return }
    Write-Output "[*] Tuning Defender cloud protection..."
    if (Test-DefenderTamperProtected) {
        Write-Warning "[WARN] Tamper Protection is ON; this change will not persist - disable Tamper Protection in Windows Security > Virus & threat protection first"
        exit 1
    }
    try {
        Set-MpPreference -MAPSReporting Advanced -ErrorAction Stop
        Set-MpPreference -SubmitSamplesConsent SendSafeSamples -ErrorAction Stop
        Set-MpPreference -DisableBlockAtFirstSeen $false -ErrorAction Stop
        Set-MpPreference -CloudBlockLevel High -ErrorAction Stop
        Set-MpPreference -CloudExtendedTimeout 50 -ErrorAction Stop
        # Read back one value to confirm the change actually stuck before reporting success.
        if ((Get-MpPreference -ErrorAction Stop).CloudBlockLevel -ne 'High') {
            Write-Warning "[WARN] Defender cloud tuning did not persist (CloudBlockLevel not High)"
            exit 1
        }
        Write-Output "[+] SUCCESS: Defender cloud protection tuned (MAPS Advanced, BAFS on, Cloud Block High)"
    } catch {
        Write-Warning "[WARN] Set-MpPreference failed: $($_.Exception.Message)"
        exit 1
    }
}

function Set-DefenderSandboxEnabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Enable sandbox mode")) { return }
    Write-Output "[*] Enabling Defender sandbox mode..."
    & setx.exe /M MP_FORCE_USE_SANDBOX 1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "[WARN] setx returned $LASTEXITCODE"
    }
    Write-Output "[+] SUCCESS: Defender sandbox flag set (requires REBOOT to take effect)"
}

function Set-AslrSystemWideEnabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Enable system-wide mandatory ASLR")) { return }
    Write-Output "[*] Enabling system-wide mandatory ASLR (ForceRelocateImages)..."
    Write-Output "[!] WARNING: System-wide mandatory ASLR can crash or prevent launch of games' anti-cheat drivers, older 32-bit apps, and binaries built without /DYNAMICBASE. After enabling this, TEST your game launches; if something breaks, run the 'Exclude dev tools' tweak or revert this. This is especially relevant on a gaming PC."
    try {
        Set-ProcessMitigation -System -Enable ForceRelocateImages -ErrorAction Stop
        Write-Output "[+] SUCCESS: System-wide mandatory ASLR enabled (complement to DEP)"
    } catch {
        Write-Warning "[WARN] Set-ProcessMitigation failed: $($_.Exception.Message)"
        exit 1
    }
}

function Set-TlsCipherOrder {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Set TLS cipher suite + ECC curve order")) { return }
    Write-Output "[*] Setting TLS cipher suite + ECC curve order..."
    # Preferred TLS cipher suites (Windows policy CSP: TLSCipherSuites).
    $suites = @(
        'TLS_AES_256_GCM_SHA384',
        'TLS_AES_128_GCM_SHA256',
        'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384',
        'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256',
        'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384',
        'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256',
        'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384',
        'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256',
        'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384',
        'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256'
    )
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002' -Name 'Functions' -Type 'String' -Value ($suites -join ',')
    # ECC curve priority (NIST P-256 first, then P-384; curve25519 last for compat).
    $curves = @('curve25519','NistP256','NistP384')
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010003' -Name 'EccCurves' -Type 'MultiString' -Value $curves
    Write-Output "[+] SUCCESS: TLS cipher + ECC curve order configured"
}

function Set-BlockNtlmIncoming {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Block incoming NTLM authentication")) { return }
    Write-Output "[*] Blocking INCOMING NTLM authentication (2 = Deny all)..."
    Write-Output "[!] WARNING: Deny-all NTLM is intended for domain (Kerberos) environments. On a workgroup/home PC this can break SMB file-share auth, mapped network drives, RDP, and many network printers that authenticate via NTLM. Only enable this on a domain-joined machine."
    # RestrictReceivingNTLMTraffic: 0=Allow, 1=Audit, 2=Deny all
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0' -Name 'RestrictReceivingNTLMTraffic' -Type 'DWord' -Value 2
    Write-Output "[+] SUCCESS: Incoming NTLM blocked (may break SMB file shares, RDP, Hyper-V)"
}

function Set-BlockNtlmOutgoing {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Block outgoing NTLM authentication")) { return }
    Write-Output "[*] Blocking OUTGOING NTLM authentication (2 = Deny all)..."
    Write-Output "[!] WARNING: Deny-all NTLM is intended for domain (Kerberos) environments. On a workgroup/home PC this can break SMB file-share auth, mapped network drives, RDP, and many network printers that authenticate via NTLM. Only enable this on a domain-joined machine."
    # RestrictSendingNTLMTraffic: 0=Allow, 1=Audit, 2=Deny all
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0' -Name 'RestrictSendingNTLMTraffic' -Type 'DWord' -Value 2
    Write-Output "[+] SUCCESS: Outgoing NTLM blocked (may break legacy authentication to servers)"
}

function Set-AslrDevToolExclusions {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Exclude dev tools from mandatory ASLR")) { return }
    Write-Output "[*] Excluding GitHub Desktop, Git, and MSYS2 from mandatory ASLR..."
    # Known developer executables incompatible with ForceRelocateImages
    $exes = @(
        'GitHubDesktop.exe',
        'github.exe',
        'bash.exe',
        'mintty.exe',
        'msys-2.0.dll',
        'sh.exe'
    )
    foreach ($exe in $exes) {
        try {
            Set-ProcessMitigation -Name $exe -Disable ForceRelocateImages -ErrorAction Stop
            Write-Output "  [+] Excluded $exe"
        } catch {
            Write-Warning "  [WARN] Could not exclude ${exe}: $($_.Exception.Message)"
        }
    }
    Write-Output "[+] SUCCESS: Developer tool ASLR exclusions applied"
}

switch ($Action.ToLowerInvariant()) {
    "firewall-hardening" {
        Write-Output "[*] Applying Firewall Baseline..."
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall'
        )
        Set-FirewallBaseline
        Write-Output "[+] SUCCESS: Firewall baseline applied"
        Exit-PTW
    }

    "tls-hardening" {
        Write-Output "[*] Applying TLS Hardening..."
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL'
        )
        Set-TlsHardening
        Write-Output "[+] SUCCESS: TLS hardening applied"
        Exit-PTW
    }

    "security-improve-network" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters',
            'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters',
            'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient',
            'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces'
        )
        Set-ImproveNetworkSecurity
        Exit-PTW
    }

    "security-clipboard-data-disable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System',
            'HKCU:\Software\Microsoft\Clipboard'
        )
        Set-ClipboardDataCollectionDisabled
        Exit-PTW
    }

    "security-spectre-meltdown-enable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management',
            'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization'
        )
        Set-SpectreMeltdownProtection
        Exit-PTW
    }

    "security-dep-enable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        )
        Set-DepProtection
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

    "security-sehop-enable" {
        Set-SehopEnabled
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

    "security-llmnr-disable" {
        Backup-RegistryPath -Action $Action -Paths @('HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient')
        Set-LlmnrDisabled
        Exit-PTW
    }

    "security-smart-name-resolution-disable" {
        Backup-RegistryPath -Action $Action -Paths @('HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient')
        Set-SmartNameResolutionDisabled
        Exit-PTW
    }

    "security-smb-modern-enforce" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters',
            'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'
        )
        Set-SmbModernEnforced
        Exit-PTW
    }

    "security-smb-cipher-suite-order" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters',
            'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'
        )
        Set-SmbCipherSuiteOrder
        Exit-PTW
    }

    "security-firewall-logging-enable" {
        # Firewall logging applied via cmdlet, not registry — no backup needed.
        Set-FirewallLoggingEnabled
        Exit-PTW
    }

    "security-defender-cfa-enable" {
        Set-DefenderControlledFolderAccessEnabled
        Exit-PTW
    }

    "security-defender-network-protection-enable" {
        Set-DefenderNetworkProtectionEnabled
        Exit-PTW
    }

    "security-defender-pua-enable" {
        Set-DefenderPuaEnabled
        Exit-PTW
    }

    "security-defender-cloud-tune" {
        Set-DefenderCloudTuned
        Exit-PTW
    }

    "security-defender-sandbox-enable" {
        Set-DefenderSandboxEnabled
        Exit-PTW
    }

    "security-aslr-system-enable" {
        Set-AslrSystemWideEnabled
        Exit-PTW
    }

    "security-tls-cipher-order" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL'
        )
        Set-TlsCipherOrder
        Exit-PTW
    }

    "security-block-ntlm-incoming" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0'
        )
        Set-BlockNtlmIncoming
        Exit-PTW
    }

    "security-block-ntlm-outgoing" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0'
        )
        Set-BlockNtlmOutgoing
        Exit-PTW
    }

    "security-aslr-exclude-dev-tools" {
        Set-AslrDevToolExclusions
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
