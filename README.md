# HeidelAI HashiCorp Vault — Zero-.env Enterprise Secret Management

This repository contains the complete production-grade configuration, automation scripts, access policies, and application integrations for **HashiCorp Vault**.

---

## 🎯 The Core Goal: Protect Secrets on Developer Workstations (Zero .env Files)

- **The Threat We Are Solving**:
  Currently, 5 team members have `.env` files containing company API keys sitting on their personal laptops. If any team member leaves the organization, they still have those keys on their hard drive.
- **The Solution**:
  1. Developers **never** store a `.env` file on disk.
  2. Developers authenticate to Vault via GitHub (`vault login -method=github`) in VS Code.
  3. When running the backend (`uvicorn`) or frontend (`npm run dev`), Vault streams development secrets **directly into RAM (memory)**.
  4. The moment a developer leaves your company, you revoke their GitHub access. Their local codebase instantly stops working, and they have zero secrets on their laptop!
  5. When you rotate a key, you change it in Vault once. All developers automatically get the new key on their next app boot.
- **Production (Koyeb & Vercel) Remains Untouched**:
  Koyeb and Vercel continue using their native dashboard environment variables as normal. Vault is strictly scoped to securing developer machines in VS Code.

---

## 📁 Repository Structure (`d:\canned\vault`)

```text
d:\canned\vault\
├── docker-compose.yml              # Single-node Raft Vault (fast, persistent local dev)
├── docker-compose.ha.yml           # 3-node HA Raft cluster (for HA testing)
├── .gitignore                      # Prevents committing tokens, credentials, or keys
├── config/
│   ├── vault-standalone.hcl        # Local standalone server configuration
│   ├── vault1.hcl                  # HA Node 1 config
│   ├── vault2.hcl                  # HA Node 2 config
│   └── vault3.hcl                  # HA Node 3 config
├── policies/
│   ├── dev-policy.hcl              # Developer policy: read secrets from dev/heidelai-backend
│   ├── prod-policy.hcl             # Production policy: read secrets from prod/heidelai-backend
│   └── admin-policy.hcl            # Admin policy: full cluster management
├── scripts/
│   ├── init-cluster.ps1            # 1-Click initialization & unseal for local Docker
│   ├── unseal.ps1                  # 1-Click unseal when Docker or workstation restarts
│   ├── dev-login.ps1               # Quick login helper for developers (GitHub or token)
│   ├── push-env-to-vault.py        # Migrates existing .env keys into Vault KV in memory
│   ├── setup-github-auth.ps1       # Binds Vault to your GitHub Organization & teams
│   ├── setup-approle.ps1           # Creates AppRole credentials for Koyeb production
│   ├── run-with-vault.ps1          # Spawns any command (e.g. Next.js) with in-memory secrets
│   └── run-with-vault.mjs          # Cross-platform Node.js runner with in-memory secrets
└── koyeb/
    ├── koyeb-vault-deployment.md   # Step-by-step guide to hosting Vault on Koyeb (Free tier)
    └── vault-koyeb-config.json     # Pre-configured JSON for Koyeb VAULT_LOCAL_CONFIG
```

---

## 🚀 Part 1: Quick Start (Local Development)

### 1. Boot & Initialize the Local Vault
Ensure Docker Desktop is running, open PowerShell, and run:
```powershell
cd d:\canned\vault
.\scripts\init-cluster.ps1
```
This script automatically:
1. Starts the Vault container with a persistent Raft storage volume.
2. Initializes the cluster (saving master unseal keys to `.vault-credentials.json` — gitignored).
3. Unseals the vault with 3 threshold keys.
4. Enables the `kv-v2` secrets engine at path `kv/`.
5. Applies the `dev-policy` and `prod-policy`.
6. Opens the Vault Web UI at `http://127.0.0.1:8200`.

### 2. Push Your Existing Secrets into Vault
To populate Vault with your current secrets without manual typing:
```powershell
python scripts\push-env-to-vault.py --env-file "d:\canned\heidelAI-Backend-main\.env" --path "dev/heidelai-backend"
```
*Once done, you can delete or archive the `.env` file!*

---

## 💻 Part 2: Daily Developer Workflow (Zero `.env`)

### Step 1: Login in the Morning (One Command)
When a developer begins work:
```powershell
cd d:\canned\vault
.\scripts\dev-login.ps1
```
*Or directly via Vault CLI:*
```powershell
$env:VAULT_ADDR = "https://your-koyeb-vault.koyeb.app"   # or http://127.0.0.1:8200 locally
vault login -method=github
```
Vault writes a temporary session token to `~/.vault-token` on their computer.

### Step 2: Run the Backend
Because `d:\canned\heidelAI-Backend-main\config\settings.py` includes `vault_loader.py`, the backend automatically detects `~/.vault-token` and pulls secrets into memory:
```powershell
cd d:\canned\heidelAI-Backend-main
uvicorn main:app --reload
```
**No `.env` file exists on disk. No secrets in Git.**

### Step 3: Run the Frontend (Next.js)
To run the frontend with in-memory secrets:
```powershell
cd d:\canned\heidelAI-Frontend-main
node ..\vault\scripts\run-with-vault.mjs dev/heidelai-frontend npm run dev
```
*(Or in PowerShell: `..\vault\scripts\run-with-vault.ps1 dev/heidelai-frontend npm run dev`)*

---

## ☁️ Part 3: Hosting Vault on Koyeb (Free 24/7 Team Server)

To give the whole team 24/7 access to Vault without hosting on personal laptops:

1. **Create Service on Koyeb**:
   - Type: **Docker**
   - Image: `hashicorp/vault:latest`
2. **Add Persistent Volume (Critical)**:
   - Volume Name: `vault-data`
   - Size: `1 GB`
   - Mount Path: `/vault/file`
3. **Internal Port**: `8200` (Koyeb handles public HTTPS automatically).
4. **Environment Variable**:
   - Name: `VAULT_LOCAL_CONFIG`
   - Value:
     ```json
     {"storage": {"raft": {"path": "/vault/file", "node_id": "koyeb-vault-node"}}, "listener": {"tcp": {"address": "0.0.0.0:8200", "tls_disable": 1}}, "ui": true, "disable_mlock": true}
     ```
5. **Run Command Override**: `server`
6. Click **Deploy**.

Detailed instructions are available in [koyeb/koyeb-vault-deployment.md](koyeb/koyeb-vault-deployment.md).

---

## 👥 Part 4: Connecting Vault to Your GitHub Organization

To allow team members to log in with GitHub:

1. Open PowerShell and set your Vault address:
   ```powershell
   $env:VAULT_ADDR = "https://your-koyeb-vault.koyeb.app"
   vault login  # Log in with your Root Token
   ```
2. Run the automated GitHub setup script:
   ```powershell
   .\scripts\setup-github-auth.ps1 -Organization "YOUR_GITHUB_ORG" -Team "developers" -Policy "dev-policy"
   ```
3. Team members can now authenticate using:
   ```powershell
   vault login -method=github
   ```
   *(When prompted, they enter a GitHub Personal Access Token with `read:org` permission).*

---

## 🔒 Part 5: Production Setup (Koyeb Backend & Vercel Frontend)

### 1. Koyeb Backend (AppRole)
Servers cannot complete interactive logins, so they use **AppRole**:

1. Generate AppRole credentials:
   ```powershell
   .\scripts\setup-approle.ps1 -RoleName "heidelai-backend-prod" -Policy "prod-policy"
   ```
2. Copy the resulting `role_id` and `secret_id`.
3. In your **Koyeb Backend Service** -> **Environment Variables**, add only these 3 variables:
   - `VAULT_ADDR` = `https://your-koyeb-vault.koyeb.app`
   - `VAULT_ROLE_ID` = `<your-role-id>`
   - `VAULT_SECRET_ID` = `<your-secret-id>`
   - `ENVIRONMENT` = `production`

`vault_loader.py` detects `VAULT_ROLE_ID` and `VAULT_SECRET_ID`, authenticates via AppRole, and loads the production secrets directly into memory.

### 2. Vercel Frontend
Frontends require environment variables baked into the client bundle at build time.
- **Option A (GitHub Actions / CI)**: Fetch secrets from Vault in a GitHub Actions workflow and push them to Vercel via `vercel env pull` or `vercel build`.
- **Option B (Vercel Project Settings)**: Store production values in Vercel's encrypted environment variables dashboard once.

---

## 🛠️ Troubleshooting & Routine Operations

| Issue | Cause | Fix |
|---|---|---|
| `connection refused` or `connectex` | Vault container or service is stopped | Run `docker compose up -d` or check Koyeb service status |
| `Vault is sealed` | Vault restarted (standard security lockdown) | Run `.\scripts\unseal.ps1` (local) or `vault operator unseal` 3 times |
| `permission denied` | Token does not have rights to the path | Verify the user belongs to the GitHub team mapped to `dev-policy` |
| `No module named hvac` | Python package missing in virtualenv | Run `pip install hvac` or `poetry install` |
| Old `.env` values taking precedence | Existing OS environment variables | Clear shell variables or restart the terminal window |
#   V a u l t - - - S e c r e t - k e y - M a n a g e r  
 