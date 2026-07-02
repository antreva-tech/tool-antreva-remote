# Antreva Remote Pilot

This is a temporary pilot bundle for testing Antreva Remote while the
Antreva-specific code signing and branded build are being prepared.

The included executable is the official RustDesk `1.4.8` Windows x86_64 binary,
signed by the upstream RustDesk publisher. The EXE filename carries the
Antreva RustDesk server settings using RustDesk's supported custom-client
filename format. The setup script verifies the EXE hash and signature, then
launches the app.

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

Double-click:

```text
Antreva-Remote-Pilot-Setup.cmd
```

The RustDesk window should show the custom server warning/settings instead of
using the public RustDesk server.

Alternative PowerShell command:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Configure-And-Launch-Antreva-Remote-Pilot.ps1
```

This pilot does not install a Windows service. Run it again whenever you need a
support session.

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
