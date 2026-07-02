# Network Security Tweaks
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "firewall-hardening",
        "tls-hardening",
        "security-improve-network",
        "security-llmnr-disable",
        "security-smart-name-resolution-disable",
        "security-smb-modern-enforce",
        "security-smb-cipher-suite-order",
        "security-firewall-logging-enable",
        "security-tls-cipher-order",
        "security-block-ntlm-incoming",
        "security-block-ntlm-outgoing",
        "security-network-rpc-harden",
        "security-block-lolbins",
        "security-mss-hardening",
        "security-mdns-disable",
        "security-print-nightmare",
        "security-spooler-rpc-disable",
        "security-rdp-nla",
        "security-winrm-harden",
        "security-smb-guest-disable",
        "security-ntlm-session-security",
        "security-restrict-remote-sam",
        "network-all-public",
        "network-all-private",
        "country-ip-block",
        "country-ip-unblock",
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

# Firewall hardening
function Set-FirewallBaseline {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Windows Firewall", "Apply firewall baseline")) { return }
    $basePath = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall'
    foreach ($fwProfile in @('DomainProfile','PrivateProfile','PublicProfile')) {
        # Use the registry helper so write failures affect the action result.
        Set-RegValueSafe -Path "$basePath\$fwProfile" -Name 'EnableFirewall' -Type 'DWord' -Value 1
        Set-RegValueSafe -Path "$basePath\$fwProfile" -Name 'DefaultOutboundAction' -Type 'DWord' -Value 0
        Set-RegValueSafe -Path "$basePath\$fwProfile" -Name 'DefaultInboundAction' -Type 'DWord' -Value 1
        Set-RegValueSafe -Path "$basePath\$fwProfile\Logging" -Name 'LogDroppedPackets' -Type 'DWord' -Value 1
        Set-RegValueSafe -Path "$basePath\$fwProfile\Logging" -Name 'LogSuccessfulConnections' -Type 'DWord' -Value 1
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
        # Disable the SMB1 server negotiator before removing the optional feature.
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
                    $script:PTWErrorCount++
                    Write-Warning "[WARN] Failed NetBIOS disable on $($_.PSChildName): $($_.Exception.Message)"
                }
            }
        }
    } catch {
        $script:PTWErrorCount++
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
        $script:PTWErrorCount++
        Write-Warning "[WARN] Failed to disable mrxsmb10: $($_.Exception.Message)"
    }

    # Remove SMB1 dependency from LanmanWorkstation.
    try {
        $sc = Get-Command sc.exe -ErrorAction SilentlyContinue
        if ($sc) {
            & $sc.Path config lanmanworkstation depend= bowser/mrxsmb20/nsi | Out-Null
            if ($LASTEXITCODE -ne 0) {
                $script:PTWErrorCount++
                Write-Warning "[WARN] LanmanWorkstation dependency update failed (code: $LASTEXITCODE)"
            }
        }
    } catch {
        $script:PTWErrorCount++
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

        # Disable MD5 while retaining SHA-1 compatibility for legacy TLS endpoints.
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

        # Enable DTLS 1.2 for clients and servers.
        $protocols += @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\DTLS 1.2\Server'; Enabled = 1; DisabledByDefault = 0 }
        $protocols += @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\DTLS 1.2\Client'; Enabled = 1; DisabledByDefault = 0 }
        # Enable TLS 1.3 (server + client).
        $protocols += @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server'; Enabled = 1; DisabledByDefault = 0 }
        $protocols += @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client'; Enabled = 1; DisabledByDefault = 0 }

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
    Write-Output "[!] WARNING: Setting the SMB CLIENT minimum dialect to 3.1.1 will block this PC from connecting to any share that only speaks SMB 2.x/3.0 - this includes many NAS units (older Synology/QNAP firmware), network printers/scanners, Samba < 4.11, and Windows 7/8/Server 2012 shares. You may lose access until you use Restore Default."
    Write-Output "[!] WARNING: Requiring SMB server-side encryption (EncryptData) will block non-SMB3 clients (Windows 7, scan-to-folder printers, older media players/TVs) from reaching shares hosted on THIS machine."
    # Dialect values: 0x0202=2.0.2, 0x0210=2.1, 0x0300=3.0, 0x0302=3.0.2, 0x0311=3.1.1
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name 'Smb2DialectMin' -Type 'DWord' -Value 0x0311
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Name 'Smb2DialectMin' -Type 'DWord' -Value 0x0311
    try {
        Set-SmbServerConfiguration -EncryptData $true -RejectUnencryptedAccess $false -Confirm:$false -ErrorAction Stop | Out-Null
        Set-SmbClientConfiguration -RequireSecuritySignature $true -EnableSecuritySignature $true -Confirm:$false -ErrorAction Stop | Out-Null
    } catch {
        $script:PTWErrorCount++
        Write-Warning "[WARN] SMB cmdlet config failed: $($_.Exception.Message)"
    }
    if ($script:PTWErrorCount -eq 0) {
        Write-Output "[+] SUCCESS: SMB 3.1.1 minimum enforced, server encryption required"
    }
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
        $netshOk = $true
        foreach ($p in @('domainprofile','privateprofile','publicprofile')) {
            $cmds = @(
                @('logging','filename','%systemroot%\system32\LogFiles\Firewall\pfirewall.log'),
                @('logging','maxfilesize','32767'),
                @('logging','droppedconnections','enable'),
                @('logging','allowedconnections','enable')
            )
            foreach ($c in $cmds) {
                netsh advfirewall set $p @c 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    $netshOk = $false
                    Write-Warning "[WARN] netsh advfirewall set $p $($c -join ' ') failed (code: $LASTEXITCODE)"
                }
            }
        }
        if ($netshOk) {
            Write-Output "[+] SUCCESS: Firewall logging enabled via netsh"
        } else {
            Write-Output "[-] ERROR: Firewall logging fallback via netsh did not fully succeed"
            $script:PTWErrorCount++
        }
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

function Set-NetworkRpcHardening {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Harden RPC endpoint mapper and disable LMHOSTS")) { return }
    Write-Output "[*] Requiring RPC endpoint-mapper client authentication and disabling LMHOSTS lookup..."
    Set-RegDword -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Rpc' -Name 'EnableAuthEpResolution' -Value 1
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters' -Name 'EnableLMHOSTS' -Value 0
    Write-Output "[+] SUCCESS: RPC/LMHOSTS network hardening applied"
}

# Block commonly abused system binaries that PleaseTweakWindows does not require.
$script:PtwLolbins = @('bitsadmin.exe','certutil.exe','cmstp.exe','cscript.exe','wscript.exe','mshta.exe','wmic.exe','regsvr32.exe')

function Set-BlockLolbinNetwork {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Windows Firewall", "Block network for dual-use binaries")) { return }
    Write-Output "[*] Creating firewall rules to block network access for dual-use (living-off-the-land) binaries..."
    Write-Output "[!] WARNING: this cuts inbound/outbound network for tools like certutil, mshta, wscript, regsvr32. It can break legitimate admin scripting or tooling that relies on them."
    # Remove any existing rules first so re-running does not duplicate them.
    Remove-NetFirewallRule -Group 'PTW LOLBin Block' -ErrorAction SilentlyContinue
    foreach ($baseDir in @("$env:SystemRoot\System32", "$env:SystemRoot\SysWOW64")) {
        foreach ($exe in $script:PtwLolbins) {
            $progPath = Join-Path $baseDir $exe
            if (-not (Test-Path -LiteralPath $progPath)) { continue }
            foreach ($dir in @('Inbound','Outbound')) {
                try {
                    New-NetFirewallRule -DisplayName "PTW-BlockLOLBin-$exe-$dir" -Group 'PTW LOLBin Block' `
                        -Program $progPath -Direction $dir -Action Block -Profile Any -ErrorAction Stop | Out-Null
                } catch {
                    $script:PTWErrorCount++
                    Write-Output "[-] Failed to create LOLBin rule for $exe ($dir): $($_.Exception.Message)"
                }
            }
        }
    }
    Write-Output "[+] SUCCESS: dual-use binary network rules created"
}

function Set-MssHardening {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Apply MSS legacy TCP/IP hardening")) { return }
    Write-Output "[*] Applying MSS legacy TCP/IP stack hardening..."
    # Disable IPv4/IPv6 source routing entirely (2 = highest protection).
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'DisableIPSourceRouting' -Value 2
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -Name 'DisableIPSourceRouting' -Value 2
    # Ignore ICMP redirects (prevents route table poisoning).
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'EnableICMPRedirect' -Value 0
    # Don't release the NetBIOS name on demand (anti-spoofing).
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters' -Name 'NoNameReleaseOnDemand' -Value 1
    # Force safe DLL search order.
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'SafeDllSearchMode' -Value 1
    Write-Output "[+] SUCCESS: MSS legacy TCP/IP hardening applied"
}

function Set-MdnsDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable mDNS")) { return }
    Write-Output "[*] Disabling mDNS (closes the LAN mDNS spoofing vector, same class as LLMNR)..."
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' -Name 'EnableMDNS' -Value 0
    Write-Output "[+] SUCCESS: mDNS disabled"
}

function Set-PrintNightmareHardening {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Harden Print Spooler (PrintNightmare)")) { return }
    Write-Output "[*] Hardening Print Spooler against remote driver installation (CVE-2021-34527 / PrintNightmare)..."
    # RestrictDriverInstallationToAdministrators lives under PointAndPrint (per KB5005652); it is inert under the parent key.
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -Name 'RestrictDriverInstallationToAdministrators' -Value 1
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -Name 'NoWarningNoElevationOnInstall' -Value 0
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -Name 'UpdatePromptSettings' -Value 0
    Write-Output "[+] SUCCESS: Print Spooler hardened (printing still works; remote driver install is restricted to admins)"
}

function Set-RdpNla {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Require RDP Network Level Authentication")) { return }
    Write-Output "[*] Requiring Network Level Authentication and TLS for Remote Desktop..."
    Write-Output "[!] WARNING: only relevant if you use Remote Desktop to connect to this PC. NLA + high encryption + TLS will block legacy RDP clients (old mstsc, some thin clients) that cannot do CredSSP/NLA."
    $rdp = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
    Set-RegDword -Path $rdp -Name 'UserAuthentication' -Value 1
    Set-RegDword -Path $rdp -Name 'SecurityLayer' -Value 2
    Set-RegDword -Path $rdp -Name 'MinEncryptionLevel' -Value 3
    Write-Output "[+] SUCCESS: RDP Network Level Authentication required"
}

function Set-WinRmHarden {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Harden WinRM / RPC remote access")) { return }
    Write-Output "[*] Hardening WinRM and RPC remote access..."
    Write-Output "[!] WARNING: this breaks INBOUND remote PowerShell / WinRM management to this PC and restricts remote RPC clients. Do not enable on a machine you manage remotely."
    # WinRM service: no Basic auth, no unencrypted traffic, no RunAs credential delegation.
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service' -Name 'AllowBasic' -Value 0
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service' -Name 'AllowUnencryptedTraffic' -Value 0
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service' -Name 'DisableRunAs' -Value 1
    # CredSSP encryption-oracle remediation: 0 = Force Updated Clients (most secure).
    Set-RegDword -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters' -Name 'AllowEncryptionOracle' -Value 0
    # Restrict unauthenticated remote RPC clients (2 = authenticated only, no exceptions).
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Rpc' -Name 'RestrictRemoteClients' -Value 2
    Write-Output "[+] SUCCESS: WinRM / RPC remote access hardened (inbound remote management restricted)"
}

function Set-SmbGuestDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable insecure SMB guest logons")) { return }
    Write-Output "[*] Disabling insecure SMB guest logons (AllowInsecureGuestAuth=0)..."
    Write-Output "[!] WARNING: unauthenticated guest access to SMB shares will stop working. Some consumer NAS units and media boxes rely on guest SMB; you may lose access until you use Restore Default."
    # Policy form is authoritative over the service parameter.
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation' -Name 'AllowInsecureGuestAuth' -Value 0
    Write-Output "[+] SUCCESS: insecure SMB guest logons disabled"
}

function Set-NtlmSessionSecurity {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Require NTLM SSP 128-bit + NTLMv2 session security")) { return }
    Write-Output "[*] Requiring 128-bit encryption and NTLMv2 session security for the NTLM SSP (client + server)..."
    # 537395200 = 0x20080000 = Require NTLMv2 session security (0x80000) + Require 128-bit encryption (0x20000000).
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0' -Name 'NTLMMinClientSec' -Value 537395200
    Set-RegDword -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0' -Name 'NTLMMinServerSec' -Value 537395200
    Write-Output "[+] SUCCESS: NTLM minimum session security set to 128-bit + NTLMv2"
}

function Set-RestrictRemoteSam {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Restrict remote SAM enumeration to administrators")) { return }
    Write-Output "[*] Restricting remote SAM (SAMR) enumeration to administrators only..."
    # Restrict SAMR account enumeration to administrators.
    Set-RegSz -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RestrictRemoteSAM' -Value 'O:BAG:BAD:(A;;RC;;;BA)'
    Write-Output "[+] SUCCESS: remote SAM enumeration restricted to administrators"
}

function Set-SpoolerRpcDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Disable the Print Spooler inbound remote RPC endpoint")) { return }
    Write-Output "[*] Disabling the Print Spooler's inbound remote RPC endpoint (PrintNightmare-class inbound surface)..."
    Write-Output "[!] WARNING: this PC will no longer accept remote print connections (it can still print locally and to network printers). Shared printers HOSTED on this PC become unreachable; Restore Default restores the endpoint."
    # RegisterSpoolerRemoteRpcEndPoint: 1 = enabled (default), 2 = disabled.
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers' -Name 'RegisterSpoolerRemoteRpcEndPoint' -Value 2
    Write-Output "[+] SUCCESS: Print Spooler remote RPC endpoint disabled"
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
            'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces',
            'HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb10',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LanmanServer',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services',
            'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance'
        )
        Set-ImproveNetworkSecurity
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

    "security-network-rpc-harden" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Rpc',
            'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters'
        )
        Set-NetworkRpcHardening
        Exit-PTW
    }

    "security-block-lolbins" {
        Set-BlockLolbinNetwork
        Exit-PTW
    }

    "security-mss-hardening" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters',
            'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters',
            'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters',
            'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
        )
        Set-MssHardening
        Exit-PTW
    }

    "security-mdns-disable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters'
        )
        Set-MdnsDisable
        Exit-PTW
    }

    "security-print-nightmare" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers'
        )
        Set-PrintNightmareHardening
        Exit-PTW
    }

    "security-spooler-rpc-disable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers'
        )
        Set-SpoolerRpcDisable
        Exit-PTW
    }

    "security-rdp-nla" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
        )
        Set-RdpNla
        Exit-PTW
    }

    "security-winrm-harden" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Rpc'
        )
        Set-WinRmHarden
        Exit-PTW
    }

    "security-smb-guest-disable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation'
        )
        Set-SmbGuestDisable
        Exit-PTW
    }

    "security-ntlm-session-security" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0'
        )
        Set-NtlmSessionSecurity
        Exit-PTW
    }

    "security-restrict-remote-sam" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
        )
        Set-RestrictRemoteSam
        Exit-PTW
    }

    "network-all-public" {
        Write-Output "[*] Setting all network profiles to Public..."
        try {
            $profiles = @(Get-NetConnectionProfile -ErrorAction Stop)
            if ($profiles.Count -eq 0) {
                Write-Output "[-] ERROR: No network profiles were found."
                exit 1
            }
            $failed = 0
            $profiles | ForEach-Object {
                try {
                    Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Public -ErrorAction Stop
                    Write-Output "  [+] $($_.Name) -> Public"
                } catch {
                    $failed++
                    Write-Warning "  [WARN] Could not set $($_.Name) to Public: $($_.Exception.Message)"
                }
            }
            if ($failed -gt 0) {
                Write-Output "[-] ERROR: $failed of $($profiles.Count) network profile(s) could not be changed."
                exit 1
            }
            Write-Output "[+] SUCCESS: All network profiles set to Public (reduces trust to LAN devices)"
        } catch {
            Write-Error "Failed to enumerate network profiles: $($_.Exception.Message)"
            exit 1
        }
        Exit-PTW
    }

    "network-all-private" {
        Write-Output "[*] Setting all network profiles to Private..."
        try {
            $profiles = @(Get-NetConnectionProfile -ErrorAction Stop)
            if ($profiles.Count -eq 0) {
                Write-Output "[-] ERROR: No network profiles were found."
                exit 1
            }
            $failed = 0
            $profiles | ForEach-Object {
                try {
                    Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private -ErrorAction Stop
                    Write-Output "  [+] $($_.Name) -> Private"
                } catch {
                    $failed++
                    Write-Warning "  [WARN] Could not set $($_.Name) to Private: $($_.Exception.Message)"
                }
            }
            if ($failed -gt 0) {
                Write-Output "[-] ERROR: $failed of $($profiles.Count) network profile(s) could not be changed."
                exit 1
            }
            Write-Output "[+] SUCCESS: All network profiles restored to Private"
        } catch {
            Write-Error "Failed to enumerate network profiles: $($_.Exception.Message)"
            exit 1
        }
        Exit-PTW
    }

    "country-ip-block" {
        Write-Output "[*] Blocking sanctioned-region IP ranges in Windows Firewall..."
        Write-Output "[!] WARNING: this blocks inbound AND outbound traffic to entire countries' IP ranges (State Sponsors of Terrorism + OFAC sanctioned). A VPN/VPS endpoint in another country bypasses it. Lists are fetched live from a curated IANA IP-block source and validated as CIDR before use."
        $bundles = @(
            @{ Name = 'PTW Country IP Block - State Sponsors of Terrorism'; Url = 'https://raw.githubusercontent.com/HotCakeX/Official-IANA-IP-blocks/main/Curated-Lists/StateSponsorsOfTerrorism.txt' },
            @{ Name = 'PTW Country IP Block - OFAC Sanctioned'; Url = 'https://raw.githubusercontent.com/HotCakeX/Official-IANA-IP-blocks/main/Curated-Lists/OFACSanctioned.txt' }
        )
        $resolvedBundles = @()
        foreach ($b in $bundles) {
            try {
                $cidrs = @(Get-CidrListFromWeb -URL $b.Url)
                $resolvedBundles += [pscustomobject]@{ Name = $b.Name; Cidrs = $cidrs }
            } catch {
                Write-Output "[-] ERROR: Could not fetch '$($b.Name)': $($_.Exception.Message)"
                Write-Output "[i] Existing country-block rules were left unchanged."
                exit 1
            }
        }

        Remove-NetFirewallRule -Group 'PTW Country IP Block' -ErrorAction SilentlyContinue
        $chunkSize = 1000
        $created = 0
        $failed = 0
        foreach ($b in $resolvedBundles) {
            $cidrs = $b.Cidrs
            $batch = 0
            for ($i = 0; $i -lt $cidrs.Count; $i += $chunkSize) {
                $batch++
                $hi = [Math]::Min($i + $chunkSize - 1, $cidrs.Count - 1)
                $slice = @($cidrs[$i..$hi])
                foreach ($dir in @('Inbound','Outbound')) {
                    try {
                        New-NetFirewallRule -DisplayName "$($b.Name) - $dir $batch" -Group 'PTW Country IP Block' `
                            -Direction $dir -Action Block -RemoteAddress $slice -Profile Any -ErrorAction Stop | Out-Null
                        $created++
                    } catch {
                        $failed++
                        Write-Output "[-] '$($b.Name)' batch $batch ($dir) failed: $($_.Exception.Message)"
                    }
                }
            }
            Write-Output "  [+] $($b.Name): $($cidrs.Count) ranges across $batch batch(es)"
        }
        if ($created -eq 0 -or $failed -gt 0) {
            Remove-NetFirewallRule -Group 'PTW Country IP Block' -ErrorAction SilentlyContinue
            Write-Output "[-] ERROR: Country IP blocking was incomplete ($created rules created, $failed failures). Partial rules were rolled back."
            exit 1
        }
        Write-Output "[+] SUCCESS: country IP blocking applied ($created firewall rule(s))"
        Exit-PTW
    }

    "country-ip-unblock" {
        Write-Output "[*] Removing country IP block firewall rules..."
        try {
            Remove-NetFirewallRule -Group 'PTW Country IP Block' -ErrorAction Stop
        } catch {
            $remaining = @(Get-NetFirewallRule -Group 'PTW Country IP Block' -ErrorAction SilentlyContinue)
            if ($remaining.Count -gt 0) {
                Write-Output "[-] ERROR: Could not remove all country IP block rules: $($_.Exception.Message)"
                exit 1
            }
        }
        Write-Output "[+] SUCCESS: country IP block rules removed"
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
