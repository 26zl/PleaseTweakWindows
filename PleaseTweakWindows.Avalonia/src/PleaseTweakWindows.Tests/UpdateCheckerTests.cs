using FluentAssertions;
using PleaseTweakWindows.Services;
using Xunit;

namespace PleaseTweakWindows.Tests;

public class UpdateCheckerTests
{
    [Fact]
    public void ExtractJsonField_ExtractsTagName()
    {
        var json = """{"tag_name":"v2.0.0","html_url":"https://example.com/release"}""";
        UpdateChecker.ExtractJsonField(json, "tag_name").Should().Be("v2.0.0");
    }

    [Fact]
    public void ExtractJsonField_ExtractsHtmlUrl()
    {
        var json = """{"tag_name":"v2.0.0","html_url":"https://example.com/release"}""";
        UpdateChecker.ExtractJsonField(json, "html_url").Should().Be("https://example.com/release");
    }

    [Fact]
    public void ExtractJsonField_ReturnsNullForMissingField()
    {
        var json = """{"tag_name":"v2.0.0"}""";
        UpdateChecker.ExtractJsonField(json, "nonexistent").Should().BeNull();
    }

    [Fact]
    public void ExtractJsonField_HandlesEscapedCharacters()
    {
        var json = """{"field":"value with \"quotes\""}""";
        UpdateChecker.ExtractJsonField(json, "field").Should().Be("value with \"quotes\"");
    }

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
    [InlineData("1.0.0.0", "1.0.1", true)] // extra parts ignored
    public void IsNewerVersion_HandlesMalformedVersions(string current, string remote, bool expected)
    {
        UpdateChecker.IsNewerVersion(current, remote).Should().Be(expected);
    }
}
