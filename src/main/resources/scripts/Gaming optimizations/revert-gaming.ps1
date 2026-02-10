# Gaming Optimizations Revert Script
# Purpose: Restores defaults and repairs gaming components.
# Usage: powershell -File revert-gaming.ps1 -Mode <Revert|Repair|RevertAndRepair>
# Version: 2.1.0
# Last Updated: 2026-01-18
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Revert', 'Repair', 'RevertAndRepair')]
    [string]$Mode = 'RevertAndRepair'
)

function Set-ServiceStartIfPresent {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string]$ServiceNamePattern,
        [Parameter(Mandatory=$true)][int]$StartValue
    )
    # Handles both normal and per-user services (e.g. BcastDVRUserService_XXXXX)
    try {
        $servicesRoot = "Registry::HKLM\SYSTEM\CurrentControlSet\Services"
        if (-not (Test-Path $servicesRoot)) { return }

        Get-ChildItem -Path $servicesRoot -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -like $ServiceNamePattern } |
            ForEach-Object {
                try {
                    if ($PSCmdlet.ShouldProcess("$($_.PSPath)\\Start", "Set service start to $StartValue")) {
                        Set-RegDword -Path $_.PSPath -Name "Start" -Value $StartValue
                    }
                } catch { Write-Verbose "Failed to set service start for $($_.PSChildName): $($_.Exception.Message)" }
            }
    } catch { Write-Verbose "Failed to update service start values: $($_.Exception.Message)" }
}

function Confirm-Inspector {
    param([Parameter(Mandatory=$true)][string]$InspectorPath)

    if (Test-Path $InspectorPath) { return $true }

    $drsPath = "C:\ProgramData\NVIDIA Corporation\Drs"
    if (Test-Path $drsPath) {
        Get-ChildItem -Path $drsPath -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
    }

    if (Get-Command Get-FileFromWeb -ErrorAction SilentlyContinue) {
        try {
            Get-FileFromWeb -URL "https://github.com/Orbmu2k/nvidiaProfileInspector/releases/download/2.4.0.31/nvidiaProfileInspector.zip" -File "$env:TEMP\nvidiaProfileInspector.zip"
            Expand-Archive "$env:TEMP\nvidiaProfileInspector.zip" -DestinationPath (Split-Path $InspectorPath) -Force
        } catch { Write-Verbose "Failed to download Inspector.exe: $($_.Exception.Message)" }
    }

    return (Test-Path $InspectorPath)
}

function Register-AppxIfPresent {
    param([Parameter(Mandatory=$true)][string]$NameLike)

    try {
        $pkgs = Get-AppxPackage -AllUsers $NameLike -ErrorAction SilentlyContinue
        foreach ($pkg in $pkgs) {
            try {
                if ($pkg.InstallLocation -and (Test-Path (Join-Path $pkg.InstallLocation "AppXManifest.xml"))) {
                    Add-AppxPackage -DisableDevelopmentMode -Register (Join-Path $pkg.InstallLocation "AppXManifest.xml") -ErrorAction SilentlyContinue | Out-Null
                }
            } catch { Write-Verbose "Failed to register appx package $($pkg.Name): $($_.Exception.Message)" }
        }
    } catch { Write-Verbose "Failed to enumerate appx packages: $($_.Exception.Message)" }
}

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

$scriptsRoot = Split-Path $PSScriptRoot -Parent
$commonFunctionsPath = Join-Path $scriptsRoot "CommonFunctions.ps1"
if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
}

$doRevert = ($Mode -eq 'Revert') -or ($Mode -eq 'RevertAndRepair')
$doRepair = ($Mode -eq 'Repair') -or ($Mode -eq 'RevertAndRepair')

Write-Output ""
Write-Output "========================================"
Write-Output "  Gaming Optimizations - $Mode"
Write-Output "========================================"
Write-Output ""

#region REVERT Operations
if ($doRevert) {
    $totalSteps = 7
    $currentStep = 0

    # NVIDIA Profile Inspector
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Resetting NVIDIA profile settings..."
    $inspectorPath = Join-Path $env:TEMP "nvidiaProfileInspector\nvidiaProfileInspector.exe"
if (Confirm-Inspector -InspectorPath $inspectorPath) {
    $defaultsNip = @"
<?xml version="1.0" encoding="utf-16"?>
<ArrayOfProfile>
  <Profile>
    <ProfileName>Base Profile</ProfileName>
    <Executeables />
    <Settings />
  </Profile>
</ArrayOfProfile>
"@
    # Use Unicode to match the XML header better (UTF-16LE in Windows)
    Set-Content -Path "$env:TEMP\Defaults.nip" -Value $defaultsNip -Force -Encoding Unicode
    try {
        $proc = Start-Process -FilePath $inspectorPath -ArgumentList "$env:TEMP\Defaults.nip" -Wait -PassThru -ErrorAction SilentlyContinue
        if ($proc.ExitCode -ne 0) {
            Write-Output "  [!] NVIDIA Profile Inspector skipped (requires NVIDIA drivers)"
        }
    } catch {
        Write-Output "  [!] NVIDIA Profile Inspector skipped (not available or incompatible)"
    }

    # Re-enable GR535 (undo legacy sharpen disable)
    Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS" -Name "EnableGR535" -Value 1
    Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS" -Name "EnableGR535" -Value 1
} else {
    Write-PTWWarning "NVIDIA Profile Inspector skipped (no NVIDIA GPU)"
}

    # GPU power states
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring GPU power states..."
    try {
        $nvidiaKeys = Get-GpuClassKeysByVendor -Vendor "NVIDIA"
        foreach ($key in $nvidiaKeys) {
            Remove-RegValue -Path "Registry::$key" -Name "DisableDynamicPstate"
        }

        $amdKeys = Get-GpuClassKeysByVendor -Vendor "AMD"
        foreach ($key in $amdKeys) {
            Set-RegDword -Path "Registry::$key" -Name "EnableUlps" -Value 1
        }
        Write-PTWSuccess "GPU power states restored"
    } catch {
        Write-PTWWarning "Could not restore GPU power states"
    }
    Remove-RegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy" -Name "WHQLSettings"

    # Fullscreen & Game Bar
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring fullscreen & Game Bar settings..."
    Set-RegDword -Path "Registry::HKCU\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 0
    Set-RegDword -Path "Registry::HKCU\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 0
    Remove-RegValue -Path "Registry::HKCU\System\GameConfigStore" -Name "GameDVR_FSEBehavior"
    Set-RegDword -Path "Registry::HKCU\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 0
    Set-RegDword -Path "Registry::HKCU\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 1
    Set-RegDword -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 1
    Remove-RegValue -Path "Registry::HKCU\Software\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled"
    Write-PTWSuccess "Fullscreen & Game Bar restored"

    # Xbox services
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring Xbox services..."
    Set-ServiceStartIfPresent -ServiceNamePattern "GameInputSvc" -StartValue 3
    Set-ServiceStartIfPresent -ServiceNamePattern "BcastDVRUserService*" -StartValue 3
    Set-ServiceStartIfPresent -ServiceNamePattern "XboxGipSvc" -StartValue 3
    Set-ServiceStartIfPresent -ServiceNamePattern "XblAuthManager" -StartValue 3
    Set-ServiceStartIfPresent -ServiceNamePattern "XblGameSave" -StartValue 3
    Set-ServiceStartIfPresent -ServiceNamePattern "XboxNetApiSvc" -StartValue 3
    Write-PTWSuccess "Xbox services restored"

    # Protocol handlers
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring protocol handlers..."
    Remove-RegKey -Path "Registry::HKEY_CLASSES_ROOT\ms-gamebar"
    Remove-RegKey -Path "Registry::HKEY_CLASSES_ROOT\ms-gamebarservices"
    Remove-RegKey -Path "Registry::HKEY_CLASSES_ROOT\ms-gamingoverlay"
    try {
        $gamebarReg = @"
Windows Registry Editor Version 5.00

[HKEY_CLASSES_ROOT\ms-gamingoverlay]
"URL Protocol"=""
@="URL:ms-gamingoverlay"
"@
        Set-Content -Path "$env:TEMP\MsGamebarNotiOn.reg" -Value $gamebarReg -Force -Encoding ASCII
        & regedit.exe /S "$env:TEMP\MsGamebarNotiOn.reg" 2>$null
    } catch { Write-Verbose "Failed to restore protocol handlers: $($_.Exception.Message)" }
    Write-PTWSuccess "Protocol handlers restored"

    # MSI mode
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring MSI mode settings..."
    try {
        $gpuDevices = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue
        foreach ($gpu in $gpuDevices) {
            $instanceID = $gpu.InstanceId
            if (-not $instanceID) { continue }
            $msiPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$instanceID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            Set-RegDword -Path $msiPath -Name "MSISupported" -Value 0
        }
        Write-PTWSuccess "MSI mode restored"
    } catch {
        Write-PTWWarning "Could not restore MSI mode"
    }

    # Mouse & display settings
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring mouse & display settings..."
    Remove-RegValue -Path "HKCU:\Control Panel\Mouse" -Name "RawMouseThrottleEnabled"
    Remove-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode"
    Remove-RegValue -Path "Registry::HKCU\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings"
    Write-PTWSuccess "Mouse & display settings restored"

    Write-Output ""
    Write-PTWSuccess "All revert operations completed"
}
#endregion

#region REPAIR Operations
if ($doRepair) {
    Write-Output ""
    Write-Output "----------------------------------------"
    Write-Output "  REPAIR Operations"
    Write-Output "----------------------------------------"
    $repairSteps = 3
    $repairStep = 0

    # Xbox & Gaming apps
    $repairStep++
    Write-Output "  [$repairStep/$repairSteps] Re-registering Xbox & gaming apps..."
    Register-AppxIfPresent -NameLike "*Microsoft.GamingApp*"
    Register-AppxIfPresent -NameLike "*Microsoft.Xbox.TCUI*"
    Register-AppxIfPresent -NameLike "*Microsoft.XboxApp*"
    Register-AppxIfPresent -NameLike "*Microsoft.XboxGameOverlay*"
    Register-AppxIfPresent -NameLike "*Microsoft.XboxGamingOverlay*"
    Register-AppxIfPresent -NameLike "*Microsoft.XboxIdentityProvider*"
    Register-AppxIfPresent -NameLike "*Microsoft.XboxSpeechToTextOverlay*"
    Register-AppxIfPresent -NameLike "*Microsoft.WindowsStore*"
    Register-AppxIfPresent -NameLike "*Microsoft.Microsoft.StorePurchaseApp*"
    Write-PTWSuccess "Xbox & gaming apps processed"

    # Edge WebView
    $repairStep++
    Write-Output "  [$repairStep/$repairSteps] Installing Edge WebView runtime..."
    if (Get-Command Get-FileFromWeb -ErrorAction SilentlyContinue) {
        try {
            Get-FileFromWeb -URL "https://msedge.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/304fddef-b073-4e0a-b1ff-c2ea02584017/MicrosoftEdgeWebview2Setup.exe" -File "$env:TEMP\EdgeWebView.exe"
            Start-Process -Wait "$env:TEMP\EdgeWebView.exe" -ErrorAction SilentlyContinue
            Write-PTWSuccess "Edge WebView installed"
        } catch {
            Write-PTWWarning "Could not install Edge WebView"
        }
    } else {
        Write-PTWWarning "Edge WebView skipped (download function unavailable)"
    }

    # Gaming Repair Tool
    $repairStep++
    Write-Output "  [$repairStep/$repairSteps] Running Gaming Repair Tool..."
    if (Get-Command Get-FileFromWeb -ErrorAction SilentlyContinue) {
        try {
            Get-FileFromWeb -URL "https://aka.ms/GamingRepairTool" -File "$env:TEMP\GamingRepairTool.exe"
            Start-Process -Wait "$env:TEMP\GamingRepairTool.exe" -ErrorAction SilentlyContinue
            Write-PTWSuccess "Gaming Repair Tool completed"
        } catch {
            Write-PTWWarning "Could not run Gaming Repair Tool"
        }
    } else {
        Write-PTWWarning "Gaming Repair Tool skipped (download function unavailable)"
    }

    Write-Output ""
    Write-PTWSuccess "All repair operations completed"
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
