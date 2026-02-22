using System.Collections.ObjectModel;
using System.Diagnostics;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Extensions.Logging;
using PleaseTweakWindows.Services;

namespace PleaseTweakWindows.ViewModels;

public partial class MainWindowViewModel : ViewModelBase
{
    private readonly ITweakRegistry _tweakRegistry;
    private readonly IScriptExecutor _executor;
    private readonly IDialogService _dialogService;
    private readonly IRestorePointGuard _restorePointGuard;
    private readonly IResourceExtractor _resourceExtractor;
    private readonly IUpdateChecker _updateChecker;
    private readonly AdminChecker _adminChecker;
    private readonly ILogger<MainWindowViewModel> _logger;

    private string? _scriptDirectory;

    [ObservableProperty]
    private bool _isScriptsRunning;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(FilteredCategories))]
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

    public MainWindowViewModel(
        ITweakRegistry tweakRegistry,
        IScriptExecutor executor,
        IDialogService dialogService,
        IRestorePointGuard restorePointGuard,
        IResourceExtractor resourceExtractor,
        IUpdateChecker updateChecker,
        AdminChecker adminChecker,
        ILoggerFactory loggerFactory)
    {
        _tweakRegistry = tweakRegistry;
        _executor = executor;
        _dialogService = dialogService;
        _restorePointGuard = restorePointGuard;
        _resourceExtractor = resourceExtractor;
        _updateChecker = updateChecker;
        _adminChecker = adminChecker;
        _logger = loggerFactory.CreateLogger<MainWindowViewModel>();
        LogPanel = new LogPanelViewModel();
    }

    public async void InitializeAsync()
    {
        // Check admin
        if (!_adminChecker.IsRunningAsAdministrator())
        {
            ErrorMessage = "PleaseTweakWindows requires Administrator privileges.\nPlease right-click the application and select \"Run as administrator\".";
            _logger.LogError("Application must be run as Administrator.");
            return;
        }

        // Check PowerShell
        if (!IScriptExecutor.IsPowerShellAvailable())
        {
            ErrorMessage = "Windows PowerShell 5.1 is required but was not found.";
            _logger.LogError("PowerShell 5.1 not found.");
            return;
        }

        // Extract scripts
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

        // Load tweaks
        foreach (var tweak in _tweakRegistry.GetTweaks())
        {
            Categories.Add(new TweakCategoryViewModel(
                tweak, _scriptDirectory, _executor, _dialogService,
                _restorePointGuard, LogPanel,
                () => IsScriptsRunning,
                running => IsScriptsRunning = running));
        }

        IsInitialized = true;
        _logger.LogInformation("UI initialized with {Count} categories.", Categories.Count);

        // Check for updates
        await CheckForUpdatesAsync();
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
                line => Avalonia.Threading.Dispatcher.UIThread.Post(() => LogPanel.AppendLine(line)));

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

        if (Avalonia.Application.Current?.ApplicationLifetime is Avalonia.Controls.ApplicationLifetimes.IClassicDesktopStyleApplicationLifetime desktop)
        {
            desktop.MainWindow?.Close();
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
            if (uri.Scheme is not ("https" or "http"))
            {
                _logger.LogWarning("Refused to open non-HTTP URL: {Url}", UpdateUrl);
                return;
            }

            Process.Start(new ProcessStartInfo
            {
                FileName = "rundll32",
                Arguments = $"url.dll,FileProtocolHandler {UpdateUrl}",
                UseShellExecute = false
            });
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Failed to open browser: {Message}", ex.Message);
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

    /// <summary>Collapse all categories except the one being toggled (accordion behavior).</summary>
    public void OnCategoryExpanded(TweakCategoryViewModel expandedCategory)
    {
        foreach (var cat in Categories)
        {
            if (cat != expandedCategory)
                cat.IsExpanded = false;
        }
    }
}
