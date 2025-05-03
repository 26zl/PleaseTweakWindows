@echo off
color b
echo Reverting all gemeraø tweaks to Windows defaults...
echo.

:: Restore DPI scaling
reg delete "HKEY_CURRENT_USER\Control Panel\Desktop" /v "Win8DpiScaling" /f
reg delete "HKEY_CURRENT_USER\Control Panel\Desktop" /v "DpiScalingVer" /f
reg delete "HKEY_CURRENT_USER\Control Panel\Desktop" /v "LogPixels" /f

:: Restore Advertising ID
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d "1" /f

:: Restore Windows Activity Feed
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableActivityFeed" /f

:: Restore Silent Installed Apps
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SilentInstalledAppsEnabled" /f

:: Restore Start Menu Suggestions
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SystemPaneSuggestionsEnabled" /f

:: Restore Sync Provider Notifications
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowSyncProviderNotifications" /t REG_DWORD /d "1" /f

:: Restore Soft Landing
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SoftLandingEnabled" /f

:: Restore Rotating Lock Screen
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "RotatingLockScreenEnabled" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "RotatingLockScreenOverlayEnabled" /f

:: Restore Consumer Features
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CloudContent" /v "DisableWindowsConsumerFeatures" /f

:: Remove Photo Viewer file associations
for %%a in (".tif" ".tiff" ".bmp" ".dib" ".gif" ".jfif" ".jpe" ".jpeg" ".jpg" ".jxr" ".png") do (
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" /v "%%a" /f
)

:: Re-enable GameDVR
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /t REG_DWORD /d "1" /f
reg add "HKEY_CURRENT_USER\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d "1" /f

:: Restore services
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\kdnic" /v "Start" /t REG_DWORD /d "3" /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NdisVirtualBus" /v "Start" /t REG_DWORD /d "3" /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Vid" /v "Start" /t REG_DWORD /d "3" /f

:: Remove additional tweaks
reg delete "HKCU\AppEvents\Schemes" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "DelayedDesktopSwitchTimeout" /f
reg delete "HKCU\SOFTWARE\Microsoft\Multimedia\Audio" /v "UserDuckingPreference" /f
reg delete "HKCU\Keyboard Layout\Toggle" /v "Language Hotkey" /f
reg delete "HKCU\Keyboard Layout\Toggle" /v "Hotkey" /f
reg delete "HKCU\Keyboard Layout\Toggle" /v "Layout Hotkey" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "DisallowShaking" /f

:: Restore Accessibility flags
reg delete "HKU.DEFAULT\Control Panel\Accessibility\HighContrast" /v "Flags" /f
reg delete "HKU.DEFAULT\Control Panel\Accessibility\Keyboard Response" /v "Flags" /f
reg delete "HKU.DEFAULT\Control Panel\Accessibility\MouseKeys" /v "Flags" /f
reg delete "HKU.DEFAULT\Control Panel\Accessibility\SoundSentry" /v "Flags" /f
reg delete "HKU.DEFAULT\Control Panel\Accessibility\StickyKeys" /v "Flags" /f
reg delete "HKU.DEFAULT\Control Panel\Accessibility\TimeOut" /v "Flags" /f
reg delete "HKU.DEFAULT\Control Panel\Accessibility\ToggleKeys" /v "Flags" /f

reg delete "HKCU\Control Panel\Accessibility\MouseKeys" /v "Flags" /f
reg delete "HKCU\Control Panel\Accessibility\MouseKeys" /v "MaximumSpeed" /f
reg delete "HKCU\Control Panel\Accessibility\MouseKeys" /v "TimeToMaximumSpeed" /f

:: Restore Explorer defaults
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Hidden" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "IconsOnly" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ListviewAlphaSelect" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ListviewShadow" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAnimations" /f

:: Restore DWM effects
reg delete "HKCU\SOFTWARE\Microsoft\Windows\DWM" /v "CompositionPolicy" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\DWM" /v "Composition" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\DWM" /v "EnableWindowColorization" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\DWM" /v "EnableAeroPeek" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\DWM" /v "AlwaysHibernateThumbnails" /f

:: Restore Visual Effects
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "VisualFXSetting" /f
reg delete "HKCU\Control Panel\Desktop" /v "DragFullWindows" /f
reg delete "HKCU\Control Panel\Desktop" /v "FontSmoothing" /f
reg delete "HKCU\Control Panel\Desktop" /v "UserPreferencesMask" /f
reg delete "HKCU\Control Panel\Desktop\WindowMetrics" /v "MinAnimate" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "ShellState" /f

:: Restore disk space checks and Explorer policies
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoLowDiskSpaceChecks" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "LinkResolveIgnoreLinkInfo" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoResolveSearch" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoResolveTrack" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoInternetOpenWith" /f

echo.
echo All tweaks have been reverted to Windows defaults!
echo Please restart your computer for the changes to take effect.
pause
