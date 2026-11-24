# ========================================================
# One-Click Vault Local Initialization & Setup Script
# ========================================================
[CmdletBinding()]
param (
    [string]$ContainerName = "heidelai-vault",
    [string]$VaultAddr = "http://127.0.0.1:8200"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VaultRootDir = Split-Path -Parent $ScriptDir
$CredsFile = Join-Path $VaultRootDir ".vault-credentials.json"

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "       Vault Local Initialization Setup          " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# 1. Start Docker container if not running
Set-Location $VaultRootDir
Write-Host "[1/5] Starting Vault container with Docker Compose..." -ForegroundColor Yellow
docker compose up -d

Write-Host "Waiting 3 seconds for Vault service to be ready..." -ForegroundColor Gray
Start-Sleep -Seconds 3

# 2. Check Vault Status
$statusRaw = docker exec -e VAULT_ADDR=$VaultAddr $ContainerName vault status -format=json 2>&1
$isInit = $false
$isSealed = $true

if ($statusRaw -match '"initialized":\s*true') {
    $isInit = $true
}
if ($statusRaw -match '"sealed":\s*false') {
    $isSealed = $false
}

# 3. Initialize if needed
if (-not $isInit) {
    Write-Host "[2/5] Initializing Vault (creating master unseal keys and root token)..." -ForegroundColor Yellow
    $initJson = docker exec -e VAULT_ADDR=$VaultAddr $ContainerName vault operator init -key-shares=5 -key-threshold=3 -format=json
    
    # Save credentials securely
    $initJson | Out-File -FilePath $CredsFile -Encoding utf8
    Write-Host "Credentials saved to: $CredsFile (Do NOT commit to git!)" -ForegroundColor Green
    $creds = $initJson | ConvertFrom-Json
} else {
    Write-Host "[2/5] Vault is already initialized." -ForegroundColor Green
    if (Test-Path $CredsFile) {
        $creds = Get-Content $CredsFile -Raw | ConvertFrom-Json
    } else {
        Write-Host "Warning: $CredsFile not found. You will need to supply unseal keys manually if sealed." -ForegroundColor Magenta
    }
}

# 4. Unseal if needed
if ($isSealed) {
    Write-Host "[3/5] Unsealing Vault (submitting 3 threshold keys)..." -ForegroundColor Yellow
    if ($creds -and $creds.unseal_keys_b64) {
        for ($i = 0; $i -lt 3; $i++) {
            $key = $creds.unseal_keys_b64[$i]
            docker exec -e VAULT_ADDR=$VaultAddr $ContainerName vault operator unseal $key | Out-Null
        }
        Write-Host "Vault unsealed successfully!" -ForegroundColor Green
    } else {
        Write-Host "Please run scripts/unseal.ps1 to unseal manually." -ForegroundColor Yellow
    }
} else {
    Write-Host "[3/5] Vault is already unsealed." -ForegroundColor Green
}

# 5. Enable KV-v2 Secrets Engine and configure default dev secrets
if ($creds -and $creds.root_token) {
    Write-Host "[4/5] Logging in as Root and configuring KV-v2 engine..." -ForegroundColor Yellow
    docker exec -e VAULT_ADDR=$VaultAddr $ContainerName vault login $creds.root_token | Out-Null
    
    # Enable KV v2 (ignore if already enabled)
    docker exec -e VAULT_ADDR=$VaultAddr $ContainerName vault secrets enable -path=kv kv-v2 2>$null
    
    # Apply dev policy
    $policyPath = "/vault/policies/dev-policy.hcl"
    docker exec -e VAULT_ADDR=$VaultAddr -i $ContainerName vault policy write dev-policy - < "$VaultRootDir\policies\dev-policy.hcl" | Out-Null
    docker exec -e VAULT_ADDR=$VaultAddr -i $ContainerName vault policy write prod-policy - < "$VaultRootDir\policies\prod-policy.hcl" | Out-Null
    
    Write-Host "[5/5] Dev & Prod policies applied successfully." -ForegroundColor Green
}

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "Vault is ready at: $VaultAddr" -ForegroundColor Green
Write-Host "Web UI available at: http://127.0.0.1:8200" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan
