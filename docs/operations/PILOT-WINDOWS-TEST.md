# Pilot Windows Test

This test uses the official signed RustDesk Windows binary configured for the
Antreva Remote server and managed-access onboarding. It is not yet the final
branded Antreva executable.

This run supports Windows 7 SP1 through Windows 11 x86/x64. Windows 7 test
systems must have WMF 5.1 and SHA-2 updates KB4490628 and KB4474419 installed
before onboarding. See `docs/operations/WINDOWS-7-11-SUPPORT.md`.

## Server Values

- ID server: `104.184.67.190`
- Relay server: `104.184.67.190`
- Public key: `YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=`

These values are stored in `config/antreva-client-policy.json`.

## Prepare Each Managed Windows Client

For customer-style pilot testing, run:

```text
AntrevaDesk-Setup-1.0.0.exe
```

The installer GUI will:

- verify Windows 7-11 x86/x64 support requirements before install;
- collect the architecture selection;
- collect and confirm the permanent support password;
- request administrator elevation;
- install the RustDesk service;
- apply and verify the Antreva server and managed-access settings;
- launch RustDesk when configuration finishes.

For local developer testing only, run this from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Setup-WindowsPilot.ps1 -LaunchAfterConfigure
```

The script will:

- verify Windows 7-11 x86/x64 support requirements before install;
- validate the Antreva managed-access policy;
- download the selected RustDesk `1.4.8` Windows payload if needed;
- verify the release SHA-256;
- verify the upstream Authenticode signature;
- relaunch itself as Administrator if needed;
- prompt the technician for the permanent support password;
- install the RustDesk service;
- apply and verify the Antreva server and managed-access settings;
- launch RustDesk when configuration finishes.

## Managed Access Test Flow

Use two machines on different networks if possible.

1. On the client machine, run `AntrevaDesk-Setup-1.0.0.exe` during authorized
   onboarding.
2. Select the recommended architecture.
3. Enter and confirm the permanent support password in the installer.
4. Approve the Windows administrator elevation prompt if Windows asks for it.
5. Write down the client RustDesk ID shown in the app.
6. On the technician machine, run Antreva Remote/RustDesk configured for the
   Antreva server.
7. Enter the client ID from the technician machine and connect.
8. Authenticate using the permanent support password.
9. Verify remote control:
   - move the mouse;
   - type into Notepad;
   - switch windows;
   - disconnect cleanly.
10. Verify file transfer:
   - send a small file from technician to client;
   - send a small file from client to technician;
   - cancel one transfer mid-way;
   - test a larger file if bandwidth allows.
11. Confirm the tray/app remains visible on the client machine.

Repeat this flow on Windows 7 SP1 x64, Windows 8 x64, Windows 8.1 x64,
Windows 10 x64, Windows 7 SP1 x86, Windows 8 x86, Windows 8.1 x86, Windows 10
x86, and Windows 11 x64 before claiming Windows 7-11 support for a release.

## Expected Results

- The client installs as a Windows service.
- The client connects through the Antreva RustDesk server.
- Remote desktop control works with the permanent support password.
- File transfer works in both directions during support sessions.
- The tray/app remains visible.
- Antreva server settings remain configured after reboot.

## Known Pilot Limitations

- The app still displays RustDesk branding.
- The binary is signed by the upstream RustDesk publisher, not Antreva.
- The final Antreva-branded build still needs the Windows build toolchain,
  branding assets, and Antreva code-signing certificate.
