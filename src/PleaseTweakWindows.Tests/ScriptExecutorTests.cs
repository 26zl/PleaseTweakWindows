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
}
