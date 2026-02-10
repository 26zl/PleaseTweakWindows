# PleaseTweakWindows

> **This project is currently under active development and testing. Use at your own risk.**

Windows optimization tool for performance tuning, gaming, network, privacy, security, and system customization.

![PleaseTweakWindows Logo](.github/logo.png)

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
| **Gaming** | 12 | GPU drivers, Game Bar, FSO/FSE, MSI mode, DirectX, polling rate |
| **Network** | 3 | IPv4 adapter bindings, TCP/IP optimization, DNS |
| **General** | 15 | Power plans, bloatware removal, registry tweaks, scaling fixes |
| **Services** | 2 | Disable unnecessary Windows services, restore defaults |
| **Privacy** | 18 | Telemetry, Copilot, DNS-over-HTTPS, tracking, Live Tiles |
| **Security** | 11 | Firewall hardening, TLS, DEP, SEHOP, Spectre/Meltdown protection |

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
- PowerShell 5.1+ (7+ recommended)

## Build from Source

```cmd
REM Requires: GraalVM 25+, Maven 3.9+, Java 21
git clone https://github.com/26zl/PleaseTweakWindows.git
cd PleaseTweakWindows
Build.bat
```

The build produces a native Windows executable (~31 MB) with no Java runtime dependency.

## Disclaimer

**USE AT YOUR OWN RISK.** Always create a restore point before applying tweaks. Some changes may require manual restoration. This project is provided as-is with no warranty.

## License

MIT License
