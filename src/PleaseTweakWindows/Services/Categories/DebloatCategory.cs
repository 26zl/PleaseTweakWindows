using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static Tweak BuildDebloat() => new(
        "Debloat",
        $"Debloat{S}debloat.ps1",
        [
            new SubTweak("Remove Bloatware", "bloatware-remove",
                "Uninstall UWP apps and unnecessary Windows features")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will uninstall pre-installed Windows apps.\n\n" +
                    "Some apps may be difficult to reinstall. Make sure you have a restore point.",
            },
            new SubTweak("Keep Bloatware Removed (persistent)", SubTweakType.Toggle, "bloatware-persist-on", "bloatware-persist-off",
                "Install a logon task that re-removes bloatware Windows re-adds via updates. WARNING: runs as SYSTEM at every logon and removes all non-protected Store apps; revert removes the task and its script")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' installs a scheduled task that runs as SYSTEM at every logon.\n\n" +
                    "WARNING: it removes and de-provisions ALL non-protected Store apps each time you sign in, so apps Windows re-adds via updates are removed again. " +
                    "Revert deletes the task and its script.",
            },
            new SubTweak("Install Microsoft Store", "store-install",
                "Reinstall Microsoft Store"),
            new SubTweak("Disable Widgets", SubTweakType.Toggle, "widgets-disable", "widgets-enable",
                "Disable Windows 11 Widgets"),
            new SubTweak("Disable Background Apps", SubTweakType.Toggle, "background-apps-disable", "background-apps-enable",
                "Prevent apps from running in background"),
            new SubTweak("Disable Unnecessary Services", "services-disable",
                "Disable Windows services not needed for gaming. WARNING: also disables Printing (Print Spooler), File/Printer sharing hosting (LanmanServer), and Themes/visual styles")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' will disable Windows services.\n\n" +
                    "WARNING: This may break Windows features like printing, Bluetooth, or remote desktop.\n" +
                    "A system restore point is STRONGLY recommended.",
            },
            new SubTweak("Restore Default Services", "services-restore",
                "Restore all Windows services to default state"),
        ]);
}
