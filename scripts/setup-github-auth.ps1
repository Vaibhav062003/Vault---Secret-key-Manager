# ========================================================
# Setup GitHub Team & Organization Authentication in Vault
# ========================================================
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$Organization,

    [string]$Team = "developers",
    [string]$Policy = "dev-policy",
    [string]$VaultAddr = $env:VAULT_ADDR
)

if (-not $VaultAddr) {
    $VaultAddr = "http://127.0.0.1:8200"
}

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "     Vault GitHub Authentication Setup          " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "Vault Address: $VaultAddr"
Write-Host "GitHub Organization: $Organization"
Write-Host "GitHub Team: $Team -> Policy: $Policy"

$env:VAULT_ADDR = $VaultAddr

# 1. Enable native GitHub auth method
Write-Host "`n[1/3] Enabling GitHub auth engine..." -ForegroundColor Yellow
vault auth enable github 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "GitHub auth method already enabled or configured." -ForegroundColor Gray
}

# 2. Configure GitHub Organization
Write-Host "[2/3] Binding Vault to GitHub Organization: $Organization..." -ForegroundColor Yellow
vault write auth/github/config organization="$Organization"

# 3. Map GitHub Team or Users to Dev Policy
Write-Host "[3/3] Mapping team '$Team' to policy '$Policy'..." -ForegroundColor Yellow
vault write auth/github/map-teams/$Team value="$Policy"

Write-Host "`n=================================================" -ForegroundColor Green
Write-Host "SUCCESS: GitHub Auth is configured!" -ForegroundColor Green
Write-Host "Any member of '$Organization/$Team' can now log in using:" -ForegroundColor Yellow
Write-Host "  vault login -method=github" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Green
