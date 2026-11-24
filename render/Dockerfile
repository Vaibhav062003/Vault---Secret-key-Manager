FROM hashicorp/vault:latest

EXPOSE 8200

# Bypass docker-entrypoint.sh (which fails on Render due to setcap/IPC_LOCK restrictions)
ENTRYPOINT []

# Create config directory, write VAULT_LOCAL_CONFIG if present, and start vault server
CMD ["sh", "-c", "mkdir -p /vault/config && if [ -n \"$VAULT_LOCAL_CONFIG\" ]; then echo \"$VAULT_LOCAL_CONFIG\" > /vault/config/local.json; fi && exec vault server -config=/vault/config"]
