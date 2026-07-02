[CmdletBinding()]
param(
    [string]$PolicyPath,
    [string]$ArtifactsDir,
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = Resolve-Path (Join-Path $ScriptDir '..')

if ([string]::IsNullOrWhiteSpace($PolicyPath)) {
    $PolicyPath = Join-Path $Root 'config\antreva-client-policy.json'
}
if ([string]::IsNullOrWhiteSpace($ArtifactsDir)) {
    $ArtifactsDir = Join-Path $Root 'artifacts\pilot'
}
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $Root 'artifacts'
}

$Version = '1.4.8'
$FileName = "rustdesk-$Version-x86_64.exe"
$DownloadUrl = "https://github.com/rustdesk/rustdesk/releases/download/$Version/$FileName"
$ExpectedSha256 = 'f0053229fa2a2459c8b86f326c3e7423018a72f010f9758dc21be171b112d1b2'
$PortableExe = Join-Path $ArtifactsDir $FileName
$BundleName = "Antreva-Remote-Pilot-RustDesk-$Version"
$BundleDir = Join-Path $OutputDir $BundleName
$ZipPath = Join-Path $OutputDir "$BundleName.zip"
$ChecksumPath = Join-Path $OutputDir "$BundleName.sha256.txt"

& (Join-Path $ScriptDir 'Validate-AntrevaRemote.ps1') -PolicyPath $PolicyPath

$policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
$options = $policy.rustdeskOptions
$hostName = [string]$options.'custom-rendezvous-server'
$relayName = [string]$options.'relay-server'
$serverKey = [string]$options.key
$customExeName = "rustdesk-host=$hostName,key=$serverKey,relay=$relayName.exe"

New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

if (-not (Test-Path -LiteralPath $PortableExe)) {
    Write-Output "Downloading RustDesk $Version Windows x86_64..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $PortableExe
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $PortableExe).Hash.ToLowerInvariant()
if ($hash -ne $ExpectedSha256) {
    throw "RustDesk download hash mismatch. Expected $ExpectedSha256 but got $hash."
}

if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    $signature = Get-AuthenticodeSignature -FilePath $PortableExe
    if ($signature.Status -ne 'Valid') {
        throw "RustDesk Authenticode signature is not valid: $($signature.StatusMessage)"
    }
} else {
    Write-Warning 'Skipping Authenticode verification because this is not Windows.'
}

Remove-Item -LiteralPath $BundleDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $ZipPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $ChecksumPath -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $BundleDir | Out-Null

Copy-Item -LiteralPath $PortableExe -Destination (Join-Path $BundleDir $customExeName)
Copy-Item -LiteralPath (Join-Path $Root 'packaging\pilot\Antreva-Remote-Pilot-Setup.cmd') -Destination $BundleDir
Copy-Item -LiteralPath (Join-Path $Root 'packaging\pilot\Configure-And-Launch-Antreva-Remote-Pilot.ps1') -Destination $BundleDir
Copy-Item -LiteralPath (Join-Path $Root 'packaging\pilot\README.md') -Destination $BundleDir

Compress-Archive -Path (Join-Path $BundleDir '*') -DestinationPath $ZipPath -Force

$zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ZipPath).Hash.ToUpperInvariant()
Set-Content -LiteralPath $ChecksumPath -Encoding ASCII -Value "$zipHash *$(Split-Path -Leaf $ZipPath)"

Write-Output "Bundle: $ZipPath"
Write-Output "Checksum: $ChecksumPath"
Write-Output "SHA256: $zipHash"
