#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$failures = [System.Collections.Generic.List[string]]::new()

$dispatchers = @(
    'scripts/Gaming optimizations/Gaming-Optimizations.ps1',
    'scripts/Network optimizations/Network-Optimizations.ps1',
    'scripts/Performance/performance.ps1',
    'scripts/Privacy Security/privacy.ps1',
    'scripts/Defender/defender.ps1',
    'scripts/Exploit Protection/exploit-protection.ps1',
    'scripts/Device Guard/device-guard.ps1',
    'scripts/Network Security/network-security.ps1',
    'scripts/System Security/system-security.ps1',
    'scripts/Compliance/compliance-baselines.ps1',
    'scripts/Debloat/debloat.ps1',
    'scripts/Maintenance/maintenance.ps1',
    'scripts/Customize/Customize.ps1',
    'scripts/Windows Update/windows-update.ps1',
    'scripts/Edge/Edge.ps1'
)

$catalogRoutes = @(
    @{ Catalog = 'GamingCategory.cs'; Script = 'scripts/Gaming optimizations/Gaming-Optimizations.ps1' },
    @{ Catalog = 'NetworkCategory.cs'; Script = 'scripts/Network optimizations/Network-Optimizations.ps1' },
    @{ Catalog = 'PerformanceCategory.cs'; Script = 'scripts/Performance/performance.ps1' },
    @{ Catalog = 'PrivacyCategory.cs'; Script = 'scripts/Privacy Security/privacy.ps1' },
    @{ Catalog = 'DefenderCategory.cs'; Script = 'scripts/Defender/defender.ps1' },
    @{ Catalog = 'ExploitProtectionCategory.cs'; Script = 'scripts/Exploit Protection/exploit-protection.ps1' },
    @{ Catalog = 'DeviceGuardCategory.cs'; Script = 'scripts/Device Guard/device-guard.ps1' },
    @{ Catalog = 'NetworkSecurityCategory.cs'; Script = 'scripts/Network Security/network-security.ps1' },
    @{ Catalog = 'SystemSecurityCategory.cs'; Script = 'scripts/System Security/system-security.ps1' },
    @{ Catalog = 'ComplianceBaselinesCategory.cs'; Script = 'scripts/Compliance/compliance-baselines.ps1' },
    @{ Catalog = 'DebloatCategory.cs'; Script = 'scripts/Debloat/debloat.ps1' },
    @{ Catalog = 'MaintenanceCategory.cs'; Script = 'scripts/Maintenance/maintenance.ps1' },
    @{ Catalog = 'CustomizeCategory.cs'; Script = 'scripts/Customize/Customize.ps1' },
    @{ Catalog = 'WindowsUpdateCategory.cs'; Script = 'scripts/Windows Update/windows-update.ps1' },
    @{ Catalog = 'EdgeCategory.cs'; Script = 'scripts/Edge/Edge.ps1' }
)

$routeCases = @{}
foreach ($relativePath in $dispatchers) {
    $path = Join-Path $repoRoot $relativePath
    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile(
        $path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        $failures.Add("${relativePath}: parse failed")
        continue
    }

    $actionParameter = $ast.ParamBlock.Parameters |
        Where-Object { $_.Name.VariablePath.UserPath -eq 'Action' } |
        Select-Object -First 1
    $validateSet = $actionParameter.Attributes |
        Where-Object { $_.TypeName.Name -eq 'ValidateSet' } |
        Select-Object -First 1
    if (-not $validateSet) {
        $failures.Add("${relativePath}: Action has no ValidateSet")
        continue
    }

    $declared = @($validateSet.PositionalArguments | ForEach-Object {
        [string]$_.SafeGetValue()
    })
    $dispatcher = $ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.SwitchStatementAst] -and
            $node.Condition.Extent.Text -match '(?i)\$Action'
    }, $true) | Select-Object -First 1
    if (-not $dispatcher) {
        $failures.Add("${relativePath}: no Action switch")
        continue
    }

    $cases = @($dispatcher.Clauses | ForEach-Object {
        [string]$_.Item1.SafeGetValue()
    })
    $routeCases[$relativePath] = $cases
    $missing = @($declared | Where-Object { $_ -notin $cases })
    $extra = @($cases | Where-Object { $_ -notin $declared })
    if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
        $failures.Add(
            "${relativePath}: ValidateSet/switch mismatch; missing=[$($missing -join ', ')], extra=[$($extra -join ', ')]")
    }
}

$categoryRoot = Join-Path $repoRoot 'src/PleaseTweakWindows/Services/Categories'
$togglePattern = [regex]::new(
    'new\s+SubTweak\(\s*"(?:\\.|[^"\\])*"\s*,\s*SubTweakType\.Toggle\s*,\s*"(?<apply>[a-z0-9_-]+)"\s*,\s*"(?<revert>[a-z0-9_-]+)"',
    [Text.RegularExpressions.RegexOptions]::Singleline)
$buttonPattern = [regex]::new(
    'new\s+SubTweak\(\s*"(?:\\.|[^"\\])*"\s*,\s*"(?<apply>[a-z0-9_-]+)"\s*,',
    [Text.RegularExpressions.RegexOptions]::Singleline)

foreach ($pair in $catalogRoutes) {
    $catalogPath = Join-Path $categoryRoot $pair.Catalog
    $catalogContent = Get-Content -LiteralPath $catalogPath -Raw
    $toggleMatches = $togglePattern.Matches($catalogContent)
    $expectedApply = @(
        $toggleMatches | ForEach-Object {
            $_.Groups['apply'].Value
        }
        $buttonPattern.Matches($catalogContent) | ForEach-Object {
            $_.Groups['apply'].Value
        }
    ) | Sort-Object -Unique
    $registeredCatalogActions = @(
        $expectedApply
        $toggleMatches | ForEach-Object {
            $_.Groups['revert'].Value
        }
    ) | Sort-Object -Unique

    $cases = @($routeCases[$pair.Script])
    $missing = @($expectedApply | Where-Object { $_ -notin $cases })
    $extra = @($cases | Where-Object { $_ -ne 'menu' -and $_ -notin $registeredCatalogActions })
    if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
        $failures.Add(
            "$($pair.Script): catalog/dispatcher mismatch; missing=[$($missing -join ', ')], unregistered=[$($extra -join ', ')]")
    }
}

# Compliance profiles compose existing toggle routes. Validate all four fields together so a
# renamed action or script cannot silently turn a baseline into a partial apply/restore.
$profileCatalogs = @(
    @{ Catalog = 'DefenderCategory.cs'; ApplyScript = 'Defender/defender.ps1'; RevertScript = 'Defender/revert-defender.ps1' },
    @{ Catalog = 'DeviceGuardCategory.cs'; ApplyScript = 'Device Guard/device-guard.ps1'; RevertScript = 'Device Guard/revert-device-guard.ps1' },
    @{ Catalog = 'ExploitProtectionCategory.cs'; ApplyScript = 'Exploit Protection/exploit-protection.ps1'; RevertScript = 'Exploit Protection/revert-exploit-protection.ps1' },
    @{ Catalog = 'NetworkSecurityCategory.cs'; ApplyScript = 'Network Security/network-security.ps1'; RevertScript = 'Network Security/revert-network-security.ps1' },
    @{ Catalog = 'SystemSecurityCategory.cs'; ApplyScript = 'System Security/system-security.ps1'; RevertScript = 'System Security/revert-system-security.ps1' },
    @{ Catalog = 'EdgeCategory.cs'; ApplyScript = 'Edge/Edge.ps1'; RevertScript = 'Edge/Edge.ps1' }
)
$validProfileRoutes = @{}
foreach ($catalog in $profileCatalogs) {
    $catalogContent = Get-Content -LiteralPath (Join-Path $categoryRoot $catalog.Catalog) -Raw
    foreach ($match in $togglePattern.Matches($catalogContent)) {
        $key = @(
            $catalog.ApplyScript,
            $match.Groups['apply'].Value,
            $catalog.RevertScript,
            $match.Groups['revert'].Value
        ) -join '|'
        $validProfileRoutes[$key] = $true
    }
}

$profilePaths = @(
    'STIG/STIG-Windows-11-V2R9.psd1',
    'CIS/CIS-Windows-11-24H2-L1.psd1'
)
foreach ($relativeProfilePath in $profilePaths) {
    $baselineProfile = Import-PowerShellDataFile -LiteralPath (Join-Path $repoRoot $relativeProfilePath)
    if ($baselineProfile.SchemaVersion -ne 1 -or @($baselineProfile.Routes).Count -eq 0) {
        $failures.Add("${relativeProfilePath}: invalid schema or empty route list")
        continue
    }
    $profileKeys = @{}
    foreach ($route in @($baselineProfile.Routes)) {
        $key = @(
            $route.ApplyScript,
            $route.ApplyAction,
            $route.RevertScript,
            $route.RevertAction
        ) -join '|'
        if (-not $validProfileRoutes.ContainsKey($key)) {
            $failures.Add("${relativeProfilePath}: unknown composed route [$key]")
        }
        if ($profileKeys.ContainsKey($key)) {
            $failures.Add("${relativeProfilePath}: duplicate composed route [$key]")
        }
        $profileKeys[$key] = $true
    }
}

$revertPairs = @(
    @{ Catalog = 'DefenderCategory.cs'; Script = 'scripts/Defender/revert-defender.ps1' },
    @{ Catalog = 'DeviceGuardCategory.cs'; Script = 'scripts/Device Guard/revert-device-guard.ps1' },
    @{ Catalog = 'ExploitProtectionCategory.cs'; Script = 'scripts/Exploit Protection/revert-exploit-protection.ps1' },
    @{ Catalog = 'NetworkSecurityCategory.cs'; Script = 'scripts/Network Security/revert-network-security.ps1' },
    @{ Catalog = 'PrivacyCategory.cs'; Script = 'scripts/Privacy Security/revert-privacy.ps1'; Kind = 'Switch' },
    @{ Catalog = 'SystemSecurityCategory.cs'; Script = 'scripts/System Security/revert-system-security.ps1' }
)

foreach ($pair in $revertPairs) {
    $catalogPath = Join-Path $categoryRoot $pair.Catalog
    $catalogContent = Get-Content -LiteralPath $catalogPath -Raw
    $expectedRoutes = @($togglePattern.Matches($catalogContent) | ForEach-Object {
        [pscustomobject]@{
            Apply = $_.Groups['apply'].Value
            Revert = $_.Groups['revert'].Value
        }
    })

    $scriptPath = Join-Path $repoRoot $pair.Script
    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile(
        $scriptPath, [ref]$tokens, [ref]$parseErrors)

    if ($pair.Kind -eq 'Switch') {
        $dispatcher = $ast.FindAll({
            param($node)
            $node -is [Management.Automation.Language.SwitchStatementAst] -and
                $node.Condition.Extent.Text -match '(?i)\$Action'
        }, $true) | Select-Object -First 1
        $cases = @($dispatcher.Clauses | ForEach-Object {
            [string]$_.Item1.SafeGetValue()
        })
        $missing = @($expectedRoutes | Where-Object {
            $_.Revert -notin $cases
        } | ForEach-Object { $_.Revert })
        if ($missing.Count -gt 0) {
            $failures.Add("$($pair.Script): missing switch cases [$($missing -join ', ')]")
        }
        continue
    }

    $assignment = $ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
            $node.Left.VariablePath.UserPath -eq 'actionMap'
    }, $true) | Select-Object -Last 1

    $hashtable = $assignment.Right.Expression
    if ($hashtable -isnot [Management.Automation.Language.HashtableAst]) {
        $failures.Add("$($pair.Script): actionMap is missing or is not a literal hashtable")
        continue
    }
    $mapKeys = @($hashtable.KeyValuePairs | ForEach-Object {
        [string]$_.Item1.SafeGetValue()
    })
    $missing = @($expectedRoutes | Where-Object {
        $_.Apply -notin $mapKeys -and $_.Revert -notin $mapKeys
    } | ForEach-Object { "$($_.Apply) / $($_.Revert)" })
    if ($missing.Count -gt 0) {
        $failures.Add("$($pair.Script): missing actionMap keys [$($missing -join ', ')]")
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "[+] Action routing validation passed for $($dispatchers.Count) catalog dispatchers, $($revertPairs.Count) revert maps, and $($profilePaths.Count) compliance profiles."
