[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CertificateThumbprint,

    [string]$PolicyPath,
    [string]$RustDeskDir,
    [string]$ArtifactsDir
)

$ErrorActionPreference = 'Stop'

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if ([string]::IsNullOrWhiteSpace($PolicyPath)) {
    $PolicyPath = Join-Path $ScriptDir '..\config\antreva-client-policy.json'
}
if ([string]::IsNullOrWhiteSpace($RustDeskDir)) {
    $RustDeskDir = Join-Path $ScriptDir '..\upstream\rustdesk'
}
if ([string]::IsNullOrWhiteSpace($ArtifactsDir)) {
    $ArtifactsDir = Join-Path $ScriptDir '..\artifacts'
}

& (Join-Path $ScriptDir 'Validate-AntrevaRemote.ps1') -PolicyPath $PolicyPath

if (-not (Test-Path -LiteralPath (Join-Path $RustDeskDir 'Cargo.toml'))) {
    throw "RustDesk source not found at $RustDeskDir. Run git submodule update --init --recursive."
}

if (-not (Get-Command signtool.exe -ErrorAction SilentlyContinue)) {
    throw "signtool.exe was not found on PATH. Install Windows SDK or run from a Developer PowerShell."
}

New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null

Write-Output "Policy validated. Build RustDesk Windows artifacts from $RustDeskDir using upstream Windows build prerequisites."
Write-Output "After binaries are produced, sign them with:"
Write-Output "signtool.exe sign /sha1 $CertificateThumbprint /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 <binary>"
Write-Output "Place signed Antreva Remote artifacts in $ArtifactsDir."
