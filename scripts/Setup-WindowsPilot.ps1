[CmdletBinding()]
param(
    [string]$PolicyPath,
    [string]$ArtifactsDir,
    [switch]$LaunchAfterConfigure
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

$Version = '1.4.8'
$FileName = "rustdesk-$Version-x86_64.exe"
$DownloadUrl = "https://github.com/rustdesk/rustdesk/releases/download/$Version/$FileName"
$ExpectedSha256 = 'f0053229fa2a2459c8b86f326c3e7423018a72f010f9758dc21be171b112d1b2'
$PortableExe = Join-Path $ArtifactsDir $FileName
$ExtractedExe = Join-Path $env:LOCALAPPDATA 'rustdesk\rustdesk.exe'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

& (Join-Path $ScriptDir 'Validate-AntrevaRemote.ps1') -PolicyPath $PolicyPath

New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null

if (-not (Test-Path -LiteralPath $PortableExe)) {
    Write-Output "Downloading RustDesk $Version Windows x86_64..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $PortableExe
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $PortableExe).Hash.ToLowerInvariant()
if ($hash -ne $ExpectedSha256) {
    throw "RustDesk download hash mismatch. Expected $ExpectedSha256 but got $hash."
}

$signature = Get-AuthenticodeSignature -FilePath $PortableExe
if ($signature.Status -ne 'Valid') {
    throw "RustDesk Authenticode signature is not valid: $($signature.StatusMessage)"
}

if (-not (Test-IsAdministrator)) {
    Write-Output "Configuration requires elevation. Relaunching this script as Administrator..."
    $args = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$PSCommandPath`"",
        '-PolicyPath', "`"$PolicyPath`"",
        '-ArtifactsDir', "`"$ArtifactsDir`""
    )
    if ($LaunchAfterConfigure) {
        $args += '-LaunchAfterConfigure'
    }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs
    exit 0
}

if (-not (Test-Path -LiteralPath $ExtractedExe)) {
    Write-Output "Extracting RustDesk runtime..."
    & $PortableExe --version | Out-Null
}

if (-not (Test-Path -LiteralPath $ExtractedExe)) {
    throw "RustDesk runtime was not found at $ExtractedExe after extraction."
}

Write-Output "Applying Antreva Remote policy to $ExtractedExe..."
& (Join-Path $ScriptDir 'Apply-AntrevaClientPolicy.ps1') -RustDeskExe $ExtractedExe -PolicyPath $PolicyPath

Write-Output "Pilot app is configured for Antreva Remote."
Write-Output "Executable: $ExtractedExe"

if ($LaunchAfterConfigure) {
    Start-Process -FilePath $ExtractedExe
}
