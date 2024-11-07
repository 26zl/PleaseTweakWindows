@echo off
color b

:: Disable Teredo
netsh interface teredo set state disabled

:: Disable 6to4
netsh interface 6to4 set state disabled

:: Reset Winsock
netsh winsock reset

:: Disable ISATAP
netsh int isatap set state disable

:: Disable TCP/IP Task Offload
netsh int ip set global taskoffload=disabled

:: Set Neighbor Cache Limit
netsh int ip set global neighborcachelimit=4096

:: Disable TCP timestamps
netsh int tcp set global timestamps=disabled

:: Disable TCP heuristic processing
netsh int tcp set heuristics disabled

:: Disable TCP autotuning
netsh int tcp set global autotuninglevel=disable

:: Disable TCP chimney offload
netsh int tcp set global chimney=disabled

:: Disable ECN capability
netsh int tcp set global ecncapability=disabled

:: Enable TCP RSS (Receive Side Scaling)
netsh int tcp set global rss=enabled

:: Disable TCP RSC (Receive Segment Coalescing)
netsh int tcp set global rsc=disabled

:: Enable TCP DCA (Direct Cache Access)
netsh int tcp set global dca=enabled

:: Enable TCP NetDMA
netsh int tcp set global netdma=enabled

:: Disable TCP Non-SACK RTT Resiliency
netsh int tcp set global nonsackrttresiliency=disabled

:: Disable TCP MPP (Multipath Provider Path)
netsh int tcp set security mpp=disabled

:: Disable TCP security profiles
netsh int tcp set security profiles=disabled

:: Disable ICMP redirects
netsh int ip set global icmpredirects=disabled

:: Disable QoS on network adapters
powershell -Command "Disable-NetAdapterQoS -Name '*'"

:: Disable power management on network adapters
powershell -Command "ForEach($adapter In Get-NetAdapter){Disable-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction SilentlyContinue}"

:: Disable Large Send Offload (LSO) on network adapters
powershell -Command "ForEach($adapter In Get-NetAdapter){Disable-NetAdapterLso -Name $adapter.Name -ErrorAction SilentlyContinue}"

:: Modify Registry settings
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "EnableICMPRedirect" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "EnablePMTUDiscovery" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "Tcp1323Opts" /t REG_DWORD /d "0" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "TcpMaxDupAcks" /t REG_DWORD /d "2" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "TcpTimedWaitDelay" /t REG_DWORD /d "32" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "GlobalMaxTcpWindowSize" /t REG_DWORD /d "8760" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "TcpWindowSize" /t REG_DWORD /d "8760" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "MaxConnectionsPerServer" /t REG_DWORD /d "0" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "MaxUserPort" /t REG_DWORD /d "65534" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "SackOpts" /t REG_DWORD /d "0" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "DefaultTTL" /t REG_DWORD /d "64" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "NetworkThrottlingIndex" /t REG_SZ /d "ffffffff" /f

:: Tcpip\ServiceProvider
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v LocalPriority /t REG_DWORD /d 4 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v HostsPriority /t REG_DWORD /d 5 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v DnsPriority /t REG_DWORD /d 6 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v NetbtPriority /t REG_DWORD /d 7 /f

:: Tcpip\Parameters
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DisableLargeMtu /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DisableTaskOffload /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DelayedAckFrequency /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DelayedAckTicks /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v CongestionAlgorithm /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MultihopSets /t REG_DWORD /d 15 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v FastCopyReceiveThreshold /t REG_DWORD /d 16384 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v FastSendDatagramThreshold /t REG_DWORD /d 16384 /f

:: AFD\Parameters
reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultReceiveWindow /t REG_DWORD /d 16384 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultSendWindow /t REG_DWORD /d 16384 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v FastCopyReceiveThreshold /t REG_DWORD /d 16384 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v FastSendDatagramThreshold /t REG_DWORD /d 16384 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DynamicSendBufferDisable /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v IgnorePushBitOnReceives /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v NonBlockingSendSpecialBuffering /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DisableRawSecurity /t REG_DWORD /d 1 /f

:: LanmanWorkstation\Parameters
reg add "HKLM\SYSTEM\
