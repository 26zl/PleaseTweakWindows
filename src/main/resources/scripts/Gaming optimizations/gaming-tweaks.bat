@echo off
color b
echo Starting Optimization and Privacy Tweaks...
echo.

REM ==============================
REM DISABLE DYNAMIC TICK AND HPET
REM ==============================
REM Disables the dynamic tick mechanism to improve system stability and responsiveness.
bcdedit /set disabledynamictick yes

REM Removes the use of the platform clock for timing, restoring default behavior.
bcdedit /deletevalue useplatformclock

REM Enables platform tick to improve timing consistency on modern systems.
bcdedit /set useplatformtick yes

REM Sets an enhanced timestamp counter synchronization policy for better CPU timing.
bcdedit /set tscsyncpolicy enhanced

REM ==============================
REM DISABLE TRUSTED PLATFORM MODULE (TPM) BOOT ENTROPY
REM ==============================
REM Prevents TPM from contributing entropy to the system's random number generator during boot.
bcdedit /set tpmbootentropy ForceDisable

REM ==============================
REM MONITOR LATENCY AND REFRESH LATENCY TOLERANCES
REM ==============================
REM Optimizes monitor response times by setting lower latency tolerance values.
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\DXGKrnl" /v "MonitorLatencyTolerance" /t REG_DWORD /d 0 /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\DXGKrnl" /v "MonitorRefreshLatencyTolerance" /t REG_DWORD /d 0 /f

REM ==============================
REM DISABLE MOUSE SMOOTHING AND ACCELERATION
REM ==============================
REM Adjusts mouse settings to provide a raw input experience for better accuracy.
reg add "HKCU\Control Panel\Mouse" /v "MouseSensitivity" /t REG_SZ /d "10" /f
reg add "HKCU\Control Panel\Mouse" /v "SmoothMouseXCurve" /t REG_BINARY /d 0000000000000000C0CC0C0000000000809919000000000040662600000000000033330000000000 /f
reg add "HKCU\Control Panel\Mouse" /v "SmoothMouseYCurve" /t REG_BINARY /d 0000000000000000000038000000000000007000000000000000A800000000000000E00000000000 /f

REM ==============================
REM PRIVACY TWEAKS AND DISABLE DATA COLLECTION
REM ==============================
REM Disables telemetry and background data collection to enhance privacy.
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d 0 /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SilentInstalledAppsEnabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f

REM Disables Windows tracking services.
reg add "HKLM\SYSTEM\CurrentControlSet\Services\DiagTrack" /v "Start" /t REG_DWORD /d 4 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\dmwappushservice" /v "Start" /t REG_DWORD /d 4 /f

REM Prevents Windows Explorer from sending activity tracking data.
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoInstrumentation" /t REG_DWORD /d 1 /f

REM ==============================
REM UNLOCK CPU CORE CONTROL AND SET POWER MANAGEMENT OPTIONS
REM ==============================
REM Disables Sleep Study to prevent logging of sleep states.
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v "SleepStudyDisabled" /t REG_DWORD /d 1 /f

REM Deactivates power-savings functions.
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power" /v "CsEnabled" /t REG_DWORD /d "0" /f

REM Deactivates power-saving functions on USB's.
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\USB" /v "DisableSelectiveSuspend" /t REG_DWORD /d "1" /f

REM Deactivates power-saving functions on PCI-E
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\501a4d13-42af-4429-9fd1-a8218c268e20" /v "Attributes" /t REG_DWORD /d "2" /f
powercfg -setacvalueindex SCHEME_CURRENT SUB_PCIE EXPRESS 0

REM Enables hidden CPU power settings.
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\943c8cb6-6f93-4227-ad87-e9a3feec08d1" /v "Attributes" /t REG_DWORD /d 2 /f

REM ==============================
REM USER INTERFACE ENHANCEMENTS
REM ==============================
REM Adjusts Windows UI behavior for faster responsiveness.
reg add "HKCU\Control Panel\Desktop" /v "AutoEndTasks" /t REG_SZ /d "1" /f
reg add "HKCU\Control Panel\Desktop" /v "HungAppTimeout" /t REG_SZ /d "4000" /f
reg add "HKCU\Control Panel\Desktop" /v "WaitToKillAppTimeout" /t REG_SZ /d "2000" /f

REM Disables startup delay for programs.
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" /v "StartupDelayInMSec" /t REG_DWORD /d 0 /f

REM Disables file extensions hiding in Windows Explorer.
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t REG_DWORD /d 1 /f

REM ==============================
REM DISABLE HANDWRITING ERROR REPORTS
REM ==============================
REM Prevents Windows from collecting handwriting recognition error data.
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" /v "PreventHandwritingErrorReports" /t REG_DWORD /d 1 /f

REM ==============================
REM SYSTEM PERFORMANCE OPTIMIZATIONS
REM ==============================
REM Disables paging executive to keep system files in RAM, improving performance.
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "DisablePagingExecutive" /t REG_DWORD /d 1 /f

REM Enables a larger system cache for better disk performance.
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "LargeSystemCache" /t REG_DWORD /d 1 /f

REM ==============================
REM DISABLE PREFETCH AND SUPERFETCH
REM ==============================
REM Prevents Windows from preloading apps and services, reducing unnecessary disk usage.
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "EnablePrefetcher" /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "EnableSuperfetch" /t REG_DWORD /d 0 /f

REM ==============================
REM DISABLE GAME DVR AND TELEMETRY
REM ==============================
REM Prevents Windows from running background recording and telemetry during gaming.
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /t REG_DWORD /d 0 /f
reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR" /v "Value" /t REG_DWORD /d 0 /f

echo All tweaks and optimizations have been applied successfully.
echo Please restart your computer for changes to take effect.
pause