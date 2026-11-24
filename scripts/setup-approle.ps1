# ========================================================
# Setup AppRole Authentication (For Koyeb Backend & CI/CD)
# ========================================================
[CmdletBinding()]
param (
    [string]$RoleName = "heidelai-backend-prod",
    [string]$Policy = "prod-policy",
    [string]$VaultAddr = $env:VAULT_ADDR
)

if (-not $VaultAddr) {
    $VaultAddr = "http://127.0.0.1:8200"
}

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "       Vault AppRole Setup for Production        " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "Vault Address: $VaultAddr"
Write-Host "Role Name: $RoleName"

$env:VAULT_ADDR = $VaultAddr

# 1. Enable AppRole
Write-Host "`n[1/4] Enabling AppRole auth engine..." -ForegroundColor Yellow
vault auth enable approle 2>$null

# 2. Write AppRole definition
Write-Host "[2/4] Creating AppRole '$RoleName' with policy '$Policy'..." -ForegroundColor Yellow
vault write auth/approle/role/$RoleName `
    token_policies="$Policy" `
    token_ttl=24h `
    token_max_ttl=720h `
    secret_id_num_uses=0 `
    secret_id_ttl=0

# 3. Retrieve Role ID
Write-Host "[3/4] Fetching Role ID..." -ForegroundColor Yellow
$roleId = vault read -field=role_id auth/approle/role/$RoleName/role-id

# 4. Generate Secret ID
Write-Host "[4/4] Generating Secret ID..." -ForegroundColor Yellow
$secretId = vault write -f -field=secret_id auth/approle/role/$RoleName/secret-id

Write-Host "`n=================================================" -ForegroundColor Green
Write-Host "SUCCESS: AppRole created for Production!" -ForegroundColor Green
Write-Host "Add these 3 environment variables in your Koyeb Backend service:" -ForegroundColor Yellow
Write-Host "  VAULT_ADDR       = $VaultAddr" -ForegroundColor Cyan
Write-Host "  VAULT_ROLE_ID    = $roleId" -ForegroundColor Cyan
Write-Host "  VAULT_SECRET_ID  = $secretId" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Green
