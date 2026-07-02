using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static Tweak BuildDeviceGuard() => new(
        "Device Guard",
        $"Device Guard{S}device-guard.ps1",
        $"Device Guard{S}revert-device-guard.ps1",
        [
            new SubTweak("LSA protection (RunAsPPL)", SubTweakType.Toggle,
                "security-lsa-protection-enable", "security-lsa-protection-enable-revert",
                "Run LSASS as a Protected Process so tools can't dump credentials from its memory. Requires REBOOT. WARNING: rare legacy auth/SSO/smartcard plugins that inject into LSASS may break")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' runs LSASS as a Protected Process (RunAsPPL).\n\n" +
                    "Blocks credential dumping from LSASS memory. REQUIRES A REBOOT. Rare legacy authentication/SSO/smartcard plugins that inject into LSASS may stop working.",
            },
            new SubTweak("Memory Integrity (HVCI)", SubTweakType.Toggle,
                "security-hvci-enable", "security-hvci-enable-revert",
                "Enable Virtualization-Based Security + Hypervisor-Enforced Code Integrity. Requires REBOOT and compatible hardware. WARNING: blocks unsigned/incompatible kernel drivers (some anti-cheat, old drivers, VM tools). Not Mandatory mode, so Restore Default plus a reboot disables it")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' enables Virtualization-Based Security + Memory Integrity (HVCI).\n\n" +
                    "REQUIRES A REBOOT and compatible hardware. HVCI blocks unsigned/incompatible kernel drivers — some anti-cheat, older hardware drivers and virtualization tools may stop working. Not Mandatory mode, so Restore Default plus a reboot disables it.",
            },
            new SubTweak("Credential Guard", SubTweakType.Toggle,
                "security-credential-guard-enable", "security-credential-guard-enable-revert",
                "Isolate LSA secrets via VBS to stop credential theft. Requires REBOOT and compatible hardware. WARNING: can break legacy SSO/VPN/credential providers. Configured without a UEFI lock so it stays reversible")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' enables Credential Guard (VBS-isolated LSA).\n\n" +
                    "REQUIRES A REBOOT and compatible hardware. Can break legacy SSO, some VPN/credential providers and older Wi-Fi/RADIUS auth. Configured without a UEFI lock so it stays reversible from Windows.",
            },
            new SubTweak("Vulnerable Driver Blocklist", SubTweakType.Toggle,
                "security-vuln-driver-blocklist", "security-vuln-driver-blocklist-revert",
                "Enable Microsoft's recommended vulnerable (BYOVD) driver block list so known-exploitable drivers can't load. Requires REBOOT. Low risk"),
            new SubTweak("Disable WDigest credential caching", SubTweakType.Toggle,
                "security-wdigest-disable", "security-wdigest-disable-revert",
                "Stop WDigest from caching plaintext credentials in LSASS memory (UseLogonCredential=0)"),
            new SubTweak("Memory Integrity — UEFI-locked",
                "security-hvci-mandatory",
                "One-way action: UEFI-lock Memory Integrity (HVCI) so it cannot be turned off from Windows. The app cannot automatically restore a firmware-applied lock; use Microsoft's documented UEFI removal procedure")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' applies the Memory Integrity (HVCI) UEFI lock.\n\n" +
                    "ONE-WAY FROM THIS APP: HVCI cannot be turned off from Windows after the firmware lock is applied. Clearing it requires Microsoft's documented UEFI removal procedure. The script refuses unless HVCI is confirmed running after a reboot.",
                Requires = new SubTweakRequirement("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\DeviceGuard\\Scenarios\\HypervisorEnforcedCodeIntegrity", "Enabled", 1, "Enable Memory Integrity (HVCI) first and reboot to activate it before applying the UEFI lock.")
            },
            new SubTweak("System Guard Secure Launch (DRTM)", SubTweakType.Toggle,
                "security-secure-launch", "security-secure-launch-revert",
                "Enable Dynamic Root of Trust for Measurement so firmware is measured at every boot. Requires REBOOT. WARNING: needs a DRTM-capable CPU/firmware; can prevent boot on incompatible hardware")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' enables System Guard Secure Launch (DRTM).\n\n" +
                    "SEVERE: requires a DRTM-capable CPU and firmware. On incompatible hardware this can PREVENT THE MACHINE FROM BOOTING. Requires a reboot. Enable Memory Integrity (HVCI) first.",
                Requires = new SubTweakRequirement("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\DeviceGuard\\Scenarios\\HypervisorEnforcedCodeIntegrity", "Enabled", 1, "Enable Memory Integrity (HVCI) first and reboot to activate it before enabling Secure Launch.")
            },
            new SubTweak("Block external DMA devices (Kernel DMA Protection)", SubTweakType.Toggle,
                "security-kernel-dma-protection", "security-kernel-dma-protection-revert",
                "Block newly-plugged external Thunderbolt/PCIe peripherals that don't support DMA remapping (DeviceEnumerationPolicy=0), defeating drive-by DMA attacks. Needs Kernel DMA Protection hardware. WARNING: incompatible external devices won't work while locked")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' blocks external DMA-capable peripherals incompatible with DMA remapping.\n\n" +
                    "Requires Kernel DMA Protection hardware support (UEFI + IOMMU). External Thunderbolt/PCIe devices without DMA-remapping support will be blocked while the screen is locked or before sign-in. Restore Default removes the policy.",
            },
        ]);
}
