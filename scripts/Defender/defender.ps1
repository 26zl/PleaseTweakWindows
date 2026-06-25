# Microsoft Defender Tweaks
# Purpose: Non-interactive action dispatcher.
# Usage: powershell -File defender.ps1 -Action "<action-id>"
# Version: 2.1.0
# Last Updated: 2026-01-21
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "security-defender-cfa-enable",
        "security-defender-network-protection-enable",
        "security-defender-pua-enable",
        "security-defender-cloud-tune",
        "security-defender-sandbox-enable",
        "security-asr-rules-enable",
        "security-defender-max-protection",
        "security-defender-gaming-scan",
        "menu"
    )]
    [string]$Action = "Menu"
)

$script:ScriptVersion = "2.1.0"

function Write-PTWLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) { "INFO" { "[*]" } "SUCCESS" { "[+]" } "WARNING" { "[!]" } "ERROR" { "[-]" } default { "[*]" } }
    Write-Output "$timestamp $prefix $Message"
}

# Admin check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-PTWLog "Administrator privileges required" "ERROR"
    exit 1
}

# Unblock scripts
Get-ChildItem -Path $PSScriptRoot -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

# Dot-source common functions
$scriptsRoot = Split-Path $PSScriptRoot -Parent
$commonFunctionsPath = Join-Path $scriptsRoot "CommonFunctions.ps1"
if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
} else {
    Write-PTWLog "CommonFunctions.ps1 not found - some features may not work" "WARNING"
}

function Set-DefenderControlledFolderAccessEnabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Enable Controlled Folder Access")) { return }
    Write-Output "[*] Enabling Controlled Folder Access (ransomware protection)..."
    if (Test-DefenderTamperProtected) {
        Write-Warning "[WARN] Tamper Protection is ON; this change will not persist - disable Tamper Protection in Windows Security > Virus & threat protection first"
        exit 1
    }
    try {
        Set-MpPreference -EnableControlledFolderAccess Enabled -ErrorAction Stop
        Write-Output "[+] SUCCESS: Controlled Folder Access enabled"
    } catch {
        Write-Warning "[WARN] Set-MpPreference failed: $($_.Exception.Message)"
        exit 1
    }
}

function Set-DefenderNetworkProtectionEnabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Enable Network Protection")) { return }
    Write-Output "[*] Enabling Defender Network Protection..."
    if (Test-DefenderTamperProtected) {
        Write-Warning "[WARN] Tamper Protection is ON; this change will not persist - disable Tamper Protection in Windows Security > Virus & threat protection first"
        exit 1
    }
    try {
        Set-MpPreference -EnableNetworkProtection Enabled -ErrorAction Stop
        Write-Output "[+] SUCCESS: Network Protection enabled"
    } catch {
        Write-Warning "[WARN] Set-MpPreference failed: $($_.Exception.Message)"
        exit 1
    }
}

function Set-DefenderPuaEnabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Enable PUA Protection")) { return }
    Write-Output "[*] Enabling Potentially Unwanted App (PUA) protection..."
    if (Test-DefenderTamperProtected) {
        Write-Warning "[WARN] Tamper Protection is ON; this change will not persist - disable Tamper Protection in Windows Security > Virus & threat protection first"
        exit 1
    }
    try {
        Set-MpPreference -PUAProtection Enabled -ErrorAction Stop
        Write-Output "[+] SUCCESS: PUA protection enabled"
    } catch {
        Write-Warning "[WARN] Set-MpPreference failed: $($_.Exception.Message)"
        exit 1
    }
}

function Set-DefenderCloudTuned {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Tune Defender cloud protection")) { return }
    Write-Output "[*] Tuning Defender cloud protection..."
    if (Test-DefenderTamperProtected) {
        Write-Warning "[WARN] Tamper Protection is ON; this change will not persist - disable Tamper Protection in Windows Security > Virus & threat protection first"
        exit 1
    }
    try {
        Set-MpPreference -MAPSReporting Advanced -ErrorAction Stop
        Set-MpPreference -SubmitSamplesConsent SendSafeSamples -ErrorAction Stop
        Set-MpPreference -DisableBlockAtFirstSeen $false -ErrorAction Stop
        Set-MpPreference -CloudBlockLevel High -ErrorAction Stop
        Set-MpPreference -CloudExtendedTimeout 50 -ErrorAction Stop
        # Read back one value to confirm the change actually stuck before reporting success.
        if ((Get-MpPreference -ErrorAction Stop).CloudBlockLevel -ne 'High') {
            Write-Warning "[WARN] Defender cloud tuning did not persist (CloudBlockLevel not High)"
            exit 1
        }
        Write-Output "[+] SUCCESS: Defender cloud protection tuned (MAPS Advanced, BAFS on, Cloud Block High)"
    } catch {
        Write-Warning "[WARN] Set-MpPreference failed: $($_.Exception.Message)"
        exit 1
    }
}

function Set-DefenderSandboxEnabled {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Enable sandbox mode")) { return }
    Write-Output "[*] Enabling Defender sandbox mode..."
    & setx.exe /M MP_FORCE_USE_SANDBOX 1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "[WARN] setx returned $LASTEXITCODE"
    }
    Write-Output "[+] SUCCESS: Defender sandbox flag set (requires REBOOT to take effect)"
}

# ---------------------------------------------------------------------------
# Defender hardening functions.
# ---------------------------------------------------------------------------

# All 19 standard ASR rule GUIDs (17 Block + 2 false-positive-prone Warn).
$script:PtwAsrBlock = @(
    '56a863a9-875e-4185-98a7-b882c64b5ce5', '7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c',
    'd4f940ab-401b-4efc-aadc-ad5f3c50688a', '9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2',
    'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550', '5beb7efe-fd9a-4556-801d-275e5ffc04cc',
    'd3e037e1-3eb8-44c8-a917-57927947596d', '3b576869-a4ec-4529-8536-b80a7769e899',
    '75668c1f-73b5-4cf0-bb93-3ecf5cb7cc84', '26190899-1602-49e8-8b27-eb1d0a1ce869',
    'e6db77e5-3df2-4cf1-b95a-636979351e5b', 'd1e49aac-8f56-4280-b9ba-993a6d77406c',
    'b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4', '92e97fa1-2edf-4476-bdd6-9dd0b4dddc7b',
    'a8f5898e-1dc8-49a9-9878-85004b8a61e6', '33ddedf1-c6e0-47cb-833e-de6133960387',
    'c0033c00-d16d-4114-a5a0-dc9b3a7d2ceb'
)
$script:PtwAsrWarn = @(
    '01443614-cd74-433a-b99e-2ecdc07bfc25', 'c1db55ab-c21a-4637-bb3f-a12568109d35'
)
$script:PtwAsrRegBase = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR\Rules'

function Set-AsrRules {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Microsoft Defender", "Enable Attack Surface Reduction rules")) { return }
    if (Test-DefenderTamperProtected) {
        Write-Warning "[WARN] Tamper Protection is ON; ASR changes will not persist - turn it off in Windows Security first"
        exit 1
    }
    Write-Output "[*] Enabling Attack Surface Reduction (ASR) rules..."
    Write-Output "[!] WARNING: aggressive rules (block untrusted executables from USB, block Office child processes, block executables by prevalence) can block some legitimate installers, macros and tools. Two false-positive-prone rules are set to Warn instead of Block."
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR' -Name 'ExploitGuard_ASR_Rules' -Value 1
    foreach ($g in $script:PtwAsrBlock) {
        Add-MpPreference -AttackSurfaceReductionRules_Ids $g -AttackSurfaceReductionRules_Actions Enabled -ErrorAction SilentlyContinue
        Set-RegSz -Path $script:PtwAsrRegBase -Name $g -Value '1'
    }
    foreach ($g in $script:PtwAsrWarn) {
        Add-MpPreference -AttackSurfaceReductionRules_Ids $g -AttackSurfaceReductionRules_Actions Warn -ErrorAction SilentlyContinue
        Set-RegSz -Path $script:PtwAsrRegBase -Name $g -Value '6'
    }
    Write-Output "[+] SUCCESS: ASR rules enabled (17 Block, 2 Warn)"
}

function Set-DefenderMaxProtection {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Microsoft Defender", "Apply maximum protection settings")) { return }
    if (Test-DefenderTamperProtected) {
        Write-Warning "[WARN] Tamper Protection is ON; these changes will not persist - turn it off in Windows Security first"
        exit 1
    }
    Write-Output "[*] Applying maximum Microsoft Defender protection..."
    Write-Output "[!] WARNING: ZeroTolerance cloud blocking and full sample submission are aggressive; first-run of unsigned apps may be delayed or blocked, and all suspicious samples are sent to Microsoft."
    # Cloud depth (negated -Disable* flags use $false to ENABLE the scanning).
    Invoke-MpPrefSafe @{ CloudBlockLevel = 'ZeroTolerance' }
    Invoke-MpPrefSafe @{ CloudExtendedTimeout = 50 }
    Invoke-MpPrefSafe @{ EnableFileHashComputation = $true }
    Invoke-MpPrefSafe @{ SubmitSamplesConsent = 'SendAllSamples' }
    Invoke-MpPrefSafe @{ MAPSReporting = 'Advanced' }
    Invoke-MpPrefSafe @{ DisableArchiveScanning = $false }
    Invoke-MpPrefSafe @{ DisableScanningNetworkFiles = $false }
    Invoke-MpPrefSafe @{ DisableEmailScanning = $false }
    Invoke-MpPrefSafe @{ DisableRemovableDriveScanning = $false }
    # Signature freshness.
    Invoke-MpPrefSafe @{ SignatureUpdateInterval = 3 }
    Invoke-MpPrefSafe @{ CheckForSignaturesBeforeRunningScan = $true }
    # Threat remediation by severity.
    Invoke-MpPrefSafe @{ LowThreatDefaultAction = 'Quarantine' }
    Invoke-MpPrefSafe @{ ModerateThreatDefaultAction = 'Quarantine' }
    Invoke-MpPrefSafe @{ HighThreatDefaultAction = 'Remove' }
    Invoke-MpPrefSafe @{ SevereThreatDefaultAction = 'Remove' }
    # Behavioural: brute-force + remote-encryption (ransomware) protection (Win11 24H2+).
    Invoke-MpPrefSafe @{ EnableConvertWarnToBlock = $true }
    Invoke-MpPrefSafe @{ BruteForceProtectionLocalNetworkBlocking = $true }
    Invoke-MpPrefSafe @{ BruteForceProtectionAggressiveness = 2 }
    Invoke-MpPrefSafe @{ RemoteEncryptionProtectionAggressiveness = 2 }
    Write-Output "[+] SUCCESS: Defender maximum protection applied"
}

function Set-DefenderGamingScan {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Microsoft Defender", "Minimize gaming scan impact")) { return }
    if (Test-DefenderTamperProtected) {
        Write-Warning "[WARN] Tamper Protection is ON; these changes will not persist - turn it off in Windows Security first"
        exit 1
    }
    Write-Output "[*] Minimizing Defender scan impact for gaming (idle-only scans, capped CPU)..."
    # Run scheduled scans only when the machine is idle, cap their CPU, and still throttle on idle.
    Invoke-MpPrefSafe @{ ScanOnlyIfIdleEnabled = $true }
    Invoke-MpPrefSafe @{ ScanAvgCPULoadFactor = 30 }
    Invoke-MpPrefSafe @{ DisableCpuThrottleOnIdleScans = $false }
    Write-Output "[+] SUCCESS: Defender scans set to idle-only with a 30% CPU cap (real-time protection unchanged)"
}

switch ($Action.ToLowerInvariant()) {
    "security-defender-cfa-enable" {
        Set-DefenderControlledFolderAccessEnabled
        Exit-PTW
    }

    "security-defender-network-protection-enable" {
        Set-DefenderNetworkProtectionEnabled
        Exit-PTW
    }

    "security-defender-pua-enable" {
        Set-DefenderPuaEnabled
        Exit-PTW
    }

    "security-defender-cloud-tune" {
        Set-DefenderCloudTuned
        Exit-PTW
    }

    "security-defender-sandbox-enable" {
        Set-DefenderSandboxEnabled
        Exit-PTW
    }

    "security-asr-rules-enable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard'
        )
        Set-AsrRules
        Exit-PTW
    }

    "security-defender-max-protection" {
        Set-DefenderMaxProtection
        Exit-PTW
    }

    "security-defender-gaming-scan" {
        Set-DefenderGamingScan
        Exit-PTW
    }

    "menu" {
        Write-Output "[i] No interactive menu - use JavaFX GUI to select tweaks"
        Exit-PTW
    }

    default {
        Write-Error "Unknown action: $Action"
        exit 1
    }
}
