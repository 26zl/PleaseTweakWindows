using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static readonly char S = Path.DirectorySeparatorChar;

    private readonly IReadOnlyList<Tweak> _tweaks = BuildTweaks();

    public IReadOnlyList<Tweak> GetTweaks() => _tweaks;

    private static IReadOnlyList<Tweak> BuildTweaks() =>
    [
        BuildGamingOptimizations(),
        BuildPerformance(),
        BuildNetworkOptimizations(),
        BuildDebloat(),
        BuildPrivacy(),
        BuildDefender(),
        BuildExploitProtection(),
        BuildDeviceGuard(),
        BuildNetworkSecurity(),
        BuildSystemSecurity(),
        BuildComplianceBaselines(),
        BuildCustomize(),
        BuildMaintenance(),
        BuildWindowsUpdate(),
        BuildEdge()
    ];
}
