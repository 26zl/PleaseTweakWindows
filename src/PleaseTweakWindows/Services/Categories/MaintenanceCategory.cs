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
            new SubTweak("Clean GPU Drivers", "driver-clean",
                "Use DDU to clean GPU drivers")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' will remove GPU drivers using DDU.\n\n" +
                    "Your display may go blank temporarily. Have a new driver ready to install.",
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
