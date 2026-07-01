# Patch Workflow

The upstream RustDesk source is pinned under `upstream/rustdesk` and
`upstream/rustdesk-server`. Keep Antreva changes as small, reviewable patches.

Recommended patch order:

1. Apply product naming and Windows metadata changes.
2. Apply icon and about/source-offer changes.
3. Bake `config/antreva-client-policy.json` values into RustDesk built-in or
   overwrite settings.
4. Hide or disable unattended/password features for the v1 build.
5. Keep RustDesk file transfer enabled and bidirectional.

Do not add stealth startup, hidden persistence, unattended enrollment, or
credential capture behavior.
