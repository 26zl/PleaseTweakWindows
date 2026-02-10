# Contributing to PleaseTweakWindows

Thanks for your interest in contributing. This guide covers everything you need to get started.

## Prerequisites

- **Java 21** (GraalVM or Liberica NIK recommended)
- **Maven 3.9.9+**
- **GraalVM Native Image** (for building the .exe)
- **Windows 10/11** (scripts only work on Windows)
- **PowerShell 5.1+** (7+ recommended)

## Getting Started

```cmd
git clone https://github.com/26zl/PleaseTweakWindows.git
cd PleaseTweakWindows
mvn test
```

### Useful Commands

| Command | What it does |
| --- | --- |
| `mvn test` | Run all 34 unit tests |
| `mvn javafx:run` | Run the app in dev mode |
| `mvn clean package -Pnative` | Build native .exe |
| `Build.bat` | Full build + distribution ZIP |
| `Test.bat` | Run tests, optionally launch dev mode |
| `Cleanup.bat` | Clean build artifacts and temp files |

## Project Structure

```text
src/main/java/com/zl/pleasetweakwindows/
    Main.java               JavaFX entry point
    TweakController.java    Tweak/SubTweak definitions
    UiLogic.java            Accordion UI + button handlers
    Executor.java           Script runner (4-thread pool)
    ResourceExtractor.java  Extracts scripts to temp dir
    DialogUtils.java        Confirmation dialogs
    RestorePointGuard.java  Restore point prompt (once per session)

src/main/resources/scripts/
    CommonFunctions.ps1     Shared utilities (registry, downloads, logging)
    index.txt               Resource manifest for native image
    file-checksums.json     SHA256 hashes for downloaded files
    Gaming optimizations/   Gaming-Optimizations.ps1 + revert-gaming.ps1
    Network optimizations/  Network-Optimizations.ps1 + revert-network.ps1
    General Tweaks/         General-Tweaks.ps1 + revert-general.ps1
    Privacy Security/       privacy.ps1, security.ps1 + reverts
    Services management/    Services-Management.ps1 + revert-services.ps1
```

## Adding a New Tweak

1. Add the action to the PowerShell script's `ValidateSet` and `switch` block
2. Register a `SubTweak` in `TweakController.java` with matching action IDs
3. Update `index.txt` if you added new files
4. If the action is destructive, add it to `DialogUtils.DESTRUCTIVE_ACTIONS`
5. If it's high-risk, also add it to `DialogUtils.HIGH_RISK_ACTIONS`
6. Run `mvn test` to verify

### Action ID Format

- Lowercase, alphanumeric with dashes: `nvidia-settings-on`, `bloatware-remove`
- 2-64 characters
- Must match exactly between Java and PowerShell (CI validates this)

## PowerShell Script Conventions

### Main Scripts (action dispatchers)

- Accept `-Action <id>` parameter with `ValidateSet`
- Use a `switch ($Action)` block to dispatch
- Must be **non-interactive** (no `Read-Host`, no `pause`)
- Check for `PTW_EMBEDDED` env var (set by the GUI) to skip prompts
- Dot-source `CommonFunctions.ps1` for shared utilities
- Exit 0 on success, non-zero on error

### Revert Scripts

- Accept `-Mode <Revert|Repair|RevertAndRepair>` parameter
- Require `#Requires -RunAsAdministrator`
- Dot-source `CommonFunctions.ps1`

### Downloads

- **HTTPS only** - enforced by `Get-FileFromWeb` in CommonFunctions.ps1
- Domain whitelist: `microsoft.com`, `github.com`, `githubusercontent.com`, etc.
- Add SHA256 checksums to `file-checksums.json` for new downloads

### Shared Functions

Use functions from `CommonFunctions.ps1` instead of defining local copies:

- `Set-RegDword`, `Set-RegSz`, `Remove-RegValue`, `Remove-RegKey`
- `Get-FileFromWeb` (secure download with checksum verification)
- `Write-PTWSuccess`, `Write-PTWWarning`, `Write-PTWError`, `Write-PTWLog`
- `Get-ActiveAdapter`, `Import-RegistryFile`, `Wait-ForUser`

## Java Conventions

- JPMS module system (`module-info.java`)
- Use `ProcessRunner`/`ProcessRunnerFactory` for testability (not `ProcessBuilder` directly)
- UI updates must go through `Platform.runLater()`
- Script path validation rejects `..`, `;`, `|`, `&`, `>`, `<`

## CI Checks

All of these must pass before merging:

| Workflow | What it checks |
| --- | --- |
| **build.yml** | Script syntax, structure, index.txt consistency, native build |
| **functionality-test.yml** | PSScriptAnalyzer, non-interactive architecture, Java-PS action ID match |
| **security.yml** | Obfuscated code, credential exposure, security feature disabling, suspicious URLs |

### PSScriptAnalyzer

Runs on all `.ps1` files. Errors fail the build, warnings are reported. Excluded rules:

- `PSAvoidUsingWriteHost`
- `PSUseShouldProcessForStateChangingFunctions`
- `PSAvoidGlobalVars`

## Testing

```cmd
mvn test
```

Tests cover: `Executor` (command building, cancellation, validation), `DialogUtils`, `TweakController`, `SubTweak`, `ResourceExtractor`, `Tweak`.

If you add new Java functionality, add corresponding tests in `src/test/java/`.

## Pull Request Guidelines

1. Fork the repo and create a branch from `main`
2. Make your changes
3. Run `mvn test` and make sure all tests pass
4. Make sure your PowerShell scripts pass `Invoke-ScriptAnalyzer`
5. Update `index.txt` if you added/removed script files
6. Open a PR with a clear description of what changed and why

## Reporting Issues

Open an issue on GitHub with:

- What you expected to happen
- What actually happened
- Your Windows version and PowerShell version
- Any relevant log output from the `logs/` directory
