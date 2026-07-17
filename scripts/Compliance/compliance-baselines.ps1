# Compliance baseline dispatcher
#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet(
        'compliance-stig-v2r9-apply',
        'compliance-stig-v2r9-revert',
        'compliance-cis-l1-apply',
        'compliance-cis-l1-revert'
    )]
    [string]$Action
)

$ErrorActionPreference = 'Stop'

$scriptsRoot = Split-Path $PSScriptRoot -Parent
$commonFunctionsPath = Join-Path $scriptsRoot 'CommonFunctions.ps1'
if (-not (Test-Path -LiteralPath $commonFunctionsPath)) {
    Write-Output '[-] CommonFunctions.ps1 not found; refusing to continue'
    exit 1
}
. $commonFunctionsPath

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-PTWError 'Administrator privileges required.'
    exit 1
}

$profileFile = switch ($Action) {
    'compliance-stig-v2r9-apply'  { 'STIG-Windows-11-V2R9.psd1'; break }
    'compliance-stig-v2r9-revert' { 'STIG-Windows-11-V2R9.psd1'; break }
    'compliance-cis-l1-apply'      { 'CIS-Windows-11-24H2-L1.psd1'; break }
    'compliance-cis-l1-revert'     { 'CIS-Windows-11-24H2-L1.psd1'; break }
    default { throw "Unsupported compliance action: $Action" }
}
$operation = if ($Action.EndsWith('-apply', [StringComparison]::OrdinalIgnoreCase)) { 'Apply' } else { 'Revert' }
$profilePath = Join-Path (Join-Path $PSScriptRoot 'Profiles') $profileFile
$statePath = Get-PTWStatePath -Name 'compliance-baseline-state.json'
$powerShell = Join-Path $PSHOME 'powershell.exe'
$actionPattern = '^[a-z0-9_-]{2,64}$'

function Save-ComplianceState {
    param(
        [Parameter(Mandatory)][hashtable]$State
    )

    $tempPath = "$statePath.tmp"
    $State.UpdatedUtc = [DateTime]::UtcNow.ToString('o')
    $State | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $tempPath -Encoding UTF8 -Force
    Move-Item -LiteralPath $tempPath -Destination $statePath -Force
}

function Get-ComplianceState {
    if (-not (Test-Path -LiteralPath $statePath)) { return $null }
    try {
        return Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    } catch {
        throw "Compliance state is unreadable; refusing to overwrite it: $statePath"
    }
}

function Resolve-ProfileScript {
    param([Parameter(Mandatory)][string]$RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        [IO.Path]::IsPathRooted($RelativePath) -or
        $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "Unsafe script path in compliance profile: $RelativePath"
    }

    $rootFull = [IO.Path]::GetFullPath($scriptsRoot).TrimEnd('\\', '/')
    $full = [IO.Path]::GetFullPath((Join-Path $rootFull $RelativePath))
    $prefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Compliance profile path escapes the protected scripts directory: $RelativePath"
    }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "Compliance profile script was not found: $RelativePath"
    }
    if (-not (Test-PtwFileChecksum -Path $full)) {
        throw "Compliance profile script failed integrity verification: $RelativePath"
    }
    return $full
}

function Test-ComplianceProfile {
    param([Parameter(Mandatory)]$BaselineProfile)

    if ($BaselineProfile.SchemaVersion -ne 1 -or [string]::IsNullOrWhiteSpace([string]$BaselineProfile.Id)) {
        throw 'Unsupported or malformed compliance profile.'
    }
    $routes = @($BaselineProfile.Routes)
    if ($routes.Count -lt 1 -or $routes.Count -gt 100) {
        throw "Compliance profile route count is outside the supported range: $($routes.Count)"
    }

    $seen = @{}
    foreach ($route in $routes) {
        foreach ($property in @('ApplyScript', 'ApplyAction', 'RevertScript', 'RevertAction')) {
            if ([string]::IsNullOrWhiteSpace([string]$route.$property)) {
                throw "Compliance profile route is missing $property."
            }
        }
        if ($route.ApplyAction -notmatch $actionPattern -or $route.RevertAction -notmatch $actionPattern) {
            throw "Compliance profile contains an invalid action ID: $($route.ApplyAction) / $($route.RevertAction)"
        }
        $key = "$($route.ApplyScript)|$($route.ApplyAction)"
        if ($seen.ContainsKey($key)) { throw "Duplicate compliance route: $key" }
        $seen[$key] = $true
    }
}

function Invoke-ProfileRoute {
    param(
        [Parameter(Mandatory)]$Route,
        [Parameter(Mandatory)][ValidateSet('Apply','Revert')][string]$Direction
    )

    $relativeScript = if ($Direction -eq 'Apply') { [string]$Route.ApplyScript } else { [string]$Route.RevertScript }
    $routeAction = if ($Direction -eq 'Apply') { [string]$Route.ApplyAction } else { [string]$Route.RevertAction }
    if ($routeAction -notmatch $actionPattern) {
        throw "Invalid action ID in compliance state/profile: $routeAction"
    }
    $scriptPath = Resolve-ProfileScript -RelativePath $relativeScript

    Write-Output "[>] $Direction $routeAction"
    & $powerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $scriptPath -Action $routeAction 2>&1 |
        ForEach-Object { Write-Output "$_" }
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-PTWError "$Direction failed for $routeAction (exit $exitCode)."
        return $false
    }
    return $true
}

function Get-ProfileRouteKey {
    param([Parameter(Mandatory)]$Route)
    return @($Route.ApplyScript, $Route.ApplyAction, $Route.RevertScript, $Route.RevertAction) -join '|'
}

if (-not (Test-PtwFileChecksum -Path $profilePath)) {
    Write-PTWError "Compliance profile failed integrity verification: $profileFile"
    exit 1
}
if (-not (Test-Path -LiteralPath $powerShell -PathType Leaf)) {
    Write-PTWError "Windows PowerShell was not found at the trusted path: $powerShell"
    exit 1
}

$baselineProfile = Import-PowerShellDataFile -LiteralPath $profilePath
Test-ComplianceProfile -BaselineProfile $baselineProfile
$routes = @($baselineProfile.Routes)
$profileHash = (Get-FileHash -LiteralPath $profilePath -Algorithm SHA256).Hash
$existingState = Get-ComplianceState

if ($operation -eq 'Apply') {
    if ($existingState) {
        if ($existingState.ProfileId -eq $baselineProfile.Id) {
            Write-PTWWarning "The baseline '$($baselineProfile.Name)' is already recorded as active. Restore it before applying again."
            exit 0
        }
        Write-PTWError "Another compliance baseline is active: $($existingState.ProfileName). Restore it before applying '$($baselineProfile.Name)'."
        exit 1
    }

    Write-PTWWarning "$($baselineProfile.Coverage)"
    $state = @{
        SchemaVersion = 2
        ProfileId = [string]$baselineProfile.Id
        ProfileName = [string]$baselineProfile.Name
        ProfileHash = $profileHash
        Completed = @()
        UpdatedUtc = ''
    }
    Save-ComplianceState -State $state

    for ($index = 0; $index -lt $routes.Count; $index++) {
        # Record the route before launch. If the child is interrupted after a partial mutation,
        # Restore will pessimistically run its idempotent revert instead of losing track of it.
        $state.Completed = @($state.Completed) + $routes[$index]
        Save-ComplianceState -State $state
        if (Invoke-ProfileRoute -Route $routes[$index] -Direction Apply) {
            continue
        }

        Write-PTWWarning 'Apply stopped. Attempting to restore completed routes in reverse order.'
        $remaining = @($state.Completed)
        $reverseRoutes = @($state.Completed)
        [array]::Reverse($reverseRoutes)
        foreach ($completedRoute in $reverseRoutes) {
            if (Invoke-ProfileRoute -Route $completedRoute -Direction Revert) {
                $completedKey = Get-ProfileRouteKey -Route $completedRoute
                $remaining = @($remaining | Where-Object { (Get-ProfileRouteKey -Route $_) -ne $completedKey })
            }
        }
        if ($remaining.Count -eq 0) {
            Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
        } else {
            $state.Completed = @($remaining)
            Save-ComplianceState -State $state
            Write-PTWError 'Automatic rollback was incomplete. Use Restore for this baseline to retry.'
        }
        exit 1
    }

    Write-PTWSuccess "Applied $($routes.Count) routes from '$($baselineProfile.Name)'. A reboot may be required."
    exit 0
}

if (-not $existingState) {
    Write-PTWWarning 'No compliance baseline is recorded as active; nothing was changed.'
    exit 0
}
if ($existingState.ProfileId -ne $baselineProfile.Id) {
    Write-PTWError "The active baseline is '$($existingState.ProfileName)', not '$($baselineProfile.Name)'. Use its Restore button."
    exit 1
}
if ($existingState.SchemaVersion -ne 2) {
    Write-PTWError "Unsupported compliance state schema: $($existingState.SchemaVersion)"
    exit 1
}
if ($existingState.ProfileHash -ne $profileHash) {
    Write-PTWWarning 'The embedded profile changed after Apply. Restore will use the exact recorded routes.'
}

$remaining = @($existingState.Completed)
$reverseRoutes = @($existingState.Completed)
[array]::Reverse($reverseRoutes)
foreach ($completedRoute in $reverseRoutes) {
    if (Invoke-ProfileRoute -Route $completedRoute -Direction Revert) {
        $completedKey = Get-ProfileRouteKey -Route $completedRoute
        $remaining = @($remaining | Where-Object { (Get-ProfileRouteKey -Route $_) -ne $completedKey })
        if ($remaining.Count -gt 0) {
            $state = @{
                SchemaVersion = 2
                ProfileId = [string]$baselineProfile.Id
                ProfileName = [string]$baselineProfile.Name
                ProfileHash = $profileHash
                Completed = @($remaining)
                UpdatedUtc = ''
            }
            Save-ComplianceState -State $state
        }
    }
}

if ($remaining.Count -gt 0) {
    Write-PTWError "Restore is incomplete; $($remaining.Count) route(s) remain recorded for retry."
    exit 1
}

Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
Write-PTWSuccess "Restored documented defaults for '$($baselineProfile.Name)'. A reboot may be required."
exit 0
