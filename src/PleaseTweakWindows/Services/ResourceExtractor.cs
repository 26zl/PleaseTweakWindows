using System.Reflection;
using System.Security.AccessControl;
using System.Security.Principal;
using Microsoft.Extensions.Logging;

namespace PleaseTweakWindows.Services;

public sealed class ResourceExtractor : IResourceExtractor
{
    private readonly ILogger<ResourceExtractor> _logger;
    private string? _scriptsDirectory;
    private readonly object _lock = new();

    public ResourceExtractor(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<ResourceExtractor>();
    }

    public string PrepareScriptsPath()
    {
        lock (_lock)
        {
            if (_scriptsDirectory != null)
                return _scriptsDirectory;

            // Always extract from embedded resources. A filesystem scripts\ folder next
            // to the EXE would be writable by any admin on the box, which would let a
            // compromised admin modify privileged script content without rebuilding.
            // The EXE ships self-contained and is only modifiable by re-publishing.
            _logger.LogInformation("Extracting scripts from embedded resources");
            var tempDir = CreateTempDirectory();
            ExtractFromEmbeddedResources(tempDir);
            _scriptsDirectory = tempDir;
            return tempDir;
        }
    }

    public void Cleanup()
    {
        lock (_lock)
        {
            if (_scriptsDirectory == null) return;
            try
            {
                if (Directory.Exists(_scriptsDirectory))
                {
                    Directory.Delete(_scriptsDirectory, recursive: true);
                    _logger.LogDebug("Cleaned up temp scripts directory: {Dir}", _scriptsDirectory);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to cleanup temp directory: {Dir}", _scriptsDirectory);
            }
            _scriptsDirectory = null;
        }
    }

    private string CreateTempDirectory()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"pleasetweakwindows-scripts-{Guid.NewGuid():N}");
        Directory.CreateDirectory(tempDir);
        RestrictDirectoryPermissions(tempDir);
        return tempDir;
    }

    private void RestrictDirectoryPermissions(string directory)
    {
        try
        {
            var dirInfo = new DirectoryInfo(directory);
            var security = dirInfo.GetAccessControl();

            security.SetAccessRuleProtection(isProtected: true, preserveInheritance: false);
            var rules = security.GetAccessRules(true, true, typeof(SecurityIdentifier));
            foreach (FileSystemAccessRule rule in rules)
            {
                security.RemoveAccessRule(rule);
            }

            var currentUser = WindowsIdentity.GetCurrent().User
                ?? throw new InvalidOperationException("Could not resolve current user SID");
            var administrators = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
            var localSystem = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null);

            security.SetOwner(administrators);

            security.AddAccessRule(new FileSystemAccessRule(
                administrators,
                FileSystemRights.FullControl,
                InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                PropagationFlags.None,
                AccessControlType.Allow));
            security.AddAccessRule(new FileSystemAccessRule(
                localSystem,
                FileSystemRights.FullControl,
                InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                PropagationFlags.None,
                AccessControlType.Allow));
            security.AddAccessRule(new FileSystemAccessRule(
                currentUser,
                FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read,
                InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                PropagationFlags.None,
                AccessControlType.Allow));

            dirInfo.SetAccessControl(security);
            _logger.LogDebug("Restricted temp directory permissions to elevated administrators + read-only current user: {Dir}", directory);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to restrict temp directory permissions: {Dir}", directory);
            try { Directory.Delete(directory, recursive: true); }
            catch (Exception cleanupEx) { _logger.LogDebug(cleanupEx, "Cleanup after ACL failure failed"); }
            throw new InvalidOperationException(
                $"Could not secure scripts directory {directory}. Refusing to continue with world-readable temp dir.", ex);
        }
    }

    private void ExtractFromEmbeddedResources(string targetDir)
    {
        var assembly = Assembly.GetExecutingAssembly();
        var allNames = assembly.GetManifestResourceNames();

        var indexResourceName = allNames
            .FirstOrDefault(n => n.EndsWith("index.txt", StringComparison.OrdinalIgnoreCase));

        if (indexResourceName == null)
            throw new InvalidOperationException("Script manifest not found: index.txt");

        using var indexStream = assembly.GetManifestResourceStream(indexResourceName)
            ?? throw new InvalidOperationException("Script manifest not found: index.txt");
        using var reader = new StreamReader(indexStream);

        string? line;
        while ((line = reader.ReadLine()) != null)
        {
            if (string.IsNullOrWhiteSpace(line)) continue;
            ExtractSingleResource(assembly, allNames, line.Trim(), targetDir);
        }
    }

    private void ExtractSingleResource(Assembly assembly, string[] allNames, string relativePath, string targetDir)
    {
        var msbuildSuffix = "Scripts." + relativePath
            .Replace('/', '.')
            .Replace('\\', '.')
            .Replace(' ', '_');

        var resourceName = allNames.FirstOrDefault(n =>
            n.EndsWith(msbuildSuffix, StringComparison.OrdinalIgnoreCase));

        if (resourceName == null)
        {
            _logger.LogError("Missing embedded resource for: {Path} (looked for suffix: {Suffix})", relativePath, msbuildSuffix);
            throw new InvalidOperationException($"Missing embedded resource: {relativePath}");
        }

        using var stream = assembly.GetManifestResourceStream(resourceName)
            ?? throw new InvalidOperationException($"Missing embedded resource: {resourceName}");

        var destination = Path.Combine(targetDir, relativePath.Replace('/', Path.DirectorySeparatorChar));
        var parentDir = Path.GetDirectoryName(destination);
        if (parentDir != null)
            Directory.CreateDirectory(parentDir);

        using var fileStream = File.Create(destination);
        stream.CopyTo(fileStream);
    }
}
