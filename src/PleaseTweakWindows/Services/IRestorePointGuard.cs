namespace PleaseTweakWindows.Services;

public interface IRestorePointGuard
{
    void MarkCreated();
    Task<bool> EnsureRestorePointAsync(string scriptDirectory, Action<string>? onOutput, CancellationToken cancellationToken = default);
}
