#!/usr/bin/env bash
#
# Pull a generated WireGuard client config off the running Fly machine and
# save it locally (gitignored). Import the resulting .conf into the WireGuard
# app on your Mac, then Activate.
#
set -euo pipefail

APP="${FLY_APP:-fly-vpn-erdem}"
PEER="${1:-mac}"
VAULT="${AZ_VAULT:-dp-kv-deliverypilot}"
SECRET="${AZ_SECRET:-FLYIOTOKEN}"
OUT_DIR="wg-clients"

FLY_API_TOKEN="$(az keyvault secret show --vault-name "$VAULT" --name "$SECRET" --query value -o tsv)"
export FLY_API_TOKEN

mkdir -p "$OUT_DIR"
echo "==> Reading /config/peer_${PEER}/peer_${PEER}.conf from $APP"
fly ssh console -a "$APP" -C "cat /config/peer_${PEER}/peer_${PEER}.conf" > "$OUT_DIR/${PEER}.conf"

echo "==> Saved $OUT_DIR/${PEER}.conf"
echo "    Import it into the WireGuard app on your Mac and click Activate."
echo
echo "    Or show the QR code (for phones) with:"
echo "    fly ssh console -a $APP -C \"/app/show-peer ${PEER}\""
