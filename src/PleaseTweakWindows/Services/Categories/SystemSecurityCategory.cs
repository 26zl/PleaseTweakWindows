using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static Tweak BuildSystemSecurity() => new(
        "System Security",
        $"System Security{S}system-security.ps1",
        $"System Security{S}revert-system-security.ps1",
        [
            new SubTweak("Disable clipboard data collection", SubTweakType.Toggle,
                "security-clipboard-data-disable", "security-clipboard-data-revert",
                "Disable clipboard sync, history, and background clipboard service")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will disable clipboard sync and history.\n\n" +
                    "Clipboard sync across devices and history will stop working.",
            },
            new SubTweak("Disable AutoPlay and AutoRun", SubTweakType.Toggle,
                "security-autorun-disable", "security-autorun-revert",
                "Disable AutoPlay/AutoRun for all drives and devices")
            {
                Risk = SubTweakRisk.Confirm,
                Warning = "'{0}' disables AutoPlay and AutoRun for every drive and device, so inserting media or USB drives will no longer launch programs automatically.",
            },
            new SubTweak("Disable lock screen camera access", SubTweakType.Toggle,
                "security-lock-screen-camera-disable", "security-lock-screen-camera-revert",
                "Block camera access on the lock screen")
            {
                Risk = SubTweakRisk.Confirm,
            },
            new SubTweak("Disable storage of the LAN Manager password hashes", SubTweakType.Toggle,
                "security-lm-hash-disable", "security-lm-hash-revert",
                "Prevent LM hash storage for local passwords")
            {
                Risk = SubTweakRisk.Confirm,
                Warning = "'{0}' stops Windows from storing the weak LAN Manager (LM) hash of local passwords; very old LM-only network clients may no longer be able to authenticate.",
            },
            new SubTweak("Disable \"Always install with elevated privileges\" in Windows Installer", SubTweakType.Toggle,
                "security-always-install-elevated-disable", "security-always-install-elevated-revert",
                "Prevent MSI privilege escalation (AlwaysInstallElevated)")
            {
                Risk = SubTweakRisk.Confirm,
                Warning = "'{0}' clears the AlwaysInstallElevated policy so MSI packages no longer install with SYSTEM privileges; per-user installs that relied on that elevation may fail.",
            },
            new SubTweak("Enable security against PowerShell 2.0 downgrade attacks", SubTweakType.Toggle,
                "security-ps2-downgrade-protection-enable", "security-ps2-downgrade-protection-revert",
                "Disable PowerShell 2.0 optional features")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will disable PowerShell 2.0 optional features.\n\n" +
                    "Legacy scripts requiring PowerShell 2.0 may stop working.",
            },
            new SubTweak("Disable \"Windows Connect Now\" wizard", SubTweakType.Toggle,
                "security-wcn-disable", "security-wcn-revert",
                "Disable WCN UI/registrars")
            {
                Risk = SubTweakRisk.Confirm,
                Warning = "'{0}' disables the Windows Connect Now wizard and its registrars, so the WPS push-button wizard for adding Wi-Fi devices will no longer be available.",
            },
            new SubTweak("Silent elevation for administrators (no UAC prompt)", SubTweakType.Toggle,
                "security-uac-silent-elevation", "security-uac-silent-elevation-revert",
                "Set User Account Control to 'Never notify' so admin apps elevate without a prompt. WARNING: aggressive — malware that gains admin can act unattended (EnableLUA stays on). Restore Default restores the default prompt")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' sets User Account Control to 'Never notify'.\n\n" +
                    "WARNING: programs that request administrator rights will elevate WITHOUT a prompt, so malware that gets admin can act unattended. " +
                    "EnableLUA stays on; Restore Default restores the default prompt.",
            },
            new SubTweak("Binary integrity hardening", SubTweakType.Toggle,
                "security-binary-integrity-harden", "security-binary-integrity-harden-revert",
                "Enforce certificate-padding check (CVE-2013-3900), signed-only AMSI providers, full command-line auditing in event 4688, and always-visible .url/.lnk/.pif extensions (anti-phishing)"),
            new SubTweak("svchost.exe mitigation policy", SubTweakType.Toggle,
                "security-svchost-mitigation-enable", "security-svchost-mitigation-enable-revert",
                "Force svchost child processes to be Microsoft-signed-only with extra mitigations. WARNING: requires a Business SKU; can break third-party services that inject unsigned DLLs into svchost")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' forces svchost child processes to load only Microsoft-signed code.\n\n" +
                    "SEVERE: requires a Business/Enterprise Windows SKU and can break third-party services that inject unsigned DLLs into svchost. Restore Default removes the policy.",
            },
            new SubTweak("Enforce SmartScreen (Block)", SubTweakType.Toggle,
                "security-smartscreen-enforce", "security-smartscreen-enforce-revert",
                "Force Microsoft Defender SmartScreen on for apps/files at the Block level (phishing/malware URL + download reputation)"),
            new SubTweak("Lock screen / logon hardening", SubTweakType.Toggle,
                "security-lock-screen-harden", "security-lock-screen-harden-revert",
                "Don't show the last/locked user name, require Ctrl+Alt+Del to sign in, hide the lock-screen network UI, set a 2-min inactivity lock. WARNING: changes the sign-in UX")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' hides the last user name, requires Ctrl+Alt+Del to sign in, hides the lock-screen network UI, and sets a 2-minute inactivity lock.\n\n" +
                    "WARNING: this changes the sign-in experience for everyone on this PC. Restore Default returns to the Windows defaults.",
            },
            new SubTweak("Account lockout policy", SubTweakType.Toggle,
                "security-account-lockout", "security-account-lockout-revert",
                "Lock an account for 15 minutes after 3 failed sign-ins (anti brute-force; STIG/CIS threshold). WARNING: repeated password mistakes will temporarily lock you out; Restore Default disables lockout")
            {
                Risk = SubTweakRisk.High,
                Warning =
                    "'{0}' locks an account for 15 minutes after 3 failed sign-ins.\n\n" +
                    "WARNING: repeatedly mistyping your password — including a local administrator — will lock you out temporarily. Restore Default disables lockout.",
            },
            new SubTweak("PowerShell audit logging", SubTweakType.Toggle,
                "security-powershell-audit", "security-powershell-audit-revert",
                "Enable script-block, module and transcription logging for Windows PowerShell and PowerShell 7. Transcripts are admin-only but can capture commands, paths, output, and secrets typed on a command line")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' enables system-wide PowerShell script-block, module, and transcript logging.\n\n" +
                    "Transcripts are stored in an administrator-only ProgramData folder, but they can contain command output, paths, account names, tokens, or passwords passed on a command line. Restore Default disables the policy and removes the transcript folder.",
            },
            new SubTweak("Advanced audit policy", SubTweakType.Toggle,
                "security-audit-policy", "security-audit-policy-revert",
                "Enable success+failure auditing for 8 key subcategories (logon, process creation, privilege use, removable storage, etc.) and force subcategory override"),
            new SubTweak("Disable driver co-installers", SubTweakType.Toggle,
                "security-disable-coinstallers", "security-disable-coinstallers-revert",
                "Stop vendor driver co-installer DLLs from running during device setup (DisableCoInstallers=1)"),
            new SubTweak("Disable Windows Script Host", SubTweakType.Toggle,
                "security-wsh-disable", "security-wsh-disable-revert",
                "Block all .vbs/.js/.wsf script execution via Windows Script Host. WARNING: breaks legitimate scripts and some installers; Restore Default re-enables WSH")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' disables Windows Script Host.\n\n" +
                    "WARNING: blocks ALL .vbs / .js / .wsf script execution, which breaks legitimate logon scripts, some installers and admin tooling. Restore Default re-enables WSH.",
            },
            new SubTweak("Admin Approval Mode for built-in Administrator", SubTweakType.Toggle,
                "security-filter-admin-token", "security-filter-admin-token-revert",
                "Force the built-in Administrator account through UAC (FilterAdministratorToken=1) instead of running fully elevated silently — the hardening counterpart to the silent-elevation tweak")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' makes the built-in Administrator account run with a filtered token and receive UAC prompts.\n\n" +
                    "Closes a common token-theft/lateral-movement hole. If you rely on the built-in Administrator running silently elevated, this changes that.",
            },
            new SubTweak("Disable NTFS 8.3 short-name creation", SubTweakType.Toggle,
                "security-ntfs-8dot3-disable", "security-ntfs-8dot3-disable-revert",
                "Stop NTFS from creating legacy 8.3 short-name aliases (can be abused to reference protected paths; minor metadata write savings). Affects new files only; Restore Default restores the Windows default"),
        ]);
}
