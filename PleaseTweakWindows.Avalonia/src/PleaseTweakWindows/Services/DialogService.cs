using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
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
    };

    private static readonly HashSet<string> HighRiskActions = new(StringComparer.Ordinal)
    {
        "services-disable",
        "driver-clean",
        "tls-hardening",
        "firewall-hardening",
        "security-spectre-meltdown-enable",
        "security-improve-network",
    };

    private readonly ILogger<DialogService> _logger;

    public DialogService(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<DialogService>();
    }

    public bool RequiresConfirmation(string action) => DestructiveActions.Contains(action);
    public bool IsHighRisk(string action) => HighRiskActions.Contains(action);

    public async Task<bool> ShowConfirmationAsync(string action, string actionName)
    {
        var isHigh = IsHighRisk(action);
        var title = isHigh ? "High-Risk Operation" : "Confirm Action";
        var header = isHigh
            ? "This operation may cause system instability!"
            : "Are you sure you want to proceed?";
        var content = GetActionWarning(action, actionName);

        var dialog = new ConfirmationDialog
        {
            DialogTitle = title,
            DialogHeader = header,
            DialogContent = content,
            ConfirmText = "Yes, Proceed",
            CancelText = "Cancel",
            IsHighRisk = isHigh
        };

        var result = await ShowDialogAsync(dialog);
        _logger.LogInformation("Confirmation dialog for '{Action}': {Result}", action, result ? "confirmed" : "cancelled");
        return result;
    }

    public async Task<RestorePointDecision> ShowRestorePointPromptAsync()
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
            SkipText = "Continue Without"
        };

        var owner = GetMainWindow();
        if (owner == null) return RestorePointDecision.Cancel;

        dialog.WindowStartupLocation = WindowStartupLocation.CenterOwner;
        var result = await dialog.ShowDialog<string?>(owner);

        return result switch
        {
            "confirm" => RestorePointDecision.Create,
            "skip" => RestorePointDecision.Skip,
            _ => RestorePointDecision.Cancel
        };
    }

    public async Task<bool> ShowCancelConfirmationAsync()
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
            IsHighRisk = true
        };

        var result = await ShowDialogAsync(dialog);
        _logger.LogInformation("Cancel confirmation: {Result}", result ? "user cancelled operation" : "user continued");
        return result;
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
        _ =>
            $"'{actionName}' will make changes to your system.\n\n" +
            "Are you sure you want to proceed?"
    };

    private static async Task<bool> ShowDialogAsync(ConfirmationDialog dialog)
    {
        var owner = GetMainWindow();
        if (owner == null) return false;

        dialog.WindowStartupLocation = WindowStartupLocation.CenterOwner;
        var result = await dialog.ShowDialog<string?>(owner);
        return result == "confirm";
    }

    private static Window? GetMainWindow()
    {
        if (Application.Current?.ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
            return desktop.MainWindow;
        return null;
    }
}
