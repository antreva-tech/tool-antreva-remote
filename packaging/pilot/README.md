# Antreva Desk 1.0.3 Managed Access

This is a temporary PowerShell installer bundle for testing Antreva Desk
Managed Access while the Antreva-specific code signing and fully branded
client build are being prepared.

`Antreva-Desk-1.0.3-Windows.zip` bundles the official RustDesk `1.4.8`
Windows payloads:

- `payloads\x64\rustdesk-1.4.8-x86_64.exe`
- `payloads\x86\rustdesk-1.4.8-x86-sciter.exe`

The CMD launcher starts the PowerShell setup, which automatically selects the
correct payload, verifies its exact hash and pinned RustDesk publisher,
requests Windows administrator elevation, visibly prompts for the permanent
support password, installs the RustDesk service, and applies and verifies the
Antreva server settings. On restricted or offline clients, setup can continue
when Windows reports only a missing or untrusted certificate chain; every
other signature failure remains blocked.

The current-attempt setup log is written to
`%ProgramData%\AntrevaDesk\Logs\AntrevaDesk-Setup.log`.

This pilot installer supports Windows 7 SP1 through Windows 11 x86/x64. Windows
7 requires WMF 5.1 plus SHA-2 updates KB4490628 and KB4474419 before setup.

## Contents

- `Antreva-Remote-Pilot-Setup.cmd`
- `Configure-And-Launch-Antreva-Remote-Pilot.ps1`
- `AntrevaDesk-PayloadValidation.ps1`
- `payloads\x64\rustdesk-1.4.8-x86_64.exe`
- `payloads\x86\rustdesk-1.4.8-x86-sciter.exe`
- `README.md`

## Server Settings

- ID server: `104.184.67.190`
- Relay server: `104.184.67.190`
- Public key: `YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=`

## How to Run

Extract the ZIP during authorized onboarding, then double-click:

```text
Antreva-Remote-Pilot-Setup.cmd
```

The setup will:

- verify the supported Windows 7-11 x86/x64 client matrix;
- automatically choose 64-bit on 64-bit Windows and 32-bit on 32-bit Windows;
- request administrator elevation;
- collect and confirm the permanent support password in the visible PowerShell
  window;
- install the RustDesk service;
- import and verify the Antreva ID server, relay server, and public key;
- apply Antreva server and managed-access settings;
- create visible `Antreva Desk` shortcuts;
- launch the installed app.

The setup creates:

- Desktop shortcut: `Antreva Desk`
- Start Menu folder: `Antreva > Antreva Desk`
- Local launcher folder: `%LOCALAPPDATA%\AntrevaDesk`

## Test Flow

1. Run this installer on the client computer during authorized onboarding.
2. Approve the Windows administrator elevation prompt if Windows asks for it.
3. Enter and confirm the permanent support password in PowerShell.
4. Confirm setup reports that the Antreva server settings and permanent
   password were verified.
5. Leave Antreva Desk/RustDesk running after setup finishes.
6. Record the client RustDesk ID shown in the app.
7. From the technician computer, connect to that ID using the permanent support
   password.
8. Test remote control and file transfer in both directions.
9. Confirm the tray/app remains visible on the client computer.

## Limitations

- The launcher and shortcuts are named Antreva Desk, but the app UI is still
  RustDesk-branded.
- The RustDesk payloads are signed by the upstream RustDesk publisher, not
  Antreva.
- The final Antreva Desk client build will be separately branded and signed
  after Antreva code signing is ready.
