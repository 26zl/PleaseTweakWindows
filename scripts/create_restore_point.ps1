param (
    [string]$Description = "System Restore Point"
)

if (-not $Description) {
    Write-Host "Error: Description is required."
    exit 1
}

$powershellPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path $powershellPath)) {
    Write-Host "Error: PowerShell not found at $powershellPath"
    exit 1
}

try {
    Write-Host "Creating restore point: $Description"
    Start-Process $powershellPath -ArgumentList "-ExecutionPolicy Bypass -NoExit -Command `"Checkpoint-Computer -Description '$Description' -RestorePointType 'MODIFY_SETTINGS'`"" -Verb RunAs
} catch {
    Write-Host "Error occurred while creating restore point: $_"
    exit 1
}