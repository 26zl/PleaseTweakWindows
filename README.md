<div align="center">

# PleaseTweakWindows

A lightweight Windows optimization tool for performance and gaming.

<img src=".github/logo.png" alt="PleaseTweakWindows Logo" width="330" />

</div>


## Disclaimer

**USE AT YOUR OWN RISK**

This tool modifies Windows registry settings and system configurations. While all tweaks can be reverted, incorrect usage may cause system instability.

- Always create a restore point before applying tweaks
- Review what each tweak does before applying
- The author is not responsible for any damage or data loss
- Use on production systems at your own discretion

## Quick Start

### PowerShell One-Liner (Lightweight)

Run this command in PowerShell (Administrator) to start the PowerShell interface directly:

```powershell
irm https://raw.githubusercontent.com/26zl/PleaseTweakWindows/main/PleaseTweakWindowsPScript.ps1 | iex
```

**Benefits:**
- No installation required
- Runs directly in your terminal
- Always up-to-date (fetches from main branch)
- No download of large EXE file

### GUI Application (Full Version)

For the JavaFX GUI application with logging and modern interface:

1. Download `PleaseTweakWindows.zip` from [releases](https://github.com/26zl/PleaseTweakWindows/releases)
2. Extract the ZIP file
3. Right-click `PleaseTweakWindows.exe` and select "Run as Administrator"
4. The JavaFX GUI will start with:
   - Visual tweak selector
   - Built-in logging to `logs/` directory
   - Create restore point functionality
   - All tweaks are reversible

**What's included:**
- `PleaseTweakWindows.exe` - Native executable (no Java required)
- `scripts/` - All Windows optimization scripts
- `logs/README.txt` - Logging information

## Features

- Gaming optimizations
- Network tweaks
- Windows settings optimization
- Boot configuration tweaks
- Services management
- System restore point creation
- All tweaks are reversible

## Build from Source

### Requirements

- **GraalVM 25+** with Native Image
- Maven 3.6+

### Build Steps

```cmd
git clone https://github.com/26zl/PleaseTweakWindows.git
cd PleaseTweakWindows
Build.bat
```

The native executable will be in the `target/` folder and a complete distribution package in the `dist/` folder.

### Manual Build (Advanced)

```cmd
mvn clean package -DskipNativeBuild=false
```

This creates the native executable in `target/PleaseTweakWindows.exe`.

## License

MIT License
