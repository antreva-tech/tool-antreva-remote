[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$MinimumPowerShellMajor = 3
if ($PSVersionTable.PSVersion.Major -lt $MinimumPowerShellMajor) {
    throw 'PowerShell 5.1 or newer is required on Windows 7. PowerShell 3 or newer is required on Windows 8 through Windows 11.'
}

$ExpectedSha256 = 'f0053229fa2a2459c8b86f326c3e7423018a72f010f9758dc21be171b112d1b2'
$PilotExeName = 'rustdesk-host=104.184.67.190,key=YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg=,relay=104.184.67.190.exe'
$PortableExe = Join-Path $PSScriptRoot $PilotExeName
$InstallDir = Join-Path $env:LOCALAPPDATA 'AntrevaDesk'
$Launcher = Join-Path $InstallDir 'Launch Antreva Desk.cmd'
$ShortcutName = 'Antreva Desk'
$SupportedWindowsLabel = 'Windows 7 SP1 through Windows 11 x64'

$ManagedOptions = @{
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
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
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

function Get-Sha256Hash {
    param([Parameter(Mandatory = $true)][string]$Path)

    $sha256 = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hashBytes = $sha256.ComputeHash($stream)
        return -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
    } finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
        if ($null -ne $sha256) {
            $sha256.Dispose()
        }
    }
}

function Test-SupportedWindowsVersion {
    $os = Get-WmiObject -Class Win32_OperatingSystem
    $version = [Version]$os.Version
    $servicePackMajor = [int]$os.ServicePackMajorVersion
    $architecture = [string]$os.OSArchitecture
    $caption = [string]$os.Caption

    if ([int]$os.ProductType -ne 1) {
        throw "Antreva Desk $SupportedWindowsLabel support is limited to Windows client editions. Detected: $caption."
    }

    if ($architecture -notmatch '64') {
        throw "Antreva Desk $SupportedWindowsLabel support is x64 only. 32-bit Windows is not supported."
    }

    $isWindows7 = $version.Major -eq 6 -and $version.Minor -eq 1
    $isWindows8 = $version.Major -eq 6 -and $version.Minor -eq 2
    $isWindows81 = $version.Major -eq 6 -and $version.Minor -eq 3
    $isWindows10Or11 = $version.Major -eq 10

    if ($isWindows7 -and $servicePackMajor -lt 1) {
        throw 'Windows 7 support requires Windows 7 SP1 x64. Install Service Pack 1, then run this setup again.'
    }

    if (-not ($isWindows7 -or $isWindows8 -or $isWindows81 -or $isWindows10Or11)) {
        throw "Antreva Desk supports $SupportedWindowsLabel for this release. Detected: $caption $($os.Version)."
    }

    return [pscustomobject]@{
        Caption = $caption
        Version = $os.Version
        Architecture = $architecture
        IsWindows7 = $isWindows7
    }
}

function Test-Windows7Prerequisites {
    $version = $PSVersionTable.PSVersion
    if ($version.Major -lt 5 -or ($version.Major -eq 5 -and $version.Minor -lt 1)) {
        throw 'Windows 7 SP1 x64 support requires WMF 5.1 / PowerShell 5.1. Install Windows Management Framework 5.1, then run this setup again.'
    }

    $missingHotFixes = @()
    foreach ($hotFixId in @('KB4490628', 'KB4474419')) {
        $hotFix = Get-HotFix -Id $hotFixId -ErrorAction SilentlyContinue
        if ($null -eq $hotFix) {
            $missingHotFixes += $hotFixId
        }
    }

    if ($missingHotFixes.Count -gt 0) {
        throw "Windows 7 SP1 x64 support requires SHA-2 signing updates KB4490628 and KB4474419. Missing: $($missingHotFixes -join ', ')."
    }
}

function Assert-AntrevaDeskWindowsSupport {
    $windowsSupport = Test-SupportedWindowsVersion
    if ($windowsSupport.IsWindows7) {
        Test-Windows7Prerequisites
    }

    return $windowsSupport
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

function Get-RustDeskOption {
    param(
        [Parameter(Mandatory = $true)][string]$RustDeskExe,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $output = & $RustDeskExe --option $Name 2>&1
    $text = ($output | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read RustDesk option '$Name' with exit code $LASTEXITCODE. $text"
    }
    if ($text -match 'Installation and administrative privileges required|Settings are disabled') {
        throw "Failed to read RustDesk option '$Name'. $text"
    }

    return $text
}

function Assert-RustDeskOption {
    param(
        [Parameter(Mandatory = $true)][string]$RustDeskExe,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ExpectedValue
    )

    $actual = ''
    $deadline = (Get-Date).AddSeconds(15)
    while ((Get-Date) -lt $deadline) {
        $actual = Get-RustDeskOption -RustDeskExe $RustDeskExe -Name $Name
        if ($actual -eq $ExpectedValue) {
            return
        }

        Start-Sleep -Seconds 1
    }

    throw "RustDesk option '$Name' did not verify. Expected '$ExpectedValue' but got '$actual'."
}

function Import-RustDeskCustomServerConfig {
    param(
        [Parameter(Mandatory = $true)][string]$RustDeskExe,
        [Parameter(Mandatory = $true)][string]$ConfigName
    )

    Write-Output "Importing Antreva server configuration from installer name..."
    $output = & $RustDeskExe --config $ConfigName 2>&1
    $text = ($output | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to import Antreva server configuration with exit code $LASTEXITCODE. $text"
    }
    if ($text -match 'Installation and administrative privileges required|Settings are disabled') {
        throw "Failed to import Antreva server configuration. $text"
    }
}

function Assert-RustDeskManagedOptions {
    param(
        [Parameter(Mandatory = $true)][string]$RustDeskExe,
        [Parameter(Mandatory = $true)][hashtable]$Options
    )

    foreach ($property in $Options.GetEnumerator()) {
        Assert-RustDeskOption -RustDeskExe $RustDeskExe -Name $property.Key -ExpectedValue ([string]$property.Value)
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

function Invoke-RustDeskManagedInstall {
    param([Parameter(Mandatory = $true)][string]$InstallerExe)

    $stdoutPath = Join-Path $env:TEMP "antreva-rustdesk-install-$PID.out.log"
    $stderrPath = Join-Path $env:TEMP "antreva-rustdesk-install-$PID.err.log"
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue

    $process = Start-Process `
        -FilePath $InstallerExe `
        -ArgumentList '--silent-install' `
        -PassThru `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath

    $deadline = (Get-Date).AddSeconds(120)
    $postExitDeadline = $null
    $installCompletionDeadline = $null
    $installedExe = $null

    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2

        if ([string]::IsNullOrWhiteSpace($installedExe)) {
            $installedExe = Get-InstalledRustDeskExe
        }

        if (-not [string]::IsNullOrWhiteSpace($installedExe) -and $process.HasExited) {
            return $installedExe
        }

        if (-not [string]::IsNullOrWhiteSpace($installedExe) -and $null -eq $installCompletionDeadline) {
            Write-Output 'Installed executable found. Waiting for RustDesk installer finalization...'
            $installCompletionDeadline = (Get-Date).AddSeconds(20)
        }

        if (-not [string]::IsNullOrWhiteSpace($installedExe) -and $null -ne $installCompletionDeadline -and (Get-Date) -ge $installCompletionDeadline) {
            if (-not $process.HasExited) {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            }
            return $installedExe
        }

        if ($process.HasExited -and $null -eq $postExitDeadline) {
            $postExitDeadline = (Get-Date).AddSeconds(10)
        }

        if ($null -ne $postExitDeadline -and (Get-Date) -ge $postExitDeadline) {
            break
        }
    }

    if (-not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }

    $exitCode = if ($process.HasExited) { $process.ExitCode } else { 'timeout' }
    $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { '' }
    $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { '' }
    $installText = (($stdout, $stderr) -join "`n").Trim()
    if ([string]::IsNullOrWhiteSpace($installText)) {
        $installText = 'No installer output was captured.'
    }

    throw "RustDesk installation did not complete. Installer result: $exitCode. $installText"
}

$windowsSupport = Assert-AntrevaDeskWindowsSupport
Write-Output "Windows support preflight passed: $($windowsSupport.Caption) $($windowsSupport.Version) $($windowsSupport.Architecture)."

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

$hash = Get-Sha256Hash -Path $PortableExe
if ($hash -ne $ExpectedSha256) {
    throw "Pilot executable hash mismatch. Expected $ExpectedSha256 but got $hash."
}

$signature = Get-AuthenticodeSignature -FilePath $PortableExe
if ($signature.Status -ne 'Valid') {
    throw "Pilot executable signature is not valid: $($signature.StatusMessage)"
}

Write-Output "Antreva Desk 0.1.0 Managed Access setup"
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

    Write-Output "Installing Antreva Desk managed access service..."
    $installedExe = Invoke-RustDeskManagedInstall -InstallerExe $PortableExe

    Import-RustDeskCustomServerConfig -RustDeskExe $installedExe -ConfigName (Split-Path -Leaf $PortableExe)

    foreach ($property in $ManagedOptions.GetEnumerator()) {
        Invoke-RustDeskOption -RustDeskExe $installedExe -Name $property.Key -Value $property.Value
    }
    Assert-RustDeskManagedOptions -RustDeskExe $installedExe -Options $ManagedOptions

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
        $shortcut.Description = 'Antreva Desk managed support client'
        $shortcut.Save()
    }

    Write-Output "Launching Antreva Desk managed access..."
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
