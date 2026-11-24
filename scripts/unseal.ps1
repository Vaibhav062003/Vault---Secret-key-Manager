# ========================================================
# One-Click Vault Unseal Script (For Windows PowerShell)
# ========================================================
[CmdletBinding()]
param (
    [string]$ContainerName = "heidelai-vault",
    [string]$VaultAddr = "http://127.0.0.1:8200"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VaultRootDir = Split-Path -Parent $ScriptDir
$CredsFile = Join-Path $VaultRootDir ".vault-credentials.json"

Write-Host "Checking Vault status on $VaultAddr..." -ForegroundColor Cyan

if (Test-Path $CredsFile) {
    $creds = Get-Content $CredsFile -Raw | ConvertFrom-Json
    if ($creds.unseal_keys_b64) {
        Write-Host "Using keys from $CredsFile to unseal..." -ForegroundColor Yellow
        for ($i = 0; $i -lt 3; $i++) {
            $key = $creds.unseal_keys_b64[$i]
            docker exec -e VAULT_ADDR=$VaultAddr $ContainerName vault operator unseal $key | Out-Null
        }
        Write-Host "Vault unsealed successfully!" -ForegroundColor Green
        exit 0
    }
}

Write-Host "Credentials file not found or empty. Please enter 3 unseal keys manually:" -ForegroundColor Yellow
for ($i = 1; $i -le 3; $i++) {
    $key = Read-Host "Enter Unseal Key $i"
    if ($key) {
        docker exec -e VAULT_ADDR=$VaultAddr $ContainerName vault operator unseal $key
    }
}
