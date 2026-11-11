using PleaseTweakWindows.Services;
using Xunit;

[assembly: AssemblyFixture(typeof(PleaseTweakWindows.Tests.TestLogsDirectoryFixture))]

namespace PleaseTweakWindows.Tests;

/// <summary>
/// Points the app's log directory at a temporary folder for the whole test run, so running the tests
/// never creates %LOCALAPPDATA%\PleaseTweakWindows on the developer's machine.
/// </summary>
public sealed class TestLogsDirectoryFixture : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), $"ptw-tests-{Guid.NewGuid():N}");

    public TestLogsDirectoryFixture()
    {
        AppPaths.LogsDirectoryOverride = Path.Combine(_root, "logs");
    }

    public void Dispose()
    {
        AppPaths.LogsDirectoryOverride = null;
        try
        {
            if (Directory.Exists(_root))
                Directory.Delete(_root, recursive: true);
        }
        catch (IOException)
        {
            // A log file still open by a finished test only leaves a temp folder behind.
        }
        catch (UnauthorizedAccessException)
        {
            // Same as above.
        }
    }
}
