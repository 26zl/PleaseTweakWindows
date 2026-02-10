# General Tweaks
# Purpose: Non-interactive action dispatcher.
# Usage: powershell -File General-Tweaks.ps1 -Action "<action-id>"
# Version: 2.1.0
# Last Updated: 2026-01-18
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "power-plan-on",
        "power-plan-default",
        "bloatware-remove",
        "store-install",
        "widgets-disable",
        "widgets-enable",
        "background-apps-disable",
        "background-apps-enable",
        "cpp-install",
        "registry-apply",
        "scaling-fix",
        "scaling-default",
        "lockscreen-disable",
        "lockscreen-enable",
        "startmenu-clean",
        "shortcuts-add",
        "keyboard-disable",
        "keyboard-enable",
        "driver-clean",
        "hdcp-disable",
        "hdcp-enable",
        "cleanup-run",
        "autoruns-open",
        "menu"
    )]
    [string]$Action = "Menu"
)

$script:ScriptVersion = "2.1.0"

#region Logging
function Write-PTWLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) { "INFO" { "[*]" } "SUCCESS" { "[+]" } "WARNING" { "[!]" } "ERROR" { "[-]" } default { "[*]" } }
    Write-Output "$timestamp $prefix $Message"
}
#endregion

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
$script:CanDownload = Get-Command Get-FileFromWeb -ErrorAction SilentlyContinue

function Import-RegistryFile {
    param([string]$FileName)
    $regPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "regs") -ChildPath $FileName
    if (Test-Path $regPath) {
        Start-Process -FilePath "regedit.exe" -ArgumentList "/s `"$regPath`"" -Wait
    }
}

function Test-PowerSchemeExists {
    param([Parameter(Mandatory=$true)][string]$SchemeId)
    $list = powercfg /list 2>$null
    return ($list -match [regex]::Escape($SchemeId))
}

function Get-ActivePowerSchemeId {
    $active = powercfg /getactivescheme 2>$null
    if ($active -match '([0-9A-Fa-f-]{36})') {
        return $Matches[1]
    }
    return $null
}

#region Action Dispatcher
switch ($Action.ToLowerInvariant()) {

    "power-plan-on" {
        Write-Output "[*] Applying Ultimate Power Plan..."
        $schemeId = "99999999-9999-9999-9999-999999999999"
        if (-not (Test-PowerSchemeExists -SchemeId $schemeId)) {
            cmd /c "powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 $schemeId >nul 2>&1"
        }
        if ((Get-ActivePowerSchemeId) -ne $schemeId) {
            cmd /c "powercfg /SETACTIVE $schemeId >nul 2>&1"
        }
        Set-RegDword -Path "Registry::HKLM\SYSTEM\ControlSet001\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" -Name "ValueMax" -Value 0
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Value 1
        Write-Output "[+] SUCCESS: Ultimate Power Plan applied (restart required)"
        exit 0
    }

    "power-plan-default" {
        Write-Output "[*] Restoring default power plan..."
        cmd /c "powercfg /restoredefaultschemes >nul 2>&1"
        Remove-RegValue -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff"
        Write-Output "[+] SUCCESS: Default power plan restored (restart required)"
        exit 0
    }

    "bloatware-remove" {
        Write-Output "[*] Removing bloatware (protecting system components)..."
        $progressPreference = 'SilentlyContinue'
        $protectedPrefixes = @(
            # Core Windows Shell
            'Microsoft.Windows.ShellExperienceHost',
            'MicrosoftWindows.Client.CBS',
            'MicrosoftWindows.Client.Core',
            'Microsoft.Windows.StartMenuExperienceHost',
            'Microsoft.Windows.Search',
            'Windows.Search',
            'MicrosoftWindows.Client.FileExp',
            'MicrosoftWindows.Client.Photon',
            'Microsoft.Windows.FilePicker',
            'Microsoft.Windows.FileExplorer',
            'Microsoft.Windows.CloudExperienceHost',
            'Microsoft.Windows.ContentDeliveryManager',
            'Microsoft.Windows.PeopleExperienceHost',
            'Microsoft.AAD.BrokerPlugin',
            'Microsoft.AccountsControl',
            'Microsoft.LockApp',
            'windows.immersivecontrolpanel',
            'Windows.PrintDialog',
            # Store & App Infrastructure
            'Microsoft.WindowsStore',
            'Microsoft.StorePurchaseApp',
            'Microsoft.DesktopAppInstaller',
            'Microsoft.WindowsAppRuntime',
            'Microsoft.VCLibs',
            'Microsoft.UI.Xaml',
            'Microsoft.NET.Native',
            'AppXSvc',
            # Security & System
            'Microsoft.SecHealthUI',
            'Microsoft.Windows.SecureAssessmentBrowser',
            'Microsoft.BioEnrollment',
            'Microsoft.CredDialogHost',
            'Microsoft.ECApp',
            'Microsoft.AsyncTextService',
            # GPU Drivers
            'NVIDIACorp',
            'NVIDIA',
            'AdvancedMicroDevicesInc',
            'AMD',
            # Useful Apps
            'Microsoft.HEVCVideoExtension',
            'Microsoft.Paint',
            'Microsoft.WindowsNotepad',
            'Microsoft.Windows.Photos',
            'Microsoft.WindowsCalculator',
            'Microsoft.WindowsTerminal',
            'Microsoft.PowerShell',
            'Microsoft.WindowsCamera',
            'Microsoft.ScreenSketch'
        )

        function Test-ProtectedApp {
            param(
                [Parameter(Mandatory)][object]$App,
                [Parameter(Mandatory)][string[]]$Prefixes
            )
            $name = ($App.Name | ForEach-Object { $_.ToLowerInvariant() }) -join ''
            $family = ($App.PackageFamilyName | ForEach-Object { $_.ToLowerInvariant() }) -join ''
            foreach ($p in $Prefixes) {
                $needle = $p.ToLowerInvariant()
                if ($name.StartsWith($needle) -or $family.StartsWith($needle)) {
                    return $true
                }
            }
            return $false
        }

        $allApps = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        $appsToRemove = @()
        foreach ($app in $allApps) {
            if (Test-ProtectedApp -App $app -Prefixes $protectedPrefixes) { continue }
            if ($app.IsFramework -or $app.NonRemovable) { continue }
            if (-not $app.PackageFullName) { continue }
            $appsToRemove += [pscustomobject]@{
                Name = $app.Name
                PackageFullName = $app.PackageFullName
                PackageFamilyName = $app.PackageFamilyName
                InstallLocation = $app.InstallLocation
            }
        }

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $logDir = Join-Path $env:ProgramData "PleaseTweakWindows\\logs"
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        $backupPath = Join-Path $logDir "bloatware-removed-$timestamp.json"
        $restoreScriptPath = Join-Path $logDir "bloatware-restore-$timestamp.ps1"
        $appsToRemove | ConvertTo-Json -Depth 4 | Set-Content -Path $backupPath -Encoding UTF8

        $restoreScript = @"
# Restore removed UWP apps for the current user (best effort).
# Usage: powershell -File `"$restoreScriptPath`"
param([string]`$LogFile = `"$backupPath`")

if (-not (Test-Path `$LogFile)) {
    Write-Output "[-] Log file not found: `$LogFile"
    exit 1
}

`$apps = Get-Content -Path `$LogFile -Raw | ConvertFrom-Json
foreach (`$app in `$apps) {
    if (`$app.InstallLocation -and (Test-Path `$app.InstallLocation)) {
        `$manifest = Join-Path `$app.InstallLocation "AppxManifest.xml"
        if (Test-Path `$manifest) {
            Add-AppxPackage -DisableDevelopmentMode -Register `$manifest -ErrorAction SilentlyContinue | Out-Null
            Write-Output "[+] Restored: `$(`$app.Name)"
        } else {
            Write-Output "[!] Missing manifest for: `$(`$app.Name)"
        }
    } else {
        Write-Output "[!] Missing install location for: `$(`$app.Name)"
    }
}
"@
        Set-Content -Path $restoreScriptPath -Value $restoreScript -Encoding UTF8

        $removed = 0
        foreach ($app in $appsToRemove) {
            try {
                Remove-AppxPackage -Package $app.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                $removed++
            } catch {
                Write-Verbose "Failed to remove $($app.Name): $($_.Exception.Message)"
            }
        }
        Stop-Process -Force -Name OneDrive -ErrorAction SilentlyContinue
        cmd /c "C:\Windows\SysWOW64\OneDriveSetup.exe -uninstall >nul 2>&1"
        Write-Output "[+] SUCCESS: Removed $removed apps (restart required)"
        Write-Output "[i] Backup list: $backupPath"
        Write-Output "[i] Restore script: $restoreScriptPath"
        exit 0
    }

    "store-install" {
        Write-Output "[*] Reinstalling Microsoft Store..."
        Get-AppxPackage -AllUsers *Microsoft.WindowsStore* -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.InstallLocation -and (Test-Path "$($_.InstallLocation)\AppXManifest.xml")) {
                Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
            }
        }
        Write-Output "[+] SUCCESS: Microsoft Store reinstalled"
        exit 0
    }

    "widgets-disable" {
        Write-Output "[*] Disabling Widgets..."
        Set-RegDword -Path "Registry::HKLM\SOFTWARE\Microsoft\PolicyManager\default\NewsAndInterests\AllowNewsAndInterests" -Name "value" -Value 0
        Set-RegDword -Path "Registry::HKLM\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0
        Stop-Process -Force -Name Widgets -ErrorAction SilentlyContinue
        Write-Output "[+] SUCCESS: Widgets disabled (restart required)"
        exit 0
    }

    "widgets-enable" {
        Write-Output "[*] Enabling Widgets..."
        Remove-RegValue -Path "Registry::HKLM\SOFTWARE\Microsoft\PolicyManager\default\NewsAndInterests\AllowNewsAndInterests" -Name "value"
        Remove-RegValue -Path "Registry::HKLM\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests"
        Write-Output "[+] SUCCESS: Widgets enabled (restart required)"
        exit 0
    }

    "background-apps-disable" {
        Write-Output "[*] Disabling Background Apps..."
        Set-RegDword -Path "Registry::HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground" -Value 2
        Write-Output "[+] SUCCESS: Background Apps disabled (restart required)"
        exit 0
    }

    "background-apps-enable" {
        Write-Output "[*] Enabling Background Apps..."
        Remove-RegValue -Path "Registry::HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground"
        Write-Output "[+] SUCCESS: Background Apps enabled (restart required)"
        exit 0
    }

    "cpp-install" {
        Write-Output "[*] Installing C++ Redistributables..."
        $urls = @(
            @{url="https://aka.ms/vs/17/release/vc_redist.x64.exe"; file="vcredist_x64.exe"; args="/passive /norestart"},
            @{url="https://aka.ms/vs/17/release/vc_redist.x86.exe"; file="vcredist_x86.exe"; args="/passive /norestart"}
        )
        foreach ($item in $urls) {
            Get-FileFromWeb -URL $item.url -File "$env:TEMP\$($item.file)"
            Start-Process -Wait "$env:TEMP\$($item.file)" -ArgumentList $item.args
        }
        Write-Output "[+] SUCCESS: C++ Redistributables installed"
        exit 0
    }

    "registry-apply" {
        $markerPath = "HKCU:\Software\PleaseTweakWindows"
        if (Get-ItemProperty -Path $markerPath -Name "RegistryOptimized" -ErrorAction SilentlyContinue) {
            Write-Output "[!] Registry tweaks already applied. Skipping to prevent corruption."
            exit 0
        }

        Write-Output "[*] Applying Registry Tweaks..."
        schtasks /Change /DISABLE /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" 2>$null
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PCIE EXPRESS 0
        Import-RegistryFile -FileName "Registry-Optimize.reg"

        if (!(Test-Path $markerPath)) { New-Item -Path $markerPath -Force | Out-Null }
        Set-ItemProperty -Path $markerPath -Name "RegistryOptimized" -Value 1
        Write-Output "[+] SUCCESS: Registry tweaks applied (restart required)"
        exit 0
    }

    "scaling-fix" {
        Write-Output "[*] Applying 100% scaling fix..."
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseSensitivity" -Value "10"
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseSpeed" -Value "0"
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0"
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0"
        Set-RegDword -Path "Registry::HKCU\Control Panel\Desktop" -Name "Win8DpiScaling" -Value 1
        Set-RegDword -Path "Registry::HKCU\Control Panel\Desktop" -Name "LogPixels" -Value 96
        Set-RegDword -Path "Registry::HKCU\Control Panel\Desktop" -Name "EnablePerProcessSystemDPI" -Value 0
        Write-Output "[+] SUCCESS: Scaling fix applied (restart required)"
        exit 0
    }

    "scaling-default" {
        Write-Output "[*] Restoring default scaling..."
        Remove-RegValue -Path "Registry::HKCU\Control Panel\Desktop" -Name "Win8DpiScaling"
        Remove-RegValue -Path "Registry::HKCU\Control Panel\Desktop" -Name "LogPixels"
        Remove-RegValue -Path "Registry::HKCU\Control Panel\Desktop" -Name "EnablePerProcessSystemDPI"
        Write-Output "[+] SUCCESS: Default scaling restored (restart required)"
        exit 0
    }

    "lockscreen-disable" {
        Write-Output "[*] Disabling Lock Screen..."
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $w = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Width
        $h = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height
        $bmp = New-Object System.Drawing.Bitmap $w, $h
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.FillRectangle([System.Drawing.Brushes]::Black, 0, 0, $w, $h)
        $g.Dispose()
        $bmp.Save("C:\Windows\Black.jpg")
        $bmp.Dispose()
        Set-RegSz -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImagePath" -Value "C:\Windows\Black.jpg"
        Set-RegDword -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImageStatus" -Value 1
        Write-Output "[+] SUCCESS: Lock Screen disabled (restart required)"
        exit 0
    }

    "lockscreen-enable" {
        Write-Output "[*] Enabling Lock Screen..."
        Remove-Item -Force "C:\Windows\Black.jpg" -ErrorAction SilentlyContinue
        Remove-Item -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Output "[+] SUCCESS: Lock Screen enabled (restart required)"
        exit 0
    }

    "startmenu-clean" {
        Write-Output "[*] Cleaning Start Menu and Taskbar..."
        Remove-RegKey -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
        Set-RegDword -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0
        Set-RegDword -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0
        Set-RegDword -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0
        Set-RegDword -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0
        Stop-Process -Force -Name explorer -ErrorAction SilentlyContinue
        Write-Output "[+] SUCCESS: Start Menu cleaned (restart required)"
        exit 0
    }

    "shortcuts-add" {
        Write-Output "[*] Adding Start Menu Shortcuts..."
        $WshShell = New-Object -ComObject WScript.Shell
        $paths = @(
            @{target="$env:ProgramData\Microsoft\Windows\Start Menu\Programs"; name="Start Menu Shortcuts 1.lnk"},
            @{target="$env:AppData\Microsoft\Windows\Start Menu\Programs"; name="Start Menu Shortcuts 2.lnk"},
            @{target="$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup"; name="Startup Programs 1.lnk"},
            @{target="$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"; name="Startup Programs 2.lnk"}
        )
        foreach ($p in $paths) {
            $s = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$($p.name)")
            $s.TargetPath = $p.target
            $s.Save()
        }
        Write-Output "[+] SUCCESS: Start Menu shortcuts added"
        exit 0
    }

    "keyboard-disable" {
        Write-Output "[*] Disabling Keyboard Shortcuts..."
        Set-RegDword -Path "Registry::HKLM\SYSTEM\ControlSet001\Services\hidserv" -Name "Start" -Value 4
        Set-RegDword -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoWinKeys" -Value 1
        Set-RegDword -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisabledHotkeys" -Value 1
        Write-Output "[+] SUCCESS: Keyboard shortcuts disabled (restart required)"
        exit 0
    }

    "keyboard-enable" {
        Write-Output "[*] Enabling Keyboard Shortcuts..."
        Set-RegDword -Path "Registry::HKLM\SYSTEM\ControlSet001\Services\hidserv" -Name "Start" -Value 3
        Remove-RegValue -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoWinKeys"
        Remove-RegValue -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisabledHotkeys"
        Remove-RegValue -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map"
        Write-Output "[+] SUCCESS: Keyboard shortcuts enabled (restart required)"
        exit 0
    }

    "driver-clean" {
        Write-Output "[*] Installing DDU..."
        Get-FileFromWeb -URL "https://github.com/FR33THYFR33THY/files/raw/main/DDU.zip" -File "$env:TEMP\DDU.zip"
        Expand-Archive "$env:TEMP\DDU.zip" -DestinationPath "$env:TEMP\DDU" -Force -ErrorAction SilentlyContinue
        $WshShell = New-Object -ComObject WScript.Shell
        $s = $WshShell.CreateShortcut("$Home\Desktop\Display Driver Uninstaller.lnk")
        $s.TargetPath = "$env:TEMP\DDU\Display Driver Uninstaller.exe"
        $s.Save()
        Write-Output "[+] SUCCESS: DDU installed to Desktop"
        exit 0
    }

    "hdcp-disable" {
        Write-Output "[*] Disabling HDCP..."
        $subkeys = (Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue).Name
        foreach ($key in $subkeys) {
            if ($key -notlike '*Configuration') {
                Set-RegDword -Path "$key" -Name "RMHdcpKeyglobZero" -Value 1
            }
        }
        Write-Output "[+] SUCCESS: HDCP disabled (restart required)"
        exit 0
    }

    "hdcp-enable" {
        Write-Output "[*] Enabling HDCP..."
        $subkeys = (Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue).Name
        foreach ($key in $subkeys) {
            if ($key -notlike '*Configuration') {
                Remove-RegValue -Path "$key" -Name "RMHdcpKeyglobZero"
            }
        }
        Write-Output "[+] SUCCESS: HDCP enabled (restart required)"
        exit 0
    }

    "cleanup-run" {
        Write-Output "[*] Running System Cleanup..."
        $paths = @("$env:TEMP","$env:SystemDrive\Windows\Temp","$env:SystemDrive\Windows\Prefetch")
        foreach ($p in $paths) { Remove-Item -Path "$p\*" -Recurse -Force -ErrorAction SilentlyContinue }
        try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch { Write-Verbose "Could not clear recycle bin: $($_.Exception.Message)" }
        Write-Output "[+] SUCCESS: System cleanup complete"
        exit 0
    }

    "autoruns-open" {
        Write-Output "[*] Launching Sysinternals Autoruns..."
        if (-not $script:CanDownload) {
            Write-Output "[-] ERROR: Download helper not available (CommonFunctions.ps1 missing)"
            exit 1
        }
        $autorunsZip = Join-Path $env:TEMP "Autoruns.zip"
        $autorunsDir = Join-Path $env:TEMP "Autoruns"
        Remove-Item -Path $autorunsZip -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $autorunsDir -Recurse -Force -ErrorAction SilentlyContinue
        Get-FileFromWeb -URL "https://download.sysinternals.com/files/Autoruns.zip" -File $autorunsZip
        Expand-Archive $autorunsZip -DestinationPath $autorunsDir -Force -ErrorAction SilentlyContinue
        $autorunsExe = if ([Environment]::Is64BitOperatingSystem) {
            Join-Path $autorunsDir "Autoruns64.exe"
        } else {
            Join-Path $autorunsDir "Autoruns.exe"
        }
        if (-not (Test-Path $autorunsExe)) {
            $autorunsExe = Join-Path $autorunsDir "Autoruns.exe"
        }
        if (-not (Test-Path $autorunsExe)) {
            Write-Output "[-] ERROR: Autoruns executable not found after download"
            exit 1
        }
        Start-Process -FilePath $autorunsExe
        Write-Output "[+] SUCCESS: Autoruns launched"
        exit 0
    }

    "menu" {
        Write-Output "[i] No interactive menu - use JavaFX GUI to select tweaks"
        exit 0
    }

    default {
        Write-Error "Unknown action: $Action"
        exit 1
    }
}
#endregion
