using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static Tweak BuildDefender() => new(
        "Microsoft Defender",
        $"Defender{S}defender.ps1",
        $"Defender{S}revert-defender.ps1",
        [
            new SubTweak("Enable Defender Controlled Folder Access", SubTweakType.Toggle,
                "security-defender-cfa-enable", "security-defender-cfa-enable-revert",
                "Ransomware protection: block untrusted apps from writing to protected folders")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' will enable Defender Controlled Folder Access.\n\n" +
                    "WARNING: Some apps (games, sync tools, backup software) may be blocked from writing to protected folders. " +
                    "You can whitelist apps via Windows Security > Virus & threat protection > Ransomware protection.",
            },
            new SubTweak("Enable Defender Network Protection", SubTweakType.Toggle,
                "security-defender-network-protection-enable", "security-defender-network-protection-enable-revert",
                "Block connections to known malicious IPs and domains (SmartScreen for network)")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will enable Defender Network Protection.\n\n" +
                    "Blocks connections to known malicious IPs and domains. Occasionally flags legitimate sites — check event log if something breaks.",
            },
            new SubTweak("Enable Defender PUA Protection", SubTweakType.Toggle,
                "security-defender-pua-enable", "security-defender-pua-enable-revert",
                "Detect and block Potentially Unwanted Applications (adware, bundled installers)"),
            new SubTweak("Tune Defender cloud protection (Block At First Sight, MAPS High)", SubTweakType.Toggle,
                "security-defender-cloud-tune", "security-defender-cloud-tune-revert",
                "Maximum cloud-based detection: Block At First Sight + MAPS Advanced + Cloud Block Level High")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will set Defender cloud protection to maximum aggressiveness.\n\n" +
                    "MAPS Advanced reporting + Cloud Block Level High + Block At First Sight. " +
                    "Requires internet connectivity for real-time cloud lookups; may slow first-run of unsigned apps.",
            },
            new SubTweak("Run Defender in sandbox (MP_FORCE_USE_SANDBOX=1)", SubTweakType.Toggle,
                "security-defender-sandbox-enable", "security-defender-sandbox-enable-revert",
                "Tamper-resistant Defender process (requires REBOOT to take effect)")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will run Defender Antivirus inside a sandbox.\n\n" +
                    "REQUIRES REBOOT to take effect. Tamper-resistant but may increase CPU overhead slightly.",
            },
            new SubTweak("Attack Surface Reduction (ASR) rules", SubTweakType.Toggle,
                "security-asr-rules-enable", "security-asr-rules-enable-revert",
                "Enable all 19 Defender ASR rules (17 Block, 2 Warn): block Office/Adobe child processes, LSASS credential theft, script/macro abuse, untrusted USB executables, ransomware. WARNING: can block some legitimate installers/macros. Requires Defender; needs Tamper Protection off")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' enables all Defender Attack Surface Reduction rules.\n\n" +
                    "Blocks Office/Adobe child processes, LSASS credential theft, untrusted USB executables, script abuse and more. " +
                    "Some legitimate installers and macro-heavy workflows may be blocked. Requires Defender with Tamper Protection off.",
            },
            new SubTweak("Defender maximum protection", SubTweakType.Toggle,
                "security-defender-max-protection", "security-defender-max-protection-revert",
                "Push Defender to maximum: ZeroTolerance cloud blocking, full sample submission, deep scan + signature scheduling, aggressive threat remediation, brute-force/remote-encryption protection. Needs Tamper Protection off. Revert resets toward Windows defaults")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' pushes Microsoft Defender to maximum aggressiveness.\n\n" +
                    "ZeroTolerance cloud blocking and full sample submission: first-run of unsigned apps may be delayed or blocked, and all suspicious samples are sent to Microsoft. Requires Tamper Protection off.",
            },
            new SubTweak("Defender: minimize gaming impact", SubTweakType.Toggle,
                "security-defender-gaming-scan", "security-defender-gaming-scan-revert",
                "Run Defender scheduled scans only when idle and cap their CPU at 30% for a real latency/FPS win. Real-time protection is unchanged. Needs Tamper Protection off"),
        ]);
}
