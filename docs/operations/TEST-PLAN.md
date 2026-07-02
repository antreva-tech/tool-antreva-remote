# Antreva Remote Managed Access Test Plan

## Server

- Start `infra/office-server/docker-compose.yml`.
- Confirm `hbbs` and `hbbr` containers are healthy after reboot.
- Confirm `data/id_ed25519.pub` exists and matches the client policy key.
- Confirm office router forwards TCP `21114:21119` and UDP `21116`.

## Managed Client Onboarding

- Run the Antreva Remote managed setup on a Windows client.
- Confirm Windows administrator elevation is required.
- Set the permanent support password during onboarding.
- Confirm the app or tray is visible after installation.
- Confirm the app shows client ID/session information.
- Reboot the client and confirm the service starts.

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
- Confirm managed access requires visible onboarding.
- Confirm no stealth startup, hidden tray behavior, disguised process, or silent
  enrollment is available in v1 defaults.
