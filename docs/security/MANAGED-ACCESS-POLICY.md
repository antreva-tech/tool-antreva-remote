# Managed Access Policy

Antreva Remote is a managed-access support tool for authorized client
computers. The technician performs onboarding on the client machine, installs
the Windows service, configures Antreva's RustDesk server, and sets the
permanent support password.

## Required Behavior

- Onboarding must be visible and run with Windows administrator approval.
- The technician sets the permanent support password during onboarding.
- The app or tray must remain visible after installation.
- The client service must use Antreva's ID server, relay server, and public key.
- File transfer is enabled for support sessions.
- Server settings remain locked to Antreva defaults.
- Stealth behavior is not supported: no hidden tray, no disguised process, no
  silent enrollment, and no bypass of Windows elevation.

## File Transfer

File transfer is bidirectional for support sessions. The managed policy sets:

- `enable-file-transfer = Y`
- `enable-file-copy-paste = Y`
- `one-way-file-transfer = N`
- `file-transfer-max-files = 200`

The release must test small files, large files, blocked paths, canceled
transfers, and network interruptions before client distribution.
