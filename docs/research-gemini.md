# Research notes — Setting up a VPN on Fly.io

> Source: a planning conversation with Gemini, recorded here for reference.
> These are the design decisions behind the configuration in this repo.

## Can you run a VPN on Fly.io?

Yes. Fly.io runs arbitrary Docker containers as microVMs across a global
network, which makes it a good host for a lightweight, high-performance VPN
gateway. Three common approaches:

### 1. Built-in Fly.io WireGuard (easiest, private only)
Fly uses WireGuard internally for its private network (6PN). You can create a
tunnel straight into your org:

```bash
fly wireguard create personal lhr my-mac
```

Best for accessing **private** databases / internal apps inside your Fly org —
not for routing general internet traffic.

### 2. Custom WireGuard gateway (what this repo does)
Deploy a WireGuard Docker image (`linuxserver/wireguard`) to route **all** of
your traffic and mask your IP. Requirements:
- Enable IPv4/IPv6 forwarding + masquerading inside the container.
- Allocate a dedicated public IP.
- Expose a **raw UDP** port in `fly.toml` (WireGuard is UDP; bypass the HTTP/TCP proxy).

### 3. Tailscale subnet router / exit node
Zero-config mesh VPN, no public inbound port or key management. Good when you
just want seamless access to your Fly network.

## Fly.io-specific constraints
- **UDP handling** — WireGuard is UDP-only; `fly.toml` must declare a UDP service.
- **Kernel modules** — you can't load host kernel modules; use the userspace
  implementation (`wireguard-go`). The linuxserver image falls back to it
  automatically. Slightly slower than the kernel module, fine for personal use.
- **Bandwidth costs** — inbound is free; outbound (egress) is metered, so heavy
  streaming through the tunnel adds up.

## Cost: self-hosted vs. commercial VPN

Self-hosted on Fly.io (single user, always-on):

| Item                       | Cost                |
|----------------------------|---------------------|
| 512MB shared-cpu-1x VM     | ~$3.32 / month      |
| Dedicated IPv4             | $2.00 / month       |
| Outbound data (UK/EU)      | $0.02 / GB          |

- Light user (50 GB/mo, UK/EU): **~$6.32 / month**
- Heavy user (300 GB/mo, UK/EU): **~$11.32 / month**

Commercial VPNs (flat rate, unlimited bandwidth):
- Mullvad ~€5/mo · ProtonVPN / NordVPN ~$4–12/mo

| Feature           | Fly.io self-hosted        | Commercial VPN            |
|-------------------|---------------------------|---------------------------|
| Pricing           | Usage-based               | Flat monthly              |
| Avg cost          | $5–12+/mo                 | $4–6/mo                   |
| Bandwidth         | Metered                   | Unlimited                 |
| IP address        | Dedicated (clean IP)      | Shared (often CAPTCHA'd)  |
| Server locations  | 1 fixed (where deployed)  | Global switching          |
| Streaming         | Poor (cloud IPs blocked)  | Good                      |

**Choose Fly.io** for a clean dedicated IP or an entry point into your Fly
private network. **Choose a commercial service** for casual privacy, heavy
streaming, or location-switching.
