# Pilot Windows Test

This test uses the official signed RustDesk Windows binary configured for the
Antreva Remote server and managed-access onboarding. It is not yet the final
branded Antreva executable.

## Server Values

- ID server: `104.184.67.190`
- Relay server: `104.184.67.190`
- Public key: `YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=`

These values are stored in `config/antreva-client-policy.json`.

## Prepare Each Managed Windows Client

Run this from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Setup-WindowsPilot.ps1 -LaunchAfterConfigure
```

The script will:

- validate the Antreva managed-access policy;
- download RustDesk `1.4.8` for Windows x86_64 if needed;
- verify the release SHA-256;
- verify the upstream Authenticode signature;
- relaunch itself as Administrator if needed;
- prompt the technician for the permanent support password;
- install the RustDesk service;
- apply the Antreva server and managed-access settings;
- launch RustDesk when configuration finishes.

## Managed Access Test Flow

Use two machines on different networks if possible.

1. On the client machine, run the managed setup script during authorized
   onboarding.
2. Approve the Windows administrator elevation prompt.
3. Enter and confirm the permanent support password.
4. Write down the client RustDesk ID shown in the app.
5. On the technician machine, run Antreva Remote/RustDesk configured for the
   Antreva server.
6. Enter the client ID from the technician machine and connect.
7. Authenticate using the permanent support password.
8. Verify remote control:
   - move the mouse;
   - type into Notepad;
   - switch windows;
   - disconnect cleanly.
9. Verify file transfer:
   - send a small file from technician to client;
   - send a small file from client to technician;
   - cancel one transfer mid-way;
   - test a larger file if bandwidth allows.
10. Confirm the tray/app remains visible on the client machine.

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
