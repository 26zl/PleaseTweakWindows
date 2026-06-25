# Debloat
# Purpose: Non-interactive action dispatcher.
# Usage: powershell -File debloat.ps1 -Action "<action-id>"
# Version: 2.1.0
# Last Updated: 2026-01-18
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "bloatware-remove",
        "bloatware-persist-on",
        "bloatware-persist-off",
        "store-install",
        "widgets-disable",
        "widgets-enable",
        "background-apps-disable",
        "background-apps-enable",
        "services-disable",
        "services-restore",
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

# Apps protected from removal: core shell, Store/app infrastructure, security, GPU
# drivers and a few useful apps. Shared by the one-shot 'bloatware-remove' action AND
# the persistent 'bloatware-persist-on' scheduled task so the two never drift apart.
$script:PtwProtectedPrefixes = @(
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

#region Action Dispatcher
switch ($Action.ToLowerInvariant()) {

    "bloatware-remove" {
        Write-Output "[*] Removing bloatware (protecting system components)..."
        $ProgressPreference = 'SilentlyContinue'
        $protectedPrefixes = $script:PtwProtectedPrefixes

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
        $logDir = Join-Path $env:ProgramData "PleaseTweakWindows\logs"
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

        # Deprovision matching packages FIRST so Windows Update and freshly-created user
        # profiles do not re-add them after this removal. Previously only Remove-AppxPackage
        # ran, so removed apps reappeared on the next feature update / new account.
        $removeNames = @($appsToRemove | ForEach-Object { $_.Name })
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | ForEach-Object {
            if ($removeNames -contains $_.DisplayName) {
                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
            }
        }

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
        cmd /c "$env:SystemRoot\SysWOW64\OneDriveSetup.exe -uninstall >nul 2>&1"
        Write-Output "[+] SUCCESS: Removed $removed apps (restart required)"
        Write-Output "[i] Backup list: $backupPath"
        Write-Output "[i] Restore script: $restoreScriptPath"
        Exit-PTW
    }

    "store-install" {
        Write-Output "[*] Reinstalling Microsoft Store..."
        Get-AppxPackage -AllUsers *Microsoft.WindowsStore* -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.InstallLocation -and (Test-Path "$($_.InstallLocation)\AppXManifest.xml")) {
                Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
            }
        }
        Write-Output "[+] SUCCESS: Microsoft Store reinstalled"
        Exit-PTW
    }

    "widgets-disable" {
        Write-Output "[*] Disabling Widgets..."
        Set-RegDword -Path "Registry::HKLM\SOFTWARE\Microsoft\PolicyManager\default\NewsAndInterests\AllowNewsAndInterests" -Name "value" -Value 0
        Set-RegDword -Path "Registry::HKLM\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0
        Stop-Process -Force -Name Widgets -ErrorAction SilentlyContinue
        Write-Output "[+] SUCCESS: Widgets disabled (restart required)"
        Exit-PTW
    }

    "widgets-enable" {
        Write-Output "[*] Enabling Widgets..."
        Remove-RegValue -Path "Registry::HKLM\SOFTWARE\Microsoft\PolicyManager\default\NewsAndInterests\AllowNewsAndInterests" -Name "value"
        Remove-RegValue -Path "Registry::HKLM\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests"
        Write-Output "[+] SUCCESS: Widgets enabled (restart required)"
        Exit-PTW
    }

    "background-apps-disable" {
        Write-Output "[*] Disabling Background Apps..."
        Set-RegDword -Path "Registry::HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground" -Value 2
        Write-Output "[+] SUCCESS: Background Apps disabled (restart required)"
        Exit-PTW
    }

    "background-apps-enable" {
        Write-Output "[*] Enabling Background Apps..."
        Remove-RegValue -Path "Registry::HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground"
        Write-Output "[+] SUCCESS: Background Apps enabled (restart required)"
        Exit-PTW
    }

    "bloatware-persist-on" {
        Write-Output "[*] Enabling persistent bloatware removal..."
        Write-Output "[!] WARNING: this installs a SYSTEM scheduled task that, at EVERY logon, removes and de-provisions all non-protected Store apps. Apps Windows re-adds via updates will be removed again. Turn it off with the Revert button."
        $ProgressPreference = 'SilentlyContinue'

        $prefixLiteral = ($script:PtwProtectedPrefixes | ForEach-Object { "    '$_'" }) -join ",`n"
        # Literal here-string: $_ / $protected stay literal; __PREFIXES__ is substituted below.
        $genTemplate = @'
# PleaseTweakWindows - persistent bloatware removal (auto-generated; do not edit).
# Runs at each logon as SYSTEM to re-remove apps Windows re-provisions.
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

$protected = @(
__PREFIXES__
)

function Test-PtwProtected {
    param([string]$Name, [string]$Family)
    $n = $Name.ToLowerInvariant()
    $f = $Family.ToLowerInvariant()
    foreach ($p in $protected) {
        $needle = $p.ToLowerInvariant()
        if ($n.StartsWith($needle) -or $f.StartsWith($needle)) { return $true }
    }
    return $false
}

Get-AppxProvisionedPackage -Online | ForEach-Object {
    $dn = "$($_.DisplayName)"
    if (-not (Test-PtwProtected -Name $dn -Family $dn)) {
        Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
    }
}

Get-AppxPackage -AllUsers | ForEach-Object {
    if ($_.IsFramework -or $_.NonRemovable) { return }
    if (-not $_.PackageFullName) { return }
    if (-not (Test-PtwProtected -Name "$($_.Name)" -Family "$($_.PackageFamilyName)")) {
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
    }
}
'@
        $generated = $genTemplate.Replace('__PREFIXES__', $prefixLiteral)

        $ptwRoot = Join-Path $env:ProgramData "PleaseTweakWindows"
        $persistDir = Join-Path $ptwRoot "Scripts"
        $persistScript = Join-Path $persistDir "BloatRemoval.ps1"
        try {
            # This script runs as SYSTEM at every logon, so the file it runs from must not be
            # modifiable OR pre-stageable by a non-admin, or it is a privilege-escalation vector.
            # C:\ProgramData is Users-writable by default, and a pre-created file keeps its
            # creator as OWNER (an owner implicitly holds WRITE_DAC). So harden the whole PTW tree:
            #   1) ensure it exists, 2) SEIZE OWNERSHIP to Administrators recursively, 3) RESET
            #   child ACLs (clears any attacker-set or broken-inheritance ACEs), 4) lock the DACL
            #   to SYSTEM + Administrators full, Users read-only. Then recreate the script dir
            #   fresh (drops any planted file / reparse point) before writing.
            New-Item -ItemType Directory -Path $ptwRoot -Force | Out-Null
            & icacls.exe "$ptwRoot" /setowner "*S-1-5-32-544" /T /C 2>&1 | Out-Null
            & icacls.exe "$ptwRoot" /reset /T /C 2>&1 | Out-Null
            & icacls.exe "$ptwRoot" /inheritance:r /grant:r "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-32-545:(OI)(CI)RX" 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Output "[-] ERROR: could not lock $ptwRoot (icacls exit $LASTEXITCODE). Aborting to avoid an unsafe SYSTEM auto-run script."
                exit 1
            }
            # Best-effort re-stamp of any pre-existing children (e.g. an earlier logs\ dir) with the
            # tightened ACL. Uses /T and is intentionally NOT failure-checked: /C can return non-zero
            # on a transient locked child, which must not abort the already-verified root lock above.
            & icacls.exe "$ptwRoot" /grant:r "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-32-545:(OI)(CI)RX" /T /C 2>&1 | Out-Null
            Remove-Item -LiteralPath $persistDir -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -ItemType Directory -Path $persistDir -Force | Out-Null
            Set-Content -Path $persistScript -Value $generated -Encoding UTF8
        } catch {
            Write-Output "[-] ERROR: could not write the persistence script: $($_.Exception.Message)"
            exit 1
        }

        try {
            $taskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$persistScript`""
            $taskTrigger = New-ScheduledTaskTrigger -AtLogOn
            $taskPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
            $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
            Register-ScheduledTask -TaskName 'BloatRemoval' -TaskPath '\PleaseTweakWindows\' `
                -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Force | Out-Null
            Start-ScheduledTask -TaskName 'BloatRemoval' -TaskPath '\PleaseTweakWindows\' -ErrorAction SilentlyContinue
        } catch {
            Write-Output "[-] ERROR: could not register the scheduled task: $($_.Exception.Message)"
            exit 1
        }

        Write-Output "[i] Persistence script: $persistScript"
        Write-Output "[+] SUCCESS: persistent bloatware removal enabled (Task Scheduler\PleaseTweakWindows\BloatRemoval)"
        Exit-PTW
    }

    "bloatware-persist-off" {
        Write-Output "[*] Disabling persistent bloatware removal..."
        Unregister-ScheduledTask -TaskName 'BloatRemoval' -TaskPath '\PleaseTweakWindows\' -Confirm:$false -ErrorAction SilentlyContinue
        $persistScript = Join-Path $env:ProgramData "PleaseTweakWindows\Scripts\BloatRemoval.ps1"
        Remove-Item -Path $persistScript -Force -ErrorAction SilentlyContinue
        Write-Output "[+] SUCCESS: persistent bloatware removal disabled (the scheduled task and its script were removed)"
        Exit-PTW
    }

    "services-disable" {
        Write-Output "[*] Applying Services Optimization (Minimal)..."
        Write-Output "[!] NOTE: Wi-Fi and Bluetooth may not work with minimal services"
        Write-Output "[!] WARNING: This aggressive service set will also:"
        Write-Output "[!]   - DISABLE PRINTING. The Print Spooler is turned off, so all local and"
        Write-Output "[!]     network printing will stop working until services are restored."
        Write-Output "[!]   - STOP FILE/PRINTER SHARING HOSTING. LanmanServer (the 'Server' service)"
        Write-Output "[!]     is disabled, so this PC can no longer host shared folders/printers,"
        Write-Output "[!]     and admin shares (C`$) used by some backup/management tools will break."
        Write-Output "[!]   - AFFECT VISUAL STYLES. The Themes service is disabled, which can revert"
        Write-Output "[!]     the desktop to a classic appearance and break Settings > Personalization."
        Write-Output "[!] Use 'Restore Default Services' to undo all of these changes."
        $regPath = Join-Path $PSScriptRoot "regs\servicesTweaked.reg"
        $defaultRegPath = Join-Path $PSScriptRoot "regs\servicesDefault.reg"
        if (Test-Path $regPath) {
            try {
                $proc = Start-Process -FilePath "regedit.exe" -ArgumentList "/s", "`"$regPath`"" -Wait -PassThru -NoNewWindow
                if ($proc.ExitCode -ne 0) {
                    throw "regedit.exe exited with code $($proc.ExitCode)"
                }
                Start-Sleep -Seconds 2
                # regedit.exe /s can return 0 even on a partial/access-denied import,
                # so spot-check a service this tweak is supposed to DISABLE (Spooler -> Start=4).
                $spoolerStart = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Spooler" -Name "Start" -ErrorAction SilentlyContinue).Start
                if ($null -ne $spoolerStart -and $spoolerStart -ne 4) {
                    Write-Output "[!] WARNING: Verification failed - Spooler Start is '$spoolerStart' (expected 4)."
                    Write-Output "[!] The services import may have been partially blocked. Review with care."
                }
                Write-Output "[+] SUCCESS: Services optimization applied (restart required)"
            } catch {
                Write-Output "[-] ERROR during services optimization: $($_.Exception.Message)"
                Write-Output "[!] Attempting rollback with default services registry..."
                if (Test-Path $defaultRegPath) {
                    $rb = Start-Process -FilePath "regedit.exe" -ArgumentList "/s", "`"$defaultRegPath`"" -Wait -PassThru -NoNewWindow
                    if ($rb.ExitCode -ne 0) {
                        Write-Output "[-] Rollback FAILED (regedit exit code $($rb.ExitCode)). Services may remain disabled - run 'Restore Default Services'."
                    } else {
                        Write-Output "[+] Rollback applied. Restart to restore defaults."
                    }
                } else {
                    Write-Output "[-] Rollback file not found: $defaultRegPath"
                }
                exit 1
            }
        } else {
            Write-Output "[-] ERROR: Registry file not found: $regPath"
            exit 1
        }
        Exit-PTW
    }

    "services-restore" {
        Write-Output "[*] Restoring Services to Default..."
        $regPath = Join-Path $PSScriptRoot "regs\servicesDefault.reg"
        if (Test-Path $regPath) {
            $proc = Start-Process -FilePath "regedit.exe" -ArgumentList "/s", "`"$regPath`"" -Wait -PassThru -NoNewWindow
            Start-Sleep -Seconds 2
            # regedit.exe /s can report exit 0 even on a partial/blocked import, so
            # re-validate a couple of key services actually returned to their defaults
            # (Spooler -> 2 / Automatic, Themes -> 2 / Automatic).
            $spoolerStart = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Spooler" -Name "Start" -ErrorAction SilentlyContinue).Start
            $themesStart = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Themes" -Name "Start" -ErrorAction SilentlyContinue).Start
            if (($proc.ExitCode -ne 0) -or ($spoolerStart -ne 2) -or ($themesStart -ne 2)) {
                Write-Output "[-] ERROR: Services restore did not fully apply (regedit exit $($proc.ExitCode); Spooler Start='$spoolerStart', Themes Start='$themesStart', expected 2)."
                Write-Output "[!] Some services may still be disabled. Try running 'Restore Default Services' again as Administrator."
                exit 1
            }
            Write-Output "[+] SUCCESS: Services restored to default (restart required)"
        } else {
            Write-Output "[-] ERROR: Registry file not found: $regPath"
            exit 1
        }
        Exit-PTW
    }

    "menu" {
        Write-Output "[i] No interactive menu - use JavaFX GUI to select tweaks"
        Exit-PTW
    }

    default {
        Write-Error "Unknown action: $Action"
        exit 1
    }
}
#endregion
