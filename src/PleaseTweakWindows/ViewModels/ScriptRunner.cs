using PleaseTweakWindows.Services;

namespace PleaseTweakWindows.ViewModels;

internal enum ScriptRunOutcome
{
    /// <summary>Script was executed (exit code is in ExitCode).</summary>
    Applied,
    /// <summary>User declined the restore-point prompt.</summary>
    RestorePointCancelled,
    /// <summary>User declined the confirmation dialog.</summary>
    ConfirmationCancelled,
}

internal readonly record struct ScriptRunResult(ScriptRunOutcome Outcome, int ExitCode)
{
    public bool UserCancelled =>
        Outcome is ScriptRunOutcome.RestorePointCancelled
                or ScriptRunOutcome.ConfirmationCancelled;
}

/// <summary>
/// Shared script-execution flow: ensure restore point → confirm if destructive → run.
/// Used by both per-action (SubTweakViewModel) and per-category (TweakCategoryViewModel) flows.
/// </summary>
internal static class ScriptRunner
{
    public static async Task<ScriptRunResult> RunAsync(
        string scriptPath,
        string action,
        string actionName,
        string scriptDirectory,
        IScriptExecutor executor,
        IDialogService dialogService,
        IRestorePointGuard restorePointGuard,
        LogPanelViewModel logPanel,
        bool ensureRestorePoint = true,
        bool skipConfirmation = false)
    {
        Action<string> onOutput = line => UiDispatcher.Post(() => logPanel.AppendLine(line));

        if (ensureRestorePoint)
        {
            var proceed = await restorePointGuard.EnsureRestorePointAsync(scriptDirectory, onOutput);
            if (!proceed)
                return new ScriptRunResult(ScriptRunOutcome.RestorePointCancelled, -1);
        }

        // When the caller already confirmed the whole batch (Run All), skip the
        // per-action confirmation dialog so the user isn't prompted N times.
        if (!skipConfirmation && dialogService.RequiresConfirmation(action))
        {
            var confirmed = await dialogService.ShowConfirmationAsync(action, actionName);
            if (!confirmed)
                return new ScriptRunResult(ScriptRunOutcome.ConfirmationCancelled, -1);
        }

        var exit = await executor.RunScriptAsync(scriptPath, action, onOutput);
        return new ScriptRunResult(ScriptRunOutcome.Applied, exit);
    }
}
