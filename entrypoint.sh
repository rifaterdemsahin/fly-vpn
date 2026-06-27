#!/bin/bash
# Generate WireGuard server + peer configs on first boot, then bring the
# tunnel up with the userspace implementation (wireguard-go). Configs persist
# on the /config volume so keys stay stable across redeploys.
set -euo pipefail

CONF_DIR=/config
SERVER_CONF="$CONF_DIR/wg0.conf"
PORT="${SERVERPORT:-51820}"
PREFIX="${SUBNET_PREFIX:-10.13.13}"      # /24, server is .1, peers from .2
PEERS="${PEERS:-mac}"
DNS="${PEERDNS:-1.1.1.1}"
ALLOWEDIPS="${ALLOWEDIPS:-0.0.0.0/0}"
SERVERURL="${SERVERURL:-$(curl -s https://api.ipify.org || echo CHANGE_ME)}"

mkdir -p "$CONF_DIR"

# --- server keys (generated once) ---
if [ ! -f "$CONF_DIR/server_private.key" ]; then
  umask 077
  wg genkey | tee "$CONF_DIR/server_private.key" | wg pubkey > "$CONF_DIR/server_public.key"
fi
SERVER_PRIV="$(cat "$CONF_DIR/server_private.key")"
SERVER_PUB="$(cat "$CONF_DIR/server_public.key")"

# --- server interface ---
cat > "$SERVER_CONF" <<EOF
[Interface]
Address = ${PREFIX}.1/24
ListenPort = ${PORT}
PrivateKey = ${SERVER_PRIV}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE; iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
EOF

# --- peers ---
i=2
IFS=','
for p in $PEERS; do
  p="$(echo "$p" | tr -d '[:space:]')"
  [ -z "$p" ] && continue
  PDIR="$CONF_DIR/peer_$p"
  mkdir -p "$PDIR"
  if [ ! -f "$PDIR/private.key" ]; then
    umask 077
    wg genkey | tee "$PDIR/private.key" | wg pubkey > "$PDIR/public.key"
    wg genpsk > "$PDIR/preshared.key"
  fi
  PPRIV="$(cat "$PDIR/private.key")"
  PPUB="$(cat "$PDIR/public.key")"
  PPSK="$(cat "$PDIR/preshared.key")"
  PIP="${PREFIX}.${i}"

  cat >> "$SERVER_CONF" <<EOF

[Peer]
# ${p}
PublicKey = ${PPUB}
PresharedKey = ${PPSK}
AllowedIPs = ${PIP}/32
EOF

  cat > "$PDIR/peer_$p.conf" <<EOF
[Interface]
PrivateKey = ${PPRIV}
Address = ${PIP}/24
DNS = ${DNS}
MTU = ${CLIENT_MTU:-1280}

[Peer]
PublicKey = ${SERVER_PUB}
PresharedKey = ${PPSK}
Endpoint = ${SERVERURL}:${PORT}
AllowedIPs = ${ALLOWEDIPS}
PersistentKeepalive = 25
EOF
  echo "peer '$p' -> ${PIP}  (config: $PDIR/peer_$p.conf)"
  i=$((i + 1))
done
unset IFS

# --- enable forwarding ---
echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || sysctl -w net.ipv4.ip_forward=1 || true

# --- bring up tunnel using userspace wireguard-go ---
export WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go
export WG_I_PREFER_BUGGY_USERSPACE_TO_POLISHED_KMOD=1

wg-quick down "$SERVER_CONF" 2>/dev/null || true
wg-quick up "$SERVER_CONF"

echo "==> WireGuard up on UDP ${PORT}. Endpoint: ${SERVERURL}:${PORT}"
wg show

# keep the container alive
while true; do sleep 3600; done
