@echo off
color b

:: Revert Teredo state
netsh interface teredo set state default

:: Revert 6to4 state
netsh interface 6to4 set state default

:: Revert Winsock to original state
netsh winsock reset

:: Revert ISATAP state
netsh int isatap set state default

:: Re-enable TCP/IP Task Offload
netsh int ip set global taskoffload=enabled

:: Revert Neighbor Cache Limit
netsh int ip set global neighborcachelimit=default

:: Re-enable TCP timestamps
netsh int tcp set global timestamps=enabled

:: Re-enable TCP heuristic processing
netsh int tcp set heuristics enabled

:: Re-enable TCP autotuning
netsh int tcp set global autotuninglevel=normal

:: Re-enable TCP chimney offload
netsh int tcp set global chimney=enabled

:: Re-enable ECN capability
netsh int tcp set global ecncapability=enabled

:: Disable TCP RSS (Receive Side Scaling)
netsh int tcp set global rss=disabled

:: Re-enable TCP RSC (Receive Segment Coalescing)
netsh int tcp set global rsc=enabled

:: Disable TCP DCA (Direct Cache Access)
netsh int tcp set global dca=disabled

:: Disable TCP NetDMA
netsh int tcp set global netdma=disabled

:: Re-enable TCP Non-SACK RTT Resiliency
netsh int tcp set global nonsackrttresiliency=enabled

:: Re-enable TCP MPP (Multipath Provider Path)
netsh int tcp set security mpp=enabled

:: Re-enable TCP security profiles
netsh int tcp set security profiles=enabled

:: Re-enable ICMP redirects
netsh int ip set global icmpredirects=enabled

:: Re-enable QoS on network adapters
powershell -Command "Enable-NetAdapterQoS -Name '*'"

:: Re-enable power management on network adapters
powershell -Command "ForEach($adapter In Get-NetAdapter){Enable-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction SilentlyContinue}"

:: Re-enable Large Send Offload (LSO) on network adapters
powershell -Command "ForEach($adapter In Get-NetAdapter){Enable-NetAdapterLso -Name $adapter.Name -ErrorAction SilentlyContinue}"

:: Revert Registry settings
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

:: Revert Tcpip\ServiceProvider settings
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v LocalPriority /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v HostsPriority /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v DnsPriority /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v NetbtPriority /f

:: Revert Tcpip\Parameters settings
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DisableLargeMtu /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DisableTaskOffload /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DelayedAckFrequency /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DelayedAckTicks /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v CongestionAlgorithm /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MultihopSets /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v FastCopyReceiveThreshold /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v FastSendDatagramThreshold /f

:: Revert AFD\Parameters settings
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultReceiveWindow /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultSendWindow /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v FastCopyReceiveThreshold /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v FastSendDatagramThreshold /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DynamicSendBufferDisable /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v IgnorePushBitOnReceives /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v NonBlockingSendSpecialBuffering /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DisableRawSecurity /f

:: Re-enable settings for LanmanWorkstation\Parameters
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v DisableLargeMtu /f

echo All settings have been reverted to their defaults.
pause
