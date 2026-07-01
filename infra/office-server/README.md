# Office Server Deployment

This folder deploys the self-hosted RustDesk OSS server for Antreva Remote.

## Prerequisites

- Local office server with Docker Compose.
- Static public IP or DNS name.
- Router/firewall forwarding TCP `21114:21119` and UDP `21116`.
- Backups for `infra/office-server/data`.

## Start

```powershell
Copy-Item .env.example .env
notepad .env
docker compose up -d
```

After the containers start, read the generated public key:

```powershell
..\..\scripts\Get-RustDeskServerKey.ps1
```

Copy that value into `config/antreva-client-policy.json` as the `key` option.

## Verify

```powershell
docker compose ps
docker compose logs --tail 100 hbbs
docker compose logs --tail 100 hbbr
```

From an external network, confirm that TCP `21115`, `21116`, `21117`, `21118`,
and `21119` are reachable and UDP `21116` is forwarded.
