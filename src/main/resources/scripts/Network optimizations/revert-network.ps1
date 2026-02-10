# Network Optimizations Revert Script
# Purpose: Restores network settings to defaults.
# Usage: powershell -File revert-network.ps1 -Mode <Revert|Repair|RevertAndRepair>
# Version: 2.1.0
# Last Updated: 2026-01-18
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Revert', 'Repair', 'RevertAndRepair')]
    [string]$Mode = 'RevertAndRepair'
)

$scriptsRoot = Split-Path $PSScriptRoot -Parent
$commonFunctionsPath = Join-Path $scriptsRoot "CommonFunctions.ps1"
if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
} else {
    Write-Output "[!] CommonFunctions.ps1 not found - some features may not work"
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-PTWError "Administrator privileges required."
    $global:LASTEXITCODE = 2
    return
}

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

$doRevert = ($Mode -eq 'Revert') -or ($Mode -eq 'RevertAndRepair')
$doRepair = ($Mode -eq 'Repair') -or ($Mode -eq 'RevertAndRepair')

Write-Output ""
Write-Output "========================================"
Write-Output "  Network Optimizations - $Mode"
Write-Output "========================================"
Write-Output ""

if ($doRevert) {
    $totalSteps = 5
    $currentStep = 0

    # Network throttling
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring network throttling settings..."
    $RegKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    try {
        Set-ItemProperty -Path $RegKey -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $RegKey -Name "SystemResponsiveness" -Value 20 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-PTWSuccess "Network throttling restored to defaults"
    } catch {
        Write-PTWWarning "Could not restore throttling defaults"
    }

    # IPv6 & Teredo
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring IPv6 & Teredo settings..."
    $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"
    try {
        if (Test-Path $RegPath) {
            Remove-ItemProperty -Path $RegPath -Name "DisabledComponents" -Force -ErrorAction SilentlyContinue
        }
        Start-Process -FilePath "netsh" -ArgumentList "interface teredo set state default" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        Write-PTWSuccess "IPv6 & Teredo restored"
    } catch {
        Write-PTWWarning "Could not fully restore IPv6 settings"
    }

    # DNS & DoH settings
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring DNS & DoH settings..."
    $dnsServers = @("1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001", "8.8.8.8", "8.8.4.4", "9.9.9.9", "149.112.112.112")
    foreach ($dns in $dnsServers) {
        try { netsh dns delete encryption server=$dns 2>&1 | Out-Null } catch { Write-Verbose "Failed to delete DoH server ${dns}: $($_.Exception.Message)" }
    }
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    $dnsResetCount = 0
    foreach ($adapter in $adapters) {
        try {
            Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ResetServerAddresses -ErrorAction Stop
            $dnsResetCount++
        } catch { Write-Verbose "Failed to reset DNS on adapter $($adapter.Name): $($_.Exception.Message)" }
    }
    ipconfig /flushdns 2>$null | Out-Null
    Write-PTWSuccess "DNS reset on $dnsResetCount adapter(s), cache flushed"

    # Adapter bindings
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring adapter bindings..."
    $bindings = @("ms_lldp", "ms_lltdio", "ms_implat", "ms_tcpip", "ms_rspndr", "ms_tcpip6", "ms_server", "ms_msclient", "ms_pacer")
    foreach ($binding in $bindings) {
        Enable-NetAdapterBinding -Name "*" -ComponentID $binding -ErrorAction SilentlyContinue
    }
    Write-PTWSuccess "Adapter bindings restored"

    # Manual steps reminder
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Checking for manual steps..."
    Write-PTWWarning "Network adapter driver settings require manual reset"
    Write-Output "        To restore: Device Manager > Network Adapter > Advanced"

    Write-Output ""
    Write-PTWSuccess "All revert operations completed"
}

# Note: Network doesn't have separate "repair" actions - all operations are in revert
if ($doRepair -and -not $doRevert) {
    Write-Output ""
    Write-Output "----------------------------------------"
    Write-Output "  REPAIR Operations"
    Write-Output "----------------------------------------"
    Write-Output "  [1/2] Restoring network defaults..."

    $RegKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $RegKey -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $RegKey -Name "SystemResponsiveness" -Value 20 -Type DWord -Force -ErrorAction SilentlyContinue

    $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"
    if (Test-Path $RegPath) {
        Remove-ItemProperty -Path $RegPath -Name "DisabledComponents" -Force -ErrorAction SilentlyContinue
    }
    Start-Process -FilePath "netsh" -ArgumentList "interface teredo set state default" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
    Write-PTWSuccess "Network defaults restored"

    Write-Output "  [2/2] Restoring adapter bindings..."
    $bindings = @("ms_lldp", "ms_lltdio", "ms_implat", "ms_tcpip", "ms_rspndr", "ms_tcpip6", "ms_server", "ms_msclient", "ms_pacer")
    foreach ($binding in $bindings) {
        Enable-NetAdapterBinding -Name "*" -ComponentID $binding -ErrorAction SilentlyContinue
    }
    Write-PTWSuccess "Adapter bindings restored"

    Write-Output ""
    Write-PTWSuccess "All repair operations completed"
}

Write-Output ""
Write-Output "========================================"
Write-Output "  [+] $Mode complete"
Write-Output "  [!] Restart required for changes to take effect"
Write-Output "========================================"
Wait-ForUser
$global:LASTEXITCODE = 0
return
