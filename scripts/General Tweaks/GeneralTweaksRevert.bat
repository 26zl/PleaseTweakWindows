@echo off
color b
echo Reverting all registry and performance tweaks to default settings...
echo.

REM ==============================
REM RESTORE DPI SCALING & FONT SETTINGS
REM ==============================
echo Restoring DPI scaling and font sharpness settings...
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "Win8DpiScaling" /t REG_DWORD /d "1" /f
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "DpiScalingVer" /t REG_DWORD /d "0" /f
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "LogPixels" /t REG_DWORD /d "120" /f

REM ==============================
REM RESTORE PRIVACY & TELEMETRY SETTINGS
REM ==============================
echo Restoring Advertising ID...
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d "1" /f

echo Restoring Windows Activity Feed...
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableActivityFeed" /t REG_DWORD /d "1" /f

echo Restoring Silent Installed Apps...
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SilentInstalledAppsEnabled" /t REG_DWORD /d "1" /f

echo Restoring Start Menu Suggestions...
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SystemPaneSuggestionsEnabled" /t REG_DWORD /d "1" /f

echo Restoring Sync Provider Notifications...
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowSyncProviderNotifications" /t REG_DWORD /d "1" /f

echo Restoring Rotating Lock Screen & Soft Landing...
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SoftLandingEnabled" /t REG_DWORD /d "1" /f
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "RotatingLockScreenEnabled" /t REG_DWORD /d "1" /f
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "RotatingLockScreenOverlayEnabled" /t REG_DWORD /d "1" /f

echo Restoring Windows Consumer Features...
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CloudContent" /v "DisableWindowsConsumerFeatures" /t REG_DWORD /d "0" /f

REM ==============================
REM RESTORE WINDOWS PHOTO VIEWER ASSOCIATIONS
REM ==============================
echo Removing Windows Photo Viewer associations...
for %%a in (".tif" ".tiff" ".bmp" ".dib" ".gif" ".jfif" ".jpe" ".jpeg" ".jpg" ".jxr" ".png") do (
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" /v "%%a" /f
)

REM ==============================
REM RESTORE GAME DVR & XBOX SERVICES
REM ==============================
echo Restoring GameDVR and Xbox Game Bar...
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /t REG_DWORD /d "1" /f
reg add "HKEY_CURRENT_USER\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d "1" /f

REM ==============================
REM RESTORE DISABLED SERVICES
REM ==============================
echo Restoring virtualized network services...
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\kdnic" /v "Start" /t REG_DWORD /d "3" /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NdisVirtualBus" /v "Start" /t REG_DWORD /d "3" /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Vid" /v "Start" /t REG_DWORD /d "3" /f

REM ==============================
REM RESTORE USER EXPERIENCE & UI PERFORMANCE SETTINGS
REM ==============================
echo Restoring UI performance settings...
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "DragFullWindows" /t REG_SZ /d "1" /f
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "FontSmoothing" /t REG_SZ /d "1" /f
reg add "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /v "MinAnimate" /t REG_SZ /d "1" /f
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAnimations" /t REG_DWORD /d "1" /f

REM ==============================
REM RESTORE SYSTEM PERFORMANCE OPTIMIZATION SETTINGS
REM ==============================
echo Restoring service timeout delays...
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "AutoEndTasks" /t REG_SZ /d "0" /f
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "HungAppTimeout" /t REG_SZ /d "5000" /f
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "WaitToKillAppTimeout" /t REG_SZ /d "5000" /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control" /v "WaitToKillServiceTimeout" /t REG_SZ /d "5000" /f

REM ==============================
REM RESTORE FILE EXPLORER DEFAULT ITEMS
REM ==============================
echo Restoring File Explorer default settings...
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" /f
reg add "HKEY_CLASSES_ROOT\CLSID\{B4FB3F98-C1EA-428d-A78A-D1F5659CBA93}\ShellFolder" /f

echo.
echo All tweaks have been reverted to their default Windows settings!
echo Please restart your computer for the changes to take effect.
pause