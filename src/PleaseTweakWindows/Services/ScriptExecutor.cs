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

    internal static readonly HashSet<string> ConsolidatedScripts = new(StringComparer.OrdinalIgnoreCase)
    {
        "gaming-optimizations.ps1",
        "network-optimizations.ps1",
        "performance.ps1",
        "revert-performance.ps1",
        "debloat.ps1",
        "revert-debloat.ps1",
        "maintenance.ps1",
        "revert-privacy.ps1",
        "privacy.ps1",
        "defender.ps1",
        "revert-defender.ps1",
        "exploit-protection.ps1",
        "revert-exploit-protection.ps1",
        "device-guard.ps1",
        "revert-device-guard.ps1",
        "network-security.ps1",
        "revert-network-security.ps1",
        "system-security.ps1",
        "revert-system-security.ps1",
        "customize.ps1",
        "windows-update.ps1",
        "edge.ps1"
    };

    private readonly IProcessRunner _processRunner;
    private readonly ILogger<ScriptExecutor> _logger;
    private readonly ILogger _telemetryLogger;
    private readonly SemaphoreSlim _semaphore = new(MaxConcurrency, MaxConcurrency);
    private readonly ConcurrentDictionary<string, Process> _activeProcesses = new();
    private readonly object _ctsLock = new();
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
        }
        return @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe";
    }

    public void CancelAllOperations()
    {
        _logger.LogInformation("Cancellation requested for all operations");

        CancellationTokenSource oldCts;
        lock (_ctsLock)
        {
            oldCts = _globalCts;
            _globalCts = new CancellationTokenSource();
        }

        oldCts.Cancel();

        foreach (var (key, process) in _activeProcesses)
        {
            _logger.LogInformation("Terminating process: {Key}", key);
            try { process.Kill(entireProcessTree: true); }
            catch (Exception ex) { _logger.LogDebug(ex, "Kill failed for {Key}", key); }
        }
        _activeProcesses.Clear();
        oldCts.Dispose();
    }

    private CancellationToken GetGlobalToken()
    {
        lock (_ctsLock) { return _globalCts.Token; }
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

        var expectedHash = ComputeFileHash(scriptPath);

        onOutput?.Invoke($"> Starting: {Path.GetFileName(scriptPath)}");
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
                StandardOutputEncoding = System.Text.Encoding.UTF8,
                StandardErrorEncoding = System.Text.Encoding.UTF8,
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
            var logDir = AppPaths.GetLogsDirectory();
            psi.Environment["PTW_LOG_DIR"] = logDir;

            var processKey = $"{scriptPath}_{Interlocked.Increment(ref _keyCounter)}";

            using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, GetGlobalToken());

            Process? process = null;
            try
            {
                process = _processRunner.Start(psi);
                _activeProcesses[processKey] = process;

                // Apply one shared hard-cap timeout across BOTH the stream reads and the
                // WaitForExitAsync. Previously the 30s timeout was only attached to the
                // exit wait, which was unreachable for hung processes because the stream
                // reads above would block indefinitely (ReadLineAsync returns null only
                // when the process closes its stdout/stderr — a hung process never does).
                using var timeoutCts = new CancellationTokenSource(TimeSpan.FromMinutes(10));
                using var combinedCts = CancellationTokenSource.CreateLinkedTokenSource(linkedCts.Token, timeoutCts.Token);

                var outputTask = ReadStreamAsync(process.StandardOutput, onOutput, combinedCts.Token);
                var errorTask = ReadStreamAsync(process.StandardError, onOutput, combinedCts.Token);

                try
                {
                    await process.WaitForExitAsync(combinedCts.Token);
                    exitCode = process.ExitCode;
                }
                catch (OperationCanceledException) when (timeoutCts.IsCancellationRequested)
                {
                    _logger.LogWarning("Process exceeded 10-minute timeout, forcing: {ScriptPath}", scriptPath);
                    onOutput?.Invoke("[!] Script exceeded 10-minute timeout — forcing termination.");
                    try { process.Kill(entireProcessTree: true); } catch { }
                    exitCode = -1;
                }
                catch (OperationCanceledException)
                {
                    onOutput?.Invoke("[!] Operation cancelled by user");
                    try { process.Kill(entireProcessTree: true); } catch { }
                    exitCode = -1;
                }
                finally
                {
                    // Always drain the read tasks, even on timeout/cancel. After Kill or
                    // a token trip these complete quickly — usually with OperationCanceledException.
                    // Leaving them unawaited causes unobserved task exceptions later.
                    try { await Task.WhenAll(outputTask, errorTask); }
                    catch (OperationCanceledException) { }
                    catch (Exception ex) { _logger.LogDebug(ex, "Drain of read tasks threw"); }
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
                // If we fell through to the outer catch after Start already succeeded, the
                // powershell child may still be running. Don't orphan a privileged process:
                // kill the tree before disposing the handle (Dispose alone does not kill it).
                if (exitCode != 0 && process != null)
                {
                    try
                    {
                        if (!process.HasExited)
                            process.Kill(entireProcessTree: true);
                    }
                    catch { }
                }
                process?.Dispose();
            }

            if (exitCode == 0)
            {
                onOutput?.Invoke("[+] SUCCESS - Operation completed");
                _logger.LogInformation("Script finished successfully: {ScriptPath}", scriptPath);
            }
            else
            {
                onOutput?.Invoke($"[X] FAILED (exit code {exitCode}) — this tweak did NOT apply correctly. See output above.");
                _logger.LogWarning("Script finished with exit code {ExitCode}: {ScriptPath}", exitCode, scriptPath);
            }
            onOutput?.Invoke("");
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
                // Use GetRelativePath to decide containment — a plain StartsWith on the
                // prefix would also match sibling directories like "<base>-evil\...".
                var rel = Path.GetRelativePath(baseAbs, normalized);
                if (rel.StartsWith("..", StringComparison.Ordinal) || Path.IsPathRooted(rel))
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
            try { process.Kill(entireProcessTree: true); }
            catch (Exception ex) { _logger.LogDebug(ex, "Shutdown kill failed"); }
        }
        _activeProcesses.Clear();
        // Do NOT dispose _globalCts or _semaphore: they are process-lifetime singletons.
        // An in-flight tweak task can still touch them after shutdown (semaphore Release,
        // GetGlobalToken), and disposing here races those awaits into ObjectDisposedException.
        // The OS reclaims them on process exit. Cancel is enough to unblock waiters.
        lock (_ctsLock)
        {
            _globalCts.Cancel();
        }
    }

    [GeneratedRegex(@"^[A-Za-z0-9_-]{2,64}$")]
    private static partial Regex ActionIdRegex();
}
