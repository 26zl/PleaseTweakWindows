# Performance & Power
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "power-plan-on",
        "power-plan-default",
        "registry-apply",
        "registry-default",
        "scaling-fix",
        "scaling-default",
        "hdcp-disable",
        "hdcp-enable",
        "usb-suspend-disable",
        "usb-suspend-default",
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

function Import-LocalRegistryFile {
    param([string]$FileName)
    $regPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "regs") -ChildPath $FileName
    if (Test-Path $regPath) {
        # Import the verified registry file with failure-aware reg.exe handling.
        return (Import-RegistryFile -RegFile $regPath)
    }
    Write-Output "[-] WARNING: Registry file not found: $regPath"
    return $false
}

function Get-RegOptimizeBackupPath {
    # Derive the backup set from Registry-Optimize.reg section headers.
    param([string]$FileName = "Registry-Optimize.reg")
    $regPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "regs") -ChildPath $FileName
    if (-not (Test-Path $regPath)) { return @() }
    $hiveMap = @{
        'HKEY_LOCAL_MACHINE'  = 'HKLM:'
        'HKEY_CURRENT_USER'   = 'HKCU:'
        'HKEY_USERS'          = 'HKU:'
        'HKEY_CLASSES_ROOT'   = 'HKCR:'
        'HKEY_CURRENT_CONFIG' = 'HKCC:'
    }
    $keys = [System.Collections.Generic.List[string]]::new()
    foreach ($line in Get-Content -LiteralPath $regPath) {
        # Include section headers for both modified and deleted keys.
        $m = [regex]::Match($line, '^\s*\[-?(?<k>HKEY_[^\]]+)\]\s*$')
        if (-not $m.Success) { continue }
        $k = $m.Groups['k'].Value
        $hive = ($k -split '\\', 2)[0]
        if (-not $hiveMap.ContainsKey($hive)) { continue }
        $rest = $k.Substring($hive.Length).TrimStart('\')
        $keys.Add(($hiveMap[$hive] + '\' + $rest).TrimEnd('\'))
    }
    # Remove keys already covered by a recursively exported ancestor.
    $kept = [System.Collections.Generic.List[string]]::new()
    foreach ($k in (($keys | Sort-Object -Unique) | Sort-Object { $_.Length })) {
        $covered = $false
        foreach ($a in $kept) {
            if ($k.Equals($a, [StringComparison]::OrdinalIgnoreCase) -or
                $k.StartsWith($a + '\', [StringComparison]::OrdinalIgnoreCase)) { $covered = $true; break }
        }
        if (-not $covered) { $kept.Add($k) }
    }
    return $kept.ToArray()
}

function Test-PowerSchemeExistence {
    param([Parameter(Mandatory=$true)][string]$SchemeId)
    $list = powercfg /list 2>$null
    return ($list -match [regex]::Escape($SchemeId))
}

function Invoke-PowerCfg {
    param([Parameter(Mandatory)][string[]]$Arguments)
    & powercfg.exe @Arguments 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "powercfg $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
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
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling',
            # power-plan-on writes ValueMax=0 here machine-wide; snapshot it so power-plan-default can be verified.
            'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583'
        )
        $schemeId = "99999999-9999-9999-9999-999999999999"
        try {
            if (-not (Test-PowerSchemeExistence -SchemeId $schemeId)) {
                Invoke-PowerCfg -Arguments @('/duplicatescheme', 'e9a42b02-d5df-448d-aa00-03f14749eb61', $schemeId)
            }
            if ((Get-ActivePowerSchemeId) -ne $schemeId) {
                Invoke-PowerCfg -Arguments @('/setactive', $schemeId)
            }
        } catch {
            Write-Output "[-] ERROR: Could not activate the Ultimate Performance plan: $($_.Exception.Message)"
            exit 1
        }
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" -Name "ValueMax" -Value 0
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Value 1
        Write-Output "[+] SUCCESS: Ultimate Power Plan applied (restart required)"
        Exit-PTW
    }

    "power-plan-default" {
        Write-Output "[*] Restoring default power plan..."
        $balancedScheme = '381b4222-f694-41f0-9685-ff5bb260df2e'
        $ptwScheme = '99999999-9999-9999-9999-999999999999'
        try {
            if (-not (Test-PowerSchemeExistence -SchemeId $balancedScheme)) {
                throw "The Windows Balanced power plan is missing. Refusing to delete or overwrite custom plans."
            }
            Invoke-PowerCfg -Arguments @('/setactive', $balancedScheme)
            if (Test-PowerSchemeExistence -SchemeId $ptwScheme) {
                Invoke-PowerCfg -Arguments @('/delete', $ptwScheme)
            }
        } catch {
            Write-Output "[-] ERROR: Could not restore the Balanced power plan: $($_.Exception.Message)"
            exit 1
        }
        Remove-RegValue -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff"
        # Windows default for this Processor performance core parking max is PRESENT=100 (0x64), not absent.
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" -Name "ValueMax" -Value 0x64
        Write-Output "[+] SUCCESS: Default power plan restored (restart required)"
        Exit-PTW
    }

    "registry-apply" {
        $markerPath = "HKCU:\Software\PleaseTweakWindows"
        if (Get-ItemProperty -Path $markerPath -Name "RegistryOptimized" -ErrorAction SilentlyContinue) {
            Write-Output "[!] Registry tweaks already applied. Skipping to prevent corruption."
            Exit-PTW
        }

        Write-Output "[*] Applying Registry Tweaks..."
        # Snapshot the registry-file section keys as a convenience backup.
        Backup-RegistryPath -Action $Action -Paths (Get-RegOptimizeBackupPath)
        try {
            Invoke-PowerCfg -Arguments @('/setacvalueindex', 'SCHEME_CURRENT', 'SUB_PCIE', 'EXPRESS', '0')
            # Throw on import failure so rollback runs and no applied marker is written.
            if (-not (Import-LocalRegistryFile -FileName "Registry-Optimize.reg")) {
                throw "Registry-Optimize.reg failed its integrity check or reg.exe import"
            }

            if (!(Test-Path $markerPath)) { New-Item -Path $markerPath -Force | Out-Null }
            Set-ItemProperty -Path $markerPath -Name "RegistryOptimized" -Value 1
            Write-Output "[+] SUCCESS: Registry tweaks applied (restart required)"
        } catch {
            Write-Output "[-] ERROR during registry tweaks: $($_.Exception.Message)"
            Write-Output "[!] Attempting rollback with default registry settings..."
            $rolledBack = Import-LocalRegistryFile -FileName "Registry-Defaults.reg"
            Remove-ItemProperty -Path $markerPath -Name "RegistryOptimized" -ErrorAction SilentlyContinue
            if ($rolledBack) {
                Write-Output "[+] Rollback applied. Restart to restore defaults."
            } else {
                Write-Output "[-] Rollback FAILED to import Registry-Defaults.reg — the machine may be left partially tweaked. Use System Restore to recover."
            }
            exit 1
        }
        Exit-PTW
    }

    "registry-default" {
        Write-Output "[*] Restoring default registry settings..."
        $markerPath = "HKCU:\Software\PleaseTweakWindows"
        # Same verified-import helper the registry-apply rollback uses for this file.
        if (Import-LocalRegistryFile -FileName "Registry-Defaults.reg") {
            Write-Output "[+] SUCCESS: Default registry settings restored (restart required)"
        } else {
            Write-Output "[-] ERROR: Registry-Defaults.reg failed its integrity check or reg.exe import"
        }
        # Clear the marker registry-apply sets so the tweak can be re-applied later.
        Remove-ItemProperty -Path $markerPath -Name "RegistryOptimized" -ErrorAction SilentlyContinue
        Exit-PTW
    }

    "scaling-fix" {
        Write-Output "[*] Applying 100% scaling fix..."
        Backup-RegistryPath -Action $Action -Paths @(
            'HKCU:\Control Panel\Mouse',
            'HKCU:\Control Panel\Desktop'
        )
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseSensitivity" -Value "10"
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseSpeed" -Value "0"
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0"
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0"
        Set-RegDword -Path "Registry::HKCU\Control Panel\Desktop" -Name "Win8DpiScaling" -Value 1
        Set-RegDword -Path "Registry::HKCU\Control Panel\Desktop" -Name "LogPixels" -Value 96
        Set-RegDword -Path "Registry::HKCU\Control Panel\Desktop" -Name "EnablePerProcessSystemDPI" -Value 0
        Write-Output "[+] SUCCESS: Scaling fix applied (restart required)"
        Exit-PTW
    }

    "scaling-default" {
        Write-Output "[*] Restoring default scaling..."
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseSensitivity" -Value "10"
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseSpeed" -Value "1"
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseThreshold1" -Value "6"
        Set-RegSz -Path "Registry::HKCU\Control Panel\Mouse" -Name "MouseThreshold2" -Value "10"
        Remove-RegValue -Path "Registry::HKCU\Control Panel\Desktop" -Name "Win8DpiScaling"
        Remove-RegValue -Path "Registry::HKCU\Control Panel\Desktop" -Name "LogPixels"
        Remove-RegValue -Path "Registry::HKCU\Control Panel\Desktop" -Name "EnablePerProcessSystemDPI"
        Write-Output "[+] SUCCESS: Default scaling restored (restart required)"
        Exit-PTW
    }

    "hdcp-disable" {
        Write-Output "[*] Disabling HDCP..."
        Backup-RegistryPath -Action $Action -Paths @(
            'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
        )
        $subkeys = (Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue).Name
        foreach ($key in $subkeys) {
            if ($key -notlike '*Configuration') {
                Set-RegDword -Path "$key" -Name "RMHdcpKeyglobZero" -Value 1
            }
        }
        Write-Output "[+] SUCCESS: HDCP disabled (restart required)"
        Exit-PTW
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
        Exit-PTW
    }

    "usb-suspend-disable" {
        Write-Output "[*] Disabling USB selective suspend (stops Windows powering down USB controllers - avoids audio/HID stutter and disconnects)..."
        # SUB_USB subgroup / USB selective suspend setting; 0 = disabled, on both AC and DC.
        $usbSub = '2a737441-1930-4402-8d77-b2bebba308a3'
        $usbSetting = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
        try {
            Invoke-PowerCfg -Arguments @('/setacvalueindex', 'SCHEME_CURRENT', $usbSub, $usbSetting, '0')
            Invoke-PowerCfg -Arguments @('/setdcvalueindex', 'SCHEME_CURRENT', $usbSub, $usbSetting, '0')
            Invoke-PowerCfg -Arguments @('/setactive', 'SCHEME_CURRENT')
        } catch {
            Write-Output "[-] ERROR: Could not disable USB selective suspend: $($_.Exception.Message)"
            exit 1
        }
        Write-Output "[+] SUCCESS: USB selective suspend disabled"
        Exit-PTW
    }

    "usb-suspend-default" {
        Write-Output "[*] Restoring USB selective suspend to the Windows default (enabled)..."
        $usbSub = '2a737441-1930-4402-8d77-b2bebba308a3'
        $usbSetting = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
        try {
            Invoke-PowerCfg -Arguments @('/setacvalueindex', 'SCHEME_CURRENT', $usbSub, $usbSetting, '1')
            Invoke-PowerCfg -Arguments @('/setdcvalueindex', 'SCHEME_CURRENT', $usbSub, $usbSetting, '1')
            Invoke-PowerCfg -Arguments @('/setactive', 'SCHEME_CURRENT')
        } catch {
            Write-Output "[-] ERROR: Could not restore USB selective suspend: $($_.Exception.Message)"
            exit 1
        }
        Write-Output "[+] SUCCESS: USB selective suspend restored to default"
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
