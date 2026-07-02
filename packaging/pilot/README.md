# Antreva Remote Pilot

This is a temporary pilot bundle for testing Antreva Remote while the
Antreva-specific code signing and branded build are being prepared.

The included executable is the official RustDesk `1.4.8` Windows x86_64 binary,
signed by the upstream RustDesk publisher. The setup script verifies the EXE
hash and signature, configures it for the Antreva RustDesk server, then launches
the app.

## Contents

- `rustdesk-1.4.8-x86_64.exe`
- `Antreva-Remote-Pilot-Setup.cmd`
- `Configure-And-Launch-Antreva-Remote-Pilot.ps1`
- `README.md`

## Server Settings

- ID server: `104.184.67.190`
- Relay server: `104.184.67.190`
- Public key: `YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=`

## How to Run

Double-click:

```text
Antreva-Remote-Pilot-Setup.cmd
```

Approve the Windows Administrator prompt if it appears.

Alternative PowerShell command:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Configure-And-Launch-Antreva-Remote-Pilot.ps1
```

If you run the script without Administrator permission, it will ask Windows to
relaunch itself elevated.

## Test Flow

1. Run this bundle on the client computer and leave RustDesk open.
2. Give the technician the RustDesk ID shown on the client computer.
3. Run this bundle on the technician computer.
4. The technician enters the client ID and starts the connection.
5. The client approves the session.
6. Test remote control and file transfer in both directions.
7. End the session from the client side when finished.

## Limitations

- This pilot is RustDesk-branded.
- It is signed by the upstream RustDesk publisher, not Antreva.
- The final Antreva Remote build will be separately branded and signed after
  Antreva code signing is ready.
