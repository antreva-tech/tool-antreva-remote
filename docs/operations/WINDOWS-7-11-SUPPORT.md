# Windows 7-11 Support

Antreva Desk 1.0.4 is certified by explicit Windows client build number, not
marketing product-name heuristics. The Command Prompt installer covers
Windows 7 SP1 through Windows 11 x86/x64 only for the allowlisted builds below.
Managed clients do not need PowerShell.

## Supported Client Matrix

| Operating system | Architecture | Required prerequisites |
| --- | --- | --- |
| Windows 7 SP1 x86 | x86 | KB4490628, KB4474419 |
| Windows 7 SP1 x64 | x64 | KB4490628, KB4474419 |
| Windows 8 x86 | x86 | Built-in Command Prompt tools |
| Windows 8 x64 | x64 | Built-in Command Prompt tools |
| Windows 8.1 x86 | x86 | Built-in Command Prompt tools |
| Windows 8.1 x64 | x64 | Built-in Command Prompt tools |
| Windows 10 x86 | x86 | Certified builds through 19045 |
| Windows 10 x64 | x64 | Certified builds through 19045 |
| Windows 11 x64 | x64 | Certified builds through 28000 |

The explicit allowed builds are `7601`, `9200`, `9600`, `10240`, `10586`,
`14393`, `15063`, `16299`, `17134`, `17763`, `18362`, `18363`, `19041`,
`19042`, `19043`, `19044`, `19045`, `22000`, `22621`, `22631`, `26100`,
`26200`, and `28000`. Windows 10 22H2 is build 19045 and the Windows 11 26H1
target is build 28000. Unknown, gap, and future builds fail as not certified.
On 32-bit Windows setup selects x86. On 64-bit Windows—including a 32-bit
Command Prompt—it selects x64 using `%ProgramW6432%` discovery.

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
4. Extract `Antreva-Desk-1.0.4-Windows.zip` and run
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
- Windows ARM64.
- Windows client builds not present in the explicit allowlist.

## Certification Checklist

Before distributing 1.0.4, run clean-install and upgrade certification on:

- Windows 7 SP1 x86 with KB4490628 and KB4474419 installed (including the hard
  1.4.8 Sciter launch gate).
- Windows 7 SP1 x64 with KB4490628 and KB4474419 installed.
- Windows 10 22H2 x86.
- Windows 10 22H2 x64.
- Windows 10 22H2 standard user with separate administrator credentials.

Continue compatibility checks on:

- Windows 8 x86.
- Windows 8 x64.
- Windows 8.1 x86.
- Windows 8.1 x64.
- Windows 11 x64.
- Windows 11 26H1 x64 as the current latest-version target.

For each VM, verify clean/upgrade behavior as applicable, post-reboot automatic
running service with the exact image path, original-user Public Desktop and
Start Menu visibility, visible tray, exact server/relay/key persistence,
password authentication, remote control, bidirectional file transfer, and clean
disconnect. If Windows 7 x86 cannot launch the pinned payload, block 1.0.4 and
open a separate payload-selection task instead of silently downgrading.
