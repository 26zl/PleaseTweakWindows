# Privacy Tweaks
# Purpose: Non-interactive action dispatcher.
# Usage: powershell -File privacy.ps1 -Action "<action-id>"
# Version: 2.1.0
# Last Updated: 2026-01-21
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "ooshutup-apply",
        "ui-online-content-disable",
        "ui-secure-recent-docs",
        "ui-remove-this-pc-folders",
        "ui-lock-screen-notifications-disable",
        "ui-store-open-with-disable",
        "ui-quick-access-recent-disable",
        "ui-sync-provider-notifications-disable",
        "ui-hibernation-disable",
        "ui-camera-osd-enable",
        "copilot-disable",
        "telemetry-off",
        "telemetry-policy-enforce",
        "block-ms-account",
        "onedrive-policy-disable",
        "dns-cloudflare",
        "dns-google",
        "dns-reset",
        "doh-enable",
        "menu"
    )]
    [string]$Action = "Menu"
)

$script:ScriptVersion = "2.1.0"

function Write-PTWLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) { "INFO" { "[*]" } "SUCCESS" { "[+]" } "WARNING" { "[!]" } "ERROR" { "[-]" } default { "[*]" } }
    Write-Output "$timestamp $prefix $Message"
}

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

function Set-DnsAddress {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string[]]$Addresses,
        [string]$Label = 'Custom DNS'
    )
    $adapters = Get-ActiveAdapter | Select-Object -ExpandProperty Name
    if (-not $adapters) {
        Write-Output 'No active adapters found.'
        return
    }
    foreach ($adapter in $adapters) {
        if ($PSCmdlet.ShouldProcess($adapter, "Set DNS servers ($Label)")) {
            Set-DnsClientServerAddress -InterfaceAlias $adapter -ServerAddresses $Addresses -ErrorAction SilentlyContinue
            Write-Output "[$Label] Applied to $adapter"
        }
    }
}

function Enable-AllDoh {
    $dnsServers = @(
        @{ Server = '1.1.1.1'; Template = 'https://cloudflare-dns.com/dns-query' },
        @{ Server = '1.0.0.1'; Template = 'https://cloudflare-dns.com/dns-query' },
        @{ Server = '8.8.8.8'; Template = 'https://dns.google/dns-query' },
        @{ Server = '8.8.4.4'; Template = 'https://dns.google/dns-query' },
        @{ Server = '9.9.9.9'; Template = 'https://dns.quad9.net/dns-query' }
    )
    foreach ($dns in $dnsServers) {
        Start-Process -FilePath 'netsh' -ArgumentList "dns add encryption server=$($dns.Server) dohtemplate=$($dns.Template) autoupgrade=yes udpfallback=yes" -WindowStyle Hidden -Wait
        Write-Output "Enabled DoH for $($dns.Server)"
    }
    # Registering DoH templates alone does nothing unless an adapter actually
    # uses one of these resolver IPs. Point active adapters at Cloudflare (a
    # registered DoH-capable resolver) so DoH truly engages instead of being an
    # inert no-op on machines using router/DHCP DNS.
    Set-DnsAddress -Addresses '1.1.1.1','1.0.0.1' -Label 'Cloudflare DoH'
    ipconfig /flushdns | Out-Null
}

function Hide-ExplorerFolder {
    param(
        [Parameter(Mandatory)][string]$FolderName,
        [Parameter(Mandatory)][string]$Guid
    )
    Write-Output "[*] Hiding '$FolderName' from This PC..."

    # Hide via FolderDescriptions property bag (64-bit + WoW64).
    $paths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{$Guid}\PropertyBag",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{$Guid}\PropertyBag"
    )
    foreach ($path in $paths) {
        Set-RegValueSafe -Path $path -Name 'ThisPCPolicy' -Type 'String' -Value 'Hide'
    }

    # Per-user hide in This PC.
    Set-RegValueSafe -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideMyComputerIcons' -Name "{$Guid}" -Type 'DWord' -Value 1

    $build = [Environment]::OSVersion.Version.Build
    $nsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{$Guid}"
    if ($build -lt 22000) {
        # Windows 10 and earlier: remove the NameSpace key.
        Remove-RegKeySafe -Path $nsPath
    } else {
        # Windows 11+: hide via documented flag. Previously also wrote HideIfEnabled with
        # an undocumented magic bitmask (0x022AB9B9) that re-interprets across builds —
        # HiddenByDefault=1 alone is the supported mechanism.
        if (Test-Path -LiteralPath $nsPath) {
            Set-RegValueSafe -Path $nsPath -Name 'HiddenByDefault' -Type 'DWord' -Value 1
        }
    }
}

function Invoke-UiOnlineContentDisable {
    Write-Output "[*] Disabling online content in File Explorer..."

    $regSets = @(
        # Disable online tips.
        [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'AllowOnlineTips'; Type = 'DWord'; Value = 0 },
        # Disable Internet file association service.
        [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoInternetOpenWith'; Type = 'DWord'; Value = 1 },
        # Disable Order Prints wizard.
        [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoOnlinePrintsWizard'; Type = 'DWord'; Value = 1 },
        # Disable Publish to Web wizard.
        [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoPublishingWizard'; Type = 'DWord'; Value = 1 },
        # Disable provider list downloads.
        [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoWebServices'; Type = 'DWord'; Value = 1 }
    )

    foreach ($r in $regSets) {
        Set-RegValueSafe -Path $r.Path -Name $r.Name -Type $r.Type -Value $r.Value
    }

    Write-Output "[+] SUCCESS: online content disabled"
}

function Invoke-UiSecureRecentDocList {
    Write-Output "[*] Securing recent document lists..."

    # Disable recent documents history.
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoRecentDocsHistory' -Type 'DWord' -Value 1
    # Clear recent documents on exit.
    Set-RegValueSafe -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'ClearRecentDocsOnExit' -Type 'DWord' -Value 1

    Write-Output "[+] SUCCESS: recent document lists secured"
}

function Invoke-UiRemoveThisPcFolderList {
    Write-Output "[*] Removing folders from This PC..."

    # Hide standard folders in "This PC".
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
        Hide-ExplorerFolder -FolderName $name -Guid $folders[$name]
    }

    # Remove legacy NameSpace keys on Windows 10 and earlier.
    $build = [Environment]::OSVersion.Version.Build
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
            Remove-RegKeySafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{$guid}"
        }
    }

    Write-Output "[+] SUCCESS: This PC folders hidden"
}

function Invoke-UiLockScreenNotificationsDisable {
    Write-Output "[*] Disabling lock screen app notifications..."

    # Disable lock screen notifications.
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'DisableLockScreenAppNotifications' -Type 'DWord' -Value 1

    Write-Output "[+] SUCCESS: lock screen notifications disabled"
}

function Invoke-UiStoreOpenWithDisable {
    Write-Output "[*] Disabling 'Look for app in the Store'..."

    # Disable "Look for app in Store".
    Set-RegValueSafe -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'NoUseStoreOpenWith' -Type 'DWord' -Value 1

    Write-Output "[+] SUCCESS: Store Open With disabled"
}

function Invoke-UiQuickAccessRecentDisable {
    Write-Output "[*] Disabling recent files in Quick Access..."

    # Disable recent files in Quick Access.
    Set-RegValueSafe -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' -Name 'ShowRecent' -Type 'DWord' -Value 0

    # Remove DelegateFolder for Recent Files (Standard & WoW64).
    $delegateGuid = '{3134ef9c-6b18-4996-ad04-ed5912e00eb5}'
    $delegatePaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HomeFolderDesktop\NameSpace\DelegateFolders\$delegateGuid",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\HomeFolderDesktop\NameSpace\DelegateFolders\$delegateGuid"
    )
    foreach ($path in $delegatePaths) {
        Remove-RegValueSafe -Path $path -Name '(Default)'
    }

    Write-Output "[+] SUCCESS: Quick Access recent items disabled"
}

function Invoke-UiSyncProviderNotificationsDisable {
    Write-Output "[*] Disabling sync provider notifications..."

    # Disable Sync Provider notifications.
    Set-RegValueSafe -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowSyncProviderNotifications' -Type 'DWord' -Value 0

    Write-Output "[+] SUCCESS: sync provider notifications disabled"
}

function Invoke-UiHibernationDisable {
    Write-Output "[*] Disabling hibernation..."

    try {
        powercfg -h off | Out-Null
        Write-Output "[+] SUCCESS: hibernation disabled"
    } catch {
        Write-Warning "[WARN] Failed to disable hibernation: $($_.Exception.Message)"
    }
}

function Invoke-UiCameraOsdEnable {
    Write-Output "[*] Enabling camera on/off OSD notifications..."

    # Enable camera on/off OSD notification.
    Set-RegValueSafe -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoPhysicalCameraLED' -Type 'DWord' -Value 1

    Write-Output "[+] SUCCESS: camera OSD notifications enabled"
}

function Invoke-TelemetryPolicyEnforce {
    Write-Output "[*] Enforcing telemetry / consumer-content GPO policies..."
    # Consumer content / tailored experiences.
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableConsumerAccountStateContent' -Value 1
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableTailoredExperiencesWithDiagnosticData' -Value 1
    # Application Impact Telemetry (AIT).
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' -Name 'AITEnable' -Value 0
    # Customer Experience Improvement Program (CEIP).
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows' -Name 'CEIPEnable' -Value 0
    # Help Experience Improvement / implicit feedback.
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Assistance\Client\1.0' -Name 'NoImplicitFeedback' -Value 1
    # Diagnostic data collection policy.
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'DoNotShowFeedbackNotifications' -Value 1
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowDeviceNameInTelemetry' -Value 0
    # Advertising ID.
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' -Name 'DisabledByGroupPolicy' -Value 1
    Write-Output "[+] SUCCESS: telemetry / consumer GPO policies enforced"
}

function Invoke-BlockMsAccount {
    Write-Output "[*] Blocking Microsoft account sign-in..."
    Write-Output "[!] WARNING: NoConnectedUser=3 blocks adding OR using a Microsoft account on this PC. This breaks Microsoft Store purchases, OneDrive, Copilot and Office sign-in. Revert removes the block."
    Set-RegDword -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'NoConnectedUser' -Value 3
    Write-Output "[+] SUCCESS: Microsoft account sign-in blocked"
}

function Invoke-OneDrivePolicyDisable {
    Write-Output "[*] Disabling OneDrive file sync via policy (durable across reinstall)..."
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Name 'DisableFileSyncNGSC' -Value 1
    Write-Output "[+] SUCCESS: OneDrive sync disabled via policy"
}

switch ($Action.ToLowerInvariant()) {
    "ooshutup-apply" {
        Write-Output "[*] Applying O&O ShutUp10++ Profile..."
        $configPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "regs") -ChildPath "ooshutup10.cfg"

        if (-not (Test-Path $configPath)) {
            Write-Output "[-] ERROR: O&O config file not found."
            Write-Output "    Expected: $configPath"
            exit 1
        }

        # Download to the ACL-restricted per-user script dir (not world-writable
        # $env:TEMP) and always fetch a fresh copy so a pre-placed binary cannot
        # be reused. Authenticode is still re-verified below before execution.
        $oosuExe = Join-Path $PSScriptRoot "OOSU10.exe"
        Remove-Item -Path $oosuExe -Force -ErrorAction SilentlyContinue
        Write-Output "[*] Downloading OOSU10.exe..."
        Get-FileFromWeb -URL "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe" -File $oosuExe

        # Dynamic-hash download — verify Authenticode before executing as admin
        Test-SignedFile -Path $oosuExe -PublisherPatterns @('O&O Software', 'OO Software')

        & $oosuExe $configPath /quiet
        if ($LASTEXITCODE -ne 0) {
            Write-Output "[-] ERROR: OOSU10 returned $LASTEXITCODE"
            exit 1
        }
        Write-Output "[+] SUCCESS: OOSU10 profile applied"
        Exit-PTW
    }

    "ui-online-content-disable" {
        Invoke-UiOnlineContentDisable
        Exit-PTW
    }

    "ui-secure-recent-docs" {
        Invoke-UiSecureRecentDocList
        Exit-PTW
    }

    "ui-remove-this-pc-folders" {
        Invoke-UiRemoveThisPcFolderList
        Exit-PTW
    }

    "ui-lock-screen-notifications-disable" {
        Invoke-UiLockScreenNotificationsDisable
        Exit-PTW
    }

    "ui-store-open-with-disable" {
        Invoke-UiStoreOpenWithDisable
        Exit-PTW
    }

    "ui-quick-access-recent-disable" {
        Invoke-UiQuickAccessRecentDisable
        Exit-PTW
    }

    "ui-sync-provider-notifications-disable" {
        Invoke-UiSyncProviderNotificationsDisable
        Exit-PTW
    }

    "ui-hibernation-disable" {
        Invoke-UiHibernationDisable
        Exit-PTW
    }

    "ui-camera-osd-enable" {
        Invoke-UiCameraOsdEnable
        Exit-PTW
    }

    "copilot-disable" {
        Write-Output "[*] Disabling Copilot..."
        $ProgressPreference = 'SilentlyContinue'
        # Policy-only disable so the toggle is genuinely reversible. We do NOT
        # uninstall the Copilot Appx packages (Remove-AppxPackage deletes the
        # install location and cannot be undone by the revert), and we no longer
        # kill the unrelated OneDrive/Widgets processes.
        Set-RegDword -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1
        Set-RegDword -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1
        Write-Output "[+] SUCCESS: Copilot disabled (restart recommended)"
        Exit-PTW
    }

    "telemetry-off" {
        Write-Output "[*] Disabling Windows telemetry/diagnostic data collection..."
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
        )
        # Policy value; on Pro/Enterprise this caps telemetry at Security (0), on Home it is
        # honoured as the lowest selectable level. SmartScreen/Defender reporting is untouched.
        Set-RegDword -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
        Set-RegDword -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0
        Write-Output "[+] SUCCESS: telemetry minimized"
        Exit-PTW
    }

    "telemetry-policy-enforce" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat',
            'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows',
            'HKLM:\SOFTWARE\Policies\Microsoft\Assistance\Client\1.0',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'
        )
        Invoke-TelemetryPolicyEnforce
        Exit-PTW
    }

    "block-ms-account" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        )
        Invoke-BlockMsAccount
        Exit-PTW
    }

    "onedrive-policy-disable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'
        )
        Invoke-OneDrivePolicyDisable
        Exit-PTW
    }

    "dns-cloudflare" {
        Write-Output "[*] Setting Cloudflare DNS..."
        Set-DnsAddress -Addresses "1.1.1.1","1.0.0.1" -Label "Cloudflare DNS"
        Write-Output "[+] SUCCESS: Cloudflare DNS applied"
        Exit-PTW
    }

    "dns-google" {
        Write-Output "[*] Setting Google DNS..."
        Set-DnsAddress -Addresses "8.8.8.8","8.8.4.4" -Label "Google DNS"
        Write-Output "[+] SUCCESS: Google DNS applied"
        Exit-PTW
    }

    "dns-reset" {
        Write-Output "[*] Resetting DNS to automatic (DHCP)..."
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notlike '*Virtual*' -and $_.Name -notlike '*vEthernet*' }
        if (-not $adapters) {
            Write-Output "[!] No active adapters found."
        }
        foreach ($adapter in $adapters) {
            try {
                Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ResetServerAddresses -ErrorAction Stop
                Write-Output " [OK] DNS reset to automatic on: $($adapter.Name)"
            } catch {
                Write-Output " [WARN] Could not reset DNS on: $($adapter.Name)"
            }
        }
        ipconfig /flushdns | Out-Null
        Write-Output "[+] SUCCESS: DNS reset to automatic"
        Exit-PTW
    }

    "doh-enable" {
        Write-Output "[*] Enabling DNS over HTTPS..."
        Enable-AllDoh
        Write-Output "[+] SUCCESS: DoH enabled"
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
