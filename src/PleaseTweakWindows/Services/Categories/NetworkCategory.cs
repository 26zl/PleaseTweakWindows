using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static Tweak BuildNetworkOptimizations() => new(
        "Network Optimizations",
        $"Network optimizations{S}Network-Optimizations.ps1",
        [
            new SubTweak("IPv4 Only Adapter Bindings", SubTweakType.Toggle, "adapter-ipv4only", "adapter-default",
                "Disable IPv6 and unnecessary protocols for gaming")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' unbinds IPv6 and other adapter protocols.\n\n" +
                    "WARNING: this can break IPv6-only or dual-stack networks and anything that depends on those bindings (some file/printer sharing, VPNs). Restore Default re-enables the default bindings.",
            },
            new SubTweak("Smart Network Optimization", "smart-optimize",
                "Optimize network adapters, disable throttling, power saving features"),
            new SubTweak("Smart Network Optimization (Aggressive)", "smart-optimize-aggressive",
                "Also disables Flow Control/Jumbo Frames and forces Interrupt Moderation (may increase latency or reduce throughput)")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' applies aggressive network adapter changes.\n\n" +
                    "It may disable Flow Control/Jumbo Frames and force Interrupt Moderation.\n" +
                    "This can reduce throughput on some LANs or increase latency.",
            },
            new SubTweak("Restore Smart Network Defaults", "smart-optimize-revert",
                "Restore multimedia network defaults and the latest adapter settings snapshot created by Smart Network Optimization"),
        ]);
}
