# Privacy Revert Script
# Purpose: Restores privacy settings to defaults.
# Usage: powershell -File revert-privacy.ps1 -Mode <Revert|Repair|RevertAndRepair>
# Version: 2.1.0
# Last Updated: 2026-01-21
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
    Write-Output "[!] CommonFunctions.ps1 not found - some features may not work"
}

function Restore-ExplorerFolder {
    param(
        [Parameter(Mandatory)][string]$FolderName,
        [Parameter(Mandatory)][string]$Guid,
        [Parameter(Mandatory)][int]$Build
    )
    Write-Output " [*] Restoring '$FolderName' in This PC..."

    $paths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{$Guid}\PropertyBag",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{$Guid}\PropertyBag"
    )
    foreach ($path in $paths) {
        Set-RegValueSafe -Path $path -Name 'ThisPCPolicy' -Type 'String' -Value 'Show'
    }

    Remove-RegValueSafe -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideMyComputerIcons' -Name "{$Guid}"

    $nsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{$Guid}"
    if (-not (Test-Path -LiteralPath $nsPath)) {
        New-Item -Path $nsPath -Force | Out-Null
    }

    if ($Build -ge 22000) {
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

    $build = [Environment]::OSVersion.Version.Build
    foreach ($name in $folders.Keys) {
        Restore-ExplorerFolder -FolderName $name -Guid $folders[$name] -Build $build
    }

    if ($build -lt 22000) {
        $legacyGuids = @(
            'A8CDFF1C-4878-43be-B5FD-F8091C1C60D0',
            'd3162b92-9365-467a-956b-92703aca08af',
            '088e3905-0323-4b02-9826-5d99428e115f',
            '374DE290-123F-4565-9164-39C4925E467B',
            '3dfdf296-dbec-4fb4-81d1-6a3438bcf4de',
            '1CF1260C-4DD0-4ebb-811F-33C572699FDE',
            '24ad3ad4-a569-4530-98e1-ab02f9417aa8',
            '3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA',
            'f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a',
            'A0953C92-50DC-43bf-BE83-3742FED03C9C',
            '0DB7E03F-FC29-4DC6-9020-FF41B59E513A'
        )
        foreach ($guid in $legacyGuids) {
            $nsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{$guid}"
            if (-not (Test-Path -LiteralPath $nsPath)) {
                New-Item -Path $nsPath -Force | Out-Null
            }
        }
    }
}

function Restore-UiLockScreenNotification {
    Remove-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'DisableLockScreenAppNotifications'
}

function Restore-UiLiveTile {
    Remove-RegValueSafe -Path 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications' -Name 'NoTileApplicationNotification'
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

function Restore-UiAppUsageTracking {
    Remove-RegValueSafe -Path 'HKCU:\Software\Policies\Microsoft\Windows\EdgeUI' -Name 'DisableMFUTracking'
}

function Restore-UiRecentApp {
    Remove-RegValueSafe -Path 'HKCU:\Software\Policies\Microsoft\Windows\EdgeUI' -Name 'DisableRecentApps'
}

function Restore-UiBacktracking {
    Remove-RegValueSafe -Path 'HKCU:\Software\Policies\Microsoft\Windows\EdgeUI' -Name 'TurnOffBackstack'
}

function Restore-Copilot {
    $progressPreference = 'SilentlyContinue'
    Get-AppXPackage -AllUsers *Microsoft.Windows.Ai.Copilot.Provider* | ForEach-Object { Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue }
    Get-AppXPackage -AllUsers *Microsoft.Copilot* | ForEach-Object { Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue }
    Remove-RegKey -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
    Remove-RegKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
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

    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notlike '*Virtual*' -and $_.Name -notlike '*vEthernet*' }
    foreach ($adapter in $adapters) {
        try {
            Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ResetServerAddresses -ErrorAction Stop
            Write-Output " [OK] DNS reset to automatic on: $($adapter.Name)"
        } catch {
            Write-Output " [WARN] Could not reset DNS on: $($adapter.Name)"
        }
    }

    try { ipconfig /flushdns | Out-Null } catch {
        Write-Verbose "Failed to flush DNS cache."
    }
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-PTWError "Administrator privileges required."
    $global:LASTEXITCODE = 2
    return
}

if ($Action) {
    Write-Output ""
    Write-Output "========================================"
    Write-Output " Privacy - Action: $Action"
    Write-Output "========================================"
    Write-Output ""

    switch ($Action.ToLowerInvariant()) {
        "copilot-enable" {
            try {
                Restore-Copilot
                Write-Output " [OK] Copilot restored to default"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Copilot revert failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        "dns-default" {
            try {
                Restore-DnsAndDoh
                Write-Output " [OK] DNS and DoH reverted"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] DNS/DoH revert failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        "doh-disable" {
            try {
                Restore-DnsAndDoh
                Write-Output " [OK] DoH disabled and DNS reset"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] DoH disable failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        "ui-online-content-revert" {
            try {
                Restore-UiOnlineContent
                Write-Output " [OK] Online content restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Online content revert failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        "ui-secure-recent-docs-revert" {
            try {
                Restore-UiSecureRecentDocList
                Write-Output " [OK] Recent document settings restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Recent docs revert failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        "ui-remove-this-pc-folders-revert" {
            try {
                Restore-UiThisPcFolderList
                Write-Output " [OK] This PC folders restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] This PC folders revert failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        "ui-lock-screen-notifications-revert" {
            try {
                Restore-UiLockScreenNotification
                Write-Output " [OK] Lock screen notifications restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Lock screen notifications revert failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        "ui-live-tiles-revert" {
            try {
                Restore-UiLiveTile
                Write-Output " [OK] Live Tiles notifications restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Live Tiles revert failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        "ui-store-open-with-revert" {
            try {
                Restore-UiStoreOpenWith
                Write-Output " [OK] Store Open With restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Store Open With revert failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        "ui-quick-access-recent-revert" {
            try {
                Restore-UiQuickAccessRecentItem
                Write-Output " [OK] Quick Access recent items restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Quick Access revert failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        "ui-sync-provider-notifications-revert" {
            try {
                Restore-UiSyncProviderNotification
                Write-Output " [OK] Sync provider notifications restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Sync provider revert failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        "ui-hibernation-revert" {
            try {
                Restore-UiHibernation
                Write-Output " [OK] Hibernation restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Hibernation revert failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        "ui-camera-osd-revert" {
            try {
                Restore-UiCameraOsd
                Write-Output " [OK] Camera OSD setting restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Camera OSD revert failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        "ui-app-usage-tracking-revert" {
            try {
                Restore-UiAppUsageTracking
                Write-Output " [OK] App usage tracking restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] App usage tracking revert failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        "ui-recent-apps-revert" {
            try {
                Restore-UiRecentApp
                Write-Output " [OK] Recent apps restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Recent apps revert failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        "ui-backtracking-revert" {
            try {
                Restore-UiBacktracking
                Write-Output " [OK] Backtracking restored"
                $global:LASTEXITCODE = 0
            } catch {
                Write-Output " [WARN] Backtracking revert failed: $($_.Exception.Message)"
                $global:LASTEXITCODE = 1
            }
        }
        default {
            Write-PTWError "Unknown action: $Action"
            $global:LASTEXITCODE = 1
        }
    }

    Write-Output ""
    Write-Output "========================================"
    Write-Output " [+] Action complete"
    Write-Output " [!] Restart recommended for changes to take effect"
    Write-Output "========================================"
    Wait-ForUser
    return
}

$doRevert = ($Mode -eq 'Revert') -or ($Mode -eq 'RevertAndRepair')
$doRepair = ($Mode -eq 'Repair') -or ($Mode -eq 'RevertAndRepair')

Write-Output ""
Write-Output "========================================"
Write-Output " Privacy - $Mode"
Write-Output "========================================"
Write-Output ""

if ($doRevert -or $doRepair) {
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
        Restore-UiLiveTile
        Restore-UiStoreOpenWith
        Restore-UiQuickAccessRecentItem
        Restore-UiSyncProviderNotification
        Restore-UiHibernation
        Restore-UiCameraOsd
        Restore-UiAppUsageTracking
        Restore-UiRecentApp
        Restore-UiBacktracking
        Write-Output " [OK] UI and Explorer privacy tweaks reverted"
    } catch {
        Write-Output " [WARN] UI/Explorer revert failed: $($_.Exception.Message)"
    }

}

Write-Output ""
Write-PTWSuccess "All privacy revert operations completed"
Write-Output ""
Write-Output "========================================"
Write-Output " [+] $Mode complete"
Write-Output " [!] Restart recommended for changes to take effect"
Write-Output "========================================"
Wait-ForUser
$global:LASTEXITCODE = 0
return
