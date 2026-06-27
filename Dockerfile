# WireGuard VPN gateway for Fly.io — self-contained, userspace.
#
# Fly microVMs can't load the wireguard kernel module and Fly's init takes
# PID 1 (which breaks s6-based images like linuxserver/wireguard). So we run
# the userspace implementation (wireguard-go) directly via wg-quick, with a
# small entrypoint that generates server + peer configs on first boot.

# --- build wireguard-go (not packaged in Alpine stable) ---
FROM golang:1.23-alpine AS build
RUN apk add --no-cache git make bash
RUN git clone --depth 1 https://git.zx2c4.com/wireguard-go /src \
    && cd /src \
    && make \
    && install -m 0755 wireguard-go /wireguard-go

# --- runtime ---
FROM alpine:3.20
RUN apk add --no-cache \
      wireguard-tools \
      iptables \
      ip6tables \
      iproute2 \
      bash \
      curl
COPY --from=build /wireguard-go /usr/bin/wireguard-go
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
