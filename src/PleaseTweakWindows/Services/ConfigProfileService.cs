using System.Text.Json;
using System.Text.Json.Serialization;

namespace PleaseTweakWindows.Services;

/// <summary>
/// A portable, versioned tweak profile: a list of apply-action IDs that can be
/// exported on one machine and re-applied on another. It records WHAT to apply,
/// not the machine's current state (PTW has no applied-state model).
/// </summary>
public sealed class ConfigProfile
{
    public int SchemaVersion { get; set; } = 1;
    public string CreatedAtUtc { get; set; } = "";
    public string AppVersion { get; set; } = "";
    public List<string> Actions { get; set; } = new();
}

public sealed record ConfigImportResult(
    IReadOnlyList<string> ValidActions,
    IReadOnlyList<string> DroppedActions,
    string? Error);

public sealed class ConfigProfileService
{
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        // Be lenient about key casing for hand-edited / foreign-tool profiles. Without this a
        // non-camelCase "schemaversion" key would silently bind to the default (1) and bypass
        // the unsupported-version rejection below.
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never,
    };

    public string Export(IEnumerable<string> actionIds, string appVersion, DateTimeOffset nowUtc)
    {
        var actions = actionIds
            .Where(a => !string.IsNullOrWhiteSpace(a))
            .Distinct(StringComparer.Ordinal)
            .ToList();

        var profile = new ConfigProfile
        {
            SchemaVersion = 1,
            CreatedAtUtc = nowUtc.UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ssZ"),
            AppVersion = appVersion,
            Actions = actions,
        };
        return JsonSerializer.Serialize(profile, Options);
    }

    public ConfigImportResult Import(string json, ISet<string> knownActionIds)
    {
        ConfigProfile? profile;
        try
        {
            profile = JsonSerializer.Deserialize<ConfigProfile>(json, Options);
        }
        catch (Exception ex) when (ex is JsonException or NotSupportedException or ArgumentException)
        {
            return new ConfigImportResult([], [], $"Not a valid PleaseTweakWindows profile: {ex.Message}");
        }

        if (profile is null)
            return new ConfigImportResult([], [], "Profile file was empty or not valid JSON.");
        if (profile.SchemaVersion != 1)
            return new ConfigImportResult([], [], $"Unsupported profile schema version {profile.SchemaVersion}. This build understands version 1.");
        if (profile.Actions is null || profile.Actions.Count == 0)
            return new ConfigImportResult([], [], "Profile contains no actions.");

        var valid = new List<string>();
        var dropped = new List<string>();
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var action in profile.Actions)
        {
            if (string.IsNullOrWhiteSpace(action) || !seen.Add(action))
                continue;
            // Drop unknown IDs (different/older PTW build, hand-edited typo) rather than
            // ever passing an unvalidated string through to a script invocation.
            if (knownActionIds.Contains(action))
                valid.Add(action);
            else
                dropped.Add(action);
        }
        return new ConfigImportResult(valid, dropped, null);
    }
}
