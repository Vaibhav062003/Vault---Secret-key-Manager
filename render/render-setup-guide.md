# Complete Guide: Deploying HashiCorp Vault on Render

There are two ways to deploy Vault on Render:
1. **Method A (100% Free)**: Render Free Web Service + Free Neon.tech PostgreSQL database.
2. **Method B ($7/month)**: Render Starter Web Service with a Persistent Disk.

---

## Method A: 100% Free Deployment (Postgres Storage Backend)

Render's Free Web Service tier wipes its disk on every restart, but HashiCorp Vault supports storing all encrypted data in a PostgreSQL database.

### Step 1: Create a Free PostgreSQL Database (Takes 30 seconds)
1. Go to [neon.tech](https://neon.tech) and create a free account.
2. Create a new project named `heidelai-vault-db`.
3. Copy your **PostgreSQL Connection String**. It looks like:
   `postgres://user:password@ep-xyz.aws.neon.tech/neondb?sslmode=require`

### Step 2: Initialize the Vault PostgreSQL Table
In your Neon dashboard, open the **SQL Editor** and run:
```sql
CREATE TABLE IF NOT EXISTS vault_kv_store (
  parent_path TEXT COLLATE "C" NOT NULL,
  path        TEXT COLLATE "C",
  key         TEXT COLLATE "C",
  value       BYTEA,
  CONSTRAINT vault_kv_store_pkey PRIMARY KEY (parent_path, path, key)
);

CREATE INDEX IF NOT EXISTS parent_path_idx ON vault_kv_store (parent_path);
```

### Step 3: Deploy on Render
1. In Render Dashboard, click **New +** -> **Web Service**.
2. Connect your Git repository (or push the `vault/render` folder to GitHub).
3. **Environment**: `Docker` (Render will build `vault/render/Dockerfile`).
4. **Instance Type**: Select **Free**.
5. **Environment Variables**:
   - Add `DATABASE_URL`: Paste your Neon connection string.
6. Click **Create Web Service**.
7. Render will provide a free public HTTPS URL: `https://<service-name>.onrender.com`.

### Step 4: Prevent Render Free Tier from Sleeping
Render free services sleep after 15 minutes of inactivity. When it sleeps, Vault locks.
To keep it awake 24/7 for free:
1. Go to [uptimerobot.com](https://uptimerobot.com) (free).
2. Add a new HTTP monitor pointing to:
   `https://<service-name>.onrender.com/v1/sys/health`
3. Interval: `5 minutes` or `10 minutes`.
*This keeps your Render service running 24/7 for free!*

---

## Method B: Paid Render Deployment ($7/month with Persistent Disk)

If your company doesn't want an external database:

1. In Render Dashboard, click **New +** -> **Web Service**.
2. Select **Existing Image** and enter:
   `hashicorp/vault:latest`
3. **Instance Type**: Select **Starter** ($7/mo).
4. **Disk**:
   - Click **Add Disk**
   - Name: `vault-data`
   - Size: `1 GB`
   - Mount Path: `/vault/file`
5. **Environment Variables**:
   - Add `VAULT_LOCAL_CONFIG`:
     ```json
     {"storage": {"raft": {"path": "/vault/file", "node_id": "render-node"}}, "listener": {"tcp": {"address": "0.0.0.0:8200", "tls_disable": 1}}, "ui": true, "disable_mlock": true}
     ```
6. **Docker Command**: `server`
7. Click **Create Web Service**.
