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

1. **Clone the Repository**
Open a command prompt (or PowerShell) and run:

git clone https://github.com/26zl/PleaseTweakWindows.git
cd PleaseTweakWindows

3. **Build the Project**
Use the Maven Wrapper to build:

Execute the built JAR:
java -jar target/PleaseTweakWindows-1.0-SNAPSHOT.jar

4. **Build the EXE Installer**

Install Java 21, JavaFX SDK and Jmods
From here: https://gluonhq.com/products/javafx/

To package the application into a Windows EXE installer, ensure you have the WiX Toolset installed (download from https://wixtoolset.org/releases/ and install it so that `candle.exe` and `light.exe` are in your PATH). 
Then run:
“C:\Program Files\Java\jdk-21\bin\jpackage.exe” –name PleaseTweakWindows –input “target” –main-jar “PleaseTweakWindows-1.0-SNAPSHOT.jar” –main-class “com.zl.pleasetweakwindows.Main” –type exe –runtime-image “custom-runtime” –dest “installers” –win-shortcut –win-menu –resource-dir “scripts”
This command will create the EXE installer in the `installers` folder and set up desktop shortcuts.

---

## 🚀 Contributing
Pull requests are welcome! If you want to contribute, please open an issue or submit a pull request. Any help in optimizing tweaks, improving the UI, or adding security features is greatly appreciated.

---

## 📜 License
This project is licensed under the [MIT License](LICENSE).

🚀 Happy Tweaking!
