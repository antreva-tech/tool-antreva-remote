# Antreva Remote Managed Access Pilot

This is a temporary pilot bundle for testing Antreva Remote Managed Access while
the Antreva-specific code signing and branded build are being prepared.

The included executable is the official RustDesk `1.4.8` Windows x86_64 binary,
signed by the upstream RustDesk publisher. The setup script verifies the EXE
hash and signature, requests Windows administrator elevation, installs the
RustDesk service, applies Antreva server settings, and prompts the technician to
set the permanent support password.

## Contents

- `rustdesk-host=104.184.67.190,key=YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=,relay=104.184.67.190.exe`
- `Antreva-Remote-Pilot-Setup.cmd`
- `Configure-And-Launch-Antreva-Remote-Pilot.ps1`
- `README.md`

## Server Settings

- ID server: `104.184.67.190`
- Relay server: `104.184.67.190`
- Public key: `YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=`

## How to Run

During authorized onboarding, double-click:

```text
Antreva-Remote-Pilot-Setup.cmd
```

The setup will:

- request administrator elevation;
- install the RustDesk service;
- prompt the technician to enter and confirm the permanent support password;
- apply Antreva server and managed-access settings;
- create visible `Antreva Remote` shortcuts;
- launch the installed app.

The setup creates:

- Desktop shortcut: `Antreva Remote`
- Start Menu folder: `Antreva > Antreva Remote`
- Local launcher folder: `%LOCALAPPDATA%\AntrevaRemotePilot`

Alternative PowerShell command:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Configure-And-Launch-Antreva-Remote-Pilot.ps1
```

## Test Flow

1. Run this bundle on the client computer during authorized onboarding.
2. Approve the Windows administrator elevation prompt.
3. Enter and confirm the permanent support password.
4. Leave Antreva Remote/RustDesk running after setup finishes.
5. Record the client RustDesk ID shown in the app.
6. From the technician computer, connect to that ID using the permanent support
   password.
7. Test remote control and file transfer in both directions.
8. Confirm the tray/app remains visible on the client computer.

## Limitations

- The launcher and shortcuts are named Antreva Remote, but the app UI is still
  RustDesk-branded.
- It is signed by the upstream RustDesk publisher, not Antreva.
- The setup uses a visible Antreva onboarding script, but the underlying
  RustDesk installer command is the upstream installer path.
- The final Antreva Remote build will be separately branded and signed after
  Antreva code signing is ready.
