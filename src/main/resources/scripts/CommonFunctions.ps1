# Common Functions
# Purpose: Shared functions used across PleaseTweakWindows scripts.
# Usage: . "$PSScriptRoot\\CommonFunctions.ps1"
# Version: 2.1.0
# Last Updated: 2026-01-18

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
# Writes detailed operation logs to a daily log file for debugging.
# Activated automatically when PTW_EMBEDDED=1 and PTW_LOG_DIR is set by the Java GUI.
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

    # Start a PowerShell transcript to capture ALL console output (Write-Output, Write-Warning,
    # Write-Error, exceptions, etc.) to a separate transcript file. This catches every direct
    # cmdlet output (services, network, apps, powercfg, etc.) that doesn't go through our helpers.
    $script:PTWTranscriptFile = Join-Path $env:PTW_LOG_DIR "PleaseTweakWindows-transcript-$dateStamp.log"
    try {
        Start-Transcript -Path $script:PTWTranscriptFile -Append -Force | Out-Null
    } catch {
        # Transcript may already be running (nested dot-source) — safe to ignore
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
    if (Test-Path $RegFile) {
        $p = Start-Process -FilePath "regedit.exe" -ArgumentList "/s", "`"$RegFile`"" -Wait -PassThru -NoNewWindow
        $success = ($p.ExitCode -eq 0)
        Write-PTWDetail "  $(if ($success) { 'OK' } else { "FAILED (exit code $($p.ExitCode))" })"
        return $success
    }
    Write-PTWDetail "  SKIP (file not found)"
    return $false
}
#endregion

#region Registry Helpers (Safe)
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
        [Parameter(Mandatory)][ValidateSet('DWord','String')][string]$Type,
        [Parameter(Mandatory)]$Value
    )
    $Path = ConvertTo-PSDrivePath $Path
    Write-PTWDetail "SET $Type $Path\$Name = $Value"
    try {
        if ($PSCmdlet.ShouldProcess("$Path\\$Name", "Set registry value")) {
            if (-not (Test-Path -LiteralPath $Path)) {
                New-Item -Path $Path -Force | Out-Null
                Write-PTWDetail "  Created registry key: $Path"
            }
            New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force | Out-Null
            Write-PTWDetail "  OK"
        }
    } catch {
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
    try {
        if (Test-Path -LiteralPath $Path) {
            $has = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($null -ne $has) {
                if ($PSCmdlet.ShouldProcess("$Path\\$Name", "Remove registry value")) {
                    Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
                    Write-PTWDetail "  OK (removed)"
                }
            } else {
                Write-PTWDetail "  SKIP (value not found)"
            }
        } else {
            Write-PTWDetail "  SKIP (key not found)"
        }
    } catch {
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
    try {
        if (Test-Path -LiteralPath $Path) {
            if ($PSCmdlet.ShouldProcess($Path, "Remove registry key")) {
                Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
                Write-PTWDetail "  OK (key removed)"
            }
        } else {
            Write-PTWDetail "  SKIP (key not found)"
        }
    } catch {
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
                New-Item -Path $Path -Force | Out-Null
                Write-PTWDetail "  Created registry key: $Path"
            }
            New-ItemProperty -Path $Path -Name '(Default)' -PropertyType String -Value $Value -Force | Out-Null
            Write-PTWDetail "  OK"
        }
    } catch {
        Write-PTWDetail "  FAILED: $($_.Exception.Message)" "ERROR"
        Write-Warning "Failed to set default value for ${Path}: $($_.Exception.Message)"
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
    $entry = @{ Path = $Path; Name = $Name; Existed = $false; PreviousValue = $null; PreviousType = $null }
    try {
        if (Test-Path -LiteralPath $Path) {
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
        [Parameter(Mandatory)][ValidateSet('DWord','String')][string]$Type,
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
            if ($entry.Existed) {
                $type = if ($entry.PreviousType -eq 'DWord') { 'DWord' } else { 'String' }
                Set-RegValueSafe -Path $entry.Path -Name $entry.Name -Type $type -Value $entry.PreviousValue
                Write-Verbose "Restored: $($entry.Path)\$($entry.Name)"
            } else {
                Remove-RegValueSafe -Path $entry.Path -Name $entry.Name
                Write-Verbose "Removed new value: $($entry.Path)\$($entry.Name)"
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
            
            # Legacy: check checksums section
            if ($checksumData.PSObject.Properties.Name -contains "checksums") {
                if ($checksumData.checksums.PSObject.Properties.Name -contains $URL) {
                    $hash = $checksumData.checksums.$URL
                    if ($null -ne $hash -and $hash -ne "" -and $hash -ne "DYNAMIC" -and $hash -ne "REQUIRED") {
                        return $hash
                    }
                    if ($hash -eq "REQUIRED") {
                        return "REQUIRED"
                    }
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

# Shared function for downloading files with URL validation and optional checksum verification
function Get-FileFromWeb {
    param (
        [Parameter(Mandatory)][string]$URL,
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory=$false)][string]$ExpectedHash
    )

    Write-PTWDetail "DOWNLOAD $URL -> $File"
    # Force TLS 1.2/1.3 for secure downloads (required by most modern servers)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
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
        'msedge.sf.dl.delivery.mp.microsoft.com',
        'go.microsoft.com',
        'github.com',
        'raw.githubusercontent.com',
        'download.sysinternals.com',
        'oo-software.com',
        'geforce.com',
        'nvidia.com',
        '7-zip.org',
        'wagnardsoft.com',
        'amd.com'
    )

    # Use exact domain matching to prevent bypass via subdomain attacks
    # Extract hostname from URL
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
        Write-Warning "Downloading from non-trusted domain: $URL"

        # In embedded mode (GUI), auto-accept non-trusted domains with warning
        if ($env:PTW_EMBEDDED -eq '1') {
            Write-Warning "Auto-accepting download in GUI mode (PTW_EMBEDDED=1)"
        } else {
            $response = Read-Host "Continue? (y/n)"
            if ($response -ne 'y') {
                throw "Download cancelled by user"
            }
        }
    }

    # For security-critical downloads from third-party sources (e.g., GitHub user repos),
    # require explicit hash verification to prevent supply-chain attacks
    $isThirdParty = $hostname -like "*.githubusercontent.com" -or $hostname -like "*.github.com"
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
        $response = $request.GetResponse()
        if ($File -match '^\.\\') { $File = Join-Path (Get-Location -PSProvider 'FileSystem') ($File -Split '^\.')[1] }
        if ($File -and !(Split-Path $File)) { $File = Join-Path (Get-Location -PSProvider 'FileSystem') $File }
        if ($File) { $fileDirectory = $([System.IO.Path]::GetDirectoryName($File)); if (!(Test-Path($fileDirectory))) { [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null } }
        [long]$fullSize = $response.ContentLength
        [byte[]]$buffer = new-object byte[] 1048576
        [long]$total = [long]$count = 0
        $reader = $response.GetResponseStream()
        $writer = new-object System.IO.FileStream $File, 'Create'
        do {
            $count = $reader.Read($buffer, 0, $buffer.Length)
            $writer.Write($buffer, 0, $count)
            $total += $count
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
    finally {
        if ($reader) { $reader.Close() }
        if ($writer) { $writer.Close() }
    }
}
