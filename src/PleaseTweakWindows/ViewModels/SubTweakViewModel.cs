using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PleaseTweakWindows.Models;
using PleaseTweakWindows.Services;

namespace PleaseTweakWindows.ViewModels;

public partial class SubTweakViewModel : ViewModelBase
{
    private readonly SubTweak _model;
    private readonly string _applyScriptPath;
    private readonly string _revertScriptPath;
    private readonly string _scriptDirectory;
    private readonly IScriptExecutor _executor;
    private readonly IDialogService _dialogService;
    private readonly RestorePointGuard _restorePointGuard;
    private readonly LogPanelViewModel _logPanel;
    private readonly Func<bool> _isGloballyRunning;
    private readonly Action<bool> _setGloballyRunning;
    private readonly Action<string?> _setError;

    [ObservableProperty]
    private bool _isRunning;

    public string Name => _model.Name;
    public string? Description => _model.Description;
    public bool HasRevert => _model.Type == SubTweakType.Toggle && _model.RevertAction != null;

    /// <summary>Indicates whether any tweak operation is running.</summary>
    public bool IsGloballyRunning => _isGloballyRunning();

    /// <summary>Indicates whether this tweak's live dependency is met.</summary>
    public bool RequirementMet => RegistryState.IsSatisfied(_model.Requires);
    public bool RequirementUnmet => !RequirementMet;
    public bool HasRequirement => _model.Requires != null;

    // Show the dependency tooltip only while Apply is disabled.
    public string? RequirementMessage => RequirementUnmet ? _model.Requires?.UnmetMessage : null;

    public SubTweakViewModel(
        SubTweak model,
        string applyScriptPath,
        string revertScriptPath,
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
        _applyScriptPath = applyScriptPath;
        _revertScriptPath = revertScriptPath;
        _scriptDirectory = scriptDirectory;
        _executor = executor;
        _dialogService = dialogService;
        _restorePointGuard = restorePointGuard;
        _logPanel = logPanel;
        _isGloballyRunning = isGloballyRunning;
        _setGloballyRunning = setGloballyRunning;
        _setError = setError;
    }

    /// <summary>Refreshes global-running and dependency state.</summary>
    public void OnGlobalRunningChanged()
    {
        OnPropertyChanged(nameof(IsGloballyRunning));
        OnPropertyChanged(nameof(RequirementMet));
        OnPropertyChanged(nameof(RequirementUnmet));
        OnPropertyChanged(nameof(RequirementMessage));
    }

    [RelayCommand]
    private async Task ApplyAsync()
    {
        // Guard: a greyed (unmet-dependency) Apply must be a no-op even if invoked.
        if (!RequirementMet) return;
        await ExecuteActionAsync(_applyScriptPath, _model.ApplyAction);
    }

    [RelayCommand]
    private async Task RevertAsync()
    {
        var revertAction = _model.RevertAction;
        if (string.IsNullOrEmpty(revertAction)) return;
        await ExecuteActionAsync(_revertScriptPath, revertAction);
    }

    private async Task ExecuteActionAsync(string scriptPath, string action)
    {
        if (_isGloballyRunning()) return;

        // Clear any stale error from a previous run before starting a new one.
        _setError(null);

        IsRunning = true;
        _setGloballyRunning(true);

        try
        {
            var result = await ScriptRunner.RunAsync(
                scriptPath, action, Name, _scriptDirectory,
                _executor, _dialogService, _restorePointGuard, _logPanel);

            // Show script failures in the banner while leaving cancellations silent.
            if (result.Outcome == ScriptRunOutcome.Applied && result.ExitCode != 0)
            {
                _setError($"'{Name}' failed (exit {result.ExitCode}) — check the output panel.");
            }
            else if (result.Outcome == ScriptRunOutcome.RestorePointFailed)
            {
                _setError($"Restore point creation failed — '{Name}' was not applied. See the output panel.");
            }
        }
        catch (Exception ex)
        {
            UiDispatcher.Post(() => _logPanel.AppendLine($"[-] ERROR: {ex.Message}"));
            _setError($"'{Name}' could not be completed — check the output panel.");
        }
        finally
        {
            IsRunning = false;
            _setGloballyRunning(false);
        }
    }
}
