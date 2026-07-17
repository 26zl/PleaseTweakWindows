@{
    SchemaVersion = 1
    Id = 'cis-windows-11-24h2-l1'
    Name = 'Windows 11 CIS Level 1-aligned baseline'
    Benchmark = 'CIS Microsoft Windows 11 24H2 Level 1 Benchmark (curated reference subset; based on v4.0.0, newer CIS release exists)'
    ReferenceCommit = '54116592C959C2BC4EE7111D8783C251DA089A83'
    Coverage = 'Conservative project action set; not an official CIS Build Kit or certification.'
    Routes = @(
        @{ ApplyScript = 'System Security/system-security.ps1'; ApplyAction = 'security-autorun-disable'; RevertScript = 'System Security/revert-system-security.ps1'; RevertAction = 'security-autorun-revert' }
        @{ ApplyScript = 'System Security/system-security.ps1'; ApplyAction = 'security-lm-hash-disable'; RevertScript = 'System Security/revert-system-security.ps1'; RevertAction = 'security-lm-hash-revert' }
        @{ ApplyScript = 'System Security/system-security.ps1'; ApplyAction = 'security-always-install-elevated-disable'; RevertScript = 'System Security/revert-system-security.ps1'; RevertAction = 'security-always-install-elevated-revert' }
        @{ ApplyScript = 'System Security/system-security.ps1'; ApplyAction = 'security-ps2-downgrade-protection-enable'; RevertScript = 'System Security/revert-system-security.ps1'; RevertAction = 'security-ps2-downgrade-protection-revert' }
        @{ ApplyScript = 'System Security/system-security.ps1'; ApplyAction = 'security-wcn-disable'; RevertScript = 'System Security/revert-system-security.ps1'; RevertAction = 'security-wcn-revert' }
        @{ ApplyScript = 'System Security/system-security.ps1'; ApplyAction = 'security-binary-integrity-harden'; RevertScript = 'System Security/revert-system-security.ps1'; RevertAction = 'security-binary-integrity-harden-revert' }
        @{ ApplyScript = 'System Security/system-security.ps1'; ApplyAction = 'security-smartscreen-enforce'; RevertScript = 'System Security/revert-system-security.ps1'; RevertAction = 'security-smartscreen-enforce-revert' }
        @{ ApplyScript = 'System Security/system-security.ps1'; ApplyAction = 'security-lock-screen-harden'; RevertScript = 'System Security/revert-system-security.ps1'; RevertAction = 'security-lock-screen-harden-revert' }
        @{ ApplyScript = 'System Security/system-security.ps1'; ApplyAction = 'security-account-lockout'; RevertScript = 'System Security/revert-system-security.ps1'; RevertAction = 'security-account-lockout-revert' }
        @{ ApplyScript = 'System Security/system-security.ps1'; ApplyAction = 'security-audit-policy'; RevertScript = 'System Security/revert-system-security.ps1'; RevertAction = 'security-audit-policy-revert' }
        @{ ApplyScript = 'System Security/system-security.ps1'; ApplyAction = 'security-disable-coinstallers'; RevertScript = 'System Security/revert-system-security.ps1'; RevertAction = 'security-disable-coinstallers-revert' }
        @{ ApplyScript = 'System Security/system-security.ps1'; ApplyAction = 'security-filter-admin-token'; RevertScript = 'System Security/revert-system-security.ps1'; RevertAction = 'security-filter-admin-token-revert' }
        @{ ApplyScript = 'Defender/defender.ps1'; ApplyAction = 'security-defender-network-protection-enable'; RevertScript = 'Defender/revert-defender.ps1'; RevertAction = 'security-defender-network-protection-enable-revert' }
        @{ ApplyScript = 'Defender/defender.ps1'; ApplyAction = 'security-defender-pua-enable'; RevertScript = 'Defender/revert-defender.ps1'; RevertAction = 'security-defender-pua-enable-revert' }
        @{ ApplyScript = 'Defender/defender.ps1'; ApplyAction = 'security-defender-cloud-tune'; RevertScript = 'Defender/revert-defender.ps1'; RevertAction = 'security-defender-cloud-tune-revert' }
        @{ ApplyScript = 'Defender/defender.ps1'; ApplyAction = 'security-asr-rules-enable'; RevertScript = 'Defender/revert-defender.ps1'; RevertAction = 'security-asr-rules-enable-revert' }
        @{ ApplyScript = 'Exploit Protection/exploit-protection.ps1'; ApplyAction = 'security-dep-enable'; RevertScript = 'Exploit Protection/revert-exploit-protection.ps1'; RevertAction = 'security-dep-revert' }
        @{ ApplyScript = 'Exploit Protection/exploit-protection.ps1'; ApplyAction = 'security-sehop-enable'; RevertScript = 'Exploit Protection/revert-exploit-protection.ps1'; RevertAction = 'security-sehop-revert' }
        @{ ApplyScript = 'Device Guard/device-guard.ps1'; ApplyAction = 'security-lsa-protection-enable'; RevertScript = 'Device Guard/revert-device-guard.ps1'; RevertAction = 'security-lsa-protection-enable-revert' }
        @{ ApplyScript = 'Device Guard/device-guard.ps1'; ApplyAction = 'security-vuln-driver-blocklist'; RevertScript = 'Device Guard/revert-device-guard.ps1'; RevertAction = 'security-vuln-driver-blocklist-revert' }
        @{ ApplyScript = 'Device Guard/device-guard.ps1'; ApplyAction = 'security-wdigest-disable'; RevertScript = 'Device Guard/revert-device-guard.ps1'; RevertAction = 'security-wdigest-disable-revert' }
        @{ ApplyScript = 'Network Security/network-security.ps1'; ApplyAction = 'firewall-hardening'; RevertScript = 'Network Security/revert-network-security.ps1'; RevertAction = 'firewall-hardening-revert' }
        @{ ApplyScript = 'Network Security/network-security.ps1'; ApplyAction = 'security-improve-network'; RevertScript = 'Network Security/revert-network-security.ps1'; RevertAction = 'security-improve-network-revert' }
        @{ ApplyScript = 'Network Security/network-security.ps1'; ApplyAction = 'security-llmnr-disable'; RevertScript = 'Network Security/revert-network-security.ps1'; RevertAction = 'security-llmnr-disable-revert' }
        @{ ApplyScript = 'Network Security/network-security.ps1'; ApplyAction = 'security-smart-name-resolution-disable'; RevertScript = 'Network Security/revert-network-security.ps1'; RevertAction = 'security-smart-name-resolution-disable-revert' }
        @{ ApplyScript = 'Network Security/network-security.ps1'; ApplyAction = 'security-firewall-logging-enable'; RevertScript = 'Network Security/revert-network-security.ps1'; RevertAction = 'security-firewall-logging-enable-revert' }
        @{ ApplyScript = 'Network Security/network-security.ps1'; ApplyAction = 'security-network-rpc-harden'; RevertScript = 'Network Security/revert-network-security.ps1'; RevertAction = 'security-network-rpc-harden-revert' }
        @{ ApplyScript = 'Network Security/network-security.ps1'; ApplyAction = 'security-mss-hardening'; RevertScript = 'Network Security/revert-network-security.ps1'; RevertAction = 'security-mss-hardening-revert' }
        @{ ApplyScript = 'Network Security/network-security.ps1'; ApplyAction = 'security-mdns-disable'; RevertScript = 'Network Security/revert-network-security.ps1'; RevertAction = 'security-mdns-disable-revert' }
        @{ ApplyScript = 'Network Security/network-security.ps1'; ApplyAction = 'security-print-nightmare'; RevertScript = 'Network Security/revert-network-security.ps1'; RevertAction = 'security-print-nightmare-revert' }
        @{ ApplyScript = 'Network Security/network-security.ps1'; ApplyAction = 'security-smb-guest-disable'; RevertScript = 'Network Security/revert-network-security.ps1'; RevertAction = 'security-smb-guest-disable-revert' }
        @{ ApplyScript = 'Network Security/network-security.ps1'; ApplyAction = 'security-ntlm-session-security'; RevertScript = 'Network Security/revert-network-security.ps1'; RevertAction = 'security-ntlm-session-security-revert' }
        @{ ApplyScript = 'Network Security/network-security.ps1'; ApplyAction = 'security-restrict-remote-sam'; RevertScript = 'Network Security/revert-network-security.ps1'; RevertAction = 'security-restrict-remote-sam-revert' }
        @{ ApplyScript = 'Network Security/network-security.ps1'; ApplyAction = 'security-rdp-nla'; RevertScript = 'Network Security/revert-network-security.ps1'; RevertAction = 'security-rdp-nla-revert' }
        @{ ApplyScript = 'Edge/Edge.ps1'; ApplyAction = 'edge-harden'; RevertScript = 'Edge/Edge.ps1'; RevertAction = 'edge-harden-revert' }
    )
}

