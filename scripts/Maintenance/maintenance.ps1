# Maintenance & Tools
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(
        "cleanup-run",
        "ddu-install",
        "autoruns-open",
        "cpp-install",
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

#region Action Dispatcher
switch ($Action.ToLowerInvariant()) {

    "cpp-install" {
        Write-Output "[*] Installing C++ Redistributables..."
        $urls = @(
            @{url="https://aka.ms/vs/17/release/vc_redist.x64.exe"; file="vcredist_x64.exe"; args="/passive /norestart"},
            @{url="https://aka.ms/vs/17/release/vc_redist.x86.exe"; file="vcredist_x86.exe"; args="/passive /norestart"}
        )
        foreach ($item in $urls) {
            $destPath = Get-PTWRuntimePath $item.file
            Get-FileFromWeb -URL $item.url -File $destPath
            Test-SignedFile -Path $destPath -PublisherPatterns @('Microsoft Corporation')
            $install = Start-Process -FilePath $destPath -ArgumentList $item.args `
                -Wait -PassThru -ErrorAction Stop
            if ($install.ExitCode -notin @(0, 1638, 3010)) {
                Write-Output "[-] ERROR: $($item.file) exited with code $($install.ExitCode)."
                exit 1
            }
            Remove-Item -LiteralPath $destPath -Force -ErrorAction SilentlyContinue
        }
        Write-Output "[+] SUCCESS: C++ Redistributables installed"
        Exit-PTW
    }

    "ddu-install" {
        Write-Output "[*] Installing DDU..."
        $dduUrl = $PTWDownloadUrls.DisplayDriverUninstaller
        $dduExe = Get-PTWRuntimePath "DDU-setup.exe"
        $toolsDir = Join-Path $env:ProgramFiles "PleaseTweakWindows Tools"
        $dduDir = Join-Path $toolsDir "DDU"
        Get-FileFromWeb -URL $dduUrl -File $dduExe
        # DDU distributes as a self-extracting 7z archive; extract with 7-Zip
        $sevenZip = "$env:ProgramFiles\7-Zip\7z.exe"
        if (-not (Test-Path $sevenZip)) {
            $sevenZipInstaller = Get-PTWRuntimePath "7z-setup.exe"
            Get-FileFromWeb -URL $PTWDownloadUrls.SevenZip -File $sevenZipInstaller
            $install = Start-Process -FilePath $sevenZipInstaller -ArgumentList "/S" `
                -Wait -PassThru -ErrorAction Stop
            if ($install.ExitCode -ne 0) {
                Write-Output "[-] ERROR: 7-Zip installation failed with exit code $($install.ExitCode)."
                exit 1
            }
        }
        if (-not (Test-Path $sevenZip)) {
            Write-Output "[-] ERROR: 7-Zip installation did not produce $sevenZip."
            exit 1
        }
        New-Item -ItemType Directory -Path $toolsDir -Force -ErrorAction Stop | Out-Null
        Remove-Item -Recurse -Force $dduDir -ErrorAction SilentlyContinue
        & $sevenZip x $dduExe "-o$dduDir" -y | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Output "[-] ERROR: DDU extraction failed (7-Zip exit $LASTEXITCODE)."
            exit 1
        }
        $dduProgram = Join-Path $dduDir "Display Driver Uninstaller.exe"
        if (-not (Test-Path $dduProgram)) {
            Write-Output "[-] ERROR: DDU executable not found after extraction."
            exit 1
        }
        $WshShell = New-Object -ComObject WScript.Shell
        $s = $WshShell.CreateShortcut("$Home\Desktop\Display Driver Uninstaller.lnk")
        $s.TargetPath = $dduProgram
        $s.Save()
        Remove-Item -LiteralPath $dduExe -Force -ErrorAction SilentlyContinue
        Write-Output "[+] SUCCESS: DDU installed to $dduDir (Desktop shortcut created)"
        Exit-PTW
    }

    "cleanup-run" {
        Write-Output "[*] Running System Cleanup..."
        $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
        $paths = @("$env:SystemDrive\Windows\Temp")
        if (-not [string]::IsNullOrWhiteSpace($localAppData)) {
            $paths = @((Join-Path $localAppData 'Temp')) + $paths
        }
        $cleanupErrors = @()
        foreach ($p in $paths) {
            Remove-Item -Path "$p\*" -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable +cleanupErrors
        }
        try {
            Clear-RecycleBin -Force -ErrorAction Stop
        } catch {
            $cleanupErrors += $_
        }
        if ($cleanupErrors.Count -gt 0) {
            Write-Output "[!] Cleanup completed with $($cleanupErrors.Count) item(s) skipped (typically files currently in use)."
        } else {
            Write-Output "[+] SUCCESS: System cleanup complete"
        }
        Exit-PTW
    }

    "autoruns-open" {
        Write-Output "[*] Launching Sysinternals Autoruns..."
        $autorunsZip = Get-PTWRuntimePath "Autoruns.zip"
        $autorunsDir = Get-PTWRuntimePath "Autoruns"
        Remove-Item -Path $autorunsZip -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $autorunsDir -Recurse -Force -ErrorAction SilentlyContinue
        Get-FileFromWeb -URL "https://download.sysinternals.com/files/Autoruns.zip" -File $autorunsZip
        Expand-Archive $autorunsZip -DestinationPath $autorunsDir -Force -ErrorAction Stop
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
        $autorunsBinaries = Get-ChildItem -LiteralPath $autorunsDir -Recurse -File |
            Where-Object { $_.Extension -in @('.exe', '.dll') }
        if (-not $autorunsBinaries) {
            Write-Output "[-] ERROR: Autoruns archive contained no executable files."
            exit 1
        }
        foreach ($binary in $autorunsBinaries) {
            Test-SignedFile -Path $binary.FullName -PublisherPatterns @('Microsoft Corporation')
        }
        Start-Process -FilePath $autorunsExe -ErrorAction Stop
        Write-Output "[+] SUCCESS: Autoruns launched"
        Exit-PTW
    }

    "menu" {
        Write-Output "[i] No interactive menu - use the PleaseTweakWindows app to select tweaks"
        Exit-PTW
    }

    default {
        Write-Error "Unknown action: $Action"
        exit 1
    }
}
#endregion
