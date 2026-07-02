#Requires -Version 5.1

[CmdletBinding()]
param([switch]$MapSyncOnly)

$ErrorActionPreference = 'Stop'
$scriptsDir = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts')).Path
$runtimeDir = Join-Path $scriptsDir ('.runtime-signature-check-' + [Guid]::NewGuid().ToString('N'))
$logDir = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }

$env:PTW_EMBEDDED = '1'
$env:PTW_SCRIPTS_DIR = $scriptsDir
$env:PTW_RUNTIME_DIR = $runtimeDir
$env:PTW_LOG_DIR = $logDir
$env:PTW_STATE_DIR = (New-Item -ItemType Directory -Path (Join-Path $runtimeDir 'state') -Force).FullName

$checks = @{
    'https://aka.ms/vs/17/release/vc_redist.x64.exe' = @{
        File = 'vc_redist.x64.exe'; Signer = 'Microsoft Corporation'
    }
    'https://aka.ms/vs/17/release/vc_redist.x86.exe' = @{
        File = 'vc_redist.x86.exe'; Signer = 'Microsoft Corporation'
    }
    'https://download.sysinternals.com/files/Autoruns.zip' = @{
        File = 'Autoruns.zip'; Signer = 'Microsoft Corporation'; Archive = $true
    }
    'https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe' = @{
        File = 'OOSU10.exe'; Signer = 'O&O Software GmbH'
    }
}

try {
    . (Join-Path $scriptsDir 'CommonFunctions.ps1')

    $manifest = Get-Content (Join-Path $scriptsDir 'file-checksums.json') -Raw | ConvertFrom-Json
    $dynamicUrls = @($manifest.downloads.PSObject.Properties |
        Where-Object Value -eq 'DYNAMIC' |
        Select-Object -ExpandProperty Name)

    $uncovered = @($dynamicUrls | Where-Object { -not $checks.ContainsKey($_) })
    $stale = @($checks.Keys | Where-Object { $_ -notin $dynamicUrls })
    if ($uncovered.Count -gt 0 -or $stale.Count -gt 0) {
        throw "Dynamic download signature map is out of sync. Uncovered: $($uncovered -join ', '); stale: $($stale -join ', ')"
    }

    if ($MapSyncOnly) {
        Write-Host "[+] Dynamic download signature map is in sync ($($dynamicUrls.Count) entries). Skipping downloads (-MapSyncOnly)."
        return
    }

    foreach ($url in $dynamicUrls) {
        $check = $checks[$url]
        $file = Get-PTWRuntimePath $check.File
        Write-Host "[*] Downloading and verifying $url"
        Get-FileFromWeb -URL $url -File $file

        if ($check.Archive) {
            $extractDir = Get-PTWRuntimePath 'Autoruns'
            Expand-Archive -LiteralPath $file -DestinationPath $extractDir -Force
            $binaries = @(Get-ChildItem -LiteralPath $extractDir -Recurse -File |
                Where-Object { $_.Extension -in @('.exe', '.dll') })
            if ($binaries.Count -eq 0) {
                throw "Autoruns archive contained no executable files."
            }
            foreach ($binary in $binaries) {
                Test-SignedFile -Path $binary.FullName -PublisherPatterns @($check.Signer)
            }
        } else {
            Test-SignedFile -Path $file -PublisherPatterns @($check.Signer)
        }
    }

    Write-Host "[+] All $($dynamicUrls.Count) dynamic vendor downloads have valid expected signatures."
}
finally {
    Remove-Item -LiteralPath $runtimeDir -Recurse -Force -ErrorAction SilentlyContinue
}
