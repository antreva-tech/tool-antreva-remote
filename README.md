# Antreva Desk

Antreva Desk is a managed-access Windows remote support product layer built on
RustDesk OSS. The goal is a branded technician app, an authorized onboarding
installer, smooth remote desktop control, and bidirectional file transfer for
managed client systems.

This repository intentionally does not implement stealth access, hidden tray
behavior, disguised processes, or silent enrollment.

## Repository Layout

- `upstream/rustdesk`: pinned RustDesk client source.
- `upstream/rustdesk-server`: pinned RustDesk OSS server source.
- `infra/office-server`: Docker Compose deployment for the office-hosted
  `hbbs` ID/rendezvous server and `hbbr` relay server.
- `config/antreva-client-policy.json`: Antreva defaults using RustDesk option
  keys for managed support and bidirectional file transfer.
- `docs`: operations, security, and AGPL compliance material.
- `scripts`: validation and Windows release helpers.

## First-Time Setup

```powershell
git submodule update --init --recursive
Copy-Item infra/office-server/.env.example infra/office-server/.env
.\scripts\Test-Repository.ps1
```

Edit `infra/office-server/.env` and `config/antreva-client-policy.json` with
the office DNS name and RustDesk server public key after the server has started.

## Office Server Ports

Forward these ports from the office router/firewall to the office server:

- TCP `21114:21119`
- UDP `21116`

RustDesk OSS uses `hbbs` for ID/rendezvous and `hbbr` for relay. The Docker
deployment persists server keys under `infra/office-server/data`.

## Security Model

V1 is managed access:

- A technician must perform visible onboarding with Windows administrator
  approval.
- The technician sets the permanent support password during onboarding.
- The app or tray must remain visible after installation.
- File transfer is enabled for support sessions.
- No stealth startup, hidden tray behavior, disguised process, or silent
  enrollment is part of the v1 release.

## Build Notes

Use `scripts/Build-WindowsRelease.ps1` as the release orchestrator after the
RustDesk Windows build prerequisites are installed. The script enforces the
expected product metadata and code-signing inputs before producing release
artifacts.

For internal test machines, `scripts/Apply-AntrevaClientPolicy.ps1` can apply
the Antreva RustDesk options to a built `rustdesk.exe` before packaging.

For the fastest two-machine pilot using the official signed RustDesk binary,
build the ZIP with `scripts/Build-PilotBundle.ps1`, then run the bundled
`Antreva-Remote-Pilot-Setup.cmd` on the managed client and follow
`docs/operations/PILOT-WINDOWS-TEST.md`. The managed client does not require
PowerShell.

## Installer Downloads

GitHub Actions builds the Antreva Desk 1.0.4 Command Prompt installer bundle
on pull requests to `main` and on pushes to `main`.

- Pull requests and pushes upload 30-day workflow artifacts for controlled
  review and testing only.
- Ordinary `main` pushes never create, replace, or move a public release tag.
- Public publication is available only through the protected manual release
  workflow after Antreva signer verification and hashed Windows certification
  evidence pass.

Before upload, CI runs the bundled installer with `--verify-bundle`. This is a
non-installing integrity check that validates architecture selection, the exact
pinned payload SHA-256, and the WSH helpers. It intentionally skips the
client operating-system preflight so it can run on GitHub's Windows Server
runner. Running the installer normally still performs the full Windows client
preflight and rejects Windows Server editions.

The test bundle is `Antreva-Desk-1.0.4-Windows.zip`. A public release may use
the immutable tag `antreva-desk-1.0.4` only after the manual gates pass.
Extract the ZIP and double-click `Antreva-Remote-Pilot-Setup.cmd` during
authorized onboarding. Alternate administrator credentials are supported:
machine-wide setup runs elevated, while the original user waits for the result
and launches the app without elevation.

## License

RustDesk and RustDesk Server are AGPL-3.0 projects. Antreva Desk keeps the
same license obligations for modified covered work. See
`docs/compliance/AGPL-SOURCE-OFFER.md` and `docs/compliance/RELEASE-CHECKLIST.md`.
