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

            // Prefer filesystem scripts/ next to the EXE (distributed by Build.bat)
            var exeDirScripts = Path.Combine(AppContext.BaseDirectory, "scripts");
            if (Directory.Exists(exeDirScripts))
            {
                _logger.LogInformation("Using filesystem scripts directory: {Dir}", exeDirScripts);
                var tempDir = CreateTempDirectory();
                CopyDirectory(exeDirScripts, tempDir);
                _scriptsDirectory = tempDir;
                return tempDir;
            }

            // Fall back to embedded resources via index.txt
            _logger.LogInformation("Extracting scripts from embedded resources");
            var tempDir2 = CreateTempDirectory();
            ExtractFromEmbeddedResources(tempDir2);
            _scriptsDirectory = tempDir2;
            return tempDir2;
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

            // Remove inherited rules
            security.SetAccessRuleProtection(isProtected: true, preserveInheritance: false);
            var rules = security.GetAccessRules(true, true, typeof(SecurityIdentifier));
            foreach (FileSystemAccessRule rule in rules)
            {
                security.RemoveAccessRule(rule);
            }

            // Add owner-only full control
            var currentUser = WindowsIdentity.GetCurrent().User;
            if (currentUser != null)
            {
                security.AddAccessRule(new FileSystemAccessRule(
                    currentUser,
                    FileSystemRights.FullControl,
                    InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                    PropagationFlags.None,
                    AccessControlType.Allow));
            }

            dirInfo.SetAccessControl(security);
            _logger.LogDebug("Restricted temp directory permissions to owner only: {Dir}", directory);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not restrict temp directory permissions: {Dir}", directory);
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
        // MSBuild converts embedded resource paths: spaces -> _, slashes -> dots
        // e.g. "Gaming optimizations/Gaming-Optimizations.ps1"
        //   -> "PleaseTweakWindows.Scripts.Gaming_optimizations.Gaming-Optimizations.ps1"
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

    private static void CopyDirectory(string sourceDir, string targetDir)
    {
        foreach (var dirPath in Directory.GetDirectories(sourceDir, "*", SearchOption.AllDirectories))
        {
            Directory.CreateDirectory(dirPath.Replace(sourceDir, targetDir));
        }

        foreach (var filePath in Directory.GetFiles(sourceDir, "*", SearchOption.AllDirectories))
        {
            File.Copy(filePath, filePath.Replace(sourceDir, targetDir), overwrite: true);
        }
    }
}
