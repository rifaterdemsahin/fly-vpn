# fly-vpn

Self-hosted **WireGuard VPN** on [Fly.io](https://fly.io) — route your Mac's
traffic through a dedicated public IP you control.

## What's here

| Path                          | Purpose                                            |
|-------------------------------|----------------------------------------------------|
| `Dockerfile`                  | `linuxserver/wireguard` server image               |
| `fly.toml`                    | App config: raw UDP service, volume, London region |
| `scripts/deploy.sh`           | One-shot deploy (token pulled from Azure Key Vault)|
| `scripts/get-client-config.sh`| Pull a peer `.conf` to import on your Mac          |
| `docs/research-gemini.md`     | Design rationale + cost comparison                 |
| `docs/connect-mac.md`         | Step-by-step Mac connection guide                  |

## Secrets

The Fly.io API token is **not** stored in this repo. It lives in Azure Key
Vault (`dp-kv-deliverypilot` / `FLYIOTOKEN`) and is fetched at deploy time:

```bash
FLY_API_TOKEN="$(az keyvault secret show \
  --vault-name dp-kv-deliverypilot --name FLYIOTOKEN --query value -o tsv)"
```

Generated WireGuard client/server keys (`*.conf`, `wg-clients/`) are gitignored
and never committed.

## Quick start

```bash
az login                      # one-time Azure auth
./scripts/deploy.sh           # create app, IP, volume, secrets, deploy
./scripts/get-client-config.sh mac   # → wg-clients/mac.conf
```

Then import `wg-clients/mac.conf` into the WireGuard Mac app and **Activate**.
See [`docs/connect-mac.md`](docs/connect-mac.md).

## Cost (single user, UK/EU)

~$6/month light use (512MB VM + dedicated IPv4 + ~50 GB egress). Full breakdown
in [`docs/research-gemini.md`](docs/research-gemini.md).
