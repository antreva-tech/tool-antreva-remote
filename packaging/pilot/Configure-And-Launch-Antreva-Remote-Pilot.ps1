[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ExpectedSha256 = 'f0053229fa2a2459c8b86f326c3e7423018a72f010f9758dc21be171b112d1b2'
$PilotExeName = 'rustdesk-host=104.184.67.190,key=YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=,relay=104.184.67.190.exe'
$PortableExe = Join-Path $PSScriptRoot $PilotExeName
$InstallDir = Join-Path $env:LOCALAPPDATA 'AntrevaRemotePilot'
$Launcher = Join-Path $InstallDir 'Launch Antreva Remote.cmd'
$ShortcutName = 'Antreva Remote'

$ManagedOptions = [ordered]@{
    'custom-rendezvous-server' = '104.184.67.190'
    'relay-server' = '104.184.67.190'
    'key' = 'YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg='
    'access-mode' = 'password'
    'approve-mode' = 'password'
    'verification-method' = 'use-permanent-password'
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
    'hide-server-settings' = 'Y'
    'hide-proxy-settings' = 'Y'
    'hide-security-settings' = 'N'
    'hide-stop-service' = 'N'
    'disable-change-permanent-password' = 'N'
    'disable-change-id' = 'Y'
    'disable-unlock-pin' = 'Y'
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ConvertFrom-SecureStringForProcess {
    param([Parameter(Mandatory = $true)][Security.SecureString]$SecureString)

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

function Get-InstalledRustDeskExe {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'RustDesk\RustDesk.exe'),
        (Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe')
    )

    if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'RustDesk\RustDesk.exe')
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'RustDesk\rustdesk.exe')
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Invoke-RustDeskOption {
    param(
        [Parameter(Mandatory = $true)][string]$RustDeskExe,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )

    Write-Output "Applying RustDesk option: $Name"
    $output = & $RustDeskExe --option $Name $Value 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to apply RustDesk option '$Name' with exit code $LASTEXITCODE. $output"
    }
    if (($output | Out-String) -match 'Installation and administrative privileges required|Settings are disabled') {
        throw "Failed to apply RustDesk option '$Name'. $output"
    }
}

function Set-RustDeskPermanentPassword {
    param(
        [Parameter(Mandatory = $true)][string]$RustDeskExe,
        [Parameter(Mandatory = $true)][string]$Password
    )

    $output = & $RustDeskExe --password $Password 2>&1
    $text = ($output | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $text -notmatch 'Done!') {
        throw "RustDesk did not accept the permanent password. Output: $text"
    }
}

if (-not (Test-IsAdministrator)) {
    Write-Output "Managed Access setup requires administrator permission. Relaunching as Administrator..."
    $args = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$PSCommandPath`""
    )
    Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs
    exit 0
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

Write-Output "Antreva Remote Managed Access setup"
Write-Output "This will install the support service and configure permanent-password access."
$password1 = Read-Host -AsSecureString 'Enter the permanent support password'
$password2 = Read-Host -AsSecureString 'Confirm the permanent support password'
$plainPassword1 = ConvertFrom-SecureStringForProcess -SecureString $password1
$plainPassword2 = ConvertFrom-SecureStringForProcess -SecureString $password2

try {
    if ([string]::IsNullOrWhiteSpace($plainPassword1)) {
        throw 'Permanent support password cannot be empty.'
    }
    if ($plainPassword1 -ne $plainPassword2) {
        throw 'Permanent support passwords did not match.'
    }

    Write-Output "Stopping existing RustDesk processes..."
    Get-Process -Name 'rustdesk' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    Write-Output "Installing Antreva Remote managed access service..."
    & $PortableExe --silent-install
    if ($LASTEXITCODE -ne 0) {
        throw "RustDesk installation failed with exit code $LASTEXITCODE."
    }

    $installedExe = $null
    for ($i = 0; $i -lt 30 -and [string]::IsNullOrWhiteSpace($installedExe); $i++) {
        Start-Sleep -Seconds 1
        $installedExe = Get-InstalledRustDeskExe
    }

    if ([string]::IsNullOrWhiteSpace($installedExe)) {
        throw 'Installed RustDesk executable was not found under Program Files.'
    }

    foreach ($property in $ManagedOptions.GetEnumerator()) {
        Invoke-RustDeskOption -RustDeskExe $installedExe -Name $property.Key -Value $property.Value
    }

    Write-Output "Setting permanent support password..."
    Set-RustDeskPermanentPassword -RustDeskExe $installedExe -Password $plainPassword1

    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $launcherContent = @"
@echo off
start "" "$installedExe"
"@
    Set-Content -LiteralPath $Launcher -Value $launcherContent -Encoding ASCII

    $shell = New-Object -ComObject WScript.Shell
    $desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) "$ShortcutName.lnk"
    $startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Antreva'
    $startMenuShortcut = Join-Path $startMenuDir "$ShortcutName.lnk"
    New-Item -ItemType Directory -Force -Path $startMenuDir | Out-Null

    foreach ($shortcutPath in @($desktopShortcut, $startMenuShortcut)) {
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $Launcher
        $shortcut.WorkingDirectory = Split-Path -Parent $installedExe
        $shortcut.IconLocation = "$installedExe,0"
        $shortcut.Description = 'Antreva Remote managed support client'
        $shortcut.Save()
    }

    Write-Output "Launching Antreva Remote managed access..."
    Write-Output "ID server: 104.184.67.190"
    Write-Output "Relay server: 104.184.67.190"
    Start-Process -FilePath $installedExe
} finally {
    if ($null -ne $plainPassword1) {
        $plainPassword1 = $null
    }
    if ($null -ne $plainPassword2) {
        $plainPassword2 = $null
    }
}
