@echo off
color b
echo Starting Network Optimization and Privacy Tweaks...
echo.

REM ==============================
REM DISABLE LEGACY NETWORKING PROTOCOLS
REM ==============================
REM Disables Teredo tunneling protocol
netsh interface teredo set state disabled

REM Disables 6to4 tunneling protocol
netsh interface 6to4 set state disabled

REM Disables ISATAP tunneling protocol
netsh int isatap set state disable

REM ==============================
REM RESET NETWORK COMPONENTS
REM ==============================
REM Resets the Windows network stack (Winsock)
netsh winsock reset

REM ==============================
REM NETWORK PERFORMANCE OPTIMIZATIONS
REM ==============================
REM Disables TCP/IP task offloading to prevent performance issues with some NICs
netsh int ip set global taskoffload=disabled

REM Sets a larger neighbor cache limit for improved performance in high-traffic environments
netsh int ip set global neighborcachelimit=4096

REM Disables TCP timestamps to reduce overhead and potential fingerprinting risks
netsh int tcp set global timestamps=disabled

REM Disables TCP heuristics for better performance consistency
netsh int tcp set heuristics disabled

REM Disables TCP autotuning to prevent excessive buffering
netsh int tcp set global autotuninglevel=disable

REM Disables TCP chimney offload to avoid network latency issues
netsh int tcp set global chimney=disabled

REM Disables Explicit Congestion Notification (ECN) to improve compatibility
netsh int tcp set global ecncapability=disabled

REM Enables Receive Side Scaling (RSS) for better CPU load balancing across cores
netsh int tcp set global rss=enabled

REM Disables Receive Segment Coalescing (RSC) to reduce latency in some configurations
netsh int tcp set global rsc=disabled

REM Enables Direct Cache Access (DCA) for faster memory access in network operations
netsh int tcp set global dca=enabled

REM Enables NetDMA for optimized direct memory access in network operations
netsh int tcp set global netdma=enabled

REM Disables TCP Non-SACK RTT Resiliency to avoid potential latency issues
netsh int tcp set global nonsackrttresiliency=disabled

REM Disables Multipath Provider Path (MPP) to prevent conflicts with other network settings
netsh int tcp set security mpp=disabled

REM Disables TCP security profiles
netsh int tcp set security profiles=disabled

REM ==============================
REM DISABLE UNNECESSARY NETWORK FEATURES
REM ==============================
REM Disables ICMP redirects to prevent potential MITM attacks
netsh int ip set global icmpredirects=disabled

REM Disables QoS (Quality of Service) on all network adapters
powershell -Command "Disable-NetAdapterQoS -Name '*'"

REM Disables power management for network adapters to prevent latency spikes
powershell -Command "ForEach($adapter In Get-NetAdapter){Disable-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction SilentlyContinue}"

REM Disables Large Send Offload (LSO) on all network adapters to improve latency
powershell -Command "ForEach($adapter In Get-NetAdapter){Disable-NetAdapterLso -Name $adapter.Name -ErrorAction SilentlyContinue}"

REM ==============================
REM REGISTRY TWEAKS FOR NETWORK PERFORMANCE
REM ==============================
REM Disables ICMP redirects
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "EnableICMPRedirect" /t REG_DWORD /d "1" /f

REM Enables Path MTU Discovery
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "EnablePMTUDiscovery" /t REG_DWORD /d "1" /f

REM Disables TCP timestamps and window scaling options
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "Tcp1323Opts" /t REG_DWORD /d "0" /f

REM Sets maximum duplicate ACKs before retransmission
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "TcpMaxDupAcks" /t REG_DWORD /d "2" /f

REM Reduces the TIME_WAIT delay for faster reconnections
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "TcpTimedWaitDelay" /t REG_DWORD /d "32" /f

REM Sets global TCP window size for optimized throughput
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "GlobalMaxTcpWindowSize" /t REG_DWORD /d "8760" /f

REM Increases the maximum number of simultaneous connections
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "MaxConnectionsPerServer" /t REG_DWORD /d "0" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "MaxUserPort" /t REG_DWORD /d "65534" /f

REM Disables Selective Acknowledgement (SACK) for stability
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "SackOpts" /t REG_DWORD /d "0" /f

REM Sets default Time-to-Live (TTL) for outbound packets
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "DefaultTTL" /t REG_DWORD /d "64" /f

REM Disables Network Throttling Index for better network performance in gaming and streaming
Reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "NetworkThrottlingIndex" /t REG_DWORD /d "ffffffff" /f

REM Increases the IRPStackSize for better performance
Reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "IRPStackSize" /t REG_DWORD /d "32" /f


REM ==============================
REM TCPIP\SERVICE PROVIDER PRIORITY SETTINGS
REM ==============================
REM Adjusts priority for name resolution
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v LocalPriority /t REG_DWORD /d 4 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v HostsPriority /t REG_DWORD /d 5 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v DnsPriority /t REG_DWORD /d 6 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v NetbtPriority /t REG_DWORD /d 7 /f

REM ==============================
REM TCPIP\PARAMETERS PERFORMANCE TWEAKS
REM ==============================
REM Adjusts network behavior for optimized performance
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DisableLargeMtu /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DisableTaskOffload /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DelayedAckFrequency /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DelayedAckTicks /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v CongestionAlgorithm /t REG_DWORD /d 1 /f

REM ==============================
REM AFD\PARAMETERS OPTIMIZATION
REM ==============================
REM Adjusts Windows' Ancillary Function Driver (AFD) parameters for improved networking
reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultReceiveWindow /t REG_DWORD /d 16384 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultSendWindow /t REG_DWORD /d 16384 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v IgnorePushBitOnReceives /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DisableRawSecurity /t REG_DWORD /d 1 /f

echo Network optimizations have been successfully applied.
echo Please restart your computer for the changes to take effect.

pause