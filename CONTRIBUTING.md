# Contributing to PleaseTweakWindows

Thanks for your interest in contributing. This guide covers everything you need to get started.

## Prerequisites

- **.NET 9 SDK** ([download](https://dotnet.microsoft.com/download)). SDK selection is pinned by `global.json` (baseline 9.0.100, rolls forward to a newer major if 9.x is absent — so a .NET 10 SDK also works for building).
- **Windows 10/11** (WPF targets `net9.0-windows`; scripts only work on Windows)
- **Windows PowerShell 5.1** (built-in — the app does not use PowerShell 7)
- Off-Windows you can only **build** (`dotnet build … -p:EnableWindowsTargeting=true`); `dotnet test` needs the **.NET 9 Windows Desktop Runtime**, so tests run on Windows/CI only.

## Getting Started

```cmd
git clone https://github.com/26zl/PleaseTweakWindows.git
cd PleaseTweakWindows
dotnet test PleaseTweakWindows.sln
```

### Useful Commands

| Command | What it does |
| --- | --- |
| `dotnet test` | Run all unit tests |
| `dotnet run --project src/PleaseTweakWindows` | Run the app in dev mode (UAC prompt appears) |
| `dotnet build -c Release` | Release build |
| `Build.bat` | Full build + single-file EXE + distribution ZIP |

## Project Structure

```text
/
  PleaseTweakWindows.sln
  src/
    PleaseTweakWindows/                     WPF app (net9.0-windows)
      App.xaml / App.xaml.cs                Entry point, DI container, Serilog
      Views/                                XAML windows + user controls
      ViewModels/                           CommunityToolkit.Mvvm
      Services/                             ScriptExecutor, DialogService, etc.
      Models/                               Tweak, SubTweak, SubTweakType, SubTweakRisk, SubTweakRequirement
      Services/                             ScriptExecutor, ResourceExtractor, DialogService,
                                            TweakRegistry (+ Categories/*.cs), RegistryState,
                                            RestorePointGuard, ConfigProfileService, …
      Converters/                           IValueConverter implementations
      Themes/AppTheme.xaml                  Styles / brushes
      app.manifest                          UAC + DPI declarations
    PleaseTweakWindows.Tests/               xUnit + FluentAssertions + Moq
  scripts/                                  PowerShell scripts (embedded in EXE)
    CommonFunctions.ps1                     Shared toolkit (reg helpers, downloads, Exit-PTW, …)
    index.txt                               Resource manifest (forward + reverse checked in CI)
    file-checksums.json                     SHA256 hashes for scripts + downloads
    Gaming optimizations/                   Gaming-Optimizations.ps1 + revert-gaming.ps1
    Performance/                            performance.ps1 + revert + regs/
    Network optimizations/                  Network-Optimizations.ps1 + revert
    Debloat/                                debloat.ps1 + revert + regs/
    Privacy Security/                       privacy.ps1 + revert-privacy.ps1
    Defender/                               defender.ps1 + revert-defender.ps1
    Exploit Protection/                     exploit-protection.ps1 + revert
    Device Guard/                           device-guard.ps1 + revert
    Network Security/                       network-security.ps1 + revert
    System Security/                        system-security.ps1 + revert
    Customize/                              Customize.ps1 (apply + revert in one script)
    Maintenance/                            maintenance.ps1
    Windows Update/                         windows-update.ps1
    Edge/                                   Edge.ps1
```

Each `TweakRegistry` category is one `partial class` file under `Services/Categories/*.cs`.

## Adding a New Tweak

Adding one action id touches several files in lockstep — miss one and a test/CI gate fails:

1. **`Services/Categories/<X>.cs`** — add a `SubTweak` row with matching action ids. Put its
   risk and confirmation text **on the SubTweak itself**: `Risk` (`SubTweakRisk.None/Confirm/High`),
   `Warning` (the confirmation template, `{0}` = action name), and `Requires` (a
   `SubTweakRequirement` if it depends on another tweak being applied). `DialogService` projects
   confirmation/high-risk/warnings **from the registry** — there is no separate `DialogService`
   list to edit.
2. **The category's apply script** — add the id to the `ValidateSet`, add a `switch` case
   (call `Backup-RegistryPath` before destructive registry writes), end the case with `Exit-PTW`.
3. **The category's revert** — for Toggles add a `Restore-*`/`$actionMap` entry (or a revert
   case in single-script categories like Customize/Gaming). Reverts must restore the *true
   Windows default* — when the default is "value absent", use `Remove-RegValueSafe`.
4. **`scripts/file-checksums.json`** — recompute the touched script's SHA256
   (`shasum -a 256 <file> | tr a-z A-Z`, UPPERCASE). New script files also go in
   **`scripts/index.txt`**, **`ScriptExecutor.ConsolidatedScripts`**, and the **`build.yml`**
   verification lists.
5. **`TweakRegistryTests.cs`** — update the per-category SubTweak count assertion.
6. Run `dotnet test` (Windows / CI) to verify.

### Action ID Format

- Lowercase alphanumeric with dashes: `nvidia-settings-on`, `bloatware-remove`
- 2-64 characters
- Must match exactly between C# and PowerShell

## PowerShell Script Conventions

### Main Scripts (action dispatchers)

- Accept `-Action <id>` parameter with `ValidateSet`
- Use a `switch ($Action)` block to dispatch
- Must be **non-interactive** (no `Read-Host`, no `pause`)
- Check for `PTW_EMBEDDED` env var (set by the GUI) to skip prompts
- Dot-source `CommonFunctions.ps1` for shared utilities
- Exit 0 on success, non-zero on error

### Revert Scripts

- A category with its own `revert-*.ps1` uses `param([ValidateSet('Revert','Repair','RevertAndRepair')]$Mode, [string]$Action)` plus an `$actionMap` keyed by the *apply* id (revert ids strip a trailing `-revert`) and `Invoke-Mode`
- Single-script categories (Customize, Gaming, …) put both apply and revert cases in the one script
- Require `#Requires -RunAsAdministrator`
- Dot-source `CommonFunctions.ps1`
- A revert must restore the **true Windows default**, not a hardcoded value that leaves the machine below default

### Downloads

- **HTTPS only** — enforced by `Get-FileFromWeb` in `CommonFunctions.ps1`
- Domain whitelist: `microsoft.com`, `github.com`, `githubusercontent.com`, etc.
- Add SHA256 checksums to `file-checksums.json` for new downloads

### Shared Functions

Use functions from `CommonFunctions.ps1` instead of defining local copies:

- `Set-RegDword`, `Set-RegSz`, `Set-RegValueSafe`, `Remove-RegValue`, `Remove-RegKey`
- `Set-RegValueSafeTx`, `Start-PTWTransaction`, `Undo-PTWTransaction`, `Stop-PTWTransaction` (transactional registry ops)
- `Get-FileFromWeb` (secure download with domain whitelist + SHA256 checksum verification)
- `Write-PTWSuccess`, `Write-PTWWarning`, `Write-PTWError`, `Write-PTWLog`
- `Get-ActiveAdapter`, `Get-GpuClassKeysByVendor`, `Import-RegistryFile`, `Wait-ForUser`

## C# Conventions

- MVVM with `CommunityToolkit.Mvvm` (`[ObservableProperty]`, `[RelayCommand]`)
- Services are registered in `App.xaml.cs`; inject via constructor
- Use `IProcessRunner` for process creation (not `Process.Start` directly) to keep tests isolated
- UI updates from background threads must go through `UiDispatcher.Post` or `Application.Current.Dispatcher.BeginInvoke`
- Script path validation rejects `..`, `;`, `|`, `&`, `>`, `<`

## Testing

```cmd
dotnet test
```

Tests cover: `ScriptExecutor` (action/path validation, hash integrity, rejection paths), `DialogService` (destructive/high-risk classification, warnings), `TweakRegistry` (category/sub-tweak counts, action ID format, Toggle/Button invariants, path shape), `UpdateChecker` (JSON parsing, semver comparison).

Tests run on Windows only (WPF target). Access private members via the existing `InternalsVisibleTo("PleaseTweakWindows.Tests")` attribute in the main csproj.

## Pull Request Guidelines

1. Fork the repo and create a branch from `main`
2. Make your changes
3. Run `dotnet test` and make sure all tests pass
4. Make sure your PowerShell scripts pass `Invoke-ScriptAnalyzer`
5. Update `scripts/index.txt` if you added/removed script files
6. Open a PR with a clear description of what changed and why

## Reporting Issues

Open an issue on GitHub with:

- What you expected to happen
- What actually happened
- Your Windows version and PowerShell version
- Any relevant log output from the `logs/` directory
