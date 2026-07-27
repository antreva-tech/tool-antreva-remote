# Pilot Windows Test

This test uses the Antreva Desk 1.0.4 test artifact. Ordinary CI artifacts use
the official RustDesk publisher signature and are not client-ready releases.
Only the protected manual release workflow may publish after Antreva signing
and live certification evidence pass.

This run supports Windows 7 SP1 through Windows 11 x86/x64. Windows 7 test
systems must have SHA-2 updates KB4490628 and KB4474419 installed before
onboarding. PowerShell is not required. See
`docs/operations/WINDOWS-7-11-SUPPORT.md`.

## Server Values

- ID server: `104.184.67.190`
- Relay server: `104.184.67.190`
- Public key: `YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=`

These values are stored in `config/antreva-client-policy.json`.

## Prepare Each Managed Windows Client

For customer-style pilot testing, extract the release ZIP and run:

```text
Antreva-Remote-Pilot-Setup.cmd
```

The Command Prompt installer will:

- verify Windows 7-11 x86/x64 support requirements before install;
- automatically select the matching x86 or x64 payload;
- keep the original user process waiting while an administrator process
  performs machine-wide setup;
- collect and confirm the permanent support password in Command Prompt;
- verify the selected payload against its exact pinned SHA-256;
- install and verify the exact RustDesk payload as an automatic running service;
- apply and exactly verify every Antreva option in CLI and the service profile;
- create Public Desktop and all-users Start Menu shortcuts; and
- launch RustDesk without elevation for the original signed-in user.

## Optional Bundle Integrity Check

Before onboarding a managed client, a technician can run this non-installing
check from Command Prompt:

```text
Antreva-Remote-Pilot-Setup.cmd --verify-bundle
```

This mode verifies architecture-based payload selection, the exact pinned
SHA-256, and the required WSH helpers. It does not request administrator
access, install RustDesk, change client configuration, or launch the app. It
also does not run the supported-client OS preflight, so passing this check is
not a substitute for the Windows certification matrix below.

## Managed Access Test Flow

Use two machines on different networks if possible.

1. On the client machine, extract `Antreva-Desk-1.0.4-Windows.zip` and run
   `Antreva-Remote-Pilot-Setup.cmd` during authorized onboarding.
2. Confirm setup selects the architecture that matches Windows.
3. Confirm the setup log records successful verification of the exact pinned
   payload SHA-256. A changed payload must stop installation.
4. Enter and confirm the permanent support password in Command Prompt.
5. Approve the Windows administrator elevation prompt if Windows asks for it.
6. Write down the client RustDesk ID shown in the app.
7. On the technician machine, run Antreva Remote/RustDesk configured for the
   Antreva server.
8. Enter the client ID from the technician machine and connect.
9. Authenticate using the permanent support password.
10. Verify remote control:
   - move the mouse;
   - type into Notepad;
   - switch windows;
   - disconnect cleanly.
11. Verify file transfer:
   - send a small file from technician to client;
   - send a small file from client to technician;
   - cancel one transfer mid-way;
   - test a larger file if bandwidth allows.
12. Confirm the tray/app remains visible on the client machine.
13. Reboot, then verify the RustDesk service is automatic/running, shortcuts
    are still visible, authentication works, and server/relay/key values remain
    exact.

The public 1.0.4 hard gate requires clean-install and upgrade runs on Windows 7
SP1 x86/x64 and Windows 10 22H2 x86/x64. It also requires one Windows 10
standard-user run using separate administrator credentials. Continue broader
matrix checks on Windows 8, 8.1, and certified Windows 11 builds. Every VM must
pass rebooted service state, original-user tray/shortcuts, exact
server/relay/key persistence, password authentication, remote control, and
bidirectional file transfer.

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
- Windows briefly exposes the password in the RustDesk CLI process command
  line while the daemon receives it; logs and result files do not contain it.
- Windows 7 x86 launch of the pinned 1.4.8 Sciter payload is a hard release
  gate. Failure blocks 1.0.4 and requires a separate payload-selection task.
- The final Antreva-branded build still needs the Windows build toolchain,
  branding assets, and Antreva code-signing certificate.
