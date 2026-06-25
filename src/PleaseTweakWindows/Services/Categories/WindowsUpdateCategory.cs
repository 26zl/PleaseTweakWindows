using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static Tweak BuildWindowsUpdate() => new(
        "Windows Update",
        $"Windows Update{S}windows-update.ps1",
        [
            new SubTweak("Default (Microsoft-managed updates)", "wu-default",
                "Restore normal automatic Windows Update — clears any mode set below"),
            new SubTweak("Security Updates Only", "wu-security-only",
                "Defer feature updates up to 365 days while quality/security updates keep flowing"),
            new SubTweak("Pause Updates (long)", "wu-pause-updates",
                "Pause all updates into the far future. Use Default to resume")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will pause all Windows updates into the far future.\n\n" +
                    "Security patches will not install while paused. Use the 'Default' mode to resume.",
            },
            new SubTweak("Turn Off Updates (aggressive)", "wu-disable",
                "Stop ALL Windows updates and disable the update services. WARNING: blocks security patches; your PC becomes progressively more vulnerable. Use Default to turn updates back on")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' will turn off Windows Update and disable the update services.\n\n" +
                    "SEVERE: your PC will stop receiving SECURITY patches and become progressively more vulnerable. " +
                    "Use the 'Default' mode to turn updates back on.",
            },
            new SubTweak("Secure (prompt installs of all MS products)", "wu-secure",
                "Auto-download but prompt before installing updates, and register Microsoft Update so other Microsoft products (Office, etc.) are covered too"),
        ]);
}
