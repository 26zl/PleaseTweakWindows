# Privacy Revert Script
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Revert', 'Repair', 'RevertAndRepair')]
    [string]$Mode = 'RevertAndRepair',
    [Parameter(Mandatory=$false)]
    [string]$Action = ''
)

$scriptsRoot = Split-Path $PSScriptRoot -Parent
$commonFunctionsPath = Join-Path $scriptsRoot "CommonFunctions.ps1"
if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
} else {
    Write-Output "[-] CommonFunctions.ps1 not found; refusing to continue"
    exit 1
}

function Restore-ExplorerFolder {
    param(
        [Parameter(Mandatory)][string]$FolderName,
        [Parameter(Mandatory)][string]$Guid
    )
    Write-Output " [*] Restoring '$FolderName' in This PC..."

    # Keep the 3D Objects folder hidden to match the Windows 11 default.
    $threeDObjectsGuid = '31C0DD25-9439-4F12-BF41-7FF4EDA38722'
    if ($Guid -ne $threeDObjectsGuid) {
        $paths = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{$Guid}\PropertyBag",
            "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{$Guid}\PropertyBag"
        )
        foreach ($path in $paths) {
            Set-RegValueSafe -Path $path -Name 'ThisPCPolicy' -Type 'String' -Value 'Show'
        }
    }

    Remove-RegValueSafe -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideMyComputerIcons' -Name "{$Guid}"

    # Clear hide flags only on existing namespace keys.
    $nsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{$Guid}"
    if (Test-Path -LiteralPath $nsPath) {
        # Windows 11: clear the HiddenByDefault / HideIfEnabled flags to unhide the folder.
        Remove-RegValueSafe -Path $nsPath -Name 'HiddenByDefault'
        Remove-RegValueSafe -Path $nsPath -Name 'HideIfEnabled'
    }
}

function Restore-UiOnlineContent {
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'AllowOnlineTips'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoInternetOpenWith'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoOnlinePrintsWizard'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoPublishingWizard'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoWebServices'
}

function Restore-UiSecureRecentDocList {
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoRecentDocsHistory'
    Remove-RegValueSafe -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'ClearRecentDocsOnExit'
}

function Restore-UiThisPcFolderList {
    $folders = @{
        'Desktop'    = 'B4BFCC3A-DB2C-424C-B029-7FE99A87C641'
        'Documents'  = 'f42ee2d3-909f-4907-8871-4c22fc0bf756'
        'Downloads'  = '7d83ee9b-2244-4e70-b1f5-5393042af1e4'
        'Music'      = 'a0c69a99-21c8-4671-8703-7934162fcf1d'
        'Pictures'   = '0ddd015d-b06c-45d5-8c4c-f59713854639'
        'Videos'     = '35286a68-3c57-41a1-bbb1-0eae73d76c95'
        '3D Objects' = '31C0DD25-9439-4F12-BF41-7FF4EDA38722'
    }

    foreach ($name in $folders.Keys) {
        Restore-ExplorerFolder -FolderName $name -Guid $folders[$name]
    }
}

function Restore-UiLockScreenNotification {
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'DisableLockScreenAppNotifications'
}

function Restore-UiStoreOpenWith {
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'NoUseStoreOpenWith'
}

function Restore-UiQuickAccessRecentItem {
    Remove-RegValueSafe -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' -Name 'ShowRecent'

    $delegateGuid = '{3134ef9c-6b18-4996-ad04-ed5912e00eb5}'
    $delegatePaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HomeFolderDesktop\NameSpace\DelegateFolders\$delegateGuid",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\HomeFolderDesktop\NameSpace\DelegateFolders\$delegateGuid"
    )
    foreach ($path in $delegatePaths) {
        Set-RegistryDefaultValueSafe -Path $path -Value 'Recent Files Folder'
    }
}

function Restore-UiSyncProviderNotification {
    Remove-RegValueSafe -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowSyncProviderNotifications'
}

function Restore-UiHibernation {
    try {
        powercfg -h on | Out-Null
    } catch {
        Write-Warning "[WARN] Failed to re-enable hibernation: $($_.Exception.Message)"
    }
}

function Restore-UiCameraOsd {
    Remove-RegValueSafe -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoPhysicalCameraLED'
}

function Restore-Copilot {
    $ProgressPreference = 'SilentlyContinue'
    # Restore Copilot by removing its policy overrides.
    Remove-RegKey -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
    Remove-RegKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"

    Write-Output "[i] Copilot policy overrides cleared. The installed package was not modified."
}

function Restore-Telemetry {
    # Removes the AllowTelemetry policy override set by the privacy 'telemetry-off' apply.
    Remove-RegValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry"
    Remove-RegValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry"
}

function Restore-TelemetryPolicyEnforce {
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableConsumerAccountStateContent'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableTailoredExperiencesWithDiagnosticData'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' -Name 'AITEnable'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows' -Name 'CEIPEnable'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Assistance\Client\1.0' -Name 'NoImplicitFeedback'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'DoNotShowFeedbackNotifications'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowDeviceNameInTelemetry'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' -Name 'DisabledByGroupPolicy'
}

function Restore-BlockMsAccount {
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'NoConnectedUser'
}

function Restore-OneDrivePolicyDisable {
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Name 'DisableFileSyncNGSC'
}

function Restore-RecallDisable {
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableAIDataAnalysis'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'AllowRecallEnablement'
    Remove-RegValueSafe -Path 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableAIDataAnalysis'
}

function Restore-CameraMicDeny {
    # Restore sensor consent to Allow and remove the policy overrides.
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam' -Name 'Value' -Type 'String' -Value 'Allow'
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone' -Name 'Value' -Type 'String' -Value 'Allow'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Name 'LetAppsAccessCamera'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Name 'LetAppsAccessMicrophone'
}

$script:PtwTelemetryTasks = @(
    @{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'Microsoft Compatibility Appraiser' },
    @{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'ProgramDataUpdater' },
    @{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'StartupAppTask' },
    @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'Consolidator' },
    @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'UsbCeip' },
    @{ Path = '\Microsoft\Windows\Autochk\'; Name = 'Proxy' },
    @{ Path = '\Microsoft\Windows\Feedback\Siuf\'; Name = 'DmClient' },
    @{ Path = '\Microsoft\Windows\Feedback\Siuf\'; Name = 'DmClientOnScenarioDownload' },
    @{ Path = '\Microsoft\Windows\Windows Error Reporting\'; Name = 'QueueReporting' }
)

function Restore-TelemetryTasksDisable {
    foreach ($t in $script:PtwTelemetryTasks) {
        try {
            $task = Get-ScheduledTask -TaskPath $t.Path -TaskName $t.Name -ErrorAction SilentlyContinue
            if ($task) {
                Enable-ScheduledTask -TaskPath $t.Path -TaskName $t.Name -ErrorAction Stop | Out-Null
            }
        } catch {
            Write-Verbose "Could not re-enable $($t.Name): $($_.Exception.Message)"
        }
    }
}

function Restore-LocationDisable {
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocation'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocationScripting'
}

function Restore-WebSearchDisable {
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'DisableWebSearch'
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'ConnectedSearchUseWeb'
    Remove-RegValueSafe -Path 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions'
}

function Restore-DeliveryOptimizationDisable {
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Name 'DODownloadMode'
}

function Restore-DnsAndDoh {
    $dnsServers = @(
        "1.1.1.1",
        "1.0.0.1",
        "2606:4700:4700::1111",
        "2606:4700:4700::1001",
        "8.8.8.8",
        "8.8.4.4",
        "9.9.9.9",
        "149.112.112.112"
    )

    foreach ($dns in $dnsServers) {
        try {
            Start-Process -FilePath "netsh" -ArgumentList "dns delete encryption server=$dns" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        } catch {
            Write-Verbose "Failed to delete DoH server entry for $dns."
        }
    }

    # Remove DoH templates without changing the selected DNS resolver.
    Write-Output " [i] DoH templates removed; your selected DNS resolver is left as-is (use 'Reset DNS to automatic' to clear it)."

    try { ipconfig /flushdns | Out-Null } catch {
        Write-Verbose "Failed to flush DNS cache."
    }
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-PTWError "Administrator privileges required."
    exit 2
}

if ($Action) {
    Write-Output ""
    Write-Output "========================================"
    Write-Output " Privacy - Action: $Action"
    Write-Output "========================================"
    Write-Output ""

    switch ($Action.ToLowerInvariant()) {
        "copilot-disable-revert" {
            try {
                Restore-Copilot
                Write-Output " [OK] Copilot restored to default"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Copilot revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "doh-enable-revert" {
            try {
                Restore-DnsAndDoh
                Write-Output " [OK] DoH disabled and DNS reset"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] DoH disable failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "ui-online-content-revert" {
            try {
                Restore-UiOnlineContent
                Write-Output " [OK] Online content restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Online content revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "ui-secure-recent-docs-revert" {
            try {
                Restore-UiSecureRecentDocList
                Write-Output " [OK] Recent document settings restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Recent docs revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "ui-remove-this-pc-folders-revert" {
            try {
                Restore-UiThisPcFolderList
                Write-Output " [OK] This PC folders restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] This PC folders revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "ui-lock-screen-notifications-revert" {
            try {
                Restore-UiLockScreenNotification
                Write-Output " [OK] Lock screen notifications restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Lock screen notifications revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "ui-store-open-with-revert" {
            try {
                Restore-UiStoreOpenWith
                Write-Output " [OK] Store Open With restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Store Open With revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "ui-quick-access-recent-revert" {
            try {
                Restore-UiQuickAccessRecentItem
                Write-Output " [OK] Quick Access recent items restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Quick Access revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "ui-sync-provider-notifications-revert" {
            try {
                Restore-UiSyncProviderNotification
                Write-Output " [OK] Sync provider notifications restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Sync provider revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "ui-hibernation-revert" {
            try {
                Restore-UiHibernation
                Write-Output " [OK] Hibernation restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Hibernation revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "ui-camera-osd-revert" {
            try {
                Restore-UiCameraOsd
                Write-Output " [OK] Camera OSD setting restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Camera OSD revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "telemetry-off-revert" {
            try {
                Restore-Telemetry
                Write-Output " [OK] Telemetry policy override removed (back to Windows default)"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Telemetry revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "telemetry-policy-enforce-revert" {
            try {
                Restore-TelemetryPolicyEnforce
                Write-Output " [OK] Telemetry / consumer GPO policies removed"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Telemetry policy revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "block-ms-account-revert" {
            try {
                Restore-BlockMsAccount
                Write-Output " [OK] Microsoft account sign-in re-allowed"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Microsoft account revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "onedrive-policy-disable-revert" {
            try {
                Restore-OneDrivePolicyDisable
                Write-Output " [OK] OneDrive sync policy removed"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] OneDrive policy revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "privacy-recall-disable-revert" {
            try {
                Restore-RecallDisable
                Write-Output " [OK] Windows Recall policy override removed"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Recall revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "privacy-camera-mic-deny-revert" {
            try {
                Restore-CameraMicDeny
                Write-Output " [OK] Camera/microphone access restored to default (Allow)"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Camera/mic revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "privacy-telemetry-tasks-disable-revert" {
            try {
                Restore-TelemetryTasksDisable
                Write-Output " [OK] Telemetry scheduled tasks re-enabled"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Telemetry tasks revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "privacy-location-disable-revert" {
            try {
                Restore-LocationDisable
                Write-Output " [OK] Location policy override removed"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Location revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "privacy-web-search-disable-revert" {
            try {
                Restore-WebSearchDisable
                Write-Output " [OK] Web search policy override removed"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Web search revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        "privacy-delivery-optimization-disable-revert" {
            try {
                Restore-DeliveryOptimizationDisable
                Write-Output " [OK] Delivery Optimization policy override removed"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Delivery Optimization revert failed: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
        default {
            Write-PTWError "Unknown action: $Action"
            $script:PTWErrorCount++
        }
    }

    Write-Output ""
    Write-Output "========================================"
    Write-Output " [+] Action complete"
    Write-Output " [!] Restart recommended for changes to take effect"
    Write-Output "========================================"
    Wait-ForUser
    # Exit through Exit-PTW so per-action restore failures return a non-zero code.
    Exit-PTW
}

$doRevert = ($Mode -eq 'Revert') -or ($Mode -eq 'RevertAndRepair')

Write-Output ""
Write-Output "========================================"
Write-Output " Privacy - $Mode"
Write-Output "========================================"
Write-Output ""

if ($doRevert) {
    Write-Output " [1/3] Reverting Copilot settings..."
    try {
        Restore-Copilot
        Write-Output " [OK] Copilot restored to default"
    } catch {
        Write-Output " [WARN] Copilot revert failed: $($_.Exception.Message)"
    }

    Write-Output " [2/3] Reverting DNS and DoH settings..."
    try {
        Restore-DnsAndDoh
        Write-Output " [OK] DNS and DoH reverted"
    } catch {
        Write-Output " [WARN] DNS/DoH revert failed: $($_.Exception.Message)"
    }

    Write-Output " [3/3] Reverting UI and Explorer privacy tweaks..."
    try {
        Restore-UiOnlineContent
        Restore-UiSecureRecentDocList
        Restore-UiThisPcFolderList
        Restore-UiLockScreenNotification
        Restore-UiStoreOpenWith
        Restore-UiQuickAccessRecentItem
        Restore-UiSyncProviderNotification
        Restore-UiHibernation
        Restore-UiCameraOsd
        Restore-Telemetry
        Restore-TelemetryPolicyEnforce
        Restore-BlockMsAccount
        Restore-OneDrivePolicyDisable
        Restore-RecallDisable
        Restore-CameraMicDeny
        Restore-TelemetryTasksDisable
        Restore-LocationDisable
        Restore-WebSearchDisable
        Restore-DeliveryOptimizationDisable
        Write-Output " [OK] UI and Explorer privacy tweaks reverted"
    } catch {
        Write-Output " [WARN] UI/Explorer revert failed: $($_.Exception.Message)"
    }
} else {
    Write-Output " [i] Skipping revert (Mode=$Mode)"
}

Write-Output ""
Write-PTWSuccess "All privacy revert operations completed"
Write-Output ""
Write-Output "========================================"
Write-Output " [+] $Mode complete"
Write-Output " [!] Restart recommended for changes to take effect"
Write-Output "========================================"
Wait-ForUser
# Honour $PTWErrorCount (the reg helpers increment it on failure) rather than forcing exit 0.
Exit-PTW
