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
$AntrevaDeskVersion = '1.0.0'
$InstallerName = "AntrevaDesk-Setup-$AntrevaDeskVersion"
$InstallerPath = Join-Path $OutputDir "$InstallerName.exe"
$ChecksumPath = Join-Path $OutputDir "$InstallerName.sha256.txt"
$InstallerSourceDir = Join-Path $Root 'packaging\antrevadesk'
$StagingDir = Join-Path $InstallerSourceDir 'staging'
$SetupStageDir = Join-Path $StagingDir 'setup'
$PayloadStageDir = Join-Path $StagingDir 'payloads'

$Payloads = @{
    x64 = @{
        FileName = 'rustdesk-1.4.8-x86_64.exe'
        DownloadUrl = "https://github.com/rustdesk/rustdesk/releases/download/$RustDeskVersion/rustdesk-1.4.8-x86_64.exe"
        Sha256 = 'f0053229fa2a2459c8b86f326c3e7423018a72f010f9758dc21be171b112d1b2'
    }
    x86 = @{
        FileName = 'rustdesk-1.4.8-x86-sciter.exe'
        DownloadUrl = "https://github.com/rustdesk/rustdesk/releases/download/$RustDeskVersion/rustdesk-1.4.8-x86-sciter.exe"
        Sha256 = '10a14578ed3adbab66bfe5c8daa0d49d07e002d48f69f303966ea349f58dfea7'
    }
}

function Resolve-MakeNsis {
    $command = Get-Command makensis.exe -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'NSIS\makensis.exe'),
        (Join-Path $env:ProgramFiles 'NSIS\makensis.exe')
    )
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    throw 'makensis.exe was not found. Install NSIS, then run this build again.'
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
    } else {
        Write-Warning "Skipping RustDesk $arch Authenticode verification because this is not Windows."
    }
}

$makeNsis = Resolve-MakeNsis

Remove-Item -LiteralPath $StagingDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $InstallerPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $ChecksumPath -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $SetupStageDir | Out-Null

Copy-Item -LiteralPath (Join-Path $Root 'packaging\pilot\Configure-And-Launch-Antreva-Remote-Pilot.ps1') -Destination $SetupStageDir

foreach ($entry in $Payloads.GetEnumerator()) {
    $arch = [string]$entry.Key
    $payload = $entry.Value
    $archStageDir = Join-Path $PayloadStageDir $arch
    New-Item -ItemType Directory -Force -Path $archStageDir | Out-Null
    Copy-Item -LiteralPath (Join-Path $ArtifactsDir ([string]$payload.FileName)) -Destination $archStageDir
}

Push-Location $InstallerSourceDir
try {
    & $makeNsis "/DOUTFILE=$InstallerPath" 'AntrevaDesk-Setup.nsi'
    if ($LASTEXITCODE -ne 0) {
        throw "makensis.exe failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $InstallerPath)) {
    throw "NSIS did not produce the expected installer: $InstallerPath"
}

$installerHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $InstallerPath).Hash.ToUpperInvariant()
Set-Content -LiteralPath $ChecksumPath -Encoding ASCII -Value "$installerHash *$(Split-Path -Leaf $InstallerPath)"

Write-Output "Installer: $InstallerPath"
Write-Output "Checksum: $ChecksumPath"
Write-Output "SHA256: $installerHash"
