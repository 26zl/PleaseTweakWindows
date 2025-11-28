# PleaseTweakWindows PowerShell Script
# Requires PowerShell 5.1 or later (PowerShell 7+ recommended)

#Requires -RunAsAdministrator

param(
    [switch]$Help
)

# Set console to use modern Unicode font and colors
$Host.UI.RawUI.WindowTitle = "PleaseTweakWindows"
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"

# Modern progress bar style
$ProgressPreference = 'SilentlyContinue'

# Professional header with improved ASCII art
function Show-Header {
    Clear-Host

    # Set console colors for modern look
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "White"
    Clear-Host

    Write-Host @"
                 ::                                ::
               .::                                 .:::
              ::-:.                                .::::
             :.:--:.       ...::::::::::...       .:--:..
             :..::--:....:::::::::-----::::::....::--:..:
              :...:::::::::::-------------:::::::::::..:
               ......::::::::::-----====-----:::::.....
          .:.   ....:::::::::-------+---------::::....   .:.
       .....   ....:::::::::-------+=------::::::::....   .....
     ........  ....:::::-----------=----------:::::::..  .........
   :...............:.....::-----::--:-:----::...:::::.............:
  :..:............::::.....::---:--:::--:..:...::::::...........::.:
 ..:::::.::.......:::::....:....::::::.....:..:::::::......::...:::.:
.:::.::.::........::::::::.....::-:::::.....::---:::........::.::.:::.
:.    .:      :....:::::::::::::---=-::::::::---:::.....     .:     ::
:      .       :..........:::::--:---:::::::...:::.....              :
                :...........:::::::::::...............
                 .........................::..........
                   ............:::::::................:::
                     ............................      .::.
                        .....................           .::
                              .........                 :::
                                     ..              .:::.
                                  .:::  :::::::::::::..
                                 .  ::::
                                  .:::::::.
                                 ::.  ..
                                :.

                      PleaseTweakWindows
"@ -ForegroundColor Red
    Write-Host ""
    Write-Host " >> Windows Optimization Tool " -ForegroundColor Red -NoNewline
    Write-Host "| PowerShell 7+ " -ForegroundColor DarkGray -NoNewline
    Write-Host "| v1.0" -ForegroundColor DarkGray
    Write-Host ""
}

# Modern color functions with better formatting
function Write-InfoText {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Write-SuccessText {
    param([string]$Text)
    Write-Host "[+] $Text" -ForegroundColor Green
}

function Write-ErrorText {
    param([string]$Text)
    Write-Host "[-] $Text" -ForegroundColor Red
}

function Write-WarningText {
    param([string]$Text)
    Write-Host "[!] $Text" -ForegroundColor Yellow
}

# Main menu function
function Show-MainMenu {
    Show-Header
    
    Write-InfoText "Select an optimization category:" -Color Cyan
    Write-Host ""
    Write-Host "  [1] All Windows Settings Optimized" -ForegroundColor White
    Write-Host "  [2] Gaming Optimizations" -ForegroundColor White
    Write-Host "  [3] Network Optimizations" -ForegroundColor White
    Write-Host "  [4] General Tweaks" -ForegroundColor White
    Write-Host "  [5] BCDEdit Tweaks" -ForegroundColor White
    Write-Host "  [6] Services Management" -ForegroundColor White
    Write-Host "  [7] Create System Restore Point" -ForegroundColor White
    Write-Host "  [8] Revert All Changes" -ForegroundColor Yellow
    Write-Host "  [9] Exit" -ForegroundColor Red
    Write-Host ""
}

# Function to execute scripts safely
function Invoke-TweakScript {
    param(
        [string]$ScriptPath,
        [string]$Description
    )
    
    if (-not (Test-Path $ScriptPath)) {
        Write-ErrorText "Script not found: $ScriptPath"
        return $false
    }
    
    Write-InfoText "Executing: $Description" -Color Yellow
    Write-InfoText "Script: $ScriptPath" -Color Gray
    
    try {
        $process = Start-Process -FilePath $ScriptPath -Wait -PassThru -WindowStyle Hidden
        if ($process.ExitCode -eq 0) {
            Write-SuccessText "$Description completed successfully"
            return $true
        } else {
            Write-ErrorText "$Description failed with exit code: $($process.ExitCode)"
            return $false
        }
    } catch {
        Write-ErrorText "Error executing $Description`: $($_.Exception.Message)"
        return $false
    }
}

# Function to create restore point
function New-SystemRestorePoint {
    Write-InfoText "Creating system restore point..." -Color Yellow
    
    $scriptPath = Join-Path $PSScriptRoot "scripts\create_restore_point.ps1"
    if (Test-Path $scriptPath) {
        try {
            & $scriptPath
            Write-SuccessText "System restore point created successfully"
        } catch {
            Write-ErrorText "Failed to create restore point: $($_.Exception.Message)"
        }
    } else {
        Write-WarningText "Restore point script not found. Creating basic restore point..."
        try {
            Checkpoint-Computer -Description "PleaseTweakWindows - Before Optimization" -RestorePointType "MODIFY_SETTINGS"
            Write-SuccessText "Basic system restore point created"
        } catch {
            Write-ErrorText "Failed to create basic restore point: $($_.Exception.Message)"
        }
    }
}

# Main execution logic
function Start-PleaseTweakWindows {
    if ($Help) {
        Show-Header
        Write-InfoText "PleaseTweakWindows - Windows Optimization Tool" -Color Cyan
        Write-Host ""
        Write-InfoText "This tool provides various Windows optimizations for better performance."
        Write-InfoText "All changes can be reverted using the revert options."
        Write-Host ""
        Write-InfoText "Usage: .\PleaseTweakWindowsPScript.ps1 [-Help]"
        Write-Host ""
        return
    }

    # Check if running as administrator
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-ErrorText "This script requires Administrator privileges!"
        Write-InfoText "Please run PowerShell as Administrator and try again."
        Write-Host ""
        Read-Host "Press Enter to exit"
        return
    }

    # Main loop
    do {
        Show-MainMenu
        $choice = Read-Host "Enter your choice (1-9)"
        
        switch ($choice) {
            "1" {
                Write-InfoText "Applying All Windows Settings Optimizations..." -Color Yellow
                $scriptPath = Join-Path $PSScriptRoot "scripts\All windows settings optimized\Windows-settings-tweaked.bat"
                Invoke-TweakScript -ScriptPath $scriptPath -Description "All Windows Settings Optimized"
            }
            "2" {
                Write-InfoText "Applying Gaming Optimizations..." -Color Yellow
                $scriptPath = Join-Path $PSScriptRoot "scripts\Gaming optimizations\gaming-tweaks.bat"
                Invoke-TweakScript -ScriptPath $scriptPath -Description "Gaming Optimizations"
            }
            "3" {
                Write-InfoText "Applying Network Optimizations..." -Color Yellow
                $scriptPath = Join-Path $PSScriptRoot "scripts\Network optimizations\network tweaks.bat"
                Invoke-TweakScript -ScriptPath $scriptPath -Description "Network Optimizations"
            }
            "4" {
                Write-InfoText "Applying General Tweaks..." -Color Yellow
                $scriptPath = Join-Path $PSScriptRoot "scripts\General Tweaks\GeneralTweaks.bat"
                Invoke-TweakScript -ScriptPath $scriptPath -Description "General Tweaks"
            }
            "5" {
                Write-InfoText "Applying BCDEdit Tweaks..." -Color Yellow
                $scriptPath = Join-Path $PSScriptRoot "scripts\Bcdedit tweaks\bcdedit-tweaks.bat"
                Invoke-TweakScript -ScriptPath $scriptPath -Description "BCDEdit Tweaks"
            }
            "6" {
                Write-InfoText "Managing Windows Services..." -Color Yellow
                $scriptPath = Join-Path $PSScriptRoot "scripts\Services disable and revert\Services-disabled.bat"
                Invoke-TweakScript -ScriptPath $scriptPath -Description "Services Management"
            }
            "7" {
                New-SystemRestorePoint
            }
            "8" {
                Write-InfoText "Reverting all changes..." -Color Yellow
                Write-Host ""
                
                # Revert in reverse order
                $revertScripts = @(
                    @{Path = "scripts\All windows settings optimized\Revert.bat"; Desc = "Revert Windows Settings"},
                    @{Path = "scripts\Gaming optimizations\revert gaming tweaks.bat"; Desc = "Revert Gaming Optimizations"},
                    @{Path = "scripts\Network optimizations\revert for network tweaks.bat"; Desc = "Revert Network Optimizations"},
                    @{Path = "scripts\General Tweaks\GeneralTweaksRevert.bat"; Desc = "Revert General Tweaks"},
                    @{Path = "scripts\Bcdedit tweaks\Revert bcdedits to default.bat"; Desc = "Revert BCDEdit Tweaks"},
                    @{Path = "scripts\Services disable and revert\Revert services to default.bat"; Desc = "Revert Services"}
                )
                
                foreach ($script in $revertScripts) {
                    $scriptPath = Join-Path $PSScriptRoot $script.Path
                    Invoke-TweakScript -ScriptPath $scriptPath -Description $script.Desc
                }
                
                Write-SuccessText "All changes have been reverted!"
            }
            "9" {
                Write-InfoText "Thank you for using PleaseTweakWindows!" -Color Cyan
                Write-InfoText "Goodbye!" -Color Gray
                return
            }
            default {
                Write-ErrorText "Invalid choice. Please select 1-9."
            }
        }
        
        if ($choice -ne "9") {
            Write-Host ""
            Read-Host "Press Enter to continue"
        }
        
    } while ($choice -ne "9")
}

# Start the application
Start-PleaseTweakWindows