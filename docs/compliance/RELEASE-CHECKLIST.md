# Release Checklist

Complete this checklist before distributing a build to clients.

- [ ] `config/antreva-client-policy.json` contains the production office host.
- [ ] `config/antreva-client-policy.json` contains the production server key.
- [ ] `enable-file-transfer` is `Y`.
- [ ] `one-way-file-transfer` is `N`.
- [ ] Managed-access onboarding has been manually tested.
- [ ] Permanent password setup requires visible technician onboarding and
      Windows administrator approval.
- [ ] No stealth startup, hidden tray behavior, disguised process, or silent
      enrollment is exposed in the branded v1 build.
- [ ] Windows 7 SP1 through Windows 11 x86/x64 support matrix has been certified.
- [ ] Clean install and upgrade pass on Windows 7 SP1 x86/x64 and Windows 10
      22H2 x86/x64.
- [ ] A Windows 10 standard-user test passes with separate administrator
      credentials, Public Desktop/all-users shortcuts, and original-user launch.
- [ ] Each certification VM passes rebooted service state, exact
      server/relay/key persistence, password authentication, remote control,
      and bidirectional file transfer.
- [ ] The pinned RustDesk 1.4.8 x86 Sciter payload launches on Windows 7 SP1
      x86; failure blocks 1.0.4 without a silent payload downgrade.
- [ ] Windows 7 prerequisite failures for KB4490628 and KB4474419 are visible
      before install.
- [ ] Windows binaries are signed with the Antreva code signing certificate.
- [ ] Source archive or repository tag is published for the exact build.
- [ ] AGPL/source link is present near the binary download.
- [ ] PR and `main` workflows expose `Antreva-Desk-1.0.4-Windows.zip` only as
      a 30-day test artifact.
- [ ] The protected manual release workflow verifies the Antreva signer and
      attaches the hashed Windows certification archive before publishing.
- [ ] The 1.0.3 upstream-signed release remains available as a prerelease and
      its tag has not been force-moved.
- [ ] GitHub Actions `--verify-bundle` check passes for both the exact pinned
      payload and WSH helpers without installing the client.
- [ ] Normal setup still runs the supported-client OS preflight and rejects
      Windows Server editions before installation.
- [ ] Unknown Windows client builds, ARM64, Server, pre-SP1 Windows 7, and
      build gaps are rejected as not certified.
- [ ] Office server `data` directory is backed up.
- [ ] External connectivity to TCP `21114:21119` and UDP `21116` is verified.
