# General Tweaks Revert Script
# Purpose: Restores defaults and repairs removed components.
# Usage: powershell -File revert-general.ps1 -Mode <Revert|Repair|RevertAndRepair>
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
Write-Output "  General Tweaks - $Mode"
Write-Output "========================================"
Write-Output ""

#region REVERT Operations
if ($doRevert) {
    $totalSteps = 8
    $currentStep = 0

    # Power plans & power policy
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring power settings..."
    try {
        powercfg -restoredefaultschemes 2>$null | Out-Null
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

    # Privacy & UX defaults
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring privacy & UX settings..."
    try {
        Set-RegDword -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 1
        Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed"
        Set-RegDword -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Value 1
        Set-RegDword -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 1
        Set-RegDword -Path "HKLM:\SOFTWARE\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 0
        Set-RegDword -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" -Name "PreventHandwritingErrorReports" -Value 0
        Set-RegSz -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "1"
        Set-RegDword -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USB" -Name "DisableSelectiveSuspend" -Value 0
        Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoLowDiskSpaceChecks"
        Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "LinkResolveIgnoreLinkInfo"
        Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoResolveSearch"
        Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoInternetOpenWith"
        Write-PTWSuccess "Privacy & UX settings restored"
    } catch {
        Write-PTWWarning "Could not fully restore privacy settings"
    }

    # Photo viewer associations
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Removing custom photo associations..."
    $photoExts = @(".tif", ".tiff", ".bmp", ".dib", ".gif", ".jfif", ".jpe", ".jpeg", ".jpg", ".jxr", ".png")
    foreach ($ext in $photoExts) {
        Remove-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" -Name $ext
    }
    Write-PTWSuccess "Photo associations cleared"

    # Background apps & Widgets
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring background apps & widgets..."
    Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground"
    Set-RegDword -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\NewsAndInterests\AllowNewsAndInterests" -Name "value" -Value 1
    Remove-RegKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
    Write-PTWSuccess "Background apps & widgets restored"

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
        Import-RegistryFile -RegFile $fallback | Out-Null
        $regSuccess = $true
    }
    if ($regSuccess) {
        Write-PTWSuccess "Registry defaults restored"
    } else {
        Write-PTWWarning "Registry defaults not found (skipped)"
    }

    # Shell & Search restore
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring shell & search components..."
    $moveTargets = @(
        @{ Source = "C:\Windows\MicrosoftWindows.Client.CBS_cw5n1h2txyewy"; Target = "C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy" },
        @{ Source = "C:\Windows\Microsoft.Windows.Search_cw5n1h2txyewy"; Target = "C:\Windows\SystemApps\Microsoft.Windows.Search_cw5n1h2txyewy" },
        @{ Source = "C:\Windows\ShellExperienceHost_cw5n1h2txyewy"; Target = "C:\Windows\SystemApps\ShellExperienceHost_cw5n1h2txyewy" },
        @{ Source = "C:\Windows\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy"; Target = "C:\Windows\SystemApps\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy" },
        @{ Source = "C:\Windows\mobsync.exe"; Target = "C:\Windows\System32\mobsync.exe" }
    )
    foreach ($item in $moveTargets) {
        if (Test-Path $item.Source) {
            try {
                $null = Start-Process -FilePath "takeown.exe" -ArgumentList "/f", "`"$($item.Source)`"" -WindowStyle Hidden -Wait -PassThru -ErrorAction SilentlyContinue
                $null = Start-Process -FilePath "icacls.exe" -ArgumentList "`"$($item.Source)`"", "/grant", "*S-1-3-4:F", "/t", "/q" -WindowStyle Hidden -Wait -PassThru -ErrorAction SilentlyContinue
                Move-Item -Force -Path $item.Source -Destination $item.Target -ErrorAction SilentlyContinue | Out-Null
            } catch { Write-Verbose "Failed to delete bloatware entry: $($_.Exception.Message)" }
        }
    }
    Set-RegDword -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Search\DisableSearch" -Name "value" -Value 0
    Remove-RegKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    Remove-RegValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode"
    Set-RegDword -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WSearch" -Name "Start" -Value 2
    cmd /c "taskkill /F /IM explorer.exe >nul 2>&1"
    cmd /c "start explorer.exe >nul 2>&1"
    cmd /c "sc start WSearch >nul 2>&1"
    Write-PTWSuccess "Shell & search restored"

    # Keyboard shortcuts
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring keyboard shortcuts..."
    Set-RegDword -Path "HKLM:\SYSTEM\CurrentControlSet\Services\hidserv" -Name "Start" -Value 3
    Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoWinKeys"
    Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisabledHotkeys"
    Remove-RegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map"
    Write-PTWSuccess "Keyboard shortcuts restored"

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

#region REPAIR Operations
if ($doRepair) {
    Write-Output ""
    Write-Output "----------------------------------------"
    Write-Output "  REPAIR Operations"
    Write-Output "----------------------------------------"
    $repairSteps = 4
    $repairStep = 0

    # UWP Apps
    $repairStep++
    Write-Output "  [$repairStep/$repairSteps] Reinstalling UWP apps..."
    $appsToReinstall = @(
    "*Microsoft.BingNews*",
    "*Microsoft.BingWeather*",
    "*Microsoft.GetHelp*",
    "*Microsoft.Getstarted*",
    "*Microsoft.Microsoft3DViewer*",
    "*Microsoft.MicrosoftOfficeHub*",
    "*Microsoft.MicrosoftSolitaireCollection*",
    "*Microsoft.MixedReality.Portal*",
    "*Microsoft.Office.OneNote*",
    "*Microsoft.People*",
    "*Microsoft.SkypeApp*",
    "*Microsoft.Wallet*",
    "*Microsoft.Windows.Photos*",
    "*Microsoft.WindowsAlarms*",
    "*Microsoft.WindowsCalculator*",
    "*Microsoft.WindowsCamera*",
    "*microsoft.windowscommunicationsapps*",
    "*Microsoft.WindowsFeedbackHub*",
    "*Microsoft.WindowsMaps*",
    "*Microsoft.WindowsSoundRecorder*",
    "*Microsoft.Xbox.TCUI*",
    "*Microsoft.XboxApp*",
    "*Microsoft.XboxGameOverlay*",
    "*Microsoft.XboxGamingOverlay*",
    "*Microsoft.XboxIdentityProvider*",
    "*Microsoft.XboxSpeechToTextOverlay*",
    "*Microsoft.YourPhone*",
    "*Microsoft.ZuneMusic*",
    "*Microsoft.ZuneVideo*",
    "*MicrosoftTeams*"
)

    $appsRestored = 0
    foreach ($appPattern in $appsToReinstall) {
        Get-AppXPackage -AllUsers $appPattern -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.InstallLocation -and (Test-Path (Join-Path $_.InstallLocation "AppXManifest.xml"))) {
                Add-AppxPackage -DisableDevelopmentMode -Register -ErrorAction SilentlyContinue (Join-Path $_.InstallLocation "AppXManifest.xml") | Out-Null
                $appsRestored++
            }
        }
    }
    Write-PTWSuccess "UWP apps processed ($appsRestored available)"

    # Windows Capabilities
    $repairStep++
    Write-Output "  [$repairStep/$repairSteps] Restoring Windows capabilities..."
    $capabilities = @(
    "App.StepsRecorder~~~~0.0.1.0",
    "App.Support.QuickAssist~~~~0.0.1.0",
    "Browser.InternetExplorer~~~~0.0.11.0",
    "DirectX.Configuration.Database~~~~0.0.1.0",
    "Hello.Face.18967~~~~0.0.1.0",
    "Hello.Face.20134~~~~0.0.1.0",
    "MathRecognizer~~~~0.0.1.0",
    "Media.WindowsMediaPlayer~~~~0.0.12.0",
    "Microsoft.Wallpapers.Extended~~~~0.0.1.0",
    "Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0"
)
    foreach ($capability in $capabilities) {
        Add-WindowsCapability -Online -Name $capability -ErrorAction SilentlyContinue | Out-Null
    }
    Write-PTWSuccess "Windows capabilities restored"

    # OneDrive
    $repairStep++
    Write-Output "  [$repairStep/$repairSteps] Reinstalling OneDrive..."
    if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
        try {
            $null = Start-Process -FilePath "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
            Write-PTWSuccess "OneDrive installer launched"
        } catch {
            Write-PTWWarning "Could not launch OneDrive installer"
        }
    } elseif (Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") {
        try {
            $null = Start-Process -FilePath "$env:SystemRoot\System32\OneDriveSetup.exe" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
            Write-PTWSuccess "OneDrive installer launched"
        } catch {
            Write-PTWWarning "Could not launch OneDrive installer"
        }
    } else {
        Write-PTWWarning "OneDrive installer not found (skipped)"
    }

    # Windows Store
    $repairStep++
    Write-Output "  [$repairStep/$repairSteps] Re-registering Windows Store..."
    try {
        Get-AppxPackage -AllUsers *Microsoft.WindowsStore* -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.InstallLocation -and (Test-Path "$($_.InstallLocation)\AppXManifest.xml")) {
                Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
            }
        }
        Write-PTWSuccess "Windows Store re-registered"
    } catch {
        Write-PTWWarning "Could not re-register Windows Store"
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
