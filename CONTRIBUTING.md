# Contributing to PleaseTweakWindows

Thanks for your interest in contributing. This guide covers everything you need to get started.

## Prerequisites

- **.NET 9 SDK** ([download](https://dotnet.microsoft.com/download))
- **Windows 10/11** (WPF targets `net9.0-windows`; scripts only work on Windows)
- **Windows PowerShell 5.1** (built-in — the app does not use PowerShell 7)

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
      Models/                               Tweak, SubTweak, SubTweakType
      Converters/                           IValueConverter implementations
      Themes/AppTheme.xaml                  Styles / brushes
      app.manifest                          UAC + DPI declarations
    PleaseTweakWindows.Tests/               xUnit + FluentAssertions + Moq
  scripts/                                  PowerShell scripts (embedded in EXE)
    CommonFunctions.ps1                     Shared utilities
    index.txt                               Resource manifest
    file-checksums.json                     SHA256 hashes for downloads
    Gaming optimizations/                   Gaming-Optimizations.ps1 + revert
    Network optimizations/                  Network-Optimizations.ps1 + revert
    General Tweaks/                         General-Tweaks.ps1 + revert + regs/
    Privacy Security/                       privacy.ps1 + security.ps1 + reverts
    Services management/                    Services-Management.ps1 + revert + regs/
```

## Adding a New Tweak

1. Add the action to the PowerShell script's `ValidateSet` and `switch` block
2. Register a `SubTweak` in `TweakRegistry.cs` with matching action IDs
3. Update `scripts/index.txt` if you added new files
4. If the action is destructive, add it to `DialogService.DestructiveActions`
5. If it's high-risk, also add it to `DialogService.HighRiskActions`
6. Run `dotnet test` to verify

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

- Most accept `-Mode <Revert|Repair|RevertAndRepair>` (default `RevertAndRepair`)
- `revert-privacy.ps1` and `revert-security.ps1` also accept `-Action` for individual sub-tweak reverts
- Require `#Requires -RunAsAdministrator`
- Dot-source `CommonFunctions.ps1`

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
