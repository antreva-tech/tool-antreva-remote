# Antreva Remote MVP Test Plan

## Server

- Start `infra/office-server/docker-compose.yml`.
- Confirm `hbbs` and `hbbr` containers are healthy after reboot.
- Confirm `data/id_ed25519.pub` exists and matches the client policy key.
- Confirm office router forwards TCP `21114:21119` and UDP `21116`.

## Client Session

- Launch `Antreva Remote QuickSupport.exe` on a Windows client.
- Confirm the app is visible and shows client ID/session information.
- Start a technician connection from `Antreva Remote`.
- Confirm the client approval prompt appears before control begins.
- Confirm the client can end the session.

## Remote Desktop

- Move mouse, type text, use keyboard shortcuts, and switch monitors if present.
- Confirm screen updates are smooth enough for support work.
- Confirm disconnect/reconnect behavior after network interruption.

## File Transfer

- Transfer a small text file from technician to client.
- Transfer a small text file from client to technician.
- Transfer a large file in both directions.
- Cancel an in-progress transfer.
- Attempt a transfer to a blocked or permission-denied path.
- Interrupt the network during transfer and confirm the UI reports failure or
  allows retry/resume according to RustDesk behavior.

## Release Gates

- Confirm binaries are signed.
- Confirm AGPL/source offer is visible.
- Confirm no unattended access path is available in v1 defaults.
