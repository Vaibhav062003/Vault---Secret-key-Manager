# Complete Guide: Hosting HashiCorp Vault on Oracle Cloud "Always Free" VM

This guide walks you through setting up a dedicated, 24/7 HashiCorp Vault instance on Oracle Cloud Infrastructure (OCI) completely free of charge.

---

## 🎯 Why Oracle Cloud Free Tier?

- **Cost**: $0.00 / month forever.
- **Storage**: Real, persistent hard drive (up to 200 GB Always Free).
- **No Sleep**: Never spins down or sleeps (unlike Render/Heroku free tiers).
- **Public IP**: Comes with a dedicated public IPv4 address.

---

## Step 1: Create Your Always Free VM in Oracle Cloud

1. Log in to your [Oracle Cloud Console](https://cloud.oracle.com/).
2. In the navigation menu (top left), click **Compute** -> **Instances**.
3. Click **Create Instance**.
4. Configure the instance:
   - **Name**: `heidelai-vault`
   - **Placement**: Keep default (e.g. `AD-1`).
   - **Image and shape**:
     - Image: **Canonical Ubuntu 22.04** or **Ubuntu 24.04 Minimal**
     - Shape: **VM.Standard.E2.1.Micro** (Always Free-eligible AMD) OR **VM.Standard.A1.Flex** (Always Free-eligible Ampere ARM)
   - **Networking**:
     - Virtual cloud network: Create new or select default
     - Assign a public IPv4 address: **Yes**
   - **Add SSH keys**:
     - Select **Generate a key pair for me**.
     - Click **Save Private Key** (saves a file like `ssh-key-vault.key`).
       *(Save this file in a safe folder on your PC, e.g. `C:\Users\uttam\.ssh\`)*.
   - **Boot volume**: Default (50 GB).
5. Click **Create**.
6. Wait 1–2 minutes until the status badge turns **Running**.
7. Note down your **Public IPv4 Address** (e.g. `140.238.xxx.xxx`).

---

## Step 2: Open Ports in Oracle Cloud Firewall (VCN Security List)

> ⚠️ **CRITICAL STEP**: Oracle Cloud blocks all incoming ports by default at the cloud network level. You must allow ports 80, 443, and 8200.

1. On your Instance Details page, click your **Subnet** link (under **Primary VNIC**).
2. Click the **Default Security List for your VCN**.
3. Under **Ingress Rules**, click **Add Ingress Rules**.
4. Add the following rule:
   - **Source Type**: `CIDR`
   - **Source CIDR**: `0.0.0.0/0`
   - **IP Protocol**: `TCP`
   - **Destination Port Range**: `80,443,8200`
   - **Description**: `Vault and Caddy HTTPS`
5. Click **Add Ingress Rules**.

---

## Step 3: (Optional but Recommended) Get a Free Domain via DuckDNS

To give your team a clean URL with free automatic SSL (e.g. `https://heidelai-vault.duckdns.org`):

1. Go to [duckdns.org](https://www.duckdns.org) and sign in with GitHub.
2. In the **sub domains** box, choose a domain name (e.g. `heidelai-vault`).
3. In the **current ip** box, paste your Oracle VM's **Public IP address**.
4. Click **add domain**.
5. Your domain `heidelai-vault.duckdns.org` now points to your Oracle VM!

---

## Step 4: Connect to Your VM via SSH

Open **PowerShell** on your Windows laptop:

```powershell
# If your SSH key was downloaded to Downloads:
ssh -i "C:\Users\uttam\Downloads\ssh-key-vault.key" ubuntu@<YOUR_ORACLE_PUBLIC_IP>
```

*(If you get a permissions warning on Windows for the key file, run:)*
```powershell
icacls "C:\Users\uttam\Downloads\ssh-key-vault.key" /inheritance:r
icacls "C:\Users\uttam\Downloads\ssh-key-vault.key" /grant:r "$($env:USERNAME):(R)"
```

---

## Step 5: Run the 1-Command Vault Setup

Once connected inside the Ubuntu terminal, run:

```bash
# Clone or create directory
mkdir -p ~/vault-deploy/config
cd ~/vault-deploy

# Download the setup script and configs
curl -fsSL https://raw.githubusercontent.com/hashicorp/vault/main/README.md > /dev/null 2>&1 || true
```

Or simply copy-paste these 3 files into `~/vault-deploy/`:

### 1. `config/vault.hcl`
```bash
cat << 'EOF' > ~/vault-deploy/config/vault.hcl
storage "raft" {
  path    = "/vault/file"
  node_id = "oracle-vault-1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr      = "http://127.0.0.1:8200"
cluster_addr  = "http://127.0.0.1:8201"
ui            = true
disable_mlock = true
EOF
```

### 2. `Caddyfile`
```bash
cat << 'EOF' > ~/vault-deploy/Caddyfile
{$VAULT_DOMAIN:localhost} {
    reverse_proxy vault:8200
}
EOF
```

### 3. `docker-compose.yml`
```bash
cat << 'EOF' > ~/vault-deploy/docker-compose.yml
version: '3.8'

services:
  vault:
    image: hashicorp/vault:latest
    container_name: vault
    restart: always
    environment:
      - VAULT_ADDR=http://127.0.0.1:8200
      - VAULT_API_ADDR=http://127.0.0.1:8200
    volumes:
      - ./config/vault.hcl:/vault/config/vault.hcl:ro
      - vault_data:/vault/file
    ports:
      - "127.0.0.1:8200:8200"
    command: server
    cap_add:
      - IPC_LOCK

  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - vault

volumes:
  vault_data:
  caddy_data:
  caddy_config:
EOF
```

### 4. Execute Installation
```bash
# Open OS firewall
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 8200 -j ACCEPT

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
sudo apt-get install -y docker-compose-plugin jq

# Set your DuckDNS domain (or leave blank to use HTTP on IP)
export VAULT_DOMAIN="heidelai-vault.duckdns.org"
echo "VAULT_DOMAIN=heidelai-vault.duckdns.org" > .env

# Start containers
sudo docker compose up -d
sleep 5

# Initialize Vault
sudo docker exec vault vault operator init -key-shares=5 -key-threshold=3 -format=json > ~/vault-keys.json
cat ~/vault-keys.json | jq .

# Unseal Vault automatically
KEY1=$(jq -r '.unseal_keys_b64[0]' ~/vault-keys.json)
KEY2=$(jq -r '.unseal_keys_b64[1]' ~/vault-keys.json)
KEY3=$(jq -r '.unseal_keys_b64[2]' ~/vault-keys.json)
ROOT_TOKEN=$(jq -r '.root_token' ~/vault-keys.json)

sudo docker exec vault vault operator unseal "$KEY1"
sudo docker exec vault vault operator unseal "$KEY2"
sudo docker exec vault vault operator unseal "$KEY3"

# Enable KV v2
sudo docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault secrets enable -path=kv kv-v2
```

---

## Step 6: Connect from Your Local Laptop

Now, from your local Windows PowerShell:

1. **Verify Connection**:
   ```powershell
   $env:VAULT_ADDR = "https://heidelai-vault.duckdns.org"
   vault status
   ```
   *Output will show `Sealed: false`!*

2. **Push your current `.env` secrets into Vault**:
   ```powershell
   cd d:\canned\vault
   python scripts\push-env-to-vault.py --env-file "d:\canned\heidelAI-Backend-main\.env" --path "dev/heidelai-backend" --vault-url "https://heidelai-vault.duckdns.org" --vault-token "<YOUR_ROOT_TOKEN>"
   ```

3. **Configure GitHub Auth for the 5 developers**:
   ```powershell
   .\scripts\setup-github-auth.ps1 -Organization "YOUR_GITHUB_ORG" -Team "developers" -VaultAddr "https://heidelai-vault.duckdns.org"
   ```

4. **Your team can now log in and run with zero `.env` files**:
   ```powershell
   vault login -method=github
   cd d:\canned\heidelAI-Backend-main
   uvicorn main:app --reload
   ```
