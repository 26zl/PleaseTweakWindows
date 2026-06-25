# Maintenance & Tools
# Purpose: Non-interactive action dispatcher.
# Usage: powershell -File maintenance.ps1 -Action "<action-id>"
# Version: 2.1.0
# Last Updated: 2026-01-18
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "cleanup-run",
        "driver-clean",
        "autoruns-open",
        "cpp-install",
        "menu"
    )]
    [string]$Action = "Menu"
)

$script:ScriptVersion = "2.1.0"

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
    Write-PTWLog "CommonFunctions.ps1 not found - some features may not work" "WARNING"
}

#region Action Dispatcher
switch ($Action.ToLowerInvariant()) {

    "cpp-install" {
        Write-Output "[*] Installing C++ Redistributables..."
        $urls = @(
            @{url="https://aka.ms/vs/17/release/vc_redist.x64.exe"; file="vcredist_x64.exe"; args="/passive /norestart"},
            @{url="https://aka.ms/vs/17/release/vc_redist.x86.exe"; file="vcredist_x86.exe"; args="/passive /norestart"}
        )
        foreach ($item in $urls) {
            $destPath = "$env:TEMP\$($item.file)"
            Get-FileFromWeb -URL $item.url -File $destPath
            # Dynamic-hash download — verify Authenticode before executing as admin
            Test-SignedFile -Path $destPath -PublisherPatterns @('Microsoft Corporation')
            Start-Process -Wait $destPath -ArgumentList $item.args
        }
        Write-Output "[+] SUCCESS: C++ Redistributables installed"
        Exit-PTW
    }

    "driver-clean" {
        Write-Output "[*] Installing DDU..."
        $dduUrl = $PTWDownloadUrls.DisplayDriverUninstaller
        $dduExe = "$env:TEMP\DDU-setup.exe"
        $dduDir = "$env:TEMP\DDU"
        Get-FileFromWeb -URL $dduUrl -File $dduExe
        # DDU distributes as a self-extracting 7z archive; extract with 7-Zip
        $sevenZip = "$env:ProgramFiles\7-Zip\7z.exe"
        if (-not (Test-Path $sevenZip)) {
            Get-FileFromWeb -URL $PTWDownloadUrls.SevenZip -File "$env:TEMP\7z-setup.exe"
            Start-Process -Wait "$env:TEMP\7z-setup.exe" -ArgumentList "/S"
        }
        Remove-Item -Recurse -Force $dduDir -ErrorAction SilentlyContinue
        cmd /c "`"$sevenZip`" x `"$dduExe`" -o`"$dduDir`" -y" | Out-Null
        $WshShell = New-Object -ComObject WScript.Shell
        $s = $WshShell.CreateShortcut("$Home\Desktop\Display Driver Uninstaller.lnk")
        $s.TargetPath = "$dduDir\Display Driver Uninstaller.exe"
        $s.Save()
        Write-Output "[+] SUCCESS: DDU installed to Desktop"
        Exit-PTW
    }

    "cleanup-run" {
        Write-Output "[*] Running System Cleanup..."
        $paths = @("$env:TEMP","$env:SystemDrive\Windows\Temp")
        foreach ($p in $paths) { Remove-Item -Path "$p\*" -Recurse -Force -ErrorAction SilentlyContinue }
        try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch { Write-Verbose "Could not clear recycle bin: $($_.Exception.Message)" }
        Write-Output "[+] SUCCESS: System cleanup complete"
        Exit-PTW
    }

    "autoruns-open" {
        Write-Output "[*] Launching Sysinternals Autoruns..."
        $autorunsZip = Join-Path $env:TEMP "Autoruns.zip"
        $autorunsDir = Join-Path $env:TEMP "Autoruns"
        Remove-Item -Path $autorunsZip -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $autorunsDir -Recurse -Force -ErrorAction SilentlyContinue
        Get-FileFromWeb -URL "https://download.sysinternals.com/files/Autoruns.zip" -File $autorunsZip
        Expand-Archive $autorunsZip -DestinationPath $autorunsDir -Force -ErrorAction SilentlyContinue
        $autorunsExe = if ([Environment]::Is64BitOperatingSystem) {
            Join-Path $autorunsDir "Autoruns64.exe"
        } else {
            Join-Path $autorunsDir "Autoruns.exe"
        }
        if (-not (Test-Path $autorunsExe)) {
            $autorunsExe = Join-Path $autorunsDir "Autoruns.exe"
        }
        if (-not (Test-Path $autorunsExe)) {
            Write-Output "[-] ERROR: Autoruns executable not found after download"
            exit 1
        }
        # Dynamic-hash download — verify Authenticode before execution
        Test-SignedFile -Path $autorunsExe -PublisherPatterns @('Microsoft Corporation')
        Start-Process -FilePath $autorunsExe
        Write-Output "[+] SUCCESS: Autoruns launched"
        Exit-PTW
    }

    "menu" {
        Write-Output "[i] No interactive menu - use JavaFX GUI to select tweaks"
        Exit-PTW
    }

    default {
        Write-Error "Unknown action: $Action"
        exit 1
    }
}
#endregion
