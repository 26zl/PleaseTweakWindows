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
        _service = new DialogService(NullLoggerFactory.Instance, new TweakRegistry());
    }

    [Theory]
    [InlineData("bloatware-remove", true)]
    [InlineData("services-disable", true)]
    [InlineData("ddu-install", true)]
    [InlineData("tls-hardening", true)]
    [InlineData("firewall-hardening", true)]
    [InlineData("smart-optimize-aggressive", true)]
    [InlineData("security-improve-network", true)]
    [InlineData("security-smb-modern-enforce", true)]
    [InlineData("copilot-disable", true)]
    [InlineData("amd-driver-install", true)]
    [InlineData("nvidia-driver-install", true)]
    [InlineData("ooshutup-apply", true)]
    [InlineData("network-all-private", true)]
    [InlineData("bloatware-persist-on", true)]
    [InlineData("wu-disable", true)]
    [InlineData("security-uac-silent-elevation", true)]
    [InlineData("security-asr-rules-enable", true)]
    [InlineData("security-hvci-enable", true)]
    [InlineData("country-ip-block", true)]
    [InlineData("security-hvci-mandatory", true)]
    [InlineData("security-winrm-harden", true)]
    [InlineData("block-ms-account", true)]
    [InlineData("security-wsh-disable", true)]
    [InlineData("security-defender-gaming-scan", false)]
    [InlineData("wu-secure", false)]
    [InlineData("edge-harden", false)]
    [InlineData("security-smartscreen-enforce", false)]
    [InlineData("wu-default", false)]
    [InlineData("theme-dark", false)]
    [InlineData("nvidia-settings-on", true)]
    [InlineData("store-install", false)]
    [InlineData("power-plan-on", false)]
    [InlineData("power-plan-default", true)]
    [InlineData("security-defender-cfa-enable-revert", true)]
    [InlineData("run-all-batch", true)]
    [InlineData("run-all-batch-high-risk", true)]
    [InlineData("unknown-action", false)]
    public void RequiresConfirmation_IdentifiesDestructiveActions(string action, bool expected)
    {
        _service.RequiresConfirmation(action).Should().Be(expected);
    }

    [Theory]
    [InlineData("services-disable", true)]
    [InlineData("ddu-install", false)]
    [InlineData("tls-hardening", true)]
    [InlineData("firewall-hardening", true)]
    [InlineData("smart-optimize-aggressive", true)]
    [InlineData("security-spectre-meltdown-enable", true)]
    [InlineData("security-improve-network", true)]
    [InlineData("security-smb-modern-enforce", true)]
    [InlineData("security-defender-cfa-enable", true)]
    [InlineData("run-all-batch-high-risk", true)]
    [InlineData("bloatware-persist-on", true)]
    [InlineData("wu-disable", true)]
    [InlineData("security-uac-silent-elevation", true)]
    [InlineData("security-hvci-enable", true)]
    [InlineData("security-hvci-enable-revert", true)]
    [InlineData("security-block-lolbins", true)]
    [InlineData("country-ip-block", true)]
    [InlineData("security-secure-launch", true)]
    [InlineData("block-ms-account", true)]
    [InlineData("security-rdp-nla", true)]
    [InlineData("security-wsh-disable", false)]
    [InlineData("security-asr-rules-enable", true)]
    [InlineData("edge-hardcore", false)]
    [InlineData("bloatware-remove", true)]
    [InlineData("nvidia-driver-install", true)]
    [InlineData("ooshutup-apply", true)]
    [InlineData("copilot-disable", false)]
    [InlineData("wu-pause-updates", false)]
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
    public void GetActionWarning_RevertExplainsRestoreDefaultSemantics()
    {
        var warning = _service.GetActionWarning(
            "security-defender-cfa-enable-revert", "Controlled Folder Access");

        warning.Should().Contain("Windows default");
        warning.Should().Contain("not an exact undo");
        warning.Should().Contain("organization-managed");
    }

    [Fact]
    public void GetActionWarning_CoversMajorDestructiveActions()
    {
        var actionsWithSpecificWarnings = new[]
        {
            "bloatware-remove", "services-disable", "ddu-install",
            "nvidia-driver-install", "nvidia-settings-on", "ooshutup-apply",
            "tls-hardening", "firewall-hardening", "security-improve-network",
            "security-spectre-meltdown-enable", "smart-optimize-aggressive",
            "security-smb-modern-enforce", "run-all-batch-high-risk"
        };

        foreach (var action in actionsWithSpecificWarnings)
        {
            var warning = _service.GetActionWarning(action, "Test");
            warning.Should().NotContain("changes to your system",
                $"Action '{action}' should have a specific warning, not the generic one");
        }
    }
}
