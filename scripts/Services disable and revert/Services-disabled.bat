@echo off
color b

:: Disable non-essential services

echo Disabling AllJoyn Router Service...
sc stop AJRouter
sc config AJRouter start= disabled

echo Disabling Auto Time Zone Updater...
sc stop tzautoupdate
sc config tzautoupdate start= disabled

echo Disabling Background Intelligent Transfer Service...
sc stop BITS
sc config BITS start= disabled

echo Disabling Bluetooth Handsfree Service...
sc stop BthHFSrv
sc config BthHFSrv start= disabled

echo Disabling BranchCache...
sc stop PeerDistSvc
sc config PeerDistSvc start= disabled

echo Disabling Client License Service (ClipSVC)...
sc stop ClipSVC
sc config ClipSVC start= disabled

echo Disabling Connected User Experiences and Telemetry...
sc stop DiagTrack
sc config DiagTrack start= disabled

echo Disabling Connected Devices Platform Service...
sc stop CDPSvc
sc config CDPSvc start= disabled

echo Disabling Data Usage...
sc stop DusmSvc
sc config DusmSvc start= disabled

echo Disabling Downloaded Maps Manager...
sc stop MapsBroker
sc config MapsBroker start= disabled

echo Disabling Geolocation Service...
sc stop lfsvc
sc config lfsvc start= disabled

echo Disabling HomeGroup Listener...
sc stop HomeGroupListener
sc config HomeGroupListener start= disabled

echo Disabling HomeGroup Provider...
sc stop HomeGroupProvider
sc config HomeGroupProvider start= disabled

echo Disabling MessagingService_XXXXX
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\MessagingService" /v Start /t REG_DWORD /d 00000004 /f

echo Disabling Print Spooler...
sc stop Spooler
sc config Spooler start= disabled

echo Disabling Retail Demo Service...
sc stop RetailDemo
sc config RetailDemo start= disabled

echo Disabling Windows Push Notifications System Service...
sc stop WpnService
sc config WpnService start= disabled

echo Disabling Windows Mobile Hotspot Service...
sc stop icssvc
sc config icssvc start= disabled

echo Disabling Xbox Live Auth Manager...
sc stop XblAuthManager
sc config XblAuthManager start= disabled

echo Disabling Xbox Live Game Save...
sc stop XblGameSave
sc config XblGameSave start= disabled

echo Disabling Xbox Live Networking Service...
sc stop XboxNetApiSvc
sc config XboxNetApiSvc start= disabled

echo Disabling Windows Push Notifications User Service_XXXXX
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\WpnUserService" /v Start /t REG_DWORD /d 00000004 /f

echo.
pause
