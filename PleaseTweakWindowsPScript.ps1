# PleaseTweakWindows PowerShell Script

Clear-Host
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "     PleaseTweakWindows PowerShell     " -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Script directory
$scriptDir = "$PSScriptRoot\scripts"

# Function to run BAT files
Function Run-Tweak {
    param (
        [string]$message,
        [string]$scriptPath
    )

    $response = Read-Host "$message (Y/N)"
    if ($response -eq "Y" -or $response -eq "y") {
        Write-Host "Applying tweak..." -ForegroundColor Yellow
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$scriptPath`"" -NoNewWindow -Wait
        Write-Host "Tweak applied successfully!" -ForegroundColor Green
    } else {
        Write-Host "Skipping tweak..." -ForegroundColor Red
    }
}

# Function to revert tweaks
Function Revert-Tweak {
    param (
        [string]$message,
        [string]$scriptPath
    )

    $response = Read-Host "$message (Y/N)"
    if ($response -eq "Y" -or $response -eq "y") {
        Write-Host "Reverting tweak..." -ForegroundColor Yellow
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$scriptPath`"" -NoNewWindow -Wait
        Write-Host "Tweak reverted successfully!" -ForegroundColor Green
    } else {
        Write-Host "Skipping revert..." -ForegroundColor Red
    }
}

# System restore
Write-Host ""
Write-Host "IMPORTANT: It is recommended to create a system restore point before applying tweaks." -ForegroundColor Yellow
Run-Tweak "Would you like to create a system restore point now?" "$scriptDir\create_restore_point.ps1"

# Main menu loop
do {
    Clear-Host
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "         PLEASETWEAKWINDOWS           " -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "1. Apply Windows Tweaks" -ForegroundColor Green
    Write-Host "2. Revert Windows Tweaks" -ForegroundColor Red
    Write-Host "3. Exit" -ForegroundColor Yellow
    Write-Host ""

    $choice = Read-Host "Select an option (1-3)"

    switch ($choice) {
        "1" {
            Write-Host "Applying tweaks..." -ForegroundColor Yellow

            Run-Tweak "Would you like to apply all Windows settings optimizations?" "$scriptDir\All windows settings optimized\Windows-settings-tweaked.bat"
            Run-Tweak "Would you like to apply BCDEDIT Tweaks?" "$scriptDir\Bcdedit tweaks\bcdedit-tweaks.bat"
            Run-Tweak "Would you like to apply Gaming Optimizations?" "$scriptDir\Gaming optimizations\gaming-tweaks.bat"
            Run-Tweak "Would you like to apply Network Optimizations?" "$scriptDir\Network optimizations\network tweaks.bat"
            Run-Tweak "Would you like to disable unnecessary services?" "$scriptDir\Services disable and revert\Services-disabled.bat"
            Run-Tweak "Would you like to apply General UI and responsiveness tweaks?" "$scriptDir\General Tweaks\GeneralTweaks.bat"
        }

        "2" {
            Write-Host "Reverting tweaks..." -ForegroundColor Yellow

            Revert-Tweak "Would you like to revert Windows settings?" "$scriptDir\All windows settings optimized\Revert.bat"
            Revert-Tweak "Would you like to revert BCDEDIT Tweaks?" "$scriptDir\Bcdedit tweaks\Revert bcdedits to default.bat"
            Revert-Tweak "Would you like to revert Gaming Optimizations?" "$scriptDir\Gaming optimizations\revert gaming tweaks.bat"
            Revert-Tweak "Would you like to revert Network Optimizations?" "$scriptDir\Network optimizations\revert for network tweaks.bat"
            Revert-Tweak "Would you like to revert disabled services?" "$scriptDir\Services disable and revert\Revert services to default.bat"
            Revert-Tweak "Would you like to revert General UI and responsiveness tweaks?" "$scriptDir\General Tweaks\GeneralTweaksRevert.bat"
        }

        "3" {
            Write-Host "Exiting... Goodbye!" -ForegroundColor Cyan
            exit
        }

        Default {
            Write-Host "Invalid selection, please try again." -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Press any key to return to the main menu..."
    [void][System.Console]::ReadKey($true)

} while ($true)