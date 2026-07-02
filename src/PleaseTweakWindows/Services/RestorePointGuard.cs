using Microsoft.Extensions.Logging;

namespace PleaseTweakWindows.Services;

/// <summary>Outcome of the latest restore-point request.</summary>
public enum RestorePointStatus { None, Created, Skipped, UserCancelled, Failed }

public sealed class RestorePointGuard
{
    private enum Decision { Unknown, Created, Skipped }

    private readonly IDialogService _dialogService;
    private readonly IScriptExecutor _executor;
    private readonly ILogger<RestorePointGuard> _logger;
    private readonly object _lock = new();
    private Decision _decision = Decision.Unknown;

    // Runs are serialized by the global IsScriptsRunning gate.
    public RestorePointStatus LastStatus { get; private set; } = RestorePointStatus.None;
    // Track whether the user has skipped the prompt for a high-risk action.
    private bool _highRiskSkipAcknowledged;

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

    public async Task<bool> EnsureRestorePointAsync(string scriptDirectory, Action<string>? onOutput, bool isHighRisk = false, CancellationToken cancellationToken = default)
    {
        lock (_lock)
        {
            // A successfully created restore point covers the whole session.
            if (_decision == Decision.Created)
            {
                LastStatus = RestorePointStatus.Created;
                return true;
            }
            // Re-prompt high-risk actions until the user skips in a high-risk context.
            if (_decision == Decision.Skipped && (!isHighRisk || _highRiskSkipAcknowledged))
            {
                LastStatus = RestorePointStatus.Skipped;
                return true;
            }
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
                    LastStatus = RestorePointStatus.Created;
                    return true;
                }
                // Treat Stop during restore-point creation as a user cancellation.
                if (exitCode == ScriptExecutor.CancelledExitCode)
                {
                    LastStatus = RestorePointStatus.UserCancelled;
                    return false;
                }
                // Block the tweak when requested restore-point creation fails.
                _logger.LogWarning("Restore point creation failed (exit={ExitCode}); blocking tweak.", exitCode);
                onOutput?.Invoke("[-] ERROR: Restore point creation failed — tweak aborted.");
                LastStatus = RestorePointStatus.Failed;
                return false;

            case RestorePointDecision.Skip:
                lock (_lock)
                {
                    _decision = Decision.Skipped;
                    if (isHighRisk) _highRiskSkipAcknowledged = true;
                }
                LastStatus = RestorePointStatus.Skipped;
                return true;

            case RestorePointDecision.Cancel:
            default:
                // Report that Apply was cancelled at the restore-point prompt.
                onOutput?.Invoke("[!] Restore point cancelled — tweak not applied.");
                LastStatus = RestorePointStatus.UserCancelled;
                return false;
        }
    }
}
