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
    private readonly IRestorePointGuard _restorePointGuard;
    private readonly LogPanelViewModel _logPanel;
    private readonly Func<bool> _isGloballyRunning;
    private readonly Action<bool> _setGloballyRunning;

    [ObservableProperty]
    private bool _isRunning;

    public string Name => _model.Name;
    public string? Description => _model.Description;
    public bool HasRevert => _model.Type == SubTweakType.Toggle && _model.RevertAction != null;

    public SubTweakViewModel(
        SubTweak model,
        string applyScriptPath,
        string revertScriptPath,
        string scriptDirectory,
        IScriptExecutor executor,
        IDialogService dialogService,
        IRestorePointGuard restorePointGuard,
        LogPanelViewModel logPanel,
        Func<bool> isGloballyRunning,
        Action<bool> setGloballyRunning)
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
    }

    [RelayCommand]
    private async Task ApplyAsync()
    {
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

        IsRunning = true;
        _setGloballyRunning(true);

        try
        {
            _ = await ScriptRunner.RunAsync(
                scriptPath, action, Name, _scriptDirectory,
                _executor, _dialogService, _restorePointGuard, _logPanel);
        }
        finally
        {
            IsRunning = false;
            _setGloballyRunning(false);
        }
    }
}
