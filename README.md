# PleaseTweakWindows

![Build](https://github.com/26zl/PleaseTweakWindows/actions/workflows/build.yml/badge.svg)

> **Under active development** — sub-tweaks, UI, and behavior may change between releases. Pin to a specific tag if you need stability.

Windows optimization tool focused on **security hardening, privacy, latency/FPS, and debloating** — with per-tweak Apply/Revert, dependency-aware toggles that grey out until their prerequisite is applied, and shareable config profiles.

<p align="center">
  <img src=".github/logo.png" alt="PleaseTweakWindows Logo" width="200" />
</p>

## Warning

This tool modifies Windows registry settings, services, and system configuration. Some changes may affect system stability. The app prompts you to create a system restore point on first use; let it.

## VirusTotal

Latest EXE scan: [c4256a0c...7fea56](https://www.virustotal.com/gui/file/c4256a0c990b75482db93bb6f3f16c8da6b6fa8a9a7a2413ccd5be7f947fea56?nocache=1)

## Quick Start

**Requires Administrator privileges.**

1. Download from [Releases](https://github.com/26zl/PleaseTweakWindows/releases)
2. Run `PleaseTweakWindows.exe` as Administrator
3. Accept the restore-point prompt on first tweak

## Categories

14 categories, ~128 sub-tweaks.

| Category | Sub-tweaks | Description |
| --- | --- | --- |
| **Gaming Optimizations** | 12 | GPU drivers, Game Bar, MSI mode, DirectX, polling rate, MPO, HAGS, Game Mode |
| **Performance & Power** | 4 | Ultimate power plan, performance registry batch, HDCP, DPI scaling fix |
| **Network Optimizations** | 3 | IPv4-only adapter bindings, Smart Network Optimization (standard / aggressive) |
| **Debloat** | 7 | Remove bloatware (+ persistent), reinstall Store, disable widgets / background apps / unnecessary services |
| **Privacy** | 19 | Telemetry, Copilot, DNS (Cloudflare / Google / DoH), Explorer privacy, MS-account & OneDrive policy, O&O ShutUp profile |
| **Microsoft Defender** | 8 | Controlled Folder Access, network / PUA protection, cloud + max protection, ASR rules, sandbox, gaming-scan tuning |
| **Exploit Protection** | 7 | System & per-app mitigations, ASLR, DEP, SEHOP, Spectre/Meltdown |
| **Device Guard** | 7 | HVCI / Memory Integrity, Credential Guard, LSA protection, vulnerable-driver blocklist, WDigest |
| **Network Security** | 20 | Firewall hardening + logging, TLS / SMB / NTLM / LLMNR / mDNS, country-IP blocking, LOLBin block, RDP NLA, WinRM, PrintNightmare |
| **System Security** | 17 | UAC level, SmartScreen, binary integrity, lock screen, account lockout, audit policy, PowerShell logging, WSH |
| **Customize** | 13 | Dark mode, taskbar, Explorer, context menu, lock screen, Start menu, keyboard shortcuts |
| **Maintenance & Tools** | 4 | Disk cleanup, DDU driver cleanup, Autoruns, C++ redistributables |
| **Windows Update** | 5 | Default / security-only / pause / off / secure modes |
| **Edge** | 2 | Security baseline + HardCore hardening |

Each toggle sub-tweak exposes **Apply** and **Revert** buttons individually. A toggle that depends on another tweak greys out until its prerequisite is applied (live registry check). "Run All" applies every toggle in a category sequentially and stops if you cancel a confirmation dialog — it does not bulk-revert.

## How It Works

```text
WPF UI (.NET 9)
    |
powershell -File <script>.ps1 -Action "<action-id>"
    |
Category Scripts  (Non-interactive dispatchers)
Revert Scripts    (Restore defaults + repair components)
```

- Individual sub-tweaks are executed via `-Action` parameter
- Revert scripts restore defaults and optionally repair affected components

## Requirements

**End users:**

- Windows 10/11
- Administrator privileges
- Windows PowerShell 5.1 (built-in)

**Developers / building from source:**

- [.NET 9 SDK](https://dotnet.microsoft.com/download)
- Windows (WPF targets `net9.0-windows`)

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

## Build a Release EXE

```cmd
REM Produces dist\PleaseTweakWindows.zip with the single-file self-contained EXE.
Build.bat
```

`Build.bat` runs `dotnet test` → `dotnet publish -c Release -r win-x64 --self-contained -p:PublishSingleFile=true` → copies the EXE + README + LICENSE into `dist\PleaseTweakWindows\` → zips it. Scripts are embedded inside the EXE; no loose `scripts\` folder ships with the release.

## Disclaimer

**USE AT YOUR OWN RISK.** Some changes may require manual restoration. This project is provided as-is with no warranty.

## License

MIT License
