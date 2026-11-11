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
                "Download the pinned DDU package to Program Files and create a desktop shortcut; this does not remove a driver. Installs 7-Zip to Program Files first if it is missing (7-Zip stays installed)")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' downloads and installs DDU under Program Files.\n\n" +
                    "DDU ships as a 7-Zip archive: if 7-Zip is not installed, the pinned 7-Zip installer is downloaded, verified and installed to Program Files first, and it stays installed. " +
                    "No driver is removed by this action. Driver cleanup only starts if you later choose it inside DDU.",
            },
            new SubTweak("System Cleanup", "cleanup-run",
                "Delete files in your TEMP and Windows Temp folders (the Recycle Bin is not touched)")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will delete the contents of your TEMP folder and the Windows Temp folder.\n\n" +
                    "Files that are in use are skipped. The Recycle Bin is not emptied; use 'Empty Recycle Bin' for that.",
            },
            new SubTweak("Empty Recycle Bin", "recycle-bin-empty",
                "Permanently delete everything in the Recycle Bin on all drives")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' permanently deletes every file in the Recycle Bin on all drives.\n\n" +
                    "The files cannot be recovered afterwards, not with Restore Default and not with a system restore point.",
            },
            new SubTweak("Autoruns (Manage Startup)", "autoruns-open",
                "Open Sysinternals Autoruns to manage startup programs"),
        ]);
}
