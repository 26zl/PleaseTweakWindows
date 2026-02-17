# Gaming Optimizations
# Purpose: Non-interactive action dispatcher.
# Usage: powershell -File Gaming-Optimizations.ps1 -Action "<action-id>"
# Version: 2.1.0
# Last Updated: 2026-01-18
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "nvidia-settings-on",
        "nvidia-settings-default",
        "nvidia-driver-install",
        "amd-driver-install",
        "p0-state-on",
        "p0-state-default",
        "ulps-disable",
        "ulps-enable",
        "controller-oc-on",
        "controller-oc-default",
        "gamebar-off",
        "gamebar-on",
        "msi-mode-on",
        "msi-mode-off",
        "polling-unlock",
        "polling-default",
        "directx-install",
        "mpo-on",
        "mpo-default",
        "menu"
    )]
    [string]$Action = "Menu"
)

$script:ScriptVersion = "2.1.0"

#region Logging Functions
function Write-PTWLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) {
        "INFO"    { "[*]" }
        "SUCCESS" { "[+]" }
        "WARNING" { "[!]" }
        "ERROR"   { "[-]" }
        default   { "[*]" }
    }
    Write-Output "$timestamp $prefix $Message"
}
#endregion

#region Prerequisite Checks
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
#endregion



#region Action Dispatcher
switch ($Action.ToLowerInvariant()) {

    "nvidia-settings-on" {
        Write-Output "[*] Applying NVIDIA Profile Inspector settings..."
        $drsPath = "$env:ProgramData\NVIDIA Corporation\Drs"
        if (Test-Path $drsPath) { Get-ChildItem -Path $drsPath -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue }
        $inspectorDir = "$env:TEMP\nvidiaProfileInspector"
        if (-not (Test-Path "$inspectorDir\nvidiaProfileInspector.exe")) {
            Get-FileFromWeb -URL "https://github.com/Orbmu2k/nvidiaProfileInspector/releases/download/2.4.0.31/nvidiaProfileInspector.zip" -File "$env:TEMP\nvidiaProfileInspector.zip"
            Expand-Archive "$env:TEMP\nvidiaProfileInspector.zip" -DestinationPath $inspectorDir -Force
        }
        $nvidiaConfigPath = Join-Path $PSScriptRoot "reg\nvidia_profile.xml"
        if (Test-Path $nvidiaConfigPath) {
            Copy-Item -Path $nvidiaConfigPath -Destination "$inspectorDir\Inspector.nip" -Force
        } else {
            Write-Output "[-] ERROR: nvidia_profile.xml not found"
            exit 1
        }
        Start-Process -Wait "$inspectorDir\nvidiaProfileInspector.exe" -ArgumentList "$inspectorDir\Inspector.nip"
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS" -Name "EnableGR535" -Value 0
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS" -Name "EnableGR535" -Value 0
        Write-Output "[+] SUCCESS: NVIDIA Profile applied"
        exit 0
    }

    "nvidia-settings-default" {
        Write-Output "[*] Resetting NVIDIA settings to default..."
        Remove-RegValue -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS" -Name "EnableGR535"
        Remove-RegValue -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS" -Name "EnableGR535"
        Write-Output "[+] SUCCESS: NVIDIA settings reset (restart required)"
        exit 0
    }

    "nvidia-driver-install" {
        Write-Output "[*] Finding latest NVIDIA driver..."
        $nvidiaGpuKeys = Get-GpuClassKeysByVendor -Vendor "NVIDIA"
        if (-not $nvidiaGpuKeys -or $nvidiaGpuKeys.Count -eq 0) {
            Write-Output "[-] ERROR: No NVIDIA GPU detected. Cannot install NVIDIA driver."
            exit 1
        }
        Remove-Item -Recurse -Force "$env:TEMP\NvidiaDriver.exe" -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force "$env:TEMP\NvidiaDriver" -ErrorAction SilentlyContinue
        # Query NVIDIA API for latest Game Ready driver (psid=131 = GeForce RTX 50 Series, pfid=1066 = RTX 5090)
        # The returned driver is universal and supports all modern GeForce GPUs (RTX 50/40/30/20, GTX 16)
        $uri = 'https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=DriverManualLookup&psid=131&pfid=1066&osID=57&languageCode=1033&isWHQL=1&dch=1&sort1=0&numberOfResults=1'
        $response = Invoke-WebRequest -Uri $uri -Method GET -UseBasicParsing
        $payload = $response.Content | ConvertFrom-Json
        $version = $payload.IDS[0].downloadInfo.Version
        $url = $payload.IDS[0].downloadInfo.DownloadURL
        if (-not $url) {
            Write-Output "[-] ERROR: Could not retrieve NVIDIA driver download URL from API."
            exit 1
        }
        Write-Output "[*] Downloading NVIDIA Driver $version..."
        Get-FileFromWeb -URL $url -File "$env:TEMP\NvidiaDriver.exe"
        $sevenZip = "$env:ProgramFiles\7-Zip\7z.exe"
        if (-not (Test-Path $sevenZip)) {
            Get-FileFromWeb -URL "https://www.7-zip.org/a/7z2501-x64.exe" -File "$env:TEMP\7z-setup.exe"
            Start-Process -Wait "$env:TEMP\7z-setup.exe" -ArgumentList "/S"
        }
        cmd /c "`"$sevenZip`" x `"$env:TEMP\NvidiaDriver.exe`" -o`"$env:TEMP\NvidiaDriver`" -y" | Out-Null
        Start-Process "$env:TEMP\NvidiaDriver\setup.exe"
        Write-Output "[+] SUCCESS: NVIDIA Driver installer launched"
        exit 0
    }

    "amd-driver-install" {
        Write-Output "[*] Opening AMD driver download page..."
        $amdGpuKeys = Get-GpuClassKeysByVendor -Vendor "AMD"
        if (-not $amdGpuKeys -or $amdGpuKeys.Count -eq 0) {
            Write-Output "[-] ERROR: No AMD GPU detected. Cannot install AMD driver."
            exit 1
        }
        # AMD has no public API for driver lookups. Open the official download page
        # which always offers the latest Auto-Detect installer.
        Start-Process "https://www.amd.com/en/support/download/drivers.html"
        Write-Output "[+] SUCCESS: AMD driver download page opened - click 'Download Windows Drivers' to get the latest installer"
        exit 0
    }

    "p0-state-on" {
        Write-Output "[*] Enabling P0 State (Maximum Performance)..."
        $subkeys = Get-GpuClassKeysByVendor -Vendor "NVIDIA"
        if (-not $subkeys -or $subkeys.Count -eq 0) {
            Write-Output "[!] No NVIDIA GPU detected; skipping P0 State change."
            exit 0
        }
        foreach ($key in $subkeys) {
            if ($key -notlike '*Configuration') {
                Set-RegDword -Path "$key" -Name "DisableDynamicPstate" -Value 1
            }
        }
        Write-Output "[+] SUCCESS: P0 State enabled (restart required)"
        exit 0
    }

    "p0-state-default" {
        Write-Output "[*] Restoring default P-State..."
        $subkeys = Get-GpuClassKeysByVendor -Vendor "NVIDIA"
        if (-not $subkeys -or $subkeys.Count -eq 0) {
            Write-Output "[!] No NVIDIA GPU detected; skipping P-State restore."
            exit 0
        }
        foreach ($key in $subkeys) {
            if ($key -notlike '*Configuration') {
                Remove-RegValue -Path "$key" -Name "DisableDynamicPstate"
            }
        }
        Write-Output "[+] SUCCESS: P-State restored to default (restart required)"
        exit 0
    }

    "ulps-disable" {
        Write-Output "[*] Disabling ULPS (Ultra Low Power State)..."
        $subkeys = Get-GpuClassKeysByVendor -Vendor "AMD"
        if (-not $subkeys -or $subkeys.Count -eq 0) {
            Write-Output "[!] No AMD GPU detected; skipping ULPS change."
            exit 0
        }
        foreach ($key in $subkeys) {
            if ($key -notlike '*Configuration') {
                Set-RegDword -Path "$key" -Name "EnableUlps" -Value 0
            }
        }
        Write-Output "[+] SUCCESS: ULPS disabled (restart required)"
        exit 0
    }

    "ulps-enable" {
        Write-Output "[*] Enabling ULPS..."
        $subkeys = Get-GpuClassKeysByVendor -Vendor "AMD"
        if (-not $subkeys -or $subkeys.Count -eq 0) {
            Write-Output "[!] No AMD GPU detected; skipping ULPS restore."
            exit 0
        }
        foreach ($key in $subkeys) {
            if ($key -notlike '*Configuration') {
                Set-RegDword -Path "$key" -Name "EnableUlps" -Value 1
            }
        }
        Write-Output "[+] SUCCESS: ULPS enabled (restart required)"
        exit 0
    }

    "controller-oc-on" {
        Write-Output "[*] Enabling USB Controller Overclock with Secure Boot..."
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy" -Name "WHQLSettings" -Value 1
        Write-Output "[+] SUCCESS: Controller overclock enabled (restart required)"
        exit 0
    }

    "controller-oc-default" {
        Write-Output "[*] Disabling USB Controller Overclock..."
        Remove-RegValue -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy" -Name "WHQLSettings"
        Write-Output "[+] SUCCESS: Controller overclock disabled (restart required)"
        exit 0
    }

    "gamebar-off" {
        Write-Output "[*] Disabling Game Bar and Xbox services..."
        $markerPath = "HKCU:\Software\PleaseTweakWindows"
        $marker = Get-ItemProperty -Path $markerPath -Name "GameBarDisabled" -ErrorAction SilentlyContinue
        if ($marker.GameBarDisabled -eq 1) {
            Write-Output "[i] Game Bar already disabled (marker present)."
            exit 0
        }

        $ProgressPreference = 'SilentlyContinue'
        Set-RegDword -Path "Registry::HKCU\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0
        Set-RegDword -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0
        Set-RegDword -Path "Registry::HKCU\Software\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Value 0
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\GameInputSvc" -Name "Start" -Value 4
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\BcastDVRUserService" -Name "Start" -Value 4
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\XboxGipSvc" -Name "Start" -Value 4
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\XblAuthManager" -Name "Start" -Value 4
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\XblGameSave" -Name "Start" -Value 4
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\XboxNetApiSvc" -Name "Start" -Value 4
        Stop-Process -Force -Name GameBar -ErrorAction SilentlyContinue
        if (!(Test-Path $markerPath)) { New-Item -Path $markerPath -Force | Out-Null }
        Set-ItemProperty -Path $markerPath -Name "GameBarDisabled" -Value 1
        Write-Output "[+] SUCCESS: Game Bar disabled (restart required)"
        exit 0
    }

    "gamebar-on" {
        Write-Output "[*] Enabling Game Bar..."
        Set-RegDword -Path "Registry::HKCU\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 1
        Set-RegDword -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 1
        Set-RegDword -Path "Registry::HKCU\Software\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Value 1
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\GameInputSvc" -Name "Start" -Value 3
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\BcastDVRUserService" -Name "Start" -Value 3
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\XboxGipSvc" -Name "Start" -Value 3
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\XblAuthManager" -Name "Start" -Value 3
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\XblGameSave" -Name "Start" -Value 3
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\XboxNetApiSvc" -Name "Start" -Value 3
        Remove-ItemProperty -Path "HKCU:\Software\PleaseTweakWindows" -Name "GameBarDisabled" -ErrorAction SilentlyContinue
        Write-Output "[+] SUCCESS: Game Bar enabled (restart required)"
        exit 0
    }

    "msi-mode-on" {
        Write-Output "[*] Enabling MSI Mode for GPUs..."
        $gpuDevices = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue
        foreach ($gpu in $gpuDevices) {
            $instanceID = $gpu.InstanceId
            Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Enum\$instanceID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" -Name "MSISupported" -Value 1
        }
        Write-Output "[+] SUCCESS: MSI Mode enabled (restart required)"
        exit 0
    }

    "msi-mode-off" {
        Write-Output "[*] Disabling MSI Mode for GPUs..."
        $gpuDevices = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue
        foreach ($gpu in $gpuDevices) {
            $instanceID = $gpu.InstanceId
            Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Enum\$instanceID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" -Name "MSISupported" -Value 0
        }
        Write-Output "[+] SUCCESS: MSI Mode disabled (restart required)"
        exit 0
    }

    "polling-unlock" {
        Write-Output "[*] Unlocking background polling rate cap..."
        Set-RegDword -Path "Registry::HKCU\Control Panel\Mouse" -Name "RawMouseThrottleEnabled" -Value 0
        Write-Output "[+] SUCCESS: Polling rate cap unlocked (restart required)"
        exit 0
    }

    "polling-default" {
        Write-Output "[*] Restoring default polling rate cap..."
        Remove-RegValue -Path "Registry::HKCU\Control Panel\Mouse" -Name "RawMouseThrottleEnabled"
        Write-Output "[+] SUCCESS: Polling rate cap restored (restart required)"
        exit 0
    }

    "directx-install" {
        Write-Output "[*] Installing DirectX Runtime..."
        Get-FileFromWeb -URL "https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe" -File "$env:TEMP\DirectX.exe"
        $sevenZip = "$env:ProgramFiles\7-Zip\7z.exe"
        if (-not (Test-Path $sevenZip)) {
            Get-FileFromWeb -URL "https://www.7-zip.org/a/7z2501-x64.exe" -File "$env:TEMP\7z-setup.exe"
            Start-Process -Wait "$env:TEMP\7z-setup.exe" -ArgumentList "/S"
        }
        cmd /c "`"$sevenZip`" x `"$env:TEMP\DirectX.exe`" -o`"$env:TEMP\DirectX`" -y" | Out-Null
        Start-Process "$env:TEMP\DirectX\DXSETUP.exe"
        Write-Output "[+] SUCCESS: DirectX installer launched"
        exit 0
    }

    "mpo-on" {
        Write-Output "[*] Enabling MPO and Windowed Optimizations..."
        Remove-RegValue -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode"
        Set-RegSz -Path "Registry::HKCU\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -Value "VRROptimizeEnable=1;SwapEffectUpgradeEnable=1;"
        Write-Output "[+] SUCCESS: MPO enabled (restart required)"
        exit 0
    }

    "mpo-default" {
        Write-Output "[*] Disabling MPO..."
        Set-RegDword -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode" -Value 5
        Remove-RegValue -Path "Registry::HKCU\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings"
        Write-Output "[+] SUCCESS: MPO disabled (restart required)"
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
