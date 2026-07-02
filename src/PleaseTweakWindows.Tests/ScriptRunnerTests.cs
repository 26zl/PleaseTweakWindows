using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using PleaseTweakWindows.Services;
using PleaseTweakWindows.ViewModels;
using Xunit;

namespace PleaseTweakWindows.Tests;

/// <summary>Covers restore-point and confirmation ordering before script execution.</summary>
public class ScriptRunnerTests
{
    private readonly Mock<IScriptExecutor> _executor = new();
    private readonly Mock<IDialogService> _dialog = new();

    private RestorePointGuard Guard() =>
        new(_dialog.Object, _executor.Object, NullLoggerFactory.Instance);

    private Task<ScriptRunResult> Run(bool ensureRestorePoint = true, bool skipConfirmation = false) =>
        ScriptRunner.RunAsync(
            "script.ps1", "some-action", "Some Tweak", "dir",
            _executor.Object, _dialog.Object, Guard(), new LogPanelViewModel(),
            ensureRestorePoint: ensureRestorePoint, skipConfirmation: skipConfirmation);

    private void SetupExecutor(int exitCode) =>
        _executor.Setup(e => e.RunScriptAsync(It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<Action<string>?>(), It.IsAny<CancellationToken>()))
                 .ReturnsAsync(exitCode);

    [Fact]
    public async Task RestorePointDeclined_ShortCircuits_WithoutRunningScript()
    {
        _dialog.Setup(d => d.ShowRestorePointPromptAsync()).ReturnsAsync(RestorePointDecision.Cancel);

        var result = await Run(ensureRestorePoint: true);

        result.Outcome.Should().Be(ScriptRunOutcome.RestorePointCancelled);
        _executor.Verify(e => e.RunScriptAsync(It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<Action<string>?>(), It.IsAny<CancellationToken>()),
            Times.Never, "a declined restore point must block the tweak");
    }

    [Fact]
    public async Task RestorePointCreationFails_ReturnsRestorePointFailed_WithoutRunningTweak()
    {
        _dialog.Setup(d => d.ShowRestorePointPromptAsync()).ReturnsAsync(RestorePointDecision.Create);
        // The only executor call that should happen is the restore-point script itself, which fails.
        SetupExecutor(1);

        var result = await Run(ensureRestorePoint: true);

        result.Outcome.Should().Be(ScriptRunOutcome.RestorePointFailed);
        _executor.Verify(e => e.RunScriptAsync(It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<Action<string>?>(), It.IsAny<CancellationToken>()),
            Times.Once, "only the restore-point script runs; the tweak must not run after a failed restore point");
    }

    [Fact]
    public async Task ConfirmationDeclined_ShortCircuits_WithoutRunningScript()
    {
        _dialog.Setup(d => d.RequiresConfirmation("some-action")).Returns(true);
        _dialog.Setup(d => d.ShowConfirmationAsync("some-action", It.IsAny<string>())).ReturnsAsync(false);

        var result = await Run(ensureRestorePoint: false);

        result.Outcome.Should().Be(ScriptRunOutcome.ConfirmationCancelled);
        _executor.Verify(e => e.RunScriptAsync(It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<Action<string>?>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task SkipConfirmation_BypassesPerActionPrompt()
    {
        _dialog.Setup(d => d.RequiresConfirmation("some-action")).Returns(true);
        SetupExecutor(0);

        var result = await Run(ensureRestorePoint: false, skipConfirmation: true);

        result.Outcome.Should().Be(ScriptRunOutcome.Applied);
        result.ExitCode.Should().Be(0);
        _dialog.Verify(d => d.ShowConfirmationAsync(It.IsAny<string>(), It.IsAny<string>()), Times.Never,
            "a confirmed batch must not re-prompt per action");
    }

    [Fact]
    public async Task UserCancelledScript_MapsToCancelledOutcome_NotFailure()
    {
        SetupExecutor(ScriptExecutor.CancelledExitCode);

        var result = await Run(ensureRestorePoint: false, skipConfirmation: true);

        result.Outcome.Should().Be(ScriptRunOutcome.Cancelled,
            "a user Stop must not be reported as a script failure");
    }

    [Fact]
    public async Task NonZeroExit_IsAppliedWithExitCode()
    {
        SetupExecutor(5);

        var result = await Run(ensureRestorePoint: false, skipConfirmation: true);

        result.Outcome.Should().Be(ScriptRunOutcome.Applied);
        result.ExitCode.Should().Be(5);
    }
}
