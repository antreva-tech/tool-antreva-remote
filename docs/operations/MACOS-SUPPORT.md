# Antreva Desk for Mac (preview)

Native installers are available for **Intel (x86_64)** and **Apple Silicon
(M1 and later, arm64)**. Antreva's initial target is **macOS 12 Monterey or newer**.
The Apple Silicon build does not require Rosetta. Older macOS versions are not
part of this installer support target.

## Download and install

Download from the [GitHub releases page](https://github.com/antreva-tech/tool-antreva-remote/releases)
or the matching **Build Mac Installers** workflow artifact under
[GitHub Actions](https://github.com/antreva-tech/tool-antreva-remote/actions/workflows/build-macos-installers.yml).
Actions artifacts require a GitHub login and expire after 30 days.

| About This Mac shows | Download |
| --- | --- |
| Processor: Intel | `Antreva-Desk-1.0.6-macOS-Intel.pkg` |
| Chip: Apple M1 or later | `Antreva-Desk-1.0.6-macOS-Apple-Silicon.pkg` |

1. Quit RustDesk. If already installed with a service, remove that service
   through RustDesk settings before replacing the app, then quit the app.
   The installer refuses active processes and existing service registrations.
   Never upgrade over the session being used to control this Mac.
2. Double-click the `.pkg` and approve installation with a Mac administrator.
   It installs `RustDesk.app` and an `Antreva Desk` folder in `/Applications`.
3. Open **Applications > Antreva Desk > Configure Antreva Desk.command**.
   Terminal opens a visible consent prompt and guides the signed-in user through
   enabling RustDesk's service, granting permissions, and setting a permanent
   support password in RustDesk. An administrator can authorize the setup when
   requested; the app itself opens in the original desktop session.
4. Setup applies and reads back every option in `config/antreva-client-policy.json`,
   including Antreva's ID server, relay, key, and file-transfer settings.
   A mismatch is a setup failure. Rerunning setup is supported.
5. A technician must verify a real remote session, permanent-password login,
   keyboard/mouse control, and file transfer in both directions.

The RustDesk app retains its upstream name, bundle identity and signature.
Antreva branding applies to the installer and onboarding, as with the Windows
pilot. A Mac can be the technician's computer or the managed client's computer.
Server and relay infrastructure are shared with the Windows clients.

## Preview signing and permissions

The `.pkg` wrapper is currently **unsigned and not Apple-notarized**. It is a
preview for controlled testing, not a certified client release. Gatekeeper may
block it. If you trust this download, use macOS's per-item **Open Anyway** flow
in Privacy & Security. Do not disable Gatekeeper or remove quarantine globally.
Production distribution requires an Antreva Developer ID Installer certificate,
package signing, notarization and stapling; no Apple signing credentials are
configured in this repository. The builder verifies the upstream app signature
before and after packaging, and pins each DMG by SHA-256.

macOS requires user approval for **Screen Recording** and **Accessibility**.
Grant **Input Monitoring** if RustDesk requests it. Setup cannot grant these
permissions. It does not claim they or the password are ready from policy checks
alone. See [RustDesk's Mac guide](https://rustdesk.com/docs/en/client/mac/).
FileVault's pre-boot unlock and first-time permission prompts require local
interaction; test reboot/login behavior before relying on unattended support.

## Build and release

On macOS with Python 3.11+ and Apple command line tools:

```sh
python3 -m unittest discover -s tests -p 'test_macos*.py' -v
python3 scripts/build-macos-installers.py --arch x86_64
python3 scripts/build-macos-installers.py --arch arm64
```

Output is under `artifacts/macos`: a `.pkg`, SHA-256 file, and provenance JSON
for each processor. GitHub Actions builds and inspects the packages on native
Intel and Apple Silicon runners. CI checks signatures, payload versions and
native architectures, and extracts each resulting package to verify its app.
It also installs the package on each native runner, launches the installed
binary's version command, and checks the administrator helper's ownership.
CI does not install a service or exercise macOS privacy dialogs.

Unsigned previews are distributed through workflow artifacts only, preserving
the repository's code-signing release gate. The protected **Release Mac Installers**
workflow signs and notarizes both packages before creating a GitHub release.
It uses the separate immutable tag `antreva-desk-macos-1.0.6`, leaving Windows
release tags unchanged. It attaches these instructions and the provenance files.

Configure the `macos-release` GitHub environment with these secrets:

- `MACOS_INSTALLER_CERTIFICATE_BASE64`: a Developer ID Installer P12 certificate.
- `MACOS_INSTALLER_CERTIFICATE_PASSWORD`: its P12 password.
- `MACOS_INSTALLER_IDENTITY`: the full Developer ID Installer signing identity.
- `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_SPECIFIC_PASSWORD`: notarization credentials.

The workflow requires an HTTPS certification evidence archive and its SHA-256,
covering the live checks below. It refuses publication without valid Apple
signatures, accepted notarization, stapled tickets and matching evidence hash.

Before declaring production support, verify clean installation, wrong-processor
rejection (including Rosetta), cancel/retry, standard-user setup with separate
administrator credentials, reboot, reconnection, permanent-password behavior,
remote control, clipboard, and bidirectional file transfer on both architectures.
The minimum supported macOS version also needs a live test.

The app is unmodified RustDesk 1.5.0, licensed AGPL-3.0. Corresponding source:
[RustDesk exact source revision](https://github.com/rustdesk/rustdesk/tree/fada664df7a294d1d1a9ca3e7cd3637069122f17).
Installer source and build instructions:
[Antreva repository](https://github.com/antreva-tech/tool-antreva-remote).
The package installs `SOURCE-OFFER.txt` beside the onboarding command.
