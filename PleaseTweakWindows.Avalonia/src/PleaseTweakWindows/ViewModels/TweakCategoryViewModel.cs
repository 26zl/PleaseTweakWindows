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

        foreach (var sub in model.SubTweaks)
        {
            var applyPath = Path.Combine(scriptDirectory, model.ApplyScript);
            var revertPath = Path.Combine(scriptDirectory, model.RevertScript);

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

        var proceed = await _restorePointGuard.EnsureRestorePointAsync(
            _scriptDirectory,
            line => Avalonia.Threading.Dispatcher.UIThread.Post(() => _logPanel.AppendLine(line)));
        if (!proceed) return;

        _setGloballyRunning(true);

        try
        {
            var scriptPath = Path.Combine(_scriptDirectory, _model.ApplyScript);

            foreach (var sub in _model.SubTweaks)
            {
                var action = sub.ApplyAction;
                if (string.IsNullOrEmpty(action)) continue;

                if (_dialogService.RequiresConfirmation(action))
                {
                    var confirmed = await _dialogService.ShowConfirmationAsync(action, sub.Name);
                    if (!confirmed) continue;
                }

                await _executor.RunScriptAsync(scriptPath, action,
                    line => Avalonia.Threading.Dispatcher.UIThread.Post(() => _logPanel.AppendLine(line)));
            }
        }
        finally
        {
            _setGloballyRunning(false);
        }
    }

    /// <summary>Check if category title or any sub-tweak matches the filter.</summary>
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
