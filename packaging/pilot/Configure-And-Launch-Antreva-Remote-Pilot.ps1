[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ExpectedSha256 = 'f0053229fa2a2459c8b86f326c3e7423018a72f010f9758dc21be171b112d1b2'
$PortableExe = Join-Path $PSScriptRoot 'rustdesk-1.4.8-x86_64.exe'
$ExtractedExe = Join-Path $env:LOCALAPPDATA 'rustdesk\rustdesk.exe'

$Options = [ordered]@{
    'custom-rendezvous-server' = '104.184.67.190'
    'relay-server' = '104.184.67.190'
    'key' = 'YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg='
    'access-mode' = 'click'
    'approve-mode' = 'click'
    'verification-method' = 'use-temporary-password'
    'enable-keyboard' = 'Y'
    'enable-clipboard' = 'Y'
    'enable-file-transfer' = 'Y'
    'enable-file-copy-paste' = 'Y'
    'one-way-file-transfer' = 'N'
    'file-transfer-max-files' = '200'
    'enable-terminal' = 'N'
    'enable-tunnel' = 'N'
    'enable-remote-printer' = 'N'
    'enable-remote-restart' = 'N'
    'enable-record-session' = 'N'
    'enable-block-input' = 'N'
    'enable-privacy-mode' = 'N'
    'allow-remote-config-modification' = 'N'
    'allow-auto-update' = 'N'
    'hide-tray' = 'N'
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Path -LiteralPath $PortableExe)) {
    throw "Missing pilot executable next to this script: $PortableExe"
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $PortableExe).Hash.ToLowerInvariant()
if ($hash -ne $ExpectedSha256) {
    throw "Pilot executable hash mismatch. Expected $ExpectedSha256 but got $hash."
}

$signature = Get-AuthenticodeSignature -FilePath $PortableExe
if ($signature.Status -ne 'Valid') {
    throw "Pilot executable signature is not valid: $($signature.StatusMessage)"
}

if (-not (Test-IsAdministrator)) {
    Write-Output "Administrator permission is required to configure RustDesk for Antreva Remote. Relaunching elevated..."
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$PSCommandPath`""
    ) -Verb RunAs
    exit 0
}

Write-Output "Extracting RustDesk pilot runtime..."
& $PortableExe --version | Out-Null

if (-not (Test-Path -LiteralPath $ExtractedExe)) {
    throw "RustDesk runtime was not found at $ExtractedExe after extraction."
}

Write-Output "Applying Antreva Remote pilot server settings..."
foreach ($entry in $Options.GetEnumerator()) {
    & $ExtractedExe --option $entry.Key ([string]$entry.Value)
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Failed to apply RustDesk option '$($entry.Key)' with exit code $LASTEXITCODE."
    }
}

Write-Output "Launching Antreva Remote pilot..."
Start-Process -FilePath $ExtractedExe
