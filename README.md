# PleaseTweakWindows

A lightweight tool for optimizing Windows settings to enhance performance, security, and privacy.  
Designed for power users who want a simple way to tweak Windows settings.

## Status: In Development

This program is **under active development**. Check the issues tab for known problems.

---

## Installation

### Download and Install

1. Go to the [GitHub repository](https://github.com/26zl/PleaseTweakWindows).
2. Download the latest `PleaseTweakWindows-<version>-win-x64.zip`.
3. Unzip the file to extract the `PleaseTweakWindows.exe` installer.
4. Run the installer and follow the on-screen instructions.

> **Note:** You do **not** need to install Java — the installer includes everything.

---

## Alternative: Use the PowerShell Script

If you **prefer not to install anything** or want a minimal approach, you can run the built-in **PowerShell tweak menu**.

### How to Use the PowerShell Script

1. Download or clone the repository.
2. Navigate to the project root folder.
3. Double-click `RunTweaks.bat` — this will automatically launch the tweak menu.

### Manually Running the PowerShell Script

```powershell
cd "path\to\PleaseTweakWindows"
powershell.exe -ExecutionPolicy Bypass -File .\PleaseTweakWindowsPScript.ps1
```

You can apply or revert tweaks by entering **Y (Yes)** or **N (No)** in the terminal.

This method is perfect for users who want a **quick, no-install experience**.

---

## Build from Source (For Developers)

### Clone the Repository

```bash
git clone https://github.com/26zl/PleaseTweakWindows.git
cd PleaseTweakWindows
```

### Build the Project
Make sure to have Maven installed. https://maven.apache.org/install.html
```batch
mvn clean package
mvn package
```

This generates artifacts in the `target` folder. The folder is auto-cleaned on every build and usually excluded from version control.

### Run the Application (Using Installed Java)

```batch
java -jar target\PleaseTweakWindows-1.0-SNAPSHOT.jar
```

### Run the Application (Using Custom Runtime)

```powershell
path\to\custom-runtime\bin\java.exe -jar path\to\target\PleaseTweakWindows-1.0-SNAPSHOT.jar
```

This lets you run the app on machines **without a full Java installation**.

---

## Create Custom Runtime with jlink

```batch
jlink --module-path "%JAVA_HOME%\jmods;path\to\javafx-jmods" --add-modules java.base,javafx.controls,javafx.graphics,javafx.base,java.logging --output custom-runtime --strip-debug --compress=2 --no-header-files --no-man-pages
```

This generates the `custom-runtime` folder expected by the build scripts.

---

## Build the EXE Installer

A batch script (`Build.bat`) automates creating the EXE installer. It performs:

- Deleting any previous app image and installer files.
- Creating an app image using `jpackage`.
- Copying external scripts into the app image.
- Creating an EXE installer with an upgrade UUID (so new installs overwrite old).
- Zipping the installer EXE into the project root.
- Removing the standalone EXE, leaving only the ZIP.

### Prerequisites

- **Java 21 or later** (must include `jpackage`; add it to PATH).
- **JavaFX SDK and Jmods** (from [GluonHQ](https://gluonhq.com/products/javafx/)).
- **WiX Toolset 3.11** (not 3.14) from [WiX Releases](https://wixtoolset.org/releases/).
    - Ensure `candle.exe` and `light.exe` are in your PATH.

> ⚠ **Important:** If you get error 2738 (ICE errors) during build, register the VBScript and JScript engines manually:
>
> ```cmd
> regsvr32 vbscript.dll
> regsvr32 jscript.dll
> ```
---

### Running the Script

```batch
Build.bat
```

When finished, the installer ZIP (e.g., `PleaseTweakWindows-1.0-win-x64.zip`) will be in the project root.  
Unzip it and run the contained `PleaseTweakWindows.exe`.

---

## Contributing

Pull requests are welcome!  
If you want to contribute, please open an issue or submit a PR. Contributions related to:
- Optimizing tweaks
- Improving the UI
- Adding new security or privacy features

…are especially appreciated.

---

## License
This project is licensed under the [MIT License](LICENSE).
