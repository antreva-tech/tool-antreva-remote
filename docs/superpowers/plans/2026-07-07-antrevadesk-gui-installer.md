# AntrevaDesk GUI Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a branded `AntrevaDesk-Setup-0.1.0.exe` GUI installer that bundles x86 and x64 RustDesk payloads and lets customers install the matching architecture.

**Architecture:** Add a thin NSIS GUI bootstrapper around the existing PowerShell managed-access setup backend. Keep the PowerShell script responsible for OS checks, hash/signature verification, service install, Antreva server policy, permanent password setup, shortcuts, and app launch. Update repository verification scripts so CI protects the new installer contract.

**Tech Stack:** PowerShell, NSIS, GitHub Actions, RustDesk upstream Windows EXE payloads, Windows Authenticode verification.

---

### Task 1: Repository Checks for the New Installer Contract

**Files:**
- Modify: `scripts/Test-AntrevaDeskReleaseNaming.ps1`
- Modify: `scripts/Test-AntrevaDeskWindowsSupport.ps1`

- [ ] **Step 1: Write the failing release naming checks**

Add assertions to `scripts/Test-AntrevaDeskReleaseNaming.ps1` for `AntrevaDesk-Setup-0.1.0.exe`, `AntrevaDesk-Setup-0.1.0.sha256.txt`, and absence of the old zip artifact in the workflow upload path.

- [ ] **Step 2: Write the failing Windows support checks**

Add assertions to `scripts/Test-AntrevaDeskWindowsSupport.ps1` for both payload names, the x86 SHA-256, architecture selection in the NSIS script, and documentation that no longer says `32-bit Windows is not supported`.

- [ ] **Step 3: Run tests to verify RED**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-AntrevaDeskReleaseNaming.ps1`
Expected: FAIL because the GUI installer artifact names are not implemented yet.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-AntrevaDeskWindowsSupport.ps1`
Expected: FAIL because the x86 payload and NSIS architecture selection are not implemented yet.

### Task 2: Branding Assets

**Files:**
- Create: `branding/antreva-tech-logo.png`
- Create: `packaging/antrevadesk/assets/banner.bmp`
- Create: `packaging/antrevadesk/assets/dialog.bmp`
- Create: `packaging/antrevadesk/assets/antrevadesk.ico`

- [ ] **Step 1: Copy the provided logo**

Copy `D:\vault\Antreva\code\main-site\public\Antreva Tech Transparente white.png` to `branding/antreva-tech-logo.png`.

- [ ] **Step 2: Generate installer image assets**

Use a local PowerShell image conversion helper to render the transparent white logo onto dark installer-safe backgrounds for `banner.bmp`, `dialog.bmp`, and `antrevadesk.ico`.

- [ ] **Step 3: Verify assets exist**

Run: `Test-Path .\branding\antreva-tech-logo.png; Test-Path .\packaging\antrevadesk\assets\banner.bmp; Test-Path .\packaging\antrevadesk\assets\dialog.bmp; Test-Path .\packaging\antrevadesk\assets\antrevadesk.ico`
Expected: four `True` lines.

### Task 3: PowerShell Backend Architecture Support

**Files:**
- Modify: `packaging/pilot/Configure-And-Launch-Antreva-Remote-Pilot.ps1`
- Modify: `scripts/Setup-WindowsPilot.ps1`

- [ ] **Step 1: Add architecture parameters and payload metadata**

Add `-Architecture` and `-PortableExe` support so the GUI installer can pass either `x86` or `x64`. Store the two RustDesk payload filenames and SHA-256 hashes in one metadata table.

- [ ] **Step 2: Replace the x64-only support check**

Change Windows support checks so x86 Windows is allowed when the selected architecture is `x86`, x64 remains recommended on 64-bit Windows, and x64 selection is blocked on 32-bit Windows.

- [ ] **Step 3: Preserve managed-access behavior**

Keep password prompting, admin elevation, RustDesk service install, server policy application, shortcut creation, logging, and launch behavior unchanged except for using the selected payload path.

- [ ] **Step 4: Run backend checks**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-AntrevaDeskWindowsSupport.ps1`
Expected: still FAIL until the NSIS and docs changes are added.

### Task 4: NSIS GUI Installer and Build Script

**Files:**
- Create: `packaging/antrevadesk/AntrevaDesk-Setup.nsi`
- Modify: `scripts/Build-PilotBundle.ps1`
- Modify: `.github/workflows/build-and-release-installers.yml`

- [ ] **Step 1: Add the NSIS script**

Create `AntrevaDesk-Setup.nsi` with Modern UI pages, AntrevaDesk branding, architecture radio buttons, x64 default on 64-bit Windows, x86-only behavior on 32-bit Windows, extraction of the selected payload and setup script, and a call to PowerShell with `-Architecture` and `-PortableExe`.

- [ ] **Step 2: Update the build script**

Make `scripts/Build-PilotBundle.ps1` download and verify both payloads, stage the PowerShell backend and NSIS assets, call `makensis.exe`, and emit `AntrevaDesk-Setup-0.1.0.exe` plus `AntrevaDesk-Setup-0.1.0.sha256.txt`.

- [ ] **Step 3: Update GitHub Actions**

Install NSIS if needed, upload the EXE and checksum, and update release notes to describe the GUI installer and x86/x64 selection.

- [ ] **Step 4: Run release naming checks**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-AntrevaDeskReleaseNaming.ps1`
Expected: PASS.

### Task 5: Documentation

**Files:**
- Modify: `README.md`
- Modify: `packaging/pilot/README.md`
- Modify: `docs/operations/WINDOWS-7-11-SUPPORT.md`
- Modify: `docs/operations/PILOT-WINDOWS-TEST.md`
- Modify: `docs/compliance/RELEASE-CHECKLIST.md`

- [ ] **Step 1: Update customer-facing install instructions**

Replace the zip/script instructions with `AntrevaDesk-Setup-0.1.0.exe`, describe the architecture picker, and keep the Windows 7 prerequisite notes.

- [ ] **Step 2: Update certification matrix**

List Windows 7 SP1, Windows 8, Windows 8.1, and Windows 10 as x86/x64; list Windows 11 as x64.

- [ ] **Step 3: Run Windows support checks**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-AntrevaDeskWindowsSupport.ps1`
Expected: PASS.

### Task 6: Full Verification

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run repository verification**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Repository.ps1`
Expected: `Repository verification passed.`

- [ ] **Step 2: Run build script if NSIS is available**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-PilotBundle.ps1`
Expected when NSIS is installed: paths for `AntrevaDesk-Setup-0.1.0.exe` and `AntrevaDesk-Setup-0.1.0.sha256.txt`.

If NSIS is not installed locally, verify that the script fails with the explicit `makensis.exe was not found` message and rely on repository verification plus workflow setup.

- [ ] **Step 3: Inspect git diff**

Run: `git diff --check`
Expected: no whitespace errors.

