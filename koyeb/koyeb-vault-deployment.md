# Deploying Vault on Koyeb (Free, 24/7 with HTTPS & Persistent Storage)

This guide shows how to deploy your team's centralized HashiCorp Vault on Koyeb in under 5 minutes.

---

## 1. Prerequisites
- A free Koyeb account ([koyeb.com](https://www.koyeb.com))
- 1 persistent volume (included in Koyeb's Free/Starter tiers)

---

## 2. Step-by-Step Koyeb Service Creation

1. In the Koyeb dashboard, click **Create Service**.
2. Select **Docker** (not GitHub).
3. **Docker image**: `hashicorp/vault:latest`
4. **Volumes** (Crucial for persistence!):
   - Click **Add Volume** or **Create Volume**
   - Volume Name: `vault-data`
   - Size: `1 GB` (or minimum allowed)
   - Mount Path: `/vault/file`
5. **Ports & Routing**:
   - Internal Port: `8200`
   - Protocol: `HTTP` (Koyeb automatically provides the public `HTTPS` edge termination)
6. **Environment Variables**:
   - Click **Add Variable**
   - Name: `VAULT_LOCAL_CONFIG`
   - Value: Copy the single-line JSON from `vault-koyeb-config.json`:
     ```json
     {"storage": {"raft": {"path": "/vault/file", "node_id": "koyeb-vault-node"}}, "listener": {"tcp": {"address": "0.0.0.0:8200", "tls_disable": 1}}, "ui": true, "disable_mlock": true}
     ```
7. **Advanced Settings (Run Command Override)**:
   - Override Command: `server`
8. **Service Name**:
   - Give it a name like `heidelai-vault`
9. Click **Deploy**.

---

## 3. Initialize & Unseal

Once the status turns **Healthy**:
1. Copy the public Koyeb URL (e.g. `https://heidelai-vault-<your-org>.koyeb.app`).
2. On your local machine (PowerShell):
   ```powershell
   $env:VAULT_ADDR = "https://heidelai-vault-<your-org>.koyeb.app"

   # Initialize Vault (Generates your 5 Unseal Keys and 1 Initial Root Token)
   vault operator init
   ```
3. **SAVE** the 5 Unseal Keys and Root Token in a secure password manager (e.g. 1Password / Bitwarden).
4. Unseal it by running 3 times:
   ```powershell
   vault operator unseal
   # Paste Key 1

   vault operator unseal
   # Paste Key 2

   vault operator unseal
   # Paste Key 3
   ```
5. Log in as Root:
   ```powershell
   vault login
   # Paste Root Token
   ```
6. Enable the KV v2 secrets engine:
   ```powershell
   vault secrets enable -path=kv kv-v2
   ```

Vault is now live on the internet 24/7 with automated HTTPS and encrypted persistent storage!
