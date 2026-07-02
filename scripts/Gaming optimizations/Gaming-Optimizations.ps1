# Gaming Optimizations
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "nvidia-settings-on",
        "nvidia-driver-install",
        "amd-driver-install",
        "p0-state-on",
        "p0-state-default",
        "ulps-disable",
        "ulps-enable",
        "gamebar-off",
        "gamebar-on",
        "msi-mode-on",
        "msi-mode-off",
        "polling-unlock",
        "polling-default",
        "directx-install",
        "mpo-on",
        "mpo-default",
        "hags-on",
        "hags-off",
        "game-mode-on",
        "game-mode-off",
        "menu"
    )]
    [string]$Action = "Menu"
)

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
    Write-PTWLog "CommonFunctions.ps1 not found; refusing to continue" "ERROR"
    exit 1
}
#endregion



#region Action Dispatcher
switch ($Action.ToLowerInvariant()) {

    "nvidia-settings-on" {
        Write-Output "[*] Applying NVIDIA Profile Inspector settings..."
        $drsPath = "$env:ProgramData\NVIDIA Corporation\Drs"
        if (Test-Path $drsPath) { Get-ChildItem -Path $drsPath -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue }
        $inspectorDir = Get-PTWRuntimePath "nvidiaProfileInspector"
        $inspectorZip = Get-PTWRuntimePath "nvidiaProfileInspector.zip"
        Remove-Item -Recurse -Force $inspectorDir -ErrorAction SilentlyContinue
        if (-not (Test-Path "$inspectorDir\nvidiaProfileInspector.exe")) {
            Get-FileFromWeb -URL $PTWDownloadUrls.NvidiaProfileInspector -File $inspectorZip
            Expand-Archive $inspectorZip -DestinationPath $inspectorDir -Force
        }
        $nvidiaConfigPath = Join-Path $PSScriptRoot "reg\nvidia_profile.xml"
        if (Test-PtwFileChecksum -Path $nvidiaConfigPath) {
            Copy-Item -Path $nvidiaConfigPath -Destination "$inspectorDir\Inspector.nip" -Force
        } else {
            Write-Output "[-] ERROR: nvidia_profile.xml is missing or failed its integrity check"
            exit 1
        }
        $inspector = Start-Process -FilePath "$inspectorDir\nvidiaProfileInspector.exe" `
            -ArgumentList "$inspectorDir\Inspector.nip" -Wait -PassThru -ErrorAction Stop
        if ($inspector.ExitCode -ne 0) {
            Write-Output "[-] ERROR: NVIDIA Profile Inspector exited with code $($inspector.ExitCode)"
            exit 1
        }
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS" -Name "EnableGR535" -Value 0
        Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS" -Name "EnableGR535" -Value 0
        Write-Output "[+] SUCCESS: NVIDIA Profile applied"
        Exit-PTW
    }

    "nvidia-driver-install" {
        Write-Output "[*] Finding latest NVIDIA driver..."
        $nvidiaGpuKeys = Get-GpuClassKeysByVendor -Vendor "NVIDIA"
        if (-not $nvidiaGpuKeys -or $nvidiaGpuKeys.Count -eq 0) {
            Write-Output "[-] ERROR: No NVIDIA GPU detected. Cannot install NVIDIA driver."
            exit 1
        }
        $driverExe = Get-PTWRuntimePath "NvidiaDriver.exe"
        $driverDir = Get-PTWRuntimePath "NvidiaDriver"
        Remove-Item -Force $driverExe -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $driverDir -ErrorAction SilentlyContinue
        # Query NVIDIA's API for the universal Game Ready driver package.
        $uri = 'https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=DriverManualLookup&psid=131&pfid=1066&osID=57&languageCode=1033&isWHQL=1&dch=1&sort1=0&numberOfResults=1'
        $response = Invoke-WebRequest -Uri $uri -Method GET -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
        if ($response.RawContentLength -gt 1MB -or $response.Content.Length -gt 1MB) {
            Write-Output "[-] ERROR: NVIDIA driver API returned an unexpectedly large response."
            exit 1
        }
        $payload = $response.Content | ConvertFrom-Json
        $version = $payload.IDS[0].downloadInfo.Version
        $url = $payload.IDS[0].downloadInfo.DownloadURL
        if (-not $url) {
            Write-Output "[-] ERROR: Could not retrieve NVIDIA driver download URL from API."
            exit 1
        }
        Write-Output "[*] Downloading NVIDIA Driver $version..."
        # Raise the response cap for large Game Ready driver packages.
        Get-FileFromWeb -URL $url -File $driverExe -MaxBytes 3GB
        # Verify the dynamic NVIDIA driver package with Authenticode.
        Test-SignedFile -Path $driverExe -PublisherPatterns @('NVIDIA Corporation')
        $sevenZip = "$env:ProgramFiles\7-Zip\7z.exe"
        if (-not (Test-Path $sevenZip)) {
            $sevenZipInstaller = Get-PTWRuntimePath "7z-setup.exe"
            Get-FileFromWeb -URL $PTWDownloadUrls.SevenZip -File $sevenZipInstaller
            $sevenZipInstall = Start-Process -FilePath $sevenZipInstaller -ArgumentList "/S" -Wait -PassThru -ErrorAction Stop
            if ($sevenZipInstall.ExitCode -ne 0) {
                Write-Output "[-] ERROR: 7-Zip installation failed with exit code $($sevenZipInstall.ExitCode)."
                exit 1
            }
        }
        if (-not (Test-Path $sevenZip)) {
            Write-Output "[-] ERROR: 7-Zip installation did not produce $sevenZip."
            exit 1
        }
        & $sevenZip x $driverExe "-o$driverDir" -y | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Output "[-] ERROR: NVIDIA driver extraction failed (7-Zip exit $LASTEXITCODE)."
            exit 1
        }
        $driverSetup = Join-Path $driverDir "setup.exe"
        if (Test-Path $driverSetup) {
            Test-SignedFile -Path $driverSetup -PublisherPatterns @('NVIDIA Corporation')
        }
        if (-not (Test-Path $driverSetup)) {
            Write-Output "[-] ERROR: NVIDIA driver package did not extract correctly (setup.exe missing). Driver not installed."
            exit 1
        }
        $driverInstall = Start-Process -FilePath $driverSetup -Wait -PassThru -ErrorAction Stop
        if ($driverInstall.ExitCode -notin @(0, 3010)) {
            Write-Output "[-] ERROR: NVIDIA installer exited with code $($driverInstall.ExitCode)."
            exit 1
        }
        Remove-Item -LiteralPath $driverExe -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $driverDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Output "[+] SUCCESS: NVIDIA Driver installer completed"
        Exit-PTW
    }

    "amd-driver-install" {
        Write-Output "[*] Opening AMD driver download page..."
        $amdGpuKeys = Get-GpuClassKeysByVendor -Vendor "AMD"
        if (-not $amdGpuKeys -or $amdGpuKeys.Count -eq 0) {
            Write-Output "[-] ERROR: No AMD GPU detected. Cannot install AMD driver."
            exit 1
        }
        # Open AMD's official page for the latest Auto-Detect installer.
        Start-Process "https://www.amd.com/en/support/download/drivers.html"
        Write-Output "[+] SUCCESS: AMD driver download page opened - click 'Download Windows Drivers' to get the latest installer"
        Exit-PTW
    }

    "p0-state-on" {
        Write-Output "[*] Enabling P0 State (Maximum Performance)..."
        $subkeys = Get-GpuClassKeysByVendor -Vendor "NVIDIA"
        if (-not $subkeys -or $subkeys.Count -eq 0) {
            Write-Output "[!] No NVIDIA GPU detected; skipping P0 State change."
            Exit-PTW
        }
        $backupKeys = @($subkeys | Where-Object { $_ -notlike '*Configuration' } | ForEach-Object { "Registry::$_" })
        if ($backupKeys.Count -gt 0) { Backup-RegistryPath -Action $Action -Paths $backupKeys }
        foreach ($key in $subkeys) {
            if ($key -notlike '*Configuration') {
                Set-RegDword -Path "$key" -Name "DisableDynamicPstate" -Value 1
            }
        }
        Write-Output "[+] SUCCESS: P0 State enabled (restart required)"
        Exit-PTW
    }

    "p0-state-default" {
        Write-Output "[*] Restoring default P-State..."
        $subkeys = Get-GpuClassKeysByVendor -Vendor "NVIDIA"
        if (-not $subkeys -or $subkeys.Count -eq 0) {
            Write-Output "[!] No NVIDIA GPU detected; skipping P-State restore."
            Exit-PTW
        }
        foreach ($key in $subkeys) {
            if ($key -notlike '*Configuration') {
                Remove-RegValue -Path "$key" -Name "DisableDynamicPstate"
            }
        }
        Write-Output "[+] SUCCESS: P-State restored to default (restart required)"
        Exit-PTW
    }

    "ulps-disable" {
        Write-Output "[*] Disabling ULPS (Ultra Low Power State)..."
        $subkeys = Get-GpuClassKeysByVendor -Vendor "AMD"
        if (-not $subkeys -or $subkeys.Count -eq 0) {
            Write-Output "[!] No AMD GPU detected; skipping ULPS change."
            Exit-PTW
        }
        $backupKeys = @($subkeys | Where-Object { $_ -notlike '*Configuration' } | ForEach-Object { "Registry::$_" })
        if ($backupKeys.Count -gt 0) { Backup-RegistryPath -Action $Action -Paths $backupKeys }
        foreach ($key in $subkeys) {
            if ($key -notlike '*Configuration') {
                Set-RegDword -Path "$key" -Name "EnableUlps" -Value 0
            }
        }
        Write-Output "[+] SUCCESS: ULPS disabled (restart required)"
        Exit-PTW
    }

    "ulps-enable" {
        Write-Output "[*] Enabling ULPS..."
        $subkeys = Get-GpuClassKeysByVendor -Vendor "AMD"
        if (-not $subkeys -or $subkeys.Count -eq 0) {
            Write-Output "[!] No AMD GPU detected; skipping ULPS restore."
            Exit-PTW
        }
        foreach ($key in $subkeys) {
            if ($key -notlike '*Configuration') {
                Set-RegDword -Path "$key" -Name "EnableUlps" -Value 1
            }
        }
        Write-Output "[+] SUCCESS: ULPS enabled (restart required)"
        Exit-PTW
    }

    "gamebar-off" {
        Write-Output "[*] Disabling Game Bar and Xbox services..."
        $markerPath = "HKCU:\Software\PleaseTweakWindows"
        $marker = Get-ItemProperty -Path $markerPath -Name "GameBarDisabled" -ErrorAction SilentlyContinue
        if ($marker.GameBarDisabled -eq 1) {
            Write-Output "[i] Game Bar already disabled (marker present)."
            Exit-PTW
        }

        $ProgressPreference = 'SilentlyContinue'
        # Keep diagnostic .reg snapshots before changing the service and GameDVR values.
        Backup-RegistryPath -Action $Action -Paths @(
            "Registry::HKCU\System\GameConfigStore",
            "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR",
            "Registry::HKCU\Software\Microsoft\GameBar",
            "Registry::HKLM\SYSTEM\CurrentControlSet\Services\GameInputSvc",
            "Registry::HKLM\SYSTEM\CurrentControlSet\Services\BcastDVRUserService",
            "Registry::HKLM\SYSTEM\CurrentControlSet\Services\XboxGipSvc",
            "Registry::HKLM\SYSTEM\CurrentControlSet\Services\XblAuthManager",
            "Registry::HKLM\SYSTEM\CurrentControlSet\Services\XblGameSave",
            "Registry::HKLM\SYSTEM\CurrentControlSet\Services\XboxNetApiSvc"
        )
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
        Exit-PTW
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
        Exit-PTW
    }

    "msi-mode-on" {
        Write-Output "[*] Enabling MSI Mode for GPUs..."
        # Apply MSI mode only to present NVIDIA and AMD discrete GPUs.
        $gpuDevices = Get-PnpDevice -Class Display -Status OK -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match "VEN_10DE|VEN_1002" }
        $msiPaths = @()
        foreach ($gpu in $gpuDevices) {
            $instanceID = $gpu.InstanceId
            if (-not $instanceID) { continue }
            $msiPaths += "Registry::HKLM\SYSTEM\CurrentControlSet\Enum\$instanceID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        }
        if ($msiPaths.Count -gt 0) {
            Backup-RegistryPath -Action $Action -Paths $msiPaths
        }
        foreach ($p in $msiPaths) {
            Set-RegDword -Path $p -Name "MSISupported" -Value 1
        }
        Write-Output "[+] SUCCESS: MSI Mode enabled (restart required)"
        Exit-PTW
    }

    "msi-mode-off" {
        Write-Output "[*] Removing the GPU MSI Mode override..."
        $gpuDevices = Get-PnpDevice -Class Display -Status OK -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match "VEN_10DE|VEN_1002" }
        foreach ($gpu in $gpuDevices) {
            $instanceID = $gpu.InstanceId
            if (-not $instanceID) { continue }
            Remove-RegValue -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Enum\$instanceID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" -Name "MSISupported"
        }
        Write-Output "[+] SUCCESS: GPU MSI Mode override removed (restart required)"
        Exit-PTW
    }

    "polling-unlock" {
        Write-Output "[*] Unlocking background polling rate cap..."
        Set-RegDword -Path "Registry::HKCU\Control Panel\Mouse" -Name "RawMouseThrottleEnabled" -Value 0
        Write-Output "[+] SUCCESS: Polling rate cap unlocked (restart required)"
        Exit-PTW
    }

    "polling-default" {
        Write-Output "[*] Restoring default polling rate cap..."
        Remove-RegValue -Path "Registry::HKCU\Control Panel\Mouse" -Name "RawMouseThrottleEnabled"
        Write-Output "[+] SUCCESS: Polling rate cap restored (restart required)"
        Exit-PTW
    }

    "directx-install" {
        Write-Output "[*] Installing DirectX Runtime..."
        $directXExe = Get-PTWRuntimePath "DirectX.exe"
        $directXDir = Get-PTWRuntimePath "DirectX"
        Get-FileFromWeb -URL "https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe" -File $directXExe
        $sevenZip = "$env:ProgramFiles\7-Zip\7z.exe"
        if (-not (Test-Path $sevenZip)) {
            $sevenZipInstaller = Get-PTWRuntimePath "7z-setup.exe"
            Get-FileFromWeb -URL $PTWDownloadUrls.SevenZip -File $sevenZipInstaller
            $sevenZipInstall = Start-Process -FilePath $sevenZipInstaller -ArgumentList "/S" -Wait -PassThru -ErrorAction Stop
            if ($sevenZipInstall.ExitCode -ne 0) {
                Write-Output "[-] ERROR: 7-Zip installation failed with exit code $($sevenZipInstall.ExitCode)."
                exit 1
            }
        }
        if (-not (Test-Path $sevenZip)) {
            Write-Output "[-] ERROR: 7-Zip installation did not produce $sevenZip."
            exit 1
        }
        Remove-Item -Recurse -Force $directXDir -ErrorAction SilentlyContinue
        & $sevenZip x $directXExe "-o$directXDir" -y | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Output "[-] ERROR: DirectX extraction failed (7-Zip exit $LASTEXITCODE)."
            exit 1
        }
        $directXSetup = Join-Path $directXDir "DXSETUP.exe"
        if (-not (Test-Path $directXSetup)) {
            Write-Output "[-] ERROR: DirectX setup was not found after extraction."
            exit 1
        }
        Test-SignedFile -Path $directXSetup -PublisherPatterns @('Microsoft Corporation')
        $directXInstall = Start-Process -FilePath $directXSetup -Wait -PassThru -ErrorAction Stop
        if ($directXInstall.ExitCode -notin @(0, 3010)) {
            Write-Output "[-] ERROR: DirectX setup exited with code $($directXInstall.ExitCode)."
            exit 1
        }
        Remove-Item -LiteralPath $directXExe -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $directXDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Output "[+] SUCCESS: DirectX Runtime installer completed"
        Exit-PTW
    }

    "mpo-on" {
        Write-Output "[*] Disabling Multi-Plane Overlay and enabling Windowed Optimizations..."
        Backup-RegistryPath -Action $Action -Paths @(
            "Registry::HKLM\SOFTWARE\Microsoft\Windows\Dwm",
            "Registry::HKCU\Software\Microsoft\DirectX\UserGpuPreferences"
        )
        # Disable MPO (OverlayTestMode=5) to reduce flicker/stutter on VRR/multi-monitor setups.
        Set-RegDword -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode" -Value 5
        Set-RegSz -Path "Registry::HKCU\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -Value "VRROptimizeEnable=1;SwapEffectUpgradeEnable=1;"
        Write-Output "[+] SUCCESS: MPO disabled (restart required)"
        Exit-PTW
    }

    "mpo-default" {
        Write-Output "[*] Restoring Multi-Plane Overlay to Windows default..."
        # Remove the OverlayTestMode value so the Windows default (MPO enabled) is restored.
        Remove-RegValue -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode"
        Remove-RegValue -Path "Registry::HKCU\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings"
        Write-Output "[+] SUCCESS: MPO restored to default (restart required)"
        Exit-PTW
    }

    "hags-on" {
        Write-Output "[*] Enabling Hardware-Accelerated GPU Scheduling..."
        try {
            Backup-RegistryPath -Action $Action -Paths @("Registry::HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers")
            Set-RegDword -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2
            Write-Output "[+] SUCCESS: Hardware-Accelerated GPU Scheduling enabled (restart required)"
            Exit-PTW
        } catch {
            Write-Output "[-] ERROR: Could not enable Hardware-Accelerated GPU Scheduling: $($_.Exception.Message)"
            exit 1
        }
    }

    "hags-off" {
        Write-Output "[*] Restoring Hardware-Accelerated GPU Scheduling to the Windows default..."
        try {
            Remove-RegValue -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode"
            Write-Output "[+] SUCCESS: Hardware-Accelerated GPU Scheduling override removed (restart required)"
            Exit-PTW
        } catch {
            Write-Output "[-] ERROR: Could not disable Hardware-Accelerated GPU Scheduling: $($_.Exception.Message)"
            exit 1
        }
    }

    "game-mode-on" {
        Write-Output "[*] Enabling Windows Game Mode..."
        try {
            Backup-RegistryPath -Action $Action -Paths @("Registry::HKCU\Software\Microsoft\GameBar")
            Set-RegDword -Path "Registry::HKCU\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1
            Set-RegDword -Path "Registry::HKCU\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1
            Write-Output "[+] SUCCESS: Windows Game Mode enabled"
            Exit-PTW
        } catch {
            Write-Output "[-] ERROR: Could not enable Windows Game Mode: $($_.Exception.Message)"
            exit 1
        }
    }

    "game-mode-off" {
        Write-Output "[*] Restoring the Windows 11 Game Mode default..."
        try {
            Remove-RegValue -Path "Registry::HKCU\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled"
            Remove-RegValue -Path "Registry::HKCU\Software\Microsoft\GameBar" -Name "AllowAutoGameMode"
            Write-Output "[+] SUCCESS: Windows Game Mode overrides removed"
            Exit-PTW
        } catch {
            Write-Output "[-] ERROR: Could not disable Windows Game Mode: $($_.Exception.Message)"
            exit 1
        }
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
