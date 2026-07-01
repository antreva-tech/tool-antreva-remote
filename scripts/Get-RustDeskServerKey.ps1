[CmdletBinding()]
param(
    [string]$OfficeServerDir
)

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if ([string]::IsNullOrWhiteSpace($OfficeServerDir)) {
    $OfficeServerDir = Join-Path $ScriptDir '..\infra\office-server'
}

$dataDir = Join-Path $OfficeServerDir 'data'
$keyPath = Join-Path $dataDir 'id_ed25519.pub'

if (-not (Test-Path -LiteralPath $keyPath)) {
    Write-Error "RustDesk public key not found at $keyPath. Start the office server first with docker compose up -d."
    exit 1
}

$key = (Get-Content -LiteralPath $keyPath -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($key)) {
    Write-Error "RustDesk public key file is empty: $keyPath"
    exit 1
}

Write-Output $key
