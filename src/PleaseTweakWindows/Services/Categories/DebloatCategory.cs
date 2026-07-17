using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static Tweak BuildDebloat() => new(
        "Debloat",
        $"Debloat{S}debloat.ps1",
        [
            new SubTweak("Remove Non-Core Store Apps", "bloatware-remove",
                "Remove and de-provision every installed Store app except the explicit protected core/useful-app allowlist. This can remove apps you installed yourself")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' removes ALL Store apps that are not on the protected allowlist, including apps you installed yourself.\n\n" +
                    "Packages are also de-provisioned for new users. The saved inventory is not a guaranteed offline restore; reinstalling some apps may require Microsoft Store. Create a restore point first.",
            },
            new SubTweak("Keep Bloatware Removed (persistent)", SubTweakType.Toggle, "bloatware-persist-on", "bloatware-persist-off",
                "Install a logon task that re-removes bloatware Windows re-adds via updates. WARNING: runs as SYSTEM at every logon and removes all non-protected Store apps; Restore Default removes the task and its script")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' installs a scheduled task that runs as SYSTEM at every logon.\n\n" +
                    "WARNING: it removes and de-provisions ALL non-protected Store apps each time you sign in, so apps Windows re-adds via updates are removed again. " +
                    "Restore Default deletes the task and its script.",
            },
            new SubTweak("Install Microsoft Store", "store-install",
                "Reinstall Microsoft Store"),
            new SubTweak("Disable Widgets", SubTweakType.Toggle, "widgets-disable", "widgets-enable",
                "Disable Windows 11 Widgets"),
            new SubTweak("Disable Background Apps", SubTweakType.Toggle, "background-apps-disable", "background-apps-enable",
                "Prevent apps from running in background"),
            new SubTweak("Remove legacy Windows capabilities", SubTweakType.Toggle,
                "capabilities-remove-legacy", "capabilities-restore-legacy",
                "Remove optional legacy capabilities (Internet Explorer 11, WordPad, Steps Recorder, PowerShell ISE, Quick Assist, Windows Media Player). Restore Default re-adds them (needs internet / Features-on-Demand source)")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' removes legacy Windows capabilities (IE11, WordPad, Steps Recorder, PowerShell ISE, Quick Assist, Windows Media Player).\n\n" +
                    "These are optional and re-installable. Restore Default re-adds them, which needs internet access or a Features-on-Demand source.",
            },
            new SubTweak("Enable virtualization features", SubTweakType.Toggle,
                "features-virtualization-enable", "features-virtualization-disable",
                "Turn on Hyper-V, WSL, Virtual Machine Platform, Windows Hypervisor Platform and Windows Sandbox. WARNING: the hypervisor can break some anti-cheat games and older third-party VM software; requires a reboot. Restore Default disables them")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' enables the Windows virtualization features (Hyper-V, WSL, VM Platform, Hypervisor Platform, Sandbox).\n\n" +
                    "WARNING: turning on the hypervisor can break third-party hypervisors (older VMware/VirtualBox) and some anti-cheat games, and REQUIRES A REBOOT. Restore Default disables them again.",
            },
            new SubTweak("Disable Reserved Storage", SubTweakType.Toggle,
                "reserved-storage-disable", "reserved-storage-enable",
                "Turn off Windows Reserved Storage to reclaim the ~7 GB the OS sets aside for updates and temp files. WARNING: feature updates may need to free that space themselves; Restore Default re-enables it (both fail if an update is mid-flight)")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' turns off Windows Reserved Storage (frees the ~7 GB the OS reserves for updates).\n\n" +
                    "WARNING: both Apply and Restore Default can fail if a feature update is mid-flight. Run them only when no Windows update is installing. Without the reserve, a future feature update has to free the space itself.",
            },
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
                "Restore all Windows services to default state")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' rewrites Windows service start types to their defaults.\n\n" +
                    "WARNING: any custom or organization-managed service configuration will be overwritten. Continue only if restoring Windows defaults is what you intend.",
            },
        ]);
}
