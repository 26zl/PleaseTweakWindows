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
}
