# Antreva Remote Managed Access Design

## Goal

Antreva Remote is a single managed-access support system for authorized client computers. The technician performs onboarding on the client machine, installs the Windows service, configures the Antreva RustDesk server, and sets the permanent password used for later support sessions.

## Access Model

- Antreva Remote uses managed unattended access by default.
- Onboarding requires an administrator-run installer on the client computer.
- The technician sets the permanent password during onboarding.
- The app/tray remains visible after installation.
- Server, relay, and key settings are locked to Antreva defaults.
- File transfer remains enabled for support sessions.
- Stealth behavior is not supported: no hidden tray, no disguised process, no silent enrollment without an explicit onboarding script, and no bypass of Windows elevation.

## Installer Behavior

The pilot installer uses the official signed RustDesk binary while Antreva-specific signing and branding are pending. The managed setup script:

- verifies the official RustDesk binary hash and Authenticode signature;
- relaunches as Administrator when required;
- prompts the technician for the permanent password in the elevated session;
- installs RustDesk as a Windows service;
- applies Antreva server and managed-access options;
- sets the permanent password through RustDesk's installed/admin CLI path;
- creates Antreva Remote desktop and Start Menu shortcuts;
- starts the installed app.

## Policy Changes

The client policy channel changes from `mvp-attended-windows` to `mvp-managed-windows`.

Managed access policy values:

- `access-mode = password`
- `approve-mode = password`
- `verification-method = use-permanent-password`
- `disable-change-permanent-password = N`
- `hide-tray = N`
- `hide-stop-service = N`
- `allowsUnattendedAccess = true`

## Test Plan

- Validate the policy file.
- Parse-check PowerShell scripts.
- Build the pilot zip.
- Verify the zip contains the setup files and official RustDesk executable.
- On a Windows test machine, run setup as non-admin and confirm it elevates.
- Enter a permanent password during onboarding.
- Confirm RustDesk installs as a service.
- Confirm Antreva server settings are applied.
- Confirm connection by ID works using the permanent password.
- Confirm file transfer works.
- Confirm the tray/app remains visible.
