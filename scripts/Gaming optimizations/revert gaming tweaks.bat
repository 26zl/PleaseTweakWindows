@echo off
color b
echo Starting Reverting Optimization and Privacy Tweaks...
echo.

REM ==============================
REM REVERT DYNAMIC TICK AND HPET SETTINGS
REM ==============================
REM Restores default behavior for system timers and high precision event timers (HPET).
bcdedit /set disabledynamictick no
bcdedit /deletevalue useplatformtick
bcdedit /deletevalue tscsyncpolicy

REM ==============================
REM RE-ENABLE TRUSTED PLATFORM MODULE (TPM) BOOT ENTROPY
REM ==============================
REM Allows the TPM to contribute entropy to the system’s random number generator during boot.
bcdedit /deletevalue tpmbootentropy

REM ==============================
REM REVERT MONITOR LATENCY AND REFRESH LATENCY TOLERANCES
REM ==============================
REM Removes custom latency settings and restores Windows' default monitor response handling.
Reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Services\DXGKrnl" /v "MonitorLatencyTolerance" /f
Reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Services\DXGKrnl" /v "MonitorRefreshLatencyTolerance" /f

REM ==============================
REM RE-ENABLE MOUSE SMOOTHING AND ACCELERATION
REM ==============================
REM Restores default Windows mouse acceleration and smoothing settings.
reg delete "HKCU\Control Panel\Mouse" /v "MouseSensitivity" /f
reg delete "HKCU\Control Panel\Mouse" /v "SmoothMouseXCurve" /f
reg delete "HKCU\Control Panel\Mouse" /v "SmoothMouseYCurve" /f

REM ==============================
REM REVERT PRIVACY AND TELEMETRY SETTINGS
REM ==============================
REM Restores Windows default settings for data collection and advertising.
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d 1 /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SilentInstalledAppsEnabled" /t REG_DWORD /d 1 /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "AllowTelemetry" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\DiagTrack" /v "Start" /t REG_DWORD /d 2 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\dmwappushservice" /v "Start" /t REG_DWORD /d 2 /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\WMI\AutoLogger\AutoLogger-Diagtrack-Listener" /v "Start" /f
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoInstrumentation" /f

REM ==============================
REM REVERT CPU CORE CONTROL AND POWER MANAGEMENT SETTINGS
REM ==============================
REM Restores CPU and power management settings to their original values.
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v "SleepStudyDisabled" /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\943c8cb6-6f93-4227-ad87-e9a3feec08d1" /v "Attributes" /f

REM ==============================
REM REVERT USER INTERFACE TWEAKS
REM ==============================
REM Removes performance tweaks that modify UI responsiveness.
reg delete "HKCU\Control Panel\Desktop" /v "AutoEndTasks" /f
reg delete "HKCU\Control Panel\Desktop" /v "HungAppTimeout" /f
reg delete "HKCU\Control Panel\Desktop" /v "WaitToKillAppTimeout" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" /v "StartupDelayInMSec" /f
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /f
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowInfoTip" /f
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowSuperHidden" /f
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoRecentDocsHistory" /f

REM ==============================
REM RE-ENABLE HANDWRITING ERROR REPORTS
REM ==============================
REM Restores Windows' default handwriting recognition error reporting.
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" /v "PreventHandwritingErrorReports" /f

REM ==============================
REM REVERT SYSTEM PERFORMANCE OPTIMIZATIONS
REM ==============================
REM Restores default memory management settings.
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "DisablePagingExecutive" /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "LargeSystemCache" /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v "DistributeTimers" /f

REM ==============================
REM RE-ENABLE PREFETCH AND SUPERFETCH
REM ==============================
REM Restores Windows' default application preloading behavior.
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "EnablePrefetcher" /t REG_DWORD /d 3 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "EnableSuperfetch" /t REG_DWORD /d 3 /f

REM ==============================
REM REVERT GAME DVR AND TELEMETRY SETTINGS
REM ==============================
REM Restores default settings for Game DVR and background telemetry collection.
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /f
reg delete "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /f
reg delete "HKLM\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR" /v "Value" /f

echo All settings have been reverted to their default states.
echo Please restart your computer for the changes to take effect.

pause