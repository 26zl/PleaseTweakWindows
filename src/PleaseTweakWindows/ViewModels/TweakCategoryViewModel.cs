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
    public ObservableCollection<SubTweakViewModel> SubTweaks { get; } = new();

    /// <summary>
    /// True while ANY operation is running. Bound to the "Run All" button's
    /// IsEnabled so it is disabled during other runs.
    /// </summary>
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

    /// <summary>
    /// Pushes a change notification for <see cref="IsGloballyRunning"/> to this
    /// category and all of its sub-tweaks so their button IsEnabled bindings update.
    /// </summary>
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

        // One batch confirmation up front instead of up to N per-action dialogs.
        // Decline = do nothing.
        var actionableCount = _model.SubTweaks.Count(s => !string.IsNullOrEmpty(s.ApplyAction));
        var highRiskCount = _model.SubTweaks.Count(s =>
            !string.IsNullOrEmpty(s.ApplyAction) && _dialogService.IsHighRisk(s.ApplyAction));
        if (actionableCount == 0) return;

        var batchAction = highRiskCount > 0 ? "run-all-batch-high-risk" : "run-all-batch";
        var batchConfirmed = await _dialogService.ShowConfirmationAsync(
            batchAction,
            highRiskCount > 0
                ? $"{Title}: {actionableCount} tweaks ({highRiskCount} high-risk)"
                : $"{Title}: {actionableCount} tweaks");
        if (!batchConfirmed) return;

        // Ensure a restore point once for the whole sweep, then skip it inside the loop.
        var proceed = await _restorePointGuard.EnsureRestorePointAsync(
            _scriptDirectory,
            line => UiDispatcher.Post(() => _logPanel.AppendLine(line)),
            isHighRisk: highRiskCount > 0);
        if (!proceed) return;

        _setGloballyRunning(true);

        try
        {
            var scriptPath = Path.Combine(_scriptDirectory, _model.ApplyScript);
            Action<string> onOutput = line => UiDispatcher.Post(() => _logPanel.AppendLine(line));

            foreach (var sub in _model.SubTweaks)
            {
                var action = sub.ApplyAction;
                if (string.IsNullOrEmpty(action)) continue;

                var result = await ScriptRunner.RunAsync(
                    scriptPath, action, sub.Name, _scriptDirectory,
                    _executor, _dialogService, _restorePointGuard, _logPanel,
                    ensureRestorePoint: false,
                    skipConfirmation: true);

                // User cancelled a confirmation dialog — stop the whole batch rather
                // than silently skipping into the next destructive tweak and leaving
                // the machine in a half-applied state.
                if (result.Outcome == ScriptRunOutcome.ConfirmationCancelled)
                {
                    onOutput("[!] Batch cancelled by user — stopping remaining tweaks.");
                    break;
                }

                // A script failed mid-batch. Continuing would apply more tweaks on top
                // of an incomplete state; bail out so the user can investigate.
                if (result.Outcome == ScriptRunOutcome.Applied && result.ExitCode != 0)
                {
                    onOutput($"[!] '{sub.Name}' exited with code {result.ExitCode} — stopping batch.");
                    _setError($"'{sub.Name}' failed (exit {result.ExitCode}) — check the output panel.");
                    break;
                }
            }
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
