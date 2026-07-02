# Antreva Remote

Antreva Remote is an attended-only Windows remote support product layer built on
RustDesk OSS. The goal is a branded technician app, a portable QuickSupport
client, smooth remote desktop control, and bidirectional file transfer after the
client approves the support session.

This repository intentionally does not implement stealth access, hidden
persistence, or unattended access for v1.

## Repository Layout

- `upstream/rustdesk`: pinned RustDesk client source.
- `upstream/rustdesk-server`: pinned RustDesk OSS server source.
- `infra/office-server`: Docker Compose deployment for the office-hosted
  `hbbs` ID/rendezvous server and `hbbr` relay server.
- `config/antreva-client-policy.json`: Antreva defaults using RustDesk option
  keys for attended support and session-approved file transfer.
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

V1 is consent based:

- The client must launch the visible QuickSupport app.
- The client must approve each remote support session.
- File transfer is enabled only inside an approved active session.
- No unattended access, stealth startup, hidden tray behavior, or permanent
  password flow is part of the v1 release.

## Build Notes

Use `scripts/Build-WindowsRelease.ps1` as the release orchestrator after the
RustDesk Windows build prerequisites are installed. The script enforces the
expected product metadata and code-signing inputs before producing release
artifacts.

For internal test machines, `scripts/Apply-AntrevaClientPolicy.ps1` can apply
the Antreva RustDesk options to a built `rustdesk.exe` before packaging.

For the fastest two-machine pilot using the official signed RustDesk binary,
run `scripts/Setup-WindowsPilot.ps1` and follow
`docs/operations/PILOT-WINDOWS-TEST.md`.

## License

RustDesk and RustDesk Server are AGPL-3.0 projects. Antreva Remote keeps the
same license obligations for modified covered work. See
`docs/compliance/AGPL-SOURCE-OFFER.md` and `docs/compliance/RELEASE-CHECKLIST.md`.
