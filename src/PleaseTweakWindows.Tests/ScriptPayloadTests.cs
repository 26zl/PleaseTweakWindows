using System.Text.Json;
using System.Text.RegularExpressions;
using FluentAssertions;
using PleaseTweakWindows.Services;
using Xunit;

namespace PleaseTweakWindows.Tests;

// Static checks on the embedded scripts and registry payloads: Restore Default must put back what Apply
// changed, and the payloads must not drift back into whole-key deletions or security regressions.
public class ScriptPayloadTests
{
    private static readonly string[] RemovedSecurityServices =
    [
        "BDESVC", "EFS", "SCardSvr", "ScDeviceEnum", "SCPolicySvc", "CertPropSvc",
        "fhsvc", "wbengine", "SDRSVC", "vds", "DsmSvc", "defragsvc", "SgrmBroker",
    ];

    [Theory]
    [InlineData("Set-LsaProtection", "lsa-protection")]
    [InlineData("Set-HvciEnable", "hvci")]
    [InlineData("Set-CredentialGuardEnable", "credential-guard")]
    public void DeviceGuardApply_SnapshotsEveryValueItWrites(string setFunction, string feature)
    {
        var script = ReadEmbedded("Device Guard/device-guard.ps1");
        var snapshot = FunctionBody(script, "Save-DeviceGuardSnapshot");
        var featureBlock = Section(snapshot, $"'{feature}' {{", "'", "if ($Feature -ne 'lsa-protection')");
        var sharedBlock = snapshot[snapshot.IndexOf("if ($Feature -ne 'lsa-protection')", StringComparison.Ordinal)..];
        var recorded = feature == "lsa-protection" ? featureBlock : featureBlock + sharedBlock;

        var written = Regex.Matches(FunctionBody(script, setFunction), @"-Name '(?<n>\w+)'")
            .Select(m => m.Groups["n"].Value)
            .Distinct()
            .ToList();

        written.Should().NotBeEmpty();
        foreach (var name in written)
            recorded.Should().Contain($"Name = '{name}'", $"{setFunction} writes {name}, so Apply must record its previous value first");
    }

    [Theory]
    [InlineData("security-lsa-protection-enable", "lsa-protection", "Set-LsaProtection")]
    [InlineData("security-hvci-enable", "hvci", "Set-HvciEnable")]
    [InlineData("security-credential-guard-enable", "credential-guard", "Set-CredentialGuardEnable")]
    public void DeviceGuardApply_SavesBeforeWriting(string action, string feature, string setFunction)
    {
        var body = SwitchCase(ReadEmbedded("Device Guard/device-guard.ps1"), action);

        var save = body.IndexOf($"Save-DeviceGuardSnapshot -Feature '{feature}'", StringComparison.Ordinal);
        var write = body.IndexOf($"{setFunction}\n", StringComparison.Ordinal);

        save.Should().BeGreaterThanOrEqualTo(0);
        write.Should().BeGreaterThan(save, "the previous values must be saved before Apply changes them");
    }

    [Fact]
    public void DeviceGuardRevert_RestoresEveryStateApplySaves()
    {
        var apply = ReadEmbedded("Device Guard/device-guard.ps1");
        var revert = ReadEmbedded("Device Guard/revert-device-guard.ps1");

        var saved = Regex.Matches(apply, @"Save-PTWRegistrySnapshot -StateName '(?<s>[a-z-]+\.json)'")
            .Select(m => m.Groups["s"].Value)
            .ToHashSet();

        saved.Should().BeEquivalentTo(
            ["device-guard-lsa-protection.json", "device-guard-hvci.json", "device-guard-credential-guard.json", "device-guard-vbs.json"]);
        foreach (var state in saved)
            revert.Should().Contain($"Restore-PTWRegistrySnapshot -StateName '{state}'");
        revert.Should().NotContain("instead of disabling the default-on feature");
    }

    [Fact]
    public void RegistryDefaults_NeverDeletesWholeKeys()
    {
        ReadEmbedded("Performance/regs/Registry-Defaults.reg")
            .Split('\n')
            .Select(line => line.Trim())
            .Should().NotContain(line => line.StartsWith("[-", StringComparison.Ordinal),
                "Restore Default must remove only the values Apply wrote; whole keys can hold other tweaks' values and organization policies");
    }

    [Fact]
    public void RegistryDefaults_RevertsEveryValueOptimizeSets()
    {
        var optimize = ParseRegValues(ReadEmbedded("Performance/regs/Registry-Optimize.reg"));
        var defaults = ParseRegValues(ReadEmbedded("Performance/regs/Registry-Defaults.reg"))
            .Select(v => v.Id)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        // performance.ps1 deletes this Apply-created COM override key itself (Remove-ClassicContextMenuOverride).
        const string handledByScript = @"HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32|@";

        var missing = optimize
            .Where(v => v.Data != "-")
            .Select(v => v.Id)
            .Where(id => !defaults.Contains(id) && !string.Equals(id, handledByScript, StringComparison.OrdinalIgnoreCase))
            .ToList();

        missing.Should().BeEmpty("every value Registry-Optimize.reg writes needs its own revert entry");
    }

    [Fact]
    public void RegistryDefaults_TouchesOnlyValuesOptimizeWrites()
    {
        var written = ParseRegValues(ReadEmbedded("Performance/regs/Registry-Optimize.reg"))
            .Where(v => v.Data != "-")
            .Select(v => v.Id)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        var allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            // Set by Registry-Optimize.reg up to v2.2.0; reverting them keeps Restore Default working after an upgrade.
            @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance|MaintenanceDisabled",
            @"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\WindowsStore|AutoDownload",
            // Registry-Optimize.reg deletes this namespace entry (Home); Restore Default recreates it.
            @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}|@",
        };

        var unrelated = ParseRegValues(ReadEmbedded("Performance/regs/Registry-Defaults.reg"))
            .Select(v => v.Id)
            .Where(id => !written.Contains(id) && !allowed.Contains(id))
            .ToList();

        unrelated.Should().BeEmpty("Restore Default must not change settings that Apply never touched");
    }

    [Theory]
    [MemberData(nameof(RemovedSecurityServiceData))]
    public void ServicesTweaked_DoesNotDisableSecurityOrBackupService(string service)
    {
        ReadEmbedded("Debloat/regs/servicesTweaked.reg")
            .Should().NotContainEquivalentOf($@"\Services\{service}]");
    }

    public static TheoryData<string> RemovedSecurityServiceData() => new(RemovedSecurityServices);

    [Fact]
    public void ServicesDisable_SavesStartTypesBeforeImporting()
    {
        var body = SwitchCase(ReadEmbedded("Debloat/debloat.ps1"), "services-disable");

        var save = body.IndexOf("Save-PTWRegistrySnapshot", StringComparison.Ordinal);
        var import = body.IndexOf("Import-RegistryFile -RegFile $regPath", StringComparison.Ordinal);

        save.Should().BeGreaterThanOrEqualTo(0);
        import.Should().BeGreaterThan(save, "the current start types must be saved before the batch changes them");
    }

    [Fact]
    public void ServicesRestore_PrefersSavedStartTypesOverDefaults()
    {
        var body = SwitchCase(ReadEmbedded("Debloat/debloat.ps1"), "services-restore");

        var restore = body.IndexOf("Restore-PTWRegistrySnapshot", StringComparison.Ordinal);
        var defaults = body.IndexOf("servicesDefault.reg", StringComparison.Ordinal);

        restore.Should().BeGreaterThanOrEqualTo(0);
        defaults.Should().BeGreaterThan(restore, "Windows defaults are only the fallback when nothing was saved");
    }

    [Fact]
    public void NetworkAllPublic_SavesCategoriesBeforeChangingThem()
    {
        var body = SwitchCase(ReadEmbedded("Network Security/network-security.ps1"), "network-all-public");

        var save = body.IndexOf("Save-PTWNetworkCategorySnapshot", StringComparison.Ordinal);
        var change = body.IndexOf("Set-NetConnectionProfile", StringComparison.Ordinal);

        save.Should().BeGreaterThanOrEqualTo(0);
        change.Should().BeGreaterThan(save);
    }

    [Fact]
    public void NetworkRestore_PutsBackSavedCategoriesInsteadOfPrivate()
    {
        var revert = FunctionBody(ReadEmbedded("Network Security/revert-network-security.ps1"), "Restore-NetworkAllPrivate");
        var applyScriptCase = SwitchCase(ReadEmbedded("Network Security/network-security.ps1"), "network-all-private");

        revert.Should().Contain("Restore-PTWNetworkCategorySnapshot").And.NotContain("-NetworkCategory Private");
        applyScriptCase.Should().Contain("Restore-PTWNetworkCategorySnapshot").And.NotContain("-NetworkCategory Private");
    }

    [Fact]
    public void CountryIpLists_ArePinnedToACommitWithShippedHashes()
    {
        var script = ReadEmbedded("Network Security/network-security.ps1");
        var urls = Regex.Matches(script, @"https://raw\.githubusercontent\.com/HotCakeX/[^'""\s]+")
            .Select(m => m.Value)
            .ToList();
        using var manifest = JsonDocument.Parse(ReadEmbedded("file-checksums.json"));
        var downloads = manifest.RootElement.GetProperty("downloads");

        urls.Should().HaveCount(2);
        foreach (var url in urls)
        {
            url.Should().MatchRegex("/[0-9a-f]{40}/Curated-Lists/", "the lists must come from one fixed commit");
            downloads.TryGetProperty(url, out var hash).Should().BeTrue($"{url} needs a pinned SHA256 in file-checksums.json");
            hash.GetString().Should().MatchRegex("^[0-9A-F]{64}$");
        }
    }

    [Fact]
    public void SystemCleanup_DoesNotEmptyTheRecycleBin()
    {
        var script = ReadEmbedded("Maintenance/maintenance.ps1");

        SwitchCase(script, "cleanup-run").Should().NotContain("Clear-RecycleBin");
        SwitchCase(script, "recycle-bin-empty").Should().Contain("Clear-RecycleBin");
    }

    [Fact]
    public void WindowsUpdatePause_IsCappedAt35Days()
    {
        var body = SwitchCase(ReadEmbedded("Windows Update/windows-update.ps1"), "wu-pause-updates");

        body.Should().Contain("$pauseDays = 35").And.Contain("AddDays($pauseDays)").And.NotContain("AddDays(3500)");
    }

    [Fact]
    public void BloatwarePersistence_RemovesOnlyRecordedAppsAndKeepsGaming()
    {
        var script = ReadEmbedded("Debloat/debloat.ps1");
        var persist = SwitchCase(script, "bloatware-persist-on");

        Regex.Matches(persist, @"\$removeOnly -contains").Should().HaveCount(2, "both removal loops must be limited to the recorded apps");
        persist.Should().Contain("Test-PtwPackageName", "only validated package names may be embedded into the SYSTEM task");
        foreach (var prefix in new[] { "'Microsoft.GamingApp'", "'Microsoft.GamingServices'", "'Microsoft.Xbox'" })
            script.Should().Contain(prefix);
    }

    private static string ReadEmbedded(string relativePath)
    {
        var asm = typeof(ScriptExecutor).Assembly;
        var suffix = "Scripts." + relativePath.Replace('/', '.').Replace('\\', '.').Replace(' ', '_');
        var name = asm.GetManifestResourceNames()
            .Single(n => n.EndsWith(suffix, StringComparison.OrdinalIgnoreCase));
        using var reader = new StreamReader(asm.GetManifestResourceStream(name)!);
        return reader.ReadToEnd().Replace("\r\n", "\n");
    }

    private static string FunctionBody(string script, string functionName)
    {
        var start = script.IndexOf($"function {functionName} {{", StringComparison.Ordinal);
        start.Should().BeGreaterThanOrEqualTo(0, $"function {functionName} must exist");
        var next = script.IndexOf("\nfunction ", start + 1, StringComparison.Ordinal);
        return next < 0 ? script[start..] : script[start..next];
    }

    // One case of the top-level "switch ($Action...)" dispatcher.
    private static string SwitchCase(string script, string action)
    {
        var header = Regex.Match(script, $"^    \"{Regex.Escape(action)}\" \\{{$", RegexOptions.Multiline);
        header.Success.Should().BeTrue($"the dispatcher must handle '{action}'");
        var next = Regex.Match(script[(header.Index + header.Length)..], "^    (\"[a-z0-9-]+\"|default) \\{$", RegexOptions.Multiline);
        return next.Success
            ? script.Substring(header.Index, header.Length + next.Index)
            : script[header.Index..];
    }

    // Text from the start marker to the next line that starts a sibling block, or to the end marker.
    private static string Section(string text, string startMarker, string siblingPrefix, string endMarker)
    {
        var start = text.IndexOf(startMarker, StringComparison.Ordinal);
        start.Should().BeGreaterThanOrEqualTo(0, $"'{startMarker}' must exist");
        var end = text.IndexOf(endMarker, start, StringComparison.Ordinal);
        var sibling = Regex.Match(text[(start + startMarker.Length)..], $"^\\s+{Regex.Escape(siblingPrefix)}[a-z-]+' \\{{$", RegexOptions.Multiline);
        if (sibling.Success)
            end = Math.Min(end < 0 ? int.MaxValue : end, start + startMarker.Length + sibling.Index);
        return end < 0 ? text[start..] : text[start..end];
    }

    private static List<(string Id, string Data)> ParseRegValues(string reg)
    {
        var values = new List<(string Id, string Data)>();
        var key = "";
        foreach (var raw in reg.Split('\n'))
        {
            var line = raw.Trim().TrimStart('﻿');
            if (line.StartsWith('[') && line.EndsWith(']'))
            {
                key = line.TrimStart('[', '-').TrimEnd(']');
                continue;
            }
            var match = Regex.Match(line, "^(?:\"(?<name>[^\"]*)\"|(?<default>@))=(?<data>.*)$");
            if (!match.Success)
                continue;
            var name = match.Groups["default"].Success ? "@" : match.Groups["name"].Value;
            values.Add(($"{key}|{name}", match.Groups["data"].Value));
        }
        return values;
    }
}
