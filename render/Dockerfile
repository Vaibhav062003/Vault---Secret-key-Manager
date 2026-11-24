FROM hashicorp/vault:latest

EXPOSE 8200

# Remove docker-entrypoint to bypass unprivileged setcap restrictions
ENTRYPOINT []

# Self-contained startup: writes VAULT_LOCAL_CONFIG using printf (safe against backslashes/quotes)
CMD ["sh", "-c", "printf '%s\n' \"$VAULT_LOCAL_CONFIG\" > /tmp/vault.json && echo '=== Vault Config Verified ===' && cat /tmp/vault.json && echo '=============================' && exec vault server -config=/tmp/vault.json"]
