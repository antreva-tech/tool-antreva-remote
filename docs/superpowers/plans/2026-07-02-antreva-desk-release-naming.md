# Antreva Desk Release Naming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the current installer release surface to Antreva Desk 0.1.0 and publish `Antreva-Desk-0.1.0-Windows.zip`.

**Architecture:** Keep the current pilot bundle pipeline, but centralize product/version naming in the PowerShell build script and mirror those names in the GitHub workflow. Add a repository verification script that fails when old Antreva Remote pilot release names are reintroduced.

**Tech Stack:** PowerShell, GitHub Actions YAML, Markdown documentation.

---

### Task 1: Add Release Naming Verification

**Files:**
- Create: `scripts/Test-AntrevaDeskReleaseNaming.ps1`
- Modify: `scripts/Test-Repository.ps1`

- [ ] **Step 1: Add a failing repository test**

Create a PowerShell test that reads the workflow and build script, then asserts that the release title is `Antreva Desk 0.1.0`, the artifact zip is `Antreva-Desk-0.1.0-Windows.zip`, and the legacy `Antreva-Remote-Pilot-RustDesk-1.4.8` artifact name is absent.

- [ ] **Step 2: Run the test and verify it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-AntrevaDeskReleaseNaming.ps1`

Expected: failure mentioning the missing Antreva Desk release title or artifact name.

- [ ] **Step 3: Wire the test into repository verification**

Call `Test-AntrevaDeskReleaseNaming.ps1` from `Test-Repository.ps1`.

### Task 2: Rename Release Artifacts And Release Page

**Files:**
- Modify: `scripts/Build-PilotBundle.ps1`
- Modify: `.github/workflows/build-and-release-installers.yml`
- Modify: `packaging/pilot/Antreva-Remote-Pilot-Setup.cmd`
- Modify: `packaging/pilot/Configure-And-Launch-Antreva-Remote-Pilot.ps1`
- Modify: `packaging/pilot/README.md`
- Modify: `config/antreva-client-policy.json`
- Modify: `scripts/Validate-AntrevaRemote.ps1`

- [ ] **Step 1: Update bundle name**

Set the build bundle name to `Antreva-Desk-0.1.0-Windows`, which produces `Antreva-Desk-0.1.0-Windows.zip` and `Antreva-Desk-0.1.0-Windows.sha256.txt`.

- [ ] **Step 2: Update workflow artifact and release title**

Set the uploaded artifact name to `Antreva-Desk-0.1.0-Windows`, update release notes to say `Antreva Desk 0.1.0`, and update `RELEASE_TITLE` to `Antreva Desk 0.1.0`.

- [ ] **Step 3: Update setup branding**

Change setup output, shortcuts, local launcher folder, and README text to Antreva Desk 0.1.0 where user-visible.

### Task 3: Verify

**Files:**
- Generated: `artifacts/Antreva-Desk-0.1.0-Windows.zip`
- Generated: `artifacts/Antreva-Desk-0.1.0-Windows.sha256.txt`

- [ ] **Step 1: Run repository verification**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Repository.ps1`

Expected: `Repository verification passed.`

- [ ] **Step 2: Build the renamed bundle**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-PilotBundle.ps1`

Expected output includes `Bundle: ...\artifacts\Antreva-Desk-0.1.0-Windows.zip`.

- [ ] **Step 3: Verify generated artifacts**

Run: `Test-Path .\artifacts\Antreva-Desk-0.1.0-Windows.zip` and `Test-Path .\artifacts\Antreva-Desk-0.1.0-Windows.sha256.txt`

Expected: both return `True`.
