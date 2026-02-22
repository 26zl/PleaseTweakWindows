using FluentAssertions;
using PleaseTweakWindows.Models;
using PleaseTweakWindows.Services;
using Xunit;

namespace PleaseTweakWindows.Tests;

public class TweakRegistryTests
{
    private readonly TweakRegistry _registry = new();

    [Fact]
    public void GetTweaks_ReturnsSixCategories()
    {
        var tweaks = _registry.GetTweaks();
        tweaks.Should().HaveCount(6);
    }

    [Fact]
    public void GetTweaks_HasCorrectCategoryNames()
    {
        var tweaks = _registry.GetTweaks();
        var names = tweaks.Select(t => t.Title).ToList();

        names.Should().ContainInOrder(
            "Gaming Optimizations",
            "Network Optimizations",
            "General Tweaks",
            "Services Management",
            "Privacy",
            "Security");
    }

    [Fact]
    public void Gaming_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var gaming = tweaks.First(t => t.Title == "Gaming Optimizations");
        gaming.SubTweaks.Should().HaveCount(11);
    }

    [Fact]
    public void Network_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var network = tweaks.First(t => t.Title == "Network Optimizations");
        network.SubTweaks.Should().HaveCount(3);
    }

    [Fact]
    public void General_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var general = tweaks.First(t => t.Title == "General Tweaks");
        general.SubTweaks.Should().HaveCount(16);
    }

    [Fact]
    public void Services_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var services = tweaks.First(t => t.Title == "Services Management");
        services.SubTweaks.Should().HaveCount(2);
    }

    [Fact]
    public void Privacy_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var privacy = tweaks.First(t => t.Title == "Privacy");
        privacy.SubTweaks.Should().HaveCount(14);
    }

    [Fact]
    public void Security_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var security = tweaks.First(t => t.Title == "Security");
        security.SubTweaks.Should().HaveCount(13);
    }

    [Fact]
    public void AllSubTweaks_HaveValidActionIds()
    {
        var tweaks = _registry.GetTweaks();
        var actionIdRegex = new System.Text.RegularExpressions.Regex(@"^[A-Za-z0-9_-]{2,64}$");

        foreach (var tweak in tweaks)
        {
            foreach (var sub in tweak.SubTweaks)
            {
                sub.ApplyAction.Should().MatchRegex(actionIdRegex.ToString(),
                    $"Apply action '{sub.ApplyAction}' for '{sub.Name}' should be valid");

                if (sub.RevertAction != null)
                {
                    sub.RevertAction.Should().MatchRegex(actionIdRegex.ToString(),
                        $"Revert action '{sub.RevertAction}' for '{sub.Name}' should be valid");
                }
            }
        }
    }

    [Fact]
    public void AllToggleSubTweaks_HaveRevertActions()
    {
        var tweaks = _registry.GetTweaks();

        foreach (var tweak in tweaks)
        {
            foreach (var sub in tweak.SubTweaks)
            {
                if (sub.Type == SubTweakType.Toggle)
                {
                    sub.RevertAction.Should().NotBeNullOrEmpty(
                        $"Toggle sub-tweak '{sub.Name}' must have a revert action");
                }
            }
        }
    }

    [Fact]
    public void AllButtonSubTweaks_HaveNoRevertActions()
    {
        var tweaks = _registry.GetTweaks();

        foreach (var tweak in tweaks)
        {
            foreach (var sub in tweak.SubTweaks)
            {
                if (sub.Type == SubTweakType.Button)
                {
                    sub.RevertAction.Should().BeNull(
                        $"Button sub-tweak '{sub.Name}' should not have a revert action");
                }
            }
        }
    }

    [Fact]
    public void AllTweaks_HaveValidScriptPaths()
    {
        var tweaks = _registry.GetTweaks();

        foreach (var tweak in tweaks)
        {
            tweak.ApplyScript.Should().EndWith(".ps1",
                $"Apply script for '{tweak.Title}' should be a .ps1 file");
            tweak.RevertScript.Should().EndWith(".ps1",
                $"Revert script for '{tweak.Title}' should be a .ps1 file");
        }
    }

    [Fact]
    public void PrivacySecurity_ShareScriptFolder()
    {
        var tweaks = _registry.GetTweaks();
        var privacy = tweaks.First(t => t.Title == "Privacy");
        var security = tweaks.First(t => t.Title == "Security");

        privacy.ApplyScript.Should().Contain("Privacy Security");
        security.ApplyScript.Should().Contain("Privacy Security");
    }

    [Fact]
    public void ActionIds_MatchJavaDefinitions()
    {
        // Verify key action IDs match the Java TweakController exactly
        var tweaks = _registry.GetTweaks();
        var allActions = tweaks.SelectMany(t => t.SubTweaks)
            .SelectMany(s => new[] { s.ApplyAction, s.RevertAction })
            .Where(a => a != null)
            .ToHashSet();

        // Spot-check critical action IDs
        allActions.Should().Contain("nvidia-settings-on");
        allActions.Should().Contain("nvidia-settings-default");
        allActions.Should().Contain("services-disable");
        allActions.Should().Contain("services-restore");
        allActions.Should().Contain("firewall-hardening");
        allActions.Should().Contain("tls-hardening");
        allActions.Should().Contain("copilot-disable");
        allActions.Should().Contain("doh-enable");
        allActions.Should().Contain("driver-clean");
        allActions.Should().Contain("bloatware-remove");
    }
}
