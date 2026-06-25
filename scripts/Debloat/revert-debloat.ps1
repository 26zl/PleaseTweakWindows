# Debloat Revert Script
# Purpose: Restores defaults and repairs removed components (apps, widgets, background apps, services).
# Usage: powershell -File revert-debloat.ps1 -Mode <Revert|Repair|RevertAndRepair>
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

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

$doRevert = ($Mode -eq 'Revert') -or ($Mode -eq 'RevertAndRepair')
$doRepair = ($Mode -eq 'Repair') -or ($Mode -eq 'RevertAndRepair')

Write-Output ""
Write-Output "========================================"
Write-Output "  Debloat - $Mode"
Write-Output "========================================"
Write-Output ""

#region REVERT Operations
if ($doRevert) {
    $totalSteps = 3
    $currentStep = 0

    # Background apps & Widgets
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring background apps & widgets..."
    Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground"
    Set-RegDword -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\NewsAndInterests\AllowNewsAndInterests" -Name "value" -Value 1
    Remove-RegKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
    Write-PTWSuccess "Background apps & widgets restored"

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

    # Services restore
    $currentStep++
    Write-Output "  [$currentStep/$totalSteps] Restoring services to default..."
    $regPath = Join-Path $PSScriptRoot "regs\servicesDefault.reg"
    if (-not (Test-Path $regPath)) {
        Write-PTWWarning "Services default registry not found: $regPath (skipped)"
    } else {
        $imported = Import-RegistryFile -RegFile $regPath
        # regedit.exe /s can report success even on a partial/blocked import, so
        # re-validate a couple of key services returned to their defaults (Start=2).
        $spoolerStart = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Spooler" -Name "Start" -ErrorAction SilentlyContinue).Start
        $themesStart = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Themes" -Name "Start" -ErrorAction SilentlyContinue).Start
        if ((-not $imported) -or ($spoolerStart -ne 2) -or ($themesStart -ne 2)) {
            Write-PTWWarning "Services restore did not fully apply (Spooler Start='$spoolerStart', Themes Start='$themesStart', expected 2). Some services may still be disabled - try running this again as Administrator."
        } else {
            Write-PTWSuccess "Services restored to Windows defaults"
        }
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
