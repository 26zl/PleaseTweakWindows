package com.zl.pleasetweakwindows;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

public class TweakController {
    private final List<Tweak> tweaks = new ArrayList<>();

    public void addTweak(Tweak tweak) {
        tweaks.add(tweak);
    }

    public List<Tweak> getTweaks() {
        return tweaks;
    }

    public void loadTweaks() {
        loadGamingOptimizations();
        loadNetworkOptimizations();
        loadGeneralTweaks();
        loadServicesManagement();
        loadPrivacySecurity();
    }

    private void loadGamingOptimizations() {
        Tweak gaming = new Tweak("Gaming Optimizations",
                "Gaming optimizations" + File.separator + "Gaming-Optimizations.ps1",
                "Gaming optimizations" + File.separator + "Gaming-Optimizations.ps1");

        gaming.addSubTweak(new SubTweak("Nvidia Settings", SubTweak.SubTweakType.TOGGLE,
                "nvidia-settings-on", "nvidia-settings-default",
                "Optimize NVIDIA control panel settings for gaming performance"));

        gaming.addSubTweak(new SubTweak("AMD Driver",
                "amd-driver-install",
                "Install optimized AMD driver"));

        gaming.addSubTweak(new SubTweak("Nvidia Driver",
                "nvidia-driver-install",
                "Install/update NVIDIA driver or NvCleanInstall"));

        gaming.addSubTweak(new SubTweak("P0 State Nvidia", SubTweak.SubTweakType.TOGGLE,
                "p0-state-on", "p0-state-default",
                "Force maximum GPU performance state (disable dynamic P-states)"));

        gaming.addSubTweak(new SubTweak("ULPS AMD", SubTweak.SubTweakType.TOGGLE,
                "ulps-disable", "ulps-enable",
                "Disable Ultra Low Power State for AMD GPUs"));

        gaming.addSubTweak(new SubTweak("Controller Overclock", SubTweak.SubTweakType.TOGGLE,
                "controller-oc-on", "controller-oc-default",
                "Enable USB controller overclock with Secure Boot"));

        gaming.addSubTweak(new SubTweak("Fullscreen Mode", SubTweak.SubTweakType.TOGGLE,
                "fse-on", "fso-on",
                "Choose between FSE (Exclusive) or FSO (Optimizations)",
                "FSE", "FSO"));

        gaming.addSubTweak(new SubTweak("Xbox Game Bar", SubTweak.SubTweakType.TOGGLE,
                "gamebar-off", "gamebar-on",
                "Disable Xbox Game Bar and related services"));

        gaming.addSubTweak(new SubTweak("MSI Mode", SubTweak.SubTweakType.TOGGLE,
                "msi-mode-on", "msi-mode-off",
                "Enable Message Signaled Interrupts for GPU"));

        gaming.addSubTweak(new SubTweak("Unlock Background Polling Rate", SubTweak.SubTweakType.TOGGLE,
                "polling-unlock", "polling-default",
                "Remove background mouse polling rate cap"));

        gaming.addSubTweak(new SubTweak("DirectX Runtime",
                "directx-install",
                "Install DirectX June 2010 Runtime"));

        gaming.addSubTweak(new SubTweak("MPO / Windowed Optimizations", SubTweak.SubTweakType.TOGGLE,
                "mpo-on", "mpo-default",
                "Enable/disable Multi-Plane Overlay and windowed optimizations"));

        addTweak(gaming);
    }

    private void loadNetworkOptimizations() {
        Tweak network = new Tweak("Network Optimizations",
                "Network optimizations" + File.separator + "Network-Optimizations.ps1",
                "Network optimizations" + File.separator + "Network-Optimizations.ps1");

        network.addSubTweak(new SubTweak("IPv4 Only Adapter Bindings", SubTweak.SubTweakType.TOGGLE,
                "adapter-ipv4only", "adapter-default",
                "Disable IPv6 and unnecessary protocols for gaming"));

        network.addSubTweak(new SubTweak("Smart Network Optimization",
                "smart-optimize",
                "Optimize network adapters, disable throttling, power saving features"));

        network.addSubTweak(new SubTweak("Smart Network Optimization (Aggressive)",
                "smart-optimize-aggressive",
                "Also disables Flow Control/Jumbo Frames and forces Interrupt Moderation (may increase latency or reduce throughput)"));

        addTweak(network);
    }

    private void loadGeneralTweaks() {
        Tweak general = new Tweak("General Tweaks",
                "General Tweaks" + File.separator + "General-Tweaks.ps1",
                "General Tweaks" + File.separator + "General-Tweaks.ps1");

        general.addSubTweak(new SubTweak("Ultimate Power Plan", SubTweak.SubTweakType.TOGGLE,
                "power-plan-on", "power-plan-default",
                "Apply Ultimate Performance power plan and unpark CPU cores"));

        general.addSubTweak(new SubTweak("Remove Bloatware",
                "bloatware-remove",
                "Uninstall UWP apps and unnecessary Windows features"));

        general.addSubTweak(new SubTweak("Install Microsoft Store",
                "store-install",
                "Reinstall Microsoft Store"));

        general.addSubTweak(new SubTweak("Disable Widgets", SubTweak.SubTweakType.TOGGLE,
                "widgets-disable", "widgets-enable",
                "Disable Windows 11 Widgets"));

        general.addSubTweak(new SubTweak("Disable Background Apps", SubTweak.SubTweakType.TOGGLE,
                "background-apps-disable", "background-apps-enable",
                "Prevent apps from running in background"));

        general.addSubTweak(new SubTweak("Install C++ Redistributables",
                "cpp-install",
                "Install Visual C++ Runtime libraries"));

        general.addSubTweak(new SubTweak("Apply Registry Tweaks",
                "registry-apply",
                "Apply performance and privacy registry optimizations"));

        general.addSubTweak(new SubTweak("125%/150% Scaling Fix", SubTweak.SubTweakType.TOGGLE,
                "scaling-fix", "scaling-default",
                "Disable DPI scaling acceleration"));

        general.addSubTweak(new SubTweak("Disable Lock Screen", SubTweak.SubTweakType.TOGGLE,
                "lockscreen-disable", "lockscreen-enable",
                "Skip lock screen on sign-in"));

        general.addSubTweak(new SubTweak("Clean Start Menu & Taskbar",
                "startmenu-clean",
                "Remove default pinned items from Start Menu and Taskbar"));

        general.addSubTweak(new SubTweak("Add Start Menu Shortcuts",
                "shortcuts-add",
                "Add useful shortcuts to Start Menu"));

        general.addSubTweak(new SubTweak("Disable Keyboard Shortcuts", SubTweak.SubTweakType.TOGGLE,
                "keyboard-disable", "keyboard-enable",
                "Disable Windows key shortcuts"));

        general.addSubTweak(new SubTweak("Clean GPU Drivers",
                "driver-clean",
                "Use DDU to clean GPU drivers"));

        general.addSubTweak(new SubTweak("Disable HDCP", SubTweak.SubTweakType.TOGGLE,
                "hdcp-disable", "hdcp-enable",
                "Disable HDCP (High-bandwidth Digital Content Protection)"));

        general.addSubTweak(new SubTweak("System Cleanup",
                "cleanup-run",
                "Run Windows Disk Cleanup and optimize storage"));

        general.addSubTweak(new SubTweak("Autoruns (Manage Startup)",
                "autoruns-open",
                "Open Sysinternals Autoruns to manage startup programs"));

        addTweak(general);
    }

    private void loadServicesManagement() {
        Tweak services = new Tweak("Services Management",
                "Services management" + File.separator + "Services-Management.ps1",
                "Services management" + File.separator + "Services-Management.ps1");

        services.addSubTweak(new SubTweak("Disable Unnecessary Services",
                "services-disable",
                "Disable Windows services not needed for gaming"));

        services.addSubTweak(new SubTweak("Restore Default Services",
                "services-restore",
                "Restore all Windows services to default state"));

        addTweak(services);
    }

    private void loadPrivacySecurity() {
        Tweak privacy = new Tweak("Privacy",
                "Privacy Security" + File.separator + "privacy.ps1",
                "Privacy Security" + File.separator + "revert-privacy.ps1");

        privacy.addSubTweak(new SubTweak("Apply OOSU10 Profile",
                "ooshutup-apply",
                "Apply the bundled O&O ShutUp10++ privacy/performance profile"));

        privacy.addSubTweak(new SubTweak("Disable online content in File Explorer", SubTweak.SubTweakType.TOGGLE,
                "ui-online-content-disable", "ui-online-content-revert",
                "Disable online tips, wizards, and web services in File Explorer"));

        privacy.addSubTweak(new SubTweak("Secure recent document lists", SubTweak.SubTweakType.TOGGLE,
                "ui-secure-recent-docs", "ui-secure-recent-docs-revert",
                "Disable recent docs history and clear recent documents on exit"));

        privacy.addSubTweak(new SubTweak("Remove folders from This PC in File Explorer", SubTweak.SubTweakType.TOGGLE,
                "ui-remove-this-pc-folders", "ui-remove-this-pc-folders-revert",
                "Hide Desktop, Documents, Downloads, etc. from This PC (files stay on disk)"));

        privacy.addSubTweak(new SubTweak("Disable lock screen app notifications", SubTweak.SubTweakType.TOGGLE,
                "ui-lock-screen-notifications-disable", "ui-lock-screen-notifications-revert",
                "Disable notifications shown on the lock screen"));

        privacy.addSubTweak(new SubTweak("Disable Live Tiles push notifications", SubTweak.SubTweakType.TOGGLE,
                "ui-live-tiles-disable", "ui-live-tiles-revert",
                "Disable Live Tiles push notifications"));

        privacy.addSubTweak(new SubTweak("Disable the 'Look for an app in the Store' option", SubTweak.SubTweakType.TOGGLE,
                "ui-store-open-with-disable", "ui-store-open-with-revert",
                "Remove the Store prompt when opening unknown file types"));

        privacy.addSubTweak(new SubTweak("Disable the display of recently used files in Quick Access", SubTweak.SubTweakType.TOGGLE,
                "ui-quick-access-recent-disable", "ui-quick-access-recent-revert",
                "Hide recent files from Quick Access"));

        privacy.addSubTweak(new SubTweak("Disable sync provider notifications", SubTweak.SubTweakType.TOGGLE,
                "ui-sync-provider-notifications-disable", "ui-sync-provider-notifications-revert",
                "Disable OneDrive and sync provider notifications in Explorer"));

        privacy.addSubTweak(new SubTweak("Disable hibernation", SubTweak.SubTweakType.TOGGLE,
                "ui-hibernation-disable", "ui-hibernation-revert",
                "Disable hibernation to remove hiberfil.sys and speed up shutdown"));

        privacy.addSubTweak(new SubTweak("Enable camera on/off OSD notifications", SubTweak.SubTweakType.TOGGLE,
                "ui-camera-osd-enable", "ui-camera-osd-revert",
                "Show on-screen notifications when the camera turns on/off"));

        privacy.addSubTweak(new SubTweak("Disable app usage tracking", SubTweak.SubTweakType.TOGGLE,
                "ui-app-usage-tracking-disable", "ui-app-usage-tracking-revert",
                "Disable app usage tracking (MFU)"));

        privacy.addSubTweak(new SubTweak("Disable recent apps", SubTweak.SubTweakType.TOGGLE,
                "ui-recent-apps-disable", "ui-recent-apps-revert",
                "Disable recently used apps list"));

        privacy.addSubTweak(new SubTweak("Disable backtracking", SubTweak.SubTweakType.TOGGLE,
                "ui-backtracking-disable", "ui-backtracking-revert",
                "Disable backtracking navigation history"));

        privacy.addSubTweak(new SubTweak("Disable Copilot",
                "copilot-disable",
                "Disable Windows Copilot AI assistant"));

        privacy.addSubTweak(new SubTweak("Set Cloudflare DNS",
                "dns-cloudflare",
                "Set DNS to Cloudflare (1.1.1.1, 1.0.0.1)"));

        privacy.addSubTweak(new SubTweak("Set Google DNS",
                "dns-google",
                "Set DNS to Google (8.8.8.8, 8.8.4.4)"));

        privacy.addSubTweak(new SubTweak("Enable DNS over HTTPS (DoH)",
                "doh-enable",
                "Enable encrypted DNS for common DNS providers"));

        addTweak(privacy);

        Tweak security = new Tweak("Security",
                "Privacy Security" + File.separator + "security.ps1",
                "Privacy Security" + File.separator + "revert-security.ps1");

        security.addSubTweak(new SubTweak("Harden Firewall Policies",
                "firewall-hardening",
                "Apply baseline Windows Firewall policies (domain/private/public)"));

        security.addSubTweak(new SubTweak("Improve network security", SubTweak.SubTweakType.TOGGLE,
                "security-improve-network", "security-improve-network-revert",
                "Disable SMB1/NetBIOS/legacy network components and harden remote access"));

        security.addSubTweak(new SubTweak("Disable clipboard data collection", SubTweak.SubTweakType.TOGGLE,
                "security-clipboard-data-disable", "security-clipboard-data-revert",
                "Disable clipboard sync, history, and background clipboard service"));

        security.addSubTweak(new SubTweak("Enable protection against Meltdown and Spectre", SubTweak.SubTweakType.TOGGLE,
                "security-spectre-meltdown-enable", "security-spectre-meltdown-revert",
                "Enable OS/Hyper-V mitigations for Spectre and Meltdown"));

        security.addSubTweak(new SubTweak("Enable Data Execution Prevention (DEP)", SubTweak.SubTweakType.TOGGLE,
                "security-dep-enable", "security-dep-revert",
                "Enable DEP policy settings"));

        security.addSubTweak(new SubTweak("Disable AutoPlay and AutoRun", SubTweak.SubTweakType.TOGGLE,
                "security-autorun-disable", "security-autorun-revert",
                "Disable AutoPlay/AutoRun for all drives and devices"));

        security.addSubTweak(new SubTweak("Disable lock screen camera access", SubTweak.SubTweakType.TOGGLE,
                "security-lock-screen-camera-disable", "security-lock-screen-camera-revert",
                "Block camera access on the lock screen"));

        security.addSubTweak(new SubTweak("Disable storage of the LAN Manager password hashes", SubTweak.SubTweakType.TOGGLE,
                "security-lm-hash-disable", "security-lm-hash-revert",
                "Prevent LM hash storage for local passwords"));

        security.addSubTweak(new SubTweak("Disable \"Always install with elevated privileges\" in Windows Installer",
                SubTweak.SubTweakType.TOGGLE,
                "security-always-install-elevated-disable", "security-always-install-elevated-revert",
                "Prevent MSI privilege escalation (AlwaysInstallElevated)"));

        security.addSubTweak(new SubTweak("Enable Structured Exception Handling Overwrite Protection (SEHOP)",
                SubTweak.SubTweakType.TOGGLE,
                "security-sehop-enable", "security-sehop-revert",
                "Enable SEHOP to harden process exception handling"));

        security.addSubTweak(new SubTweak("Enable security against PowerShell 2.0 downgrade attacks",
                SubTweak.SubTweakType.TOGGLE,
                "security-ps2-downgrade-protection-enable", "security-ps2-downgrade-protection-revert",
                "Disable PowerShell 2.0 optional features"));

        security.addSubTweak(new SubTweak("Disable \"Windows Connect Now\" wizard", SubTweak.SubTweakType.TOGGLE,
                "security-wcn-disable", "security-wcn-revert",
                "Disable WCN UI/registrars"));

        security.addSubTweak(new SubTweak("Harden TLS/Cryptography",
                "tls-hardening",
                "Disable TLS 1.0/1.1 and weak ciphers, enforce modern cryptography (may break legacy apps)"));

        addTweak(security);
    }
}