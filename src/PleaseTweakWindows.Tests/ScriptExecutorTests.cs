using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using PleaseTweakWindows.Services;
using Xunit;

namespace PleaseTweakWindows.Tests;

public class ScriptExecutorTests
{
    private readonly Mock<IProcessRunner> _mockRunner = new();
    private readonly ScriptExecutor _executor;

    public ScriptExecutorTests()
    {
        _executor = new ScriptExecutor(_mockRunner.Object, NullLoggerFactory.Instance);
    }

    [Theory]
    [InlineData("nvidia-settings-on", true)]
    [InlineData("p0-state-default", true)]
    [InlineData("services-disable", true)]
    [InlineData("Menu", true)]
    [InlineData("ab", true)]
    [InlineData("a-b_c-123", true)]
    [InlineData("a", false)]
    [InlineData("", false)]
    [InlineData("has spaces", false)]
    [InlineData("has;semicolons", false)]
    [InlineData("has|pipe", false)]
    public void IsValidAction_ValidatesCorrectly(string action, bool expected)
    {
        _executor.IsValidAction(action).Should().Be(expected);
    }

    [Fact]
    public void IsValidAction_RejectsControlCharsAndOverLength()
    {
        // Reject action IDs with trailing line breaks.
        _executor.IsValidAction("trailing-newline\n").Should().BeFalse();
        _executor.IsValidAction("trailing-cr\r").Should().BeFalse();
        _executor.IsValidAction("mid\nnewline").Should().BeFalse();
        // Length floor/ceiling.
        _executor.IsValidAction(new string('a', 64)).Should().BeTrue();
        _executor.IsValidAction(new string('a', 65)).Should().BeFalse();
    }

    [Theory]
    [InlineData(null, false)]
    [InlineData("", false)]
    [InlineData("   ", false)]
    [InlineData("test.ps1", true)]
    [InlineData("test.txt", false)]
    [InlineData("..\\escape.ps1", false)]
    [InlineData("path\\..\\escape.ps1", false)]
    [InlineData("normal\\script.ps1", true)]
    [InlineData("script;inject.ps1", false)]
    [InlineData("script|inject.ps1", false)]
    [InlineData("script&inject.ps1", false)]
    public void IsValidScriptPath_ValidatesCorrectly(string? scriptPath, bool expected)
    {
        _executor.IsValidScriptPath(scriptPath).Should().Be(expected);
    }

    [Fact]
    public void IsValidScriptPath_RejectsPathOutsideBaseDir()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), "test-scripts");
        Directory.CreateDirectory(tempDir);

        try
        {
            _executor.SetScriptsBaseDir(tempDir);

            var validPath = Path.Combine(tempDir, "test.ps1");
            _executor.IsValidScriptPath(validPath).Should().BeTrue();

            var outsidePath = Path.Combine(Path.GetTempPath(), "outside.ps1");
            _executor.IsValidScriptPath(outsidePath).Should().BeFalse();
        }
        finally
        {
            Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void IsValidScriptPath_RejectsSiblingPrefixAttack()
    {
        var baseDir = Path.Combine(Path.GetTempPath(), "base-scripts");
        var siblingDir = Path.Combine(Path.GetTempPath(), "base-scripts-evil");
        Directory.CreateDirectory(baseDir);
        Directory.CreateDirectory(siblingDir);

        try
        {
            _executor.SetScriptsBaseDir(baseDir);

            // A prefix-based check would accept this path because it starts with baseDir.
            var attackPath = Path.Combine(siblingDir, "payload.ps1");
            _executor.IsValidScriptPath(attackPath).Should().BeFalse();
        }
        finally
        {
            Directory.Delete(baseDir, true);
            Directory.Delete(siblingDir, true);
        }
    }

    [Fact]
    public async Task RunScriptAsync_RejectsInvalidPath()
    {
        var output = new List<string>();
        var result = await _executor.RunScriptAsync("invalid.txt", null, line => output.Add(line),
            TestContext.Current.CancellationToken);

        result.Should().Be(-1);
        output.Should().Contain(s => s.Contains("Invalid script path"));
    }

    [Fact]
    public async Task RunScriptAsync_RejectsNonexistentScript()
    {
        var output = new List<string>();
        var result = await _executor.RunScriptAsync("nonexistent.ps1", null, line => output.Add(line),
            TestContext.Current.CancellationToken);

        result.Should().Be(-1);
        output.Should().Contain(s => s.Contains("Script not found"));
    }

    [Fact]
    public async Task RunScriptAsync_RejectsInvalidAction()
    {
        var tempFile = Path.Combine(Path.GetTempPath(), "test-valid.ps1");
        await File.WriteAllTextAsync(tempFile, "# test", TestContext.Current.CancellationToken);

        try
        {
            var output = new List<string>();
            var result = await _executor.RunScriptAsync(tempFile, "bad action!", line => output.Add(line),
                TestContext.Current.CancellationToken);

            result.Should().Be(-1);
            output.Should().Contain(s => s.Contains("Invalid action"));
        }
        finally
        {
            File.Delete(tempFile);
        }
    }

    [Fact]
    public async Task RunScriptAsync_RejectsWhenBaseDirNotSet()
    {
        // Refuse execution until the scripts base directory is configured.
        var tempFile = Path.Combine(Path.GetTempPath(), $"nobase-{Guid.NewGuid():N}.ps1");
        await File.WriteAllTextAsync(tempFile, "# test", TestContext.Current.CancellationToken);
        try
        {
            var output = new List<string>();
            var result = await _executor.RunScriptAsync(tempFile, null, line => output.Add(line),
                TestContext.Current.CancellationToken);

            result.Should().Be(-1);
            output.Should().Contain(s => s.Contains("base directory not initialized", StringComparison.OrdinalIgnoreCase));
            _mockRunner.Verify(r => r.Start(It.IsAny<System.Diagnostics.ProcessStartInfo>()), Times.Never);
        }
        finally
        {
            File.Delete(tempFile);
        }
    }

    [Fact]
    public void ComputeFileHash_ReturnsConsistentHash()
    {
        var tempFile = Path.Combine(Path.GetTempPath(), "hash-test.ps1");
        File.WriteAllText(tempFile, "test content");

        try
        {
            var hash1 = ScriptExecutor.ComputeFileHash(tempFile);
            var hash2 = ScriptExecutor.ComputeFileHash(tempFile);

            hash1.Should().NotBeNull();
            hash2.Should().NotBeNull();
            hash1.Should().Be(hash2);
            hash1!.Length.Should().Be(64);
        }
        finally
        {
            File.Delete(tempFile);
        }
    }

    [Fact]
    public void ComputeFileHash_ReturnsNullForMissingFile()
    {
        ScriptExecutor.ComputeFileHash("nonexistent_file.ps1").Should().BeNull();
    }

    [Fact]
    public void GetPowerShellPath_ReturnsValidPath()
    {
        var path = ScriptExecutor.GetPowerShellPath();
        path.Should().EndWith("powershell.exe");
        path.Should().Contain("WindowsPowerShell");
    }

    // Materialize an embedded script that matches the checksum manifest.
    private static (string baseDir, string scriptPath) MaterializeEmbeddedScript(string relativePath = "CommonFunctions.ps1")
    {
        var asm = typeof(ScriptExecutor).Assembly;
        var suffix = "Scripts." + relativePath.Replace('/', '.').Replace('\\', '.').Replace(' ', '_');
        var name = asm.GetManifestResourceNames()
            .First(n => n.EndsWith(suffix, StringComparison.OrdinalIgnoreCase));

        var baseDir = Path.Combine(Path.GetTempPath(), $"ptw-test-{Guid.NewGuid():N}");
        var dest = Path.Combine(baseDir, relativePath.Replace('/', Path.DirectorySeparatorChar));
        Directory.CreateDirectory(Path.GetDirectoryName(dest)!);
        using (var s = asm.GetManifestResourceStream(name)!)
        using (var fs = File.Create(dest))
            s.CopyTo(fs);
        return (baseDir, dest);
    }

    [Fact]
    public async Task RunScriptAsync_AbortsOnHashMismatch_TOCTOU()
    {
        // Mutate a valid script between its initial and execution-time integrity checks.
        var (baseDir, scriptPath) = MaterializeEmbeddedScript();

        try
        {
            var output = new List<string>();
            var mutated = false;

            void OnOutput(string line)
            {
                output.Add(line);
                // Mutate once after the initial integrity check.
                if (!mutated)
                {
                    mutated = true;
                    File.WriteAllText(scriptPath, "# TAMPERED content - injected after validation");
                }
            }

            _executor.SetScriptsBaseDir(baseDir);
            var result = await _executor.RunScriptAsync(scriptPath, null, OnOutput,
                TestContext.Current.CancellationToken);

            result.Should().Be(-1, "a hash mismatch between validation and execution must abort the script");
            output.Should().Contain(s => s.Contains("integrity check failed"));
            // The process must never be launched once integrity fails.
            _mockRunner.Verify(r => r.Start(It.IsAny<System.Diagnostics.ProcessStartInfo>()), Times.Never);
            _executor.HasActiveOperations.Should().BeFalse();
        }
        finally
        {
            Directory.Delete(baseDir, true);
        }
    }

    [Fact]
    public async Task RunScriptAsync_RejectsScriptNotInManifest()
    {
        // Refuse scripts that are absent from the embedded checksum manifest.
        var baseDir = Path.Combine(Path.GetTempPath(), $"ptw-test-{Guid.NewGuid():N}");
        Directory.CreateDirectory(baseDir);
        var rogue = Path.Combine(baseDir, "not-a-real-script.ps1");
        await File.WriteAllTextAsync(rogue, "# unknown payload", TestContext.Current.CancellationToken);

        try
        {
            _executor.SetScriptsBaseDir(baseDir);
            var output = new List<string>();
            var result = await _executor.RunScriptAsync(rogue, null, line => output.Add(line),
                TestContext.Current.CancellationToken);

            result.Should().Be(-1);
            output.Should().Contain(s => s.Contains("not in embedded checksum manifest", StringComparison.OrdinalIgnoreCase));
            _mockRunner.Verify(r => r.Start(It.IsAny<System.Diagnostics.ProcessStartInfo>()), Times.Never);
        }
        finally
        {
            Directory.Delete(baseDir, true);
        }
    }

    [Fact]
    public async Task RunScriptAsync_HonorsAlreadyCancelledToken()
    {
        // Short-circuit when cancellation occurs before semaphore acquisition.
        var (baseDir, scriptPath) = MaterializeEmbeddedScript();

        try
        {
            using var cts = new CancellationTokenSource();
            cts.Cancel();

            _executor.SetScriptsBaseDir(baseDir);
            var act = async () => await _executor.RunScriptAsync(scriptPath, null, null, cts.Token);

            await act.Should().ThrowAsync<OperationCanceledException>();
            _mockRunner.Verify(r => r.Start(It.IsAny<System.Diagnostics.ProcessStartInfo>()), Times.Never);
            _executor.HasActiveOperations.Should().BeFalse();
        }
        finally
        {
            Directory.Delete(baseDir, true);
        }
    }

    [Fact]
    public void LoadManifestHashes_ContainsKnownScriptsAsLowercaseSha256()
    {
        var map = ScriptExecutor.LoadManifestHashes();

        map.Should().ContainKey("CommonFunctions.ps1");
        map.Should().ContainKey("Privacy Security/revert-privacy.ps1");
        // Hashes are normalized to lowercase 64-hex so they compare against ComputeFileHash.
        map["CommonFunctions.ps1"].Should().MatchRegex("^[0-9a-f]{64}$");
    }

    [Theory]
    [InlineData(@"C:\extract", @"C:\extract\CommonFunctions.ps1", "CommonFunctions.ps1")]
    [InlineData(@"C:\extract", @"C:\extract\Privacy Security\revert-privacy.ps1", "Privacy Security/revert-privacy.ps1")]
    [InlineData(@"C:\extract", @"C:\other\evil.ps1", null)]
    public void ToManifestKey_NormalizesToForwardSlashRelativePath(string baseDir, string scriptPath, string? expected)
    {
        ScriptExecutor.ToManifestKey(baseDir, scriptPath).Should().Be(expected);
    }

    [Fact]
    public void CancelAllOperations_ClearsActiveStateAndRotatesToken()
    {
        // Allow cancellation when no processes are active.
        _executor.HasActiveOperations.Should().BeFalse();

        var act = () => _executor.CancelAllOperations();

        act.Should().NotThrow();
        _executor.HasActiveOperations.Should().BeFalse();
        // Idempotent: a second call is still safe.
        _executor.CancelAllOperations();
        _executor.HasActiveOperations.Should().BeFalse();
    }

    [Fact]
    public void ConsolidatedScripts_AllExistAsEmbeddedResources()
    {
        // Every action-dispatch script must map to a shipped embedded resource.
        var resources = typeof(ScriptExecutor).Assembly.GetManifestResourceNames();

        foreach (var name in ScriptExecutor.ConsolidatedScripts)
        {
            resources.Should().Contain(
                r => r.EndsWith("." + name, StringComparison.OrdinalIgnoreCase),
                $"consolidated script '{name}' must exist as an embedded resource (a rename silently drops its -Action argument)");
        }
    }

    [Fact]
    public void ConsolidatedScripts_CoversEveryRegistryScript()
    {
        // Registry-routed scripts must receive the -Action argument.
        var registry = new TweakRegistry();

        var registryScripts = registry.GetTweaks()
            .SelectMany(t => new[] { t.ApplyScript, t.RevertScript })
            .Select(Path.GetFileName)
            .Where(n => !string.IsNullOrEmpty(n))
            .Distinct(StringComparer.OrdinalIgnoreCase);

        foreach (var name in registryScripts)
        {
            ScriptExecutor.ConsolidatedScripts
                .Contains(name!, StringComparer.OrdinalIgnoreCase)
                .Should().BeTrue(
                    $"registry script '{name}' must be listed in ScriptExecutor.ConsolidatedScripts so it receives its -Action argument (a rename silently drops it otherwise)");
        }
    }

    // Consolidated scripts receive the action and the protected embedded-mode paths.
    [Fact]
    public void BuildPsi_ConsolidatedScript_IncludesActionAndEmbeddedEnv()
    {
        var psi = ScriptExecutor.BuildScriptProcessStartInfo(
            @"C:\extract\privacy.ps1", "telemetry-off", @"C:\extract", @"C:\protected-state");

        psi.ArgumentList.Should().ContainInOrder("-File", @"C:\extract\privacy.ps1");
        psi.ArgumentList.Should().ContainInOrder("-Action", "telemetry-off");
        psi.Environment["PTW_EMBEDDED"].Should().Be("1");
        psi.Environment.Should().ContainKey("PTW_LOG_DIR");
        psi.Environment.Should().ContainKey("PTW_STATE_DIR");
        psi.Environment["PTW_STATE_DIR"].Should().Be(Path.GetFullPath(@"C:\protected-state"));
        psi.Environment["PTW_SCRIPTS_DIR"].Should().Be(Path.GetFullPath(@"C:\extract"));
        psi.Environment["PTW_RUNTIME_DIR"].Should().Be(
            Path.Combine(Path.GetFullPath(@"C:\extract"), ".runtime"));
        psi.Environment["TEMP"].Should().Be(psi.Environment["PTW_RUNTIME_DIR"]);
        psi.Environment["TMP"].Should().Be(psi.Environment["PTW_RUNTIME_DIR"]);
        psi.WorkingDirectory.Should().Be(Path.GetFullPath(@"C:\extract"));
        psi.Environment["PATH"].Should().NotBeNullOrWhiteSpace();
        psi.Environment["ComSpec"].Should().EndWith("cmd.exe");
        psi.UseShellExecute.Should().BeFalse();
    }

    [Fact]
    public void BuildPsi_NonConsolidatedScript_OmitsAction()
    {
        // create_restore_point.ps1 is the one script that intentionally runs WITHOUT -Action.
        var psi = ScriptExecutor.BuildScriptProcessStartInfo(@"C:\extract\create_restore_point.ps1", "anything");

        psi.ArgumentList.Should().NotContain("-Action");
        psi.ArgumentList.Should().NotContain("anything");
    }

    [Fact]
    public void BuildPsi_AlwaysHardensInvocation_AndNullActionOmitsAction()
    {
        var psi = ScriptExecutor.BuildScriptProcessStartInfo(@"C:\extract\privacy.ps1", null);

        psi.ArgumentList.Should().ContainInOrder(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File");
        // null action → no -Action even for a consolidated script.
        psi.ArgumentList.Should().NotContain("-Action");
    }

    [Fact]
    public void InstallerActions_GetLongerTimeout()
    {
        ScriptExecutor.GetTimeout("nvidia-driver-install").Should().Be(TimeSpan.FromMinutes(45));
        ScriptExecutor.GetTimeout("telemetry-off").Should().Be(TimeSpan.FromMinutes(10));
    }
}
