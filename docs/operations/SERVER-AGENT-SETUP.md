# Antreva Remote Server Setup Task

You are setting up the self-hosted RustDesk OSS server for Antreva Remote.

Repository:

https://github.com/antreva-tech/tool-antreva-remote.git

Environment:

The agent is running in WSL on the computer that will host the service. Use the
Linux/WSL commands below. Windows Firewall and router/firewall forwarding may
still need to be configured from Windows or the network appliance.

## Goal

Run the RustDesk server components:

- `hbbs`: ID/rendezvous server
- `hbbr`: relay server

This server must be reachable publicly through the office static IP or DNS name.

## Steps

### 1. Clone the Repository

Run:

```bash
git clone https://github.com/antreva-tech/tool-antreva-remote.git
cd tool-antreva-remote
git submodule update --init --recursive
```

### 2. Install Docker

Install Docker and Docker Compose if they are not already installed.

Preferred WSL setup:

- Docker Desktop installed on Windows.
- WSL integration enabled for this distro.
- `docker` and `docker compose` available inside WSL.

Alternative:

- Native Docker Engine installed inside WSL.
- The agent must confirm containers can publish ports reachable from outside the
  machine.

After installation, verify Docker works:

```bash
docker --version
docker compose version
```

### 3. Configure the Office Server Deployment

Go to the server deployment folder:

```bash
cd infra/office-server
cp .env.example .env
```

Edit `.env` and replace:

```env
ANTREVA_REMOTE_HOST=remote.antreva.example
```

with the real public DNS name or static IP for this office server.

Example:

```env
ANTREVA_REMOTE_HOST=remote.antreva.com
```

### 4. Start the RustDesk Server

Run:

```bash
docker compose pull
docker compose up -d
docker compose ps
```

You should see both containers running:

- `antreva-remote-hbbs`
- `antreva-remote-hbbr`

### 5. Open Firewall and Router Ports

Forward these ports from the public Internet to this office server.

TCP:

```text
21114-21119
```

UDP:

```text
21116
```

If this server uses Windows Firewall, add inbound allow rules for those ports.

If this server is behind a router or firewall appliance, forward those ports to this computer's LAN IP address.

WSL note:

- If using Docker Desktop with WSL integration, verify the ports are reachable
  on the Windows host, not only inside WSL.
- If using WSL2 NAT networking and the ports are not reachable externally, use
  Docker Desktop port publishing, WSL mirrored networking, or Windows `netsh
  interface portproxy` rules to expose the ports through the Windows host.
- Do not mark the setup complete until the ports are reachable from outside the
  office network.

### 6. Verify Server Logs

From `infra/office-server`, run:

```bash
docker compose logs --tail 100 hbbs
docker compose logs --tail 100 hbbr
```

Confirm there are no repeated startup errors.

### 7. Get the RustDesk Server Public Key

From `infra/office-server`, run:

```bash
cat data/id_ed25519.pub
```

Send this public key back to Steve.

Do not share, delete, or overwrite files inside:

```text
infra/office-server/data/
```

That folder contains the server identity and must be backed up.

## Success Criteria

- `docker compose ps` shows `antreva-remote-hbbs` running.
- `docker compose ps` shows `antreva-remote-hbbr` running.
- TCP `21114-21119` are reachable from outside the office network.
- UDP `21116` is forwarded to the server.
- The public key from `infra/office-server/data/id_ed25519.pub` has been sent
  back to Steve.
- `infra/office-server/data/` is backed up or marked for backup.

## Do Not Do

- Do not change managed-access behavior from the approved visible onboarding
  flow.
- Do not expose private key files.
- Do not commit `.env`.
- Do not commit `infra/office-server/data/`.
- Do not change the Docker ports unless Steve approves it.
- Do not delete or regenerate the server key after clients have been configured.

## Final Report Back to Steve

Send Steve:

- The public DNS name or static IP used for `ANTREVA_REMOTE_HOST`.
- The RustDesk server public key.
- Confirmation that both containers are running.
- Confirmation that TCP `21114-21119` and UDP `21116` are forwarded.
- Any errors or warnings from Docker logs.
