# Windows 7-11 Support

Antreva Desk 0.1.0 supports Windows 7 SP1 through Windows 11 x86/x64 for the
managed-access GUI installer. The installer includes both 32-bit and 64-bit
RustDesk payloads and presents an architecture selection page before setup.

## Supported Client Matrix

| Operating system | Architecture | Required prerequisites |
| --- | --- | --- |
| Windows 7 SP1 x86 | x86 | WMF 5.1, KB4490628, KB4474419 |
| Windows 7 SP1 x64 | x64 | WMF 5.1, KB4490628, KB4474419 |
| Windows 8 x86 | x86 | Built-in PowerShell 3 or newer |
| Windows 8 x64 | x64 | Built-in PowerShell 3 or newer |
| Windows 8.1 x86 | x86 | Built-in PowerShell 4 or newer |
| Windows 8.1 x64 | x64 | Built-in PowerShell 4 or newer |
| Windows 10 x86 | x86 | Built-in PowerShell 5.1 or newer |
| Windows 10 x64 | x64 | Built-in PowerShell 5.1 or newer |
| Windows 11 x64 | x64 | Built-in PowerShell 5.1 or newer |

On 32-bit Windows, the installer disables the 64-bit option. On 64-bit Windows,
the installer selects 64-bit by default while still allowing a deliberate
32-bit override.

## Windows 7 Requirements

Windows 7 is end-of-life and must be prepared before Antreva Desk onboarding:

1. Install Windows 7 Service Pack 1.
2. Install Windows Management Framework 5.1 so PowerShell reports version 5.1
   or newer.
3. Install SHA-2 signing support updates KB4490628 and KB4474419.
4. Reboot after installing prerequisites.
5. Run `AntrevaDesk-Setup-0.1.0.exe`.

The setup script checks these prerequisites before installing the managed
support service. Missing Windows 7 prerequisites stop setup with a visible
message instead of continuing into a partial install.

## Unsupported Cases

The installer must fail before install for:

- Choosing the 64-bit payload on 32-bit Windows.
- Windows 7 without Service Pack 1.
- Windows 7 missing WMF 5.1.
- Windows 7 missing KB4490628 or KB4474419.
- Windows versions older than Windows 7 SP1.
- Windows Server editions.

## Certification Checklist

Before distributing a release with Windows 7-11 support, manually test the
installer on:

- Windows 7 SP1 x86 with WMF 5.1, KB4490628, and KB4474419 installed.
- Windows 7 SP1 x64 with WMF 5.1, KB4490628, and KB4474419 installed.
- Windows 8 x86.
- Windows 8 x64.
- Windows 8.1 x86.
- Windows 8.1 x64.
- Windows 10 x86.
- Windows 10 x64.
- Windows 11 x64.

For each supported OS, verify install, app launch, visible tray, remote
control, bidirectional file transfer, clean disconnect, and post-reboot server
settings persistence.
