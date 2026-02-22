using Microsoft.Extensions.Logging;

namespace PleaseTweakWindows.Services;

public sealed class RestorePointGuard : IRestorePointGuard
{
    private enum Decision { Unknown, Created, Skipped }

    private readonly IDialogService _dialogService;
    private readonly IScriptExecutor _executor;
    private readonly ILogger<RestorePointGuard> _logger;
    private readonly object _lock = new();
    private Decision _decision = Decision.Unknown;

    public RestorePointGuard(IDialogService dialogService, IScriptExecutor executor, ILoggerFactory loggerFactory)
    {
        _dialogService = dialogService;
        _executor = executor;
        _logger = loggerFactory.CreateLogger<RestorePointGuard>();
    }

    public void MarkCreated()
    {
        lock (_lock)
        {
            _decision = Decision.Created;
        }
    }

    /// <summary>
    /// Returns true if the user wants to proceed, false if cancelled.
    /// </summary>
    public async Task<bool> EnsureRestorePointAsync(string scriptDirectory, Action<string>? onOutput, CancellationToken cancellationToken = default)
    {
        lock (_lock)
        {
            if (_decision != Decision.Unknown)
                return true;
        }

        var choice = await _dialogService.ShowRestorePointPromptAsync();

        switch (choice)
        {
            case RestorePointDecision.Create:
                var scriptPath = Path.Combine(scriptDirectory, "create_restore_point.ps1");
                var exitCode = await _executor.RunScriptAsync(scriptPath, null, onOutput, cancellationToken);
                if (exitCode == 0)
                {
                    lock (_lock) { _decision = Decision.Created; }
                }
                // Stay Unknown on failure so user is prompted again next time
                return true;

            case RestorePointDecision.Skip:
                lock (_lock) { _decision = Decision.Skipped; }
                return true;

            case RestorePointDecision.Cancel:
            default:
                return false;
        }
    }
}
