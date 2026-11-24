# ========================================================
# Production AppRole Policy: Read-Only Access to Production Secrets
# ========================================================

# Allow Koyeb production backend to read its secrets
path "kv/data/prod/heidelai-backend" {
  capabilities = ["read"]
}

path "kv/metadata/prod/heidelai-backend" {
  capabilities = ["read", "list"]
}

# Allow AppRole token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
