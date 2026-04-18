using System.Diagnostics;

namespace PleaseTweakWindows.Services;

public interface IProcessRunner
{
    Process Start(ProcessStartInfo startInfo);
}
