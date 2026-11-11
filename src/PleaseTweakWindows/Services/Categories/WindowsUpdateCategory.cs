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
            new SubTweak("Defer Feature Updates", "wu-security-only",
                "Defer feature updates up to 365 days while quality/security and other applicable updates keep flowing"),
            new SubTweak("Pause Updates (35 days)", "wu-pause-updates",
                "Pause all updates for 35 days, the longest pause Windows itself offers. Updates resume automatically afterwards; use Default to resume earlier")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' pauses all Windows updates, including security patches, for 35 days.\n\n" +
                    "No security patches install while paused. Updates resume automatically when the pause ends; use the 'Default' mode to resume earlier.",
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
