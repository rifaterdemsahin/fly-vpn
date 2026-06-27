# WireGuard VPN gateway for Fly.io
#
# The linuxserver/wireguard image runs WireGuard in *server* mode and
# auto-generates peer (client) configs on first boot. When the host kernel
# does not expose the wireguard module (as on Fly.io microVMs), the image
# transparently falls back to the userspace implementation (wireguard-go),
# so no host kernel module is required.
FROM ghcr.io/linuxserver/wireguard:latest
