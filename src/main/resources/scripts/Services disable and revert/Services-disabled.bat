@echo off
color b
echo Setting a wide list of services to manual for optimization...
echo.

REM ==============================
REM TELEMETRY & CLOUD SERVICES
REM ==============================
sc config DiagTrack start= demand
sc config DusmSvc start= demand
sc config WerSvc start= demand
sc config WaaSMedicSvc start= demand
sc config BITS start= demand
sc config wisvc start= demand
sc config CDPSvc start= demand
sc config CDPUserSvc_* start= demand

REM ==============================
REM XBOX & GAMING SERVICES
REM ==============================
sc config XblAuthManager start= demand
sc config XblGameSave start= demand
sc config XboxNetApiSvc start= demand
sc config GamingServices start= demand
sc config GamingServicesNet start= demand

REM ==============================
REM NETWORK & SHARING SERVICES
REM ==============================
sc config HomeGroupListener start= demand
sc config HomeGroupProvider start= demand
sc config PeerDistSvc start= demand
sc config TermService start= demand
sc config icssvc start= demand
sc config RasAuto start= demand
sc config RasMan start= demand
sc config RemoteAccess start= demand
sc config RemoteRegistry start= demand
sc config LanmanServer start= demand
sc config LanmanWorkstation start= demand
sc config Netlogon start= demand
sc config NetSetupSvc start= demand
sc config Netman start= demand
sc config Dhcp start= demand
sc config Dnscache start= demand

REM ==============================
REM LOCATION & MAP SERVICES
REM ==============================
sc config lfsvc start= demand
sc config MapsBroker start= demand
sc config NaturalAuthentication start= demand

REM ==============================
REM PRINT & DEVICE SERVICES
REM ==============================
sc config Spooler start= demand
sc config Fax start= demand
sc config BthHFSrv start= demand
sc config bthserv start= demand
sc config DeviceAssociationService start= demand
sc config DevicesFlowUserSvc_* start= demand
sc config WPDBusEnum start= demand
sc config PlugPlay start= demand
sc config StiSvc start= demand

REM ==============================
REM WINDOWS STORE & CLOUD SYNC
REM ==============================
sc config InstallService start= demand
sc config wlidsvc start= demand
sc config OneSyncSvc_* start= demand
sc config WpcMonSvc start= demand
sc config WbioSrvc start= demand

REM ==============================
REM PUSH NOTIFICATIONS & MESSAGING
REM ==============================
sc config WpnService start= demand
sc config MessagingService_* start= demand
sc config WpnUserService_* start= demand

REM ==============================
REM MEDIA & STREAMING SERVICES
REM ==============================
sc config AudioEndpointBuilder start= demand
sc config Audiosrv start= demand
sc config AudioSrv start= demand
sc config BcastDVRUserService_* start= demand
sc config CaptureService_* start= demand
sc config FrameServer start= demand
sc config FrameServerMonitor start= demand
sc config PrintNotify start= demand

REM ==============================
REM OTHER BACKGROUND SERVICES
REM ==============================
sc config AJRouter start= demand
sc config tzautoupdate start= demand
sc config RetailDemo start= demand
sc config fdPHost start= demand
sc config SharedAccess start= demand
sc config VaultSvc start= demand
sc config W32Time start= demand
sc config upnphost start= demand
sc config svsvc start= demand
sc config swprv start= demand
sc config wbengine start= demand
sc config SmsRouter start= demand
sc config TabletInputService start= demand
sc config TroubleshootingSvc start= demand
sc config Workfolderssvc start= demand

REM ==============================
REM SECURITY & AUTHENTICATION SERVICES
REM ==============================
sc config SCardSvr start= demand
sc config SamSs start= demand
sc config RpcSs start= demand
sc config RpcEptMapper start= demand
sc config DcomLaunch start= demand
sc config EventLog start= demand
sc config SecurityHealthService start= demand
sc config Sense start= demand
sc config TrustedInstaller start= demand
sc config UevAgentService start= demand

REM ==============================
REM PERFORMANCE & OPTIMIZATION
REM ==============================
sc config SysMain start= demand
sc config PcaSvc start= demand
sc config PerfHost start= demand
sc config DiagTrack start= demand
sc config diagnosticshub.standardcollector.service start= demand

REM ==============================
REM VIRTUALIZATION & HYPER-V
REM ==============================
sc config vmicguestinterface start= demand
sc config vmicheartbeat start= demand
sc config vmickvpexchange start= demand
sc config vmicrdv start= demand
sc config vmicshutdown start= demand
sc config vmictimesync start= demand
sc config vmicvmsession start= demand
sc config vmicvss start= demand
sc config vm3dservice start= demand
sc config HvHost start= demand

REM ==============================
REM WINDOWS UPDATE & MAINTENANCE
REM ==============================
sc config UsoSvc start= demand
sc config wuauserv start= demand
sc config WaaSMedicSvc start= demand
sc config sspvc start= demand

REM ==============================
REM EDGE & BROWSER SERVICES
REM ==============================
sc config edgeupdate start= demand
sc config edgeupdatem start= demand
sc config MicrosoftEdgeElevationService start= demand

echo.
echo All listed services have been set to manual.
echo Please restart your computer for changes to take effect.
pause
