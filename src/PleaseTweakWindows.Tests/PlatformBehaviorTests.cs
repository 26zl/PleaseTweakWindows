using System.Xml.Linq;
using FluentAssertions;
using PleaseTweakWindows.Services;
using PleaseTweakWindows.Themes;
using PleaseTweakWindows.ViewModels;
using Xunit;

namespace PleaseTweakWindows.Tests;

public class PlatformBehaviorTests
{
    [Fact]
    public void LogsDirectory_IsRedirectedAwayFromLocalAppDataDuringTests()
    {
        var logs = AppPaths.GetLogsDirectory();
        var userFolder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), AppPaths.ProductName);

        logs.Should().StartWith(Path.GetTempPath());
        logs.Should().NotStartWith(userFolder);
        Directory.Exists(logs).Should().BeTrue();
    }

    [Fact]
    public void BuildPsi_PassesTheRedirectedLogsDirectory()
    {
        var psi = ScriptExecutor.BuildScriptProcessStartInfo(@"C:\extract\privacy.ps1", "telemetry-off");

        psi.Environment["PTW_LOG_DIR"].Should().Be(AppPaths.GetLogsDirectory());
    }

    [Fact]
    public void OpenUrl_GoesThroughExplorerSoTheBrowserIsNotElevated()
    {
        const string url = "https://github.com/26zl/PleaseTweakWindows/releases/tag/v2.2.1";

        var psi = MainWindowViewModel.BuildOpenUrlStartInfo(new Uri(url));

        Path.GetFileName(psi.FileName).Should().BeEquivalentTo("explorer.exe");
        Path.GetDirectoryName(psi.FileName).Should().BeEquivalentTo(
            Environment.GetFolderPath(Environment.SpecialFolder.Windows));
        psi.UseShellExecute.Should().BeFalse();
        psi.ArgumentList.Should().Equal(url);
    }

    [Fact]
    public void HighContrastTheme_MapsEveryThemeBrush()
    {
        XNamespace wpf = "http://schemas.microsoft.com/winfx/2006/xaml/presentation";
        XNamespace xaml = "http://schemas.microsoft.com/winfx/2006/xaml";
        var themePath = Path.Combine(FindRepositoryRoot(), "src", "PleaseTweakWindows", "Themes", "AppTheme.xaml");

        var brushKeys = XDocument.Load(themePath).Root!
            .Elements(wpf + "SolidColorBrush")
            .Select(e => (string)e.Attribute(xaml + "Key")!)
            .ToList();

        brushKeys.Should().NotBeEmpty();
        HighContrastTheme.BrushMap.Keys.Should().BeEquivalentTo(brushKeys,
            "every theme brush needs a high-contrast replacement, or it keeps its dark colour in high contrast mode");
    }

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory != null && !File.Exists(Path.Combine(directory.FullName, "PleaseTweakWindows.sln")))
            directory = directory.Parent;
        directory.Should().NotBeNull("the tests run from inside the repository");
        return directory!.FullName;
    }
}
