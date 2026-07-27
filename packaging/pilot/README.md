# Antreva Desk 1.0.4 Managed Access Test Bundle

`Antreva-Desk-1.0.4-Windows.zip` is a zero-PowerShell Command Prompt bundle
for controlled Windows certification. Ordinary pull-request and `main`
workflows upload it as a 30-day test artifact. It is not client-ready and must
not be presented as the latest public release unless the separate protected
release workflow completes Antreva signing and live Windows certification.
The documented test matrix spans Windows 7 SP1 through Windows 11 x86/x64,
subject to the explicit build allowlist and live gates below.

The test bundle contains the pinned RustDesk `1.4.8` x64 and x86 Sciter
payloads, the generated `Antreva-Remote-Pilot-Setup.cmd`, and Windows Script
Host helpers for elevation, bounded process execution, service inspection, and
exact configuration verification. No PowerShell file or invocation is shipped
to the managed client.

## Setup Behavior

Run `Antreva-Remote-Pilot-Setup.cmd` from the extracted folder. Setup:

- allows only explicitly certified Windows client build numbers;
- selects native x86, native x64, or x64 from a 32-bit Command Prompt on x64;
- verifies the selected payload hash before and after installation;
- keeps the original user process waiting while a separate administrator
  process performs machine-wide setup;
- waits up to 180 seconds for the installer and rejects failure output;
- requires a matching, automatic, running `RustDesk` service;
- visibly prompts for the permanent password and requires daemon
  acknowledgement;
- verifies exact CLI and LocalService-profile persistence for the rendezvous
  server, non-blank relay, public key, and every managed policy option;
- creates Public Desktop and all-users Start Menu launchers; and
- returns to the original user process to launch RustDesk without elevation.

When a standard user supplies separate administrator credentials, the service
and shortcuts remain machine-wide and the original signed-in user receives the
final result and app launch.

The current-attempt log is
`%ProgramData%\AntrevaDesk\Logs\AntrevaDesk-Setup.log`. Result files never
contain the permanent password. The password is visible while typed and is
briefly exposed in the RustDesk CLI process command line while the daemon
receives it; this is unavoidable with the pinned RustDesk CLI.

## Contents

- `Antreva-Remote-Pilot-Setup.cmd`
- `AntrevaDesk-Elevate.vbs`
- `AntrevaDesk-ProcessWrapper.vbs`
- `AntrevaDesk-VerifyService.vbs`
- `AntrevaDesk-VerifyConfig.vbs`
- `payloads\x64\rustdesk-1.4.8-x86_64.exe`
- `payloads\x86\rustdesk-1.4.8-x86-sciter.exe`

## Non-installing CI Check

```text
Antreva-Remote-Pilot-Setup.cmd --verify-bundle
```

This checks architecture selection, the selected exact payload hash, and
required WSH helpers. It does not install the service and deliberately skips
the client OS check so it can run on a Windows Server CI runner. Passing it is
not Windows certification.

## Release Boundary

The pinned x86 Sciter payload must successfully launch on live Windows 7 SP1
x86 before 1.0.4 can be public. If it fails, block 1.0.4 and open a separate
pinned-payload selection task; do not silently downgrade the payload.
