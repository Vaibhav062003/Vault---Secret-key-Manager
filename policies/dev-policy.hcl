# ========================================================
# Developer Policy: Read-Only Access to Development Secrets
# ========================================================

# Allow reading dev backend secrets
path "kv/data/dev/heidelai-backend" {
  capabilities = ["read"]
}

# Allow reading any dev secrets under dev/*
path "kv/data/dev/*" {
  capabilities = ["read", "list"]
}

# Allow listing secret keys under dev
path "kv/metadata/dev/*" {
  capabilities = ["list", "read"]
}

# Allow reading own token info and renewing session
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
