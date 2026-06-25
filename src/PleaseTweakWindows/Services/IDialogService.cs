namespace PleaseTweakWindows.Services;

public enum RestorePointDecision
{
    Create,
    Skip,
    Cancel
}

public interface IDialogService
{
    bool RequiresConfirmation(string action);
    bool IsHighRisk(string action);
    Task<bool> ShowConfirmationAsync(string action, string actionName);
    Task<RestorePointDecision> ShowRestorePointPromptAsync();
    Task<bool> ShowCancelConfirmationAsync();
    string GetActionWarning(string action, string actionName);

    /// <summary>
    /// Shows the per-item import review. Returns the action IDs the user kept,
    /// or null if they cancelled.
    /// </summary>
    Task<IReadOnlyList<string>?> ShowConfigReviewAsync(
        IReadOnlyList<(string ActionId, string DisplayName)> items, int droppedCount);
}
