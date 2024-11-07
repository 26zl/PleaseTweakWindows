@echo off
color b

:: Re-enable previously disabled services

echo Re-enabling AllJoyn Router Service...
sc config AJRouter start= demand
sc start AJRouter

echo Re-enabling Auto Time Zone Updater...
sc config tzautoupdate start= demand
sc start tzautoupdate

echo Re-enabling Background Intelligent Transfer Service...
sc config BITS start= demand
sc start BITS

echo Re-enabling Bluetooth Handsfree Service...
sc config BthHFSrv start= demand
sc start BthHFSrv

echo Re-enabling BranchCache...
sc config PeerDistSvc start= demand
sc start PeerDistSvc

echo Re-enabling Client License Service (ClipSVC)...
sc config ClipSVC start= demand
sc start ClipSVC

echo Re-enabling Connected User Experiences and Telemetry...
sc config DiagTrack start= auto
sc start DiagTrack

echo Re-enabling Connected Devices Platform Service...
sc config CDPSvc start= demand
sc start CDPSvc

echo Re-enabling Data Usage...
sc config DusmSvc start= demand
sc start DusmSvc

echo Re-enabling Downloaded Maps Manager...
sc config MapsBroker start= demand
sc start MapsBroker

echo Re-enabling Geolocation Service...
sc config lfsvc start= demand
sc start lfsvc

echo Re-enabling HomeGroup Listener...
sc config HomeGroupListener start= demand
sc start HomeGroupListener

echo Re-enabling HomeGroup Provider...
sc config HomeGroupProvider start= demand
sc start HomeGroupProvider

echo Re-enabling MessagingService_XXXXX...
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\MessagingService" /v Start /t REG_DWORD /d 00000003 /f

echo Re-enabling Print Spooler...
sc config Spooler start= auto
sc start Spooler

echo Re-enabling Retail Demo Service...
sc config RetailDemo start= demand
sc start RetailDemo

echo Re-enabling Windows Push Notifications System Service...
sc config WpnService start= auto
sc start WpnService

echo Re-enabling Windows Mobile Hotspot Service...
sc config icssvc start= demand
sc start icssvc

echo Re-enabling Xbox Live Auth Manager...
sc config XblAuthManager start= demand
sc start XblAuthManager

echo Re-enabling Xbox Live Game Save...
sc config XblGameSave start= demand
sc start XblGameSave

echo Re-enabling Xbox Live Networking Service...
sc config XboxNetApiSvc start= demand
sc start XboxNetApiSvc

echo Re-enabling Windows Push Notifications User Service_XXXXX...
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\WpnUserService" /v Start /t REG_DWORD /d 00000003 /f

echo.
pause
