# Microsoft Defender Revert Script

#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Revert','Repair','RevertAndRepair')]
    [string]$Mode = 'RevertAndRepair',

    [Parameter(Mandatory=$false)]
    [string]$Action = ''
)

# Dot-source common functions
$scriptsRoot = Split-Path $PSScriptRoot -Parent
$commonFunctionsPath = Join-Path $scriptsRoot "CommonFunctions.ps1"
if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
} else {
    Write-Output "[-] CommonFunctions.ps1 not found; refusing to continue"
    exit 1
}

# Admin check (kept explicit for nicer message)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-PTWLog "Administrator privileges required" "ERROR"
    exit 1
}

function Restore-DefenderControlledFolderAccess {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Disable Controlled Folder Access")) { return }
    # Refuse Defender preference restores while Tamper Protection is active.
    if (Test-DefenderTamperProtected) {
        Write-PTWLog "Tamper Protection is ON; CFA revert will not persist - disable Tamper Protection in Windows Security first" "WARNING"
        $script:PTWErrorCount++
        return
    }
    try {
        Set-MpPreference -EnableControlledFolderAccess Disabled -ErrorAction Stop
    } catch {
        Write-PTWLog "CFA disable failed: $($_.Exception.Message)" "WARNING"
        $script:PTWErrorCount++
        return
    }
    Write-PTWLog "Controlled Folder Access disabled" "SUCCESS"
}

function Restore-DefenderNetworkProtection {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Disable Network Protection")) { return }
    # Tamper Protection silently ignores Set-MpPreference (no exception) - guard up front.
    if (Test-DefenderTamperProtected) {
        Write-PTWLog "Tamper Protection is ON; Network Protection revert will not persist - disable Tamper Protection in Windows Security first" "WARNING"
        $script:PTWErrorCount++
        return
    }
    try {
        Set-MpPreference -EnableNetworkProtection Disabled -ErrorAction Stop
    } catch {
        Write-PTWLog "Network Protection disable failed: $($_.Exception.Message)" "WARNING"
        $script:PTWErrorCount++
        return
    }
    Write-PTWLog "Network Protection disabled" "SUCCESS"
}

function Restore-DefenderPua {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Restore PUA protection to Windows default")) { return }
    # Restore the Windows 11 default of enabled PUA protection.
    try {
        Set-MpPreference -PUAProtection Enabled -ErrorAction Stop
    } catch {
        Write-PTWLog "PUA restore-to-default failed: $($_.Exception.Message)" "WARNING"
        $script:PTWErrorCount++
        return
    }
    Write-PTWLog "PUA protection restored to Windows default (Enabled)" "SUCCESS"
}

function Restore-DefenderCloudTune {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Defender", "Revert cloud protection tuning")) { return }
    if (Test-DefenderTamperProtected) {
        Write-PTWLog "Tamper Protection is ON; cloud protection revert will not persist" "WARNING"
        $script:PTWErrorCount++
        return
    }
    # Preserve shared cloud settings while max protection remains applied.
    try {
        $mp = Get-MpPreference -ErrorAction Stop
        if ($mp.CloudBlockLevel -eq 'ZeroTolerance' -or $mp.BruteForceProtectionAggressiveness -eq 2) {
            Write-PTWLog "Defender max-protection is still applied; leaving the shared cloud settings to it (cloud-tune revert skipped to avoid downgrading it)." "INFO"
            return
        }
    } catch {
        Write-PTWLog "Could not inspect Defender max-protection state before reverting cloud settings: $($_.Exception.Message)" "WARNING"
    }
    # Restore shared cloud settings without lowering the default MAPS reporting level.
    try {
        Set-MpPreference -SubmitSamplesConsent SendSafeSamples -ErrorAction Stop
        Set-MpPreference -DisableBlockAtFirstSeen $false -ErrorAction Stop
        Set-MpPreference -CloudBlockLevel Default -ErrorAction Stop
        Set-MpPreference -CloudExtendedTimeout 0 -ErrorAction Stop
    } catch {
        Write-PTWLog "Defender cloud revert failed: $($_.Exception.Message)" "WARNING"
        $script:PTWErrorCount++
        return
    }
    Write-PTWLog "Defender cloud protection reset to defaults" "SUCCESS"
}

function Restore-DefenderSandbox {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Remove Defender sandbox env var")) { return }
    try {
        [System.Environment]::SetEnvironmentVariable('MP_FORCE_USE_SANDBOX', $null, 'Machine')
    } catch {
        Write-PTWLog "Defender sandbox revert failed: $($_.Exception.Message)" "WARNING"
        $script:PTWErrorCount++
        return
    }
    Write-PTWLog "Defender sandbox env var removed (reboot required)" "SUCCESS"
}

# Reverts for the Defender hardening functions.

function Invoke-MpPrefSafe {
    param([Parameter(Mandatory)][hashtable]$Pref)
    # Cache the Tamper Protection check before restoring individual preferences.
    if ($null -eq $script:PtwTamperCache) { $script:PtwTamperCache = Test-DefenderTamperProtected }
    if ($script:PtwTamperCache) {
        Write-PTWLog "Tamper Protection is ON; Defender revert '$($Pref.Keys -join ',')' will not persist - disable Tamper Protection in Windows Security first" "WARNING"
        $script:PTWErrorCount++
        return
    }
    try { Set-MpPreference @Pref -ErrorAction Stop }
    catch {
        Write-PTWLog "Defender revert setting skipped (unsupported on this build): $($Pref.Keys -join ',')" "WARNING"
        $script:PTWErrorCount++
    }
}

function Restore-AsrRule {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Microsoft Defender", "Revert ASR rules")) { return }
    if (Test-DefenderTamperProtected) {
        Write-PTWLog "Tamper Protection is ON; ASR revert may not persist" "WARNING"
        $script:PTWErrorCount++
        return
    }
    $ids = @(
        '56a863a9-875e-4185-98a7-b882c64b5ce5','7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c',
        'd4f940ab-401b-4efc-aadc-ad5f3c50688a','9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2',
        'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550','5beb7efe-fd9a-4556-801d-275e5ffc04cc',
        'd3e037e1-3eb8-44c8-a917-57927947596d','3b576869-a4ec-4529-8536-b80a7769e899',
        '75668c1f-73b5-4cf0-bb93-3ecf5cb7cc84','26190899-1602-49e8-8b27-eb1d0a1ce869',
        'e6db77e5-3df2-4cf1-b95a-636979351e5b','d1e49aac-8f56-4280-b9ba-993a6d77406c',
        'b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4','92e97fa1-2edf-4476-bdd6-9dd0b4dddc7b',
        'a8f5898e-1dc8-49a9-9878-85004b8a61e6','33ddedf1-c6e0-47cb-833e-de6133960387',
        'c0033c00-d16d-4114-a5a0-dc9b3a7d2ceb','01443614-cd74-433a-b99e-2ecdc07bfc25',
        'c1db55ab-c21a-4637-bb3f-a12568109d35'
    )
    $base = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR\Rules'
    foreach ($g in $ids) {
        Remove-RegValueSafe -Path $base -Name $g
    }
    # Remove the parent ASR policy value to restore its absent default.
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR' -Name 'ExploitGuard_ASR_Rules'
    Write-PTWLog "Reverted ASR rules (set to not-configured)" "SUCCESS"
}

function Restore-DefenderMaxProtection {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Microsoft Defender", "Reset max-protection settings to defaults")) { return }
    Invoke-MpPrefSafe @{ CloudBlockLevel = 'Default' }
    Invoke-MpPrefSafe @{ CloudExtendedTimeout = 0 }
    Invoke-MpPrefSafe @{ SubmitSamplesConsent = 'SendSafeSamples' }
    Invoke-MpPrefSafe @{ EnableFileHashComputation = $false }
    Invoke-MpPrefSafe @{ SignatureUpdateInterval = 8 }
    Invoke-MpPrefSafe @{ LowThreatDefaultAction = 'Clean' }
    Invoke-MpPrefSafe @{ ModerateThreatDefaultAction = 'Quarantine' }
    Invoke-MpPrefSafe @{ HighThreatDefaultAction = 'Quarantine' }
    Invoke-MpPrefSafe @{ SevereThreatDefaultAction = 'Quarantine' }
    Invoke-MpPrefSafe @{ BruteForceProtectionLocalNetworkBlocking = $false }
    Invoke-MpPrefSafe @{ BruteForceProtectionAggressiveness = 0 }
    Invoke-MpPrefSafe @{ RemoteEncryptionProtectionAggressiveness = 0 }
    Write-PTWLog "Reset Defender max-protection settings toward Windows defaults" "SUCCESS"
}

function Restore-DefenderGamingScan {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("Microsoft Defender", "Revert gaming scan tuning")) { return }
    # Restore Windows defaults: idle-only scheduled scans on, CPU cap 50%, idle-scan CPU throttling on.
    Invoke-MpPrefSafe @{ ScanOnlyIfIdleEnabled = $true }
    Invoke-MpPrefSafe @{ ScanAvgCPULoadFactor = 50 }
    Invoke-MpPrefSafe @{ DisableCpuThrottleOnIdleScans = $true }
    Write-PTWLog "Reverted Defender gaming scan tuning to Windows defaults" "SUCCESS"
}

$actionMap = @{
    'security-defender-cfa-enable'          = @{ Revert = { Restore-DefenderControlledFolderAccess } ; Repair = { } }
    'security-defender-network-protection-enable' = @{ Revert = { Restore-DefenderNetworkProtection } ; Repair = { } }
    'security-defender-pua-enable'          = @{ Revert = { Restore-DefenderPua } ; Repair = { } }
    'security-defender-cloud-tune'          = @{ Revert = { Restore-DefenderCloudTune } ; Repair = { } }
    'security-defender-sandbox-enable'      = @{ Revert = { Restore-DefenderSandbox } ; Repair = { } }
    'security-asr-rules-enable'             = @{ Revert = { Restore-AsrRule } ; Repair = { } }
    'security-defender-max-protection'      = @{ Revert = { Restore-DefenderMaxProtection } ; Repair = { } }
    'security-defender-gaming-scan'         = @{ Revert = { Restore-DefenderGamingScan } ; Repair = { } }
}

function Invoke-Mode {
    param([scriptblock]$RevertBlock, [scriptblock]$RepairBlock)

    $m = $Mode.ToLowerInvariant()
    if ($m -eq 'revert' -or $m -eq 'revertandrepair') {
        if ($RevertBlock) { & $RevertBlock }
    }
    if ($m -eq 'repair' -or $m -eq 'revertandrepair') {
        if ($RepairBlock) { & $RepairBlock }
    }
}

Write-PTWLog "Restore Default applies Windows defaults; it does not reconstruct prior custom or organization-managed values." "INFO"

if ([string]::IsNullOrWhiteSpace($Action)) {
    Write-PTWLog "No -Action provided; running Mode=$Mode for all security revert actions." "INFO"

    # Run in a sensible order (policy/registry first, then repair)
    Invoke-Mode -RevertBlock { Restore-DefenderControlledFolderAccess } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-DefenderNetworkProtection } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-DefenderPua } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-DefenderCloudTune } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-DefenderSandbox } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-AsrRule } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-DefenderMaxProtection } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-DefenderGamingScan } -RepairBlock { }

    Write-PTWLog "Done. A restart may be required for some changes to fully take effect." "SUCCESS"
    Exit-PTW
}

# Strip the -revert suffix before action-map lookup.
$k = $Action.ToLowerInvariant().Trim() -replace '-revert$', ''
if (-not $actionMap.ContainsKey($k)) {
    Write-PTWLog "Unknown action: $Action" "ERROR"
    Write-Output "Known actions: $($actionMap.Keys | Sort-Object | ForEach-Object { $_ } | Out-String)"
    exit 1
}

Write-PTWLog "Running Mode=$Mode for Action=$k" "INFO"
Invoke-Mode -RevertBlock $actionMap[$k].Revert -RepairBlock $actionMap[$k].Repair
Write-PTWLog "Done." "SUCCESS"
Exit-PTW
