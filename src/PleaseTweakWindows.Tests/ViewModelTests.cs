using System.Collections.Immutable;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using PleaseTweakWindows.Models;
using PleaseTweakWindows.Services;
using PleaseTweakWindows.ViewModels;
using Xunit;

namespace PleaseTweakWindows.Tests;

public class ViewModelTests
{
    [Fact]
    public async Task SubTweakApply_NonZeroExit_SetsVisibleErrorAndClearsRunningState()
    {
        var executor = new Mock<IScriptExecutor>();
        executor.Setup(e => e.RunScriptAsync(
                It.IsAny<string>(), "test-apply", It.IsAny<Action<string>?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(7);
        var dialogs = new Mock<IDialogService>();
        dialogs.Setup(d => d.ShowRestorePointPromptAsync())
            .ReturnsAsync(RestorePointDecision.Skip);
        var guard = new RestorePointGuard(dialogs.Object, executor.Object, NullLoggerFactory.Instance);
        var globallyRunning = false;
        string? error = null;
        var model = new SubTweak(
            "Test tweak", SubTweakType.Toggle, "test-apply", "test-restore", "Test");
        var viewModel = new SubTweakViewModel(
            model, "apply.ps1", "restore.ps1", "scripts",
            executor.Object, dialogs.Object, guard, new LogPanelViewModel(),
            () => globallyRunning, value => globallyRunning = value, value => error = value);

        await viewModel.ApplyCommand.ExecuteAsync(null);

        error.Should().Contain("failed (exit 7)");
        viewModel.IsRunning.Should().BeFalse();
        globallyRunning.Should().BeFalse();
    }

    [Fact]
    public void LogPanel_BoundsRenderedLinesInOneTrimChunk()
    {
        var viewModel = new LogPanelViewModel();

        for (var i = 0; i <= 5000; i++)
            viewModel.AppendLine($"line-{i}");

        viewModel.Lines.Should().HaveCount(3751);
        viewModel.Lines[0].Text.Should().Be("line-1250");
        viewModel.Lines[^1].Text.Should().Be("line-5000");
    }

    [Fact]
    public void CategoryFilter_MatchesTitleNameAndDescription()
    {
        var executor = new Mock<IScriptExecutor>();
        var dialogs = new Mock<IDialogService>();
        var guard = new RestorePointGuard(dialogs.Object, executor.Object, NullLoggerFactory.Instance);
        var model = new Tweak(
            "Network Tools",
            "network.ps1",
            ImmutableList.Create(new SubTweak(
                "Disable Example", "example-disable", "Stops a sample component")));
        var viewModel = new TweakCategoryViewModel(
            model, "scripts", executor.Object, dialogs.Object, guard, new LogPanelViewModel(),
            () => false, _ => { }, _ => { });

        viewModel.MatchesFilter("network").Should().BeTrue();
        viewModel.MatchesFilter("example").Should().BeTrue();
        viewModel.MatchesFilter("sample component").Should().BeTrue();
        viewModel.MatchesFilter("unrelated").Should().BeFalse();
    }
}
