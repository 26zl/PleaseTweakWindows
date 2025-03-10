@echo off
color b

:: Revert DPI scaling and blurry windows, text and elements
reg delete "HKEY_CURRENT_USER\Control Panel\Desktop" /v "Win8DpiScaling" /f
reg delete "HKEY_CURRENT_USER\Control Panel\Desktop" /v "DpiScalingVer" /f
reg delete "HKEY_CURRENT_USER\Control Panel\Desktop" /v "LogPixels" /f

:: Re-enable Advertising ID
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d "1" /f

:: Re-enable Windows Activity Feed
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableActivityFeed" /f

:: Re-enable Silent Installed Apps
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SilentInstalledAppsEnabled" /f

:: Re-enable Suggestions in Start Menu
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SystemPaneSuggestionsEnabled" /f

:: Re-enable Sync Provider Notifications
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowSyncProviderNotifications" /t REG_DWORD /d "1" /f

:: Re-enable Soft Landing
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SoftLandingEnabled" /f

:: Re-enable Rotating Lock Screen
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "RotatingLockScreenEnabled" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "RotatingLockScreenOverlayEnabled" /f

:: Re-enable Windows Consumer Features
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CloudContent" /v "DisableWindowsConsumerFeatures" /f

:: Revert Photo Viewer associations
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" /v ".tif" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" /v ".tiff" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" /v ".bmp" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" /v ".dib" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" /v ".gif" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" /v ".jfif" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" /v ".jpe" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" /v ".jpeg" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" /v ".jpg" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" /v ".jxr" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" /v ".png" /f

:: Re-enable GameDVR
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /t REG_DWORD /d "1" /f
reg add "HKEY_CURRENT_USER\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d "1" /f

:: Restore start type for kdnic, NdisVirtualBus, and Vid services
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
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Hidden" /f
reg delete "HKCU\Software\Microsoft\Windows\DWM" /v "CompositionPolicy" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\DWM" /v "Composition" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\DWM" /v "EnableWindowColorization" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\DWM" /v "EnableAeroPeek" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\DWM" /v "AlwaysHibernateThumbnails" /f

:: Revert Visual Effects Settings
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "VisualFXSetting" /f
reg delete "HKCU\Control Panel\Desktop" /v "DragFullWindows" /f
reg delete "HKCU\Control Panel\Desktop" /v "FontSmoothing" /f
reg delete "HKCU\Control Panel\Desktop" /v "UserPreferencesMask" /f
reg delete "HKCU\Control Panel\Desktop\WindowMetrics" /v "MinAnimate" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "ShellState" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "IconsOnly" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ListviewAlphaSelect" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ListviewShadow" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAnimations" /f

:: Re-enable low disk space checks and other policies
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoLowDiskSpaceChecks" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "LinkResolveIgnoreLinkInfo" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoResolveSearch" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoResolveTrack" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoInternetOpenWith
