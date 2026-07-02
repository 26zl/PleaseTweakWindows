# Customize (Shell & UX)
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "theme-dark",
        "theme-light",
        "file-ext-show",
        "file-ext-hide",
        "hidden-files-show",
        "hidden-files-hide",
        "super-hidden-show",
        "super-hidden-hide",
        "taskbar-align-left",
        "taskbar-align-center",
        "taskview-hide",
        "taskview-show",
        "explorer-this-pc",
        "explorer-quick-access",
        "context-menu-classic",
        "context-menu-default",
        "search-box-hide",
        "search-box-show",
        "lockscreen-disable",
        "lockscreen-enable",
        "startmenu-clean",
        "shortcuts-add",
        "keyboard-disable",
        "keyboard-enable",
        "menu"
    )]
    [string]$Action = "Menu"
)

#region Logging
function Write-PTWLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) { "INFO" { "[*]" } "SUCCESS" { "[+]" } "WARNING" { "[!]" } "ERROR" { "[-]" } default { "[*]" } }
    Write-Output "$timestamp $prefix $Message"
}
#endregion

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

# Prompt for one manual Explorer restart after shell settings change.
$ExplorerHint = "[i] Sign out (or restart Explorer) for this change to fully apply."

$AdvancedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$ThemeKey    = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$SearchKey   = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
# Windows 11 classic context menu shim.
$ContextClsid = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"

#region Action Dispatcher
switch ($Action.ToLowerInvariant()) {

    "theme-dark" {
        Write-Output "[*] Enabling Windows dark mode..."
        Backup-RegistryPath -Action $Action -Paths @($ThemeKey)
        Set-RegDword -Path $ThemeKey -Name "AppsUseLightTheme" -Value 0
        Set-RegDword -Path $ThemeKey -Name "SystemUsesLightTheme" -Value 0
        Write-Output "[+] SUCCESS: dark mode enabled"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "theme-light" {
        Write-Output "[*] Restoring Windows light mode..."
        Set-RegDword -Path $ThemeKey -Name "AppsUseLightTheme" -Value 1
        Set-RegDword -Path $ThemeKey -Name "SystemUsesLightTheme" -Value 1
        Write-Output "[+] SUCCESS: light mode restored"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "file-ext-show" {
        Write-Output "[*] Showing file extensions..."
        Set-RegDword -Path $AdvancedKey -Name "HideFileExt" -Value 0
        Write-Output "[+] SUCCESS: file extensions visible"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "file-ext-hide" {
        Write-Output "[*] Hiding file extensions (Windows default)..."
        Set-RegDword -Path $AdvancedKey -Name "HideFileExt" -Value 1
        Write-Output "[+] SUCCESS: file extensions hidden"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "hidden-files-show" {
        Write-Output "[*] Showing hidden files..."
        Set-RegDword -Path $AdvancedKey -Name "Hidden" -Value 1
        Write-Output "[+] SUCCESS: hidden files visible"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "hidden-files-hide" {
        Write-Output "[*] Hiding hidden files (Windows default)..."
        Set-RegDword -Path $AdvancedKey -Name "Hidden" -Value 2
        Write-Output "[+] SUCCESS: hidden files hidden"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "super-hidden-show" {
        Write-Output "[*] Showing protected operating-system files..."
        Write-Output "[!] WARNING: this reveals system files (e.g. pagefile.sys, boot files). Deleting or editing them can break Windows."
        Set-RegDword -Path $AdvancedKey -Name "ShowSuperHidden" -Value 1
        Write-Output "[+] SUCCESS: protected OS files visible"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "super-hidden-hide" {
        Write-Output "[*] Hiding protected operating-system files (Windows default)..."
        Set-RegDword -Path $AdvancedKey -Name "ShowSuperHidden" -Value 0
        Write-Output "[+] SUCCESS: protected OS files hidden"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "taskbar-align-left" {
        Write-Output "[*] Aligning taskbar to the left..."
        Set-RegDword -Path $AdvancedKey -Name "TaskbarAl" -Value 0
        Write-Output "[+] SUCCESS: taskbar aligned left"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "taskbar-align-center" {
        Write-Output "[*] Centering taskbar (Windows 11 default)..."
        Set-RegDword -Path $AdvancedKey -Name "TaskbarAl" -Value 1
        Write-Output "[+] SUCCESS: taskbar centered"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "taskview-hide" {
        Write-Output "[*] Hiding the Task View button..."
        Set-RegDword -Path $AdvancedKey -Name "ShowTaskViewButton" -Value 0
        Write-Output "[+] SUCCESS: Task View button hidden"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "taskview-show" {
        Write-Output "[*] Showing the Task View button (Windows default)..."
        Set-RegDword -Path $AdvancedKey -Name "ShowTaskViewButton" -Value 1
        Write-Output "[+] SUCCESS: Task View button visible"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "explorer-this-pc" {
        Write-Output "[*] Opening File Explorer to This PC..."
        Set-RegDword -Path $AdvancedKey -Name "LaunchTo" -Value 1
        Write-Output "[+] SUCCESS: File Explorer opens to This PC"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "explorer-quick-access" {
        Write-Output "[*] Opening File Explorer to Quick Access / Home (Windows default)..."
        Set-RegDword -Path $AdvancedKey -Name "LaunchTo" -Value 2
        Write-Output "[+] SUCCESS: File Explorer opens to Quick Access"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "context-menu-classic" {
        Write-Output "[*] Restoring the classic (Windows 10 style) right-click context menu..."
        # Empty (Default) under InprocServer32 makes the shell fall back to the full menu.
        Set-RegistryDefaultValueSafe -Path "$ContextClsid\InprocServer32" -Value ""
        Write-Output "[+] SUCCESS: classic context menu enabled"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "context-menu-default" {
        Write-Output "[*] Restoring the Windows 11 compact context menu (default)..."
        Remove-RegKeySafe -Path $ContextClsid
        Write-Output "[+] SUCCESS: default context menu restored"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "search-box-hide" {
        Write-Output "[*] Hiding the taskbar search box/icon..."
        Set-RegDword -Path $SearchKey -Name "SearchboxTaskbarMode" -Value 0
        Write-Output "[+] SUCCESS: taskbar search hidden"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "search-box-show" {
        Write-Output "[*] Showing the taskbar search box..."
        Set-RegDword -Path $SearchKey -Name "SearchboxTaskbarMode" -Value 2
        Write-Output "[+] SUCCESS: taskbar search box shown"
        Write-Output $ExplorerHint
        Exit-PTW
    }

    "lockscreen-disable" {
        Write-Output "[*] Disabling Lock Screen..."
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $w = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Width
        $h = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height
        $bmp = New-Object System.Drawing.Bitmap $w, $h
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.FillRectangle([System.Drawing.Brushes]::Black, 0, 0, $w, $h)
        $g.Dispose()
        $blackJpgPath = "$env:SystemRoot\Black.jpg"
        $bmp.Save($blackJpgPath)
        $bmp.Dispose()
        Set-RegSz -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImagePath" -Value $blackJpgPath
        Set-RegDword -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImageStatus" -Value 1
        Write-Output "[+] SUCCESS: Lock Screen disabled (restart required)"
        Exit-PTW
    }

    "lockscreen-enable" {
        Write-Output "[*] Enabling Lock Screen..."
        Remove-Item -Force "$env:SystemRoot\Black.jpg" -ErrorAction SilentlyContinue
        # Preserve unrelated PersonalizationCSP policy values.
        Remove-RegValue -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImagePath"
        Remove-RegValue -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImageStatus"
        Write-Output "[+] SUCCESS: Lock Screen enabled (restart required)"
        Exit-PTW
    }

    "startmenu-clean" {
        Write-Output "[*] Cleaning Start Menu and Taskbar..."
        Backup-RegistryPath -Action $Action -Paths @("Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband")
        Remove-RegKey -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
        Set-RegDword -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0
        Set-RegDword -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0
        Set-RegDword -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0
        Set-RegDword -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0
        Stop-Process -Force -Name explorer -ErrorAction SilentlyContinue
        Write-Output "[+] SUCCESS: Start Menu cleaned (restart required)"
        Exit-PTW
    }

    "shortcuts-add" {
        Write-Output "[*] Adding Start Menu Shortcuts..."
        $WshShell = New-Object -ComObject WScript.Shell
        $paths = @(
            @{target="$env:ProgramData\Microsoft\Windows\Start Menu\Programs"; name="Start Menu Shortcuts 1.lnk"},
            @{target="$env:AppData\Microsoft\Windows\Start Menu\Programs"; name="Start Menu Shortcuts 2.lnk"},
            @{target="$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup"; name="Startup Programs 1.lnk"},
            @{target="$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"; name="Startup Programs 2.lnk"}
        )
        foreach ($p in $paths) {
            $s = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$($p.name)")
            $s.TargetPath = $p.target
            $s.Save()
        }
        Write-Output "[+] SUCCESS: Start Menu shortcuts added"
        Exit-PTW
    }

    "keyboard-disable" {
        Write-Output "[*] Disabling Keyboard Shortcuts..."
        # Disable Windows-key shortcuts through policy without changing hidserv.
        Set-RegDword -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoWinKeys" -Value 1
        Write-Output "[+] SUCCESS: Keyboard shortcuts disabled (restart required)"
        Exit-PTW
    }

    "keyboard-enable" {
        Write-Output "[*] Enabling Keyboard Shortcuts..."
        Remove-RegValue -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoWinKeys"
        Remove-RegValue -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisabledHotkeys"
        Write-Output "[+] SUCCESS: Keyboard shortcuts enabled (restart required)"
        Exit-PTW
    }

    "menu" {
        Write-Output "[i] No interactive menu - use the GUI to select tweaks"
        Exit-PTW
    }

    default {
        Write-Error "Unknown action: $Action"
        exit 1
    }
}
#endregion
