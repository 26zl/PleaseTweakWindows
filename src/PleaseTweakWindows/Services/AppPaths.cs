using System.Security.AccessControl;
using System.Security.Principal;

namespace PleaseTweakWindows.Services;

internal static class AppPaths
{
    private static readonly object StateDirectoryLock = new();

    // Shared identifier for storage paths, logs, dialogs, and the HTTP user agent.
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
                // Try the next writable logging location.
            }
        }

        throw new InvalidOperationException("Could not create a writable log directory.");
    }

    public static string GetStateDirectory()
    {
        if (!OperatingSystem.IsWindows())
            throw new PlatformNotSupportedException("Protected persistent state is available only on Windows.");

        lock (StateDirectoryLock)
        {
            var commonAppData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
            if (string.IsNullOrWhiteSpace(commonAppData))
                throw new InvalidOperationException("Could not resolve the system ProgramData directory.");

            // Lock down the product directory (owner + admin/SYSTEM-only ACL) before creating state inside it.
            var productDirectory = Path.Combine(commonAppData, ProductName);
            EnsureRealDirectory(productDirectory);
            RestrictDirectory(productDirectory);

            var stateDirectory = Path.Combine(productDirectory, "state");
            EnsureRealDirectory(stateDirectory);
            RestrictDirectory(stateDirectory);

            // Re-verify no reparse point appeared during the create/restrict window; fail closed.
            EnsureRealDirectory(productDirectory);
            EnsureRealDirectory(stateDirectory);
            return stateDirectory;
        }
    }

    private static void EnsureRealDirectory(string path)
    {
        Directory.CreateDirectory(path);
        var directory = new DirectoryInfo(path);
        if ((directory.Attributes & FileAttributes.ReparsePoint) != 0)
            throw new InvalidOperationException($"Refusing to use a reparse point for protected state: {path}");
    }

    private static void RestrictDirectory(string path)
    {
        var administrators = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        var localSystem = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null);
        var inheritance = InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit;

        var security = new DirectorySecurity();
        security.SetOwner(administrators);
        security.SetAccessRuleProtection(isProtected: true, preserveInheritance: false);
        security.AddAccessRule(new FileSystemAccessRule(
            administrators, FileSystemRights.FullControl, inheritance,
            PropagationFlags.None, AccessControlType.Allow));
        security.AddAccessRule(new FileSystemAccessRule(
            localSystem, FileSystemRights.FullControl, inheritance,
            PropagationFlags.None, AccessControlType.Allow));

        new DirectoryInfo(path).SetAccessControl(security);
    }
}
