# Privacy Tweaks
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
        "privacy-recall-disable",
        "privacy-camera-mic-deny",
        "privacy-telemetry-tasks-disable",
        "privacy-location-disable",
        "privacy-web-search-disable",
        "privacy-delivery-optimization-disable",
        "dns-cloudflare",
        "dns-google",
        "dns-quad9",
        "dns-reset",
        "doh-enable",
        "menu"
    )]
    [string]$Action = "Menu"
)

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
    Write-PTWLog "CommonFunctions.ps1 not found; refusing to continue" "ERROR"
    exit 1
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
            try {
                Set-DnsClientServerAddress -InterfaceAlias $adapter -ServerAddresses $Addresses -ErrorAction Stop
                # Readback: confirm the addresses actually took rather than assuming success.
                $applied = (Get-DnsClientServerAddress -InterfaceAlias $adapter -ErrorAction SilentlyContinue).ServerAddresses
                $missing = @($Addresses | Where-Object { $_ -notin $applied })
                if ($missing.Count -gt 0) {
                    Write-Output "[!] [$Label] ${adapter}: DNS readback mismatch (missing: $($missing -join ', '))"
                    $script:PTWErrorCount++
                } else {
                    Write-Output "[$Label] Applied to $adapter"
                }
            } catch {
                Write-Output "[-] [$Label] Failed to set DNS on ${adapter}: $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
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
        $proc = Start-Process -FilePath 'netsh' -ArgumentList "dns add encryption server=$($dns.Server) dohtemplate=$($dns.Template) autoupgrade=yes udpfallback=yes" -WindowStyle Hidden -PassThru -Wait
        if ($proc.ExitCode -ne 0) {
            Write-Output "[!] Failed to enable DoH for $($dns.Server) (netsh exit $($proc.ExitCode))"
            $script:PTWErrorCount++
        } else {
            Write-Output "Enabled DoH for $($dns.Server)"
        }
    }
    # Preserve a supported resolver or select Cloudflare before enabling DoH.
    $dohIps = '1.1.1.1','1.0.0.1','8.8.8.8','8.8.4.4','9.9.9.9','149.112.112.112'
    $alreadyDoh = $false
    foreach ($a in (Get-ActiveAdapter | Select-Object -ExpandProperty Name)) {
        $cur = @((Get-DnsClientServerAddress -InterfaceAlias $a -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses)
        if ($cur | Where-Object { $dohIps -contains $_ }) { $alreadyDoh = $true; break }
    }
    if (-not $alreadyDoh) {
        Set-DnsAddress -Addresses '1.1.1.1','1.0.0.1' -Label 'Cloudflare DoH (default)'
    } else {
        Write-Output '[i] An active adapter already uses a DoH-capable resolver; keeping your DNS choice (DoH still engages).'
    }
    ipconfig /flushdns | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $script:PTWErrorCount++
        Write-Output "[-] ERROR: ipconfig /flushdns returned $LASTEXITCODE"
    }
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

    # Hide Explorer folders with the documented HiddenByDefault flag.
    $nsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{$Guid}"
    if (Test-Path -LiteralPath $nsPath) {
        Set-RegValueSafe -Path $nsPath -Name 'HiddenByDefault' -Type 'DWord' -Value 1
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
    # Back up the DelegateFolders keys before the destructive (Default)-value removal.
    Backup-RegistryPath -Action $Action -Paths $delegatePaths
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
        if ($LASTEXITCODE -ne 0) {
            $script:PTWErrorCount++
            Write-Output "[-] ERROR: powercfg -h off returned $LASTEXITCODE"
        } else {
            Write-Output "[+] SUCCESS: hibernation disabled"
        }
    } catch {
        $script:PTWErrorCount++
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
    Write-Output "[!] WARNING: NoConnectedUser=3 blocks adding OR using a Microsoft account on this PC. This breaks Microsoft Store purchases, OneDrive, Copilot and Office sign-in. Restore Default removes the block."
    Set-RegDword -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'NoConnectedUser' -Value 3
    Write-Output "[+] SUCCESS: Microsoft account sign-in blocked"
}

function Invoke-OneDrivePolicyDisable {
    Write-Output "[*] Disabling OneDrive file sync via policy (durable across reinstall)..."
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Name 'DisableFileSyncNGSC' -Value 1
    Write-Output "[+] SUCCESS: OneDrive sync disabled via policy"
}

function Invoke-RecallDisable {
    Write-Output "[*] Suppressing Windows Recall / AI data analysis natively (independent of the O&O ShutUp10 profile)..."
    # Disable Recall through machine, user, and CSP-equivalent policy values.
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableAIDataAnalysis' -Value 1
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'AllowRecallEnablement' -Value 0
    Set-RegDword -Path 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableAIDataAnalysis' -Value 1
    Write-Output "[+] SUCCESS: Windows Recall suppressed via native policy"
}

function Invoke-CameraMicDeny {
    Write-Output "[*] Denying app access to the camera and microphone (the two sensors the privacy batch leaves on)..."
    Write-Output "[!] WARNING: this is a system-wide app deny. Camera/microphone apps (Teams, Zoom, Camera) will be blocked until you use Restore Default or re-allow them per-app in Settings > Privacy."
    # Per-app consent store: flip the global default for webcam + microphone from Allow to Deny.
    Set-RegSz -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam' -Name 'Value' -Value 'Deny'
    Set-RegSz -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone' -Name 'Value' -Value 'Deny'
    # Policy form (Force Deny = 2) so the deny is GPO-enforced too.
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Name 'LetAppsAccessCamera' -Value 2
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Name 'LetAppsAccessMicrophone' -Value 2
    Write-Output "[+] SUCCESS: camera and microphone app access denied"
}

# Disable telemetry tasks without deleting them so Restore Default can re-enable them.
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

function Invoke-TelemetryTasksDisable {
    Write-Output "[*] Disabling telemetry / CEIP / feedback scheduled tasks..."
    foreach ($t in $script:PtwTelemetryTasks) {
        try {
            $task = Get-ScheduledTask -TaskPath $t.Path -TaskName $t.Name -ErrorAction SilentlyContinue
            if ($task) {
                Disable-ScheduledTask -TaskPath $t.Path -TaskName $t.Name -ErrorAction Stop | Out-Null
                Write-Output "  [OK] Disabled $($t.Path)$($t.Name)"
            }
        } catch {
            Write-Output "  [!] Could not disable $($t.Name): $($_.Exception.Message)"
            $script:PTWErrorCount++
        }
    }
    Write-Output "[+] SUCCESS: telemetry scheduled tasks disabled"
}

function Invoke-LocationDisable {
    Write-Output "[*] Disabling the Windows location platform via policy..."
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocation' -Value 1
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocationScripting' -Value 1
    Write-Output "[+] SUCCESS: location services disabled by policy"
}

function Invoke-WebSearchDisable {
    Write-Output "[*] Disabling web/Bing results and suggestions in Start/Search..."
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'DisableWebSearch' -Value 1
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'ConnectedSearchUseWeb' -Value 0
    Set-RegDword -Path 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 1
    Write-Output "[+] SUCCESS: web search results disabled"
}

function Invoke-DeliveryOptimizationDisable {
    Write-Output "[*] Restricting Delivery Optimization to HTTP-only (no peer-to-peer upload/download)..."
    Set-RegDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Name 'DODownloadMode' -Value 0
    Write-Output "[+] SUCCESS: Delivery Optimization peer sharing disabled"
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
        if (-not (Test-PtwFileChecksum -Path $configPath)) {
            Write-Output "[-] ERROR: O&O config file failed its integrity check."
            exit 1
        }

        $oosuExe = Get-PTWRuntimePath "OOSU10.exe"
        Remove-Item -Path $oosuExe -Force -ErrorAction SilentlyContinue
        Write-Output "[*] Downloading OOSU10.exe..."
        Get-FileFromWeb -URL "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe" -File $oosuExe

        # Dynamic-hash download — verify Authenticode before executing as admin
        Test-SignedFile -Path $oosuExe -PublisherPatterns @('O&O Software GmbH')

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
        # Keep the toggle reversible by changing policy without uninstalling Copilot.
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
        # Set the lowest supported telemetry level without changing SmartScreen or Defender reporting.
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

    "privacy-recall-disable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI',
            'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
        )
        Invoke-RecallDisable
        Exit-PTW
    }

    "privacy-camera-mic-deny" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'
        )
        Invoke-CameraMicDeny
        Exit-PTW
    }

    "privacy-telemetry-tasks-disable" {
        Invoke-TelemetryTasksDisable
        Exit-PTW
    }

    "privacy-location-disable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'
        )
        Invoke-LocationDisable
        Exit-PTW
    }

    "privacy-web-search-disable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search',
            'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
        )
        Invoke-WebSearchDisable
        Exit-PTW
    }

    "privacy-delivery-optimization-disable" {
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
        )
        Invoke-DeliveryOptimizationDisable
        Exit-PTW
    }

    "dns-cloudflare" {
        Write-Output "[*] Setting Cloudflare DNS..."
        Set-DnsAddress -Addresses "1.1.1.1","1.0.0.1" -Label "Cloudflare DNS"
        Write-Output "[+] SUCCESS: Cloudflare DNS applied"
        Exit-PTW
    }

    "dns-quad9" {
        Write-Output "[*] Setting Quad9 DNS (malware-blocking resolver)..."
        Set-DnsAddress -Addresses "9.9.9.9","149.112.112.112" -Label "Quad9 DNS"
        Write-Output "[+] SUCCESS: Quad9 DNS applied"
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
        if ($LASTEXITCODE -ne 0) {
            $script:PTWErrorCount++
            Write-Output "[-] ERROR: ipconfig /flushdns returned $LASTEXITCODE"
        }
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
        Write-Output "[i] No interactive menu - use the PleaseTweakWindows app to select tweaks"
        Exit-PTW
    }

    default {
        Write-Error "Unknown action: $Action"
        exit 1
    }
}
