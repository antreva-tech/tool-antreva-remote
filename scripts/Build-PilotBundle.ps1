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

$RustDeskVersion = '1.4.8'
$AntrevaDeskVersion = '1.0.3'
$BundleName = "Antreva-Desk-$AntrevaDeskVersion-Windows"
$BundleDir = Join-Path $OutputDir $BundleName
$ZipPath = Join-Path $OutputDir "$BundleName.zip"
$ChecksumPath = Join-Path $OutputDir "$BundleName.sha256.txt"
$PayloadStageDir = Join-Path $BundleDir 'payloads'

$Payloads = @{
    x64 = @{
        FileName = 'rustdesk-1.4.8-x86_64.exe'
        DownloadUrl = "https://github.com/rustdesk/rustdesk/releases/download/$RustDeskVersion/rustdesk-1.4.8-x86_64.exe"
        Sha256 = 'f0053229fa2a2459c8b86f326c3e7423018a72f010f9758dc21be171b112d1b2'
        SignerThumbprint = '4230334F8A7DD84E50D0273EF379E8B4A82F5DA5'
    }
    x86 = @{
        FileName = 'rustdesk-1.4.8-x86-sciter.exe'
        DownloadUrl = "https://github.com/rustdesk/rustdesk/releases/download/$RustDeskVersion/rustdesk-1.4.8-x86-sciter.exe"
        Sha256 = '10a14578ed3adbab66bfe5c8daa0d49d07e002d48f69f303966ea349f58dfea7'
        SignerThumbprint = '4230334F8A7DD84E50D0273EF379E8B4A82F5DA5'
    }
}

& (Join-Path $ScriptDir 'Validate-AntrevaRemote.ps1') -PolicyPath $PolicyPath

New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

foreach ($entry in $Payloads.GetEnumerator()) {
    $arch = [string]$entry.Key
    $payload = $entry.Value
    $payloadPath = Join-Path $ArtifactsDir ([string]$payload.FileName)
    if (-not (Test-Path -LiteralPath $payloadPath)) {
        Write-Output "Downloading RustDesk $RustDeskVersion Windows $arch..."
        Invoke-WebRequest -Uri ([string]$payload.DownloadUrl) -OutFile $payloadPath
    }

    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $payloadPath).Hash.ToLowerInvariant()
    if ($hash -ne ([string]$payload.Sha256)) {
        throw "RustDesk $arch download hash mismatch. Expected $($payload.Sha256) but got $hash."
    }

    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        $signature = Get-AuthenticodeSignature -FilePath $payloadPath
        if ($signature.Status -ne 'Valid') {
            throw "RustDesk $arch Authenticode signature is not valid: $($signature.StatusMessage)"
        }
        if ($null -eq $signature.SignerCertificate -or $signature.SignerCertificate.Thumbprint -ne ([string]$payload.SignerThumbprint)) {
            throw "RustDesk $arch Authenticode signer does not match the pinned RustDesk publisher certificate."
        }
    } else {
        Write-Warning "Skipping RustDesk $arch Authenticode verification because this is not Windows."
    }
}

Remove-Item -LiteralPath $BundleDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $ZipPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $ChecksumPath -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $BundleDir | Out-Null

Copy-Item -LiteralPath (Join-Path $Root 'packaging\pilot\Antreva-Remote-Pilot-Setup.cmd') -Destination $BundleDir
Copy-Item -LiteralPath (Join-Path $Root 'packaging\pilot\Configure-And-Launch-Antreva-Remote-Pilot.ps1') -Destination $BundleDir
Copy-Item -LiteralPath (Join-Path $Root 'packaging\pilot\AntrevaDesk-PayloadValidation.ps1') -Destination $BundleDir
Copy-Item -LiteralPath (Join-Path $Root 'packaging\pilot\README.md') -Destination $BundleDir

foreach ($entry in $Payloads.GetEnumerator()) {
    $arch = [string]$entry.Key
    $payload = $entry.Value
    $archStageDir = Join-Path $PayloadStageDir $arch
    New-Item -ItemType Directory -Force -Path $archStageDir | Out-Null
    Copy-Item -LiteralPath (Join-Path $ArtifactsDir ([string]$payload.FileName)) -Destination $archStageDir
}

Compress-Archive -Path (Join-Path $BundleDir '*') -DestinationPath $ZipPath -Force

$zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ZipPath).Hash.ToUpperInvariant()
Set-Content -LiteralPath $ChecksumPath -Encoding ASCII -Value "$zipHash *$(Split-Path -Leaf $ZipPath)"

Write-Output "Bundle: $ZipPath"
Write-Output "Checksum: $ChecksumPath"
Write-Output "SHA256: $zipHash"
