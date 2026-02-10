# Services Revert Script
# Purpose: Restores service startup types to defaults.
# Usage: powershell -File revert-services.ps1 -Mode <Revert|Repair|RevertAndRepair>
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
Write-Output "════════════════════════════════════════════════"
Write-Output "  Services Management - $Mode"
Write-Output "════════════════════════════════════════════════"
Write-Output ""

if ($doRevert -or $doRepair) {
    Write-Output "  [1/1] Restoring services to default..."
    Write-Output ""

    $regPath = Join-Path $PSScriptRoot "regs\servicesDefault.reg"
    if (-not (Test-Path $regPath)) {
        Write-PTWError "Registry file not found: $regPath"
        Write-Output "        No changes were applied."
    } else {
        Import-RegistryFile -RegFile $regPath | Out-Null
        Write-PTWSuccess "Services restored to Windows defaults"
    }
}

Write-Output ""
Write-Output "════════════════════════════════════════════════"
Write-Output "  [+] $Mode complete"
Write-Output "  [!] Restart required for changes to take effect"
Write-Output "════════════════════════════════════════════════"
Wait-ForUser
$global:LASTEXITCODE = 0
return
