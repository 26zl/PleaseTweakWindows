# PleaseTweakWindows

![Build](https://github.com/26zl/PleaseTweakWindows/actions/workflows/build.yml/badge.svg)
![License](https://img.shields.io/github/license/26zl/PleaseTweakWindows)
![Downloads](https://img.shields.io/github/downloads/26zl/PleaseTweakWindows/total)
![Stars](https://img.shields.io/github/stars/26zl/PleaseTweakWindows)

> **This tool modifies Windows system settings. Always create a restore point before use.**

Windows optimization tool for performance tuning, gaming, network, privacy, security, and system customization.

<p align="center">
  <img src=".github/logo.png" alt="PleaseTweakWindows Logo" width="200" />
</p>

## Important

> **CREATE A RESTORE POINT BEFORE USING THIS TOOL!**
>
> This tool modifies Windows registry settings, services, and system configuration.
> Some changes may affect system stability. Always backup your system first.

## Quick Start

**Requires Administrator privileges.**

1. Download from [Releases](https://github.com/26zl/PleaseTweakWindows/releases)
2. **Create a System Restore Point** (Settings > System > About > System Protection)
3. Run `PleaseTweakWindows.exe` as Administrator

## Categories

| Category | Sub-tweaks | Description |
| --- | --- | --- |
| **Gaming** | 10 | GPU drivers, Game Bar, MSI mode, DirectX, polling rate |
| **Network** | 3 | IPv4 adapter bindings, Smart Network Optimization, Smart Network Optimization (Aggressive) |
| **General** | 16 | Power plans, bloatware removal, registry tweaks, scaling fixes |
| **Services** | 2 | Disable unnecessary Windows services, restore defaults |
| **Privacy** | 14 | Telemetry, Copilot, DNS-over-HTTPS, tracking, Explorer privacy |
| **Security** | 13 | Firewall hardening, TLS, DEP, SEHOP, Spectre/Meltdown protection |

Each category supports **Apply** (execute tweak) and **Revert** (restore defaults).

## How It Works

```text
JavaFX GUI
    |
powershell -File <script>.ps1 -Action "<action-id>"
    |
Category Scripts  (Non-interactive dispatchers)
Revert Scripts    (Restore defaults + repair components)
```

- Individual sub-tweaks are executed via `-Action` parameter
- Revert scripts restore defaults and optionally repair affected components
- A system restore point prompt appears before any changes

## Requirements

- Windows 10/11
- Administrator privileges
- Windows PowerShell 5.1 (built-in)

## Build from Source

```cmd
REM Requires: Liberica NIK 21+ (or GraalVM with JavaFX), Maven 3.9.9+, Java 21
git clone https://github.com/26zl/PleaseTweakWindows.git
cd PleaseTweakWindows
Build.bat
```

The build produces a native Windows executable with no Java runtime dependency.

## Disclaimer

**USE AT YOUR OWN RISK.** Always create a restore point before applying tweaks. Some changes may require manual restoration. This project is provided as-is with no warranty.

## License

MIT License
