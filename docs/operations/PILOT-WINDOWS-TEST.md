# Pilot Windows Test

This test uses the official signed RustDesk Windows binary configured for the
Antreva Remote server. It is not yet the final branded Antreva executable.

## Server Values

- ID server: `104.184.67.190`
- Relay server: `104.184.67.190`
- Public key: `YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=`

These values are stored in `config/antreva-client-policy.json`.

## Prepare Each Windows Test Machine

Run this from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Setup-WindowsPilot.ps1 -LaunchAfterConfigure
```

The script will:

- validate the Antreva client policy;
- download RustDesk `1.4.8` for Windows x86_64 if needed;
- verify the release SHA-256;
- verify the upstream Authenticode signature;
- relaunch itself as Administrator if needed;
- apply the Antreva server settings;
- launch RustDesk when configuration finishes.

## Two-Machine Test Flow

Use two machines on different networks if possible.

1. On the client machine, run the pilot setup script and leave RustDesk open.
2. Write down the client RustDesk ID and one-time/password value shown in the app.
3. On the technician machine, run the same pilot setup script.
4. Enter the client ID from the technician machine and connect.
5. On the client machine, approve the session when prompted.
6. Verify remote control:
   - move the mouse;
   - type into Notepad;
   - switch windows;
   - disconnect cleanly.
7. Verify file transfer:
   - send a small file from technician to client;
   - send a small file from client to technician;
   - cancel one transfer mid-way;
   - test a larger file if bandwidth allows.
8. End the session from the client side and confirm the technician disconnects.

## Expected Results

- Both apps connect through the Antreva RustDesk server.
- Session approval is visible on the client machine.
- Remote desktop control works after approval.
- File transfer works in both directions during the approved session.
- The client can end the session.

## Known Pilot Limitations

- The app still displays RustDesk branding.
- The binary is signed by the upstream RustDesk publisher, not Antreva.
- A final Antreva-branded build still needs the Windows build toolchain,
  branding assets, and Antreva code-signing certificate.
