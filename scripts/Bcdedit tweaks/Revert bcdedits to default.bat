@echo off

echo Reverting boot configuration settings...
echo.

REM ==============================
REM RESTORE DEFAULT PLATFORM CLOCK SETTINGS
REM ==============================
REM Removes custom settings for platform clock usage and restores default behavior.
bcdedit /deletevalue useplatformclock

REM ==============================
REM RESTORE DEFAULT PLATFORM TICK SETTINGS
REM ==============================
REM Reverts Windows to its default timing behavior.
bcdedit /deletevalue useplatformtick

REM ==============================
REM ENABLE DYNAMIC TICK AGAIN
REM ==============================
REM Restores dynamic tick behavior, allowing the OS to stop the system timer when idle.
bcdedit /deletevalue disabledynamictick

REM ==============================
REM RE-ENABLE DATA EXECUTION PREVENTION (DEP)
REM ==============================
REM Restores Windows' default security feature that protects against memory-based attacks.
bcdedit /deletevalue nx

REM ==============================
REM RE-ENABLE WINDOWS BOOT UI
REM ==============================
REM Restores the default Windows boot logo and animations.
bcdedit /deletevalue bootux

REM ==============================
REM RESTORE DEFAULT x2APIC POLICY
REM ==============================
REM Removes custom settings for the x2APIC interrupt controller.
bcdedit /deletevalue x2apicpolicy

REM ==============================
REM RE-ENABLE LEGACY APIC MODE IF NEEDED
REM ==============================
REM Removes the custom setting for legacy APIC mode.
bcdedit /deletevalue uselegacyapicmode

REM ==============================
REM RE-ENABLE HYPERVISOR
REM ==============================
REM Restores the default behavior for Windows Hypervisor (Hyper-V).
bcdedit /deletevalue hypervisorlaunchtype

REM ==============================
REM RE-ENABLE TPM BOOT ENTROPY
REM ==============================
REM Allows the Trusted Platform Module (TPM) to contribute entropy during boot.
bcdedit /deletevalue tpmbootentropy

REM ==============================
REM RE-ENABLE QUIET BOOT
REM ==============================
REM Restores the default boot mode where the Windows logo is displayed during startup.
bcdedit /deletevalue quietboot

REM ==============================
REM RESTORE DEFAULT TIME STAMP COUNTER (TSC) POLICY
REM ==============================
REM Resets the TSC synchronization policy to its default value.
bcdedit /deletevalue tscsyncpolicy

echo Boot settings have been reverted to their default values.
echo Please restart your computer for the changes to take effect.

pause