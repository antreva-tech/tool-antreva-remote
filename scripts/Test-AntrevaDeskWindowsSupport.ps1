[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = Resolve-Path (Join-Path $ScriptDir '..')

function Read-RepoFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = Join-Path $Root $Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "Required Windows support file is missing: $Path"
    }

    return Get-Content -LiteralPath $fullPath -Raw
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Expected
    )

    if (-not $Text.Contains($Expected)) {
        throw "Windows support check failed: $Name must contain '$Expected'."
    }
}

function Assert-NotContains {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Unexpected
    )

    if ($Text.Contains($Unexpected)) {
        throw "Windows support check failed: $Name must not contain '$Unexpected'."
    }
}

function Assert-BitmapDimensions {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$ExpectedWidth,
        [Parameter(Mandatory = $true)][int]$ExpectedHeight
    )

    Add-Type -AssemblyName System.Drawing
    $fullPath = Join-Path $Root $Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "Windows support check failed: $Name image is missing: $Path"
    }

    $image = [System.Drawing.Image]::FromFile($fullPath)
    try {
        if ($image.Width -ne $ExpectedWidth -or $image.Height -ne $ExpectedHeight) {
            throw "Windows support check failed: $Name image must be ${ExpectedWidth}x${ExpectedHeight}, got $($image.Width)x$($image.Height)."
        }
    } finally {
        $image.Dispose()
    }
}

$supportDoc = Read-RepoFile 'docs\operations\WINDOWS-7-11-SUPPORT.md'
$pilotReadme = Read-RepoFile 'packaging\pilot\README.md'
$pilotTest = Read-RepoFile 'docs\operations\PILOT-WINDOWS-TEST.md'
$releaseChecklist = Read-RepoFile 'docs\compliance\RELEASE-CHECKLIST.md'
$setupCmd = Read-RepoFile 'packaging\pilot\Antreva-Remote-Pilot-Setup.cmd'
$setupScript = Read-RepoFile 'packaging\pilot\Configure-And-Launch-Antreva-Remote-Pilot.ps1'
$repoSetupScript = Read-RepoFile 'scripts\Setup-WindowsPilot.ps1'
$bundleScript = Read-RepoFile 'scripts\Build-PilotBundle.ps1'
$workflow = Read-RepoFile '.github\workflows\build-and-release-installers.yml'
$repositoryTest = Read-RepoFile 'scripts\Test-Repository.ps1'
$nsisScript = Read-RepoFile 'packaging\antrevadesk\AntrevaDesk-Setup.nsi'

foreach ($text in @($supportDoc, $pilotReadme, $pilotTest, $workflow)) {
    Assert-Contains -Name 'support matrix' -Text $text -Expected 'Windows 7 SP1 through Windows 11 x86/x64'
}

foreach ($expected in @('Windows 7 SP1 x86', 'Windows 7 SP1 x64', 'Windows 8 x86', 'Windows 8 x64', 'Windows 8.1 x86', 'Windows 8.1 x64', 'Windows 10 x86', 'Windows 10 x64', 'Windows 11 x64', 'WMF 5.1', 'KB4490628', 'KB4474419')) {
    Assert-Contains -Name 'Windows 7-11 support documentation' -Text $supportDoc -Expected $expected
}
Assert-NotContains -Name 'Windows 7-11 support documentation' -Text $supportDoc -Unexpected '32-bit Windows is not supported'

foreach ($expected in @('PowerShell 5.1 or newer is required', '$PSVersionTable.PSVersion.Major')) {
    Assert-Contains -Name 'CMD PowerShell preflight' -Text $setupCmd -Expected $expected
}

foreach ($expected in @('Test-SupportedWindowsVersion', 'Test-Windows7Prerequisites', 'Assert-AntrevaDeskWindowsSupport', 'Win32_OperatingSystem', 'OSArchitecture', 'ServicePackMajorVersion', 'Get-HotFix', 'KB4490628', 'KB4474419', 'WMF 5.1')) {
    Assert-Contains -Name 'PowerShell installer preflight' -Text $setupScript -Expected $expected
    Assert-Contains -Name 'repo-root pilot preflight' -Text $repoSetupScript -Expected $expected
}
foreach ($expected in @('-Architecture', 'Get-RustDeskPayloadMetadata', 'rustdesk-1.4.8-x86_64.exe', 'rustdesk-1.4.8-x86-sciter.exe', '10a14578ed3adbab66bfe5c8daa0d49d07e002d48f69f303966ea349f58dfea7')) {
    Assert-Contains -Name 'PowerShell architecture payload support' -Text $setupScript -Expected $expected
    Assert-Contains -Name 'repo-root architecture payload support' -Text $repoSetupScript -Expected $expected
}

Assert-Contains -Name 'repo-root pilot PowerShell preflight' -Text $repoSetupScript -Expected 'PowerShell 5.1 or newer is required'
Assert-Contains -Name 'repo-root pilot legacy hash support' -Text $repoSetupScript -Expected 'Get-Sha256Hash'
Assert-Contains -Name 'repo-root pilot TLS support' -Text $repoSetupScript -Expected 'Tls12'

Assert-Contains -Name 'pilot bundle RustDesk version' -Text $bundleScript -Expected '$RustDeskVersion = ''1.4.8'''
foreach ($expected in @('rustdesk-1.4.8-x86_64.exe', 'rustdesk-1.4.8-x86-sciter.exe', '10a14578ed3adbab66bfe5c8daa0d49d07e002d48f69f303966ea349f58dfea7')) {
    Assert-Contains -Name 'pilot bundle architecture payloads' -Text $bundleScript -Expected $expected
}
foreach ($expected in @('AntrevaDesk ArchitecturePage', 'ARCH_X64', 'ARCH_X86', 'RunningX64', '-Architecture', '-PortableExe')) {
    Assert-Contains -Name 'NSIS architecture selection' -Text $nsisScript -Expected $expected
}
Assert-BitmapDimensions -Name 'NSIS header logo' -Path 'packaging\antrevadesk\assets\banner.bmp' -ExpectedWidth 150 -ExpectedHeight 57
Assert-BitmapDimensions -Name 'NSIS welcome side logo' -Path 'packaging\antrevadesk\assets\dialog.bmp' -ExpectedWidth 164 -ExpectedHeight 314
foreach ($expected in @('RequestExecutionLevel admin', 'AntrevaDesk PasswordPage', 'PASSWORD_ONE', 'PASSWORD_TWO', 'Permanent support password', 'nsExec::ExecToLog', 'SetEnvironmentVariable', 'ANTREVA_DESK_PASSWORD', '-PasswordEnvironmentVariable', '-NonInteractive')) {
    Assert-Contains -Name 'NSIS GUI-only managed setup' -Text $nsisScript -Expected $expected
}
Assert-NotContains -Name 'NSIS visible PowerShell execution' -Text $nsisScript -Unexpected 'ExecWait ''"powershell.exe"'
foreach ($expected in @('-PasswordEnvironmentVariable', 'Get-PermanentSupportPassword', 'ANTREVA_DESK_PASSWORD')) {
    Assert-Contains -Name 'PowerShell installer-driven password support' -Text $setupScript -Expected $expected
}
Assert-Contains -Name 'repository test wiring' -Text $repositoryTest -Expected 'Test-AntrevaDeskWindowsSupport.ps1'
Assert-Contains -Name 'release checklist certification' -Text $releaseChecklist -Expected 'Windows 7 SP1 through Windows 11 x86/x64 support matrix has been certified'

Write-Output 'Antreva Desk Windows 7-11 support verification passed.'
