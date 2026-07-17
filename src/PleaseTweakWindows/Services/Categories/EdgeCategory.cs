using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static Tweak BuildEdge() => new(
        "Edge",
        $"Edge{S}Edge.ps1",
        [
            new SubTweak("Edge Security Baseline", SubTweakType.Toggle, "edge-harden", "edge-harden-revert",
                "Enforce SmartScreen + PUA + typosquatting protection, block insecure auth/SSL override, site isolation, audio sandbox, Encrypted Client Hello, secure DNS, block third-party cookies. Breaks nothing in normal browsing; Restore Default removes the policies"),
            new SubTweak("Edge HardCore Hardening", SubTweakType.Toggle, "edge-hardcore", "edge-hardcore-revert",
                "Enhanced Security Mode (Strict, disables JIT), Strict tracking prevention, block insecure private-network requests. WARNING: can slow/break some sites and intranet web UIs; Restore Default removes the policies")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' enables Edge Enhanced Security Mode (Strict, disables JIT), strict tracking prevention, and blocks insecure private-network requests.\n\n" +
                    "WARNING: this can slow or break some sites and intranet web UIs. Restore Default removes the policies.",
            },
        ]);
}
