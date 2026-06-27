# Connecting your Mac to the Fly.io VPN

This repo deploys a **custom WireGuard gateway** (full-internet VPN). Steps:

## 1. Install the WireGuard client
Install **WireGuard** from the Mac App Store.

## 2. Get your client config
After deploying (`scripts/deploy.sh`), pull the generated config:

```bash
scripts/get-client-config.sh mac      # writes wg-clients/mac.conf
```

This SSHes into the Fly machine and reads `/config/peer_mac/peer_mac.conf`.

## 3. Import and activate
1. Open the WireGuard app on your Mac.
2. Click **+ → Import tunnel(s) from file** and select `wg-clients/mac.conf`.
3. Click **Activate**.

## 4. Verify your new IP
Visit `https://ifconfig.me` (or `icanhazip.com`). The IP shown should match the
dedicated IPv4 allocated to the Fly app, not your home ISP.

---

## Bonus: Fly's built-in private network (Scenario A)
If instead you only need to reach apps *inside* your Fly org (not full-internet
routing):

```bash
fly wireguard create personal lhr my-mac   # outputs a WireGuard config block
```

Save the output as `fly.conf`, import it into the WireGuard app, Activate.

## Troubleshooting
- **DNS not resolving `*.internal`** — ensure the config has a `DNS = fdaa::3` line.
- **Tunnel "Active" but no traffic** — restrictive Wi-Fi may block outbound UDP;
  WireGuard needs UDP to pass data.
- **Ping works / small pages load but HTTPS hangs** — MTU is too high for the
  path to Fly. Add `MTU = 1280` under `[Interface]` in the client config and
  reconnect. The server also clamps TCP MSS to PMTU as a safety net.
  Verify with: `ping -c2 -D -s 1400 10.13.13.1` (fails) vs `-s 1200` (works).
