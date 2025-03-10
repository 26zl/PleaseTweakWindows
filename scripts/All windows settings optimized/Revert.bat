@echo off
color b
echo Starting Reverting Logging and Privacy Tweaks...
echo.

REM ==============================
REM RE-ENABLE EVENT LOGGING
REM ==============================
REM Restores various system logs that collect event data,
REM including network activity, security logs, and performance tracking.

reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\AppModel" /v "Start" /t REG_DWORD /d "1" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Cellcore" /v "Start" /t REG_DWORD /d "1" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Circular Kernel Context Logger" /v "Start" /t REG_DWORD /d "1" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\CloudExperienceHostOobe" /v "Start" /t REG_DWORD /d "1" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DataMarket" /v "Start" /t REG_DWORD /d "1" /f

REM Re-enable Defender logging
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderApiLogger" /v "Start" /t REG_DWORD /d "1" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderAuditLogger" /v "Start" /t REG_DWORD /d "1" /f

REM Re-enable general diagnostics and performance logs
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DiagLog" /v "Start" /t REG_DWORD /d "1" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\HolographicDevice" /v "Start" /t REG_DWORD /d "1" /f

REM ==============================
REM RE-ENABLE CUSTOMER EXPERIENCE IMPROVEMENT PROGRAM
REM ==============================
REM Allows Windows to collect and send user experience data to Microsoft.

reg delete "HKLM\SOFTWARE\Policies\Microsoft\SQMClient\Windows" /v "CEIPEnable" /f
reg delete "HKLM\SOFTWARE\Policies\Microsoft\SQMClient" /v "CorporateSQMURL" /f

REM ==============================
REM RE-ENABLE SUGGESTIONS AND PERSONALIZATION
REM ==============================
REM Restores Windows' ability to suggest device setup improvements
REM and use diagnostic data for personalization.

reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v "ScoobeSystemSettingEnabled" /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" /v "TailoredExperiencesWithDiagnosticDataEnabled" /f

REM ==============================
REM RE-ENABLE ADVERTISING ID
REM ==============================
REM Allows apps to use the advertising ID for cross-app tracking.

reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v "DisabledByGroupPolicy" /f

REM ==============================
REM RE-ENABLE AUTOMATIC DIAGNOSTICS AND TELEMETRY
REM ==============================
REM Restores Windows' telemetry collection for diagnostic purposes.

reg delete "HKLM\System\CurrentControlSet\Control\WMI\AutoLogger\AutoLogger-Diagtrack-Listener" /v "Start" /f
reg delete "HKLM\System\CurrentControlSet\Control\WMI\AutoLogger\SQMLogger" /v "Start" /f

reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "AllowTelemetry" /f
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /f
reg delete "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "AllowTelemetry" /f

REM ==============================
REM RE-ENABLE ACCESSIBILITY SHORTCUTS
REM ==============================
REM Restores accessibility features like Sticky Keys, Toggle Keys, and Mouse Keys.

reg add "HKEY_CURRENT_USER\Control Panel\Accessibility\MouseKeys" /v "Flags" /t REG_SZ /d "186" /f
reg add "HKEY_CURRENT_USER\Control Panel\Accessibility\StickyKeys" /v "Flags" /t REG_SZ /d "510" /f
reg add "HKEY_CURRENT_USER\Control Panel\Accessibility\Keyboard Response" /v "Flags" /t REG_SZ /d "1278" /f
reg add "HKEY_CURRENT_USER\Control Panel\Accessibility\ToggleKeys" /v "Flags" /t REG_SZ /d "58" /f

REM ==============================
REM FINAL MESSAGE
REM ==============================
echo All logging, telemetry, and privacy settings have been restored to default.
echo Please restart your computer for changes to take full effect.

pause