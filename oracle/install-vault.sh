#!/usr/bin/env bash
# ==============================================================================
# One-Command Oracle Cloud VM HashiCorp Vault Setup Script
# Installs Docker, configures firewall, boots Vault with Caddy SSL
# ==============================================================================
set -euo pipefail

echo ">>> [1/5] Updating system packages..."
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y curl ufw git jq

echo ">>> [2/5] Installing Docker & Docker Compose..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
fi

sudo apt-get install -y docker-compose-plugin

echo ">>> [3/5] Configuring Ubuntu Firewall for Oracle Cloud..."
# Oracle Ubuntu images have strict iptables rules by default
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 8200 -j ACCEPT
sudo netfilter-persistent save 2>/dev/null || sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null || true

echo ">>> [4/5] Preparing Vault directories..."
mkdir -p ~/vault-deploy/config
cd ~/vault-deploy

# Check if domain was provided
DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
    echo "=========================================================="
    echo "Enter your domain for free automated HTTPS (e.g. heidelai-vault.duckdns.org)"
    echo "Or press ENTER to use your Public IP with HTTP:"
    read -r DOMAIN
fi

if [ -n "$DOMAIN" ]; then
    export VAULT_DOMAIN="$DOMAIN"
    echo "VAULT_DOMAIN=$DOMAIN" > .env
else
    export VAULT_DOMAIN=":80"
    echo "VAULT_DOMAIN=:80" > .env
fi

echo ">>> [5/5] Launching Vault & Caddy..."
docker compose up -d

echo "Waiting 5 seconds for Vault to boot..."
sleep 5

echo "=========================================================="
echo "Initializing Vault..."
echo "=========================================================="
docker exec vault vault operator init -key-shares=5 -key-threshold=3 -format=json > ~/vault-keys.json

echo "=========================================================="
echo "CRITICAL: YOUR MASTER KEYS ARE SAVED AT ~/vault-keys.json"
echo "=========================================================="
cat ~/vault-keys.json | jq .

echo ""
echo ">>> Automatically unsealing Vault with 3 threshold keys..."
KEY1=$(jq -r '.unseal_keys_b64[0]' ~/vault-keys.json)
KEY2=$(jq -r '.unseal_keys_b64[1]' ~/vault-keys.json)
KEY3=$(jq -r '.unseal_keys_b64[2]' ~/vault-keys.json)
ROOT_TOKEN=$(jq -r '.root_token' ~/vault-keys.json)

docker exec vault vault operator unseal "$KEY1" > /dev/null
docker exec vault vault operator unseal "$KEY2" > /dev/null
docker exec vault vault operator unseal "$KEY3" > /dev/null

echo ">>> Enabling KV-v2 secrets engine..."
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault secrets enable -path=kv kv-v2

echo "=========================================================="
echo "SUCCESS! Vault is live and unsealed!"
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != ":80" ]; then
    echo "Public URL: https://$DOMAIN"
else
    echo "Public URL: http://$(curl -s ifconfig.me)"
fi
echo "Root Token: $ROOT_TOKEN"
echo "=========================================================="
