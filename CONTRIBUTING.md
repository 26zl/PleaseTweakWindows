# Contributing to PleaseTweakWindows

Thanks for your interest in contributing. This guide covers everything you need to get started.

## Prerequisites

- **Java 21** (GraalVM or Liberica NIK recommended)
- **Maven 3.9.9+**
- **GraalVM Native Image** (for building the .exe)
- **Windows 10/11** (scripts only work on Windows)
- **Windows PowerShell 5.1** (built-in, the app does not use PowerShell 7)

## Getting Started

```cmd
git clone https://github.com/26zl/PleaseTweakWindows.git
cd PleaseTweakWindows
mvn test
```

### Useful Commands

| Command | What it does |
| --- | --- |
| `mvn test` | Run all unit tests |
| `mvn javafx:run` | Run the app in dev mode |
| `mvn clean package -Pnative` | Build native .exe |
| `Build.bat` | Full build + distribution ZIP |
| `Test.bat` | Run tests, optionally launch dev mode |
| `Cleanup.bat` | Clean build artifacts and temp files |

## Project Structure

```text
src/main/java/com/zl/pleasetweakwindows/
    Main.java               JavaFX entry point, window chrome, close handling
    TweakController.java    Tweak/SubTweak definitions (6 categories)
    Tweak.java              Category data model
    SubTweak.java           Individual action data model (TOGGLE / BUTTON)
    UiLogic.java            Accordion UI + button handlers
    Executor.java           Script runner (4-thread pool, cancellation)
    ResourceExtractor.java  Extracts scripts to temp dir on startup
    DialogUtils.java        Confirmation dialogs for destructive actions
    RestorePointGuard.java  Restore point prompt (once per session)
    UpdateChecker.java      GitHub release checker (async, non-blocking)
    ProcessRunner.java      Process abstraction interface (for testability)
    ProcessRunnerFactory.java  Factory interface for ProcessRunner

src/main/resources/scripts/
    CommonFunctions.ps1     Shared utilities (registry, downloads, GPU helpers, transactions)
    index.txt               Resource manifest for native image embedding
    file-checksums.json     SHA256 hashes for downloaded files
    Gaming optimizations/   Gaming-Optimizations.ps1 (apply + revert via -Action), revert-gaming.ps1
    Network optimizations/  Network-Optimizations.ps1 (apply + revert via -Action), revert-network.ps1
    General Tweaks/         General-Tweaks.ps1 (apply + revert via -Action), revert-general.ps1 + regs/
    Privacy Security/       privacy.ps1 + revert-privacy.ps1, security.ps1 + revert-security.ps1, regs/
    Services management/    Services-Management.ps1 (apply + revert via -Action), revert-services.ps1 + regs/
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

- Most accept `-Mode <Revert|Repair|RevertAndRepair>` parameter (default `RevertAndRepair`).
- `revert-privacy.ps1` and `revert-security.ps1` also accept `-Action` for individual sub-tweak reverts.
- Require `#Requires -RunAsAdministrator`
- Dot-source `CommonFunctions.ps1`

### Downloads

- **HTTPS only** - enforced by `Get-FileFromWeb` in CommonFunctions.ps1
- Domain whitelist: `microsoft.com`, `github.com`, `githubusercontent.com`, etc.
- Add SHA256 checksums to `file-checksums.json` for new downloads

### Shared Functions

Use functions from `CommonFunctions.ps1` instead of defining local copies:

- `Set-RegDword`, `Set-RegSz`, `Set-RegValueSafe`, `Remove-RegValue`, `Remove-RegKey`
- `Set-RegValueSafeTx`, `Start-PTWTransaction`, `Undo-PTWTransaction`, `Stop-PTWTransaction` (transactional registry ops)
- `Get-FileFromWeb` (secure download with domain whitelist + SHA256 checksum verification)
- `Write-PTWSuccess`, `Write-PTWWarning`, `Write-PTWError`, `Write-PTWLog`
- `Get-ActiveAdapter`, `Get-GpuClassKeysByVendor`, `Import-RegistryFile`, `Wait-ForUser`

## Java Conventions

- JPMS module system (`module-info.java`)
- Use `ProcessRunner`/`ProcessRunnerFactory` for testability (not `ProcessBuilder` directly)
- UI updates must go through `Platform.runLater()`
- Script path validation rejects `..`, `;`, `|`, `&`, `>`, `<`

## CI Checks

All checks are in a single workflow (`build.yml`) with 5 jobs. All must pass before merging:

| Job | What it checks |
| --- | --- |
| **validate-scripts** | PowerShell syntax, parameter structure, `index.txt` consistency, `$script:ScriptVersion` |
| **security-scan** | Obfuscated code, credential exposure, security feature disabling, suspicious URLs, hardcoded paths |
| **functional-testing** | PSScriptAnalyzer, non-interactive architecture (no `Read-Host`), Java-to-PowerShell action ID match, revert script structure |
| **build-exe** | Maven tests, Windows resource compilation (`rc.exe`), GraalVM native image build |
| **create-release** | Distribution ZIP + GitHub release (main branch only) |

### PSScriptAnalyzer

Runs on all `.ps1` files. Errors fail the build, warnings are reported. Excluded rules:

- `PSAvoidUsingWriteHost`
- `PSUseShouldProcessForStateChangingFunctions`
- `PSAvoidGlobalVars`

## Testing

```cmd
mvn test
```

Tests cover: `Executor` (command building, cancellation, validation, integration), `DialogUtils`, `TweakController` (definitions + path resolution), `SubTweak`, `Tweak`, `ResourceExtractor` (extraction + idempotency), `UpdateChecker` (version comparison + JSON parsing), `ActionIdConsistency` (Java-to-PowerShell ID match).

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
