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

    /// <summary>Returns the reviewed action IDs or null when cancelled.</summary>
    Task<IReadOnlyList<string>?> ShowConfigReviewAsync(
        IReadOnlyList<(string ActionId, string DisplayName)> items, int droppedCount);
}
