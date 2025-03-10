@echo off
color b
echo Disabling unnecessary services for low latency and minimal background processes...
echo.

REM ==============================
REM TELEMETRY & CLOUD SERVICES
REM ==============================
echo Disabling Connected User Experiences and Telemetry...
sc stop DiagTrack
sc config DiagTrack start= disabled

echo Disabling Data Usage Service...
sc stop DusmSvc
sc config DusmSvc start= disabled

echo Disabling Windows Error Reporting Service...
sc stop WerSvc
sc config WerSvc start= disabled

echo Disabling Windows Update Medic Service...
sc stop WaaSMedicSvc
sc config WaaSMedicSvc start= disabled

echo Disabling Background Intelligent Transfer Service (BITS)...
sc stop BITS
sc config BITS start= disabled

echo Disabling Windows Insider Service...
sc stop wisvc
sc config wisvc start= disabled

REM ==============================
REM XBOX & GAMING SERVICES
REM ==============================
echo Disabling Xbox Services...
sc stop XblAuthManager
sc config XblAuthManager start= disabled
sc stop XblGameSave
sc config XblGameSave start= disabled
sc stop XboxNetApiSvc
sc config XboxNetApiSvc start= disabled
sc stop GamingServices
sc config GamingServices start= disabled
sc stop GamingServicesNet
sc config GamingServicesNet start= disabled

REM ==============================
REM NETWORK & SHARING SERVICES
REM ==============================
echo Disabling HomeGroup Services...
sc stop HomeGroupListener
sc config HomeGroupListener start= disabled
sc stop HomeGroupProvider
sc config HomeGroupProvider start= disabled

echo Disabling Peer-to-Peer Networking (BranchCache)...
sc stop PeerDistSvc
sc config PeerDistSvc start= disabled

echo Disabling Remote Desktop Services...
sc stop TermService
sc config TermService start= disabled

echo Disabling Windows Mobile Hotspot Service...
sc stop icssvc
sc config icssvc start= disabled

REM ==============================
REM LOCATION & MAP SERVICES
REM ==============================
echo Disabling Geolocation Service...
sc stop lfsvc
sc config lfsvc start= disabled

echo Disabling Downloaded Maps Manager...
sc stop MapsBroker
sc config MapsBroker start= disabled

REM ==============================
REM PRINT & DEVICE SERVICES
REM ==============================
echo Disabling Print Spooler (if you don't use printers)...
sc stop Spooler
sc config Spooler start= disabled

echo Disabling Windows Fax and Scan (if not needed)...
sc stop Fax
sc config Fax start= disabled

echo Disabling Bluetooth Support Services (if you don't use Bluetooth)...
sc stop BthHFSrv
sc config BthHFSrv start= disabled
sc stop bthserv
sc config bthserv start= disabled

REM ==============================
REM WINDOWS STORE & CLOUD SYNC
REM ==============================
echo Disabling Microsoft Store Install Service...
sc stop InstallService
sc config InstallService start= disabled

echo Disabling Microsoft Account Sign-in Assistant...
sc stop wlidsvc
sc config wlidsvc start= disabled

echo Disabling OneSyncSvc (syncs email, calendar, contacts, etc.)...
sc stop OneSyncSvc
sc config OneSyncSvc start= disabled

REM ==============================
REM PUSH NOTIFICATIONS & MESSAGING
REM ==============================
echo Disabling Windows Push Notifications...
sc stop WpnService
sc config WpnService start= disabled

echo Disabling Windows Push Notifications User Service...
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\WpnUserService" /v Start /t REG_DWORD /d 00000004 /f

echo Disabling Messaging Service...
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\MessagingService" /v Start /t REG_DWORD /d 00000004 /f

REM ==============================
REM OTHER BACKGROUND SERVICES
REM ==============================
echo Disabling Windows Retail Demo Service...
sc stop RetailDemo
sc config RetailDemo start= disabled

echo Disabling AllJoyn Router Service (IoT-related)...
sc stop AJRouter
sc config AJRouter start= disabled

echo Disabling Auto Time Zone Updater...
sc stop tzautoupdate
sc config tzautoupdate start= disabled

echo Disabling Connected Devices Platform Service...
sc stop CDPSvc
sc config CDPSvc start= disabled

echo Disabling Parental Controls...
sc stop WpcMonSvc
sc config WpcMonSvc start= disabled

echo Disabling Windows Biometric Service (Fingerprint/Face Recognition)...
sc stop WbioSrvc
sc config WbioSrvc start= disabled

echo.
echo All unnecessary services have been disabled.
echo Restart your computer for changes to take effect.
pause