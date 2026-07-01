# Attended Access Policy

Antreva Remote v1 is for client-approved support sessions only.

## Required Behavior

- The client application must be visible while it is running.
- The client must approve a session before screen control or file transfer.
- The technician can transfer files only during an approved active session.
- The client can end the session from the visible app.
- Permanent password, hidden tray, unattended enrollment, silent startup, and
  stealth persistence are outside v1 scope.

## File Transfer

File transfer is bidirectional after the client approves the session. The v1
policy sets:

- `enable-file-transfer = Y`
- `enable-file-copy-paste = Y`
- `one-way-file-transfer = N`
- `file-transfer-max-files = 200`

The release must test small files, large files, blocked paths, canceled
transfers, and network interruptions before client distribution.
