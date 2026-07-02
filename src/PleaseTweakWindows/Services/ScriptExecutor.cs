using System.Collections.Concurrent;
using System.Diagnostics;
using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;

namespace PleaseTweakWindows.Services;

public sealed partial class ScriptExecutor : IScriptExecutor, IDisposable
{
    private const int MaxConcurrency = 4;
    private static readonly string PowerShellPath = GetPowerShellPath();
    // Action IDs that use the 45-minute timeout instead of the 10-minute default.
    internal static readonly HashSet<string> LongRunningActions = new(StringComparer.Ordinal)
    {
        "cpp-install",
        "directx-install",
        "nvidia-driver-install"
    };

    // STATUS_CONTROL_C_EXIT marks cancellation initiated by Stop.
    internal const int CancelledExitCode = -1073741510;

    internal static readonly HashSet<string> ConsolidatedScripts = new(StringComparer.OrdinalIgnoreCase)
    {
        "gaming-optimizations.ps1",
        "network-optimizations.ps1",
        "performance.ps1",
        "debloat.ps1",
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
    private readonly ILogger _activityLogger;
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
        _activityLogger = loggerFactory.CreateLogger("LocalActivity");
    }

    public void SetScriptsBaseDir(string baseDir) => _scriptsBaseDir = baseDir;

    public static string GetPowerShellPath()
    {
        // Resolve PowerShell from the trusted Windows system directory.
        return Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe");
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
        // Refuse execution unless the script can be confined to the protected extraction directory.
        if (_scriptsBaseDir == null)
        {
            RejectWithError("Scripts base directory not initialized — refusing to run.", scriptPath, action, onOutput);
            return -1;
        }

        // Trust the manifest embedded in this EXE, not a replaceable on-disk copy.
        var expectedHash = GetManifestHashForScript(scriptPath);
        if (expectedHash == null)
        {
            RejectWithError($"Script not in embedded checksum manifest — refusing to run: {Path.GetFileName(scriptPath)}", scriptPath, action, onOutput);
            return -1;
        }

        // A read failure must not bypass the integrity re-check.
        var diskHash = ComputeFileHash(scriptPath);
        if (diskHash == null)
        {
            RejectWithError($"Could not hash script for integrity check: {scriptPath}", scriptPath, action, onOutput);
            return -1;
        }
        if (!string.Equals(expectedHash, diskHash, StringComparison.Ordinal))
        {
            RejectWithError($"Script failed embedded-manifest integrity check: {Path.GetFileName(scriptPath)}", scriptPath, action, onOutput);
            return -1;
        }

        onOutput?.Invoke($"> Starting: {Path.GetFileName(scriptPath)}");
        _logger.LogInformation("Running script: {ScriptPath} (action={Action})", scriptPath, action);

        var globalToken = GetGlobalToken();
        using var queueCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, globalToken);
        try
        {
            await _semaphore.WaitAsync(queueCts.Token);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            onOutput?.Invoke("[!] Operation cancelled by user");
            LogActionTelemetry(scriptPath, action, CancelledExitCode, 0);
            return CancelledExitCode;
        }

        try
        {
            return await ExecuteScriptAsync(
                scriptPath, action, expectedHash, onOutput, cancellationToken, globalToken);
        }
        finally
        {
            _semaphore.Release();
        }
    }

    internal static ProcessStartInfo BuildScriptProcessStartInfo(
        string scriptPath,
        string? action,
        string? scriptsBaseDir = null,
        string? stateDirectory = null)
    {
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
        }

        psi.Environment["PTW_EMBEDDED"] = "1";
        psi.Environment["PTW_LOG_DIR"] = AppPaths.GetLogsDirectory();
        if (!string.IsNullOrWhiteSpace(scriptsBaseDir))
        {
            if (string.IsNullOrWhiteSpace(stateDirectory))
                throw new InvalidOperationException("Protected state directory was not provided.");

            var baseDir = Path.GetFullPath(scriptsBaseDir);
            var systemDirectory = Environment.SystemDirectory;
            var windowsDirectory = Directory.GetParent(systemDirectory)?.FullName
                ?? throw new InvalidOperationException("Could not resolve the Windows directory.");
            var powerShellDirectory = Path.GetDirectoryName(PowerShellPath)
                ?? throw new InvalidOperationException("Could not resolve the PowerShell directory.");

            psi.WorkingDirectory = baseDir;
            psi.Environment["PTW_SCRIPTS_DIR"] = baseDir;
            psi.Environment["PTW_STATE_DIR"] = Path.GetFullPath(stateDirectory);
            var runtimeDirectory = Path.Combine(baseDir, ".runtime");
            psi.Environment["PTW_RUNTIME_DIR"] = runtimeDirectory;
            psi.Environment["TEMP"] = runtimeDirectory;
            psi.Environment["TMP"] = runtimeDirectory;
            psi.Environment["SystemRoot"] = windowsDirectory;
            psi.Environment["windir"] = windowsDirectory;
            psi.Environment["ComSpec"] = Path.Combine(systemDirectory, "cmd.exe");
            psi.Environment["PATH"] = string.Join(Path.PathSeparator,
                systemDirectory,
                windowsDirectory,
                Path.Combine(systemDirectory, "Wbem"),
                powerShellDirectory);
        }
        // Enable full PowerShell transcripts only for debug builds or explicit opt-in.
#if DEBUG
        psi.Environment["PTW_TRANSCRIPT"] = "1";
#endif
        return psi;
    }

    private async Task<int> ExecuteScriptAsync(
        string scriptPath,
        string? action,
        string expectedHash,
        Action<string>? onOutput,
        CancellationToken cancellationToken,
        CancellationToken globalToken)
    {
        var sw = Stopwatch.StartNew();
        var exitCode = -1;
        // Set only when Stop initiates cancellation.
        var cancelledByUser = false;

        try
        {
            var currentHash = ComputeFileHash(scriptPath);
            if (!string.Equals(expectedHash, currentHash, StringComparison.Ordinal))
            {
                onOutput?.Invoke("ERROR: Script integrity check failed - file was modified between validation and execution");
                _logger.LogError("TOCTOU: Script hash mismatch for {ScriptPath}. Expected={Expected}, Got={Got}", scriptPath, expectedHash, currentHash);
                return -1;
            }

            var psi = BuildScriptProcessStartInfo(
                scriptPath, action, _scriptsBaseDir, AppPaths.GetStateDirectory());
            if (psi.ArgumentList.Contains("-Action"))
                onOutput?.Invoke($"[>] Action: {action}");

            var processKey = $"{scriptPath}_{Interlocked.Increment(ref _keyCounter)}";

            using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, globalToken);

            Process? process = null;
            try
            {
                process = _processRunner.Start(psi);
                _activeProcesses[processKey] = process;

                // Apply one timeout to output reads and process exit.
                using var timeoutCts = new CancellationTokenSource(GetTimeout(action));
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
                    _logger.LogWarning("Process exceeded timeout, forcing: {ScriptPath}", scriptPath);
                    onOutput?.Invoke($"[!] Script exceeded its {GetTimeout(action).TotalMinutes:0}-minute timeout — forcing termination.");
                    try { process.Kill(entireProcessTree: true); } catch { }
                    exitCode = -1;
                }
                catch (OperationCanceledException)
                {
                    onOutput?.Invoke("[!] Operation cancelled by user");
                    try { process.Kill(entireProcessTree: true); } catch { }
                    exitCode = CancelledExitCode;
                    cancelledByUser = true;
                }
                finally
                {
                    // Drain output tasks after timeout or cancellation to observe their exceptions.
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
                // Terminate a started PowerShell process before disposing its handle.
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
            else if (cancelledByUser)
            {
                // Suppress the failure banner only for cancellation initiated by Stop.
                _logger.LogInformation("Script cancelled by user: {ScriptPath}", scriptPath);
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

    internal static TimeSpan GetTimeout(string? action) =>
        action != null && LongRunningActions.Contains(action)
            ? TimeSpan.FromMinutes(45)
            : TimeSpan.FromMinutes(10);

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
                // Use relative-path semantics to reject sibling directories with matching prefixes.
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
            _activityLogger.LogInformation("{@LocalActivity}", msg);
        else
            _activityLogger.LogWarning("{@LocalActivity}", msg);
    }

    // Cache embedded script checksums by normalized manifest path.
    private static readonly Lazy<IReadOnlyDictionary<string, string>> ManifestHashes =
        new(LoadManifestHashes);

    internal static IReadOnlyDictionary<string, string> LoadManifestHashes()
    {
        var assembly = Assembly.GetExecutingAssembly();
        var resourceName = assembly.GetManifestResourceNames()
            .FirstOrDefault(n => n.EndsWith("Scripts.file-checksums.json", StringComparison.OrdinalIgnoreCase))
            ?? throw new InvalidOperationException("Embedded checksum manifest not found: file-checksums.json");

        using var stream = assembly.GetManifestResourceStream(resourceName)
            ?? throw new InvalidOperationException("Embedded checksum manifest stream was null: file-checksums.json");
        using var doc = JsonDocument.Parse(stream);

        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (doc.RootElement.TryGetProperty("scripts", out var scripts) && scripts.ValueKind == JsonValueKind.Object)
        {
            foreach (var entry in scripts.EnumerateObject())
            {
                var hash = entry.Value.GetString();
                if (!string.IsNullOrWhiteSpace(hash))
                    map[entry.Name] = hash.ToLowerInvariant();
            }
        }
        return map;
    }

    // Relative path of an extracted script as it appears in the manifest (forward slashes).
    internal static string? ToManifestKey(string scriptsBaseDir, string scriptPath)
    {
        try
        {
            var rel = Path.GetRelativePath(Path.GetFullPath(scriptsBaseDir), Path.GetFullPath(scriptPath));
            if (rel.StartsWith("..", StringComparison.Ordinal) || Path.IsPathRooted(rel)) return null;
            return rel.Replace('\\', '/');
        }
        catch { return null; }
    }

    private string? GetManifestHashForScript(string scriptPath)
    {
        var baseDir = _scriptsBaseDir;
        if (baseDir == null) return null;
        var key = ToManifestKey(baseDir, scriptPath);
        if (key == null) return null;
        try
        {
            return ManifestHashes.Value.TryGetValue(key, out var hash) ? hash : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to load embedded checksum manifest");
            return null;
        }
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
        // Cancel operations without disposing synchronization objects still used by in-flight tasks.
        lock (_ctsLock)
        {
            _globalCts.Cancel();
        }
    }

    public void Dispose()
    {
        Shutdown();
        _semaphore.Dispose();
        lock (_ctsLock)
        {
            _globalCts.Dispose();
        }
    }

    // Use absolute anchors so action IDs with trailing newlines are rejected.
    [GeneratedRegex(@"\A[A-Za-z0-9_-]{2,64}\z")]
    private static partial Regex ActionIdRegex();
}
