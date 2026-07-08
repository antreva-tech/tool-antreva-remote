# AntrevaDesk GUI Installer Design

## Goal

AntrevaDesk needs a normal Windows GUI installer EXE for customer onboarding. The installer must support customers on both 32-bit and 64-bit Windows, let the technician choose the target architecture when appropriate, and keep the current visible managed-access setup flow: administrator approval, service install, Antreva server configuration, permanent support password setup, visible shortcuts, and app launch.

The distributed installer should be branded as `AntrevaDesk`. The installer will use the provided Antreva logo source:

`D:\vault\Antreva\code\main-site\public\Antreva Tech Transparente white.png`

## Current State

The current pilot release is a zip bundle named `Antreva-Desk-0.1.0-Windows.zip`. It contains:

- one upstream signed RustDesk `1.4.8` x86_64 executable;
- `Antreva-Remote-Pilot-Setup.cmd`;
- `Configure-And-Launch-Antreva-Remote-Pilot.ps1`;
- bundled README documentation.

The setup script already performs the important managed-access work, but it explicitly rejects 32-bit Windows and presents as a script-based bundle rather than a customer-friendly installer.

RustDesk `1.4.8` provides both Windows payloads needed for this release:

- `rustdesk-1.4.8-x86_64.exe`
- `rustdesk-1.4.8-x86-sciter.exe`

The x86 Sciter build is treated as the legacy 32-bit-compatible payload.

## Recommended Approach

Use an NSIS bootstrapper to produce a single GUI installer:

`AntrevaDesk-Setup-0.1.0.exe`

The NSIS installer will bundle both RustDesk payloads and the existing PowerShell setup backend. This keeps the customer-facing entry point simple while preserving the setup behavior that is already tested in this repository.

WiX/MSI is not recommended for this step because a single MSI is not a good fit for switching between x86 and x64 application payloads. A Burn bootstrapper plus separate MSIs would be more complex than this pilot needs.

## User Experience

The installer will show a branded wizard:

1. Welcome page branded as `AntrevaDesk`.
2. Architecture selection page:
   - On 32-bit Windows, only `32-bit` is enabled.
   - On 64-bit Windows, `64-bit` is selected by default and marked recommended.
   - `32-bit` remains selectable on 64-bit Windows for technician override.
3. Managed-access setup page explaining that administrator approval and a permanent support password are required.
4. Install/progress page.
5. Finish page with an option to launch AntrevaDesk.

The installer must not imply hidden or silent enrollment. It remains an authorized, visible onboarding flow.

## Branding Assets

The provided PNG will be copied into the repo under a stable branding path during implementation, then converted into installer-friendly formats:

- `branding/antreva-tech-logo.png` for source tracking;
- `packaging/antrevadesk/assets/banner.bmp` for NSIS wizard branding;
- `packaging/antrevadesk/assets/dialog.bmp` if the chosen NSIS theme uses a side image;
- `packaging/antrevadesk/assets/antrevadesk.ico` if an ICO can be generated cleanly from the source.

If the white transparent logo does not read well on the default installer background, the NSIS pages should use a dark or neutral header area behind the logo instead of altering the source logo destructively.

## Payload Handling

`scripts/Build-PilotBundle.ps1` will be replaced or extended with an installer build script that:

- downloads both RustDesk payloads when missing;
- verifies each payload SHA-256;
- verifies Authenticode signatures on Windows;
- places the payloads into the NSIS build staging directory;
- embeds the managed setup script;
- builds `AntrevaDesk-Setup-0.1.0.exe`;
- writes `AntrevaDesk-Setup-0.1.0.sha256.txt`.

Expected payload metadata will live in one script-level table keyed by architecture:

- `x64`: filename, URL, SHA-256, display label;
- `x86`: filename, URL, SHA-256, display label.

The release pipeline should fail if either payload is missing, hash verification fails, signature verification fails, or NSIS is unavailable.

## Setup Backend

The existing PowerShell setup flow will remain the source of truth for managed access behavior. It will be refactored to accept a selected architecture or explicit installer EXE path from the GUI bootstrapper.

Required backend behavior:

- detect Windows client/server edition and block server editions;
- support Windows 7 SP1 through Windows 11 on x86 or x64 where the matching payload is selected;
- keep Windows 7 prerequisites: WMF 5.1, KB4490628, and KB4474419;
- verify the selected payload hash;
- verify the selected payload signature;
- request elevation when needed;
- install the RustDesk service using the selected payload;
- import Antreva custom server configuration;
- apply managed-access options;
- prompt for and verify the permanent support password;
- create visible `Antreva Desk` desktop and Start Menu shortcuts;
- launch the installed app when setup completes.

The installed RustDesk application may still show upstream RustDesk branding until the separate Antreva-branded client build is ready. The installer, shortcuts, local launcher folder, and release artifact names should use AntrevaDesk or Antreva Desk consistently.

## Documentation Updates

Update the Windows support documentation from x64-only to x86/x64 support:

- Windows 7 SP1 x86 and x64;
- Windows 8 x86 and x64;
- Windows 8.1 x86 and x64;
- Windows 10 x86 and x64;
- Windows 11 x64.

Windows 11 x86 is not listed because Windows 11 is distributed for 64-bit client systems.

Update the pilot README, test plan, release checklist, and workflow release notes to describe the single GUI installer and architecture selection.

## Tests and Verification

Repository verification scripts should assert:

- the release artifact is `AntrevaDesk-Setup-0.1.0.exe`;
- both x86 and x64 RustDesk payload names appear in the build script;
- both payload hashes are checked;
- the setup backend no longer rejects all 32-bit Windows;
- the installer includes an architecture selection path;
- documentation no longer says 32-bit Windows is unsupported;
- the AntrevaDesk name appears in user-facing installer surfaces.

Manual certification should include:

- Windows 7 SP1 x86 with WMF 5.1 and SHA-2 updates;
- Windows 7 SP1 x64 with WMF 5.1 and SHA-2 updates;
- Windows 8 x86 and x64;
- Windows 8.1 x86 and x64;
- Windows 10 x86 and x64;
- Windows 11 x64.

For each platform, verify install, service startup, Antreva server settings, permanent password access, remote control, bidirectional file transfer, visible tray/app, shortcuts, app launch, and reboot persistence.

## Open Implementation Notes

The implementation must fetch and record the exact SHA-256 for `rustdesk-1.4.8-x86-sciter.exe` before enabling the x86 build path. The x64 SHA-256 is already known in the current scripts.

NSIS may need to be installed on GitHub Actions before building the installer. If `windows-latest` does not include it, the workflow should install it with Chocolatey or a pinned setup step.

