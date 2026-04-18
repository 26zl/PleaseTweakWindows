using System.Reflection;
using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace PleaseTweakWindows.Services;

public sealed class UpdateChecker : IUpdateChecker
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
        var client = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
        client.DefaultRequestHeaders.Add("Accept", "application/vnd.github.v3+json");
        client.DefaultRequestHeaders.Add("User-Agent", "PleaseTweakWindows");
        return client;
    }

    private static string LoadVersion()
    {
        try
        {
            var assembly = Assembly.GetExecutingAssembly();
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
            var response = await HttpClient.GetAsync(ReleasesApi);
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
            var prefsPath = GetPrefsPath();
            var dir = Path.GetDirectoryName(prefsPath);
            if (dir != null) Directory.CreateDirectory(dir);
            File.WriteAllText(prefsPath, $"dismissed_version={version}");
        }
        catch (Exception ex)
        {
            _logger.LogDebug("Failed to save update preferences: {Message}", ex.Message);
        }
    }

    internal static (string? tagName, string? htmlUrl) ParseReleaseJson(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            string? tag = root.TryGetProperty("tag_name", out var t) && t.ValueKind == JsonValueKind.String ? t.GetString() : null;
            string? url = root.TryGetProperty("html_url", out var u) && u.ValueKind == JsonValueKind.String ? u.GetString() : null;
            return (tag, url);
        }
        catch (JsonException)
        {
            return (null, null);
        }
    }

    internal static string? ExtractJsonField(string json, string field)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            if (doc.RootElement.TryGetProperty(field, out var prop) && prop.ValueKind == JsonValueKind.String)
                return prop.GetString();
        }
        catch (JsonException) { }
        return null;
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
        var split = version.Split('.');
        for (int i = 0; i < Math.Min(split.Length, 3); i++)
        {
            if (int.TryParse(split[i], out var val))
                parts[i] = val;
        }
        return parts;
    }

    private static string GetPrefsPath() =>
        Path.Combine(AppContext.BaseDirectory, "logs", "ptw-update-prefs.properties");

    private static bool IsDismissed(string version)
    {
        var path = GetPrefsPath();
        if (!File.Exists(path)) return false;
        try
        {
            // Exact key=value match. A substring match would incorrectly flag version
            // "2.1.1" as dismissed when the prefs file holds "dismissed_version=2.1.10".
            foreach (var line in File.ReadAllLines(path))
            {
                var eq = line.IndexOf('=');
                if (eq <= 0) continue;
                var key = line.AsSpan(0, eq).Trim();
                var value = line.AsSpan(eq + 1).Trim();
                if (key.SequenceEqual("dismissed_version") && value.SequenceEqual(version))
                    return true;
            }
        }
        catch
        {
        }
        return false;
    }
}
