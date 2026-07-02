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
                "Apply the bundled O&O ShutUp10++ privacy/performance profile")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' applies a broad set of privacy and security policies through O&O ShutUp10++.\n\n" +
                    "This one-shot profile has no automatic Restore Default action. Create a restore point and review the bundled profile first.",
            },
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
                "Disable Windows Copilot through per-user and machine policy without uninstalling the app; Restore Default removes those policy overrides")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will disable Windows Copilot.\n\n" +
                    "This sets per-user and machine policy to prevent Copilot from running. The installed app package is left intact.",
            },
            new SubTweak("Disable Telemetry", SubTweakType.Toggle,
                "telemetry-off", "telemetry-off-revert",
                "Minimize Windows diagnostic-data collection via policy (SmartScreen/Defender reporting untouched); Restore Default removes the policy override"),
            new SubTweak("Enforce telemetry/consumer GPO policies", SubTweakType.Toggle,
                "telemetry-policy-enforce", "telemetry-policy-enforce-revert",
                "Set the GPO-enforcing DWORDs that disable consumer content, tailored experiences, AIT/CEIP, implicit feedback, device-name telemetry and the advertising ID"),
            new SubTweak("Block Microsoft account sign-in", SubTweakType.Toggle,
                "block-ms-account", "block-ms-account-revert",
                "Block adding or using a Microsoft account (NoConnectedUser=3). WARNING: breaks Store/OneDrive/Copilot/Office sign-in; Restore Default removes the block")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' blocks adding or using a Microsoft account on this PC.\n\n" +
                    "WARNING: this breaks Microsoft Store purchases, OneDrive, Copilot and Office sign-in (NoConnectedUser=3). Restore Default removes the block.",
            },
            new SubTweak("Disable OneDrive sync (policy)", SubTweakType.Toggle,
                "onedrive-policy-disable", "onedrive-policy-disable-revert",
                "Disable OneDrive file sync via policy (DisableFileSyncNGSC=1) so removal stays durable across reinstall"),
            new SubTweak("Disable Windows Recall (native)", SubTweakType.Toggle,
                "privacy-recall-disable", "privacy-recall-disable-revert",
                "Suppress Windows Recall / AI snapshot saving via native policy (DisableAIDataAnalysis=1, AllowRecallEnablement=0) — does not depend on running the O&O ShutUp10 profile"),
            new SubTweak("Deny camera + microphone app access", SubTweakType.Toggle,
                "privacy-camera-mic-deny", "privacy-camera-mic-deny-revert",
                "Set the system-wide app permission for the webcam and microphone to Deny (the two sensors the privacy batch leaves on). WARNING: blocks Camera/Teams/Zoom etc. until restored or re-allowed per app in Settings")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' denies ALL apps access to the camera and microphone system-wide.\n\n" +
                    "WARNING: camera/mic apps (Windows Camera, Teams, Zoom, etc.) will be blocked until you use Restore Default or re-allow them per app in Settings > Privacy & security.",
            },
            new SubTweak("Disable telemetry scheduled tasks", SubTweakType.Toggle,
                "privacy-telemetry-tasks-disable", "privacy-telemetry-tasks-disable-revert",
                "Disable the Appraiser / ProgramDataUpdater / CEIP / feedback / error-reporting scheduled tasks that collect and upload diagnostic data. Restore Default re-enables them")
            {
                Risk = SubTweakRisk.Confirm,
            },
            new SubTweak("Disable location services (policy)", SubTweakType.Toggle,
                "privacy-location-disable", "privacy-location-disable-revert",
                "Turn off the Windows location platform and location scripting via policy (DisableLocation=1). WARNING: breaks Maps, 'Find my device', weather and any app that needs your location")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' disables the Windows location platform system-wide.\n\n" +
                    "Maps, 'Find my device', weather and any app relying on location will stop working until the default is restored.",
            },
            new SubTweak("Disable web/Bing results in Search", SubTweakType.Toggle,
                "privacy-web-search-disable", "privacy-web-search-disable-revert",
                "Stop Start menu / Search from sending queries to Bing and showing web suggestions (DisableWebSearch=1). Local file/app search is unaffected"),
            new SubTweak("Disable Delivery Optimization peer sharing", SubTweakType.Toggle,
                "privacy-delivery-optimization-disable", "privacy-delivery-optimization-disable-revert",
                "Set Delivery Optimization to HTTP-only (DODownloadMode=0) so Windows/Store updates aren't peer-to-peer uploaded or fetched from other PCs"),
            new SubTweak("Set Cloudflare DNS", "dns-cloudflare",
                "Set DNS to Cloudflare (1.1.1.1, 1.0.0.1)"),
            new SubTweak("Set Google DNS", "dns-google",
                "Set DNS to Google (8.8.8.8, 8.8.4.4)"),
            new SubTweak("Set Quad9 DNS (malware-blocking)", "dns-quad9",
                "Set DNS to Quad9 (9.9.9.9, 149.112.112.112) — blocks known-malicious domains at the resolver"),
            new SubTweak("Reset DNS to automatic", "dns-reset",
                "Reset all adapters' DNS to automatic (DHCP) - undoes Cloudflare/Google DNS"),
            new SubTweak("Enable DNS over HTTPS (DoH)", SubTweakType.Toggle,
                "doh-enable", "doh-enable-revert",
                "Enable encrypted DNS for common DNS providers"),
        ]);
}
