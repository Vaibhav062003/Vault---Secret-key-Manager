FROM hashicorp/vault:latest

EXPOSE 8200

# Remove docker-entrypoint to bypass unprivileged setcap restrictions
ENTRYPOINT []

# Self-contained startup: writes VAULT_LOCAL_CONFIG to /tmp/vault.json and executes vault server
CMD ["sh", "-c", "echo \"$VAULT_LOCAL_CONFIG\" > /tmp/vault.json && echo '=== Vault Configuration ===' && cat /tmp/vault.json && echo '===========================' && exec vault server -config=/tmp/vault.json"]
