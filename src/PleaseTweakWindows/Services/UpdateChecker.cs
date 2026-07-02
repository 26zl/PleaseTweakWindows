using System.Reflection;
using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace PleaseTweakWindows.Services;

// ReleasePageUrl is the browser-facing GitHub release page.
public sealed record UpdateInfo(string Version, string ReleasePageUrl);

public sealed class UpdateChecker
{
    private const string ReleasesApi = "https://api.github.com/repos/26zl/PleaseTweakWindows/releases/latest";

    internal static readonly string CurrentVersion = LoadVersion();

    private static readonly HttpClient HttpClient = CreateHttpClient();

    private readonly ILogger<UpdateChecker> _logger;

    public UpdateChecker(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<UpdateChecker>();
    }

    private static HttpClient CreateHttpClient()
    {
        var client = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(10),
            MaxResponseContentBufferSize = 1024 * 1024
        };
        client.DefaultRequestHeaders.Add("Accept", "application/vnd.github.v3+json");
        client.DefaultRequestHeaders.Add("User-Agent", AppPaths.ProductName);
        return client;
    }

    private static string LoadVersion()
    {
        try
        {
            var assembly = Assembly.GetExecutingAssembly();
            // Read the project version from AssemblyInformationalVersion.
            var info = assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion;
            if (!string.IsNullOrWhiteSpace(info))
            {
                // Strip SourceLink metadata (e.g. "2.1.1+abc123") if present.
                var plus = info.IndexOf('+');
                return plus > 0 ? info[..plus] : info;
            }

            var version = assembly.GetName().Version;
            if (version != null)
                return $"{version.Major}.{version.Minor}.{version.Build}";
        }
        catch (Exception) { }
        return "1.0.0";
    }

    public async Task<UpdateInfo?> CheckForUpdateAsync()
    {
        try
        {
            using var response = await HttpClient.GetAsync(ReleasesApi);
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogDebug("Update check returned status {StatusCode}", response.StatusCode);
                return null;
            }

            var body = await response.Content.ReadAsStringAsync();
            var (tagName, htmlUrl) = ParseReleaseJson(body);

            if (tagName == null || htmlUrl == null)
            {
                _logger.LogDebug("Could not parse release info from GitHub API response");
                return null;
            }

            var remoteVersion = tagName.StartsWith('v') ? tagName[1..] : tagName;

            if (!IsNewerVersion(CurrentVersion, remoteVersion))
            {
                _logger.LogDebug("Current version {Current} is up to date (remote: {Remote})", CurrentVersion, remoteVersion);
                return null;
            }

            if (IsDismissed(remoteVersion))
            {
                _logger.LogDebug("Version {Version} was previously dismissed", remoteVersion);
                return null;
            }

            return new UpdateInfo(remoteVersion, htmlUrl);
        }
        catch (Exception ex)
        {
            _logger.LogDebug("Update check failed: {Message}", ex.Message);
            return null;
        }
    }

    public void DismissVersion(string version)
    {
        try
        {
            WriteDismissedVersion(GetPrefsPath(), version);
        }
        catch (Exception ex)
        {
            _logger.LogDebug("Failed to save update preferences: {Message}", ex.Message);
        }
    }

    // Sanitize release tags before storing or comparing preference values.
    internal static string SanitizeVersion(string version) =>
        new string(version
            .Take(64)
            .Where(c => char.IsLetterOrDigit(c) || c is '.' or '-' or '+')
            .ToArray());

    internal static void WriteDismissedVersion(string prefsPath, string version)
    {
        var safeVersion = SanitizeVersion(version);
        if (safeVersion.Length == 0)
            return;

        var dir = Path.GetDirectoryName(prefsPath);
        if (dir != null) Directory.CreateDirectory(dir);

        // Read-modify-write so we never clobber other keys the prefs file may hold later.
        var lines = File.Exists(prefsPath)
            ? File.ReadAllLines(prefsPath)
                .Where(l => !l.TrimStart().StartsWith("dismissed_version=", StringComparison.Ordinal))
                .ToList()
            : new List<string>();
        lines.Add($"dismissed_version={safeVersion}");
        File.WriteAllLines(prefsPath, lines);
    }

    internal static (string? tagName, string? htmlUrl) ParseReleaseJson(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            // Reject non-object responses before reading release properties.
            if (root.ValueKind != JsonValueKind.Object)
                return (null, null);
            string? tag = root.TryGetProperty("tag_name", out var t) && t.ValueKind == JsonValueKind.String ? t.GetString() : null;
            string? url = root.TryGetProperty("html_url", out var u) && u.ValueKind == JsonValueKind.String ? u.GetString() : null;
            return (tag, url);
        }
        catch (JsonException)
        {
            return (null, null);
        }
    }

    internal static bool IsNewerVersion(string current, string remote)
    {
        var cur = ParseVersion(current);
        var rem = ParseVersion(remote);
        for (int i = 0; i < 3; i++)
        {
            if (rem[i] > cur[i]) return true;
            if (rem[i] < cur[i]) return false;
        }
        return false;
    }

    private static int[] ParseVersion(string version)
    {
        var parts = new int[3];
        // Ignore prerelease and build-metadata suffixes during numeric comparison.
        var core = version.Split('-', '+')[0];
        var split = core.Split('.');
        for (int i = 0; i < Math.Min(split.Length, 3); i++)
        {
            if (int.TryParse(split[i], out var val))
                parts[i] = val;
        }
        return parts;
    }

    private static string GetPrefsPath() =>
        Path.Combine(AppPaths.GetLogsDirectory(), "ptw-update-prefs.properties");

    private static bool IsDismissed(string version) => IsDismissedIn(GetPrefsPath(), version);

    internal static bool IsDismissedIn(string prefsPath, string version)
    {
        if (!File.Exists(prefsPath)) return false;
        // Compare against the same sanitized form WriteDismissedVersion stored, not the raw version.
        var wanted = SanitizeVersion(version);
        if (wanted.Length == 0) return false;
        try
        {
            // Require an exact key-value match for the dismissed version.
            foreach (var line in File.ReadAllLines(prefsPath))
            {
                var eq = line.IndexOf('=');
                if (eq <= 0) continue;
                var key = line.AsSpan(0, eq).Trim();
                var value = line.AsSpan(eq + 1).Trim();
                if (key.SequenceEqual("dismissed_version") && value.SequenceEqual(wanted))
                    return true;
            }
        }
        catch
        {
        }
        return false;
    }
}
