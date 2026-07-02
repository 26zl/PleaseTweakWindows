using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static Tweak BuildPerformance() => new(
        "Performance & Power",
        $"Performance{S}performance.ps1",
        [
            new SubTweak("Ultimate Power Plan", SubTweakType.Toggle, "power-plan-on", "power-plan-default",
                "Apply Ultimate Performance power plan and unpark CPU cores"),
            new SubTweak("Apply Registry Tweaks", SubTweakType.Toggle, "registry-apply", "registry-default",
                "Apply performance and privacy registry optimizations")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will modify Windows registry settings.\n\n" +
                    "A restore point is recommended before proceeding.",
            },
            new SubTweak("125%/150% Scaling Fix", SubTweakType.Toggle, "scaling-fix", "scaling-default",
                "Disable DPI scaling acceleration"),
            new SubTweak("Disable HDCP", SubTweakType.Toggle, "hdcp-disable", "hdcp-enable",
                "Disable HDCP (High-bandwidth Digital Content Protection)"),
            new SubTweak("Disable USB selective suspend", SubTweakType.Toggle, "usb-suspend-disable", "usb-suspend-default",
                "Stop Windows from powering down USB controllers to save energy — avoids audio dropouts, HID/controller stutter and random USB disconnects on the active power plan. Restore Default re-enables the Windows default"),
        ]);
}
