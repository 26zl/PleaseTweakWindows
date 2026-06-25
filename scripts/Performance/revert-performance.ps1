# Performance & Power Revert Script
# Purpose: Restores power, registry and HDCP defaults.
# Usage: powershell -File revert-performance.ps1 -Mode <Revert|Repair|RevertAndRepair>
# Version: 2.1.0
# Last Updated: 2026-01-18
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Revert', 'Repair', 'RevertAndRepair')]
    [string]$Mode = 'RevertAndRepair'
)

$script:ScriptVersion = "2.1.0"

$scriptsRoot = Split-Path $PSScriptRoot -Parent
$commonFunctionsPath = Join-Path $scriptsRoot "CommonFunctions.ps1"
if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
} else {
    Write-Output "[!] CommonFunctions.ps1 not found - some features may not work"
}

function Resolve-FallbackRegPath {
    param([Parameter(Mandatory=$true)][string[]]$Candidates)
    foreach ($p in $Candidates) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

$doRevert = ($Mode -eq 'Revert') -or ($Mode -eq 'RevertAndRepair')
$doRepair = ($Mode -eq 'Repair') -or ($Mode -eq 'RevertAndRepair')

Write-Output ""
Write-Output "========================================"
Write-Output "  Performance & Power - $Mode"
Write-Output "========================================"
Write-Output ""

#region REVERT Operations
if ($doRevert) {
    $totalSteps = 3
    $currentStep = 0

    # Power plans & power policy
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring power settings..."
    try {
        powercfg -restoredefaultschemes 2>$null | Out-Null
        cmd /c "powercfg /delete 99999999-9999-9999-9999-999999999999 >nul 2>&1"
        Write-PTWSuccess "Power plans restored to defaults"
    } catch {
        Write-PTWWarning "Could not fully restore power settings"
    }
    Remove-RegKey -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings"
    Set-RegDword -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USB" -Name "DisableSelectiveSuspend" -Value 0
    Set-RegDword -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" -Name "ValueMax" -Value 100
    Remove-RegKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
    Set-RegDword -Path "HKLM:\System\CurrentControlSet\Control\Power\PowerSettings\2a737441-1930-4402-8d77-b2bebba308a3\0853a681-27c8-4100-a2fd-82013e970683" -Name "Attributes" -Value 1
    Set-RegDword -Path "HKLM:\System\CurrentControlSet\Control\Power\PowerSettings\2a737441-1930-4402-8d77-b2bebba308a3\d4e98f31-5ffe-4ce1-be31-1b38b384c009" -Name "Attributes" -Value 1
    powercfg -setacvalueindex SCHEME_CURRENT SUB_PCIE EXPRESS 1 2>$null | Out-Null
    powercfg -setdcvalueindex SCHEME_CURRENT SUB_PCIE EXPRESS 1 2>$null | Out-Null

    # Registry defaults
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring registry defaults..."
    $regSuccess = $false
    $fallback = Resolve-FallbackRegPath -Candidates @(
        (Join-Path $PSScriptRoot "regs\Registry Defaults.reg"),
        (Join-Path $PSScriptRoot "regs\Registry-Defaults.reg"),
        (Join-Path $PSScriptRoot "Registry Defaults.reg"),
        (Join-Path $PSScriptRoot "Registry-Defaults.reg")
    )
    if ($fallback) {
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PCIE EXPRESS 1 2>$null | Out-Null
        # Reflect the real import result instead of assuming success.
        $regSuccess = Import-RegistryFile -RegFile $fallback
    }
    if ($regSuccess) {
        Write-PTWSuccess "Registry defaults restored"
    } else {
        Write-PTWWarning "Registry defaults not found (skipped)"
    }
    # Clear the registry-apply guard marker so registry-apply can run again after revert
    Remove-RegValue -Path "HKCU:\Software\PleaseTweakWindows" -Name "RegistryOptimized"

    # HDCP settings
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring HDCP settings..."
    $gpuClassPath = "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    try {
        $gpuKeys = (Get-ChildItem -Path $gpuClassPath -Force -ErrorAction SilentlyContinue).Name
        foreach ($key in $gpuKeys) {
            if ($key -notlike '*Configuration') {
                Set-RegDword -Path "Registry::$key" -Name "RMHdcpKeyglobZero" -Value 0
            }
        }
        Write-PTWSuccess "HDCP settings restored"
    } catch {
        Write-PTWWarning "Could not restore HDCP settings"
    }

    Write-Output ""
    Write-PTWSuccess "All revert operations completed"
}
#endregion

Write-Output ""
Write-Output "========================================"
Write-Output "  [+] $Mode complete"
Write-Output "  [!] Restart required for changes to take effect"
Write-Output "========================================"
Wait-ForUser
$global:LASTEXITCODE = 0
return
