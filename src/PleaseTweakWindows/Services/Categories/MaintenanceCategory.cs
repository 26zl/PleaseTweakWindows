using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static Tweak BuildMaintenance() => new(
        "Maintenance & Tools",
        $"Maintenance{S}maintenance.ps1",
        [
            new SubTweak("Install C++ Redistributables", "cpp-install",
                "Install Visual C++ Runtime libraries"),
            new SubTweak("Install Display Driver Uninstaller (DDU)", "ddu-install",
                "Download the pinned DDU package to Program Files and create a desktop shortcut; this does not remove a driver")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' downloads and installs DDU under Program Files.\n\n" +
                    "No driver is removed by this action. Driver cleanup only starts if you later choose it inside DDU.",
            },
            new SubTweak("System Cleanup", "cleanup-run",
                "Run Windows Disk Cleanup and optimize storage")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will delete temporary files and caches.\n\n" +
                    "This is generally safe but cannot be undone.",
            },
            new SubTweak("Autoruns (Manage Startup)", "autoruns-open",
                "Open Sysinternals Autoruns to manage startup programs"),
        ]);
}
