@echo off
color b
echo Reverting all disabled services to default settings...
echo.

REM ==============================
REM TELEMETRY & CLOUD SERVICES
REM ==============================
echo Enabling Connected User Experiences and Telemetry...
sc config DiagTrack start= auto
sc start DiagTrack

echo Enabling Data Usage Service...
sc config DusmSvc start= auto
sc start DusmSvc

echo Enabling Windows Error Reporting Service...
sc config WerSvc start= manual
sc start WerSvc

echo Enabling Windows Update Medic Service...
sc config WaaSMedicSvc start= manual
sc start WaaSMedicSvc

echo Enabling Background Intelligent Transfer Service (BITS)...
sc config BITS start= manual
sc start BITS

echo Enabling Windows Insider Service...
sc config wisvc start= manual
sc start wisvc

REM ==============================
REM XBOX & GAMING SERVICES
REM ==============================
echo Enabling Xbox Services...
sc config XblAuthManager start= demand
sc start XblAuthManager
sc config XblGameSave start= demand
sc start XblGameSave
sc config XboxNetApiSvc start= demand
sc start XboxNetApiSvc
sc config GamingServices start= demand
sc start GamingServices
sc config GamingServicesNet start= demand
sc start GamingServicesNet

REM ==============================
REM NETWORK & SHARING SERVICES
REM ==============================
echo Enabling HomeGroup Services...
sc config HomeGroupListener start= manual
sc start HomeGroupListener
sc config HomeGroupProvider start= manual
sc start HomeGroupProvider

echo Enabling Peer-to-Peer Networking (BranchCache)...
sc config PeerDistSvc start= manual
sc start PeerDistSvc

echo Enabling Remote Desktop Services...
sc config TermService start= manual
sc start TermService

echo Enabling Windows Mobile Hotspot Service...
sc config icssvc start= manual
sc start icssvc

REM ==============================
REM LOCATION & MAP SERVICES
REM ==============================
echo Enabling Geolocation Service...
sc config lfsvc start= manual
sc start lfsvc

echo Enabling Downloaded Maps Manager...
sc config MapsBroker start= manual
sc start MapsBroker

REM ==============================
REM PRINT & DEVICE SERVICES
REM ==============================
echo Enabling Print Spooler...
sc config Spooler start= auto
sc start Spooler

echo Enabling Windows Fax and Scan...
sc config Fax start= demand
sc start Fax

echo Enabling Bluetooth Support Services...
sc config BthHFSrv start= manual
sc start BthHFSrv
sc config bthserv start= manual
sc start bthserv

REM ==============================
REM WINDOWS STORE & CLOUD SYNC
REM ==============================
echo Enabling Microsoft Store Install Service...
sc config InstallService start= demand
sc start InstallService

echo Enabling Microsoft Account Sign-in Assistant...
sc config wlidsvc start= demand
sc start wlidsvc

echo Enabling OneSyncSvc (syncs email, calendar, contacts, etc.)...
sc config OneSyncSvc start= demand
sc start OneSyncSvc

REM ==============================
REM PUSH NOTIFICATIONS & MESSAGING
REM ==============================
echo Enabling Windows Push Notifications...
sc config WpnService start= auto
sc start WpnService

echo Enabling Windows Push Notifications User Service...
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\WpnUserService" /v Start /t REG_DWORD /d 00000002 /f

echo Enabling Messaging Service...
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\MessagingService" /v Start /t REG_DWORD /d 00000002 /f

REM ==============================
REM OTHER BACKGROUND SERVICES
REM ==============================
echo Enabling Windows Retail Demo Service...
sc config RetailDemo start= manual
sc start RetailDemo

echo Enabling AllJoyn Router Service...
sc config AJRouter start= manual
sc start AJRouter

echo Enabling Auto Time Zone Updater...
sc config tzautoupdate start= manual
sc start tzautoupdate

echo Enabling Connected Devices Platform Service...
sc config CDPSvc start= manual
sc start CDPSvc

echo Enabling Parental Controls...
sc config WpcMonSvc start= manual
sc start WpcMonSvc

echo Enabling Windows Biometric Service...
sc config WbioSrvc start= manual
sc start WbioSrvc

echo.
echo All services have been restored to their default settings.
echo Please restart your computer for changes to take effect.
pause