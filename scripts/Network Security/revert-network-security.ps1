# Network Security Revert Script

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

    # Remove the policy key only when it is empty.
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
        @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name='fAllowToGetHelp' },
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
            if ($LASTEXITCODE -ne 0) {
                $script:PTWErrorCount++
                Write-PTWLog "LanmanWorkstation dependency restore failed (code: $LASTEXITCODE)" "WARNING"
            }
        }
    } catch {
        $script:PTWErrorCount++
        Write-PTWLog "Failed to restore LanmanWorkstation dependencies: $($_.Exception.Message)" "WARNING"
    }

    Write-PTWLog "Reverted network security hardening (policies/overrides)" "SUCCESS"
}

function Repair-ImproveNetworkSecurity {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Windows Features/Capabilities", "Repair removed/disabled networking components")) { return }

    # Do not install legacy features absent from a default Windows 11 system.

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
        Set-SmbServerConfiguration -EncryptData $false -RequireSecuritySignature $false -Confirm:$false -ErrorAction Stop | Out-Null
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

function Restore-BlockLolbinNetwork {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Windows Firewall", "Remove dual-use binary block rules")) { return }
    Remove-NetFirewallRule -Group 'PTW LOLBin Block' -ErrorAction SilentlyContinue
    Write-PTWLog "Removed the dual-use binary network rule group" "SUCCESS"
}

function Restore-NetworkRpcHardening {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert RPC/LMHOSTS hardening")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Rpc' -Name 'EnableAuthEpResolution'
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters' -Name 'EnableLMHOSTS'
    Write-PTWLog "Reverted RPC endpoint-mapper / LMHOSTS hardening" "SUCCESS"
}

function Restore-MssHardening {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert MSS legacy TCP/IP hardening")) { return }
    # Restore the documented Windows defaults for the MSS TCP/IP values.
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'DisableIPSourceRouting' -Type 'DWord' -Value 1
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -Name 'DisableIPSourceRouting' -Type 'DWord' -Value 1
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'EnableICMPRedirect' -Type 'DWord' -Value 1
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters' -Name 'NoNameReleaseOnDemand'
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'SafeDllSearchMode' -Type 'DWord' -Value 1
    Write-PTWLog "Reverted MSS legacy TCP/IP hardening (restored Windows defaults)" "SUCCESS"
}

function Restore-MdnsDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Re-enable mDNS")) { return }
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' -Name 'EnableMDNS' -Type 'DWord' -Value 1
    Write-PTWLog "Re-enabled mDNS (EnableMDNS=1)" "SUCCESS"
}

function Restore-PrintNightmareHardening {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert Print Spooler (PrintNightmare) hardening")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -Name 'RestrictDriverInstallationToAdministrators'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -Name 'NoWarningNoElevationOnInstall'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -Name 'UpdatePromptSettings'
    Write-PTWLog "Reverted Print Spooler PrintNightmare hardening (policy overrides removed)" "SUCCESS"
}

function Restore-RdpNla {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert RDP Network Level Authentication requirement")) { return }
    $rdp = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
    # Restore the Windows default that requires NLA for RDP.
    Set-RegValueSafe -Path $rdp -Name 'UserAuthentication' -Type 'DWord' -Value 1
    Remove-RegValueSafe -Path $rdp -Name 'SecurityLayer'
    Remove-RegValueSafe -Path $rdp -Name 'MinEncryptionLevel'
    # Remove the Group Policy overrides (default is "not configured"/absent).
    $rdpPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
    Remove-RegValueSafe -Path $rdpPolicy -Name 'UserAuthentication'
    Remove-RegValueSafe -Path $rdpPolicy -Name 'SecurityLayer'
    Remove-RegValueSafe -Path $rdpPolicy -Name 'MinEncryptionLevel'
    Write-PTWLog "Reverted RDP NLA tweak (UserAuthentication restored to default 1; SecurityLayer/MinEncryptionLevel removed)" "SUCCESS"
}

function Restore-WinRmHarden {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert WinRM / RPC remote-access hardening")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service' -Name 'AllowBasic'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service' -Name 'AllowUnencryptedTraffic'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service' -Name 'DisableRunAs'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters' -Name 'AllowEncryptionOracle'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Rpc' -Name 'RestrictRemoteClients'
    Write-PTWLog "Reverted WinRM / RPC remote-access hardening (policy overrides removed)" "SUCCESS"
}

function Restore-SmbGuestDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Re-allow insecure SMB guest logons")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation' -Name 'AllowInsecureGuestAuth'
    Write-PTWLog "Reverted insecure SMB guest logon restriction (policy override removed)" "SUCCESS"
}

function Restore-NtlmSessionSecurity {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert NTLM minimum session security")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0' -Name 'NTLMMinClientSec'
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0' -Name 'NTLMMinServerSec'
    Write-PTWLog "Reverted NTLM minimum session security (overrides removed)" "SUCCESS"
}

function Restore-RestrictRemoteSam {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert remote SAM enumeration restriction")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RestrictRemoteSAM'
    Write-PTWLog "Reverted remote SAM enumeration restriction (override removed)" "SUCCESS"
}

function Restore-SpoolerRpcDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Re-enable the Print Spooler inbound remote RPC endpoint")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers' -Name 'RegisterSpoolerRemoteRpcEndPoint'
    Write-PTWLog "Reverted Print Spooler remote RPC endpoint restriction (override removed)" "SUCCESS"
}

function Restore-NetworkAllPrivate {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Restore all network profiles to Private")) { return }
    Write-Output "[*] Setting all network profiles to Private..."
    try {
        $profiles = @(Get-NetConnectionProfile -ErrorAction Stop)
        if ($profiles.Count -eq 0) {
            # Treat an offline system as a successful no-op.
            Write-Output "[i] No active network profiles found; nothing to set to Private."
            return
        }
        $failures = 0
        $profiles | ForEach-Object {
            try {
                Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private -ErrorAction Stop
                Write-Output "  [+] $($_.Name) -> Private"
            } catch {
                $failures++
                Write-Warning "  [WARN] Could not set $($_.Name) to Private: $($_.Exception.Message)"
            }
        }
        if ($failures -gt 0) {
            throw "$failures of $($profiles.Count) network profile(s) could not be changed."
        }
        Write-PTWLog "All network profiles restored to Private" "SUCCESS"
    } catch {
        $script:PTWErrorCount++
        Write-PTWLog "Could not restore all network profiles: $($_.Exception.Message)" "ERROR"
    }
}

function Restore-CountryIpUnblock {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Windows Firewall", "Remove country IP block rules")) { return }
    Write-Output "[*] Removing country IP block firewall rules..."
    try {
        $rules = @(Get-NetFirewallRule -Group 'PTW Country IP Block' -ErrorAction SilentlyContinue)
        if ($rules.Count -gt 0) {
            $rules | Remove-NetFirewallRule -ErrorAction Stop
        }
        $remaining = @(Get-NetFirewallRule -Group 'PTW Country IP Block' -ErrorAction SilentlyContinue)
        if ($remaining.Count -gt 0) {
            throw "$($remaining.Count) firewall rule(s) remain."
        }
        Write-PTWLog "Country IP block rules removed" "SUCCESS"
    } catch {
        $script:PTWErrorCount++
        Write-PTWLog "Country IP block removal failed: $($_.Exception.Message)" "ERROR"
    }
}

$actionMap = @{
    'firewall-hardening'                    = @{ Revert = { Restore-FirewallBaseline } ; Repair = { } }
    'tls-hardening'                         = @{ Revert = { Restore-TlsHardening } ; Repair = { } }
    'security-improve-network'              = @{ Revert = { Restore-ImproveNetworkSecurity } ; Repair = { Repair-ImproveNetworkSecurity } }
    'security-llmnr-disable'                = @{ Revert = { Restore-LlmnrDisable } ; Repair = { } }
    'security-smart-name-resolution-disable' = @{ Revert = { Restore-SmartNameResolutionDisable } ; Repair = { } }
    'security-smb-modern-enforce'           = @{ Revert = { Restore-SmbModernEnforce } ; Repair = { } }
    'security-smb-cipher-suite-order'       = @{ Revert = { Restore-SmbCipherSuiteOrder } ; Repair = { } }
    'security-firewall-logging-enable'      = @{ Revert = { Restore-FirewallLoggingEnable } ; Repair = { } }
    'security-tls-cipher-order'             = @{ Revert = { Restore-TlsCipherOrder } ; Repair = { } }
    'security-block-ntlm-incoming'          = @{ Revert = { Restore-BlockNtlmIncoming } ; Repair = { } }
    'security-block-ntlm-outgoing'          = @{ Revert = { Restore-BlockNtlmOutgoing } ; Repair = { } }
    'security-network-rpc-harden'           = @{ Revert = { Restore-NetworkRpcHardening } ; Repair = { } }
    'security-block-lolbins'                = @{ Revert = { Restore-BlockLolbinNetwork } ; Repair = { } }
    'security-mss-hardening'                = @{ Revert = { Restore-MssHardening } ; Repair = { } }
    'security-mdns-disable'                 = @{ Revert = { Restore-MdnsDisable } ; Repair = { } }
    'security-print-nightmare'              = @{ Revert = { Restore-PrintNightmareHardening } ; Repair = { } }
    'security-spooler-rpc-disable'          = @{ Revert = { Restore-SpoolerRpcDisable } ; Repair = { } }
    'security-rdp-nla'                      = @{ Revert = { Restore-RdpNla } ; Repair = { } }
    'security-winrm-harden'                 = @{ Revert = { Restore-WinRmHarden } ; Repair = { } }
    'security-smb-guest-disable'            = @{ Revert = { Restore-SmbGuestDisable } ; Repair = { } }
    'security-ntlm-session-security'        = @{ Revert = { Restore-NtlmSessionSecurity } ; Repair = { } }
    'security-restrict-remote-sam'          = @{ Revert = { Restore-RestrictRemoteSam } ; Repair = { } }
    # Dispatch literal Network off-actions without a -revert suffix.
    'network-all-private'                   = @{ Revert = { Restore-NetworkAllPrivate } ; Repair = { } }
    'country-ip-unblock'                    = @{ Revert = { Restore-CountryIpUnblock } ; Repair = { } }
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
    Invoke-Mode -RevertBlock { Restore-FirewallBaseline } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-TlsHardening } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-ImproveNetworkSecurity } -RepairBlock { Repair-ImproveNetworkSecurity }
    Invoke-Mode -RevertBlock { Restore-LlmnrDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-SmartNameResolutionDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-SmbModernEnforce } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-SmbCipherSuiteOrder } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-FirewallLoggingEnable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-TlsCipherOrder } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-BlockNtlmIncoming } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-BlockNtlmOutgoing } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-NetworkRpcHardening } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-BlockLolbinNetwork } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-MssHardening } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-MdnsDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-PrintNightmareHardening } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-SpoolerRpcDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-RdpNla } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-WinRmHarden } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-SmbGuestDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-NtlmSessionSecurity } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-RestrictRemoteSam } -RepairBlock { }

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
