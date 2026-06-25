using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static Tweak BuildNetworkSecurity() => new(
        "Network Security",
        $"Network Security{S}network-security.ps1",
        $"Network Security{S}revert-network-security.ps1",
        [
            new SubTweak("Harden Firewall Policies", "firewall-hardening",
                "Apply baseline Windows Firewall policies (domain/private/public)")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' will modify Windows Firewall policies.\n\n" +
                    "This changes default inbound/outbound rules for all profiles. " +
                    "Some applications may be blocked.",
            },
            new SubTweak("Improve network security", SubTweakType.Toggle,
                "security-improve-network", "security-improve-network-revert",
                "Disable SMB1/NetBIOS/legacy network components and harden remote access")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' will harden SMB/NetBIOS and disable legacy network components.\n\n" +
                    "WARNING: This may break file sharing, remote access, or older devices on your network.",
            },
            new SubTweak("Harden TLS/Cryptography", "tls-hardening",
                "Disable TLS 1.0/1.1 and weak ciphers, enforce modern cryptography (may break legacy apps; disabling SHA-1 can break TLS to old appliances)")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' will disable legacy TLS/SSL protocols.\n\n" +
                    "WARNING: This may break connectivity with older websites, VPNs, or enterprise systems.",
            },
            new SubTweak("Disable LLMNR multicast name resolution", SubTweakType.Toggle,
                "security-llmnr-disable", "security-llmnr-disable-revert",
                "Closes Responder-style LAN poisoning attack vector by disabling LLMNR"),
            new SubTweak("Disable Smart Multihomed Name Resolution", SubTweakType.Toggle,
                "security-smart-name-resolution-disable", "security-smart-name-resolution-disable-revert",
                "Prevents DNS leaks on multi-interface systems (e.g., VPN + LAN)"),
            new SubTweak("Enforce SMB 3.1.1 minimum + server encryption", SubTweakType.Toggle,
                "security-smb-modern-enforce", "security-smb-modern-enforce-revert",
                "Require SMB 3.1.1 dialect minimum and server-side encryption for file shares. WARNING: can block access to NAS devices, older shares, and network printers that only support older SMB dialects")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' will enforce SMB 3.1.1 minimum and require server-side encryption.\n\n" +
                    "WARNING: May break connectivity to older file servers (SMB 2.x/3.0) including some NAS devices and printers.",
            },
            new SubTweak("Configure secure SMB cipher suite order", SubTweakType.Toggle,
                "security-smb-cipher-suite-order", "security-smb-cipher-suite-order-revert",
                "Prefer AES-256-GCM for SMB encryption (server and client)"),
            new SubTweak("Enable per-profile firewall logging", SubTweakType.Toggle,
                "security-firewall-logging-enable", "security-firewall-logging-enable-revert",
                "Log dropped and allowed connections to %SystemRoot%\\System32\\LogFiles\\Firewall\\pfirewall.log (forensics)")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will write firewall logs to %SystemRoot%\\System32\\LogFiles\\Firewall\\pfirewall.log (up to 32 MB per profile).\n\n" +
                    "Safe change — useful for forensics. Revert restores defaults.",
            },
            new SubTweak("Configure TLS cipher suite + ECC curve order", SubTweakType.Toggle,
                "security-tls-cipher-order", "security-tls-cipher-order-revert",
                "Prefer TLS 1.3 suites and AES-256-GCM; set ECC curve priority")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will set the system-wide TLS cipher suite and ECC curve order.\n\n" +
                    "Prefers TLS 1.3 suites and AES-256-GCM. Mostly safe but may affect apps that hardcoded specific cipher orders.",
            },
            new SubTweak("Block INCOMING NTLM authentication (PAW only)", SubTweakType.Toggle,
                "security-block-ntlm-incoming", "security-block-ntlm-incoming-revert",
                "Deny all incoming NTLM. WARNING: breaks SMB file shares, RDP, Hyper-V against this machine")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' will DENY all incoming NTLM authentication to this machine.\n\n" +
                    "SEVERE: Breaks SMB file shares, RDP, Hyper-V, MMC snap-ins, and any service that uses NTLM to authenticate AGAINST this machine. " +
                    "Only suitable for isolated Privileged Access Workstations.",
            },
            new SubTweak("Block OUTGOING NTLM authentication (PAW only)", SubTweakType.Toggle,
                "security-block-ntlm-outgoing", "security-block-ntlm-outgoing-revert",
                "Deny all outgoing NTLM. WARNING: breaks auth to legacy servers, some network printers")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' will DENY all outgoing NTLM authentication from this machine.\n\n" +
                    "SEVERE: Breaks authentication to legacy servers, some network printers, and SMB shares that don't support Kerberos. " +
                    "Only suitable for isolated Privileged Access Workstations.",
            },
            new SubTweak("Block dual-use (LOLBin) binaries in firewall", SubTweakType.Toggle,
                "security-block-lolbins", "security-block-lolbins-revert",
                "Block network access for commonly-abused binaries (certutil, mshta, wscript, regsvr32, bitsadmin, wmic, cmstp, cscript). WARNING: can break legitimate admin scripting that uses them")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' blocks network access for dual-use binaries (certutil, mshta, wscript, regsvr32, bitsadmin, wmic, cmstp, cscript).\n\n" +
                    "WARNING: this can break legitimate administrative scripting or tooling that relies on those binaries reaching the network.",
            },
            new SubTweak("RPC endpoint / LMHOSTS network hardening", SubTweakType.Toggle,
                "security-network-rpc-harden", "security-network-rpc-harden-revert",
                "Require authentication for RPC endpoint-mapper resolution and disable legacy LMHOSTS name lookup"),
            new SubTweak("MSS legacy TCP/IP hardening", SubTweakType.Toggle,
                "security-mss-hardening", "security-mss-hardening-revert",
                "Disable IPv4/IPv6 source routing and ICMP redirects, keep NetBIOS name on demand, and force safe DLL search mode"),
            new SubTweak("Disable mDNS", SubTweakType.Toggle,
                "security-mdns-disable", "security-mdns-disable-revert",
                "Close the mDNS LAN spoofing vector (same class as LLMNR) by disabling multicast DNS"),
            new SubTweak("Harden Print Spooler (PrintNightmare)", SubTweakType.Toggle,
                "security-print-nightmare", "security-print-nightmare-revert",
                "Restrict Point-and-Print driver installation to admins (mitigates CVE-2021-34527) without disabling printing"),
            new SubTweak("Require RDP Network Level Authentication", SubTweakType.Toggle,
                "security-rdp-nla", "security-rdp-nla-revert",
                "Force NLA + TLS + high encryption for Remote Desktop. WARNING: only relevant if you use RDP; blocks legacy RDP clients that can't do NLA")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' requires Network Level Authentication, TLS and high encryption for Remote Desktop.\n\n" +
                    "Only relevant if you use RDP to reach this PC. WARNING: this blocks legacy RDP clients that cannot do NLA/CredSSP. Revert restores the defaults.",
            },
            new SubTweak("Harden WinRM / RPC remote access", SubTweakType.Toggle,
                "security-winrm-harden", "security-winrm-harden-revert",
                "Disable WinRM Basic/unencrypted auth, force CredSSP oracle remediation, and restrict remote RPC clients. WARNING: breaks inbound remote PowerShell/management to this PC")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' hardens WinRM and remote RPC access.\n\n" +
                    "SEVERE: this breaks INBOUND remote PowerShell / WinRM management to this PC and restricts remote RPC clients. Do not enable on a machine you administer remotely. Revert removes the policy overrides.",
            },
            new SubTweak("Set all networks to Public", SubTweakType.Toggle,
                "network-all-public", "network-all-private",
                "Set all connected network profiles to Public (reduces trust to LAN devices; breaks local file sharing and printer discovery)")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' will set every connected network profile to Public.\n\n" +
                    "WARNING: Breaks local file sharing, printer discovery, mDNS/Bonjour, network discovery, and Cast-to-Device on your LAN. " +
                    "Only appropriate for coffee-shop / untrusted networks.",
            },
            new SubTweak("Block sanctioned-country IP ranges", SubTweakType.Toggle,
                "country-ip-block", "country-ip-unblock",
                "Create firewall rules that block inbound+outbound traffic to State-Sponsors-of-Terrorism + OFAC-sanctioned country IP ranges (lists fetched live from a curated IANA IP-block source). WARNING: a VPN/VPS in another country bypasses it; revert removes the rules")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' blocks inbound and outbound traffic to entire sanctioned-country IP ranges.\n\n" +
                    "Lists (State Sponsors of Terrorism + OFAC) are fetched live from a curated IANA IP-block source and validated as CIDR. A VPN/VPS endpoint in another country bypasses this. Revert removes the rules.",
            },
        ]);
}
