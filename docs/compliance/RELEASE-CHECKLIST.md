# Release Checklist

Complete this checklist before distributing a build to clients.

- [ ] `config/antreva-client-policy.json` contains the production office host.
- [ ] `config/antreva-client-policy.json` contains the production server key.
- [ ] `enable-file-transfer` is `Y`.
- [ ] `one-way-file-transfer` is `N`.
- [ ] Attended-only behavior has been manually tested.
- [ ] No unattended access, permanent password, or hidden persistence flow is
      exposed in the branded v1 build.
- [ ] Windows binaries are signed with the Antreva code signing certificate.
- [ ] Source archive or repository tag is published for the exact build.
- [ ] AGPL/source link is present near the binary download.
- [ ] Office server `data` directory is backed up.
- [ ] External connectivity to TCP `21114:21119` and UDP `21116` is verified.
