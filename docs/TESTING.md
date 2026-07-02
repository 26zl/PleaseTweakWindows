# Manual Test Plan

Automated CI validates script **syntax/structure**, action-id routing, and the C# unit tests —
but it does **not** apply real tweaks to a real machine. Because the app needs Administrator
rights and can make hard-to-reverse changes, run this manual plan before cutting a release.
CI publishes a Cobertura coverage artifact for every test run; coverage is diagnostic and does
not replace the Windows VM checks below.

> System-mutating tests are intentionally **not** run in GitHub Actions (they would damage shared
> runners). Use a throwaway VM or **Windows Sandbox** (see `tools/PleaseTweakWindows.wsb`).

Test on **Windows 11** (the only supported OS — the app refuses to launch on builds < 22000),
and ideally both **Home** and **Pro** (some policies behave differently, and locale/keyboard-layout
differences have broken tweaks before).

## Smoke test (safe — no destructive changes)

1. Launch the EXE as Administrator; the UAC prompt appears.
2. Accept the restore-point prompt → confirm a restore point is created (`rstrui.exe` lists it).
3. Apply a low-risk toggle (e.g. **Customize → Dark mode**), confirm the change, then use
   **Restore Default** and confirm the documented Windows default returns. Do not expect a
   pre-existing custom value to be reconstructed unless the action explicitly uses a snapshot.
4. Open the output panel; confirm success/failure lines are colour-coded and **Open Logs Folder**
   opens `%LOCALAPPDATA%\PleaseTweakWindows\logs`.
5. Export a profile (**Export All Tweaks**), re-import it, confirm the review dialog opens with
   **nothing pre-selected** (opt-in), tick one tweak, Apply.

## Dependency gating

6. Pick a tweak with a prerequisite (e.g. a Device Guard child of HVCI). With the prerequisite
   **not** applied, confirm Apply is greyed with a tooltip. Apply the prerequisite, confirm the
   dependent tweak becomes enabled.

## Restore-point re-prompt

7. Skip the restore-point prompt on a low-risk tweak, then trigger a **high-risk** tweak →
   confirm you are re-prompted for a restore point (a low-risk skip must not carry over).

## High-risk tweaks (manual, one at a time, with rollback ready)

For each: snapshot the VM first. Apply → reboot if prompted → verify intended effect →
**Restore Default** → reboot → verify the documented default or captured snapshot is restored.

- [ ] Defender ASR / Controlled Folder Access
- [ ] Exploit Protection (system + per-app mitigations)
- [ ] Device Guard: normal HVCI / Memory Integrity and Credential Guard (verify boot + default restore)
- [ ] Device Guard: UEFI-locked HVCI only in a disposable VM with the documented firmware-lock
      removal procedure available; this one-way app action has no automatic Restore Default button
- [ ] Network Security: firewall hardening, SMB/NTLM/LLMNR, country-IP blocking (verify normal LAN/file-sharing afterward)
- [ ] System Security: UAC level, account lockout, audit policy
- [ ] Windows Update mode changes (verify Settings reflects the mode, and Default restores it)
- [ ] Debloat: bloatware removal + reinstall Store
- [ ] Driver tools: NVIDIA/DirectX install (verify signature checks and installer exit-code reporting)

## Partial-failure reporting

8. On a machine where a network tweak can't fully apply (e.g. an adapter without a binding),
   confirm the failure is shown in the log and the run reports a non-zero exit (not silent success).

## Release verification

9. Approve the protected `release` environment deployment for the tag, if required.
10. `(Get-AuthenticodeSignature .\PleaseTweakWindows.exe).Status` is `Valid`.
11. `Get-FileHash -Algorithm SHA256 PleaseTweakWindows.zip` matches `SHA256SUMS.txt`.
12. `SBOM.json` is present in the release and lists dependencies.
