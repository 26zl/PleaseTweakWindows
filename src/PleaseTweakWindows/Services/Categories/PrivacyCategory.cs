using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static Tweak BuildPrivacy() => new(
        "Privacy",
        $"Privacy Security{S}privacy.ps1",
        $"Privacy Security{S}revert-privacy.ps1",
        [
            new SubTweak("Apply OOSU10 Profile", "ooshutup-apply",
                "Apply the bundled O&O ShutUp10++ privacy/performance profile"),
            new SubTweak("Disable online content in File Explorer", SubTweakType.Toggle,
                "ui-online-content-disable", "ui-online-content-revert",
                "Disable online tips, wizards, and web services in File Explorer")
            {
                Risk = SubTweakRisk.Confirm,
            },
            new SubTweak("Secure recent document lists", SubTweakType.Toggle,
                "ui-secure-recent-docs", "ui-secure-recent-docs-revert",
                "Disable recent docs history and clear recent documents on exit")
            {
                Risk = SubTweakRisk.Confirm,
            },
            new SubTweak("Remove folders from This PC in File Explorer", SubTweakType.Toggle,
                "ui-remove-this-pc-folders", "ui-remove-this-pc-folders-revert",
                "Hide Desktop, Documents, Downloads, etc. from This PC (files stay on disk)")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will hide standard folders from This PC.\n\n" +
                    "The folders remain on disk, but Explorer shortcuts will be hidden.",
            },
            new SubTweak("Disable lock screen app notifications", SubTweakType.Toggle,
                "ui-lock-screen-notifications-disable", "ui-lock-screen-notifications-revert",
                "Disable notifications shown on the lock screen")
            {
                Risk = SubTweakRisk.Confirm,
            },
            new SubTweak("Disable the 'Look for an app in the Store' option", SubTweakType.Toggle,
                "ui-store-open-with-disable", "ui-store-open-with-revert",
                "Remove the Store prompt when opening unknown file types")
            {
                Risk = SubTweakRisk.Confirm,
            },
            new SubTweak("Disable the display of recently used files in Quick Access", SubTweakType.Toggle,
                "ui-quick-access-recent-disable", "ui-quick-access-recent-revert",
                "Hide recent files from Quick Access")
            {
                Risk = SubTweakRisk.Confirm,
            },
            new SubTweak("Disable sync provider notifications", SubTweakType.Toggle,
                "ui-sync-provider-notifications-disable", "ui-sync-provider-notifications-revert",
                "Disable OneDrive and sync provider notifications in Explorer")
            {
                Risk = SubTweakRisk.Confirm,
            },
            new SubTweak("Disable hibernation", SubTweakType.Toggle,
                "ui-hibernation-disable", "ui-hibernation-revert",
                "Disable hibernation to remove hiberfil.sys and speed up shutdown")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will disable hibernation.\n\n" +
                    "This removes hiberfil.sys and may affect Fast Startup and sleep behavior.",
            },
            new SubTweak("Enable camera on/off OSD notifications", SubTweakType.Toggle,
                "ui-camera-osd-enable", "ui-camera-osd-revert",
                "Show on-screen notifications when the camera turns on/off")
            {
                Risk = SubTweakRisk.Confirm,
            },
            new SubTweak("Disable Copilot", SubTweakType.Toggle,
                "copilot-disable", "copilot-disable-revert",
                "Disable Windows Copilot AI assistant. Note: applying uninstalls the Copilot app; revert only re-allows it via policy and does not reinstall it")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will disable Windows Copilot.\n\n" +
                    "This removes the Copilot app and sets group policy to prevent it from running.",
            },
            new SubTweak("Disable Telemetry", SubTweakType.Toggle,
                "telemetry-off", "telemetry-off-revert",
                "Minimize Windows diagnostic-data collection via policy (SmartScreen/Defender reporting untouched); revert removes the policy override"),
            new SubTweak("Enforce telemetry/consumer GPO policies", SubTweakType.Toggle,
                "telemetry-policy-enforce", "telemetry-policy-enforce-revert",
                "Set the GPO-enforcing DWORDs that disable consumer content, tailored experiences, AIT/CEIP, implicit feedback, device-name telemetry and the advertising ID"),
            new SubTweak("Block Microsoft account sign-in", SubTweakType.Toggle,
                "block-ms-account", "block-ms-account-revert",
                "Block adding or using a Microsoft account (NoConnectedUser=3). WARNING: breaks Store/OneDrive/Copilot/Office sign-in; revert removes the block")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' blocks adding or using a Microsoft account on this PC.\n\n" +
                    "WARNING: this breaks Microsoft Store purchases, OneDrive, Copilot and Office sign-in (NoConnectedUser=3). Revert removes the block.",
            },
            new SubTweak("Disable OneDrive sync (policy)", SubTweakType.Toggle,
                "onedrive-policy-disable", "onedrive-policy-disable-revert",
                "Disable OneDrive file sync via policy (DisableFileSyncNGSC=1) so removal stays durable across reinstall"),
            new SubTweak("Set Cloudflare DNS", "dns-cloudflare",
                "Set DNS to Cloudflare (1.1.1.1, 1.0.0.1)"),
            new SubTweak("Set Google DNS", "dns-google",
                "Set DNS to Google (8.8.8.8, 8.8.4.4)"),
            new SubTweak("Reset DNS to automatic", "dns-reset",
                "Reset all adapters’ DNS to automatic (DHCP) — undoes Cloudflare/Google DNS"),
            new SubTweak("Enable DNS over HTTPS (DoH)", SubTweakType.Toggle,
                "doh-enable", "doh-enable-revert",
                "Enable encrypted DNS for common DNS providers"),
        ]);
}
