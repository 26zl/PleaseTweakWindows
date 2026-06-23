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
        var result = await _executor.RunScriptAsync("invalid.txt", null, line => output.Add(line));

        result.Should().Be(-1);
        output.Should().Contain(s => s.Contains("Invalid script path"));
    }

    [Fact]
    public async Task RunScriptAsync_RejectsNonexistentScript()
    {
        var output = new List<string>();
        var result = await _executor.RunScriptAsync("nonexistent.ps1", null, line => output.Add(line));

        result.Should().Be(-1);
        output.Should().Contain(s => s.Contains("Script not found"));
    }

    [Fact]
    public async Task RunScriptAsync_RejectsInvalidAction()
    {
        var tempFile = Path.Combine(Path.GetTempPath(), "test-valid.ps1");
        await File.WriteAllTextAsync(tempFile, "# test");

        try
        {
            var output = new List<string>();
            var result = await _executor.RunScriptAsync(tempFile, "bad action!", line => output.Add(line));

            result.Should().Be(-1);
            output.Should().Contain(s => s.Contains("Invalid action"));
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

    [Fact]
    public async Task RunScriptAsync_AbortsOnHashMismatch_TOCTOU()
    {
        // RunScriptAsync hashes the file once up front, then ExecuteScriptAsync
        // re-hashes it and aborts if the file changed. The onOutput callback for
        // "> Starting:" fires AFTER the first hash and BEFORE the re-hash, giving us
        // a deterministic seam to mutate the file mid-flight and trigger the TOCTOU
        // abort branch without ever reaching the process-launch code.
        var tempFile = Path.Combine(Path.GetTempPath(), $"toctou-{Guid.NewGuid():N}.ps1");
        await File.WriteAllTextAsync(tempFile, "# original content");

        try
        {
            var output = new List<string>();
            var mutated = false;

            void OnOutput(string line)
            {
                output.Add(line);
                // Mutate the file exactly once, on the first callback (the "> Starting:"
                // line), which lands between the two hash computations.
                if (!mutated)
                {
                    mutated = true;
                    File.WriteAllText(tempFile, "# TAMPERED content - injected after validation");
                }
            }

            var result = await _executor.RunScriptAsync(tempFile, null, OnOutput);

            result.Should().Be(-1, "a hash mismatch between validation and execution must abort the script");
            output.Should().Contain(s => s.Contains("integrity check failed"));
            // The process must never be launched once integrity fails.
            _mockRunner.Verify(r => r.Start(It.IsAny<System.Diagnostics.ProcessStartInfo>()), Times.Never);
            _executor.HasActiveOperations.Should().BeFalse();
        }
        finally
        {
            File.Delete(tempFile);
        }
    }

    [Fact]
    public async Task RunScriptAsync_HonorsAlreadyCancelledToken()
    {
        // A token cancelled before the semaphore is acquired must short-circuit:
        // _semaphore.WaitAsync(cancellationToken) throws OperationCanceledException
        // and the process is never started.
        var tempFile = Path.Combine(Path.GetTempPath(), $"cancel-{Guid.NewGuid():N}.ps1");
        await File.WriteAllTextAsync(tempFile, "# test");

        try
        {
            using var cts = new CancellationTokenSource();
            cts.Cancel();

            var act = async () => await _executor.RunScriptAsync(tempFile, null, null, cts.Token);

            await act.Should().ThrowAsync<OperationCanceledException>();
            _mockRunner.Verify(r => r.Start(It.IsAny<System.Diagnostics.ProcessStartInfo>()), Times.Never);
            _executor.HasActiveOperations.Should().BeFalse();
        }
        finally
        {
            File.Delete(tempFile);
        }
    }

    [Fact]
    public void CancelAllOperations_ClearsActiveStateAndRotatesToken()
    {
        // With no active processes, CancelAllOperations must still be safe to call,
        // leave HasActiveOperations false, and not throw. This guards the global-CTS
        // swap + _activeProcesses.Clear() path used by "Cancel All".
        _executor.HasActiveOperations.Should().BeFalse();

        var act = () => _executor.CancelAllOperations();

        act.Should().NotThrow();
        _executor.HasActiveOperations.Should().BeFalse();
        // Idempotent: a second call is still safe.
        _executor.CancelAllOperations();
        _executor.HasActiveOperations.Should().BeFalse();
    }
}
