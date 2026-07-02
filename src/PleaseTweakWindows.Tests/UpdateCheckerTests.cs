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

    [Theory]
    // Pre-release / build-metadata suffixes must be stripped, not parsed as 0.
    [InlineData("2.1.1", "2.1.1-beta", false)] // same core version → not newer
    [InlineData("2.1.0", "2.1.1-beta", true)]  // 2.1.1 core is newer than 2.1.0
    [InlineData("2.1.1-beta", "2.1.1", false)] // 2.1.1 == 2.1.1 core
    [InlineData("2.1.1", "2.1.2+abc123", true)] // build metadata ignored, 2.1.2 newer
    [InlineData("2.1.1+sha", "2.1.1+other", false)] // both 2.1.1 core
    public void IsNewerVersion_StripsPreReleaseAndBuildMetadata(string current, string remote, bool expected)
    {
        UpdateChecker.IsNewerVersion(current, remote).Should().Be(expected);
    }

    [Fact]
    public void ParseReleaseJson_ValidObject_ReturnsTagAndUrl()
    {
        var (tag, url) = UpdateChecker.ParseReleaseJson(
            """{"tag_name":"v2.1.3","html_url":"https://github.com/x/releases/v2.1.3"}""");

        tag.Should().Be("v2.1.3");
        url.Should().Be("https://github.com/x/releases/v2.1.3");
    }

    [Theory]
    [InlineData("{}")]                                     // both properties missing
    [InlineData("""{"tag_name":123,"html_url":456}""")]    // non-string values
    [InlineData("not json at all")]                        // malformed
    [InlineData("[1,2,3]")]                                // non-object root (would throw without the guard)
    [InlineData("\"a string\"")]                           // primitive root
    public void ParseReleaseJson_BadInput_ReturnsNulls(string json)
    {
        var (tag, url) = UpdateChecker.ParseReleaseJson(json);

        tag.Should().BeNull();
        url.Should().BeNull();
    }

    [Theory]
    [InlineData("""{"tag_name":"v1.0.0"}""", "v1.0.0", null)]       // html_url missing → only tag parsed
    [InlineData("""{"html_url":"https://x"}""", null, "https://x")] // tag_name missing → only url parsed
    public void ParseReleaseJson_PartialObject_ReturnsPresentFieldsIndependently(
        string json, string? expectedTag, string? expectedUrl)
    {
        // Parse available release properties independently.
        var (tag, url) = UpdateChecker.ParseReleaseJson(json);

        tag.Should().Be(expectedTag);
        url.Should().Be(expectedUrl);
    }

    private static string TempPrefs() =>
        Path.Combine(Path.GetTempPath(), $"ptw-test-{Guid.NewGuid():N}.properties");

    [Fact]
    public void Dismiss_UsesExactMatch_DoesNotFlagSimilarVersion()
    {
        var prefs = TempPrefs();
        try
        {
            UpdateChecker.WriteDismissedVersion(prefs, "2.1.1");
            UpdateChecker.IsDismissedIn(prefs, "2.1.1").Should().BeTrue();
            // Substring bug guard: a stored "2.1.1" must NOT mark "2.1.10" as dismissed.
            UpdateChecker.IsDismissedIn(prefs, "2.1.10").Should().BeFalse();
        }
        finally { File.Delete(prefs); }
    }

    [Fact]
    public void Dismiss_WorksForVersionsContainingStrippedCharacters()
    {
        var prefs = TempPrefs();
        try
        {
            // Sanitize stored and queried versions consistently.
            UpdateChecker.WriteDismissedVersion(prefs, "1.2.3_rc1");
            UpdateChecker.IsDismissedIn(prefs, "1.2.3_rc1").Should().BeTrue();
        }
        finally { File.Delete(prefs); }
    }

    [Fact]
    public void Dismiss_ReplacesRatherThanAppends()
    {
        var prefs = TempPrefs();
        try
        {
            UpdateChecker.WriteDismissedVersion(prefs, "2.1.1");
            UpdateChecker.WriteDismissedVersion(prefs, "2.1.2");

            var dismissed = File.ReadAllLines(prefs).Where(l => l.StartsWith("dismissed_version=")).ToArray();
            dismissed.Should().ContainSingle().Which.Should().Be("dismissed_version=2.1.2");
            UpdateChecker.IsDismissedIn(prefs, "2.1.1").Should().BeFalse();
            UpdateChecker.IsDismissedIn(prefs, "2.1.2").Should().BeTrue();
        }
        finally { File.Delete(prefs); }
    }

    [Fact]
    public void Dismiss_SanitizesHostileTag_NoSecondLineInjected()
    {
        var prefs = TempPrefs();
        try
        {
            // A tag carrying a newline must not inject a second prefs line.
            UpdateChecker.WriteDismissedVersion(prefs, "2.1.1\ninjected=1");

            var lines = File.ReadAllLines(prefs);
            lines.Should().ContainSingle();
            lines[0].Should().Be("dismissed_version=2.1.1injected1");
        }
        finally { File.Delete(prefs); }
    }

    [Fact]
    public void Dismiss_IgnoresInvalidAndTruncatesOversizedValues()
    {
        var prefs = TempPrefs();
        try
        {
            File.WriteAllText(prefs, "keep=yes\n");
            UpdateChecker.WriteDismissedVersion(prefs, "\r\n==");
            File.ReadAllText(prefs).Should().Be("keep=yes\n");

            UpdateChecker.WriteDismissedVersion(prefs, new string('1', 100));
            File.ReadAllLines(prefs).Single(l => l.StartsWith("dismissed_version="))
                .Should().HaveLength("dismissed_version=".Length + 64);
        }
        finally { File.Delete(prefs); }
    }
}
