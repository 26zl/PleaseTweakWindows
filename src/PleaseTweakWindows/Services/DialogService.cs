using System.Windows;
using Microsoft.Extensions.Logging;
using PleaseTweakWindows.Models;
using PleaseTweakWindows.Views.Dialogs;

namespace PleaseTweakWindows.Services;

public sealed class DialogService : IDialogService
{
    // Batch pseudo-actions and the riskier network-profile revert are not apply-side SubTweaks.
    private const string RunAllBatchWarning =
        "'{0}' will apply multiple tweaks in sequence.\n\n" +
        "The app stops on the first failed tweak so you can inspect the output before continuing.";
    private const string RunAllBatchHighRiskWarning =
        "'{0}' will apply multiple tweaks in sequence and includes high-risk changes.\n\n" +
        "Review the category contents first. These changes can affect services, networking, drivers, security policy, or app compatibility.";
    private const string NetworkAllPrivateWarning =
        "'{0}' will set every connected network profile to Private.\n\n" +
        "WARNING: This increases trust for LAN discovery and sharing. Only use on trusted home/work networks.";

    private const string GenericWarning =
        "'{0}' will make changes to your system.\n\n" +
        "Are you sure you want to proceed?";
    private const string RestoreDefaultsWarning =
        "'{0}' will restore the Windows default for this setting.\n\n" +
        "This is not an exact undo: any custom or organization-managed value that existed before PleaseTweakWindows may be overwritten. " +
        "Continue only if restoring the Windows default is what you intend.";

    // Derive confirmation and high-risk actions from the tweak model.
    private readonly HashSet<string> _destructiveActions;
    private readonly HashSet<string> _highRiskActions;
    private readonly Dictionary<string, string> _warningTemplates;

    private readonly ILogger<DialogService> _logger;

    public DialogService(ILoggerFactory loggerFactory, TweakRegistry tweakRegistry)
    {
        _logger = loggerFactory.CreateLogger<DialogService>();

        _destructiveActions = new HashSet<string>(StringComparer.Ordinal);
        _highRiskActions = new HashSet<string>(StringComparer.Ordinal);
        _warningTemplates = new Dictionary<string, string>(StringComparer.Ordinal);

        foreach (var sub in tweakRegistry.GetTweaks().SelectMany(t => t.SubTweaks))
        {
            if (sub.Risk != SubTweakRisk.None)
                _destructiveActions.Add(sub.ApplyAction);
            if (sub.Risk == SubTweakRisk.High)
                _highRiskActions.Add(sub.ApplyAction);
            if (sub.Warning != null)
                _warningTemplates[sub.ApplyAction] = sub.Warning;

            // Restore actions require explicit confirmation and inherit apply-side risk.
            if (!string.IsNullOrWhiteSpace(sub.RevertAction))
            {
                _destructiveActions.Add(sub.RevertAction);
                if (sub.Risk == SubTweakRisk.High)
                    _highRiskActions.Add(sub.RevertAction);
                _warningTemplates[sub.RevertAction] = RestoreDefaultsWarning;
            }
        }

        // Add batch actions and the high-risk network-profile revert.
        _destructiveActions.Add("run-all-batch");
        _destructiveActions.Add("run-all-batch-high-risk");
        _highRiskActions.Add("run-all-batch-high-risk");
        _destructiveActions.Add("network-all-private");
        _highRiskActions.Add("network-all-private");
        _warningTemplates["run-all-batch"] = RunAllBatchWarning;
        _warningTemplates["run-all-batch-high-risk"] = RunAllBatchHighRiskWarning;
        _warningTemplates["network-all-private"] = NetworkAllPrivateWarning;
    }

    public bool RequiresConfirmation(string action) => _destructiveActions.Contains(action);
    public bool IsHighRisk(string action) => _highRiskActions.Contains(action);

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

    public Task<IReadOnlyList<string>?> ShowConfigReviewAsync(
        IReadOnlyList<(string ActionId, string DisplayName)> items, int droppedCount)
    {
        return ShowDialogOnUiAsync<IReadOnlyList<string>?>(() =>
        {
            var reviewItems = items
                .Select(i => new ConfigReviewItem(i.ActionId, i.DisplayName))
                .ToList();
            var dialog = new ConfigReviewDialog(reviewItems, droppedCount)
            {
                Owner = GetMainWindow()
            };
            var applied = dialog.ShowDialog() == true;
            _logger.LogInformation("Config review: {Result} ({Count} selected)",
                applied ? "applied" : "cancelled", applied ? dialog.SelectedActionIds.Count : 0);
            return applied ? dialog.SelectedActionIds : null;
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

    public string GetActionWarning(string action, string actionName) =>
        _warningTemplates.TryGetValue(action, out var template)
            ? string.Format(template, actionName)
            : string.Format(GenericWarning, actionName);

    private static Task<T> ShowDialogOnUiAsync<T>(Func<T> show)
    {
        // Throw without a WPF context to avoid returning an unsafe default dialog result.
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
