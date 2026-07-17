using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static Tweak BuildComplianceBaselines() => new(
        "STIG / CIS Baselines",
        $"Compliance{S}compliance-baselines.ps1",
        [
            new SubTweak("Windows 11 STIG V2R9-aligned baseline", SubTweakType.Toggle,
                "compliance-stig-v2r9-apply", "compliance-stig-v2r9-revert",
                "Apply a curated automatable subset aligned with the DISA Windows 11 STIG V2R9. This is not a compliance certification; validate with an approved scanner and review manual controls. Restore runs matching actions in reverse and returns them to documented Windows defaults")
            {
                Risk = SubTweakRisk.High,
                IncludeInRunAll = false,
                Warning =
                    "'{0}' applies dozens of restrictive security settings across Defender, Device Guard, auditing, networking, sign-in, PowerShell, SMB, TLS, printing, and Edge.\n\n" +
                    "WARNING: this can break legacy drivers, scripts, printers, remote administration, authentication, and older network peers. It is a curated automated subset, not proof of full STIG compliance. Test on a representative machine and keep the restore point.",
            },
            new SubTweak("Windows 11 CIS Level 1-aligned baseline", SubTweakType.Toggle,
                "compliance-cis-l1-apply", "compliance-cis-l1-revert",
                "Apply a conservative Windows 11 24H2 Level 1-aligned action set. This is not an official CIS Build Kit or certification; assess against your licensed benchmark. Restore returns matching settings to documented Windows defaults")
            {
                Risk = SubTweakRisk.High,
                IncludeInRunAll = false,
                Warning =
                    "'{0}' applies a broad security baseline across Defender, auditing, sign-in, networking, exploit protection, and Edge.\n\n" +
                    "WARNING: even Level 1-aligned settings can affect authentication, scripts, remote administration, applications, and network compatibility. Obtain the official CIS benchmark, test this profile, and keep the restore point.",
            },
        ]);
}
