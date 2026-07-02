[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RustDeskExe,

    [string]$PolicyPath,
    [switch]$AllowPlaceholders
)

$ErrorActionPreference = 'Stop'

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if ([string]::IsNullOrWhiteSpace($PolicyPath)) {
    $PolicyPath = Join-Path $ScriptDir '..\config\antreva-client-policy.json'
}

& (Join-Path $ScriptDir 'Validate-AntrevaRemote.ps1') -PolicyPath $PolicyPath -AllowPlaceholders:$AllowPlaceholders

if (-not (Test-Path -LiteralPath $RustDeskExe)) {
    throw "RustDesk executable not found: $RustDeskExe"
}

$policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
$options = $policy.rustdeskOptions

foreach ($property in $options.PSObject.Properties) {
    $name = $property.Name
    $value = [string]$property.Value
    Write-Output "Applying RustDesk option: $name"
    & $RustDeskExe --option $name $value
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Failed to apply RustDesk option '$name' with exit code $LASTEXITCODE."
    }
}

Write-Output "Antreva Remote client policy applied."
