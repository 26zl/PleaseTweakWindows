using FluentAssertions;
using PleaseTweakWindows.Services;
using Xunit;

namespace PleaseTweakWindows.Tests;

public class ResourceExtractorTests
{
    [Theory]
    // Convert index paths to their embedded-resource suffixes.
    [InlineData("CommonFunctions.ps1", "Scripts.CommonFunctions.ps1")]
    [InlineData("Privacy Security/privacy.ps1", "Scripts.Privacy_Security.privacy.ps1")]
    [InlineData("Performance/regs/Registry-Optimize.reg", "Scripts.Performance.regs.Registry-Optimize.reg")]
    [InlineData("Gaming optimizations/reg/nvidia_profile.xml", "Scripts.Gaming_optimizations.reg.nvidia_profile.xml")]
    [InlineData("Device Guard\\revert-device-guard.ps1", "Scripts.Device_Guard.revert-device-guard.ps1")]
    public void ComputeResourceSuffix_MapsIndexPathToManifestSuffix(string relativePath, string expected)
    {
        ResourceExtractor.ComputeResourceSuffix(relativePath).Should().Be(expected);
    }

    // Reject manifest entries that escape the extraction directory.
    [Fact]
    public void IsWithinDirectory_AllowsNestedPaths()
    {
        var root = Path.Combine(Path.GetTempPath(), "ptw-extract");
        ResourceExtractor.IsWithinDirectory(root, Path.Combine(root, "CommonFunctions.ps1")).Should().BeTrue();
        ResourceExtractor.IsWithinDirectory(root, Path.Combine(root, "Privacy Security", "privacy.ps1")).Should().BeTrue();
    }

    [Fact]
    public void IsWithinDirectory_RejectsParentEscape()
    {
        var root = Path.Combine(Path.GetTempPath(), "ptw-extract");
        var escape = Path.Combine(root, "..", "evil.ps1");
        ResourceExtractor.IsWithinDirectory(root, escape).Should().BeFalse();
    }

    [Fact]
    public void IsWithinDirectory_RejectsSiblingPrefixEscape()
    {
        // Reject sibling directories that merely share the base path's string prefix.
        var root = Path.Combine(Path.GetTempPath(), "ptw-extract");
        var sibling = Path.Combine(Path.GetTempPath(), "ptw-extract-evil", "x.ps1");
        ResourceExtractor.IsWithinDirectory(root, sibling).Should().BeFalse();
    }
}
