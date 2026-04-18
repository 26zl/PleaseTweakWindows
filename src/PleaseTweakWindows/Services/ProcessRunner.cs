using System.Diagnostics;

namespace PleaseTweakWindows.Services;

public sealed class ProcessRunner : IProcessRunner
{
    public Process Start(ProcessStartInfo startInfo)
    {
        return Process.Start(startInfo)
            ?? throw new InvalidOperationException("Failed to start process.");
    }
}
