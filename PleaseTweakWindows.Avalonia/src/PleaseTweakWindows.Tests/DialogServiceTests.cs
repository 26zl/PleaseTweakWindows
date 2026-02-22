using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using PleaseTweakWindows.Services;
using Xunit;

namespace PleaseTweakWindows.Tests;

public class DialogServiceTests
{
    private readonly DialogService _service;

    public DialogServiceTests()
    {
        _service = new DialogService(NullLoggerFactory.Instance);
    }

    [Theory]
    [InlineData("bloatware-remove", true)]
    [InlineData("services-disable", true)]
    [InlineData("driver-clean", true)]
    [InlineData("tls-hardening", true)]
    [InlineData("firewall-hardening", true)]
    [InlineData("security-improve-network", true)]
    [InlineData("copilot-disable", true)]
    [InlineData("amd-driver-install", true)]
    [InlineData("nvidia-settings-on", false)]
    [InlineData("store-install", false)]
    [InlineData("power-plan-on", false)]
    [InlineData("unknown-action", false)]
    public void RequiresConfirmation_IdentifiesDestructiveActions(string action, bool expected)
    {
        _service.RequiresConfirmation(action).Should().Be(expected);
    }

    [Theory]
    [InlineData("services-disable", true)]
    [InlineData("driver-clean", true)]
    [InlineData("tls-hardening", true)]
    [InlineData("firewall-hardening", true)]
    [InlineData("security-spectre-meltdown-enable", true)]
    [InlineData("security-improve-network", true)]
    [InlineData("bloatware-remove", false)]
    [InlineData("copilot-disable", false)]
    [InlineData("nvidia-settings-on", false)]
    public void IsHighRisk_IdentifiesHighRiskActions(string action, bool expected)
    {
        _service.IsHighRisk(action).Should().Be(expected);
    }

    [Fact]
    public void GetActionWarning_ReturnsSpecificWarningForKnownActions()
    {
        var warning = _service.GetActionWarning("services-disable", "Disable Services");
        warning.Should().Contain("Disable Services");
        warning.Should().Contain("STRONGLY recommended");
    }

    [Fact]
    public void GetActionWarning_ReturnsGenericWarningForUnknownActions()
    {
        var warning = _service.GetActionWarning("unknown-action", "Unknown");
        warning.Should().Contain("Unknown");
        warning.Should().Contain("changes to your system");
    }

    [Fact]
    public void GetActionWarning_CoversMajorDestructiveActions()
    {
        // Ensure key actions have specific warnings (not the generic fallback)
        var actionsWithSpecificWarnings = new[]
        {
            "bloatware-remove", "services-disable", "driver-clean",
            "tls-hardening", "firewall-hardening", "security-improve-network",
            "security-spectre-meltdown-enable"
        };

        foreach (var action in actionsWithSpecificWarnings)
        {
            var warning = _service.GetActionWarning(action, "Test");
            warning.Should().NotContain("changes to your system",
                $"Action '{action}' should have a specific warning, not the generic one");
        }
    }
}
