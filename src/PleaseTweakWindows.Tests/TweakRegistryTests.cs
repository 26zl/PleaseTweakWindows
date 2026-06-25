using FluentAssertions;
using PleaseTweakWindows.Models;
using PleaseTweakWindows.Services;
using Xunit;

namespace PleaseTweakWindows.Tests;

public class TweakRegistryTests
{
    private readonly TweakRegistry _registry = new();

    [Fact]
    public void GetTweaks_ReturnsFourteenCategories()
    {
        var tweaks = _registry.GetTweaks();
        tweaks.Should().HaveCount(14);
    }

    [Fact]
    public void GetTweaks_HasCorrectCategoryNames()
    {
        var tweaks = _registry.GetTweaks();
        var names = tweaks.Select(t => t.Title).ToList();

        names.Should().ContainInOrder(
            "Gaming Optimizations",
            "Performance & Power",
            "Network Optimizations",
            "Debloat",
            "Privacy",
            "Microsoft Defender",
            "Exploit Protection",
            "Device Guard",
            "Network Security",
            "System Security",
            "Customize",
            "Maintenance & Tools",
            "Windows Update",
            "Edge");
    }

    [Fact]
    public void Gaming_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var gaming = tweaks.First(t => t.Title == "Gaming Optimizations");
        gaming.SubTweaks.Should().HaveCount(12);
    }

    [Fact]
    public void Network_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var network = tweaks.First(t => t.Title == "Network Optimizations");
        network.SubTweaks.Should().HaveCount(3);
    }

    [Fact]
    public void Performance_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var performance = tweaks.First(t => t.Title == "Performance & Power");
        performance.SubTweaks.Should().HaveCount(4);
    }

    [Fact]
    public void Debloat_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var debloat = tweaks.First(t => t.Title == "Debloat");
        debloat.SubTweaks.Should().HaveCount(7);
    }

    [Fact]
    public void Maintenance_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var maintenance = tweaks.First(t => t.Title == "Maintenance & Tools");
        maintenance.SubTweaks.Should().HaveCount(4);
    }

    [Fact]
    public void Privacy_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var privacy = tweaks.First(t => t.Title == "Privacy");
        privacy.SubTweaks.Should().HaveCount(19);
    }

    [Fact]
    public void Defender_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var defender = tweaks.First(t => t.Title == "Microsoft Defender");
        defender.SubTweaks.Should().HaveCount(8);
    }

    [Fact]
    public void ExploitProtection_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var exploit = tweaks.First(t => t.Title == "Exploit Protection");
        exploit.SubTweaks.Should().HaveCount(7);
    }

    [Fact]
    public void DeviceGuard_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var deviceGuard = tweaks.First(t => t.Title == "Device Guard");
        deviceGuard.SubTweaks.Should().HaveCount(7);
    }

    [Fact]
    public void NetworkSecurity_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var networkSecurity = tweaks.First(t => t.Title == "Network Security");
        networkSecurity.SubTweaks.Should().HaveCount(20);
    }

    [Fact]
    public void SystemSecurity_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var systemSecurity = tweaks.First(t => t.Title == "System Security");
        systemSecurity.SubTweaks.Should().HaveCount(17);
    }

    [Fact]
    public void Customize_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var customize = tweaks.First(t => t.Title == "Customize");
        customize.SubTweaks.Should().HaveCount(13);
    }

    [Fact]
    public void WindowsUpdate_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var wu = tweaks.First(t => t.Title == "Windows Update");
        wu.SubTweaks.Should().HaveCount(5);
    }

    [Fact]
    public void Edge_HasCorrectSubTweakCount()
    {
        var tweaks = _registry.GetTweaks();
        var edge = tweaks.First(t => t.Title == "Edge");
        edge.SubTweaks.Should().HaveCount(2);
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
        var defender = tweaks.First(t => t.Title == "Microsoft Defender");

        privacy.ApplyScript.Should().Contain("Privacy Security");
        defender.ApplyScript.Should().Contain("Defender");
    }

    [Fact]
    public void ActionIds_MatchJavaDefinitions()
    {
        var tweaks = _registry.GetTweaks();
        var allActions = tweaks.SelectMany(t => t.SubTweaks)
            .SelectMany(s => new[] { s.ApplyAction, s.RevertAction })
            .Where(a => a != null)
            .ToHashSet();

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

    [Fact]
    public void AllActionIds_HavePowerShellRoutes()
    {
        var scriptsRoot = FindRepositoryScriptsRoot();

        foreach (var tweak in _registry.GetTweaks())
        {
            var applyScript = File.ReadAllText(Path.Combine(scriptsRoot, tweak.ApplyScript));
            var revertScript = File.ReadAllText(Path.Combine(scriptsRoot, tweak.RevertScript));

            foreach (var sub in tweak.SubTweaks)
            {
                ScriptHandlesAction(applyScript, sub.ApplyAction).Should().BeTrue(
                    $"Apply action '{sub.ApplyAction}' for '{sub.Name}' must be routed by {tweak.ApplyScript}");

                if (sub.RevertAction != null)
                {
                    ScriptHandlesAction(revertScript, sub.RevertAction).Should().BeTrue(
                        $"Revert action '{sub.RevertAction}' for '{sub.Name}' must be routed by {tweak.RevertScript}");
                }
            }
        }
    }

    private static string FindRepositoryScriptsRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null)
        {
            var scripts = Path.Combine(dir.FullName, "scripts");
            if (Directory.Exists(scripts))
                return scripts;
            dir = dir.Parent;
        }

        throw new DirectoryNotFoundException("Could not locate repository scripts directory.");
    }

    private static bool ScriptHandlesAction(string scriptContent, string action)
    {
        if (ContainsQuotedAction(scriptContent, action))
            return true;

        if (action.EndsWith("-revert", StringComparison.OrdinalIgnoreCase))
        {
            var baseAction = action[..^"-revert".Length];
            if (ContainsQuotedAction(scriptContent, baseAction))
                return true;
        }

        return false;
    }

    private static bool ContainsQuotedAction(string scriptContent, string action) =>
        scriptContent.Contains($"\"{action}\"", StringComparison.OrdinalIgnoreCase) ||
        scriptContent.Contains($"'{action}'", StringComparison.OrdinalIgnoreCase);
}
