[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ExpectedSha256 = 'f0053229fa2a2459c8b86f326c3e7423018a72f010f9758dc21be171b112d1b2'
$PilotExeName = 'rustdesk-host=104.184.67.190,key=YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=,relay=104.184.67.190.exe'
$PortableExe = Join-Path $PSScriptRoot $PilotExeName
$InstallDir = Join-Path $env:LOCALAPPDATA 'AntrevaRemotePilot'
$InstalledExe = Join-Path $InstallDir 'Antreva Remote.exe'
$Launcher = Join-Path $InstallDir 'Launch Antreva Remote.cmd'

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

Write-Output "Installing Antreva Remote pilot launcher..."
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -LiteralPath $PortableExe -Destination $InstalledExe -Force

$launcherContent = @"
@echo off
set "RUSTDESK_APPNAME=$PilotExeName"
start "" "%~dp0Antreva Remote.exe"
"@
Set-Content -LiteralPath $Launcher -Value $launcherContent -Encoding ASCII

$shell = New-Object -ComObject WScript.Shell
$desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Antreva Remote.lnk'
$startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Antreva'
$startMenuShortcut = Join-Path $startMenuDir 'Antreva Remote.lnk'
New-Item -ItemType Directory -Force -Path $startMenuDir | Out-Null

foreach ($shortcutPath in @($desktopShortcut, $startMenuShortcut)) {
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $Launcher
    $shortcut.WorkingDirectory = $InstallDir
    $shortcut.IconLocation = "$InstalledExe,0"
    $shortcut.Description = 'Antreva Remote pilot support client'
    $shortcut.Save()
}

Write-Output "Launching Antreva Remote pilot with embedded server settings..."
Write-Output "ID server: 104.184.67.190"
Write-Output "Relay server: 104.184.67.190"
Start-Process -FilePath $Launcher
