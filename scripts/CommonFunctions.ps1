# Common Functions

# Use UTF-8 console output when a console host is available.
try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
} catch {
    Write-Verbose "Could not set UTF-8 console output: $($_.Exception.Message)"
}

#region Pinned download URLs
# Pin third-party downloads to checksums in file-checksums.json.
$script:PTWDownloadUrls = @{
    SevenZip                 = 'https://www.7-zip.org/a/7z2501-x64.exe'
    NvidiaProfileInspector   = 'https://github.com/Orbmu2k/nvidiaProfileInspector/releases/download/2.4.0.31/nvidiaProfileInspector.zip'
    DisplayDriverUninstaller = 'https://www.wagnardsoft.com/DDU/download/DDU%20v18.1.4.0.exe'
}
#endregion

#region Runtime paths
$script:PTWRuntimeDir = if ($env:PTW_EMBEDDED -eq '1') {
    if (-not $env:PTW_SCRIPTS_DIR -or -not $env:PTW_RUNTIME_DIR) {
        throw 'PTW runtime paths were not provided by the application.'
    }

    $scriptsFull = [IO.Path]::GetFullPath($env:PTW_SCRIPTS_DIR).TrimEnd('\', '/')
    $runtimeFull = [IO.Path]::GetFullPath($env:PTW_RUNTIME_DIR)
    $scriptsPrefix = $scriptsFull + [IO.Path]::DirectorySeparatorChar
    if (-not $runtimeFull.StartsWith($scriptsPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'PTW runtime directory is outside the protected scripts directory.'
    }
    $runtimeFull
} else {
    Join-Path $env:TEMP ("PleaseTweakWindows-runtime-" + [Guid]::NewGuid().ToString('N'))
}

function Get-PTWRuntimePath {
    param([Parameter(Mandatory)][string]$Name)

    $runtimeFull = [IO.Path]::GetFullPath($script:PTWRuntimeDir).TrimEnd('\', '/')
    $path = [IO.Path]::GetFullPath((Join-Path $runtimeFull $Name))
    $runtimePrefix = $runtimeFull + [IO.Path]::DirectorySeparatorChar
    if (-not $path.StartsWith($runtimePrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Runtime path escapes the protected directory: $Name"
    }
    if (-not (Test-Path -LiteralPath $runtimeFull)) {
        New-Item -ItemType Directory -Path $runtimeFull -Force -ErrorAction Stop | Out-Null
    }
    return $path
}

$script:PTWStateDir = if ($env:PTW_EMBEDDED -eq '1') {
    if (-not $env:PTW_STATE_DIR) {
        throw 'PTW protected state directory was not provided by the application.'
    }
    $stateFull = [IO.Path]::GetFullPath($env:PTW_STATE_DIR).TrimEnd('\', '/')
    $stateItem = Get-Item -LiteralPath $stateFull -Force -ErrorAction Stop
    if ($stateItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'PTW protected state directory is a reparse point.'
    }
    $stateFull
} else {
    $programData = [Environment]::GetFolderPath('CommonApplicationData')
    if ([string]::IsNullOrWhiteSpace($programData)) {
        throw 'Could not resolve ProgramData for protected PTW state.'
    }

    $productDir = Join-Path $programData 'PleaseTweakWindows'
    $existingProduct = Get-Item -LiteralPath $productDir -Force -ErrorAction SilentlyContinue
    if ($existingProduct -and ($existingProduct.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Protected PTW state parent is a reparse point: $productDir"
    }
    New-Item -ItemType Directory -Path $productDir -Force -ErrorAction Stop | Out-Null

    $stateDir = Join-Path $productDir 'state'
    $existingState = Get-Item -LiteralPath $stateDir -Force -ErrorAction SilentlyContinue
    if ($existingState -and ($existingState.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Protected PTW state path is a reparse point: $stateDir"
    }
    New-Item -ItemType Directory -Path $stateDir -Force -ErrorAction Stop | Out-Null
    & icacls.exe "$stateDir" /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not secure PTW state directory (icacls exit $LASTEXITCODE): $stateDir"
    }
    [IO.Path]::GetFullPath($stateDir).TrimEnd('\', '/')
}

function Get-PTWStatePath {
    param([Parameter(Mandatory)][string]$Name)

    $stateFull = [IO.Path]::GetFullPath($script:PTWStateDir).TrimEnd('\', '/')
    $path = [IO.Path]::GetFullPath((Join-Path $stateFull $Name))
    $statePrefix = $stateFull + [IO.Path]::DirectorySeparatorChar
    if (-not $path.StartsWith($statePrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "State path escapes the protected directory: $Name"
    }
    return $path
}
#endregion

#region Wait-ForUser (PTW_EMBEDDED aware)
function Wait-ForUser {
    param([string]$Prompt = 'Press any key to continue...')
    
    if ($env:PTW_EMBEDDED -eq '1') {
        return
    }
    
    if ($Host -and $Host.UI -and $Host.UI.RawUI) {
        try {
            Write-Output $Prompt
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        } catch {
            Write-Verbose "Console ReadKey not available; falling back to Read-Host."
        }
    }
    Read-Host $Prompt | Out-Null
}
#endregion

#region Logging
function Write-PTWLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) { "INFO" { "[*]" } "SUCCESS" { "[+]" } "WARNING" { "[!]" } "ERROR" { "[-]" } default { "[*]" } }
    Write-Output "$timestamp $prefix $Message"
}

function Write-PTWSuccess { param([string]$Text) Write-Output "[+] $Text" }
function Write-PTWWarning { param([string]$Text) Write-Output "[!] $Text" }
function Write-PTWError { param([string]$Text) Write-Output "[-] $Text" }
#endregion

#region Detailed File Logging (file-only, not visible in GUI)
# Write detailed daily logs when running in embedded mode.
$script:PTWDetailLogFile = $null

function Write-PTWDetail {
    param([string]$Message, [string]$Level = "INFO")
    if (-not $script:PTWDetailLogFile) { return }
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    "$ts [$Level] $Message" | Add-Content -LiteralPath $script:PTWDetailLogFile -Encoding UTF8 -ErrorAction SilentlyContinue
}

if ($env:PTW_EMBEDDED -eq '1' -and $env:PTW_LOG_DIR) {
    $dateStamp = Get-Date -Format "yyyy-MM-dd"
    $script:PTWDetailLogFile = Join-Path $env:PTW_LOG_DIR "PleaseTweakWindows-detail-$dateStamp.log"

    try {
        $cutoff = (Get-Date).AddDays(-14)
        Get-ChildItem -LiteralPath $env:PTW_LOG_DIR -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^PleaseTweakWindows-(detail|transcript)-.*\.log$' -and $_.LastWriteTime -lt $cutoff } |
            Remove-Item -Force -ErrorAction SilentlyContinue
        # Prune convenience snapshots without touching protected rollback state.
        $backupCutoff = (Get-Date).AddDays(-30)
        $registryBackupPath = Join-Path $env:PTW_LOG_DIR 'registry-backups'
        Get-ChildItem -LiteralPath $registryBackupPath -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $backupCutoff } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Verbose "Log retention cleanup failed: $($_.Exception.Message)"
    }

    # Enable full PowerShell transcripts only when PTW_TRANSCRIPT=1.
    if ($env:PTW_TRANSCRIPT -eq '1') {
        $script:PTWTranscriptFile = Join-Path $env:PTW_LOG_DIR "PleaseTweakWindows-transcript-$dateStamp.log"
        try {
            Start-Transcript -Path $script:PTWTranscriptFile -Append -Force | Out-Null
        } catch {
            Write-Verbose "PowerShell transcript could not start: $($_.Exception.Message)"
        }
    }

    # Log session header — the calling script name is derived from the call stack
    $callerScript = try { (Get-PSCallStack | Where-Object { $_.ScriptName -and $_.ScriptName -ne $MyInvocation.MyCommand.Path } | Select-Object -First 1).ScriptName } catch { $null }
    if (-not $callerScript) { $callerScript = $MyInvocation.ScriptName }
    $callerName = if ($callerScript) { [System.IO.Path]::GetFileName($callerScript) } else { "unknown" }
    Write-PTWDetail "================================================================"
    Write-PTWDetail "Script: $callerName | PID: $PID"
    Write-PTWDetail "================================================================"
}
#endregion

#region Network Helpers
function Get-ActiveAdapter {
    Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notlike '*Virtual*' -and $_.Name -notlike '*vEthernet*' }
}
#endregion

#region File Helpers
function Import-RegistryFile {
    param([Parameter(Mandatory=$true)][string]$RegFile)
    Write-PTWDetail "IMPORT registry file: $RegFile"
    if (-not (Test-Path $RegFile)) {
        Write-PTWDetail "  SKIP (file not found)"
        return $false
    }

    # Verify registry payload integrity before importing it into HKLM.
    if (-not (Test-PtwFileChecksum -Path $RegFile)) {
        Write-PTWError "Registry file integrity check FAILED for $RegFile. Refusing to import."
        $script:PTWErrorCount++
        return $false
    }

    # Use reg.exe so registry import failures return a non-zero exit code.
    & reg.exe import "$RegFile" 2>&1 | Out-Null
    $success = ($LASTEXITCODE -eq 0)
    Write-PTWDetail "  $(if ($success) { 'OK' } else { "FAILED (exit code $LASTEXITCODE)" })"
    if (-not $success) { $script:PTWErrorCount++ }
    return $success
}
#endregion

#region Registry Helpers (Safe)
# Track failed registry mutations for dispatcher exit codes.
$script:PTWErrorCount = 0

# Dispatchers can call this in place of `exit 0` to signal failure when any helper failed.
function Exit-PTW {
    if ($script:PTWErrorCount -gt 0) { exit 1 } else { exit 0 }
}

function ConvertTo-PSDrivePath {
    param([string]$Path)
    if ($Path -match '^Registry::(.+)$') {
        $inner = $Matches[1]
        if ($inner -match '^(HKLM|HKCU|HKCR|HKU|HKCC)\\(.*)$') {
            return "$($Matches[1]):\$($Matches[2])"
        }
    }
    # Handle bare HKEY_* paths (e.g. from Get-ChildItem .Name on registry keys)
    if ($Path -match '^HKEY_LOCAL_MACHINE\\(.*)$') { return "HKLM:\$($Matches[1])" }
    if ($Path -match '^HKEY_CURRENT_USER\\(.*)$') { return "HKCU:\$($Matches[1])" }
    if ($Path -match '^HKEY_CLASSES_ROOT\\(.*)$') { return "HKCR:\$($Matches[1])" }
    return $Path
}

function Set-RegValueSafe {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('DWord','QWord','String','ExpandString','MultiString','Binary')][string]$Type,
        [Parameter(Mandatory)]$Value
    )
    $Path = ConvertTo-PSDrivePath $Path
    Write-PTWDetail "SET $Type $Path\$Name = $Value"
    try {
        if ($PSCmdlet.ShouldProcess("$Path\\$Name", "Set registry value")) {
            if (-not (Test-Path -LiteralPath $Path)) {
                New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
                Write-PTWDetail "  Created registry key: $Path"
            }
            New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force -ErrorAction Stop | Out-Null
            Write-PTWDetail "  OK"
        }
    } catch {
        $script:PTWErrorCount++
        Write-PTWDetail "  FAILED: $($_.Exception.Message)" "ERROR"
        Write-Warning "Failed to set ${Path}\\${Name}: $($_.Exception.Message)"
    }
}

function Set-RegDword {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Value
    )
    Set-RegValueSafe -Path $Path -Name $Name -Type DWord -Value $Value
}

function Set-RegSz {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value
    )
    Set-RegValueSafe -Path $Path -Name $Name -Type String -Value $Value
}

function Remove-RegValueSafe {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )
    $Path = ConvertTo-PSDrivePath $Path
    Write-PTWDetail "REMOVE value $Path\$Name"
    # Treat an already-absent registry value as a successful restore.
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-PTWDetail "  SKIP (key not found - already default)"
        return
    }
    if ($null -eq (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue)) {
        Write-PTWDetail "  SKIP (value not found - already default)"
        return
    }
    try {
        if ($PSCmdlet.ShouldProcess("$Path\\$Name", "Remove registry value")) {
            Remove-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
            Write-PTWDetail "  OK (removed)"
        }
    } catch {
        $script:PTWErrorCount++
        Write-PTWDetail "  FAILED: $($_.Exception.Message)" "ERROR"
        Write-Warning "Failed to remove ${Path}\\${Name}: $($_.Exception.Message)"
    }
}

function Remove-RegValue {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )
    Remove-RegValueSafe -Path $Path -Name $Name
}

function Remove-RegKeySafe {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(Mandatory)][string]$Path)
    $Path = ConvertTo-PSDrivePath $Path
    Write-PTWDetail "REMOVE key $Path"
    # Treat an already-absent registry key as a successful restore.
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-PTWDetail "  SKIP (key not found - already default)"
        return
    }
    try {
        if ($PSCmdlet.ShouldProcess($Path, "Remove registry key")) {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            Write-PTWDetail "  OK (key removed)"
        }
    } catch {
        $script:PTWErrorCount++
        Write-PTWDetail "  FAILED: $($_.Exception.Message)" "ERROR"
        Write-Warning "Failed to remove key ${Path}: $($_.Exception.Message)"
    }
}

function Remove-RegKey {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(Mandatory)][string]$Path)
    Remove-RegKeySafe -Path $Path
}

function Set-RegistryDefaultValueSafe {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Value
    )
    $Path = ConvertTo-PSDrivePath $Path
    Write-PTWDetail "SET default $Path\(Default) = $Value"
    try {
        if ($PSCmdlet.ShouldProcess("$Path\\(Default)", "Set registry default value")) {
            if (-not (Test-Path -LiteralPath $Path)) {
                New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
                Write-PTWDetail "  Created registry key: $Path"
            }
            New-ItemProperty -Path $Path -Name '(Default)' -PropertyType String -Value $Value -Force -ErrorAction Stop | Out-Null
            Write-PTWDetail "  OK"
        }
    } catch {
        $script:PTWErrorCount++
        Write-PTWDetail "  FAILED: $($_.Exception.Message)" "ERROR"
        Write-Warning "Failed to set default value for ${Path}: $($_.Exception.Message)"
    }
}
#endregion

#region Shared Security Helpers
# Shared by the split security categories.

function Test-DefenderTamperProtected {
    # Detect Tamper Protection before applying Defender preferences.
    try {
        return [bool](Get-MpComputerStatus -ErrorAction Stop).IsTamperProtected
    } catch {
        return $false
    }
}

function Disable-ClipboardService {
    foreach ($svcName in @('cbdhsvc')) {
        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc) {
                if ($svc.Status -ne 'Stopped') {
                    Stop-Service -Name $svcName -Force -ErrorAction Stop
                }
                Set-Service -Name $svcName -StartupType Disabled -ErrorAction Stop
            }
        } catch {
            $script:PTWErrorCount++
            Write-Warning "[WARN] Service disable failed for ${svcName}: $($_.Exception.Message)"
        }
    }

    try {
        Get-Service -Name 'cbdhsvc_*' -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                if ($_.Status -ne 'Stopped') {
                    Stop-Service -Name $_.Name -Force -ErrorAction Stop
                }
                Set-Service -Name $_.Name -StartupType Disabled -ErrorAction Stop
            } catch {
                $script:PTWErrorCount++
                Write-Warning "Failed to disable service $($_.Name): $($_.Exception.Message)"
            }
        }
    } catch {
        $script:PTWErrorCount++
        Write-Warning "Failed to enumerate cbdhsvc_* services: $($_.Exception.Message)"
    }
}

function Disable-OptionalFeaturesSafe {
    param([string[]]$Names)
    foreach ($f in $Names) {
        try {
            $feat = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction Stop
            if ($feat -and $feat.State -ne 'Disabled') {
                Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -ErrorAction Stop | Out-Null
            }
        } catch {
            Write-Warning "[WARN] Optional feature op failed for ${f}: $($_.Exception.Message)"
            $script:PTWErrorCount++
        }
    }
}

function Remove-WindowsCapabilitiesSafe {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([string[]]$Patterns)
    foreach ($capPattern in $Patterns) {
        try {
            Get-WindowsCapability -Online -Name $capPattern -ErrorAction Stop |
                Where-Object { $_.State -ne 'NotPresent' } |
                ForEach-Object {
                    if ($PSCmdlet.ShouldProcess($_.Name, "Remove Windows capability")) {
                        Remove-WindowsCapability -Online -Name $_.Name -ErrorAction Stop | Out-Null
                    }
                }
        } catch {
            Write-Warning "[WARN] Capability remove failed for ${capPattern}: $($_.Exception.Message)"
            $script:PTWErrorCount++
        }
    }
}

# Apply Defender preferences individually for compatibility with older builds.
function Invoke-MpPrefSafe {
    param([Parameter(Mandatory)][hashtable]$Pref)
    try {
        Set-MpPreference @Pref -ErrorAction Stop
    } catch {
        Write-PTWLog "Defender setting not applied (may be unsupported on this build): $($Pref.Keys -join ',') -> $($_.Exception.Message)" "WARNING"
        $script:PTWErrorCount++
    }
}

function Enable-ServiceSafe {
    param([string[]]$Names, [ValidateSet('Automatic','Manual')][string]$StartupType = 'Manual')
    foreach ($name in $Names) {
        try {
            $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
            if ($svc) {
                Set-Service -Name $name -StartupType $StartupType -ErrorAction Stop
                if ($svc.Status -ne 'Running') {
                    Start-Service -Name $name -ErrorAction Stop
                }
            }
        } catch {
            Write-PTWLog "Failed to enable/start service ${name}: $($_.Exception.Message)" "WARNING"
            $script:PTWErrorCount++
        }
    }
}

function Enable-OptionalFeaturesSafe {
    param([string[]]$Names)
    foreach ($f in $Names) {
        try {
            $feat = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction Stop
            if ($feat -and $feat.State -ne 'Enabled') {
                Enable-WindowsOptionalFeature -Online -FeatureName $f -All -NoRestart -ErrorAction Stop | Out-Null
            }
        } catch {
            Write-PTWLog "Optional feature op failed for ${f}: $($_.Exception.Message)" "WARNING"
            $script:PTWErrorCount++
        }
    }
}

function Add-WindowsCapabilitiesSafe {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([string[]]$Patterns)

    foreach ($capPattern in $Patterns) {
        try {
            Get-WindowsCapability -Online -Name $capPattern -ErrorAction Stop |
                Where-Object { $_.State -eq 'NotPresent' } |
                ForEach-Object {
                    if ($PSCmdlet.ShouldProcess($_.Name, "Add Windows capability")) {
                        Add-WindowsCapability -Online -Name $_.Name -ErrorAction Stop | Out-Null
                    }
                }
        } catch {
            Write-PTWLog "Capability op failed for pattern ${capPattern}: $($_.Exception.Message)" "WARNING"
            $script:PTWErrorCount++
        }
    }
}
#endregion

#region Transaction Support
function Start-PTWTransaction {
    $script:PTWTransactionEntries = @()
    Write-Verbose "PTW Transaction started"
    Write-PTWDetail "TRANSACTION started"
}

function Save-RegState {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )
    $entry = @{ Path = $Path; Name = $Name; Existed = $false; PreviousValue = $null; PreviousType = $null; KeyExisted = $false }
    try {
        $entry.KeyExisted = [bool](Test-Path -LiteralPath $Path)
        if ($entry.KeyExisted) {
            $prop = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($null -ne $prop -and $null -ne $prop.$Name) {
                $entry.Existed = $true
                $entry.PreviousValue = $prop.$Name
                $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
                if ($item) {
                    $entry.PreviousType = $item.GetValueKind($Name).ToString()
                }
            }
        }
    } catch {
        Write-Verbose "Save-RegState: Could not read ${Path}\${Name}: $($_.Exception.Message)"
    }
    $script:PTWTransactionEntries += $entry
}

function Set-RegValueSafeTx {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('DWord','QWord','String','ExpandString','MultiString','Binary')][string]$Type,
        [Parameter(Mandatory)]$Value
    )
    Save-RegState -Path $Path -Name $Name
    Set-RegValueSafe -Path $Path -Name $Name -Type $Type -Value $Value
}

function Undo-PTWTransaction {
    if (-not $script:PTWTransactionEntries) {
        Write-Verbose "No transaction entries to undo"
        return
    }
    Write-Output "[!] Rolling back registry changes..."
    $reversed = @($script:PTWTransactionEntries)
    [Array]::Reverse($reversed)
    foreach ($entry in $reversed) {
        try {
            if ($entry.Existed -and $entry.PreviousType) {
                Set-RegValueSafe -Path $entry.Path -Name $entry.Name -Type $entry.PreviousType -Value $entry.PreviousValue
                Write-Verbose "Restored: $($entry.Path)\$($entry.Name)"
            } else {
                # Remove values whose original registry type is unknown.
                Remove-RegValueSafe -Path $entry.Path -Name $entry.Name
                Write-Verbose "Removed value: $($entry.Path)\$($entry.Name)"
            }
            # Remove empty keys created by the transaction.
            if (-not $entry.KeyExisted) {
                $key = Get-Item -LiteralPath $entry.Path -ErrorAction SilentlyContinue
                if ($key -and $key.ValueCount -eq 0 -and $key.SubKeyCount -eq 0) {
                    Remove-RegKeySafe -Path $entry.Path
                    Write-Verbose "Removed empty key created by transaction: $($entry.Path)"
                }
            }
        } catch {
            Write-Warning "Rollback failed for $($entry.Path)\$($entry.Name): $($_.Exception.Message)"
        }
    }
    Write-Output "[+] Rollback completed ($($reversed.Count) entries)"
    Write-PTWDetail "TRANSACTION rollback completed ($($reversed.Count) entries)"
}

function Stop-PTWTransaction {
    $script:PTWTransactionEntries = $null
    Write-Verbose "PTW Transaction stopped"
    Write-PTWDetail "TRANSACTION stopped"
}
#endregion

#region GPU Registry Helpers
function Get-GpuClassKeysByVendor {
    param(
        [Parameter(Mandatory)][ValidateSet('NVIDIA','AMD')][string]$Vendor
    )
    $classPath = "Registry::HKLM\\SYSTEM\\CurrentControlSet\\Control\\Class\\{4d36e968-e325-11ce-bfc1-08002be10318}"
    if (-not (Test-Path $classPath)) { return @() }

    $vendorId = if ($Vendor -eq 'NVIDIA') { 'VEN_10DE' } else { 'VEN_1002' }
    $vendorName = if ($Vendor -eq 'NVIDIA') { 'NVIDIA' } else { 'AMD|Advanced Micro Devices|Radeon' }

    $keys = @()
    foreach ($key in Get-ChildItem -Path $classPath -Force -ErrorAction SilentlyContinue) {
        if ($key.Name -like '*Configuration') { continue }
        try {
            $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
        } catch { continue }

        $ids = @()
        if ($props.MatchingDeviceId) { $ids += $props.MatchingDeviceId }
        if ($props.HardwareID) { $ids += $props.HardwareID }

        $hasVendor = $false
        foreach ($id in $ids) {
            if ($id -match $vendorId) { $hasVendor = $true; break }
        }
        if (-not $hasVendor) {
            $desc = @($props.DriverDesc, $props.ProviderName) -join ' '
            if ($desc -match $vendorName) { $hasVendor = $true }
        }

        if ($hasVendor) {
            $keys += $key.Name
            Write-PTWDetail "  Found $Vendor GPU key: $($key.Name)"
        }
    }
    Write-PTWDetail "GPU scan for $Vendor complete: $($keys.Count) key(s) found"
    return $keys
}
#endregion

#region File Download with Checksum Verification

# Runtime cache for dynamic file checksums (persisted per session)
$script:RuntimeChecksumCache = @{}

function Get-ChecksumFromFile {
    param ([Parameter(Mandatory)][string]$URL)

    $scriptsRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path -Parent }
    $checksumFile = Join-Path $scriptsRoot "file-checksums.json"
    
    if (Test-Path $checksumFile) {
        try {
            $checksumData = Get-Content $checksumFile -Raw | ConvertFrom-Json
            
            # Check downloads section first
            if ($checksumData.downloads.PSObject.Properties.Name -contains $URL) {
                $hash = $checksumData.downloads.$URL
                if ($null -ne $hash -and $hash -ne "" -and $hash -ne "DYNAMIC" -and $hash -ne "REQUIRED") {
                    return $hash
                }
                if ($hash -eq "REQUIRED") {
                    return "REQUIRED"
                }
                # DYNAMIC - check runtime cache
                if ($hash -eq "DYNAMIC" -and $script:RuntimeChecksumCache.ContainsKey($URL)) {
                    Write-Verbose "Using cached checksum for dynamic file: $URL"
                    return $script:RuntimeChecksumCache[$URL]
                }
            }
        } catch {
            Write-Warning "Failed to load checksums: $($_.Exception.Message)"
        }
    }
    return $null
}

function Set-RuntimeChecksum {
    param (
        [Parameter(Mandatory)][string]$URL,
        [Parameter(Mandatory)][string]$Hash
    )
    $script:RuntimeChecksumCache[$URL] = $Hash
    Write-Verbose "Cached runtime checksum for: $URL"
}

# Verify shipped payloads against the embedded checksum manifest.
function Test-PtwFileChecksum {
    param([Parameter(Mandatory)][string]$Path)
    try {
        $scriptsRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path -Parent }
        $checksumFile = Join-Path $scriptsRoot "file-checksums.json"
        # Refuse payloads when the checksum manifest is missing.
        if (-not (Test-Path $checksumFile)) {
            Write-PTWDetail "  file-checksums.json missing; refusing to import unverified."
            return $false
        }

        $full = [System.IO.Path]::GetFullPath($Path)
        $rootFull = [System.IO.Path]::GetFullPath($scriptsRoot)
        # Reject payload paths outside the scripts root.
        $rootPrefix = $rootFull.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        if (-not $full.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-PTWDetail "  Refusing to verify a path outside the scripts root: $Path"
            return $false
        }
        $rel = ($full.Substring($rootFull.Length).TrimStart('\', '/')) -replace '\\', '/'

        $data = Get-Content $checksumFile -Raw | ConvertFrom-Json
        if (-not ($data.scripts.PSObject.Properties.Name -contains $rel)) {
            Write-PTWDetail "  No checksum entry for $rel; refusing to import unverified."
            return $false
        }
        $expected = $data.scripts.$rel
        $actual = (Get-FileHash -Path $Path -Algorithm SHA256).Hash
        if ($actual -ne $expected) {
            Write-PTWDetail "  Checksum MISMATCH for ${rel}: expected $expected, got $actual"
            return $false
        }
        Write-PTWDetail "  Checksum verified OK: $rel"
        return $true
    } catch {
        Write-PTWDetail "  Checksum verification error: $($_.Exception.Message)"
        return $false
    }
}

# Shared function for downloading files with URL validation and optional checksum verification
function Get-FileFromWeb {
    param (
        [Parameter(Mandatory)][string]$URL,
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory=$false)][string]$ExpectedHash,
        # Limit response size unless the caller provides a larger cap.
        [Parameter(Mandatory=$false)][long]$MaxBytes = 1GB
    )

    Write-PTWDetail "DOWNLOAD $URL -> $File"
    $maxDownloadBytes = $MaxBytes

    $fullFile = [IO.Path]::GetFullPath($File)
    if ($env:PTW_EMBEDDED -eq '1') {
        $runtimeFull = [IO.Path]::GetFullPath($script:PTWRuntimeDir).TrimEnd('\', '/')
        $runtimePrefix = $runtimeFull + [IO.Path]::DirectorySeparatorChar
        if (-not $fullFile.StartsWith($runtimePrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "SECURITY: Embedded downloads must stay in the protected runtime directory: $fullFile"
        }
    }
    $File = $fullFile
    # Prefer TLS 1.2 and 1.3 while remaining compatible with older .NET Framework builds.
    try {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    } catch {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    # Auto-load hash from file-checksums.json if not provided
    if (-not $ExpectedHash) {
        $ExpectedHash = Get-ChecksumFromFile -URL $URL
        if ($ExpectedHash -eq "REQUIRED") {
            throw "SECURITY: Hash verification is REQUIRED for $URL but no hash found in file-checksums.json. Update the file with actual SHA256 hash."
        }
    }

    # Validate URL - only allow HTTPS and trusted domains
    if ($URL -notmatch '^https://') {
        throw "Only HTTPS URLs are allowed for security. URL: $URL"
    }

    $trustedDomains = @(
        'microsoft.com',
        'download.microsoft.com',
        'aka.ms',
        'go.microsoft.com',
        'github.com',
        'raw.githubusercontent.com',
        # Allow GitHub release-asset CDN hosts while retaining checksum verification.
        'release-assets.githubusercontent.com',
        'objects.githubusercontent.com',
        'download.sysinternals.com',
        'oo-software.com',
        'geforce.com',
        'nvidia.com',
        '7-zip.org',
        'wagnardsoft.com',
        'amd.com'
    )

    # Validate download hosts with exact domain matching.
    try {
        $uri = [System.Uri]$URL
        $hostname = $uri.Host
        $isTrusted = $false
        foreach ($domain in $trustedDomains) {
            # Exact match or ends with trusted domain (e.g., download.microsoft.com matches microsoft.com)
            if ($hostname -eq $domain -or $hostname.EndsWith(".$domain")) {
                $isTrusted = $true
                break
            }
        }
    } catch {
        throw "Invalid URL format: $URL"
    }

    if (-not $isTrusted) {
        if ($env:PTW_EMBEDDED -eq '1') {
            # In GUI mode, block untrusted domains — scripts must be non-interactive
            throw "SECURITY: Download blocked from non-trusted domain in GUI mode: $hostname. Add the domain to the trusted list in CommonFunctions.ps1 if it is safe."
        } else {
            Write-Warning "Downloading from non-trusted domain: $URL"
            $response = Read-Host "Continue? (y/n)"
            if ($response -ne 'y') {
                throw "Download cancelled by user"
            }
        }
    }

    # Require checksums for security-sensitive third-party downloads.
    $isThirdParty = $hostname -like "*.githubusercontent.com" -or $hostname -eq 'github.com' -or $hostname -like "*.github.com"
    if ($isThirdParty -and -not $ExpectedHash) {
        throw "SECURITY: Unverified third-party download blocked. Add SHA256 hash to file-checksums.json for: $URL"
    }

    function Show-Progress {
        param (
            [Parameter(Mandatory)][Single]$TotalValue,
            [Parameter(Mandatory)][Single]$CurrentValue,
            [Parameter(Mandatory)][string]$ProgressText,
            [Parameter()][switch]$Complete
        )
        if ($TotalValue -le 0) { return }
        if ($Complete) {
            Write-Progress -Id 0 -Activity $ProgressText -Completed
            return
        }
        $percentComplete = ($CurrentValue / $TotalValue) * 100
        $status = "{0:N2}% Complete" -f $percentComplete
        Write-Progress -Id 0 -Activity $ProgressText -Status $status -PercentComplete $percentComplete
    }
    try {
        $request = [System.Net.HttpWebRequest]::Create($URL)
        $request.UserAgent = "PleaseTweakWindows/1.0"
        $request.Timeout = 30000
        $request.ReadWriteTimeout = 30000
        $response = $request.GetResponse()
        if ($response.ContentLength -gt 1GB) {
            throw "Download is unexpectedly large ($($response.ContentLength) bytes): $URL"
        }

        # Revalidate the final download host after redirects.
        $finalUri = $response.ResponseUri
        $finalHost = $finalUri.Host
        if ($finalUri.Scheme -ne 'https') {
            $response.Close()
            throw "SECURITY: download redirected to non-HTTPS URL '$finalUri'. Blocked."
        }
        $finalTrusted = $false
        foreach ($domain in $trustedDomains) {
            if ($finalHost -eq $domain -or $finalHost.EndsWith(".$domain")) { $finalTrusted = $true; break }
        }
        if (-not $finalTrusted) {
            try { $response.Close() } catch { Write-Verbose "Response close failed: $($_.Exception.Message)" }
            throw "SECURITY: download redirected to non-trusted host '$finalHost' (from $URL). Blocked."
        }
        # Apply third-party checksum requirements to the final redirected host.
        $finalThirdParty = $finalHost -like "*.githubusercontent.com" -or $finalHost -eq 'github.com' -or $finalHost -like "*.github.com"
        if ($finalThirdParty -and -not $ExpectedHash) {
            try { $response.Close() } catch { Write-Verbose "Response close failed: $($_.Exception.Message)" }
            throw "SECURITY: Unverified third-party download blocked (redirected to '$finalHost'). Add SHA256 hash to file-checksums.json for: $URL"
        }
        if ($File -match '^\.\\') { $File = Join-Path (Get-Location -PSProvider 'FileSystem') ($File -Split '^\.')[1] }
        if ($File -and !(Split-Path $File)) { $File = Join-Path (Get-Location -PSProvider 'FileSystem') $File }
        if ($File) { $fileDirectory = $([System.IO.Path]::GetDirectoryName($File)); if (!(Test-Path($fileDirectory))) { [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null } }
        [long]$fullSize = $response.ContentLength
        if ($fullSize -gt $maxDownloadBytes) {
            throw "Download is too large ($fullSize bytes; maximum $maxDownloadBytes): $URL"
        }
        [byte[]]$buffer = new-object byte[] 1048576
        [long]$total = [long]$count = 0
        if (Test-Path -LiteralPath $File) {
            Remove-Item -LiteralPath $File -Force -ErrorAction Stop
        }
        $reader = $response.GetResponseStream()
        $writer = New-Object System.IO.FileStream $File, 'CreateNew'
        do {
            $count = $reader.Read($buffer, 0, $buffer.Length)
            $writer.Write($buffer, 0, $count)
            $total += $count
            if ($total -gt $maxDownloadBytes) {
                throw "Download exceeded the $maxDownloadBytes-byte limit: $URL"
            }
            if ($fullSize -gt 0) { Show-Progress -TotalValue $fullSize -CurrentValue $total -ProgressText " $([System.IO.Path]::GetFileName($File))" }
        } while ($count -gt 0)
        if ($fullSize -gt 0) { Show-Progress -TotalValue $fullSize -CurrentValue $fullSize -ProgressText " $([System.IO.Path]::GetFileName($File))" -Complete }

        # Close streams before hash verification to release the file lock
        if ($writer) { $writer.Close(); $writer = $null }
        if ($reader) { $reader.Close(); $reader = $null }

        # Verify checksum if provided, or compute and cache for dynamic files
        $actualHash = (Get-FileHash -Path $File -Algorithm SHA256).Hash
        if ($ExpectedHash) {
            Write-Information "`nVerifying file integrity..." -InformationAction Continue
            if ($actualHash -ne $ExpectedHash) {
                Remove-Item -Path $File -Force -ErrorAction SilentlyContinue
                throw "SECURITY: File hash mismatch! Expected: $ExpectedHash, Got: $actualHash. File deleted for safety."
            }
            Write-Information "File integrity verified successfully." -InformationAction Continue
            Write-PTWDetail "  Hash verified OK: $actualHash"
        } else {
            # Cache checksum for dynamic files (for re-downloads in same session)
            Set-RuntimeChecksum -URL $URL -Hash $actualHash
            Write-Verbose "Computed checksum for dynamic file: $actualHash"
            Write-PTWDetail "  Downloaded OK, hash cached: $actualHash"
        }
    }
    catch {
        if ($writer) { try { $writer.Close() } catch { Write-Verbose "Writer close failed: $($_.Exception.Message)" }; $writer = $null }
        if ($reader) { try { $reader.Close() } catch { Write-Verbose "Reader close failed: $($_.Exception.Message)" }; $reader = $null }
        if ($File -and (Test-Path -LiteralPath $File)) {
            Remove-Item -LiteralPath $File -Force -ErrorAction SilentlyContinue
        }
        throw
    }
    finally {
        if ($reader) { $reader.Close() }
        if ($writer) { $writer.Close() }
    }
}

# Download public CIDR lists only from constrained sources and validate every entry.
function Get-CidrListFromWeb {
    param([Parameter(Mandatory)][string]$URL)

    try { $uri = [System.Uri]$URL } catch { throw "Invalid URL: $URL" }
    if ($uri.Scheme -ne 'https') { throw "Only HTTPS is allowed for CIDR lists: $URL" }
    if ($uri.Host -ne 'raw.githubusercontent.com') { throw "CIDR lists may only be fetched from raw.githubusercontent.com: $URL" }
    if ($uri.AbsolutePath -notlike '/HotCakeX/Official-IANA-IP-blocks/*') { throw "Unexpected CIDR list path: $($uri.AbsolutePath)" }

    try {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    } catch {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }

    $resp = Invoke-WebRequest -Uri $URL -UseBasicParsing -UserAgent 'PleaseTweakWindows/1.0' -TimeoutSec 30 -ErrorAction Stop
    if ($resp.RawContentLength -gt 10MB) {
        throw "CIDR response is unexpectedly large ($($resp.RawContentLength) bytes): $URL"
    }
    $lines = ($resp.Content -split "`r?`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -and ($_ -notmatch '^#') }

    # Reject invalid, catch-all, and over-broad CIDR ranges.
    $valid = New-Object System.Collections.Generic.List[string]
    $skipped = 0
    foreach ($line in $lines) {
        $parts = $line -split '/', 2
        if ($parts.Count -ne 2) { $skipped++; continue }
        $ipRef = [ref]([System.Net.IPAddress]::None)
        if (-not [System.Net.IPAddress]::TryParse($parts[0], $ipRef)) { $skipped++; continue }
        $prefix = 0
        if (-not [int]::TryParse($parts[1], [ref]$prefix)) { $skipped++; continue }
        $ip = $ipRef.Value
        if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
            # Reject IPv4 prefixes below /8 (over-broad) and the all-zero base (catch-all).
            if ($prefix -lt 8 -or $prefix -gt 32) { $skipped++; continue }
        } else {
            if ($prefix -lt 16 -or $prefix -gt 128) { $skipped++; continue }
        }
        if ($ip.ToString() -eq '0.0.0.0' -or $ip.ToString() -eq '::') { $skipped++; continue }
        $valid.Add("$($ip.ToString())/$prefix")
    }

    if ($valid.Count -lt 100 -or $valid.Count -gt 60000) {
        throw "CIDR list from $URL has an unexpected size ($($valid.Count) entries); refusing."
    }
    # A few benign bad lines are tolerated; a high invalid ratio is the real tampering signal.
    if ($skipped -gt [Math]::Max(50, [int]($valid.Count * 0.05))) {
        throw "Refusing CIDR list from ${URL}: $skipped invalid line(s) vs $($valid.Count) valid (possible tampering)."
    }

    [double]$ipv4Coverage = 0
    [double]$ipv6Coverage = 0
    foreach ($cidr in $valid) {
        $cidrParts = $cidr -split '/', 2
        $parsedAddress = [System.Net.IPAddress]::Parse($cidrParts[0])
        $parsedPrefix = [int]$cidrParts[1]
        if ($parsedAddress.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
            $ipv4Coverage += [Math]::Pow(2, 32 - $parsedPrefix)
        } else {
            $ipv6Coverage += [Math]::Pow(2, 128 - $parsedPrefix)
        }
    }
    if (($ipv4Coverage / [Math]::Pow(2, 32)) -gt 0.25 -or
        ($ipv6Coverage / [Math]::Pow(2, 128)) -gt 0.25) {
        throw "CIDR list from $URL covers an implausibly large share of the internet; refusing."
    }
    return $valid.ToArray()
}

# Verify downloaded executables against expected Authenticode publisher names.
function Test-SignedFile {
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$PublisherPatterns
    )
    if (-not (Test-Path $Path)) {
        throw "Test-SignedFile: file not found: $Path"
    }
    $sig = Get-AuthenticodeSignature -FilePath $Path
    if ($sig.Status -ne 'Valid') {
        throw "SECURITY: Authenticode signature not valid for $Path (status=$($sig.Status)). Refusing to execute."
    }
    $subject = [string]$sig.SignerCertificate.Subject
    $signerName = $sig.SignerCertificate.GetNameInfo(
        [System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
    $matched = $false
    foreach ($pattern in $PublisherPatterns) {
        if ([string]::Equals($signerName, $pattern, [StringComparison]::OrdinalIgnoreCase)) {
            $matched = $true
            break
        }
    }
    if (-not $matched) {
        throw ("SECURITY: Signer '$subject' does not match expected publisher(s): " +
               ($PublisherPatterns -join ', ') + ". Refusing to execute $Path.")
    }
    Write-PTWDetail "  Authenticode OK: $subject"
}

# Export existing registry paths to a timestamped backup before destructive changes.
function Backup-RegistryPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string[]]$Paths
    )

    $logDir = if ($env:PTW_LOG_DIR) {
        $env:PTW_LOG_DIR
    } else {
        Join-Path $env:TEMP 'PleaseTweakWindows'
    }
    $backupDir = Join-Path $logDir 'registry-backups'
    if (-not (Test-Path $backupDir)) {
        try {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        } catch {
            Write-Warning "[WARN] Could not create registry backup dir ${backupDir}: $($_.Exception.Message)"
            return
        }
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $safeAction = ($Action -replace '[^A-Za-z0-9_-]','_')
    $combined = Join-Path $backupDir "${safeAction}_${stamp}.reg"

    # Clear any stale identical-second file (very unlikely but defensive).
    if (Test-Path $combined) {
        Remove-Item -Path $combined -Force -ErrorAction SilentlyContinue
    }

    $reg = Get-Command reg.exe -ErrorAction SilentlyContinue
    if (-not $reg) {
        Write-Warning "[WARN] reg.exe not found; skipping registry backup for $Action"
        return
    }

    foreach ($p in $Paths) {
        # Convert "HKLM:\Path" → "HKLM\Path" for reg.exe.
        $regPath = $p -replace '^HKLM:\\', 'HKLM\' `
                       -replace '^HKCU:\\', 'HKCU\' `
                       -replace '^HKU:\\', 'HKU\' `
                       -replace '^HKCR:\\', 'HKCR\' `
                       -replace '^Registry::', ''

        # Skip non-existent keys silently (nothing to back up).
        $testPath = $p
        if ($testPath -notmatch '^(HKLM:|HKCU:|HKU:|HKCR:|Registry::)') {
            $testPath = "Registry::$regPath"
        }
        if (-not (Test-Path $testPath -ErrorAction SilentlyContinue)) { continue }

        $tempFile = [IO.Path]::GetTempFileName()
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        $tempFile = "$tempFile.reg"

        try {
            & $reg.Path export $regPath $tempFile /y 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0 -and (Test-Path $tempFile)) {
                # Append to combined file (strip BOM/header on subsequent appends).
                $content = Get-Content -LiteralPath $tempFile -Encoding Unicode -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    if (-not (Test-Path $combined)) {
                        # First write: keep the Windows Registry Editor header.
                        [IO.File]::WriteAllText($combined, $content, [Text.UnicodeEncoding]::new($false, $true))
                    } else {
                        # Append: strip the duplicate header line.
                        $stripped = $content -replace '^(?:\uFEFF)?Windows Registry Editor Version 5\.00\r?\n\r?\n', ''
                        [IO.File]::AppendAllText($combined, "`r`n" + $stripped, [Text.UnicodeEncoding]::new($false, $true))
                    }
                }
            }
        } catch {
            Write-Warning "[WARN] Failed to back up ${regPath}: $($_.Exception.Message)"
        } finally {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    if (Test-Path $combined) {
        Write-PTWDetail "  Registry backup: $combined"
    }
}
