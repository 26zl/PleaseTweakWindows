using System.Reflection;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;

namespace PleaseTweakWindows.Services;

public sealed class UpdateChecker : IUpdateChecker
{
    private const string ReleasesApi = "https://api.github.com/repos/26zl/PleaseTweakWindows/releases/latest";

    internal static readonly string CurrentVersion = LoadVersion();
    private readonly ILogger<UpdateChecker> _logger;

    public UpdateChecker(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<UpdateChecker>();
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
        catch { /* fall through */ }
        return "1.0.0";
    }

    public async Task<UpdateInfo?> CheckForUpdateAsync()
    {
        try
        {
            using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
            client.DefaultRequestHeaders.Add("Accept", "application/vnd.github.v3+json");
            client.DefaultRequestHeaders.Add("User-Agent", "PleaseTweakWindows");

            var response = await client.GetAsync(ReleasesApi);
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogDebug("Update check returned status {StatusCode}", response.StatusCode);
                return null;
            }

            var body = await response.Content.ReadAsStringAsync();
            var tagName = ExtractJsonField(body, "tag_name");
            var htmlUrl = ExtractJsonField(body, "html_url");

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

    internal static string? ExtractJsonField(string json, string field)
    {
        var pattern = $"\"{Regex.Escape(field)}\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"";
        var match = Regex.Match(json, pattern);
        if (match.Success)
        {
            return match.Groups[1].Value
                .Replace("\\\"", "\"")
                .Replace("\\\\", "\\");
        }
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
            var content = File.ReadAllText(path);
            return content.Contains($"dismissed_version={version}");
        }
        catch
        {
            return false;
        }
    }
}
