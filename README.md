# PleaseTweakWindows

![Build](https://github.com/26zl/PleaseTweakWindows/actions/workflows/build.yml/badge.svg)

> **Under active development** — sub-tweaks, UI, and behavior may change between releases. Pin to a specific tag if you need stability.

Windows optimization tool focused on **security hardening, privacy, latency/FPS, and debloating** — with Apply/Restore Default controls, explicit one-shot actions, dependency-aware controls, and shareable config profiles.

<p align="center">
  <img src=".github/logo.png" alt="PleaseTweakWindows Logo" width="200" />
</p>

## Warning

This tool modifies Windows registry settings, services, and system configuration. Some changes may affect system stability. The app prompts you to create a system restore point on first use; let it.

## Verifying your download

Releases through v2.1.2 were not Authenticode-signed. Starting with v2.1.3, the release workflow
refuses to publish a tag unless the EXE has a valid Authenticode signature. Development artifacts
may remain unsigned. Always verify the archive against the checksum from the same release:

```powershell
# Compare against SHA256SUMS.txt from the same release
(Get-FileHash -Algorithm SHA256 .\PleaseTweakWindows.zip).Hash
```

Starting with v2.1.3, releases also ship `SHA256SUMS.txt` and a CycloneDX **SBOM** (`SBOM.json`).

## Quick Start

**Requires Administrator privileges.**

1. Download from [Releases](https://github.com/26zl/PleaseTweakWindows/releases)
2. Run `PleaseTweakWindows.exe` as Administrator
3. Accept the restore-point prompt on first tweak

## Categories

14 categories, 148 sub-tweaks.

| Category | Sub-tweaks | Description |
| --- | --- | --- |
| **Gaming Optimizations** | 12 | GPU drivers, Game Bar, MSI mode, DirectX, polling rate, MPO, HAGS, Game Mode |
| **Performance & Power** | 5 | Ultimate power plan, performance registry batch, HDCP, DPI scaling fix, USB selective suspend |
| **Network Optimizations** | 4 | IPv4-only adapter bindings, Smart Network Optimization (standard / aggressive), snapshot-based restore |
| **Debloat** | 10 | Remove bloatware (+ persistent), reinstall Store, disable widgets / background apps / unnecessary services |
| **Privacy** | 26 | Telemetry, Copilot, DNS (Cloudflare / Google / Quad9 / DoH), Explorer privacy, MS-account & OneDrive policy, O&O ShutUp profile |
| **Microsoft Defender** | 8 | Controlled Folder Access, network / PUA protection, cloud + max protection, ASR rules, sandbox, gaming-scan tuning |
| **Exploit Protection** | 8 | System & per-app mitigations, ASLR, DEP, SEHOP, Spectre/Meltdown |
| **Device Guard** | 8 | HVCI / Memory Integrity, Credential Guard, LSA protection, vulnerable-driver blocklist, WDigest |
| **Network Security** | 24 | Firewall hardening + logging, TLS / SMB / NTLM / LLMNR / mDNS, country-IP blocking, LOLBin block, RDP NLA, WinRM, PrintNightmare |
| **System Security** | 19 | UAC level, SmartScreen, binary integrity, lock screen, account lockout, audit policy, PowerShell logging, WSH |
| **Customize** | 13 | Dark mode, taskbar, Explorer, context menu, lock screen, Start menu, keyboard shortcuts |
| **Maintenance & Tools** | 4 | Disk cleanup, DDU installer, Autoruns, C++ redistributables |
| **Windows Update** | 5 | Default / feature deferral / pause / off / secure modes |
| **Edge** | 2 | Security baseline + HardCore hardening |

Each toggle sub-tweak exposes **Apply** and **Restore Default** buttons individually. Restore Default returns the affected setting to the documented Windows default; it does not generally reconstruct a custom or organization-managed value that existed before Apply. Snapshot-backed actions, such as Smart Network Optimization, restore their captured adapter state. A toggle that depends on another tweak greys out until its prerequisite is applied (live registry check). "Run All" applies toggles sequentially and stops on cancellation or failure. It deliberately excludes one-shot actions such as installers, cleanup, and mutually exclusive Windows Update modes.

## How It Works

```text
WPF UI (.NET 10 LTS)
    |
powershell -File <script>.ps1 -Action "<action-id>"
    |
Category Scripts  (Non-interactive dispatchers)
Restore Scripts   (Restore defaults + repair components)
```

- Individual sub-tweaks are executed via `-Action` parameter
- Restore scripts return settings to documented Windows defaults and can optionally repair affected components

## Requirements

**End users:**

- Windows 11 (build 22000+) — Windows 10 is not supported
- Administrator privileges
- Windows PowerShell 5.1 (built-in)

**Developers / building from source:**

- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- Windows (WPF targets `net10.0-windows`)

## Run from Source (development)

```cmd
git clone https://github.com/26zl/PleaseTweakWindows.git
cd PleaseTweakWindows

REM Launch the app — a UAC prompt appears because app.manifest requires Administrator.
dotnet run --project src/PleaseTweakWindows

REM Run the full test suite
dotnet test PleaseTweakWindows.sln

REM Run a single test class / single method
dotnet test PleaseTweakWindows.sln --filter "FullyQualifiedName~ScriptExecutorTests"
dotnet test PleaseTweakWindows.sln --filter "FullyQualifiedName=PleaseTweakWindows.Tests.ScriptExecutorTests.IsValidAction_ValidatesCorrectly"

REM Debug build (no publish, no UAC)
dotnet build PleaseTweakWindows.sln
```

Hot-edit PowerShell scripts under `scripts/` — they are re-embedded into the DLL on every build, and `ResourceExtractor` extracts them to a permission-restricted temp directory at app startup. No need to touch `Build.bat` during iteration.

## Build a Local Release-Style EXE

```cmd
REM Produces dist\PleaseTweakWindows.zip with the single-file self-contained EXE.
Build.bat
```

`Build.bat` runs `dotnet test` → `dotnet publish -c Release -r win-x64 --self-contained -p:PublishSingleFile=true` → packages the EXE, project notices, and dependency licenses under `dist\PleaseTweakWindows\` → zips it. Scripts are embedded inside the EXE; no loose `scripts\` folder ships with the release.

This local package is unsigned. Production releases are created by the tagged GitHub Actions
workflow, which requires and verifies the project code-signing certificate.

## Logging & Privacy

PleaseTweakWindows sends **no telemetry** off-device. It writes local logs under `%LOCALAPPDATA%\PleaseTweakWindows\logs` (with a temp-folder fallback) so failed tweaks are diagnosable. Use **Open Logs Folder** in the output panel to review or delete them.

- App logs roll daily and are pruned automatically (≈14 days; error logs ≈30).
- A local activity log records script name, action ID, exit code, and duration.
- Convenience registry snapshots are stored below the logs directory and pruned after 30 days.
- Persistent rollback state is stored in ACL-protected `%PROGRAMDATA%\PleaseTweakWindows\state`.
  Smart Network Optimization keeps at most five adapter snapshots and deletes the snapshot after
  a fully successful restore; incomplete restores retain it for manual recovery.
- The full PowerShell **transcript** (which captures every cmdlet's output — adapter names, paths, installed-app info) is **off by default**. It is only written when `PTW_TRANSCRIPT=1` (debug builds), and those files are pruned after 14 days.
- **Update check:** on startup the app makes a single anonymous HTTPS request to the GitHub Releases API (`api.github.com/repos/26zl/PleaseTweakWindows/releases/latest`) to see if a newer version exists. It sends only an `Accept` and a `User-Agent` header — no machine/user identifiers, no body. Set the environment variable `PTW_NO_UPDATE_CHECK=1` to disable it entirely (no outbound connection).
- Actions that install vendor tools contact the vendor URL shown in the script only when you run
  them. Country-IP blocking fetches its two validated CIDR lists from
  `raw.githubusercontent.com/HotCakeX/Official-IANA-IP-blocks` only when that action is run.

## Security

Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## Disclaimer

**USE AT YOUR OWN RISK.** Some changes may require manual restoration. This project is provided as-is with no warranty.

## License

MIT License. See [LICENSE](LICENSE).
