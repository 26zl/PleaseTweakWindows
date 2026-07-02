using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using PleaseTweakWindows.Services;
using Xunit;

namespace PleaseTweakWindows.Tests;

public class RestorePointGuardTests
{
    private readonly Mock<IDialogService> _dialog = new();
    private readonly Mock<IScriptExecutor> _executor = new();

    private RestorePointGuard Build() =>
        new(_dialog.Object, _executor.Object, NullLoggerFactory.Instance);

    private void SetupPrompt(RestorePointDecision decision) =>
        _dialog.Setup(d => d.ShowRestorePointPromptAsync())
               .ReturnsAsync(decision);

    private void SetupScriptExit(int exitCode) =>
        _executor.Setup(e => e.RunScriptAsync(It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<Action<string>?>(), It.IsAny<CancellationToken>()))
                 .ReturnsAsync(exitCode);

    [Fact]
    public async Task Create_Succeeds_ReturnsTrueAndCaches()
    {
        SetupPrompt(RestorePointDecision.Create);
        SetupScriptExit(0);
        var guard = Build();

        var first = await guard.EnsureRestorePointAsync("C:\\scripts", null,
            cancellationToken: TestContext.Current.CancellationToken);
        var second = await guard.EnsureRestorePointAsync("C:\\scripts", null,
            cancellationToken: TestContext.Current.CancellationToken);

        first.Should().BeTrue();
        second.Should().BeTrue();
        _dialog.Verify(d => d.ShowRestorePointPromptAsync(), Times.Once,
            "second call should use cached decision, not re-prompt");
    }

    [Fact]
    public async Task Create_Fails_ReturnsFalseAndDoesNotCache()
    {
        SetupPrompt(RestorePointDecision.Create);
        SetupScriptExit(1);
        var guard = Build();

        var first = await guard.EnsureRestorePointAsync("C:\\scripts", null,
            cancellationToken: TestContext.Current.CancellationToken);

        first.Should().BeFalse("restore point creation failed — destructive tweak must be blocked");

        // Reset the executor mock so a subsequent attempt can succeed.
        SetupScriptExit(0);
        var second = await guard.EnsureRestorePointAsync("C:\\scripts", null,
            cancellationToken: TestContext.Current.CancellationToken);

        second.Should().BeTrue();
        _dialog.Verify(d => d.ShowRestorePointPromptAsync(), Times.Exactly(2),
            "failed attempt must NOT cache; user should be re-prompted on next tweak");
    }

    [Fact]
    public async Task Create_WritesErrorToOutput_OnFailure()
    {
        SetupPrompt(RestorePointDecision.Create);
        SetupScriptExit(1);
        var guard = Build();
        var output = new List<string>();

        await guard.EnsureRestorePointAsync("C:\\scripts", line => output.Add(line),
            cancellationToken: TestContext.Current.CancellationToken);

        output.Should().Contain(s => s.Contains("Restore point creation failed", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task Skip_ReturnsTrueAndCaches()
    {
        SetupPrompt(RestorePointDecision.Skip);
        var guard = Build();

        var first = await guard.EnsureRestorePointAsync("C:\\scripts", null,
            cancellationToken: TestContext.Current.CancellationToken);
        var second = await guard.EnsureRestorePointAsync("C:\\scripts", null,
            cancellationToken: TestContext.Current.CancellationToken);

        first.Should().BeTrue();
        second.Should().BeTrue();
        _dialog.Verify(d => d.ShowRestorePointPromptAsync(), Times.Once,
            "Skip should cache; user should not be re-prompted");
        _executor.Verify(e => e.RunScriptAsync(It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<Action<string>?>(), It.IsAny<CancellationToken>()),
            Times.Never, "Skip must not invoke the restore-point script");
    }

    [Fact]
    public async Task Skip_LowRisk_DoesNotCarryIntoHighRisk_ThenAcknowledged()
    {
        SetupPrompt(RestorePointDecision.Skip);
        var guard = Build();

        // Low-risk skip is honoured for low-risk work...
        (await guard.EnsureRestorePointAsync("C:\\scripts", null, isHighRisk: false,
            cancellationToken: TestContext.Current.CancellationToken)).Should().BeTrue();
        (await guard.EnsureRestorePointAsync("C:\\scripts", null, isHighRisk: false,
            cancellationToken: TestContext.Current.CancellationToken)).Should().BeTrue();
        _dialog.Verify(d => d.ShowRestorePointPromptAsync(), Times.Once,
            "a low-risk skip should cache for subsequent low-risk tweaks");

        // ...but the FIRST high-risk tweak after a low-risk skip must re-prompt.
        (await guard.EnsureRestorePointAsync("C:\\scripts", null, isHighRisk: true,
            cancellationToken: TestContext.Current.CancellationToken)).Should().BeTrue();
        _dialog.Verify(d => d.ShowRestorePointPromptAsync(), Times.Exactly(2),
            "a casual low-risk skip must not silently carry into a high-risk change");

        // Honour a high-risk skip for later high-risk tweaks.
        (await guard.EnsureRestorePointAsync("C:\\scripts", null, isHighRisk: true,
            cancellationToken: TestContext.Current.CancellationToken)).Should().BeTrue();
        _dialog.Verify(d => d.ShowRestorePointPromptAsync(), Times.Exactly(2),
            "after acknowledging a high-risk skip, further high-risk tweaks should not re-prompt");
    }

    [Fact]
    public async Task Cancel_ReturnsFalseAndDoesNotCache()
    {
        SetupPrompt(RestorePointDecision.Cancel);
        var guard = Build();

        var first = await guard.EnsureRestorePointAsync("C:\\scripts", null,
            cancellationToken: TestContext.Current.CancellationToken);
        var second = await guard.EnsureRestorePointAsync("C:\\scripts", null,
            cancellationToken: TestContext.Current.CancellationToken);

        first.Should().BeFalse();
        second.Should().BeFalse();
        _dialog.Verify(d => d.ShowRestorePointPromptAsync(), Times.Exactly(2),
            "Cancel should not be cached — user should get another chance next tweak");
    }

    [Fact]
    public async Task MarkCreated_SkipsPromptOnNextCall()
    {
        var guard = Build();
        guard.MarkCreated();

        var result = await guard.EnsureRestorePointAsync("C:\\scripts", null,
            cancellationToken: TestContext.Current.CancellationToken);

        result.Should().BeTrue();
        _dialog.Verify(d => d.ShowRestorePointPromptAsync(), Times.Never);
        _executor.Verify(e => e.RunScriptAsync(It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<Action<string>?>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }
}
