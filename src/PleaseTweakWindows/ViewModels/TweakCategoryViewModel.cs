using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PleaseTweakWindows.Models;
using PleaseTweakWindows.Services;

namespace PleaseTweakWindows.ViewModels;

public partial class TweakCategoryViewModel : ViewModelBase
{
    private readonly Tweak _model;
    private readonly string _scriptDirectory;
    private readonly IScriptExecutor _executor;
    private readonly IDialogService _dialogService;
    private readonly RestorePointGuard _restorePointGuard;
    private readonly LogPanelViewModel _logPanel;
    private readonly Func<bool> _isGloballyRunning;
    private readonly Action<bool> _setGloballyRunning;
    private readonly Action<string?> _setError;

    [ObservableProperty]
    private bool _isExpanded;

    public string Title => _model.Title;
    public bool CanRunAll => _model.CanRunAll;
    public ObservableCollection<SubTweakViewModel> SubTweaks { get; } = new();

    /// <summary>Indicates whether any tweak operation is running.</summary>
    public bool IsGloballyRunning => _isGloballyRunning();

    public TweakCategoryViewModel(
        Tweak model,
        string scriptDirectory,
        IScriptExecutor executor,
        IDialogService dialogService,
        RestorePointGuard restorePointGuard,
        LogPanelViewModel logPanel,
        Func<bool> isGloballyRunning,
        Action<bool> setGloballyRunning,
        Action<string?> setError)
    {
        _model = model;
        _scriptDirectory = scriptDirectory;
        _executor = executor;
        _dialogService = dialogService;
        _restorePointGuard = restorePointGuard;
        _logPanel = logPanel;
        _isGloballyRunning = isGloballyRunning;
        _setGloballyRunning = setGloballyRunning;
        _setError = setError;

        var applyPath = Path.Combine(scriptDirectory, model.ApplyScript);
        var revertPath = Path.Combine(scriptDirectory, model.RevertScript);

        foreach (var sub in model.SubTweaks)
        {
            SubTweaks.Add(new SubTweakViewModel(
                sub, applyPath, revertPath, scriptDirectory,
                executor, dialogService, restorePointGuard, logPanel,
                isGloballyRunning, setGloballyRunning, setError));
        }
    }

    /// <summary>Refreshes global running state for the category and its sub-tweaks.</summary>
    public void OnGlobalRunningChanged()
    {
        OnPropertyChanged(nameof(IsGloballyRunning));
        foreach (var sub in SubTweaks)
            sub.OnGlobalRunningChanged();
    }

    [RelayCommand]
    private void ToggleExpand()
    {
        IsExpanded = !IsExpanded;
    }

    [RelayCommand]
    private async Task RunFullScriptAsync()
    {
        if (_isGloballyRunning()) return;

        // Clear any stale error before starting a new sweep.
        _setError(null);

        var batchTweaks = _model.RunAllSubTweaks
            .Where(s => !string.IsNullOrEmpty(s.ApplyAction))
            .ToList();
        var actionableCount = batchTweaks.Count;
        var highRiskCount = batchTweaks.Count(s => _dialogService.IsHighRisk(s.ApplyAction));
        if (actionableCount == 0) return;

        var batchAction = highRiskCount > 0 ? "run-all-batch-high-risk" : "run-all-batch";
        var batchConfirmed = await _dialogService.ShowConfirmationAsync(
            batchAction,
            highRiskCount > 0
                ? $"{Title}: {actionableCount} tweaks ({highRiskCount} high-risk)"
                : $"{Title}: {actionableCount} tweaks");
        if (!batchConfirmed) return;

        // Block other actions while both the restore point and the batch run.
        _setGloballyRunning(true);
        try
        {
            // Ensure a restore point once for the whole sweep, then skip it inside the loop.
            var proceed = await _restorePointGuard.EnsureRestorePointAsync(
                _scriptDirectory,
                line => UiDispatcher.Post(() => _logPanel.AppendLine(line)),
                isHighRisk: highRiskCount > 0);
            if (!proceed)
            {
                // Surface creation failures; user cancellations are already logged.
                if (_restorePointGuard.LastStatus == RestorePointStatus.Failed)
                    _setError("Restore point creation failed — batch aborted. See the output panel.");
                return;
            }

            var scriptPath = Path.Combine(_scriptDirectory, _model.ApplyScript);
            Action<string> onOutput = line => UiDispatcher.Post(() => _logPanel.AppendLine(line));

            foreach (var sub in batchTweaks)
            {
                var action = sub.ApplyAction;

                // Leave runtime-only prerequisite checks to the scripts.
                if (!RegistryState.IsSatisfied(sub.Requires))
                {
                    onOutput($"[!] Skipped '{sub.Name}' — prerequisite not met: {sub.Requires?.UnmetMessage}");
                    continue;
                }

                // Keep per-action warnings for high-risk batch items only.
                var skipConfirm = !_dialogService.IsHighRisk(action);
                var result = await ScriptRunner.RunAsync(
                    scriptPath, action, sub.Name, _scriptDirectory,
                    _executor, _dialogService, _restorePointGuard, _logPanel,
                    ensureRestorePoint: false,
                    skipConfirmation: skipConfirm);

                // Stop the batch when an action confirmation is cancelled.
                if (result.Outcome == ScriptRunOutcome.ConfirmationCancelled)
                {
                    onOutput("[!] Batch cancelled by user — stopping remaining tweaks.");
                    break;
                }

                // User hit Stop on a running tweak — halt the sweep without flagging a failure.
                if (result.Outcome == ScriptRunOutcome.Cancelled)
                {
                    onOutput("[!] Stopped by user — remaining tweaks not applied.");
                    break;
                }

                // Stop the batch after the first script failure.
                if (result.Outcome == ScriptRunOutcome.Applied && result.ExitCode != 0)
                {
                    onOutput($"[!] '{sub.Name}' exited with code {result.ExitCode} — stopping batch.");
                    _setError($"'{sub.Name}' failed (exit {result.ExitCode}) — check the output panel.");
                    break;
                }
            }
        }
        catch (Exception ex)
        {
            UiDispatcher.Post(() => _logPanel.AppendLine($"[-] ERROR: Batch failed: {ex.Message}"));
            _setError($"'{Title}' batch could not be completed — check the output panel.");
        }
        finally
        {
            _setGloballyRunning(false);
        }
    }

    public bool MatchesFilter(string filter)
    {
        if (string.IsNullOrWhiteSpace(filter)) return true;

        if (Title.Contains(filter, StringComparison.OrdinalIgnoreCase))
            return true;

        return _model.SubTweaks.Any(s =>
            s.Name.Contains(filter, StringComparison.OrdinalIgnoreCase) ||
            (s.Description?.Contains(filter, StringComparison.OrdinalIgnoreCase) ?? false));
    }
}
