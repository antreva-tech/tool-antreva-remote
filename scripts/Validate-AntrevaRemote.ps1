[CmdletBinding()]
param(
    [string]$PolicyPath,
    [switch]$AllowPlaceholders
)

$ErrorActionPreference = 'Stop'

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if ([string]::IsNullOrWhiteSpace($PolicyPath)) {
    $PolicyPath = Join-Path $ScriptDir '..\config\antreva-client-policy.json'
}

if (-not (Test-Path -LiteralPath $PolicyPath)) {
    throw "Policy file not found: $PolicyPath"
}

$policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
$options = $policy.rustdeskOptions
$errors = New-Object System.Collections.Generic.List[string]

function Assert-Equal {
    param([string]$Name, [string]$Actual, [string]$Expected)
    if ($Actual -ne $Expected) {
        $script:errors.Add("$Name must be '$Expected' but was '$Actual'.")
    }
}

if ($policy.productName -ne 'Antreva Remote') {
    $errors.Add("productName must be 'Antreva Remote'.")
}

if (-not $AllowPlaceholders -and $options.'custom-rendezvous-server' -eq 'remote.antreva.example') {
    $errors.Add("custom-rendezvous-server still uses the example hostname.")
}

if (-not $AllowPlaceholders -and $options.key -eq 'REPLACE_WITH_OFFICE_RUSTDESK_PUBLIC_KEY') {
    $errors.Add("key still uses the placeholder public key.")
}

Assert-Equal 'enable-file-transfer' $options.'enable-file-transfer' 'Y'
Assert-Equal 'enable-file-copy-paste' $options.'enable-file-copy-paste' 'Y'
Assert-Equal 'one-way-file-transfer' $options.'one-way-file-transfer' 'N'
Assert-Equal 'enable-terminal' $options.'enable-terminal' 'N'
Assert-Equal 'enable-tunnel' $options.'enable-tunnel' 'N'
Assert-Equal 'enable-privacy-mode' $options.'enable-privacy-mode' 'N'
Assert-Equal 'allow-remote-config-modification' $options.'allow-remote-config-modification' 'N'
Assert-Equal 'hide-tray' $options.'hide-tray' 'N'
Assert-Equal 'disable-change-permanent-password' $options.'disable-change-permanent-password' 'Y'

if ($policy.releaseGates.allowsUnattendedAccess -ne $false) {
    $errors.Add("releaseGates.allowsUnattendedAccess must be false.")
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "Antreva Remote policy validation passed."
