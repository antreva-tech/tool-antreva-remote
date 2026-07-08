# Antreva Desk 0.1.0 Managed Access

This is a temporary pilot installer for testing Antreva Desk Managed Access
while the Antreva-specific code signing and fully branded client build are
being prepared.

`AntrevaDesk-Setup-0.1.0.exe` is a branded GUI installer that bundles the
official RustDesk `1.4.8` Windows payloads:

- `rustdesk-1.4.8-x86_64.exe`
- `rustdesk-1.4.8-x86-sciter.exe`

The installer verifies the selected EXE hash and signature, requests Windows
administrator elevation, installs the RustDesk service, applies Antreva server
settings, and prompts the technician to set the permanent support password.

This pilot installer supports Windows 7 SP1 through Windows 11 x86/x64. Windows
7 requires WMF 5.1 plus SHA-2 updates KB4490628 and KB4474419 before setup.

## Server Settings

- ID server: `104.184.67.190`
- Relay server: `104.184.67.190`
- Public key: `YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=`

## How to Run

During authorized onboarding, double-click:

```text
AntrevaDesk-Setup-0.1.0.exe
```

The setup will:

- verify the supported Windows 7-11 x86/x64 client matrix;
- choose 64-bit by default on 64-bit Windows;
- disable 64-bit installation on 32-bit Windows;
- request administrator elevation;
- install the RustDesk service;
- import and verify the Antreva ID server, relay server, and public key;
- prompt the technician to enter and confirm the permanent support password;
- apply Antreva server and managed-access settings;
- create visible `Antreva Desk` shortcuts;
- launch the installed app.

The setup creates:

- Desktop shortcut: `Antreva Desk`
- Start Menu folder: `Antreva > Antreva Desk`
- Local launcher folder: `%LOCALAPPDATA%\AntrevaDesk`

## Test Flow

1. Run this installer on the client computer during authorized onboarding.
2. Select the recommended architecture unless a 32-bit Windows computer
   requires the 32-bit payload.
3. Approve the Windows administrator elevation prompt.
4. Enter and confirm the permanent support password.
5. Leave Antreva Desk/RustDesk running after setup finishes.
6. Record the client RustDesk ID shown in the app.
7. From the technician computer, connect to that ID using the permanent support
   password.
8. Test remote control and file transfer in both directions.
9. Confirm the tray/app remains visible on the client computer.

## Limitations

- The installer, launcher, and shortcuts are named AntrevaDesk or Antreva Desk,
  but the app UI is still RustDesk-branded.
- The RustDesk payloads are signed by the upstream RustDesk publisher, not
  Antreva.
- The final Antreva Desk client build will be separately branded and signed
  after Antreva code signing is ready.
