@echo off
color b
echo Reverting the wide list of services back to automatic startup...
echo.

REM ==============================
REM TELEMETRY & CLOUD SERVICES
REM ==============================
sc config DiagTrack start= auto
sc config DusmSvc start= auto
sc config WerSvc start= auto
sc config WaaSMedicSvc start= auto
sc config BITS start= delayed-auto
sc config wisvc start= auto
sc config CDPSvc start= auto
sc config CDPUserSvc_* start= auto

REM ==============================
REM XBOX & GAMING SERVICES
REM ==============================
sc config XblAuthManager start= auto
sc config XblGameSave start= auto
sc config XboxNetApiSvc start= auto
sc config GamingServices start= auto
sc config GamingServicesNet start= auto

REM ==============================
REM NETWORK & SHARING SERVICES
REM ==============================
sc config HomeGroupListener start= auto
sc config HomeGroupProvider start= auto
sc config PeerDistSvc start= auto
sc config TermService start= auto
sc config icssvc start= auto
sc config RasAuto start= auto
sc config RasMan start= auto
sc config RemoteAccess start= auto
sc config RemoteRegistry start= auto
sc config LanmanServer start= auto
sc config LanmanWorkstation start= auto
sc config Netlogon start= auto
sc config NetSetupSvc start= auto
sc config Netman start= auto
sc config Dhcp start= auto
sc config Dnscache start= auto

REM ==============================
REM LOCATION & MAP SERVICES
REM ==============================
sc config lfsvc start= auto
sc config MapsBroker start= auto
sc config NaturalAuthentication start= auto

REM ==============================
REM PRINT & DEVICE SERVICES
REM ==============================
sc config Spooler start= auto
sc config Fax start= auto
sc config BthHFSrv start= auto
sc config bthserv start= auto
sc config DeviceAssociationService start= auto
sc config DevicesFlowUserSvc_* start= auto
sc config WPDBusEnum start= auto
sc config PlugPlay start= auto
sc config StiSvc start= auto

REM ==============================
REM WINDOWS STORE & CLOUD SYNC
REM ==============================
sc config InstallService start= auto
sc config wlidsvc start= auto
sc config OneSyncSvc_* start= auto
sc config WpcMonSvc start= auto
sc config WbioSrvc start= auto

REM ==============================
REM PUSH NOTIFICATIONS & MESSAGING
REM ==============================
sc config WpnService start= auto
sc config MessagingService_* start= auto
sc config WpnUserService_* start= auto

REM ==============================
REM MEDIA & STREAMING SERVICES
REM ==============================
sc config AudioEndpointBuilder start= auto
sc config Audiosrv start= auto
sc config AudioSrv start= auto
sc config BcastDVRUserService_* start= auto
sc config CaptureService_* start= auto
sc config FrameServer start= auto
sc config FrameServerMonitor start= auto
sc config PrintNotify start= auto

REM ==============================
REM OTHER BACKGROUND SERVICES
REM ==============================
sc config AJRouter start= auto
sc config tzautoupdate start= auto
sc config RetailDemo start= auto
sc config fdPHost start= auto
sc config SharedAccess start= auto
sc config VaultSvc start= auto
sc config W32Time start= auto
sc config upnphost start= auto
sc config svsvc start= auto
sc config swprv start= auto
sc config wbengine start= auto
sc config SmsRouter start= auto
sc config TabletInputService start= auto
sc config TroubleshootingSvc start= auto
sc config Workfolderssvc start= auto

REM ==============================
REM SECURITY & AUTHENTICATION SERVICES
REM ==============================
sc config SCardSvr start= auto
sc config SamSs start= auto
sc config RpcSs start= auto
sc config RpcEptMapper start= auto
sc config DcomLaunch start= auto
sc config EventLog start= auto
sc config SecurityHealthService start= auto
sc config Sense start= auto
sc config TrustedInstaller start= auto
sc config UevAgentService start= auto

REM ==============================
REM PERFORMANCE & OPTIMIZATION
REM ==============================
sc config SysMain start= auto
sc config PcaSvc start= auto
sc config PerfHost start= auto
sc config DiagTrack start= auto
sc config diagnosticshub.standardcollector.service start= auto

REM ==============================
REM VIRTUALIZATION & HYPER-V
REM ==============================
sc config vmicguestinterface start= auto
sc config vmicheartbeat start= auto
sc config vmickvpexchange start= auto
sc config vmicrdv start= auto
sc config vmicshutdown start= auto
sc config vmictimesync start= auto
sc config vmicvmsession start= auto
sc config vmicvss start= auto
sc config vm3dservice start= auto
sc config HvHost start= auto

REM ==============================
REM WINDOWS UPDATE & MAINTENANCE
REM ==============================
sc config UsoSvc start= auto
sc config wuauserv start= auto
sc config WaaSMedicSvc start= auto
sc config sspvc start= auto

REM ==============================
REM EDGE & BROWSER SERVICES
REM ==============================
sc config edgeupdate start= auto
sc config edgeupdatem start= auto
sc config MicrosoftEdgeElevationService start= auto

echo.
echo All listed services have been reverted to automatic.
echo Please restart your computer for changes to take effect.
pause
