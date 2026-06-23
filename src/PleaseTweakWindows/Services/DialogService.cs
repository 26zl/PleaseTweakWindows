using System.Windows;
using Microsoft.Extensions.Logging;
using PleaseTweakWindows.Views.Dialogs;

namespace PleaseTweakWindows.Services;

public sealed class DialogService : IDialogService
{
    private static readonly HashSet<string> DestructiveActions = new(StringComparer.Ordinal)
    {
        "bloatware-remove",
        "services-disable",
        "driver-clean",
        "cleanup-run",
        "registry-apply",
        "tls-hardening",
        "firewall-hardening",
        "smart-optimize-aggressive",
        "network-all-private",
        "ui-online-content-disable",
        "ui-secure-recent-docs",
        "ui-remove-this-pc-folders",
        "ui-lock-screen-notifications-disable",
        "ui-store-open-with-disable",
        "ui-quick-access-recent-disable",
        "ui-sync-provider-notifications-disable",
        "ui-hibernation-disable",
        "ui-camera-osd-enable",
        "copilot-disable",
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
        "amd-driver-install",
        "security-smb-modern-enforce",
        "security-firewall-logging-enable",
        "security-defender-cfa-enable",
        "security-defender-network-protection-enable",
        "security-defender-cloud-tune",
        "security-defender-sandbox-enable",
        "security-aslr-system-enable",
        "security-tls-cipher-order",
        "security-block-ntlm-incoming",
        "security-block-ntlm-outgoing",
        "network-all-public",
    };

    private static readonly HashSet<string> HighRiskActions = new(StringComparer.Ordinal)
    {
        "run-all-batch-high-risk",
        "services-disable",
        "driver-clean",
        "tls-hardening",
        "firewall-hardening",
        "smart-optimize-aggressive",
        "security-spectre-meltdown-enable",
        "security-improve-network",
        "security-smb-modern-enforce",
        "security-defender-cfa-enable",
        "security-block-ntlm-incoming",
        "security-block-ntlm-outgoing",
        "network-all-public",
        "network-all-private",
        "security-aslr-system-enable",
    };

    private readonly ILogger<DialogService> _logger;

    public DialogService(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<DialogService>();
    }

    public bool RequiresConfirmation(string action) => DestructiveActions.Contains(action);
    public bool IsHighRisk(string action) => HighRiskActions.Contains(action);

    public Task<bool> ShowConfirmationAsync(string action, string actionName)
    {
        var isHigh = IsHighRisk(action);
        var title = isHigh ? "High-Risk Operation" : "Confirm Action";
        var header = isHigh
            ? "This operation may cause system instability!"
            : "Are you sure you want to proceed?";
        var content = GetActionWarning(action, actionName);

        return ShowDialogOnUiAsync(() =>
        {
            var dialog = new ConfirmationDialog
            {
                DialogTitle = title,
                DialogHeader = header,
                DialogContent = content,
                ConfirmText = "Yes, Proceed",
                CancelText = "Cancel",
                IsHighRisk = isHigh,
                Owner = GetMainWindow()
            };
            var result = dialog.ShowDialog() == true && dialog.Result == "confirm";
            _logger.LogInformation("Confirmation dialog for '{Action}': {Result}", action, result ? "confirmed" : "cancelled");
            return result;
        });
    }

    public Task<RestorePointDecision> ShowRestorePointPromptAsync()
    {
        return ShowDialogOnUiAsync(() =>
        {
            var dialog = new ConfirmationDialog
            {
                DialogTitle = "Restore Point Required",
                DialogHeader = "Create a restore point before making changes?",
                DialogContent = "Best practice: create a restore point before applying tweaks.\n\n" +
                              "You can continue without one, but you may not be able to fully undo changes.",
                ConfirmText = "Create Restore Point",
                CancelText = "Cancel",
                ShowSkipButton = true,
                SkipText = "Continue Without",
                Owner = GetMainWindow()
            };
            dialog.ShowDialog();
            return dialog.Result switch
            {
                "confirm" => RestorePointDecision.Create,
                "skip" => RestorePointDecision.Skip,
                _ => RestorePointDecision.Cancel
            };
        });
    }

    public Task<bool> ShowCancelConfirmationAsync()
    {
        return ShowDialogOnUiAsync(() =>
        {
            var dialog = new ConfirmationDialog
            {
                DialogTitle = "Cancel Operation",
                DialogHeader = "Cancel running operation?",
                DialogContent = "This will forcibly terminate the running script. " +
                              "The system may be left in an inconsistent state.\n\n" +
                              "Are you sure you want to cancel?",
                ConfirmText = "Yes, Cancel",
                CancelText = "No, Continue",
                IsHighRisk = true,
                Owner = GetMainWindow()
            };
            dialog.ShowDialog();
            var result = dialog.Result == "confirm";
            _logger.LogInformation("Cancel confirmation: {Result}", result ? "user cancelled operation" : "user continued");
            return result;
        });
    }

    public string GetActionWarning(string action, string actionName) => action switch
    {
        "bloatware-remove" =>
            $"'{actionName}' will uninstall pre-installed Windows apps.\n\n" +
            "Some apps may be difficult to reinstall. Make sure you have a restore point.",
        "services-disable" =>
            $"'{actionName}' will disable Windows services.\n\n" +
            "WARNING: This may break Windows features like printing, Bluetooth, or remote desktop.\n" +
            "A system restore point is STRONGLY recommended.",
        "driver-clean" =>
            $"'{actionName}' will remove GPU drivers using DDU.\n\n" +
            "Your display may go blank temporarily. Have a new driver ready to install.",
        "cleanup-run" =>
            $"'{actionName}' will delete temporary files and caches.\n\n" +
            "This is generally safe but cannot be undone.",
        "registry-apply" =>
            $"'{actionName}' will modify Windows registry settings.\n\n" +
            "A restore point is recommended before proceeding.",
        "tls-hardening" =>
            $"'{actionName}' will disable legacy TLS/SSL protocols.\n\n" +
            "WARNING: This may break connectivity with older websites, VPNs, or enterprise systems.",
        "firewall-hardening" =>
            $"'{actionName}' will modify Windows Firewall policies.\n\n" +
            "This changes default inbound/outbound rules for all profiles. " +
            "Some applications may be blocked.",
        "security-improve-network" =>
            $"'{actionName}' will harden SMB/NetBIOS and disable legacy network components.\n\n" +
            "WARNING: This may break file sharing, remote access, or older devices on your network.",
        "security-spectre-meltdown-enable" =>
            $"'{actionName}' will enable Spectre/Meltdown CPU mitigations.\n\n" +
            "WARNING: This may reduce CPU performance by 5-30% depending on workload.",
        "security-clipboard-data-disable" =>
            $"'{actionName}' will disable clipboard sync and history.\n\n" +
            "Clipboard sync across devices and history will stop working.",
        "security-ps2-downgrade-protection-enable" =>
            $"'{actionName}' will disable PowerShell 2.0 optional features.\n\n" +
            "Legacy scripts requiring PowerShell 2.0 may stop working.",
        "smart-optimize-aggressive" =>
            $"'{actionName}' applies aggressive network adapter changes.\n\n" +
            "It may disable Flow Control/Jumbo Frames and force Interrupt Moderation.\n" +
            "This can reduce throughput on some LANs or increase latency.",
        "run-all-batch" =>
            $"'{actionName}' will apply multiple tweaks in sequence.\n\n" +
            "The app stops on the first failed tweak so you can inspect the output before continuing.",
        "run-all-batch-high-risk" =>
            $"'{actionName}' will apply multiple tweaks in sequence and includes high-risk changes.\n\n" +
            "Review the category contents first. These changes can affect services, networking, drivers, security policy, or app compatibility.",
        "copilot-disable" =>
            $"'{actionName}' will disable Windows Copilot.\n\n" +
            "This removes the Copilot app and sets group policy to prevent it from running.",
        "ui-remove-this-pc-folders" =>
            $"'{actionName}' will hide standard folders from This PC.\n\n" +
            "The folders remain on disk, but Explorer shortcuts will be hidden.",
        "ui-hibernation-disable" =>
            $"'{actionName}' will disable hibernation.\n\n" +
            "This removes hiberfil.sys and may affect Fast Startup and sleep behavior.",
        "amd-driver-install" =>
            "AMD's driver download page will open in your browser.\n\n" +
            "Click 'Download Windows Drivers' on the AMD page to get the latest Auto-Detect installer.\n" +
            "The installer will detect your GPU and download the correct driver.",
        "security-smb-modern-enforce" =>
            $"'{actionName}' will enforce SMB 3.1.1 minimum and require server-side encryption.\n\n" +
            "WARNING: May break connectivity to older file servers (SMB 2.x/3.0) including some NAS devices and printers.",
        "security-firewall-logging-enable" =>
            $"'{actionName}' will write firewall logs to %SystemRoot%\\System32\\LogFiles\\Firewall\\pfirewall.log (up to 32 MB per profile).\n\n" +
            "Safe change — useful for forensics. Revert restores defaults.",
        "security-defender-cfa-enable" =>
            $"'{actionName}' will enable Defender Controlled Folder Access.\n\n" +
            "WARNING: Some apps (games, sync tools, backup software) may be blocked from writing to protected folders. " +
            "You can whitelist apps via Windows Security > Virus & threat protection > Ransomware protection.",
        "security-defender-network-protection-enable" =>
            $"'{actionName}' will enable Defender Network Protection.\n\n" +
            "Blocks connections to known malicious IPs and domains. Occasionally flags legitimate sites — check event log if something breaks.",
        "security-defender-cloud-tune" =>
            $"'{actionName}' will set Defender cloud protection to maximum aggressiveness.\n\n" +
            "MAPS Advanced reporting + Cloud Block Level High + Block At First Sight. " +
            "Requires internet connectivity for real-time cloud lookups; may slow first-run of unsigned apps.",
        "security-defender-sandbox-enable" =>
            $"'{actionName}' will run Defender Antivirus inside a sandbox.\n\n" +
            "REQUIRES REBOOT to take effect. Tamper-resistant but may increase CPU overhead slightly.",
        "security-aslr-system-enable" =>
            $"'{actionName}' will enable system-wide Mandatory ASLR (ForceRelocateImages).\n\n" +
            "WARNING: May break older apps that were not compiled with /DYNAMICBASE. " +
            "Known incompatibilities: GitHub Desktop, Git Bash, MSYS2 — enable the 'Exclude dev tools' tweak after this if you use them.",
        "security-tls-cipher-order" =>
            $"'{actionName}' will set the system-wide TLS cipher suite and ECC curve order.\n\n" +
            "Prefers TLS 1.3 suites and AES-256-GCM. Mostly safe but may affect apps that hardcoded specific cipher orders.",
        "security-block-ntlm-incoming" =>
            $"'{actionName}' will DENY all incoming NTLM authentication to this machine.\n\n" +
            "SEVERE: Breaks SMB file shares, RDP, Hyper-V, MMC snap-ins, and any service that uses NTLM to authenticate AGAINST this machine. " +
            "Only suitable for isolated Privileged Access Workstations.",
        "security-block-ntlm-outgoing" =>
            $"'{actionName}' will DENY all outgoing NTLM authentication from this machine.\n\n" +
            "SEVERE: Breaks authentication to legacy servers, some network printers, and SMB shares that don't support Kerberos. " +
            "Only suitable for isolated Privileged Access Workstations.",
        "network-all-public" =>
            $"'{actionName}' will set every connected network profile to Public.\n\n" +
            "WARNING: Breaks local file sharing, printer discovery, mDNS/Bonjour, network discovery, and Cast-to-Device on your LAN. " +
            "Only appropriate for coffee-shop / untrusted networks.",
        "network-all-private" =>
            $"'{actionName}' will set every connected network profile to Private.\n\n" +
            "WARNING: This increases trust for LAN discovery and sharing. Only use on trusted home/work networks.",
        _ =>
            $"'{actionName}' will make changes to your system.\n\n" +
            "Are you sure you want to proceed?"
    };

    private static Task<T> ShowDialogOnUiAsync<T>(Func<T> show)
    {
        // Fail fast rather than return default(T). Returning default silently would map
        // RestorePointDecision to Create (the first enum value) and cause destructive
        // tweaks to proceed as if the user had approved a restore point.
        var app = System.Windows.Application.Current
            ?? throw new InvalidOperationException(
                "DialogService called with no WPF Application context. This helper requires an active UI dispatcher.");
        if (app.Dispatcher.CheckAccess())
            return Task.FromResult(show());
        return app.Dispatcher.InvokeAsync(show).Task;
    }

    private static Window? GetMainWindow()
    {
        return System.Windows.Application.Current?.MainWindow;
    }
}
