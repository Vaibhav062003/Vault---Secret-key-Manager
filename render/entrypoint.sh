#!/bin/sh
set -e

CONFIG_FILE="/tmp/vault-config.json"

# Check if VAULT_LOCAL_CONFIG is set
if [ -n "$VAULT_LOCAL_CONFIG" ]; then
    echo "Found VAULT_LOCAL_CONFIG environment variable."
    echo "$VAULT_LOCAL_CONFIG" > "$CONFIG_FILE"
elif [ -n "$DATABASE_URL" ] || [ -n "$VAULT_PG_CONNECTION_URL" ]; then
    DB_URL="${VAULT_PG_CONNECTION_URL:-$DATABASE_URL}"
    echo "Constructing Vault config from Database URL..."
    cat << EOF > "$CONFIG_FILE"
{
  "storage": {
    "postgresql": {
      "connection_url": "$DB_URL",
      "table": "vault_kv_store"
    }
  },
  "listener": {
    "tcp": {
      "address": "0.0.0.0:8200",
      "tls_disable": 1
    }
  },
  "ui": true,
  "disable_mlock": true
}
EOF
else
    echo "FATAL ERROR: No Vault configuration found!"
    echo "Please set either VAULT_LOCAL_CONFIG or DATABASE_URL in Render Environment Variables."
    exit 1
fi

echo "=== Vault Config Loaded Successfully ==="
echo "Starting Vault Server on port 8200..."

exec vault server -config="$CONFIG_FILE"
