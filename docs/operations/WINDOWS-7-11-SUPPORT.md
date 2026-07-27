# Windows 7-11 Support

Antreva Desk 1.0.3 supports Windows 7 SP1 through Windows 11 x86/x64 for the
managed-access Command Prompt installer. The ZIP includes both 32-bit and 64-bit
RustDesk payloads, and the setup automatically selects the architecture that
matches Windows. Managed clients do not need PowerShell.

## Supported Client Matrix

| Operating system | Architecture | Required prerequisites |
| --- | --- | --- |
| Windows 7 SP1 x86 | x86 | KB4490628, KB4474419 |
| Windows 7 SP1 x64 | x64 | KB4490628, KB4474419 |
| Windows 8 x86 | x86 | Built-in Command Prompt tools |
| Windows 8 x64 | x64 | Built-in Command Prompt tools |
| Windows 8.1 x86 | x86 | Built-in Command Prompt tools |
| Windows 8.1 x64 | x64 | Built-in Command Prompt tools |
| Windows 10 x86 | x86 | Built-in Command Prompt tools |
| Windows 10 x64 | x64 | Built-in Command Prompt tools |
| Windows 11 x64 | x64 | Built-in Command Prompt tools |

The Windows 11 certification target includes Windows 11 26H1. On 32-bit
Windows, setup automatically selects x86. On 64-bit Windows, setup
automatically selects x64.

The `--verify-bundle` option is a non-installing build and integrity check, not
a supported-client check. It deliberately skips the client OS preflight so the
GitHub Actions workflow can validate the bundle on a Windows Server runner.
Normal setup without that option still performs the checks documented here and
rejects Windows Server editions before installation.

## Windows 7 Requirements

Windows 7 is end-of-life and must be prepared before Antreva Desk onboarding:

1. Install Windows 7 Service Pack 1.
2. Install SHA-2 signing support updates KB4490628 and KB4474419.
3. Reboot after installing prerequisites.
4. Extract `Antreva-Desk-1.0.3-Windows.zip` and run
   `Antreva-Remote-Pilot-Setup.cmd`.

The setup script checks these prerequisites before installing the managed
support service. Missing Windows 7 prerequisites stop setup with a visible
message instead of continuing into a partial install.

## Unsupported Cases

The installer must fail before install for:

- Forcing the 64-bit payload on 32-bit Windows.
- Windows 7 without Service Pack 1.
- Windows 7 missing KB4490628 or KB4474419.
- Windows versions older than Windows 7 SP1.
- Windows Server editions.

## Certification Checklist

Before distributing a release with Windows 7-11 support, manually test the
installer on:

- Windows 7 SP1 x86 with KB4490628 and KB4474419 installed.
- Windows 7 SP1 x64 with KB4490628 and KB4474419 installed.
- Windows 8 x86.
- Windows 8 x64.
- Windows 8.1 x86.
- Windows 8.1 x64.
- Windows 10 x86.
- Windows 10 x64.
- Windows 11 x64.
- Windows 11 26H1 x64 as the current latest-version target.

For each supported OS, verify install, app launch, visible tray, remote
control, bidirectional file transfer, clean disconnect, and post-reboot server
settings persistence.
