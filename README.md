# PleaseTweakWindows

A lightweight tool for optimizing Windows settings to enhance performance, security, and privacy.  
Designed for power users who want a simple, fast way to apply Windows tweaks.

## Status: In Development

This project is **actively developed** — check the Issues tab for known problems or feature requests.

---

## Installation

### Download and Install (Recommended)

If you want to **install**:
1. Download the latest `PleaseTweakWindows-1.0-installer.zip`.
2. Unzip it to extract the `PleaseTweakWindows.exe` installer.
3. Run the installer and follow the on-screen instructions.

✅ **No need to install Java** — the installer includes everything.

---

## Portable Version (No Installer)

If you want a **no-install version**:
1. Download the latest `PleaseTweakWindows-1.0-portable.zip`.
2. Unzip it anywhere.
3. Run `PleaseTweakWindows.exe`.

✅ **No need to install Java** — the portable package includes everything.

---

## Use the PowerShell Script (Minimal Setup)

If you want the absolute minimal approach, you can use the included PowerShell script.

### Run the Script

1. Clone or download the repository.
2. Navigate to the root folder.
3. Double-click `RunTweaks.bat` to launch the PowerShell tweak menu.

### Manually Run

```powershell
cd "path\to\PleaseTweakWindows"
powershell.exe -ExecutionPolicy Bypass -File .\PleaseTweakWindowsPScript.ps1
```

Use **Y (Yes)** or **N (No)** to apply or revert tweaks.

---

## Build from Source (For Developers)

### Prerequisites

- Java 21+ (with `jpackage` available)
- JavaFX SDK and JMods (from [GluonHQ](https://gluonhq.com/products/javafx/))
- WiX Toolset **3.11** (⚠ not 3.14) from [WiX Toolset Releases](https://wixtoolset.org/releases/)
    - Ensure `candle.exe` and `light.exe` are in your PATH.
- Maven (https://maven.apache.org/install.html)

### Clone and Build

```bash
git clone https://github.com/26zl/PleaseTweakWindows.git
cd PleaseTweakWindows
mvn clean package
```

### Create Custom Runtime

```bash
jlink --module-path "%JAVA_HOME%\jmods;path\to\javafx-jmods" --add-modules java.base,javafx.controls,javafx.graphics,javafx.base,javafx.fxml,java.logging --output custom-runtime --strip-debug --compress=2 --no-header-files --no-man-pages
```

### Run the Application

Using installed Java:
```bash
java -jar target\PleaseTweakWindows-1.0-SNAPSHOT.jar
```

Using custom runtime:
```bash
custom-runtime\bin\java.exe -jar target\PleaseTweakWindows-1.0-SNAPSHOT.jar
```

---

## Build the Installer and Portable Packages

Run the provided build script:

```batch
Build.bat
```

This will:
- Build the app image.
- Build the EXE installer.
- Zip both the installer and portable versions into the project root.
- Clean up intermediate folders.

Final outputs:
- `PleaseTweakWindows-1.0-installer.zip`
- `PleaseTweakWindows-1.0-portable.zip`

---

## Troubleshooting (Only if VBScript engine is disabled system-wide)

If you encounter **ICE errors (2738, etc.)** when using WiX:

```cmd
regsvr32 vbscript.dll
regsvr32 jscript.dll
```

---

## Contributing

Pull requests are welcome!  
We especially appreciate help with:
- Optimizing tweak scripts.
- Improving or refining the JavaFX UI.
- Adding useful Windows optimizations.

Please open an issue or submit a PR.

---

## License

This project is licensed under the [MIT License](LICENSE).
