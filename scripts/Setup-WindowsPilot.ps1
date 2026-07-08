[CmdletBinding()]
param(
    [string]$PolicyPath,
    [string]$ArtifactsDir,
    [ValidateSet('auto', 'x86', 'x64')]
    [string]$Architecture = 'auto',
    [string]$PortableExe,
    [switch]$LaunchAfterConfigure
)

$ErrorActionPreference = 'Stop'

$MinimumPowerShellMajor = 3
if ($PSVersionTable.PSVersion.Major -lt $MinimumPowerShellMajor) {
    throw 'PowerShell 5.1 or newer is required on Windows 7. PowerShell 3 or newer is required on Windows 8 through Windows 11.'
}

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = Resolve-Path (Join-Path $ScriptDir '..')

if ([string]::IsNullOrWhiteSpace($PolicyPath)) {
    $PolicyPath = Join-Path $Root 'config\antreva-client-policy.json'
}
if ([string]::IsNullOrWhiteSpace($ArtifactsDir)) {
    $ArtifactsDir = Join-Path $Root 'artifacts\pilot'
}

$Version = '1.4.8'
$Payloads = @{
    x64 = @{
        FileName = "rustdesk-$Version-x86_64.exe"
        Sha256 = 'f0053229fa2a2459c8b86f326c3e7423018a72f010f9758dc21be171b112d1b2'
        Label = '64-bit'
    }
    x86 = @{
        FileName = "rustdesk-$Version-x86-sciter.exe"
        Sha256 = '10a14578ed3adbab66bfe5c8daa0d49d07e002d48f69f303966ea349f58dfea7'
        Label = '32-bit'
    }
}
$SupportedWindowsLabel = 'Windows 7 SP1 through Windows 11 x86/x64'
$SetupLogPath = Join-Path ([IO.Path]::GetTempPath()) 'AntrevaDesk-Setup.log'

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

function Set-ModernTlsIfAvailable {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {
        Write-Warning 'Could not enable TLS 1.2 for the RustDesk download. If the download fails on Windows 7 or Windows 8, install current Windows updates and retry.'
    }
}

function Test-Is64BitOperatingSystem {
    try {
        return [Environment]::Is64BitOperatingSystem
    } catch {
        $os = Get-WmiObject -Class Win32_OperatingSystem
        return ([string]$os.OSArchitecture) -match '64'
    }
}

function Resolve-RustDeskArchitecture {
    param([Parameter(Mandatory = $true)][string]$RequestedArchitecture)

    if ($RequestedArchitecture -ne 'auto') {
        return $RequestedArchitecture
    }
    if (Test-Is64BitOperatingSystem) {
        return 'x64'
    }

    return 'x86'
}

function Get-RustDeskPayloadMetadata {
    param([Parameter(Mandatory = $true)][string]$SelectedArchitecture)

    if (-not $Payloads.ContainsKey($SelectedArchitecture)) {
        throw "Unsupported AntrevaDesk installer architecture: $SelectedArchitecture."
    }

    return $Payloads[$SelectedArchitecture]
}

function Test-SupportedWindowsVersion {
    param([Parameter(Mandatory = $true)][string]$SelectedArchitecture)

    $os = Get-WmiObject -Class Win32_OperatingSystem
    $version = [Version]$os.Version
    $servicePackMajor = [int]$os.ServicePackMajorVersion
    $architecture = [string]$os.OSArchitecture
    $caption = [string]$os.Caption

    if ([int]$os.ProductType -ne 1) {
        throw "Antreva Desk $SupportedWindowsLabel support is limited to Windows client editions. Detected: $caption."
    }

    if ($SelectedArchitecture -eq 'x64' -and $architecture -notmatch '64') {
        throw "Antreva Desk 64-bit installation requires 64-bit Windows. Choose the 32-bit installer option for this computer."
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
    param([Parameter(Mandatory = $true)][string]$SelectedArchitecture)

    $windowsSupport = Test-SupportedWindowsVersion -SelectedArchitecture $SelectedArchitecture
    if ($windowsSupport.IsWindows7) {
        Test-Windows7Prerequisites
    }

    return $windowsSupport
}

function ConvertTo-CmdArgument {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ($Value -match '^-') {
        return $Value
    }

    return '"' + ($Value -replace '"', '""') + '"'
}

function Start-ElevatedSetup {
    param([string[]]$ScriptArguments = @())

    $wrapperPath = Join-Path ([IO.Path]::GetTempPath()) "AntrevaDesk-ElevatedSetup-$PID.cmd"
    $powerShellArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath) + $ScriptArguments
    $powerShellCommand = 'powershell.exe ' + (($powerShellArgs | ForEach-Object { ConvertTo-CmdArgument -Value $_ }) -join ' ')
    $wrapperLines = @(
        '@echo off',
        $powerShellCommand,
        'set "ANTREVA_EXIT=%ERRORLEVEL%"',
        'if not "%ANTREVA_EXIT%"=="0" (',
        '  echo.',
        '  echo Antreva Desk setup failed with exit code %ANTREVA_EXIT%.',
        "  echo Log file: $SetupLogPath",
        '  echo.',
        '  echo Press any key to close this window.',
        '  pause > nul',
        ')',
        'exit /b %ANTREVA_EXIT%'
    )

    Set-Content -LiteralPath $wrapperPath -Encoding ASCII -Value $wrapperLines
    Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', "`"$wrapperPath`"") -Verb RunAs
}

function Start-SetupTranscript {
    Write-Output "Setup log: $SetupLogPath"
    try {
        Start-Transcript -LiteralPath $SetupLogPath -Append | Out-Null
    } catch {
        Write-Warning "Could not start setup transcript at $SetupLogPath. $($_.Exception.Message)"
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

function Get-RustDeskMainConfigPath {
    $candidateRoots = @(
        [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData),
        $env:APPDATA,
        [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData),
        $env:ProgramData,
        [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData),
        $env:LOCALAPPDATA
    )
    $candidates = @()
    foreach ($root in $candidateRoots) {
        if (-not [string]::IsNullOrWhiteSpace($root)) {
            $candidates += (Join-Path $root 'RustDesk\config\RustDesk.toml')
        }
    }

    $seen = @{}
    foreach ($candidate in $candidates) {
        if ($seen.ContainsKey($candidate)) {
            continue
        }
        $seen[$candidate] = $true
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    throw "RustDesk.toml was not found. Checked: $($seen.Keys -join '; ')"
}

function Read-RustDeskMainConfig {
    param([Parameter(Mandatory = $true)][string]$Path)

    $config = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\[') {
            break
        }
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }
        if ($trimmed -match '^\s*([^=\s]+)\s*=\s*(.*?)\s*$') {
            $name = $matches[1]
            $value = $matches[2].Trim()
            if ($value.Length -ge 2) {
                if (($value.StartsWith("'") -and $value.EndsWith("'")) -or ($value.StartsWith('"') -and $value.EndsWith('"'))) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
            }
            $config[$name] = $value
        }
    }

    return $config
}

function Assert-RustDeskPermanentPasswordState {
    $lastError = ''
    $deadline = (Get-Date).AddSeconds(15)
    while ((Get-Date) -lt $deadline) {
        try {
            $configPath = Get-RustDeskMainConfigPath
            $config = Read-RustDeskMainConfig -Path $configPath
            $passwordStorage = if ($config.ContainsKey('password')) { [string]$config.password } else { '' }
            $salt = if ($config.ContainsKey('salt')) { [string]$config.salt } else { '' }

            if ([string]::IsNullOrWhiteSpace($passwordStorage)) {
                throw "RustDesk permanent password storage is empty in RustDesk.toml at $configPath."
            }
            if ([string]::IsNullOrWhiteSpace($salt)) {
                throw "RustDesk permanent password salt is empty in RustDesk.toml at $configPath."
            }
            if (-not $passwordStorage.StartsWith('01')) {
                throw "RustDesk permanent password storage is not in the expected current format in RustDesk.toml at $configPath."
            }

            Write-Output "Verified RustDesk permanent password storage in RustDesk.toml: $configPath"
            return
        } catch {
            $lastError = $_.Exception.Message
        }

        Start-Sleep -Seconds 1
    }

    throw $lastError
}

function Set-RustDeskPermanentPassword {
    param(
        [Parameter(Mandatory = $true)][string]$RustDeskExe,
        [Parameter(Mandatory = $true)][string]$Password
    )

    $output = & $RustDeskExe --password $Password 2>&1
    $text = ($output | Out-String).Trim()
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "RustDesk did not accept the permanent password. Output: $text"
    }
    if ($text -match 'Installation and administrative privileges required|Settings are disabled|Changing permanent password is disabled|rejected|failed|error') {
        throw "RustDesk did not accept the permanent password. Output: $text"
    }
    Assert-RustDeskPermanentPasswordState
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

$SelectedArchitecture = Resolve-RustDeskArchitecture -RequestedArchitecture $Architecture
$PayloadMetadata = Get-RustDeskPayloadMetadata -SelectedArchitecture $SelectedArchitecture
$FileName = [string]$PayloadMetadata.FileName
$DownloadUrl = "https://github.com/rustdesk/rustdesk/releases/download/$Version/$FileName"
$ExpectedSha256 = [string]$PayloadMetadata.Sha256
if ([string]::IsNullOrWhiteSpace($PortableExe)) {
    $PortableExe = Join-Path $ArtifactsDir $FileName
}

$windowsSupport = Assert-AntrevaDeskWindowsSupport -SelectedArchitecture $SelectedArchitecture
Write-Output "Windows support preflight passed: $($windowsSupport.Caption) $($windowsSupport.Version) $($windowsSupport.Architecture), AntrevaDesk $($PayloadMetadata.Label) payload."

& (Join-Path $ScriptDir 'Validate-AntrevaRemote.ps1') -PolicyPath $PolicyPath

New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null

if (-not (Test-Path -LiteralPath $PortableExe)) {
    Write-Output "Downloading RustDesk $Version Windows $($PayloadMetadata.Label)..."
    Set-ModernTlsIfAvailable
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $PortableExe
}

$hash = Get-Sha256Hash -Path $PortableExe
if ($hash -ne $ExpectedSha256) {
    throw "RustDesk download hash mismatch. Expected $ExpectedSha256 but got $hash."
}

$signature = Get-AuthenticodeSignature -FilePath $PortableExe
if ($signature.Status -ne 'Valid') {
    throw "RustDesk Authenticode signature is not valid: $($signature.StatusMessage)"
}

if (-not (Test-IsAdministrator)) {
    Write-Output "Managed Access setup requires elevation. Relaunching this script as Administrator..."
    $elevatedArgs = @(
        '-PolicyPath', $PolicyPath,
        '-ArtifactsDir', $ArtifactsDir,
        '-Architecture', $SelectedArchitecture,
        '-PortableExe', $PortableExe
    )
    if ($LaunchAfterConfigure) {
        $elevatedArgs += '-LaunchAfterConfigure'
    }
    Start-ElevatedSetup -ScriptArguments $elevatedArgs
    exit 0
}

Start-SetupTranscript

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

    Write-Output "Installing RustDesk managed service..."
    $installedExe = Invoke-RustDeskManagedInstall -InstallerExe $PortableExe

    Write-Output "Applying Antreva Remote managed policy to $installedExe..."
    & (Join-Path $ScriptDir 'Apply-AntrevaClientPolicy.ps1') -RustDeskExe $installedExe -PolicyPath $PolicyPath

    Write-Output "Setting permanent support password..."
    Set-RustDeskPermanentPassword -RustDeskExe $installedExe -Password $plainPassword1

    Write-Output "Managed Access is configured for Antreva Remote."
    Write-Output "Executable: $installedExe"

    if ($LaunchAfterConfigure) {
        Start-Process -FilePath $installedExe
    }
} finally {
    if ($null -ne $plainPassword1) {
        $plainPassword1 = $null
    }
    if ($null -ne $plainPassword2) {
        $plainPassword2 = $null
    }
}
