namespace PleaseTweakWindows.Services;

internal static class AppPaths
{
    // Canonical app identifier: AppData/Temp subfolder, log filename prefix, dialog
    // title and HTTP User-Agent. One source so they can never drift apart.
    public const string ProductName = "PleaseTweakWindows";

    public static string GetLogsDirectory()
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var candidates = string.IsNullOrWhiteSpace(localAppData)
            ? [Path.Combine(Path.GetTempPath(), ProductName, "logs")]
            : new[]
            {
                Path.Combine(localAppData, ProductName, "logs"),
                Path.Combine(Path.GetTempPath(), ProductName, "logs")
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
