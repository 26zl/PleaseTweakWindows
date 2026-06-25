using FluentAssertions;
using PleaseTweakWindows.Services;
using Xunit;

namespace PleaseTweakWindows.Tests;

public class UpdateCheckerTests
{
    [Theory]
    [InlineData("1.0.0", "2.0.0", true)]
    [InlineData("1.0.0", "1.1.0", true)]
    [InlineData("1.0.0", "1.0.1", true)]
    [InlineData("2.0.0", "1.0.0", false)]
    [InlineData("1.1.0", "1.0.0", false)]
    [InlineData("1.0.0", "1.0.0", false)]
    [InlineData("1.2.3", "1.2.4", true)]
    [InlineData("1.2.3", "1.3.0", true)]
    [InlineData("1.2.3", "2.0.0", true)]
    public void IsNewerVersion_ComparesCorrectly(string current, string remote, bool expected)
    {
        UpdateChecker.IsNewerVersion(current, remote).Should().Be(expected);
    }

    [Theory]
    [InlineData("1", "2", true)]
    [InlineData("1.0", "1.1", true)]
    [InlineData("1.0.0.0", "1.0.1", true)]
    public void IsNewerVersion_HandlesMalformedVersions(string current, string remote, bool expected)
    {
        UpdateChecker.IsNewerVersion(current, remote).Should().Be(expected);
    }
}
