# Windows App Configuration for Antreva Remote

This file contains the server information needed to configure a Windows RustDesk / Antreva Remote client.

## Quick Client Settings

Use these values in the Windows app until a DNS name is configured:

| Field | Value |
| --- | --- |
| ID Server | `104.184.67.190` |
| Relay Server | `104.184.67.190` |
| Key / Public Key | `YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=` |

## Windows App Setup

1. Open the RustDesk / Antreva Remote Windows app.
2. Open **Settings**.
3. Go to the **Network**, **ID Server**, or **ID/Relay Server** settings area. The exact label can vary by RustDesk version/build.
4. Set **ID Server** to:

   ```text
   104.184.67.190
   ```

5. Set **Relay Server** to:

   ```text
   104.184.67.190
   ```

6. Set **Key** or **Public Key** to:

   ```text
   YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=
   ```

7. Save/apply the settings.
8. Restart the Windows app if it does not reconnect immediately.
9. Test from outside the office network when possible.

## Current Server Reference

| Item | Current value |
| --- | --- |
| Public host/IP | `104.184.67.190` |
| DNS name | Not configured yet |
| RustDesk public key | `YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=` |
| Server deployment path | `infra/office-server/` |
| Server identity/data folder | `infra/office-server/data/` |
| Current local backup | `/home/sawyer/backups/antreva-remote/office-server-data-20260701T152442Z.tar.gz` |

## Server Components

The office server runs the RustDesk OSS server components through Docker Compose:

- `antreva-remote-hbbs`: ID / rendezvous server
- `antreva-remote-hbbr`: relay server

The server is configured with:

```env
ANTREVA_REMOTE_HOST=104.184.67.190
```

## Ports

The current OSS Docker Compose deployment publishes these ports:

| Purpose | Protocol | Port(s) | Status |
| --- | --- | --- | --- |
| hbbs NAT test / support | TCP | `21115` | Public TCP verified open |
| hbbs ID / rendezvous | TCP | `21116` | Public TCP verified open |
| hbbs ID / rendezvous | UDP | `21116` | Configured/listening; verify with real external client test |
| hbbr relay | TCP | `21117` | Public TCP verified open |
| hbbs websocket | TCP | `21118` | Public TCP verified open |
| hbbr websocket | TCP | `21119` | Public TCP verified open |

Router/firewall forwarding target:

```text
192.168.50.128
```

Forwarding rules:

```text
TCP 21115-21119 -> 192.168.50.128
UDP 21116       -> 192.168.50.128
```

WSL is configured for mirrored networking so the RustDesk containers can bind through the Windows host/LAN path.

## DNS Future Change

No public DNS name is configured yet.

If Antreva later creates a DNS record such as:

```text
remote.antreva.tech -> 104.184.67.190
```

then update:

1. `infra/office-server/.env`
2. the Windows app **ID Server** value
3. the Windows app **Relay Server** value

The client values would become:

```text
ID Server:    remote.antreva.tech
Relay Server: remote.antreva.tech
Key:          YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=
```

After changing `.env`, restart the Docker Compose deployment from `infra/office-server/`.

## Key and Backup Handling

The server identity folder is backup-critical:

```text
infra/office-server/data/
```

It contains the server identity and key material used by RustDesk clients.

Current local backup created during setup:

```text
/home/sawyer/backups/antreva-remote/office-server-data-20260701T152442Z.tar.gz
```

Recommended follow-up: copy this backup to a secure off-machine location.

## Do Not Do

- Do not change managed-access behavior from the approved visible onboarding
  flow.
- Do not share, commit, or expose private key files from `infra/office-server/data/`.
- Do not commit `infra/office-server/.env`.
- Do not commit `infra/office-server/data/`.
- Do not delete or regenerate the server key after clients have been configured.
- Do not change Docker ports unless Steven approves the change.

## Troubleshooting Checklist

If a Windows app cannot connect:

1. Confirm the app has the exact ID Server, Relay Server, and Key values from this file.
2. Restart the Windows app.
3. Test from a network outside the office LAN, such as a phone hotspot.
4. Confirm the office public IP is still:

   ```text
   104.184.67.190
   ```

5. Confirm the server containers are running from `infra/office-server/`:

   ```bash
   docker compose ps
   ```

6. Confirm server logs do not show repeated startup errors:

   ```bash
   docker compose logs --tail 100 hbbs
   docker compose logs --tail 100 hbbr
   ```

7. Confirm router/firewall forwards are still pointed to:

   ```text
   192.168.50.128
   ```

8. If TCP works but connections are unreliable, verify UDP `21116` with a real external RustDesk client test.
