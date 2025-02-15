# PleaseTweakWindows

🚀 **A small program for tweaking Windows settings to improve performance, security, and privacy.**  
🔧 Designed for power users who want to optimize Windows settings easily.  

---

## **⚠️ Status: In Development**
This program is **not yet fully stable**. Below are the current development tasks:

✅ Object-oriented Java refactoring  
✅ Improved UI for better usability  
✅ Added verbose output when tweaks are applied  
⏳ Optimizing all tweaks  
⏳ Privacy & security tweaks are being developed  

---

## **📥 Installation**
### **🔹 Download and Install**
1. **Click on `PleaseTweakWindows.exe.zip` in this repository.**
2. **Press "Download Raw File"** to save the file.
3. **Run the `.exe` installer** and follow the on-screen instructions.

⚠️ **No need to install Java!** The installer includes everything required.

---

## **🔨 Build from Source (For Developers)**
If you prefer to **build the project yourself**, follow these steps:

# Windows
mvnw.cmd clean package

#Run the application
java -jar target/PleaseTweakWindows-1.0-SNAPSHOT.jar

#To build the exe installer, run:
& "C:\Program Files\Java\jdk-21\bin\jpackage.exe" `
  --name PleaseTweakWindows `
  --input "target" `
  --main-jar "PleaseTweakWindows-1.0-SNAPSHOT.jar" `
  --main-class "com.zl.pleasetweakwindows.Main" `
  --type exe `
  --runtime-image "custom-runtime" `
  --dest "installers" `
  --win-shortcut `
  --win-menu `
  --resource-dir "scripts"

### **1️⃣ Clone the repository**
```sh
git clone https://github.com/26zl/PleaseTweakWindows.git
cd PleaseTweakWindows
