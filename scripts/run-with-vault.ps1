# ========================================================
# Run any command with in-memory secrets from Vault
# Zero files are written to disk.
# ========================================================
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, Position=0)]
    [string]$SecretPath,

    [Parameter(Mandatory=$true, Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Command
)

$vaultAddr = ($env:VAULT_ADDR -replace '/$', '')
if (-not $vaultAddr) {
    $vaultAddr = "http://127.0.0.1:8200"
}

# 1. Discover Token
$token = $env:VAULT_TOKEN
if (-not $token) {
    $tokenPath = Join-Path $env:USERPROFILE ".vault-token"
    if (Test-Path $tokenPath) {
        $token = (Get-Content $tokenPath -Raw).Trim()
    }
}

if (-not $token) {
    Write-Host "[VaultRunner] Error: No Vault token found. Please run 'vault login' or './dev-login.ps1' first." -ForegroundColor Red
    exit 1
}

# 2. Fetch secrets from Vault KV v2 API
$mount = if ($env:VAULT_MOUNT) { $env:VAULT_MOUNT } else { "kv" }
$url = "$vaultAddr/v1/$mount/data/$SecretPath"

Write-Host "[VaultRunner] Fetching secrets from $url..." -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Uri $url -Headers @{ "X-Vault-Token" = $token } -Method Get
    $secrets = $response.data.data
} catch {
    Write-Host "[VaultRunner] Failed to fetch secrets from Vault: $_" -ForegroundColor Red
    exit 1
}

$keyCount = ($secrets.PSObject.Properties | Measure-Object).Count
Write-Host "[VaultRunner] Loaded $keyCount secrets into process memory." -ForegroundColor Green

# 3. Inject secrets into current session environment
foreach ($prop in $secrets.PSObject.Properties) {
    [System.Environment]::SetEnvironmentVariable($prop.Name, [string]$prop.Value, 'Process')
}

$cmdString = $Command -join " "
Write-Host "[VaultRunner] Spawning: $cmdString`n" -ForegroundColor Yellow

# 4. Execute target command
Invoke-Expression $cmdString
