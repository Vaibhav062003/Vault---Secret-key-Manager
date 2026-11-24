# ========================================================
# Developer Fast Login Script
# ========================================================
[CmdletBinding()]
param (
    [string]$VaultAddr = $env:VAULT_ADDR,
    [ValidateSet("github", "token", "userpass")]
    [string]$Method = "github"
)

if (-not $VaultAddr) {
    # If environment variable is not set, default to local Vault or ask
    $VaultAddr = "http://127.0.0.1:8200"
}

$env:VAULT_ADDR = $VaultAddr
[System.Environment]::SetEnvironmentVariable('VAULT_ADDR', $VaultAddr, 'User')

Write-Host "Connecting to Vault at: $VaultAddr" -ForegroundColor Cyan

if ($Method -eq "github") {
    Write-Host "Logging in with GitHub credentials..." -ForegroundColor Yellow
    vault login -method=github
} elseif ($Method -eq "token") {
    $token = Read-Host "Enter your Vault Token"
    vault login $token
} else {
    vault login -method=userpass
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nSuccessfully authenticated with Vault!" -ForegroundColor Green
    Write-Host "Your token is saved to ~/.vault-token" -ForegroundColor Gray
    Write-Host "You can now run your backend immediately without any .env files:" -ForegroundColor Yellow
    Write-Host "  uvicorn main:app --reload" -ForegroundColor Green
}
