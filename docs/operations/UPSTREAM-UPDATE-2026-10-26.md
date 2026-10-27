# RustDesk upstream update assessment — 2026-10-26

## Result

Prepared a **local, uncertified Antreva Desk 1.0.6 candidate** based on stable
RustDesk 1.5.0. No public release, installed client, running service, or office
server was changed. Do not distribute this candidate until the checks below pass.

## Baseline and selected target

| Component | Before | Candidate |
| --- | --- | --- |
| Antreva installer package | 1.0.5 | 1.0.6 |
| Bundled Windows x64 / x86 Sciter executables | 1.4.8 | 1.5.0 |
| Client source submodule | b3bd18845d7d9b7af565eabef30104bcb17810ac | fada664df7a294d1d1a9ca3e7cd3637069122f17 (1.5.0) |
| Client hbb_common submodule | a920d00945e1d2441b3f77b2677054cb8c3d9dd2 | 229b904508364c8997aad0fb5af57effac859f60 |
| Server source / deployment | Existing pin and configuration | Unchanged |

GitHub's latest stable release API identified 1.5.0, published September 30,
2026. There are 283 commits from the shipped 1.4.8 tag to 1.5.0, and 282 from
the previously pinned client source to 1.5.0. The source checkout had no local
modifications before updating it. The active installer ships official upstream
binaries; changing its source pin alone would not update installed functionality.

Sources: [stable release and changelog](https://github.com/rustdesk/rustdesk/releases/tag/1.5.0),
[release API](https://api.github.com/repos/rustdesk/rustdesk/releases/latest),
[upstream comparison](https://github.com/rustdesk/rustdesk/compare/1.4.8...1.5.0).

## Relevant additions and fixes

The official 1.5.0 binaries include upstream's complete stable changes, including:

- Clipboard format/range/dimension validation and file-copy permission checks.
- Faster large-directory loading and transfer-speed display in file transfer.
- Windows tray-icon duplication, display capture recovery after access loss,
  keyboard focus, window sizing/DPI, cursor sizing, and audio recovery fixes.
- Windows installer temporary-script hardening and empty deployment-ID protection.
- Reconnect/session permission fixes and transport/encryption hardening.
- HDR tone mapping, ID whitelisting, optional clipboard synchronization between
  sessions, recording options, and WebRTC support. Availability depends on the
  platform, peer and server; the legacy x86 Sciter UI does not have every Flutter
  feature.

No new restrictive ID whitelist or cross-session clipboard option was enabled.
The existing managed-access policy remains byte-for-byte unchanged, including
server settings, password access, visible tray, bidirectional file transfer, and
settings that disable terminal, tunnel, recording, privacy mode and auto-update.

## Compatibility findings

- The client source is pinned to a stable tag rather than master/nightly.
- Both release architectures are still offered: x64 Flutter and x86 Sciter.
  Upstream's 1.5.0 build workflow retains Flutter 3.24.5 for x64 with an explicit
  Windows 7 compatibility comment. This is evidence of build intent, not proof
  that either downloaded executable runs on every supported Windows version.
- Source inspection confirms the installer still has the commands it uses:
  --silent-install (including printer=0), --config, --option, --password and
  --get-id. The current permanent-password storage retains the 01 prefix and
  separate salt expected by the existing verification helper.
- Antreva's detached installation handling, alternate-administrator flow,
  daemon password acknowledgement, exact service/config checks, Windows build
  allowlist and signing/publication gates were preserved.
- The protected release workflow and regression fixtures now reference 1.0.6
  and the new payload names/hashes. Existing release tags were not changed.
- Retired NSIS/PowerShell pilot paths and historical design documents retain
  their old 1.4.8 references. They are not included by the active CMD builder.
  Use Build-PilotBundle.ps1 for this candidate.

## Payload verification

| Payload | SHA-256 |
| --- | --- |
| rustdesk-1.5.0-x86_64.exe | 8555777215510d83d2d61c9dc984e4fcc838bd7e79f9d18a42585431f5e8bb47 |
| rustdesk-1.5.0-x86-sciter.exe | 9f5e99ed33c08d3f61dd4e3d0dc06b927836bb518acd7047ffb0a68b9b138bf0 |

Both downloaded files match GitHub's asset digests. Windows WinVerifyTrust
returned 0x0 (trusted) for each. Native certutil signature inspection confirmed
the existing pinned publisher certificate for both; no signer pin was relaxed.

The exact CMD template was independently rendered into the ignored local
artifacts/upstream-1.5.0 folder, with all policy options applied and verified.
Its --verify-bundle check passed for x64 and simulated x86. This checks payload
selection, hashes and required helper availability; it does not install or test
remote sessions, and is not a substitute for the PowerShell build/regression run.

## Outstanding validation — release remains blocked

The repository test runner could not complete in this session: PowerShell
stalled before output even for a trivial NoProfile command, using both Windows
PowerShell and bundled PowerShell 7. A full WSH fixture attempt also stalled.
No regression-suite success is claimed. The ordinary CMD bundle integrity checks
and native hash/signature checks above did complete. git diff --check passed.

Before distribution:

1. Run scripts/Test-Repository.ps1 in a working Windows PowerShell environment.
2. Run scripts/Build-PilotBundle.ps1 and both CI --verify-bundle architecture
   checks through the normal build path.
3. Follow PILOT-WINDOWS-TEST.md and WINDOWS-7-11-SUPPORT.md on isolated machines:
   clean install and upgrade from 1.0.5; Windows 7 SP1 x86/x64 launch; Windows 10
   x86/x64; separate administrator credentials; service reboot; visible tray;
   exact server/relay/key persistence; password authentication; monitor switching;
   and small/large bidirectional file transfers with interruption/retry.
4. Test mixed 1.4.8/1.5.0 peers against the current office hbbs/hbbr, including
   direct and forced-relay connections. Check clipboard, screen capture after
   display changes, and authentication after reconnect.
5. Back up existing configuration before upgrade; test rollback to the retained
   1.0.5 package with that backup. Configuration migration can make rollback
   different from simply reinstalling an older executable.
6. Complete existing Antreva signing and certification evidence gates before
   the protected manual public-release workflow is used.

## Updates intentionally deferred

At inspection time master was 82 commits beyond 1.5.0, at
59f2953c94b8373f124dc38d4fd0635098f7c5cd. It contains further installer protections,
update verification, file-transfer navigation, proxy and other fixes. These are
not part of the stable payloads selected here. Importing them would require a
custom native build and separate certification; no nightly binary was substituted.

The office server image defaults to a mutable latest tag in Docker Compose, so
its actual running version cannot be inferred from the source submodule. Live
server inventory and a separately tested server upgrade remain outside this
client update. No server container or network setting was touched.
