# Antreva Desk Local Address Book Design

## Summary

Antreva Desk will replace the current Antreva Remote pilot branding and add a local-only technician address book inside the existing RustDesk Address Book experience. The address book will work without a RustDesk account or cloud login, store customer metadata locally, and support a locally encrypted managed-access password per customer system.

The first implementation should stay Windows-focused and technician-focused. It should not add a hosted customer database, Antreva account login, cross-device sync, or server-side address book service.

## Goals

- Rebrand the pilot product and release artifacts from Antreva Remote to Antreva Desk.
- Add a visible version number, starting with `0.1.0`, that is easy to identify in release artifact names and setup output.
- Make RustDesk's existing Address Book tab useful without account login.
- Store client records locally on the technician computer.
- Store each managed-access password locally and encrypted with Windows user-scoped protection.
- Keep address book data off the Antreva RustDesk server.
- Preserve RustDesk's existing remote desktop and file-transfer behavior.

## Non-Goals

- No cloud address book service in this phase.
- No shared multi-technician sync in this phase.
- No unattended setup changes beyond using the existing managed-access password created during onboarding.
- No automatic password harvesting from client machines.
- No password values in logs, screenshots, GitHub Actions output, release checksums, or source-controlled defaults.

## User Experience

The technician app should be branded as Antreva Desk. The Address Book tab should be visible and usable without signing into a RustDesk account.

The technician can create or edit a customer system record with:

- RustDesk ID
- client name
- alias or display name
- tags
- hostname
- notes
- managed-access password

The managed-access password should be masked during entry and display. The UI may allow reveal/copy actions only as explicit technician actions. If a password is not saved for a record, connection should still work through the normal manual password prompt.

The client-side installed agent should keep the existing managed-access behavior. This feature does not make the client invisible or change the consent/compliance posture already documented for managed access.

## Data Model

RustDesk already has an address book cache format exposed through:

- `mainLoadAb`
- `mainSaveAb`
- `mainClearAb`

Antreva Desk should keep using the existing local address book shape where practical:

- peer ID
- alias
- hostname
- username
- platform
- tags

Antreva-specific fields that do not fit cleanly in the upstream model should be stored in a separate local Antreva metadata file keyed by RustDesk ID. This avoids overloading upstream fields and keeps future RustDesk merges simpler.

The local metadata should include:

- client name
- notes
- encrypted password payload
- Antreva schema version
- record updated timestamp

## Password Storage

Managed-access passwords must not be stored inside the normal RustDesk address book JSON/cache as plain text.

On Windows, password storage should use DPAPI user-scoped encryption through a small Rust-side helper exposed to Flutter. The encrypted payload will be stored in an Antreva metadata file under the same per-user RustDesk/Antreva config area.

Expected behavior:

- The password can be decrypted only by the same Windows user profile that saved it.
- The encrypted payload remains local to the technician computer.
- Copy/export flows must exclude passwords unless a future explicit encrypted export feature is designed.
- If DPAPI decrypt fails, the app should keep the address book record and ask the technician to re-enter the password.

## Architecture

The implementation should patch the existing RustDesk address book flow rather than building a separate customer manager.

Flutter layer:

- Add an Antreva local-address-book mode.
- Initialize a local address book without requiring `userModel.isLogin`.
- Hide or bypass server sync paths when Antreva local mode is enabled.
- Load and save local customer metadata alongside the RustDesk address book cache.
- Add fields for client name, notes, and managed-access password in the existing add/edit peer flow.

Rust/native layer:

- Add FFI methods for Antreva local metadata load/save.
- Add FFI methods for DPAPI encrypt/decrypt of managed-access passwords on Windows.
- Keep unsupported platforms returning a clear error for password storage until they are explicitly supported.

Release/build layer:

- Add a single Antreva Desk version source used by scripts and workflow artifact names.
- Rename release zip artifacts to include product name and version, for example `Antreva-Desk-0.1.0-Windows.zip`.
- Update setup output and bundled documentation from Antreva Remote to Antreva Desk where applicable.

## Error Handling

- If local address book cache loading fails, the app should show an empty local address book and keep the corrupted/unreadable file for manual recovery where possible.
- If metadata loading fails, the core address book should still load without notes/passwords.
- If password decrypt fails, the record remains visible and the password field is treated as missing.
- If saving fails, the technician should see a clear failure message and the app should avoid pretending the password was saved.

## Compliance And Security Notes

This feature stores managed-access passwords on the technician device, so the technician Windows account and disk encryption become part of the security boundary. Documentation should state that the technician workstation should use a protected Windows account, full-disk encryption, and normal endpoint security controls.

AGPL compliance remains required because this continues to modify and distribute RustDesk OSS.

## Testing

Manual test coverage should include:

- Fresh Antreva Desk install shows the new product name and version.
- Release zip name includes `Antreva-Desk` and the version.
- Address Book tab is usable without RustDesk login.
- Add, edit, delete, and tag a customer system.
- Save notes and verify they survive app restart.
- Save managed-access password and verify it survives app restart for the same Windows user.
- Verify encrypted password data is not stored as plain text in local files.
- Verify another Windows user cannot decrypt the password payload.
- Verify connection still works when no password is stored.
- Verify password decrypt failure asks for re-entry instead of deleting the address book record.

## Open Implementation Detail

The implementation may start with the local metadata file and DPAPI FFI first, then wire deeper connection automation later if RustDesk's connection flow requires more invasive changes. The minimum useful release is a local address book that stores the password securely and lets the technician retrieve or use it during connection without needing any RustDesk account login.
