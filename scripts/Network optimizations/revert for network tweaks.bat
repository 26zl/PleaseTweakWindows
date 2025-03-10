@echo off
color b
echo Reverting Network Optimization and Privacy Tweaks...
echo.

REM ==============================
REM REVERT LEGACY NETWORKING PROTOCOLS
REM ==============================
REM Restores the default state of Teredo, ISATAP, and 6to4 tunneling protocols.
netsh interface teredo set state default
netsh interface 6to4 set state default
netsh int isatap set state default

REM Resets the Windows network stack (Winsock) to default.
netsh winsock reset

REM ==============================
REM RE-ENABLE NETWORK PERFORMANCE FEATURES
REM ==============================
REM Restores TCP/IP task offloading to default.
netsh int ip set global taskoffload=enabled

REM Resets neighbor cache limit to Windows default.
netsh int ip set global neighborcachelimit=default

REM Re-enables TCP timestamps for accurate RTT measurements.
netsh int tcp set global timestamps=enabled

REM Enables TCP heuristic processing for auto-optimization.
netsh int tcp set heuristics enabled

REM Restores TCP autotuning to Windows default behavior.
netsh int tcp set global autotuninglevel=normal

REM Re-enables TCP chimney offload for optimized network processing.
netsh int tcp set global chimney=enabled

REM Enables Explicit Congestion Notification (ECN).
netsh int tcp set global ecncapability=enabled

REM ==============================
REM REVERT NETWORK ADAPTER SETTINGS
REM ==============================
REM Disables Receive Side Scaling (RSS) to revert to default.
netsh int tcp set global rss=disabled

REM Enables Receive Segment Coalescing (RSC) to optimize large packet processing.
netsh int tcp set global rsc=enabled

REM Disables Direct Cache Access (DCA) to revert to default behavior.
netsh int tcp set global dca=disabled

REM Disables NetDMA to prevent potential conflicts with modern NICs.
netsh int tcp set global netdma=disabled

REM Re-enables TCP Non-SACK RTT Resiliency for better loss recovery.
netsh int tcp set global nonsackrttresiliency=enabled

REM Re-enables Multipath Provider Path (MPP) for secure multipath routing.
netsh int tcp set security mpp=enabled

REM Re-enables TCP security profiles for additional protection.
netsh int tcp set security profiles=enabled

REM Re-enables ICMP redirects to allow legitimate network path adjustments.
netsh int ip set global icmpredirects=enabled

REM ==============================
REM RESTORE DEFAULT NETWORK ADAPTER SETTINGS
REM ==============================
REM Re-enables QoS on all network adapters to restore bandwidth prioritization.
powershell -Command "Enable-NetAdapterQoS -Name '*'"

REM Re-enables power management on network adapters to improve energy efficiency.
powershell -Command "ForEach($adapter In Get-NetAdapter){Enable-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction SilentlyContinue}"

REM Re-enables Large Send Offload (LSO) on network adapters for optimized TCP performance.
powershell -Command "ForEach($adapter In Get-NetAdapter){Enable-NetAdapterLso -Name $adapter.Name -ErrorAction SilentlyContinue}"

REM ==============================
REM REVERT REGISTRY SETTINGS TO DEFAULT
REM ==============================
REM Deletes manually added registry keys to restore Windows defaults.
Reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "EnableICMPRedirect" /f
Reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "EnablePMTUDiscovery" /f
Reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "Tcp1323Opts" /f
Reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "TcpMaxDupAcks" /f
Reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "TcpTimedWaitDelay" /f
Reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "GlobalMaxTcpWindowSize" /f
Reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "TcpWindowSize" /f
Reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "MaxConnectionsPerServer" /f
Reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "MaxUserPort" /f
Reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "SackOpts" /f
Reg.exe delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "DefaultTTL" /f
Reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "NetworkThrottlingIndex" /f

REM ==============================
REM REVERT TCPIP\SERVICE PROVIDER PRIORITY SETTINGS
REM ==============================
REM Removes custom TCP/IP service priority settings.
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v LocalPriority /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v HostsPriority /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v DnsPriority /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v NetbtPriority /f

REM ==============================
REM REVERT TCPIP\PARAMETERS SETTINGS
REM ==============================
REM Deletes custom TCP/IP tweaks and restores Windows defaults.
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DisableLargeMtu /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DisableTaskOffload /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DelayedAckFrequency /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DelayedAckTicks /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v CongestionAlgorithm /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MultihopSets /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v FastCopyReceiveThreshold /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v FastSendDatagramThreshold /f

REM ==============================
REM REVERT AFD\PARAMETERS SETTINGS
REM ==============================
REM Removes custom network stack parameters in the Ancillary Function Driver (AFD).
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultReceiveWindow /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultSendWindow /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v FastCopyReceiveThreshold /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v FastSendDatagramThreshold /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DynamicSendBufferDisable /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v IgnorePushBitOnReceives /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v NonBlockingSendSpecialBuffering /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DisableRawSecurity /f

REM ==============================
REM REVERT LANMANWORKSTATION SETTINGS
REM ==============================
REM Restores default settings for Large MTU.
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v DisableLargeMtu /f

echo All network settings have been reverted to their defaults.
echo Please restart your computer for changes to take effect.

pause