# Create Restore Point
#Requires -RunAsAdministrator

param (
    [string]$Description = "PleaseTweakWindows - Manual Restore Point"
)

# Validate parameters
if (-not $Description) {
    Write-Output "[-] ERROR: Description is required."
    exit 1
}

$vssWasRunning = $false
$vssOriginalStartType = $null

# Start VSS temporarily if needed.
try {
    $vss = Get-Service "VSS" -ErrorAction SilentlyContinue
    if ($vss) {
        $vssWasRunning = $vss.Status -eq 'Running'
        $vssOriginalStartType = $vss.StartType
        if ($vss.Status -ne 'Running') {
            Write-Output "[*] Starting Volume Shadow Copy Service (VSS)..."
            if ($vss.StartType -eq 'Disabled') {
                Set-Service -Name "VSS" -StartupType Manual -ErrorAction Stop
            }
            Start-Service -Name "VSS" -ErrorAction Stop
            Write-Output "[+] VSS service started successfully"
        } else {
            Write-Output "[*] VSS service is already running"
        }
    } else {
        Write-Output "[!] WARNING: VSS service not found on this system"
    }
} catch {
    Write-Output "[!] WARNING: Could not start VSS service: $($_.Exception.Message)"
    Write-Output "[*] Attempting to create restore point anyway..."
}

# Enable System Protection when possible; this is required for restore points.
try {
    Write-Output "[*] Ensuring System Protection is enabled for $env:SystemDrive..."
    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
} catch {
    Write-Output "[!] WARNING: Could not enable System Protection: $($_.Exception.Message)"
}

$frequencyPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
$frequencyName = 'SystemRestorePointCreationFrequency'
$frequencyExisted = $false
$frequencyOriginal = $null
try {
    $frequencyProperties = Get-ItemProperty -Path $frequencyPath -ErrorAction Stop
    $frequencyExisted = $frequencyProperties.PSObject.Properties.Name -contains $frequencyName
    if ($frequencyExisted) {
        $frequencyOriginal = $frequencyProperties.$frequencyName
    }
    New-ItemProperty -Path $frequencyPath -Name $frequencyName -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
} catch {
    Write-Output "[!] WARNING: Could not clear restore point frequency throttle: $($_.Exception.Message)"
}

$succeeded = $false
try {
    Write-Output "[*] Creating restore point: $Description"
    $beforeSequence = Get-ComputerRestorePoint -ErrorAction SilentlyContinue |
        Measure-Object -Property SequenceNumber -Maximum |
        Select-Object -ExpandProperty Maximum
    if ($null -eq $beforeSequence) { $beforeSequence = -1 }
    Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    $afterSequence = $beforeSequence
    for ($attempt = 0; $attempt -lt 10 -and $afterSequence -le $beforeSequence; $attempt++) {
        Start-Sleep -Seconds 1
        $afterSequence = Get-ComputerRestorePoint -ErrorAction SilentlyContinue |
            Measure-Object -Property SequenceNumber -Maximum |
            Select-Object -ExpandProperty Maximum
        if ($null -eq $afterSequence) { $afterSequence = -1 }
    }
    if ($afterSequence -le $beforeSequence) {
        throw "Checkpoint-Computer returned but no new restore point appeared."
    }
    $succeeded = $true
    Write-Output "[+] SUCCESS: Restore point created successfully!"
} catch {
    Write-Output "[-] ERROR: Failed to create restore point: $($_.Exception.Message)"
    Write-Output "[!] Common causes:"
    Write-Output "    - System Protection is disabled for this drive"
    Write-Output "    - Not enough disk space (requires at least 300MB free)"
    Write-Output "    - A restore point was created too recently (Windows limits frequency)"
    Write-Output "    - Volume Shadow Copy Service (VSS) is not functioning"
} finally {
    try {
        if ($frequencyExisted) {
            New-ItemProperty -Path $frequencyPath -Name $frequencyName -Value $frequencyOriginal -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        } else {
            Remove-ItemProperty -Path $frequencyPath -Name $frequencyName -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Output "[!] WARNING: Could not restore the restore-point frequency setting: $($_.Exception.Message)"
    }

    try {
        if ($vssOriginalStartType) {
            if (-not $vssWasRunning) {
                Stop-Service -Name "VSS" -Force -ErrorAction SilentlyContinue
            }
            Set-Service -Name "VSS" -StartupType $vssOriginalStartType -ErrorAction Stop
        }
    } catch {
        Write-Output "[!] WARNING: Could not restore the original VSS state: $($_.Exception.Message)"
    }
}

if ($succeeded) { exit 0 }
exit 1
