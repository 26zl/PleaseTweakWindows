using PleaseTweakWindows.Services;

namespace PleaseTweakWindows.ViewModels;

internal enum ScriptRunOutcome
{
    /// <summary>Script was executed (exit code is in ExitCode).</summary>
    Applied,
    /// <summary>User declined the restore-point prompt.</summary>
    RestorePointCancelled,
    /// <summary>Restore point creation was requested but failed; the run was blocked.</summary>
    RestorePointFailed,
    /// <summary>User declined the confirmation dialog.</summary>
    ConfirmationCancelled,
    /// <summary>The running script was cancelled by the user (Stop) — not a failure.</summary>
    Cancelled,
}

internal readonly record struct ScriptRunResult(ScriptRunOutcome Outcome, int ExitCode);

/// <summary>Coordinates restore-point checks, confirmation, and script execution.</summary>
internal static class ScriptRunner
{
    public static async Task<ScriptRunResult> RunAsync(
        string scriptPath,
        string action,
        string actionName,
        string scriptDirectory,
        IScriptExecutor executor,
        IDialogService dialogService,
        RestorePointGuard restorePointGuard,
        LogPanelViewModel logPanel,
        bool ensureRestorePoint = true,
        bool skipConfirmation = false)
    {
        Action<string> onOutput = line => UiDispatcher.Post(() => logPanel.AppendLine(line));

        if (ensureRestorePoint)
        {
            var proceed = await restorePointGuard.EnsureRestorePointAsync(
                scriptDirectory, onOutput, isHighRisk: dialogService.IsHighRisk(action));
            if (!proceed)
                // Report only restore-point creation failures as RestorePointFailed.
                return new ScriptRunResult(
                    restorePointGuard.LastStatus == RestorePointStatus.Failed
                        ? ScriptRunOutcome.RestorePointFailed
                        : ScriptRunOutcome.RestorePointCancelled, -1);
        }

        // Skip per-action confirmation after the caller confirms a batch.
        if (!skipConfirmation && dialogService.RequiresConfirmation(action))
        {
            var confirmed = await dialogService.ShowConfirmationAsync(action, actionName);
            if (!confirmed)
                return new ScriptRunResult(ScriptRunOutcome.ConfirmationCancelled, -1);
        }

        var exit = await executor.RunScriptAsync(scriptPath, action, onOutput);
        if (exit == ScriptExecutor.CancelledExitCode)
            return new ScriptRunResult(ScriptRunOutcome.Cancelled, exit);
        return new ScriptRunResult(ScriptRunOutcome.Applied, exit);
    }
}
