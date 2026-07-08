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
- [ ] Windows 7 prerequisite failures for WMF 5.1, KB4490628, and KB4474419
      are visible before install.
- [ ] Windows binaries are signed with the Antreva code signing certificate.
- [ ] Source archive or repository tag is published for the exact build.
- [ ] AGPL/source link is present near the binary download.
- [ ] GitHub Actions release contains the `AntrevaDesk-Setup-1.0.0.exe`
      installer and SHA-256 file.
- [ ] Office server `data` directory is backed up.
- [ ] External connectivity to TCP `21114:21119` and UDP `21116` is verified.
