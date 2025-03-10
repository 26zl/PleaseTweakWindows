@echo off

echo Updating boot configuration...
echo.

REM ==============================
REM DISABLE BOOT ANIMATIONS
REM ==============================
REM Disables Windows boot logo and animations during startup.
bcdedit /set bootux disabled

REM ==============================
REM DISABLE HYPERVISOR
REM ==============================
REM Turns off Hyper-V hypervisor. This is useful if you are experiencing
REM performance issues or conflicts with third-party virtualization software.
bcdedit /set hypervisorlaunchtype off

REM ==============================
REM ENABLE QUIET BOOT
REM ==============================
REM Prevents Windows from displaying the boot logo and text messages.
REM Instead, it shows a black screen during startup.
bcdedit /set quietboot yes

REM ==============================
REM DISABLE TPM BOOT ENTROPY
REM ==============================
REM Prevents the Trusted Platform Module (TPM) from contributing entropy
REM to the system’s random number generator during boot.
bcdedit /set tpmbootentropy ForceDisable

REM ==============================
REM DISABLE PLATFORM CLOCK USAGE
REM ==============================
REM Prevents Windows from using the system’s platform clock.
REM This can improve compatibility with certain CPUs and motherboards.
bcdedit /set useplatformclock no

REM ==============================
REM ENABLE PLATFORM TICK
REM ==============================
REM Enables the use of a platform tick for timing instead of
REM relying on periodic interrupts. This can improve performance and stability.
bcdedit /set useplatformtick yes

REM ==============================
REM ENABLE x2APIC POLICY
REM ==============================
REM Enables extended x2APIC mode for better interrupt handling on modern CPUs.
REM This can improve performance on multi-core systems.
bcdedit /set x2apicpolicy enable

REM ==============================
REM DISABLE LEGACY APIC MODE
REM ==============================
REM Disables the use of the older Advanced Programmable Interrupt Controller (APIC) mode.
REM This is recommended for newer systems with x2APIC support.
bcdedit /set uselegacyapicmode no

REM ==============================
REM SET TSC SYNCHRONIZATION POLICY
REM ==============================
REM Forces Windows to use the legacy method for synchronizing the Time Stamp Counter (TSC).
REM This setting can help fix timing issues on some systems.
bcdedit /set tscsyncpolicy legacy

REM ==============================
REM DISABLE DATA EXECUTION PREVENTION (DEP)
REM ==============================
REM Disables the No-Execute (NX) bit feature, which protects against buffer overflow attacks.
REM WARNING: Turning off DEP reduces security and is not recommended unless necessary.
bcdedit /set nx alwaysoff

echo Boot settings updated successfully.
echo Please restart your computer for the changes to take effect.

pause