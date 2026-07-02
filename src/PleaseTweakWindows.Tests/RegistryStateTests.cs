using FluentAssertions;
using PleaseTweakWindows.Models;
using PleaseTweakWindows.Services;
using Xunit;

namespace PleaseTweakWindows.Tests;

// Verify that registry read failures leave dependencies unmet.
public class RegistryStateTests
{
    [Fact]
    public void IsSatisfied_NullRequirement_IsSatisfied()
    {
        RegistryState.IsSatisfied(null).Should().BeTrue();
    }

    [Fact]
    public void IsSatisfied_MissingKey_FailsClosed()
    {
        var requirement = new SubTweakRequirement(
            @"HKEY_LOCAL_MACHINE\SOFTWARE\PleaseTweakWindows\__DefinitelyDoesNotExist__",
            "Enabled", 1, "prerequisite");

        // Treat absent registry values as unmet requirements.
        RegistryState.IsSatisfied(requirement).Should().BeFalse();
    }

    [Fact]
    public void IsSatisfied_MalformedRegistryPath_FailsClosed()
    {
        // Exercise the read-error path with an invalid registry hive.
        var requirement = new SubTweakRequirement(
            @"NOT_A_HIVE\Nope", "Enabled", 1, "prerequisite");

        RegistryState.IsSatisfied(requirement).Should().BeFalse();
    }
}
