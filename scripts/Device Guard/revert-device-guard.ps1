# Device Guard Revert Script

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

function Restore-LsaProtection {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert LSA protection")) { return }
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RunAsPPL'
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RunAsPPLBoot'
    Write-PTWLog "Reverted LSA protection (RunAsPPL removed; reboot to take effect)" "SUCCESS"
}

# Clear shared VBS switches only when neither HVCI nor Credential Guard remains enabled.
function Clear-VbsMasterIfUnused {
    $dg = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
    $hvci = $null; $cg = $null
    try {
        $hvci = (Get-ItemProperty -Path "$dg\Scenarios\HypervisorEnforcedCodeIntegrity" -Name 'Enabled' -ErrorAction Stop).Enabled
    } catch {
        Write-Verbose "Could not read HVCI state: $($_.Exception.Message)"
    }
    try {
        $cg = (Get-ItemProperty -Path "$dg\Scenarios\CredentialGuard" -Name 'Enabled' -ErrorAction Stop).Enabled
    } catch {
        Write-Verbose "Could not read Credential Guard state: $($_.Exception.Message)"
    }
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
    # Remove HVCI overrides instead of disabling the default-on feature.
    Remove-RegValueSafe -Path $hvciKey -Name 'Enabled'
    Remove-RegValueSafe -Path $hvciKey -Name 'WasEnabledBy'
    Clear-VbsMasterIfUnused
    Write-PTWLog "Reverted Memory Integrity / HVCI to Windows default (values removed; reboot to take effect)" "SUCCESS"
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
    # Remove the WDigest override to retain the default of disabled plaintext caching.
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' -Name 'UseLogonCredential'
    Write-PTWLog "Reverted WDigest credential caching to Windows default (value removed)" "SUCCESS"
}

function Restore-HvciMandatory {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Remove HVCI UEFI lock configuration")) { return }
    # Removing the value cancels a not-yet-committed lock; a firmware-committed lock needs Microsoft's UEFI removal procedure.
    Remove-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name 'Locked'
    Write-PTWLog "Removed the HVCI UEFI lock configuration value. If the lock was already committed to firmware on a prior boot, clear it with Microsoft's documented UEFI lock removal procedure." "WARNING"
}

function Restore-SecureLaunch {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert System Guard Secure Launch")) { return }
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SystemGuard' -Name 'Enabled' -Type 'DWord' -Value 0
    Set-RegValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Name 'ConfigureSystemGuardLaunch' -Type 'DWord' -Value 0
    Write-PTWLog "Reverted System Guard Secure Launch (Enabled=0, ConfigureSystemGuardLaunch=0; reboot to take effect)" "SUCCESS"
}

function Restore-KernelDmaProtection {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess("System", "Revert Kernel DMA Protection policy")) { return }
    # Remove the policy so hardware controls Kernel DMA Protection.
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Kernel DMA Protection' -Name 'DeviceEnumerationPolicy'
    Write-PTWLog "Reverted Kernel DMA Protection enumeration policy to Windows default (value removed)" "SUCCESS"
}

$actionMap = @{
    'security-lsa-protection-enable'        = @{ Revert = { Restore-LsaProtection } ; Repair = { } }
    'security-hvci-enable'                  = @{ Revert = { Restore-HvciEnable } ; Repair = { } }
    'security-credential-guard-enable'      = @{ Revert = { Restore-CredentialGuardEnable } ; Repair = { } }
    'security-vuln-driver-blocklist'        = @{ Revert = { Restore-VulnDriverBlocklist } ; Repair = { } }
    'security-wdigest-disable'              = @{ Revert = { Restore-WDigestDisable } ; Repair = { } }
    'security-hvci-mandatory'               = @{ Revert = { Restore-HvciMandatory } ; Repair = { } }
    'security-secure-launch'                = @{ Revert = { Restore-SecureLaunch } ; Repair = { } }
    'security-kernel-dma-protection'        = @{ Revert = { Restore-KernelDmaProtection } ; Repair = { } }
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
    Invoke-Mode -RevertBlock { Restore-LsaProtection } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-HvciEnable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-CredentialGuardEnable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-VulnDriverBlocklist } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-WDigestDisable } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-HvciMandatory } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-SecureLaunch } -RepairBlock { }
    Invoke-Mode -RevertBlock { Restore-KernelDmaProtection } -RepairBlock { }

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
