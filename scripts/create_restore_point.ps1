# Create Restore Point
# Purpose: Create a manual restore point for PleaseTweakWindows.
# Usage: powershell -File create_restore_point.ps1 -Description "<text>"
# Version: 2.1.0
# Last Updated: 2026-01-18
#Requires -RunAsAdministrator

param (
    [string]$Description = "PleaseTweakWindows - Manual Restore Point"
)

# Validate parameters
if (-not $Description) {
    Write-Output "[-] ERROR: Description is required."
    exit 1
}

# Check and start VSS (Volume Shadow Copy Service) if needed
try {
    $vss = Get-Service "VSS" -ErrorAction SilentlyContinue
    if ($vss) {
        if ($vss.Status -ne 'Running') {
            Write-Output "[*] Starting Volume Shadow Copy Service (VSS)..."
            Set-Service -Name "VSS" -StartupType Automatic -ErrorAction Stop
            Start-Service -Name "VSS" -ErrorAction Stop
            Start-Sleep -Seconds 2
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

# Ensure System Protection is enabled for the system drive (best-effort).
# On many Windows 11 / clean Windows 10 installs this is OFF by default, which
# makes Checkpoint-Computer fail. Turn it on, reserve shadow storage, and clear
# the 24h creation-frequency throttle so a fresh point is not silently suppressed.
try {
    Write-Output "[*] Ensuring System Protection is enabled for $env:SystemDrive..."
    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
} catch {
    Write-Output "[!] WARNING: Could not enable System Protection: $($_.Exception.Message)"
}

# Best-effort reserve shadow storage so the first restore point has space.
try {
    vssadmin resize shadowstorage /for=$env:SystemDrive /on=$env:SystemDrive /maxsize=10GB | Out-Null
} catch {
    Write-Output "[!] WARNING: Could not reserve shadow storage: $($_.Exception.Message)"
}

# Bypass the once-per-24h restore point creation throttle so Checkpoint-Computer
# does not silently no-op (return without creating a point and without throwing).
try {
    New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name 'SystemRestorePointCreationFrequency' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
} catch {
    Write-Output "[!] WARNING: Could not clear restore point frequency throttle: $($_.Exception.Message)"
}

# Create restore point
try {
    Write-Output "[*] Creating restore point: $Description"
    $before = (Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Measure-Object).Count
    Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    $after = (Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($after -le $before) {
        Write-Output "[-] ERROR: Checkpoint-Computer returned but no restore point was actually created."
        Write-Output "    (Windows may have silently suppressed it, or System Protection is unavailable.)"
        exit 1
    }
    Write-Output "[+] SUCCESS: Restore point created successfully!"
    exit 0
} catch {
    Write-Output "[-] ERROR: Failed to create restore point: $($_.Exception.Message)"
    Write-Output "[!] Common causes:"
    Write-Output "    - System Protection is disabled for this drive"
    Write-Output "    - Not enough disk space (requires at least 300MB free)"
    Write-Output "    - A restore point was created too recently (Windows limits frequency)"
    Write-Output "    - Volume Shadow Copy Service (VSS) is not functioning"
    exit 1
}
