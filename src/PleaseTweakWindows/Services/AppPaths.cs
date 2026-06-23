namespace PleaseTweakWindows.Services;

internal static class AppPaths
{
    public static string GetLogsDirectory()
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var candidates = string.IsNullOrWhiteSpace(localAppData)
            ? [Path.Combine(Path.GetTempPath(), "PleaseTweakWindows", "logs")]
            : new[]
            {
                Path.Combine(localAppData, "PleaseTweakWindows", "logs"),
                Path.Combine(Path.GetTempPath(), "PleaseTweakWindows", "logs")
            };

        foreach (var candidate in candidates)
        {
            try
            {
                Directory.CreateDirectory(candidate);
                return candidate;
            }
            catch
            {
                // Try the next location. Startup logging must not depend on the install folder being writable.
            }
        }

        throw new InvalidOperationException("Could not create a writable log directory.");
    }
}
