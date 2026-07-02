# Network Optimizations
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "adapter-ipv4only",
        "adapter-default",
        "smart-optimize",
        "smart-optimize-aggressive",
        "smart-optimize-revert",
        "menu"
    )]
    [string]$Action = "Menu"
)

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
    Write-PTWLog "CommonFunctions.ps1 not found; refusing to continue" "ERROR"
    exit 1
}

#region Helper Functions

function Get-PTWNicBackupDir {
    $backupDir = Get-PTWStatePath 'nic-backups'
    if (-not (Test-Path $backupDir)) {
        try { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        catch { Write-Output "[!] Could not create NIC backup dir ${backupDir}: $($_.Exception.Message)"; return $null }
    }
    return $backupDir
}

function Set-AdapterBinding {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [ValidateSet("IPv4Only","Default")]
        [string]$Mode
    )

    $adapters = Get-ActiveAdapter | Select-Object -ExpandProperty Name
    if (-not $adapters) {
        Write-Warning "No active adapters found."
        return
    }

    $bindingPlan = @{
        IPv4Only = @{
            Enable  = @("ms_tcpip")
            Disable = @("ms_lldp","ms_lltdio","ms_implat","ms_rspndr","ms_tcpip6","ms_server","ms_msclient","ms_pacer")
        }
        Default = @{
            Enable  = @("ms_lldp","ms_lltdio","ms_implat","ms_tcpip","ms_rspndr","ms_tcpip6","ms_server","ms_msclient","ms_pacer")
            Disable = @()
        }
    }[$Mode]

    $failed = 0
    foreach ($adapter in $adapters) {
        if ($PSCmdlet.ShouldProcess($adapter, "Apply adapter bindings: $Mode")) {
            foreach ($id in $bindingPlan.Enable) {
                try { Enable-NetAdapterBinding -Name $adapter -ComponentID $id -ErrorAction Stop }
                catch {
                    # Ignore components that do not apply to the adapter type.
                    $b = Get-NetAdapterBinding -Name $adapter -ComponentID $id -ErrorAction SilentlyContinue
                    if ($null -ne $b -and -not $b.Enabled) {
                        $failed++; Write-Output "[!] Could not enable binding '$id' on '$adapter': $($_.Exception.Message)"
                    }
                }
            }
            foreach ($id in $bindingPlan.Disable) {
                try { Disable-NetAdapterBinding -Name $adapter -ComponentID $id -ErrorAction Stop }
                catch {
                    $b = Get-NetAdapterBinding -Name $adapter -ComponentID $id -ErrorAction SilentlyContinue
                    if ($null -ne $b -and $b.Enabled) {
                        $failed++; Write-Output "[!] Could not disable binding '$id' on '$adapter': $($_.Exception.Message)"
                    }
                }
            }
        }
    }
    if ($failed -gt 0) {
        Write-Output "[!] Network adapter bindings set to $Mode on $($adapters.Count) adapter(s), but $failed change(s) failed."
        $script:PTWErrorCount++
    } else {
        Write-Output "Network Adapter bindings set to $Mode on $($adapters.Count) adapter(s)."
    }
}

function Invoke-SmartNetworkOptimization {
    param([switch]$Aggressive)
    Write-Output "[*] Starting Smart Network Optimization..."
    $aggressiveEnabled = $Aggressive -or ($env:PTW_NET_AGGRESSIVE -eq '1')
    if ($aggressiveEnabled) {
        Write-Output "[!] Aggressive adapter tweaks enabled (Flow Control, Jumbo Frames, Interrupt Moderation)"
        Write-Output "[!] WARNING: Disabling Flow Control can cause packet loss/throughput drops on some NICs and"
        Write-Output "    switches, and forcing Interrupt Moderation changes latency behaviour. Original adapter"
        Write-Output "    values are snapshotted and can be restored with Restore Smart Network Defaults."
    } else {
        Write-Output "[i] Aggressive adapter tweaks disabled by default."
        Write-Output "    Set PTW_NET_AGGRESSIVE=1 or use smart-optimize-aggressive to enable them."
    }

    # Registry Fixes
    Write-Output "[*] Applying Registry Tweaks..."
    $RegKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    $errorsBeforeRegistry = $script:PTWErrorCount
    try {
        Set-RegDword -Path $RegKey -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF
        Set-RegDword -Path $RegKey -Name "SystemResponsiveness" -Value 0
        if ($script:PTWErrorCount -eq $errorsBeforeRegistry) {
            Write-Output "[+] Network Throttling Removed"
        } else {
            Write-Output "[-] One or more network throttling values could not be applied"
        }
        Write-Output "[!] NOTE: NetworkThrottlingIndex is fully disabled and SystemResponsiveness is set to 0."
        Write-Output "    This favours raw network throughput over multimedia and removes the MMCSS CPU reserve"
        Write-Output "    that protects audio/video; some systems may see audio glitches/stutter under heavy"
        Write-Output "    network load. Restore Smart Network Defaults restores NetworkThrottlingIndex=10,"
        Write-Output "    SystemResponsiveness=20)."
    } catch {
        Write-Output "[-] Could not remove throttling: $($_.Exception.Message)"
        $script:PTWErrorCount++
    }

    # Snapshot adapter state so the restore action can reconstruct driver settings.
    $nicSnapshot = @()

    # Driver Tweaks
    Write-Output "[*] Scanning Network Adapters for Power Saving features..."
    $Adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }

    if (!$Adapters) {
        Write-Warning "No active physical adapters found."
        $script:PTWErrorCount++
    } else {
        foreach ($Adapter in $Adapters) {
            Write-Output "  Processing: $($Adapter.InterfaceDescription)"

            # Record that we are disabling power management so revert can re-enable it.
            $nicSnapshot += [PSCustomObject]@{
                Adapter         = $Adapter.Name
                Type            = "PowerManagement"
                RegistryKeyword = ""
                DisplayName     = ""
                DisplayValue    = "Enabled"
            }
            try {
                $Adapter | Disable-NetAdapterPowerManagement -ErrorAction Stop
                Write-Output "    - Windows Power Saving: Disabled"
            } catch {
                Write-Output "    - Could not disable power management"
                $script:PTWErrorCount++
            }

            $AdvancedProperties = Get-NetAdapterAdvancedProperty -Name $Adapter.Name -ErrorAction SilentlyContinue
            $BadKeywords = @("Green", "Energy", "Power", "EEE", "Eco", "Sleep", "Wake")
            if ($aggressiveEnabled) {
                $BadKeywords += @("Flow Control", "Jumbo")
            }

            foreach ($Prop in $AdvancedProperties) {
                $IsBadFeature = $false
                foreach ($Key in $BadKeywords) {
                    if ($Prop.DisplayName -match $Key) { $IsBadFeature = $true; break }
                }

                if ($IsBadFeature) {
                    $ValidValues = $Prop.ValidDisplayValues
                    $TargetValue = $null
                    if ($ValidValues -contains "Disabled") { $TargetValue = "Disabled" }
                    elseif ($ValidValues -contains "Off") { $TargetValue = "Off" }
                    elseif ($ValidValues -contains "0") { $TargetValue = "0" }

                    if ($null -ne $TargetValue -and $Prop.DisplayValue -ne $TargetValue) {
                        try {
                            $nicSnapshot += [PSCustomObject]@{
                                Adapter         = $Adapter.Name
                                Type            = "AdvancedProperty"
                                RegistryKeyword = $Prop.RegistryKeyword
                                DisplayName     = $Prop.DisplayName
                                DisplayValue    = $Prop.DisplayValue
                            }
                            Set-NetAdapterAdvancedProperty -Name $Adapter.Name -DisplayName $Prop.DisplayName -DisplayValue $TargetValue -ErrorAction Stop
                            Write-Output "    - Optimized: '$($Prop.DisplayName)' -> $TargetValue"
                        } catch {
                            Write-Output "    - Could not set '$($Prop.DisplayName)': $($_.Exception.Message)"
                            $script:PTWErrorCount++
                        }
                    }
                }

                if ($aggressiveEnabled -and $Prop.DisplayName -match "Interrupt Moderation" -and $Prop.DisplayValue -ne "Enabled") {
                    $nicSnapshot += [PSCustomObject]@{
                        Adapter         = $Adapter.Name
                        Type            = "AdvancedProperty"
                        RegistryKeyword = $Prop.RegistryKeyword
                        DisplayName     = $Prop.DisplayName
                        DisplayValue    = $Prop.DisplayValue
                    }
                    try {
                        Set-NetAdapterAdvancedProperty -Name $Adapter.Name -DisplayName $Prop.DisplayName -DisplayValue "Enabled" -ErrorAction Stop
                        Write-Output "    - Aggressive: Interrupt Moderation -> Enabled"
                    } catch {
                        Write-Output "    - Could not enable Interrupt Moderation: $($_.Exception.Message)"
                        $script:PTWErrorCount++
                    }
                }
            }
            Write-Output "    - Restarting Adapter..."
            try {
                Restart-NetAdapter -Name $Adapter.Name -ErrorAction Stop
            } catch {
                Write-Output "    - WARNING: Could not restart adapter '$($Adapter.Name)': $($_.Exception.Message)"
                Write-Output "    - You may need to restart it manually or reboot."
            }
        }
    }

    # Persist the snapshot so the restore action can reconstruct the adapter changes.
    if ($nicSnapshot.Count -gt 0) {
        $backupDir = Get-PTWNicBackupDir
        if ($backupDir) {
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $snapshotFile = Join-Path $backupDir "smart-optimize_${stamp}.json"
            try {
                $nicSnapshot | ConvertTo-Json -Depth 4 | Out-File -FilePath $snapshotFile -Encoding UTF8 -Force
                Write-Output "[+] Adapter settings snapshot saved for restore: $snapshotFile"

                # Keep enough history for interrupted/repeated runs without retaining state forever.
                Get-ChildItem -LiteralPath $backupDir -Filter 'smart-optimize_*.json' -File -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -Skip 5 |
                    Remove-Item -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Output "[!] Could not save adapter snapshot (restore may need manual reset): $($_.Exception.Message)"
                $script:PTWErrorCount++
            }
        }
    }

    Write-Output "[+] Smart Optimization Complete!"
}

function Restore-SmartNetworkOptimization {
    Write-Output "[*] Restoring Smart Network Optimization defaults..."
    $regKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-RegDword -Path $regKey -Name "NetworkThrottlingIndex" -Value 10
    Set-RegDword -Path $regKey -Name "SystemResponsiveness" -Value 20

    $backupDir = Get-PTWNicBackupDir
    $snapshot = if ($backupDir) {
        Get-ChildItem -Path $backupDir -Filter 'smart-optimize_*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }
    if (-not $snapshot) {
        Write-Output "[-] ERROR: No adapter snapshot was found. Registry defaults were restored, but adapter properties need manual review."
        $script:PTWErrorCount++
        return
    }

    try {
        $entries = @(Get-Content -LiteralPath $snapshot.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        Write-Output "[-] ERROR: Could not read adapter snapshot: $($_.Exception.Message)"
        $script:PTWErrorCount++
        return
    }

    $knownAdapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    $restored = 0
    $errorsBeforeRestore = $script:PTWErrorCount
    foreach ($entry in $entries) {
        if ($knownAdapters -notcontains [string]$entry.Adapter) {
            Write-Output "[!] Snapshot adapter '$($entry.Adapter)' no longer exists; skipped."
            $script:PTWErrorCount++
            continue
        }
        try {
            if ($entry.Type -eq 'PowerManagement') {
                Enable-NetAdapterPowerManagement -Name $entry.Adapter -ErrorAction Stop
            } elseif ($entry.Type -eq 'AdvancedProperty') {
                $property = Get-NetAdapterAdvancedProperty -Name $entry.Adapter -DisplayName $entry.DisplayName -ErrorAction Stop
                if ($property.ValidDisplayValues -notcontains [string]$entry.DisplayValue) {
                    throw "saved value '$($entry.DisplayValue)' is not valid for this adapter"
                }
                Set-NetAdapterAdvancedProperty -Name $entry.Adapter -DisplayName $entry.DisplayName `
                    -DisplayValue $entry.DisplayValue -ErrorAction Stop
            } else {
                throw "unknown snapshot entry type '$($entry.Type)'"
            }
            $restored++
        } catch {
            Write-Output "[!] Could not restore '$($entry.DisplayName)' on '$($entry.Adapter)': $($_.Exception.Message)"
            $script:PTWErrorCount++
        }
    }
    Write-Output "[+] Restored $restored adapter setting(s) from $($snapshot.Name)"
    if ($script:PTWErrorCount -eq $errorsBeforeRestore) {
        Remove-Item -LiteralPath $snapshot.FullName -Force -ErrorAction SilentlyContinue
    } else {
        Write-Output "[!] The snapshot was retained because one or more adapter settings could not be restored."
    }
}

#endregion

#region Action Dispatcher
switch ($Action.ToLowerInvariant()) {

    "adapter-ipv4only" {
        Write-Output "[*] Setting IPv4 Only mode..."
        Write-Output "[!] NOTE: This also disables file & printer sharing and QoS on all active adapters"
        Write-Output "    (ms_server, ms_msclient and ms_pacer are unbound). SMB file/printer sharing will not"
        Write-Output "    work while IPv4-Only is active. Use 'adapter-default' to restore all bindings."
        Set-AdapterBinding -Mode "IPv4Only"
        Write-Output "[+] SUCCESS: IPv4 Only mode applied"
        Exit-PTW
    }

    "adapter-default" {
        Write-Output "[*] Restoring default bindings..."
        Set-AdapterBinding -Mode "Default"
        Write-Output "[+] SUCCESS: Default bindings restored"
        Exit-PTW
    }

    "smart-optimize" {
        Invoke-SmartNetworkOptimization
        Exit-PTW
    }

    "smart-optimize-aggressive" {
        Invoke-SmartNetworkOptimization -Aggressive
        Exit-PTW
    }

    "smart-optimize-revert" {
        Restore-SmartNetworkOptimization
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
#endregion
