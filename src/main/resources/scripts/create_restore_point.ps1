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

# Create restore point
try {
    Write-Output "[*] Creating restore point: $Description"
    Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
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
