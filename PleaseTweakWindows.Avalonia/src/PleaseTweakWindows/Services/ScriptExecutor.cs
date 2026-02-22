using System.Collections.Concurrent;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;

namespace PleaseTweakWindows.Services;

public sealed partial class ScriptExecutor : IScriptExecutor
{
    private const int MaxConcurrency = 4;
    private static readonly string PowerShellPath = GetPowerShellPath();

    private static readonly HashSet<string> ConsolidatedScripts = new(StringComparer.OrdinalIgnoreCase)
    {
        "gaming-optimizations.ps1",
        "network-optimizations.ps1",
        "general-tweaks.ps1",
        "services-management.ps1",
        "revert-privacy.ps1",
        "privacy.ps1",
        "security.ps1",
        "revert-security.ps1"
    };

    private readonly IProcessRunner _processRunner;
    private readonly ILogger<ScriptExecutor> _logger;
    private readonly ILogger _telemetryLogger;
    private readonly SemaphoreSlim _semaphore = new(MaxConcurrency, MaxConcurrency);
    private readonly ConcurrentDictionary<string, Process> _activeProcesses = new();
    private CancellationTokenSource _globalCts = new();
    private volatile string? _scriptsBaseDir;
    private long _keyCounter;

    public bool HasActiveOperations => !_activeProcesses.IsEmpty;

    public ScriptExecutor(IProcessRunner processRunner, ILoggerFactory loggerFactory)
    {
        _processRunner = processRunner;
        _logger = loggerFactory.CreateLogger<ScriptExecutor>();
        _telemetryLogger = loggerFactory.CreateLogger("Telemetry");
    }

    public void SetScriptsBaseDir(string baseDir) => _scriptsBaseDir = baseDir;

    public static string GetPowerShellPath()
    {
        var systemRoot = Environment.GetEnvironmentVariable("SystemRoot");
        if (string.IsNullOrWhiteSpace(systemRoot) || !Regex.IsMatch(systemRoot, @"^[A-Za-z0-9\\:]+$"))
            systemRoot = @"C:\Windows";

        try
        {
            var normalized = Path.GetFullPath(systemRoot);
            if (normalized.Length >= 3 && char.IsLetter(normalized[0]) && normalized[1] == ':' && normalized[2] == '\\')
                return Path.Combine(normalized, @"System32\WindowsPowerShell\v1.0\powershell.exe");
        }
        catch
        {
            // fall through
        }
        return @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe";
    }

    public void CancelAllOperations()
    {
        _logger.LogInformation("Cancellation requested for all operations");
        _globalCts.Cancel();

        foreach (var (key, process) in _activeProcesses)
        {
            if (!process.HasExited)
            {
                _logger.LogInformation("Terminating process: {Key}", key);
                try { process.Kill(entireProcessTree: true); } catch { /* best effort */ }
            }
        }
        _activeProcesses.Clear();

        // Reset CTS after a short delay
        _ = Task.Delay(500).ContinueWith(_ =>
        {
            var oldCts = _globalCts;
            _globalCts = new CancellationTokenSource();
            oldCts.Dispose();
        });
    }

    public async Task<int> RunScriptAsync(string scriptPath, string? action, Action<string>? onOutput, CancellationToken cancellationToken = default)
    {
        if (!IsValidScriptPath(scriptPath))
        {
            RejectWithError($"Invalid script path: {scriptPath}", scriptPath, action, onOutput);
            return -1;
        }
        if (!File.Exists(scriptPath))
        {
            RejectWithError($"Script not found: {scriptPath}", scriptPath, action, onOutput);
            return -1;
        }
        if (action != null && !IsValidAction(action))
        {
            RejectWithError($"Invalid action parameter: {action}", scriptPath, action, onOutput);
            return -1;
        }

        // TOCTOU protection: hash before execution
        var expectedHash = ComputeFileHash(scriptPath);

        onOutput?.Invoke("\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550");
        onOutput?.Invoke($"  Starting: {Path.GetFileName(scriptPath)}");
        onOutput?.Invoke("\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550");
        _logger.LogInformation("Running script: {ScriptPath} (action={Action})", scriptPath, action);

        await _semaphore.WaitAsync(cancellationToken);
        try
        {
            return await ExecuteScriptAsync(scriptPath, action, expectedHash, onOutput, cancellationToken);
        }
        finally
        {
            _semaphore.Release();
        }
    }

    private async Task<int> ExecuteScriptAsync(string scriptPath, string? action, string? expectedHash, Action<string>? onOutput, CancellationToken cancellationToken)
    {
        var sw = Stopwatch.StartNew();
        var exitCode = -1;

        try
        {
            // Verify integrity (TOCTOU check)
            if (expectedHash != null)
            {
                var currentHash = ComputeFileHash(scriptPath);
                if (!string.Equals(expectedHash, currentHash, StringComparison.Ordinal))
                {
                    onOutput?.Invoke("ERROR: Script integrity check failed - file was modified between validation and execution");
                    _logger.LogError("TOCTOU: Script hash mismatch for {ScriptPath}. Expected={Expected}, Got={Got}", scriptPath, expectedHash, currentHash);
                    return -1;
                }
            }

            var scriptName = Path.GetFileName(scriptPath);
            var isConsolidated = ConsolidatedScripts.Contains(scriptName);

            var psi = new ProcessStartInfo
            {
                FileName = PowerShellPath,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            psi.ArgumentList.Add("-NoProfile");
            psi.ArgumentList.Add("-ExecutionPolicy");
            psi.ArgumentList.Add("Bypass");
            psi.ArgumentList.Add("-WindowStyle");
            psi.ArgumentList.Add("Hidden");
            psi.ArgumentList.Add("-File");
            psi.ArgumentList.Add(scriptPath);

            if (isConsolidated && action != null)
            {
                psi.ArgumentList.Add("-Action");
                psi.ArgumentList.Add(action);
                onOutput?.Invoke($"[>] Action: {action}");
            }

            psi.Environment["PTW_EMBEDDED"] = "1";
            var logDir = Path.Combine(AppContext.BaseDirectory, "logs");
            psi.Environment["PTW_LOG_DIR"] = logDir;

            var processKey = $"{scriptPath}_{Interlocked.Increment(ref _keyCounter)}";

            using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, _globalCts.Token);

            try
            {
                var process = _processRunner.Start(psi);
                _activeProcesses[processKey] = process;

                // Read stdout and stderr concurrently
                var outputTask = ReadStreamAsync(process.StandardOutput, onOutput, linkedCts.Token);
                var errorTask = ReadStreamAsync(process.StandardError, onOutput, linkedCts.Token);

                await Task.WhenAll(outputTask, errorTask);

                // Wait for process to exit with timeout
                using var timeoutCts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
                using var combinedCts = CancellationTokenSource.CreateLinkedTokenSource(linkedCts.Token, timeoutCts.Token);

                try
                {
                    await process.WaitForExitAsync(combinedCts.Token);
                    exitCode = process.ExitCode;
                }
                catch (OperationCanceledException) when (timeoutCts.IsCancellationRequested)
                {
                    _logger.LogWarning("Process did not terminate within timeout, forcing: {ScriptPath}", scriptPath);
                    try { process.Kill(entireProcessTree: true); } catch { /* best effort */ }
                    exitCode = -1;
                }
                catch (OperationCanceledException)
                {
                    onOutput?.Invoke("[!] Operation cancelled by user");
                    try { process.Kill(entireProcessTree: true); } catch { /* best effort */ }
                    exitCode = -1;
                }
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                exitCode = -1;
                onOutput?.Invoke($"ERROR: Failed to start script process: {ex.Message}");
                onOutput?.Invoke("This may be due to insufficient permissions or PowerShell not being available.");
                _logger.LogError(ex, "Failed to start script process: {ScriptPath}", scriptPath);
            }
            finally
            {
                _activeProcesses.TryRemove(processKey, out _);
            }

            onOutput?.Invoke("\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550");
            if (exitCode == 0)
            {
                onOutput?.Invoke("  [+] SUCCESS - Operation completed");
                _logger.LogInformation("Script finished successfully: {ScriptPath}", scriptPath);
            }
            else
            {
                onOutput?.Invoke($"  [!] Finished with warnings (code: {exitCode})");
                _logger.LogWarning("Script finished with exit code {ExitCode}: {ScriptPath}", exitCode, scriptPath);
            }
            onOutput?.Invoke("\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550");
        }
        finally
        {
            sw.Stop();
            LogActionTelemetry(scriptPath, action, exitCode, sw.ElapsedMilliseconds);
        }

        return exitCode;
    }

    private static async Task ReadStreamAsync(System.IO.StreamReader reader, Action<string>? onOutput, CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            var line = await reader.ReadLineAsync(ct);
            if (line == null) break;
            onOutput?.Invoke(line);
        }
    }

    internal bool IsValidAction(string action)
    {
        if (string.IsNullOrEmpty(action)) return false;
        return ActionIdRegex().IsMatch(action);
    }

    internal bool IsValidScriptPath(string? scriptPath)
    {
        if (string.IsNullOrWhiteSpace(scriptPath)) return false;
        if (scriptPath.Contains("..")) return false;

        try
        {
            var normalized = Path.GetFullPath(scriptPath);
            if (!normalized.EndsWith(".ps1", StringComparison.OrdinalIgnoreCase)) return false;
            if (normalized.IndexOfAny([';', '|', '&', '>', '<']) >= 0) return false;

            if (_scriptsBaseDir != null)
            {
                var baseAbs = Path.GetFullPath(_scriptsBaseDir);
                if (!normalized.StartsWith(baseAbs, StringComparison.OrdinalIgnoreCase))
                {
                    _logger.LogWarning("Script path {ScriptPath} is outside base directory {BaseDir}", scriptPath, _scriptsBaseDir);
                    return false;
                }
            }

            return true;
        }
        catch
        {
            return false;
        }
    }

    private void RejectWithError(string message, string scriptPath, string? action, Action<string>? onOutput)
    {
        onOutput?.Invoke($"Error: {message}");
        _logger.LogWarning("{Message}: {ScriptPath}", message, scriptPath);
        LogActionTelemetry(scriptPath, action, -1, 0);
    }

    private void LogActionTelemetry(string scriptPath, string? action, int exitCode, long durationMs)
    {
        var actionLabel = string.IsNullOrWhiteSpace(action) ? "Menu" : action;
        var scriptName = Path.GetFileName(scriptPath);
        var msg = $"ActionTelemetry script={scriptName} action={actionLabel} exit={exitCode} duration={durationMs}ms";

        // Use a special property to route to telemetry sink
        if (exitCode == 0)
            _telemetryLogger.LogInformation("{@Telemetry}", msg);
        else
            _telemetryLogger.LogWarning("{@Telemetry}", msg);
    }

    internal static string? ComputeFileHash(string filePath)
    {
        try
        {
            var bytes = File.ReadAllBytes(filePath);
            var hash = SHA256.HashData(bytes);
            return Convert.ToHexStringLower(hash);
        }
        catch (Exception)
        {
            return null;
        }
    }

    public void Shutdown()
    {
        foreach (var (_, process) in _activeProcesses)
        {
            if (!process.HasExited)
            {
                try { process.Kill(entireProcessTree: true); } catch { /* best effort */ }
            }
        }
        _activeProcesses.Clear();
        _globalCts.Cancel();
        _globalCts.Dispose();
        _semaphore.Dispose();
    }

    [GeneratedRegex(@"^[A-Za-z0-9_-]{2,64}$")]
    private static partial Regex ActionIdRegex();
}
