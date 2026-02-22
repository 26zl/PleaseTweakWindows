using System.Collections.Immutable;
using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed class TweakRegistry : ITweakRegistry
{
    private static readonly char S = Path.DirectorySeparatorChar;

    private readonly IReadOnlyList<Tweak> _tweaks = BuildTweaks();

    public IReadOnlyList<Tweak> GetTweaks() => _tweaks;

    private static IReadOnlyList<Tweak> BuildTweaks() =>
    [
        BuildGamingOptimizations(),
        BuildNetworkOptimizations(),
        BuildGeneralTweaks(),
        BuildServicesManagement(),
        BuildPrivacy(),
        BuildSecurity()
    ];

    private static Tweak BuildGamingOptimizations() => new(
        "Gaming Optimizations",
        $"Gaming optimizations{S}Gaming-Optimizations.ps1",
        $"Gaming optimizations{S}Gaming-Optimizations.ps1",
        [
            new SubTweak("Nvidia Settings", SubTweakType.Toggle, "nvidia-settings-on", "nvidia-settings-default",
                "Optimize NVIDIA control panel settings for gaming performance"),
            new SubTweak("Nvidia Driver", "nvidia-driver-install",
                "Install/update NVIDIA driver or NvCleanInstall"),
            new SubTweak("AMD Driver", "amd-driver-install",
                "Install/update AMD Radeon driver"),
            new SubTweak("P0 State Nvidia", SubTweakType.Toggle, "p0-state-on", "p0-state-default",
                "Force maximum GPU performance state (disable dynamic P-states)"),
            new SubTweak("ULPS AMD", SubTweakType.Toggle, "ulps-disable", "ulps-enable",
                "Disable Ultra Low Power State for AMD GPUs"),
            new SubTweak("Controller Overclock", SubTweakType.Toggle, "controller-oc-on", "controller-oc-default",
                "Enable USB controller overclock with Secure Boot"),
            new SubTweak("Xbox Game Bar", SubTweakType.Toggle, "gamebar-off", "gamebar-on",
                "Disable Xbox Game Bar and related services"),
            new SubTweak("MSI Mode", SubTweakType.Toggle, "msi-mode-on", "msi-mode-off",
                "Enable Message Signaled Interrupts for GPU"),
            new SubTweak("Unlock Background Polling Rate", SubTweakType.Toggle, "polling-unlock", "polling-default",
                "Remove background mouse polling rate cap"),
            new SubTweak("DirectX Runtime", "directx-install",
                "Install DirectX June 2010 Runtime"),
            new SubTweak("MPO / Windowed Optimizations", SubTweakType.Toggle, "mpo-on", "mpo-default",
                "Enable/disable Multi-Plane Overlay and windowed optimizations"),
        ]);

    private static Tweak BuildNetworkOptimizations() => new(
        "Network Optimizations",
        $"Network optimizations{S}Network-Optimizations.ps1",
        $"Network optimizations{S}Network-Optimizations.ps1",
        [
            new SubTweak("IPv4 Only Adapter Bindings", SubTweakType.Toggle, "adapter-ipv4only", "adapter-default",
                "Disable IPv6 and unnecessary protocols for gaming"),
            new SubTweak("Smart Network Optimization", "smart-optimize",
                "Optimize network adapters, disable throttling, power saving features"),
            new SubTweak("Smart Network Optimization (Aggressive)", "smart-optimize-aggressive",
                "Also disables Flow Control/Jumbo Frames and forces Interrupt Moderation (may increase latency or reduce throughput)"),
        ]);

    private static Tweak BuildGeneralTweaks() => new(
        "General Tweaks",
        $"General Tweaks{S}General-Tweaks.ps1",
        $"General Tweaks{S}General-Tweaks.ps1",
        [
            new SubTweak("Ultimate Power Plan", SubTweakType.Toggle, "power-plan-on", "power-plan-default",
                "Apply Ultimate Performance power plan and unpark CPU cores"),
            new SubTweak("Remove Bloatware", "bloatware-remove",
                "Uninstall UWP apps and unnecessary Windows features"),
            new SubTweak("Install Microsoft Store", "store-install",
                "Reinstall Microsoft Store"),
            new SubTweak("Disable Widgets", SubTweakType.Toggle, "widgets-disable", "widgets-enable",
                "Disable Windows 11 Widgets"),
            new SubTweak("Disable Background Apps", SubTweakType.Toggle, "background-apps-disable", "background-apps-enable",
                "Prevent apps from running in background"),
            new SubTweak("Install C++ Redistributables", "cpp-install",
                "Install Visual C++ Runtime libraries"),
            new SubTweak("Apply Registry Tweaks", "registry-apply",
                "Apply performance and privacy registry optimizations"),
            new SubTweak("125%/150% Scaling Fix", SubTweakType.Toggle, "scaling-fix", "scaling-default",
                "Disable DPI scaling acceleration"),
            new SubTweak("Disable Lock Screen", SubTweakType.Toggle, "lockscreen-disable", "lockscreen-enable",
                "Skip lock screen on sign-in"),
            new SubTweak("Clean Start Menu & Taskbar", "startmenu-clean",
                "Remove default pinned items from Start Menu and Taskbar"),
            new SubTweak("Add Start Menu Shortcuts", "shortcuts-add",
                "Add useful shortcuts to Start Menu"),
            new SubTweak("Disable Keyboard Shortcuts", SubTweakType.Toggle, "keyboard-disable", "keyboard-enable",
                "Disable Windows key shortcuts"),
            new SubTweak("Clean GPU Drivers", "driver-clean",
                "Use DDU to clean GPU drivers"),
            new SubTweak("Disable HDCP", SubTweakType.Toggle, "hdcp-disable", "hdcp-enable",
                "Disable HDCP (High-bandwidth Digital Content Protection)"),
            new SubTweak("System Cleanup", "cleanup-run",
                "Run Windows Disk Cleanup and optimize storage"),
            new SubTweak("Autoruns (Manage Startup)", "autoruns-open",
                "Open Sysinternals Autoruns to manage startup programs"),
        ]);

    private static Tweak BuildServicesManagement() => new(
        "Services Management",
        $"Services management{S}Services-Management.ps1",
        $"Services management{S}Services-Management.ps1",
        [
            new SubTweak("Disable Unnecessary Services", "services-disable",
                "Disable Windows services not needed for gaming"),
            new SubTweak("Restore Default Services", "services-restore",
                "Restore all Windows services to default state"),
        ]);

    private static Tweak BuildPrivacy() => new(
        "Privacy",
        $"Privacy Security{S}privacy.ps1",
        $"Privacy Security{S}revert-privacy.ps1",
        [
            new SubTweak("Apply OOSU10 Profile", "ooshutup-apply",
                "Apply the bundled O&O ShutUp10++ privacy/performance profile"),
            new SubTweak("Disable online content in File Explorer", SubTweakType.Toggle,
                "ui-online-content-disable", "ui-online-content-revert",
                "Disable online tips, wizards, and web services in File Explorer"),
            new SubTweak("Secure recent document lists", SubTweakType.Toggle,
                "ui-secure-recent-docs", "ui-secure-recent-docs-revert",
                "Disable recent docs history and clear recent documents on exit"),
            new SubTweak("Remove folders from This PC in File Explorer", SubTweakType.Toggle,
                "ui-remove-this-pc-folders", "ui-remove-this-pc-folders-revert",
                "Hide Desktop, Documents, Downloads, etc. from This PC (files stay on disk)"),
            new SubTweak("Disable lock screen app notifications", SubTweakType.Toggle,
                "ui-lock-screen-notifications-disable", "ui-lock-screen-notifications-revert",
                "Disable notifications shown on the lock screen"),
            new SubTweak("Disable the 'Look for an app in the Store' option", SubTweakType.Toggle,
                "ui-store-open-with-disable", "ui-store-open-with-revert",
                "Remove the Store prompt when opening unknown file types"),
            new SubTweak("Disable the display of recently used files in Quick Access", SubTweakType.Toggle,
                "ui-quick-access-recent-disable", "ui-quick-access-recent-revert",
                "Hide recent files from Quick Access"),
            new SubTweak("Disable sync provider notifications", SubTweakType.Toggle,
                "ui-sync-provider-notifications-disable", "ui-sync-provider-notifications-revert",
                "Disable OneDrive and sync provider notifications in Explorer"),
            new SubTweak("Disable hibernation", SubTweakType.Toggle,
                "ui-hibernation-disable", "ui-hibernation-revert",
                "Disable hibernation to remove hiberfil.sys and speed up shutdown"),
            new SubTweak("Enable camera on/off OSD notifications", SubTweakType.Toggle,
                "ui-camera-osd-enable", "ui-camera-osd-revert",
                "Show on-screen notifications when the camera turns on/off"),
            new SubTweak("Disable Copilot", SubTweakType.Toggle,
                "copilot-disable", "copilot-disable-revert",
                "Disable Windows Copilot AI assistant"),
            new SubTweak("Set Cloudflare DNS", "dns-cloudflare",
                "Set DNS to Cloudflare (1.1.1.1, 1.0.0.1)"),
            new SubTweak("Set Google DNS", "dns-google",
                "Set DNS to Google (8.8.8.8, 8.8.4.4)"),
            new SubTweak("Enable DNS over HTTPS (DoH)", SubTweakType.Toggle,
                "doh-enable", "doh-enable-revert",
                "Enable encrypted DNS for common DNS providers"),
        ]);

    private static Tweak BuildSecurity() => new(
        "Security",
        $"Privacy Security{S}security.ps1",
        $"Privacy Security{S}revert-security.ps1",
        [
            new SubTweak("Harden Firewall Policies", "firewall-hardening",
                "Apply baseline Windows Firewall policies (domain/private/public)"),
            new SubTweak("Improve network security", SubTweakType.Toggle,
                "security-improve-network", "security-improve-network-revert",
                "Disable SMB1/NetBIOS/legacy network components and harden remote access"),
            new SubTweak("Disable clipboard data collection", SubTweakType.Toggle,
                "security-clipboard-data-disable", "security-clipboard-data-revert",
                "Disable clipboard sync, history, and background clipboard service"),
            new SubTweak("Enable protection against Meltdown and Spectre", SubTweakType.Toggle,
                "security-spectre-meltdown-enable", "security-spectre-meltdown-revert",
                "Enable OS/Hyper-V mitigations for Spectre and Meltdown"),
            new SubTweak("Enable Data Execution Prevention (DEP)", SubTweakType.Toggle,
                "security-dep-enable", "security-dep-revert",
                "Enable DEP policy settings"),
            new SubTweak("Disable AutoPlay and AutoRun", SubTweakType.Toggle,
                "security-autorun-disable", "security-autorun-revert",
                "Disable AutoPlay/AutoRun for all drives and devices"),
            new SubTweak("Disable lock screen camera access", SubTweakType.Toggle,
                "security-lock-screen-camera-disable", "security-lock-screen-camera-revert",
                "Block camera access on the lock screen"),
            new SubTweak("Disable storage of the LAN Manager password hashes", SubTweakType.Toggle,
                "security-lm-hash-disable", "security-lm-hash-revert",
                "Prevent LM hash storage for local passwords"),
            new SubTweak("Disable \"Always install with elevated privileges\" in Windows Installer", SubTweakType.Toggle,
                "security-always-install-elevated-disable", "security-always-install-elevated-revert",
                "Prevent MSI privilege escalation (AlwaysInstallElevated)"),
            new SubTweak("Enable Structured Exception Handling Overwrite Protection (SEHOP)", SubTweakType.Toggle,
                "security-sehop-enable", "security-sehop-revert",
                "Enable SEHOP to harden process exception handling"),
            new SubTweak("Enable security against PowerShell 2.0 downgrade attacks", SubTweakType.Toggle,
                "security-ps2-downgrade-protection-enable", "security-ps2-downgrade-protection-revert",
                "Disable PowerShell 2.0 optional features"),
            new SubTweak("Disable \"Windows Connect Now\" wizard", SubTweakType.Toggle,
                "security-wcn-disable", "security-wcn-revert",
                "Disable WCN UI/registrars"),
            new SubTweak("Harden TLS/Cryptography", "tls-hardening",
                "Disable TLS 1.0/1.1 and weak ciphers, enforce modern cryptography (may break legacy apps)"),
        ]);
}
