# PleaseTweakWindows

A lightweight tool for optimizing Windows settings to enhance performance, security, and privacy.  
Designed for power users who want a simple way to tweak Windows settings.

## Status: In Development
This program is not yet fully stable. Check issues.

---

## Installation

### Download and Install
1. Go to the repo and look for `PleaseTweakWindows.exe.zip`.
2. Download the `PleaseTweakWindows.exe.zip` as a RAW file.
3. Unzip the file to extract the `PleaseTweakWindows.exe` installer.
4. Run the installer and follow the on-screen instructions.

No need to install Java. The installer includes everything required.

---

## Alternative: Use the PowerShell Script
If you **prefer not to use the UI**, you can use the **PowerShell-based tweak menu** instead.

### How to Use the PowerShell Script
1. Download the repository and navigate to the project root folder.
2. Locate the batch launcher: `RunTweaks.bat`
3. **Double-click `RunTweaks.bat`**, and it will launch the tweak menu automatically.

### Manually Running the PowerShell Script
If you prefer, you can run the script manually:

1. Open PowerShell and navigate to the script directory:

   ```powershell
   cd "C:\Path\To\PleaseTweakWindows"
   ```

2. Run the script with execution policy bypass:

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\PleaseTweakWindowsPScript.ps1
   ```

3. Follow the on-screen prompts to apply or revert tweaks by entering **Y (Yes) or N (No)**.

This method ensures that **no installation is required**, making it ideal for **users who want a quick, UI-free experience**.

---

## Build from Source (For Developers)
If you prefer to build the project yourself, follow these steps. All commands assume a Windows environment.

### Clone the Repository
Open a command prompt or PowerShell and run:

```bash
git clone https://github.com/26zl/PleaseTweakWindows.git
cd PleaseTweakWindows
```

### Build the Project
Use the Maven Wrapper to build:

```batch
mvnw clean package
```

This command generates the necessary artifacts in the `target` folder. The `target` folder is automatically re-created during each build and is typically excluded from version control.

### Run the Application (Using Installed Java)
If you have Java installed globally, you can run the JAR file with:

```batch
java -jar target/PleaseTweakWindows-1.0-SNAPSHOT.jar
```

### Run the Application (Using Custom Runtime)
If you want to run the application using the custom runtime, use the following command:

```powershell
& "C:\Users\user\Documents\PleaseTweakWindows\custom-runtime\bin\java.exe" -jar "C:\Users\user\Documents\PleaseTweakWindows\target\PleaseTweakWindows-1.0-SNAPSHOT.jar"
```

This method allows the application to run on a machine without requiring a full Java installation.

---

## Build the EXE Installer
A batch script is provided to automate the creation of the EXE installer. This script performs the following steps:

- Deletes any previous build of the app image and installer files from the project folder.
- Creates an app image using `jpackage`.
- Copies external scripts into a `scripts` folder directly under the generated app image.
- Creates an EXE installer with an upgrade UUID so that a new installation automatically overwrites an existing one.
- Zips the installer output directly into the project folder.
- Removes the standalone EXE so that only the ZIP file remains.

### Prerequisites
- Java 21 (or a compatible version with jpackage) must be installed.
- JavaFX SDK and Jmods from [GluonHQ](https://gluonhq.com/products/javafx/).
- Install the WiX Toolset from [WiX Toolset Releases](https://wixtoolset.org/releases/) and ensure `candle.exe` and `light.exe` are in your PATH.
- 7‑Zip must be installed (with the executable at the specified path).
- Ensure your project folder structure matches the paths in the script.

### Running the Script
Run the provided batch script from the project root:

```batch
Build.bat
```

After the script finishes, you will find the installer ZIP file (e.g., `PleaseTweakWindows-1.0-win-x64.zip`) directly in the project folder. Unzip it and run the `PleaseTweakWindows.exe` installer.

---

## Contributing
Pull requests are welcome. If you want to contribute, please open an issue or submit a pull request. Contributions related to optimizing tweaks, improving the UI, or adding security features are appreciated.

---

## License
This project is licensed under the [MIT License](LICENSE).