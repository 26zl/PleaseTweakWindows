using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static Tweak BuildGamingOptimizations() => new(
        "Gaming Optimizations",
        $"Gaming optimizations{S}Gaming-Optimizations.ps1",
        [
            new SubTweak("Nvidia Settings", SubTweakType.Toggle, "nvidia-settings-on", "nvidia-settings-default",
                "Optimize NVIDIA control panel settings for gaming performance. WARNING: the profile sets a global ~357 FPS cap and disables G-SYNC globally; advanced users may want to adjust these in the NVIDIA Control Panel"),
            new SubTweak("Nvidia Driver", "nvidia-driver-install",
                "Install/update NVIDIA driver"),
            new SubTweak("AMD Driver", "amd-driver-install",
                "Install/update AMD Radeon driver")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "AMD's driver download page will open in your browser.\n\n" +
                    "Click 'Download Windows Drivers' on the AMD page to get the latest Auto-Detect installer.\n" +
                    "The installer will detect your GPU and download the correct driver.",
            },
            new SubTweak("P0 State Nvidia", SubTweakType.Toggle, "p0-state-on", "p0-state-default",
                "Force maximum GPU performance state (disable dynamic P-states)"),
            new SubTweak("ULPS AMD", SubTweakType.Toggle, "ulps-disable", "ulps-enable",
                "Disable Ultra Low Power State for AMD GPUs"),
            new SubTweak("Xbox Game Bar", SubTweakType.Toggle, "gamebar-off", "gamebar-on",
                "Disable Xbox Game Bar and related services"),
            new SubTweak("MSI Mode", SubTweakType.Toggle, "msi-mode-on", "msi-mode-off",
                "Enable Message Signaled Interrupts for GPU"),
            new SubTweak("Unlock Background Polling Rate", SubTweakType.Toggle, "polling-unlock", "polling-default",
                "Remove background mouse polling rate cap"),
            new SubTweak("DirectX Runtime", "directx-install",
                "Install DirectX June 2010 Runtime"),
            new SubTweak("Disable Multi-Plane Overlay (fix flicker/stutter)", SubTweakType.Toggle, "mpo-on", "mpo-default",
                "Apply disables Multi-Plane Overlay (MPO) to fix screen flicker/stutter; revert restores the Windows default"),
            new SubTweak("Hardware-Accelerated GPU Scheduling (HAGS)", SubTweakType.Toggle, "hags-on", "hags-off",
                "Enable HAGS for lower DPC latency (reboot required; safe to revert)"),
            new SubTweak("Windows Game Mode", SubTweakType.Toggle, "game-mode-on", "game-mode-off",
                "Enable Windows Game Mode to prioritise the foreground game"),
        ]);
}
