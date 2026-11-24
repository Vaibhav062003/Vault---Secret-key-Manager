FROM hashicorp/vault:latest

# Remove default/conflicting config files so Vault cleanly loads VAULT_LOCAL_CONFIG
RUN rm -rf /vault/config/*

EXPOSE 8200

CMD ["server"]
