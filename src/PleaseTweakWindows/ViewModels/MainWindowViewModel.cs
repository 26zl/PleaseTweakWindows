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

    // Propagate global running-state changes to all action controls.
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

        ErrorMessage = null; // don't leave a stale failure banner over a successful restore point
        var scriptPath = Path.Combine(_scriptDirectory, "create_restore_point.ps1");
        IsScriptsRunning = true;

        try
        {
            var exitCode = await _executor.RunScriptAsync(scriptPath, null,
                line => UiDispatcher.Post(() => LogPanel.AppendLine(line)));

            if (exitCode == 0)
                _restorePointGuard.MarkCreated();
            // A user Stop mid-creation is a deliberate cancel, not a failure — stay silent.
            else if (exitCode != ScriptExecutor.CancelledExitCode)
                ErrorMessage = $"Restore point creation failed (exit {exitCode}) — check the output panel.";
        }
        catch (Exception ex)
        {
            LogPanel.AppendLine($"[-] ERROR: Restore point creation failed: {ex.Message}");
            ErrorMessage = "Restore point creation could not be completed — check the output panel.";
            _logger.LogWarning(ex, "Restore point creation failed");
        }
        finally
        {
            IsScriptsRunning = false;
        }
    }

    [RelayCommand]
    private async Task HandleCloseAsync()
    {
        try
        {
            if (_executor.HasActiveOperations)
            {
                var cancel = await _dialogService.ShowCancelConfirmationAsync();
                if (!cancel)
                    return;

                _executor.CancelAllOperations();
            }
        }
        catch (Exception ex)
        {
            // Never let a close-handler exception escape as an unhandled async-void crash.
            _logger.LogError(ex, "Close handling failed; closing anyway");
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
            // Open update links only when they use HTTPS on github.com.
            if (!string.Equals(uri.Host, "github.com", StringComparison.OrdinalIgnoreCase))
            {
                _logger.LogWarning("Refused to open non-GitHub URL: {Url}", UpdateUrl);
                return;
            }

            // Pass the URL as one rundll32 argument.
            var psi = new ProcessStartInfo
            {
                FileName = Path.Combine(Environment.SystemDirectory, "rundll32.exe"),
                UseShellExecute = false
            };
            psi.ArgumentList.Add("url.dll,FileProtocolHandler");
            psi.ArgumentList.Add(UpdateUrl);
            using var process = Process.Start(psi);
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Failed to open browser: {Message}", ex.Message);
        }
    }

    // Map Apply action IDs to display names and scripts for profile import and export.
    private List<(string ActionId, string DisplayName, string ScriptPath, SubTweakRequirement? Requires)> BuildApplyActionCatalog()
    {
        var catalog = new List<(string ActionId, string DisplayName, string ScriptPath, SubTweakRequirement? Requires)>();
        if (_scriptDirectory == null) return catalog;

        foreach (var tweak in _tweakRegistry.GetTweaks())
        {
            var scriptPath = Path.Combine(_scriptDirectory, tweak.ApplyScript);
            foreach (var sub in tweak.SubTweaks)
                catalog.Add((sub.ApplyAction, $"{tweak.Title}: {sub.Name}", scriptPath, sub.Requires));
        }
        return catalog;
    }

    [RelayCommand]
    private void ExportConfig()
    {
        if (_scriptDirectory == null) return;
        ErrorMessage = null; // clear any stale failure banner before a fresh export
        var catalog = BuildApplyActionCatalog();
        if (catalog.Count == 0)
        {
            ErrorMessage = "Nothing to export yet.";
            return;
        }

        var dialog = new Microsoft.Win32.SaveFileDialog
        {
            Title = "Export all available tweaks (template profile)",
            Filter = "PleaseTweakWindows profile (*.ptw.json)|*.ptw.json",
            FileName = "ptw-all-tweaks.ptw.json"
        };
        if (dialog.ShowDialog() != true) return;

        try
        {
            // Use AssemblyInformationalVersion for exported profile versions.
            var version = UpdateChecker.CurrentVersion;
            var json = _configProfileService.Export(catalog.Select(c => c.ActionId), version, DateTimeOffset.UtcNow);
            File.WriteAllText(dialog.FileName, json);
            LogPanel.AppendLine($"[+] Exported all {catalog.Count} available tweaks (a template — import lets you pick which to apply) to {dialog.FileName}");
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

        // Block other actions throughout profile reading, review, and execution.
        ErrorMessage = null;
        IsScriptsRunning = true;
        try
        {
            string json;
            try
            {
                await using var stream = new FileStream(openDialog.FileName, new FileStreamOptions
                {
                    Mode = FileMode.Open,
                    Access = FileAccess.Read,
                    Share = FileShare.Read,
                    BufferSize = 4096,
                    Options = FileOptions.Asynchronous | FileOptions.SequentialScan,
                });
                if (stream.Length > ConfigProfileService.MaxProfileBytes)
                {
                    ErrorMessage = $"Profile is too large. Maximum size is {ConfigProfileService.MaxProfileBytes / 1024} KB.";
                    return;
                }
                using var reader = new StreamReader(stream);
                json = await reader.ReadToEndAsync();
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
            var proceed = await _restorePointGuard.EnsureRestorePointAsync(_scriptDirectory, onOutput, isHighRisk: highRisk);
            if (!proceed)
            {
                if (_restorePointGuard.LastStatus == RestorePointStatus.Failed)
                    ErrorMessage = "Restore point creation failed — import aborted. See the output panel.";
                return;
            }

            foreach (var actionId in selected)
            {
                var entry = byId[actionId];

                // Skip imported actions whose dependencies are unmet.
                if (!RegistryState.IsSatisfied(entry.Requires))
                {
                    onOutput($"[!] Skipped '{entry.DisplayName}' — prerequisite not met: {entry.Requires?.UnmetMessage}");
                    continue;
                }

                // Keep per-action warnings for high-risk imports only.
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
                if (runResult.Outcome == ScriptRunOutcome.Cancelled)
                {
                    onOutput("[!] Stopped by user — remaining tweaks not applied.");
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
        catch (Exception ex)
        {
            LogPanel.AppendLine($"[-] ERROR: Import failed: {ex.Message}");
            ErrorMessage = "Profile import could not be completed — check the output panel.";
            _logger.LogWarning(ex, "Config import failed");
        }
        finally
        {
            IsScriptsRunning = false;
        }
    }

    private async Task CheckForUpdatesAsync()
    {
        // PTW_NO_UPDATE_CHECK=1 disables the GitHub release check.
        var optOut = Environment.GetEnvironmentVariable("PTW_NO_UPDATE_CHECK");
        if (string.Equals(optOut, "1", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(optOut, "true", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogInformation("Update check skipped (PTW_NO_UPDATE_CHECK set).");
            return;
        }

        var update = await _updateChecker.CheckForUpdateAsync();
        if (update != null)
        {
            UpdateVersion = update.Version;
            UpdateUrl = update.ReleasePageUrl;
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
