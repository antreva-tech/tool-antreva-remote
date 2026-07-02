# Managed Access Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the Antreva Remote pilot from attended-only QuickSupport behavior to a single managed-access onboarding flow.

**Architecture:** Keep using the official signed RustDesk pilot binary while Antreva signing is pending. The setup scripts perform a visible admin onboarding flow, install the Windows service, apply Antreva server settings, and set the technician-provided permanent password.

**Tech Stack:** PowerShell, Windows batch, RustDesk Windows CLI, JSON policy, Markdown docs.

---

### Task 1: Update Managed Policy

**Files:**
- Modify: `config/antreva-client-policy.json`
- Modify: `scripts/Validate-AntrevaRemote.ps1`

- [ ] Change the policy channel to `mvp-managed-windows`.
- [ ] Set password-based managed access options.
- [ ] Update validation to require managed access, visible tray, enabled permanent password changes, and enabled unattended release gate.
- [ ] Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Validate-AntrevaRemote.ps1`
- [ ] Expected: `Antreva Remote policy validation passed.`

### Task 2: Implement Managed Setup Scripts

**Files:**
- Modify: `packaging/pilot/Configure-And-Launch-Antreva-Remote-Pilot.ps1`
- Modify: `scripts/Setup-WindowsPilot.ps1`

- [ ] Add administrator detection and relaunch before asking for the permanent password.
- [ ] Prompt the technician for the permanent password in the elevated session.
- [ ] Install RustDesk with the official CLI installer.
- [ ] Locate the installed executable under Program Files.
- [ ] Apply Antreva managed options using RustDesk `--option`.
- [ ] Set the permanent password using RustDesk `--password`.
- [ ] Create visible Antreva Remote shortcuts.
- [ ] Launch the installed app.

### Task 3: Update Pilot Documentation

**Files:**
- Modify: `packaging/pilot/README.md`
- Modify: `docs/operations/PILOT-WINDOWS-TEST.md`
- Modify: `docs/security/ATTENDED-ACCESS-POLICY.md`

- [ ] Replace attended-only language with managed-access onboarding language.
- [ ] Document that the technician sets the permanent password during authorized onboarding.
- [ ] Document that app/tray visibility remains required.
- [ ] Document the managed access test flow.

### Task 4: Verify and Package

**Files:**
- Generated: `artifacts/Antreva-Remote-Pilot-RustDesk-1.4.8.zip`

- [ ] Parse-check modified PowerShell files.
- [ ] Rebuild the pilot zip from `packaging/pilot`.
- [ ] Verify zip contents.
- [ ] Verify the official RustDesk executable Authenticode signature remains valid.
- [ ] Capture the new zip SHA256.
- [ ] Commit and push the branch.
