@echo off

echo Updating boot configuration...
bcdedit /set bootux disabled
bcdedit /set hypervisorlaunchtype off
bcdedit /set quietboot yes
bcdedit /set tpmbootentropy ForceDisable
bcdedit /set useplatformclock no
bcdedit /set useplatformtick yes
bcdedit /set x2apicpolicy enable
bcdedit /set uselegacyapicmode no
bcdedit /set tscsyncpolicy legacy
bcdedit /set nx alwaysoff

echo Boot settings updated successfully.
pause