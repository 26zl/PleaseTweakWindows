# Device Guard Revert Script
# Purpose: Reverts the changes made by device-guard.ps1 (v2.1.0) back to Windows defaults where possible.
# Usage:
#   powershell -File revert-device-guard.ps1 -Mode <Revert|Repair|RevertAndRepair> [-Action "<action-id>"]
# Notes:
#   - Revert: removes policy/override registry values created by the security hardening actions (returns to "not configured"/defaults).
#   - Repair: re-enables optional features/capabilities/services that the hardening actions may have disabled/removed.

#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Revert','Repair','RevertAndRepair')]
    [string]$Mode = 'RevertAndRepair',

    [Parameter(Mandatory=$false)]
    [string]$Action = ''
)

$script:ScriptVersion = "2.1.0"

# Dot-source common functions
$scriptsRoot = Split-Path $PSScriptRoot -Parent
$commonFunctionsPath = Join-Path $scriptsRoot "CommonFunctions.ps1"
if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
} else {
    Write-Output "[!] CommonFunctions.ps1 not found - some features may not work"
}

# Admin check (kept explicit for nicer message)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-PTWLog "Administrator privileges required" "ERROR"
    exit 1
}

function Restore-LsaProtection {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert LSA protection")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RunAsPPL'
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RunAsPPLBoot'
    Write-PTWLog "Reverted LSA protection (RunAsPPL removed; reboot to take effect)" "SUCCESS"
}

# HVCI and Credential Guard share the VBS master switches under DeviceGuard. Only clear them
# when NEITHER scenario is still enabled, so reverting one feature does not tear VBS out from
# under the other.
function Clear-VbsMasterIfUnused {
    $dg = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
    $hvci = $null; $cg = $null
    try { $hvci = (Get-ItemProperty -Path "$dg\Scenarios\HypervisorEnforcedCodeIntegrity" -Name 'Enabled' -ErrorAction SilentlyContinue).Enabled } catch {}
    try { $cg = (Get-ItemProperty -Path "$dg\Scenarios\CredentialGuard" -Name 'Enabled' -ErrorAction SilentlyContinue).Enabled } catch {}
    if (($hvci -ne 1) -and ($cg -ne 1)) {
        Remove-RegValueSafe -Path $dg -Name 'EnableVirtualizationBasedSecurity'
        Remove-RegValueSafe -Path $dg -Name 'RequirePlatformSecurityFeatures'
        Write-PTWLog "Cleared VBS master switches (no DeviceGuard scenario remains enabled)" "INFO"
    } else {
        Write-PTWLog "Left VBS master switches in place (another DeviceGuard scenario is still enabled)" "INFO"
    }
}

function Restore-HvciEnable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert Memory Integrity (HVCI)")) { return }
    $hvciKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
    Set-RegValueSafe -Path $hvciKey -Name 'Enabled' -Type 'DWord' -Value 0
    Remove-RegValueSafe -Path $hvciKey -Name 'WasEnabledBy'
    Clear-VbsMasterIfUnused
    Write-PTWLog "Reverted Memory Integrity / HVCI (Enabled=0; reboot to take effect)" "SUCCESS"
}

function Restore-CredentialGuardEnable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert Credential Guard")) { return }
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\CredentialGuard' -Name 'Enabled' -Type 'DWord' -Value 0
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'LsaCfgFlags' -Type 'DWord' -Value 0
    Clear-VbsMasterIfUnused
    Write-PTWLog "Reverted Credential Guard (LsaCfgFlags=0; reboot to take effect)" "SUCCESS"
}

function Restore-VulnDriverBlocklist {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert vulnerable driver blocklist")) { return }
    # Remove (back to "not configured") rather than forcing 0 — on Win11 22H2+ the blocklist is ON by default.
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config' -Name 'VulnerableDriverBlocklistEnable'
    Write-PTWLog "Reverted vulnerable driver blocklist to Windows default (reboot to take effect)" "SUCCESS"
}

function Restore-WDigestDisable {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert WDigest credential caching")) { return }
    # The Windows default is ABSENT (= caching disabled). Removing restores that; setting 1 would
    # actively turn ON plaintext credential caching, leaving the machine worse than a clean install.
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' -Name 'UseLogonCredential'
    Write-PTWLog "Reverted WDigest credential caching to Windows default (value removed)" "SUCCESS"
}

function Restore-HvciMandatory {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert Mandatory Memory Integrity lock")) { return }
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name 'Locked' -Type 'DWord' -Value 0
    Write-PTWLog "Reverted Mandatory HVCI lock (Locked=0). NOTE: a UEFI-applied lock may persist until cleared in firmware; reboot to take effect." "SUCCESS"
}

function Restore-SecureLaunch {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert System Guard Secure Launch")) { return }
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SystemGuard' -Name 'Enabled' -Type 'DWord' -Value 0
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Name 'ConfigureSystemGuardLaunch' -Type 'DWord' -Value 0
    Write-PTWLog "Reverted System Guard Secure Launch (Enabled=0, ConfigureSystemGuardLaunch=0; reboot to take effect)" "SUCCESS"
}

$actionMap = @{
    'security-lsa-protection-enable'        = @{ Revert = { Restore-LsaProtection } ; Repair = { } }
    'security-hvci-enable'                  = @{ Revert = { Restore-HvciEnable } ; Repair = { } }
    'security-credential-guard-enable'      = @{ Revert = { Restore-CredentialGuardEnable } ; Repair = { } }
    'security-vuln-driver-blocklist'        = @{ Revert = { Restore-VulnDriverBlocklist } ; Repair = { } }
    'security-wdigest-disable'              = @{ Revert = { Restore-WDigestDisable } ; Repair = { } }
    'security-hvci-mandatory'               = @{ Revert = { Restore-HvciMandatory } ; Repair = { } }
    'security-secure-launch'                = @{ Revert = { Restore-SecureLaunch } ; Repair = { } }
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

Write-PTWLog "Note: revert restores Windows DEFAULTS, not any prior custom/hardened values you may have had on shared SYSTEM keys (e.g. LmCompatibilityLevel, restrictanonymous, AutoShareWks, NetbiosOptions). Original values are captured in the registry-backup .reg files under the registry-backups folder of PTW_LOG_DIR if you need to restore them manually." "INFO"

if ([string]::IsNullOrWhiteSpace($Action)) {
    Write-PTWLog "No -Action provided; running Mode=$Mode for all security revert actions." "INFO"

    # Run in a sensible order (policy/registry first, then repair)
    Invoke-Mode -RevertBlock { Restore-LsaProtection } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-HvciEnable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-CredentialGuardEnable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-VulnDriverBlocklist } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-WDigestDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-HvciMandatory } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-SecureLaunch } -RepairBlock { }

    Write-PTWLog "Done. A restart may be required for some changes to fully take effect." "SUCCESS"
    Exit-PTW
}

# Strip -revert suffix: Java sends revert action IDs like 'security-improve-network-revert'
# but actionMap keys use the base apply IDs like 'security-improve-network'
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
