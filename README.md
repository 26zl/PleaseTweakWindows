# PleaseTweakWindows

🚀 **A lightweight tool for optimizing Windows settings to enhance performance, security, and privacy.**  
🔧 Designed for power users who want a simple way to tweak Windows settings.

---

## ⚠️ Status: In Development

This program is **not yet fully stable**. Current development tasks include:

- ✅ Object-oriented Java refactoring
- ✅ Improved UI for better usability
- ✅ Added verbose output when tweaks are applied
- ⏳ Optimizing all tweaks
- ⏳ Privacy & security tweaks are under development

---

## 📥 Installation

### Download and Install

1. Click on `PleaseTweakWindows.exe.zip` in this repository.

2. Press **"Download Raw File"** to save it to your computer.

3. Unzip the file to extract `PleaseTweakWindows.exe`.

4. Run the `.exe` installer and follow the on-screen instructions.

⚠️ **No need to install Java!** The installer includes everything required.

---

## 🔨 Build from Source (For Developers)

If you prefer to build the project yourself, follow these steps (all commands assume a Windows environment):

### 1. **Clone the Repository**

Open a command prompt or PowerShell and run:

```bash
git clone https://github.com/26zl/PleaseTweakWindows.git
cd PleaseTweakWindows
```

### 2. **Build the Project**

Use the Maven Wrapper to build:

```batch
mvnw clean package
```

This command generates the necessary artifacts in the `target` folder. The `target` folder is automatically re-created during each build and is typically excluded from version control.

### 3. **Run the Application (Using Installed Java)**

If you have Java installed globally, you can run the JAR file with:

```batch
java -jar target/PleaseTweakWindows-1.0-SNAPSHOT.jar
```

### 4. **Run the Application (Using Custom Runtime)**

If you want to run the application using the **custom runtime** (which was generated with jlink), use the following command:

```powershell
& "C:\Users\Lenti\Documents\PleaseTweakWindows\custom-runtime\bin\java.exe" -jar "C:\Users\Lenti\Documents\PleaseTweakWindows\target\PleaseTweakWindows-1.0-SNAPSHOT.jar"
```

> **Note:** This method allows the application to run on a machine **without** requiring a full Java installation.

### 5. **Build the EXE Installer**

A batch script is provided to automate the creation of the EXE installer. This script performs the following steps:

- **Deletes** any previous build of the app image and installer files from the project folder.
- **Creates an app image** using `jpackage`.
- **Copies** your external scripts into a `scripts` folder directly under the generated app image (outside the `app` folder) so that your application can access them as expected.
- **Zips** the installer output directly into the project folder.
- **Removes** the standalone EXE so that only the ZIP file remains.

#### Prerequisites:
- **Java 21** (or a compatible version with jpackage) must be installed.
- **JavaFX SDK**, and **Jmods** from [GluonHQ](https://gluonhq.com/products/javafx/).
- Install the **WiX Toolset** from [WiX Toolset Releases](https://wixtoolset.org/releases/) and ensure candle.exe and light.exe are in your PATH.  
- **7‑Zip** must be installed (with the executable at the specified path).
- Ensure your project folder structure matches the paths in the script.

#### Running the Script

Simply run the provided batch script from the project root:

```batch
Build.bat
```

After the script finishes, you will find the installer ZIP file (e.g., `PleaseTweakWindows-1.0-win-x64.zip`) directly in the project folder. Unzip it and run the `PleaseTweakWindows.exe` installer.

---

## 🚀 Contributing

Pull requests are welcome! If you want to contribute, please open an issue or submit a pull request. Any help in optimizing tweaks, improving the UI, or adding security features is greatly appreciated.

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).

🚀 Happy Tweaking!
