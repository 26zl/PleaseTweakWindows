# PleaseTweakWindows PowerShell Script

Clear-Host
Write-Host "======================================="
Write-Host "     PleaseTweakWindows PowerShell     "
Write-Host "======================================="
Write-Host ""

# Define script directory
$scriptDir = "$PSScriptRoot\scripts"

# Function to prompt Y/N and execute script
Function Run-Tweak {
    param (
        [string]$message,
        [string]$scriptPath
    )

    $response = Read-Host "$message (Y/N)"
    if ($response -eq "Y" -or $response -eq "y") {
        Write-Host "Applying tweak..."
        Start-Process -FilePath $scriptPath -Wait
        Write-Host "Tweak applied successfully!"
    } else {
        Write-Host "Skipping tweak..."
    }
}

# Function for revert option
Function Revert-Tweak {
    param (
        [string]$message,
        [string]$scriptPath
    )

    $response = Read-Host "$message (Y/N)"
    if ($response -eq "Y" -or $response -eq "y") {
        Write-Host "Reverting tweak..."
        Start-Process -FilePath $scriptPath -Wait
        Write-Host "Tweak reverted successfully!"
    } else {
        Write-Host "Skipping revert..."
    }
}

# Apply tweaks
Run-Tweak "Would you like to apply all Windows settings optimizations?" "$scriptDir\All windows settings optimized\Windows-settings-tweaked.bat"
Run-Tweak "Would you like to apply BCDEDIT Tweaks?" "$scriptDir\Bcdedit tweaks\bcdedit-tweaks.bat"
Run-Tweak "Would you like to apply Gaming Optimizations?" "$scriptDir\Gaming optimizations\gaming-tweaks.bat"
Run-Tweak "Would you like to apply Network Optimizations?" "$scriptDir\Network optimizations\network tweaks.bat"
Run-Tweak "Would you like to disable unnecessary services?" "$scriptDir\Services disable and revert\Services-disabled.bat"
Run-Tweak "Would you like to apply UI and general responsiveness tweaks?" "$scriptDir\UI and general responsiveness\GeneralTweaks.bat"
Run-Tweak "Would you like to create a system restore point?" "$scriptDir\create_restore_point.ps1"

# Ask for revert options
Write-Host ""
Write-Host "======================================="
Write-Host "        REVERT CHANGES MENU           "
Write-Host "======================================="
Write-Host ""

Revert-Tweak "Would you like to revert Windows settings?" "$scriptDir\All windows settings optimized\Revert.bat"
Revert-Tweak "Would you like to revert BCDEDIT Tweaks?" "$scriptDir\Bcdedit tweaks\Revert bcdedits to default.bat"
Revert-Tweak "Would you like to revert Gaming Optimizations?" "$scriptDir\Gaming optimizations\revert gaming tweaks.bat"
Revert-Tweak "Would you like to revert Network Optimizations?" "$scriptDir\Network optimizations\revert for network tweaks.bat"
Revert-Tweak "Would you like to revert disabled services?" "$scriptDir\Services disable and revert\Revert services to default.bat"
Revert-Tweak "Would you like to revert UI and general responsiveness tweaks?" "$scriptDir\UI and general responsiveness\GeneralTweaksRevert.bat"

Write-Host ""
Write-Host "All requested changes have been processed."
Write-Host "Press any key to exit..."
Pause