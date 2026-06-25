using System.Collections.ObjectModel;
using System.Diagnostics;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Extensions.Logging;
using PleaseTweakWindows.Models;
using PleaseTweakWindows.Services;

namespace PleaseTweakWindows.ViewModels;

public partial class MainWindowViewModel : ViewModelBase
{
    private readonly TweakRegistry _tweakRegistry;
    private readonly IScriptExecutor _executor;
    private readonly IDialogService _dialogService;
    private readonly RestorePointGuard _restorePointGuard;
    private readonly ResourceExtractor _resourceExtractor;
    private readonly UpdateChecker _updateChecker;
    private readonly ConfigProfileService _configProfileService;
    private readonly AdminChecker _adminChecker;
    private readonly ILogger<MainWindowViewModel> _logger;

    private string? _scriptDirectory;

    [ObservableProperty]
    private bool _isScriptsRunning;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(FilteredCategories))]
    [NotifyPropertyChangedFor(nameof(HasNoResults))]
    private string _searchText = string.Empty;

    [ObservableProperty]
    private bool _showUpdateBanner;

    [ObservableProperty]
    private string _updateVersion = string.Empty;

    [ObservableProperty]
    private string _updateUrl = string.Empty;

    [ObservableProperty]
    private string? _errorMessage;

    [ObservableProperty]
    private bool _isInitialized;

    public LogPanelViewModel LogPanel { get; }
    public ObservableCollection<TweakCategoryViewModel> Categories { get; } = new();

    public IEnumerable<TweakCategoryViewModel> FilteredCategories =>
        string.IsNullOrWhiteSpace(SearchText)
            ? Categories
            : Categories.Where(c => c.MatchesFilter(SearchText));

    public bool HasNoResults => IsInitialized && !FilteredCategories.Any();

    // When the global running flag flips, push change notifications down to every
    // category/sub-tweak so their Apply/Revert/Run All IsEnabled bindings update.
    partial void OnIsScriptsRunningChanged(bool value)
    {
        foreach (var cat in Categories)
            cat.OnGlobalRunningChanged();
    }

    // Keep the empty-state ("No matches") visibility in sync with both inputs.
    partial void OnIsInitializedChanged(bool value) => OnPropertyChanged(nameof(HasNoResults));

    public MainWindowViewModel(
        TweakRegistry tweakRegistry,
        IScriptExecutor executor,
        IDialogService dialogService,
        RestorePointGuard restorePointGuard,
        ResourceExtractor resourceExtractor,
        UpdateChecker updateChecker,
        ConfigProfileService configProfileService,
        AdminChecker adminChecker,
        ILoggerFactory loggerFactory)
    {
        _tweakRegistry = tweakRegistry;
        _executor = executor;
        _dialogService = dialogService;
        _restorePointGuard = restorePointGuard;
        _resourceExtractor = resourceExtractor;
        _updateChecker = updateChecker;
        _configProfileService = configProfileService;
        _adminChecker = adminChecker;
        _logger = loggerFactory.CreateLogger<MainWindowViewModel>();
        LogPanel = new LogPanelViewModel();
    }

    public async Task InitializeAsync()
    {
        try
        {
            if (!_adminChecker.IsRunningAsAdministrator())
            {
                ErrorMessage = "PleaseTweakWindows requires Administrator privileges.\nPlease right-click the application and select \"Run as administrator\".";
                _logger.LogError("Application must be run as Administrator.");
                return;
            }

            if (!IScriptExecutor.IsPowerShellAvailable())
            {
                ErrorMessage = "Windows PowerShell 5.1 is required but was not found.";
                _logger.LogError("PowerShell 5.1 not found.");
                return;
            }

            try
            {
                _scriptDirectory = _resourceExtractor.PrepareScriptsPath();
                _executor.SetScriptsBaseDir(_scriptDirectory);
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Failed to extract scripts: {ex.Message}";
                _logger.LogError(ex, "Failed to extract scripts");
                return;
            }

            foreach (var tweak in _tweakRegistry.GetTweaks())
            {
                Categories.Add(new TweakCategoryViewModel(
                    tweak, _scriptDirectory, _executor, _dialogService,
                    _restorePointGuard, LogPanel,
                    () => IsScriptsRunning,
                    running => IsScriptsRunning = running,
                    message => UiDispatcher.Post(() => ErrorMessage = message)));
            }

            IsInitialized = true;
            _logger.LogInformation("UI initialized with {Count} categories.", Categories.Count);

            await CheckForUpdatesAsync();
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Initialization failed: {ex.Message}";
            _logger.LogError(ex, "Unhandled exception during InitializeAsync");
        }
    }

    [RelayCommand]
    private async Task CreateRestorePointAsync()
    {
        if (IsScriptsRunning || _scriptDirectory == null) return;

        var scriptPath = Path.Combine(_scriptDirectory, "create_restore_point.ps1");
        IsScriptsRunning = true;

        try
        {
            var exitCode = await _executor.RunScriptAsync(scriptPath, null,
                line => UiDispatcher.Post(() => LogPanel.AppendLine(line)));

            if (exitCode == 0)
                _restorePointGuard.MarkCreated();
        }
        finally
        {
            IsScriptsRunning = false;
        }
    }

    [RelayCommand]
    private async Task HandleCloseAsync()
    {
        if (_executor.HasActiveOperations)
        {
            var cancel = await _dialogService.ShowCancelConfirmationAsync();
            if (cancel)
            {
                _executor.CancelAllOperations();
            }
            else
            {
                return;
            }
        }

        System.Windows.Application.Current?.MainWindow?.Close();
    }

    [RelayCommand]
    private async Task CancelRunningAsync()
    {
        if (!_executor.HasActiveOperations) return;

        var cancel = await _dialogService.ShowCancelConfirmationAsync();
        if (cancel)
        {
            _executor.CancelAllOperations();
        }
    }

    [RelayCommand]
    private void DismissUpdate()
    {
        ShowUpdateBanner = false;
        _updateChecker.DismissVersion(UpdateVersion);
    }

    [RelayCommand]
    private void OpenUpdateUrl()
    {
        if (string.IsNullOrEmpty(UpdateUrl)) return;

        try
        {
            var uri = new Uri(UpdateUrl);
            if (uri.Scheme != "https")
            {
                _logger.LogWarning("Refused to open non-HTTPS URL: {Url}", UpdateUrl);
                return;
            }

            // Use ArgumentList instead of a single Arguments string so the URL isn't
            // command-line-parsed by rundll32 — prevents any spaces/quotes in the URL
            // from splitting into unintended extra arguments.
            var psi = new ProcessStartInfo
            {
                FileName = "rundll32",
                UseShellExecute = false
            };
            psi.ArgumentList.Add("url.dll,FileProtocolHandler");
            psi.ArgumentList.Add(UpdateUrl);
            Process.Start(psi);
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Failed to open browser: {Message}", ex.Message);
        }
    }

    // Maps every apply action ID to a friendly label and the script that runs it.
    // The basis for export (all action IDs) and import (validate + run selected).
    private List<(string ActionId, string DisplayName, string ScriptPath)> BuildApplyActionCatalog()
    {
        var catalog = new List<(string ActionId, string DisplayName, string ScriptPath)>();
        if (_scriptDirectory == null) return catalog;

        foreach (var tweak in _tweakRegistry.GetTweaks())
        {
            var scriptPath = Path.Combine(_scriptDirectory, tweak.ApplyScript);
            foreach (var sub in tweak.SubTweaks)
                catalog.Add((sub.ApplyAction, $"{tweak.Title}: {sub.Name}", scriptPath));
        }
        return catalog;
    }

    [RelayCommand]
    private void ExportConfig()
    {
        if (_scriptDirectory == null) return;
        var catalog = BuildApplyActionCatalog();
        if (catalog.Count == 0)
        {
            ErrorMessage = "Nothing to export yet.";
            return;
        }

        var dialog = new Microsoft.Win32.SaveFileDialog
        {
            Title = "Export tweak profile",
            Filter = "PleaseTweakWindows profile (*.ptw.json)|*.ptw.json",
            FileName = "ptw-profile.ptw.json"
        };
        if (dialog.ShowDialog() != true) return;

        try
        {
            var version = GetType().Assembly.GetName().Version?.ToString() ?? "unknown";
            var json = _configProfileService.Export(catalog.Select(c => c.ActionId), version, DateTimeOffset.UtcNow);
            File.WriteAllText(dialog.FileName, json);
            LogPanel.AppendLine($"[+] Exported {catalog.Count} tweaks to {dialog.FileName}");
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Export failed: {ex.Message}";
            _logger.LogWarning(ex, "Config export failed");
        }
    }

    [RelayCommand]
    private async Task ImportConfigAsync()
    {
        if (IsScriptsRunning || _scriptDirectory == null) return;

        var openDialog = new Microsoft.Win32.OpenFileDialog
        {
            Title = "Import tweak profile",
            Filter = "PleaseTweakWindows profile (*.ptw.json;*.json)|*.ptw.json;*.json|All files (*.*)|*.*"
        };
        if (openDialog.ShowDialog() != true) return;

        string json;
        try
        {
            json = await File.ReadAllTextAsync(openDialog.FileName);
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Could not read profile: {ex.Message}";
            return;
        }

        var catalog = BuildApplyActionCatalog();
        var byId = catalog
            .GroupBy(c => c.ActionId, StringComparer.Ordinal)
            .ToDictionary(g => g.Key, g => g.First(), StringComparer.Ordinal);
        var known = new HashSet<string>(byId.Keys, StringComparer.Ordinal);

        var result = _configProfileService.Import(json, known);
        if (result.Error != null)
        {
            ErrorMessage = result.Error;
            return;
        }
        if (result.ValidActions.Count == 0)
        {
            ErrorMessage = "No tweaks in that profile apply to this build.";
            return;
        }

        var reviewItems = result.ValidActions
            .Select(a => (ActionId: a, DisplayName: byId[a].DisplayName))
            .ToList();
        var selected = await _dialogService.ShowConfigReviewAsync(reviewItems, result.DroppedActions.Count);
        if (selected == null || selected.Count == 0) return;

        // One batch confirmation, escalated if any selected tweak is high-risk.
        var highRisk = selected.Any(a => _dialogService.IsHighRisk(a));
        var batchAction = highRisk ? "run-all-batch-high-risk" : "run-all-batch";
        var confirmed = await _dialogService.ShowConfirmationAsync(batchAction, $"Imported profile: {selected.Count} tweaks");
        if (!confirmed) return;

        Action<string> onOutput = line => UiDispatcher.Post(() => LogPanel.AppendLine(line));

        // One restore point for the whole import, then skip it inside the loop.
        var proceed = await _restorePointGuard.EnsureRestorePointAsync(_scriptDirectory, onOutput);
        if (!proceed) return;

        IsScriptsRunning = true;
        try
        {
            foreach (var actionId in selected)
            {
                var entry = byId[actionId];
                // High-risk tweaks still show their specific warning (UAC, wu-disable,
                // persist, NTLM block, …) so an imported profile can't silently apply a
                // severe change behind one generic batch prompt. Reviewed non-high-risk
                // tweaks run without an extra prompt.
                var skipConfirm = !_dialogService.IsHighRisk(actionId);
                var runResult = await ScriptRunner.RunAsync(
                    entry.ScriptPath, actionId, entry.DisplayName, _scriptDirectory,
                    _executor, _dialogService, _restorePointGuard, LogPanel,
                    ensureRestorePoint: false, skipConfirmation: skipConfirm);

                if (runResult.Outcome == ScriptRunOutcome.ConfirmationCancelled)
                {
                    onOutput("[!] Import cancelled by user — stopping remaining tweaks.");
                    break;
                }
                if (runResult.Outcome == ScriptRunOutcome.Applied && runResult.ExitCode != 0)
                {
                    onOutput($"[!] '{entry.DisplayName}' exited with code {runResult.ExitCode} — stopping import.");
                    ErrorMessage = $"'{entry.DisplayName}' failed (exit {runResult.ExitCode}) — check the output panel.";
                    break;
                }
            }
        }
        finally
        {
            IsScriptsRunning = false;
        }
    }

    private async Task CheckForUpdatesAsync()
    {
        var update = await _updateChecker.CheckForUpdateAsync();
        if (update != null)
        {
            UpdateVersion = update.Version;
            UpdateUrl = update.DownloadUrl;
            ShowUpdateBanner = true;
        }
    }

    public void OnCategoryExpanded(TweakCategoryViewModel expandedCategory)
    {
        foreach (var cat in Categories)
        {
            if (cat != expandedCategory)
                cat.IsExpanded = false;
        }
    }
}
