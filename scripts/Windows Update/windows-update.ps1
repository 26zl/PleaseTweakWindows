# Windows Update Control
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "wu-default",
        "wu-security-only",
        "wu-pause-updates",
        "wu-disable",
        "wu-secure",
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

$WuPolicy   = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$WuPolicyAu = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
# Manage the update client together with its orchestration and remediation services.
$WuServices = @('wuauserv','UsoSvc','WaaSMedicSvc','BITS','dosvc')

function Set-ServiceStartTypeSafe {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Automatic','Manual','Disabled')][string]$StartupType,
        [switch]$StopNow,
        # Warn without failing when protected update services reject start-type changes.
        [switch]$BestEffort
    )
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { return }

    $startValue = switch ($StartupType) { 'Automatic' { 2 } 'Manual' { 3 } 'Disabled' { 4 } }
    $configured = $false
    try {
        Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop
        $configured = $true
    } catch {
        Write-PTWLog "Service '$Name' start-type change failed; trying registry fallback: $($_.Exception.Message)" "WARNING"
    }

    if (-not $configured) {
        try {
            $svcKey = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
            if (Test-Path -LiteralPath $svcKey) {
                New-ItemProperty -Path $svcKey -Name 'Start' -PropertyType DWord -Value $startValue -Force -ErrorAction Stop | Out-Null
                $configured = $true
            }
        } catch {
            Write-PTWLog "Registry Start fallback for '$Name' failed: $($_.Exception.Message)" "WARNING"
        }
    }

    if (-not $configured) {
        if (-not $BestEffort) { $script:PTWErrorCount++ }
        return
    }

    try {
        if ($StopNow -and $svc.Status -ne 'Stopped') {
            Stop-Service -Name $Name -Force -ErrorAction Stop
        } elseif (-not $StopNow -and $StartupType -eq 'Automatic' -and $svc.Status -ne 'Running') {
            Start-Service -Name $Name -ErrorAction Stop
        }
    } catch {
        Write-PTWLog "Service '$Name' state change failed: $($_.Exception.Message)" "WARNING"
        if (-not $BestEffort) { $script:PTWErrorCount++ }
    }
}

function Enable-WindowsUpdateService {
    Set-ServiceStartTypeSafe -Name 'wuauserv' -StartupType 'Manual'
    Set-ServiceStartTypeSafe -Name 'UsoSvc' -StartupType 'Automatic'
    Set-ServiceStartTypeSafe -Name 'WaaSMedicSvc' -StartupType 'Manual' -BestEffort
    Set-ServiceStartTypeSafe -Name 'BITS' -StartupType 'Manual'
    Set-ServiceStartTypeSafe -Name 'dosvc' -StartupType 'Manual'
}

function Clear-PtwWindowsUpdatePolicy {
    foreach ($name in @(
        'DeferFeatureUpdates',
        'DeferFeatureUpdatesPeriodInDays',
        'DeferQualityUpdates',
        'DeferQualityUpdatesPeriodInDays',
        'BranchReadinessLevel',
        'PauseFeatureUpdatesStartTime',
        'PauseFeatureUpdatesEndTime',
        'PauseQualityUpdatesStartTime',
        'PauseQualityUpdatesEndTime',
        'PauseUpdatesStartTime',
        'PauseUpdatesExpiryTime'
    )) {
        Remove-RegValueSafe -Path $WuPolicy -Name $name
    }
    foreach ($name in @('NoAutoUpdate', 'AUOptions')) {
        Remove-RegValueSafe -Path $WuPolicyAu -Name $name
    }
}

#region Action Dispatcher
switch ($Action.ToLowerInvariant()) {

    "wu-default" {
        Write-Output "[*] Restoring default (Microsoft-managed) Windows Update behaviour..."
        Backup-RegistryPath -Action $Action -Paths @($WuPolicy)
        Clear-PtwWindowsUpdatePolicy
        Enable-WindowsUpdateService
        Write-Output "[+] SUCCESS: Windows Update restored to default automatic mode"
        Exit-PTW
    }

    "wu-security-only" {
        Write-Output "[*] Deferring feature updates while keeping quality/security updates enabled..."
        Backup-RegistryPath -Action $Action -Paths @($WuPolicy)
        Clear-PtwWindowsUpdatePolicy
        Enable-WindowsUpdateService
        # Defer FEATURE updates up to 365 days; quality (security) updates flow with no delay.
        Set-RegDword -Path $WuPolicy -Name "DeferFeatureUpdates" -Value 1
        Set-RegDword -Path $WuPolicy -Name "DeferFeatureUpdatesPeriodInDays" -Value 365
        Set-RegDword -Path $WuPolicy -Name "DeferQualityUpdates" -Value 1
        Set-RegDword -Path $WuPolicy -Name "DeferQualityUpdatesPeriodInDays" -Value 0
        # 16 = General Availability Channel (the documented "defer features, keep security" level).
        Set-RegDword -Path $WuPolicy -Name "BranchReadinessLevel" -Value 16
        # Keep automatic install on so security patches are not held back.
        Set-RegDword -Path $WuPolicyAu -Name "NoAutoUpdate" -Value 0
        Set-RegDword -Path $WuPolicyAu -Name "AUOptions" -Value 4
        Write-Output "[!] NOTE: feature-update deferral is honoured on Windows Pro/Enterprise/Education. On Windows Home these deferral policies may be ignored; security/quality updates continue regardless."
        Write-Output "[+] SUCCESS: feature-update deferral configured; security/quality updates still flow"
        Exit-PTW
    }

    "wu-pause-updates" {
        Write-Output "[*] Pausing Windows Update for the maximum window..."
        Backup-RegistryPath -Action $Action -Paths @($WuPolicy)
        Clear-PtwWindowsUpdatePolicy
        Enable-WindowsUpdateService
        $start = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $end = (Get-Date).ToUniversalTime().AddDays(3500).ToString("yyyy-MM-ddTHH:mm:ssZ")
        Set-RegSz -Path $WuPolicy -Name "PauseFeatureUpdatesStartTime" -Value $start
        Set-RegSz -Path $WuPolicy -Name "PauseFeatureUpdatesEndTime" -Value $end
        Set-RegSz -Path $WuPolicy -Name "PauseQualityUpdatesStartTime" -Value $start
        Set-RegSz -Path $WuPolicy -Name "PauseQualityUpdatesEndTime" -Value $end
        Set-RegSz -Path $WuPolicy -Name "PauseUpdatesStartTime" -Value $start
        Set-RegSz -Path $WuPolicy -Name "PauseUpdatesExpiryTime" -Value $end
        Write-Output "[!] WARNING: updates are paused into the far future. Windows may still surface a 'resume updates' button; choose the 'Default' mode to fully resume."
        Write-Output "[+] SUCCESS: Windows Update paused (use Default mode to resume)"
        Exit-PTW
    }

    "wu-disable" {
        Write-Output "[*] Turning Windows Update off (aggressive)..."
        Write-Output "[!] WARNING: this stops the machine from receiving SECURITY patches as well as feature updates. Your PC will become progressively more vulnerable. Use the 'Default' mode to turn updates back on."
        Backup-RegistryPath -Action $Action -Paths @($WuPolicy)
        Clear-PtwWindowsUpdatePolicy
        # Disable updates with NoAutoUpdate and service state instead of legacy AUOptions.
        Set-RegDword -Path $WuPolicyAu -Name "NoAutoUpdate" -Value 1
        foreach ($svc in $WuServices) {
            Set-ServiceStartTypeSafe -Name $svc -StartupType 'Disabled' -StopNow -BestEffort:($svc -eq 'WaaSMedicSvc')
        }
        Write-Output "[+] SUCCESS: Windows Update turned off (REVERSIBLE via Default mode)"
        Exit-PTW
    }

    "wu-secure" {
        Write-Output "[*] Configuring secure updates (prompt before installing all Microsoft products)..."
        Backup-RegistryPath -Action $Action -Paths @($WuPolicy)
        Clear-PtwWindowsUpdatePolicy
        Enable-WindowsUpdateService
        # AUOptions=3 = auto download + notify for install.
        Set-RegDword -Path $WuPolicyAu -Name "NoAutoUpdate" -Value 0
        Set-RegDword -Path $WuPolicyAu -Name "AUOptions" -Value 3
        # Register Microsoft Update so updates for other MS products (Office, etc.) flow too.
        try {
            (New-Object -ComObject Microsoft.Update.ServiceManager).AddService2('7971f918-a847-4430-9279-4a52d1efe18d',7,'') 2>$null | Out-Null
            Write-Output "[+] Registered Microsoft Update for other Microsoft products"
        } catch {
            Write-PTWLog "Could not register Microsoft Update service: $($_.Exception.Message)" "WARNING"
            $script:PTWErrorCount++
        }
        Write-Output "[+] SUCCESS: secure update mode configured (installs of all Microsoft products are prompted)"
        Exit-PTW
    }

    "menu" {
        Write-Output "[i] No interactive menu - use the GUI to select a mode"
        Exit-PTW
    }

    default {
        Write-Error "Unknown action: $Action"
        exit 1
    }
}
#endregion
