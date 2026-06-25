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

    /// <summary>
    /// True while ANY operation (this one or another tweak) is running. Bound to
    /// button IsEnabled so Apply/Revert are disabled during other runs. Change
    /// notifications are pushed via <see cref="OnGlobalRunningChanged"/>.
    /// </summary>
    public bool IsGloballyRunning => _isGloballyRunning();

    /// <summary>
    /// True when this tweak has no unmet dependency (its prerequisite is applied on this
    /// machine). Read live from the registry; re-evaluated whenever a run completes.
    /// </summary>
    public bool RequirementMet => RegistryState.IsSatisfied(_model.Requires);
    public bool RequirementUnmet => !RequirementMet;
    public bool HasRequirement => _model.Requires != null;
    public string? RequirementMessage => _model.Requires?.UnmetMessage;

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

    /// <summary>
    /// Raises change notifications for <see cref="IsGloballyRunning"/> and the dependency
    /// state (a just-applied prerequisite may now satisfy another tweak's requirement).
    /// </summary>
    public void OnGlobalRunningChanged()
    {
        OnPropertyChanged(nameof(IsGloballyRunning));
        OnPropertyChanged(nameof(RequirementMet));
        OnPropertyChanged(nameof(RequirementUnmet));
    }

    [RelayCommand]
    private async Task ApplyAsync()
    {
        // Guard: a greyed (unmet-dependency) Apply must be a no-op even if invoked.
        if (!RequirementMet) return;
        await ExecuteActionAsync(_applyScriptPath, _model.ApplyAction, "apply");
    }

    [RelayCommand]
    private async Task RevertAsync()
    {
        var revertAction = _model.RevertAction;
        if (string.IsNullOrEmpty(revertAction)) return;
        await ExecuteActionAsync(_revertScriptPath, revertAction, "revert");
    }

    private async Task ExecuteActionAsync(string scriptPath, string action, string actionType)
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

            // Surface a non-zero exit visibly instead of letting it disappear into
            // a grey log line the user may never scroll to.
            if (result.Outcome == ScriptRunOutcome.Applied && result.ExitCode != 0)
            {
                _setError($"'{Name}' failed (exit {result.ExitCode}) — check the output panel.");
            }
        }
        finally
        {
            IsRunning = false;
            _setGloballyRunning(false);
        }
    }
}
