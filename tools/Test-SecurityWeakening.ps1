#Requires -Version 5.1
<#
.SYNOPSIS
    Fails when a shipped payload weakens security without an explicit, reviewed allowlist entry.

.DESCRIPTION
    Scans scripts/**/*.ps1, *.reg and *.cfg for known security-weakening settings: Windows Update
    turned off or paused, Defender, SmartScreen, firewall or UAC turned off, credential, LSA and VBS
    protections turned off, SMB/NTLM downgrades, exploit mitigations turned off, security services
    disabled, and O&O ShutUp10 entries that do the same.

    Every match must be listed in tools/security-weakening-allowlist.json with the reason it is
    acceptable (for example a disclosed High-risk tweak or a Restore Default fallback). Allowlist
    entries that no longer match anything also fail, so the list always reflects the code.

.PARAMETER AllowlistPath
    Allowlist to check against. Defaults to tools/security-weakening-allowlist.json.

.PARAMETER ListOnly
    Print every match in allowlist format and exit 0 (for reviewing or regenerating entries).
#>
[CmdletBinding()]
param(
    [string]$AllowlistPath,
    [switch]$ListOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $AllowlistPath) { $AllowlistPath = Join-Path $PSScriptRoot 'security-weakening-allowlist.json' }

# Services whose start type must not be set to Disabled without review.
$securityServices = @(
    'WinDefend', 'WdNisSvc', 'WdNisDrv', 'WdFilter', 'WdBoot', 'Sense', 'SecurityHealthService', 'wscsvc',
    'mpssvc', 'mpsdrv', 'BFE', 'wuauserv', 'UsoSvc', 'WaaSMedicSvc', 'BITS', 'dosvc', 'CryptSvc', 'EventLog',
    'BDESVC', 'EFS', 'SgrmBroker', 'SgrmAgent', 'AppIDSvc', 'KeyIso', 'VaultSvc', 'SamSs', 'NgcSvc',
    'NgcCtnrSvc', 'WbioSrvc', 'webthreatdefsvc', 'webthreatdefusersvc', 'SCardSvr', 'ScDeviceEnum',
    'SCPolicySvc', 'CertPropSvc', 'fhsvc', 'wbengine', 'SDRSVC', 'vds', 'DsmSvc', 'defragsvc', 'TrustedInstaller',
    # Browser and app updaters
    'edgeupdate', 'edgeupdatem', 'MicrosoftEdgeElevationService', 'gupdate', 'gupdatem', 'GoogleChromeElevationService'
)
$serviceAlternation = ($securityServices | ForEach-Object { [regex]::Escape($_) }) -join '|'

# "<Name> ... -Value <value>" as written by Set-RegDword / Set-RegValueSafe (an optional -Type may sit in between).
function New-ValuePattern([string]$Name, [string]$Value) {
    return ('\b{0}[''"]?\s+(-Type\s+[''"]?\w+[''"]?\s+)?-Value\s+{1}(?![\w.])' -f $Name, $Value)
}
# "<Name>"=dword:<value> in a .reg file.
function New-RegDwordPattern([string]$Name, [int]$Value) {
    return ('\|"{0}"=dword:{1:x8}$' -f $Name, $Value)
}

# Patterns run against one PowerShell line, or against "<key>|<value line>" for .reg files.
$rules = @(
    @{ Id = 'windows-update-off'; Pattern = @(
        (New-ValuePattern 'NoAutoUpdate' '1'), (New-RegDwordPattern 'NoAutoUpdate' 1),
        'DisableWindowsUpdateAccess', 'SetDisableUXWUAccess', 'DoNotConnectToWindowsUpdateInternetLocations',
        '\bWUServer\b', 'UpdateServiceUrlAlternate') },
    @{ Id = 'app-updates-or-maintenance-off'; Pattern = @(
        (New-ValuePattern 'AutoDownload' '2'), 'WindowsStore\|"AutoDownload"=dword:00000002$',
        (New-ValuePattern 'MaintenanceDisabled' '1'), (New-RegDwordPattern 'MaintenanceDisabled' 1)) },
    @{ Id = 'windows-update-pause'; Pattern = @(
        (New-ValuePattern 'Pause(Feature|Quality)?Updates(StartTime|EndTime|ExpiryTime)' '\$\w+'), 'FlightSettingsMaxPauseDays') },
    @{ Id = 'defender-off'; Pattern = @(
        'Set-MpPreference\b.*-Disable\w+\s+(\$true|1)\b', 'DisableAntiSpyware', (New-ValuePattern 'DisableRealtimeMonitoring' '1'),
        'Add-MpPreference\b.*-Exclusion', 'Windows Defender.*\|"Disable\w*"=dword:0*1$') },
    @{ Id = 'smartscreen-off'; Pattern = @(
        (New-ValuePattern 'EnableSmartScreen' '0'), (New-RegDwordPattern 'EnableSmartScreen' 0),
        (New-ValuePattern 'SmartScreenEnabled' '[''"]Off'), (New-ValuePattern 'EnableWebContentEvaluation' '0')) },
    @{ Id = 'firewall-off'; Pattern = @(
        'Set-NetFirewallProfile\b.*-Enabled\s+(False|\$false)', (New-ValuePattern 'EnableFirewall' '0'),
        (New-RegDwordPattern 'EnableFirewall' 0), 'netsh(\.exe)?\s+advfirewall\s+set\s+\w+\s+state\s+off') },
    @{ Id = 'uac-weakened'; Pattern = @(
        (New-ValuePattern 'EnableLUA' '0'), (New-RegDwordPattern 'EnableLUA' 0), (New-ValuePattern 'ConsentPromptBehaviorAdmin' '0'),
        (New-ValuePattern 'PromptOnSecureDesktop' '0'), (New-ValuePattern 'LocalAccountTokenFilterPolicy' '1')) },
    @{ Id = 'credential-protection-off'; Pattern = @(
        (New-ValuePattern 'UseLogonCredential' '1'), (New-ValuePattern 'RunAsPPL\w*' '0'), (New-ValuePattern 'LsaCfgFlags' '0'),
        (New-ValuePattern 'NoLMHash' '0'), (New-ValuePattern 'LmCompatibilityLevel' '[0-2]'), (New-ValuePattern 'RestrictAnonymous\w*' '0')) },
    @{ Id = 'vbs-hvci-off'; Pattern = @(
        (New-ValuePattern 'EnableVirtualizationBasedSecurity' '0'), (New-ValuePattern 'VulnerableDriverBlocklistEnable' '0'),
        ('(HypervisorEnforcedCodeIntegrity|CredentialGuard|SystemGuard).*' + (New-ValuePattern 'Enabled' '0')),
        (New-ValuePattern 'ConfigureSystemGuardLaunch' '0')) },
    @{ Id = 'smb-ntlm-weakened'; Pattern = @(
        'RequireSecuritySignature\s+\$false', (New-ValuePattern 'RequireSecuritySignature' '0'), 'EnableSMB1Protocol\s+\$true',
        (New-ValuePattern 'AllowInsecureGuestAuth' '1'), (New-ValuePattern 'SMB1' '1'), '-EncryptData\s+\$false',
        'RejectUnencryptedAccess\s+\$false') },
    @{ Id = 'exploit-mitigation-off'; Pattern = @(
        'Set-ProcessMitigation\b.*-Disable\b', (New-ValuePattern 'DisableExceptionChainValidation' '1'), (New-ValuePattern 'MoveImages' '0'),
        (New-ValuePattern 'FeatureSettingsOverride' '3'), 'bcdedit(\.exe)?\b.*\bnx\s+AlwaysOff', (New-ValuePattern 'NoDataExecutionPrevention' '1')) },
    @{ Id = 'security-service-disabled'; Pattern = @(
        "\b($serviceAlternation)\b.*(-StartupType\s+['""]?Disabled|'Start'\s+-Value\s+4|""Start""\s+-Value\s+4)",
        "-StartupType\s+['""]?Disabled.*\b($serviceAlternation)\b",
        "\\Services\\($serviceAlternation)\|""Start""=dword:0*4$") }
)
# O&O ShutUp10 entries in the Windows Update category or touching core protections.
$cfgPattern = 'Category: Windows Update|Defender|SmartScreen|firewall|antivirus|malware|User Account Control|\bUAC\b'

function Get-RegLogicalLine([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $encoding = if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { [Text.Encoding]::Unicode } else { [Text.Encoding]::UTF8 }
    $key = ''
    foreach ($line in ($encoding.GetString($bytes) -split "`r?`n")) {
        $t = $line.Trim().TrimStart([char]0xFEFF)
        if ($t.StartsWith('[') -and $t.EndsWith(']')) { $key = $t.Trim('[', ']'); continue }
        if ($t -match '^("[^"]*"|@)=') { "$key|$t" }
    }
}

$hits = New-Object System.Collections.Generic.List[object]
$scriptsDir = Join-Path $repoRoot 'scripts'
$files = Get-ChildItem -LiteralPath $scriptsDir -Recurse -File | Where-Object { $_.Extension -in '.ps1', '.reg', '.cfg' }
foreach ($file in $files) {
    $relative = 'scripts/' + ($file.FullName.Substring($scriptsDir.Length + 1) -replace '\\', '/')
    $lines = switch ($file.Extension) {
        '.reg' { @(Get-RegLogicalLine -Path $file.FullName) }
        default { @(Get-Content -LiteralPath $file.FullName -Encoding UTF8) }
    }
    foreach ($raw in $lines) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        if ($file.Extension -eq '.cfg') {
            # O&O ShutUp10: "<ID><tab>+<tab># <description>" applies a setting.
            if ($line -match '^\S+\s+\+\s+#\s*(?<desc>.+)$' -and $Matches.desc -match $cfgPattern) {
                $hits.Add([pscustomobject]@{ File = $relative; Rule = 'ooshutup-security-setting'; Match = $line })
            }
            continue
        }
        foreach ($rule in $rules) {
            foreach ($pattern in $rule.Pattern) {
                if ($line -match $pattern) {
                    $hits.Add([pscustomobject]@{ File = $relative; Rule = $rule.Id; Match = $line })
                    break
                }
            }
        }
    }
}
$hits = @($hits | Sort-Object File, Rule, Match -Unique)

if ($ListOnly) {
    $hits | ForEach-Object { [ordered]@{ file = $_.File; rule = $_.Rule; match = $_.Match; reason = '' } } | ConvertTo-Json -Depth 3
    return
}

$allowlist = @((Get-Content -LiteralPath $AllowlistPath -Raw | ConvertFrom-Json).entries)
$failures = New-Object System.Collections.Generic.List[string]
foreach ($entry in $allowlist) {
    if ([string]::IsNullOrWhiteSpace([string]$entry.reason)) {
        $failures.Add("Allowlist entry without a reason: $($entry.file) [$($entry.rule)] $($entry.match)")
    }
}
foreach ($hit in $hits) {
    $listed = @($allowlist | Where-Object { $_.file -eq $hit.File -and $_.rule -eq $hit.Rule -and $_.match -ceq $hit.Match })
    if ($listed.Count -eq 0) {
        $failures.Add("Not allowlisted: $($hit.File) [$($hit.Rule)] $($hit.Match)")
    }
}
foreach ($entry in $allowlist) {
    $found = @($hits | Where-Object { $_.File -eq $entry.file -and $_.Rule -eq $entry.rule -and $_.Match -ceq $entry.match })
    if ($found.Count -eq 0) {
        $failures.Add("Stale allowlist entry (no longer matches): $($entry.file) [$($entry.rule)] $($entry.match)")
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    Write-Error "$($failures.Count) security-weakening finding(s). Remove the weakening, or add an allowlist entry with a reason to $AllowlistPath after review."
    exit 1
}
Write-Output "[+] Security-weakening guard passed: $($hits.Count) known, allowlisted match(es) across $($files.Count) payload file(s)."
