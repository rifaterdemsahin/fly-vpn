#!/usr/bin/env bash
#
# Deploy the WireGuard VPN to Fly.io.
# The Fly API token is pulled from Azure Key Vault — never hardcoded.
#
# Prerequisites:
#   - az CLI logged in            (az login)
#   - flyctl installed            (brew install flyctl)
#   - read access to the vault    (dp-kv-deliverypilot / FLYIOTOKEN)
#
set -euo pipefail

APP="${FLY_APP:-fly-vpn-erdem}"
REGION="${FLY_REGION:-lhr}"
VAULT="${AZ_VAULT:-dp-kv-deliverypilot}"
SECRET="${AZ_SECRET:-FLYIOTOKEN}"

echo "==> Fetching Fly.io token from Azure Key Vault ($VAULT/$SECRET)"
FLY_API_TOKEN="$(az keyvault secret show --vault-name "$VAULT" --name "$SECRET" --query value -o tsv)"
export FLY_API_TOKEN
echo "    authenticated as: $(fly auth whoami)"

echo "==> Ensuring app '$APP' exists"
if ! fly apps list | grep -qw "$APP"; then
  fly apps create "$APP" --org personal
fi

echo "==> Creating persistent volume (if missing)"
if ! fly volumes list -a "$APP" | grep -qw wg_config; then
  fly volumes create wg_config --region "$REGION" --size 1 -a "$APP" --yes
fi

echo "==> Allocating a dedicated IPv4 (if missing)"
if ! fly ips list -a "$APP" | grep -qw v4; then
  fly ips allocate-v4 -a "$APP" --yes
fi
fly ips allocate-v6 -a "$APP" 2>/dev/null || true

PUBLIC_IP="$(fly ips list -a "$APP" | awk '/v4/{print $2; exit}')"
echo "==> Public IPv4: $PUBLIC_IP"

echo "==> Setting SERVERURL secret so peer configs point at the public IP"
fly secrets set SERVERURL="$PUBLIC_IP" -a "$APP" --stage

echo "==> Deploying"
fly deploy -a "$APP" --ha=false

echo "==> Done. Fetch client configs with: scripts/get-client-config.sh"
