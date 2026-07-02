# Antreva Code Signing Plan

This document covers how to get Windows code signing specifically under the
Antreva publisher identity.

## Recommendation

Use Azure Artifact Signing, formerly Microsoft Trusted Signing, if Antreva has
or can create a paid Azure subscription. It is Microsoft's recommended signing
service for non-Store Windows app distribution and avoids managing a USB token
or private key on a developer PC.

Fallback option: buy an OV Code Signing certificate from a public CA such as
DigiCert, Sectigo, SSL.com, or GlobalSign, using either a hardware token or the
CA's cloud signing service.

Do not buy EV only to avoid SmartScreen warnings. Microsoft now says EV
certificates no longer bypass SmartScreen reputation by default; reputation is
built over time from signed files and publisher history.

## What Antreva Needs Before Ordering

- Exact legal organization name, such as `Antreva LLC` or the registered
  business name.
- Registered business address.
- Public business phone number that can be verified by the CA.
- Business email address for the certificate request.
- Domain ownership or an Antreva-controlled email/domain verification path.
- Person authorized to approve certificate issuance.
- Decision on signing custody:
  - Azure Artifact Signing/cloud signing for automation.
  - CA cloud signing.
  - USB hardware token for manual signing.

## Option A: Azure Artifact Signing

Best for Antreva if the goal is repeatable CI/CD signing without handling key
material locally.

High-level setup:

1. Create or use a paid Azure subscription.
2. Create an Azure Artifact Signing account.
3. Complete identity validation for Antreva.
4. Create a certificate profile for public trust signing.
5. Install the Microsoft signing tooling on the build machine or CI runner.
6. Sign release artifacts during the Windows release process.

Important notes:

- Free, trial, and sponsored Azure subscriptions are not supported for creating
  Artifact Signing accounts.
- SmartScreen reputation may still need to build organically.
- Keep signing permissions restricted to release maintainers.

## Option B: OV Code Signing Certificate

Best if Antreva wants a traditional certificate from a public CA.

High-level setup:

1. Choose a CA: DigiCert, Sectigo, SSL.com, GlobalSign, or another Microsoft
   trusted public CA.
2. Order an Organization Validation code signing certificate for Antreva.
3. Complete organization validation.
4. Choose key storage:
   - CA cloud signing service, or
   - shipped/enrolled hardware token.
5. Install Windows SDK on the build/signing machine for `signtool.exe`.
6. Sign every EXE/MSI release artifact with SHA-256 and a timestamp server.

Example local signing command, once a certificate is available in the Windows
certificate store:

```powershell
signtool.exe sign /sha1 <ANTREVA_CERT_THUMBPRINT> /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 <binary.exe>
```

## Key Protection Requirement

Since June 1, 2023, publicly trusted code signing private keys must be generated,
stored, and used in suitable hardware-backed crypto modules or approved cloud
signing systems. A normal exportable `.pfx` file should not be expected for a new
public code signing certificate.

## Antreva Release Gate

Before distributing a branded Antreva build:

- [ ] Antreva certificate or Artifact Signing profile is issued.
- [ ] Build machine has signing tooling installed.
- [ ] Signing access is limited to authorized maintainers.
- [ ] `Antreva Remote.exe` is signed.
- [ ] Signature verifies with `Get-AuthenticodeSignature`.
- [ ] Timestamp is present.
- [ ] Source offer and AGPL notices are published with the release.

## Current Pilot State

The pilot currently uses the official signed RustDesk Windows binary configured
for Antreva's server. That is enough to test connectivity, managed access,
remote control, and file transfer.

The final Antreva-branded release still needs:

- Windows build toolchain;
- Antreva branding assets;
- Antreva signing identity;
- final signed EXE/MSI artifacts.
