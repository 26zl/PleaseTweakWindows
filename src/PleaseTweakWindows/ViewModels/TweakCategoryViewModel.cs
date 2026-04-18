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
    private readonly IRestorePointGuard _restorePointGuard;
    private readonly LogPanelViewModel _logPanel;
    private readonly Func<bool> _isGloballyRunning;
    private readonly Action<bool> _setGloballyRunning;

    [ObservableProperty]
    private bool _isExpanded;

    public string Title => _model.Title;
    public ObservableCollection<SubTweakViewModel> SubTweaks { get; } = new();

    public TweakCategoryViewModel(
        Tweak model,
        string scriptDirectory,
        IScriptExecutor executor,
        IDialogService dialogService,
        IRestorePointGuard restorePointGuard,
        LogPanelViewModel logPanel,
        Func<bool> isGloballyRunning,
        Action<bool> setGloballyRunning)
    {
        _model = model;
        _scriptDirectory = scriptDirectory;
        _executor = executor;
        _dialogService = dialogService;
        _restorePointGuard = restorePointGuard;
        _logPanel = logPanel;
        _isGloballyRunning = isGloballyRunning;
        _setGloballyRunning = setGloballyRunning;

        var applyPath = Path.Combine(scriptDirectory, model.ApplyScript);
        var revertPath = Path.Combine(scriptDirectory, model.RevertScript);

        foreach (var sub in model.SubTweaks)
        {
            SubTweaks.Add(new SubTweakViewModel(
                sub, applyPath, revertPath, scriptDirectory,
                executor, dialogService, restorePointGuard, logPanel,
                isGloballyRunning, setGloballyRunning));
        }
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

        // Ensure a restore point once for the whole sweep, then skip it inside the loop.
        var proceed = await _restorePointGuard.EnsureRestorePointAsync(
            _scriptDirectory,
            line => UiDispatcher.Post(() => _logPanel.AppendLine(line)));
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
                    ensureRestorePoint: false);

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
