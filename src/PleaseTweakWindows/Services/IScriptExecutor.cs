namespace PleaseTweakWindows.Services;

public interface IScriptExecutor
{
    void SetScriptsBaseDir(string baseDir);
    Task<int> RunScriptAsync(string scriptPath, string? action, Action<string>? onOutput, CancellationToken cancellationToken = default);
    void CancelAllOperations();
    bool HasActiveOperations { get; }
    void Shutdown();

    static bool IsPowerShellAvailable()
    {
        var psPath = ScriptExecutor.GetPowerShellPath();
        return File.Exists(psPath);
    }
}
