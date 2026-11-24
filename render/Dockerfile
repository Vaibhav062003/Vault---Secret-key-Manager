FROM hashicorp/vault:latest

COPY config/vault-postgres.hcl /vault/config/vault.hcl

EXPOSE 8200

CMD ["server"]
