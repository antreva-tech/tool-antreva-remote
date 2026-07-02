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

foreach ($text in @($supportDoc, $pilotReadme, $pilotTest, $workflow)) {
    Assert-Contains -Name 'support matrix' -Text $text -Expected 'Windows 7 SP1 through Windows 11 x64'
}

foreach ($expected in @('Windows 7 SP1 x64', 'Windows 8 x64', 'Windows 8.1 x64', 'Windows 10 x64', 'Windows 11 x64', 'WMF 5.1', 'KB4490628', 'KB4474419', '32-bit Windows is not supported')) {
    Assert-Contains -Name 'Windows 7-11 support documentation' -Text $supportDoc -Expected $expected
}

foreach ($expected in @('PowerShell 5.1 or newer is required', '$PSVersionTable.PSVersion.Major')) {
    Assert-Contains -Name 'CMD PowerShell preflight' -Text $setupCmd -Expected $expected
}

foreach ($expected in @('Test-SupportedWindowsVersion', 'Test-Windows7Prerequisites', 'Assert-AntrevaDeskWindowsSupport', 'Win32_OperatingSystem', 'OSArchitecture', 'ServicePackMajorVersion', 'Get-HotFix', 'KB4490628', 'KB4474419', 'WMF 5.1')) {
    Assert-Contains -Name 'PowerShell installer preflight' -Text $setupScript -Expected $expected
    Assert-Contains -Name 'repo-root pilot preflight' -Text $repoSetupScript -Expected $expected
}

Assert-Contains -Name 'repo-root pilot PowerShell preflight' -Text $repoSetupScript -Expected 'PowerShell 5.1 or newer is required'
Assert-Contains -Name 'repo-root pilot legacy hash support' -Text $repoSetupScript -Expected 'Get-Sha256Hash'
Assert-Contains -Name 'repo-root pilot TLS support' -Text $repoSetupScript -Expected 'Tls12'

Assert-Contains -Name 'pilot bundle RustDesk version' -Text $bundleScript -Expected '$RustDeskVersion = ''1.4.8'''
Assert-Contains -Name 'pilot bundle architecture' -Text $bundleScript -Expected '$FileName = "rustdesk-$RustDeskVersion-x86_64.exe"'
Assert-Contains -Name 'repository test wiring' -Text $repositoryTest -Expected 'Test-AntrevaDeskWindowsSupport.ps1'
Assert-Contains -Name 'release checklist certification' -Text $releaseChecklist -Expected 'Windows 7 SP1 through Windows 11 x64 support matrix has been certified'

Write-Output 'Antreva Desk Windows 7-11 support verification passed.'
