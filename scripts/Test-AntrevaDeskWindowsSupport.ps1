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

$supportDoc = Read-RepoFile 'docs\operations\WINDOWS-7-11-SUPPORT.md'
$pilotReadme = Read-RepoFile 'packaging\pilot\README.md'
$pilotTest = Read-RepoFile 'docs\operations\PILOT-WINDOWS-TEST.md'
$releaseChecklist = Read-RepoFile 'docs\compliance\RELEASE-CHECKLIST.md'
$generatedSetupPath = Join-Path ([System.IO.Path]::GetTempPath()) "AntrevaDesk-WindowsSupport-$PID.cmd"
& (Join-Path $ScriptDir 'New-AntrevaDeskInstaller.ps1') `
    -PolicyPath (Join-Path $Root 'config\antreva-client-policy.json') `
    -TemplatePath (Join-Path $Root 'packaging\pilot\Antreva-Remote-Pilot-Setup.cmd.in') `
    -OutputPath $generatedSetupPath `
    -Version '1.0.4' | Out-Null
$setupCmd = Get-Content -LiteralPath $generatedSetupPath -Raw
Remove-Item -LiteralPath $generatedSetupPath -Force
$bundleScript = Read-RepoFile 'scripts\Build-PilotBundle.ps1'
$workflow = Read-RepoFile '.github\workflows\build-and-release-installers.yml'
$repositoryTest = Read-RepoFile 'scripts\Test-Repository.ps1'

foreach ($text in @($supportDoc, $pilotReadme, $pilotTest)) {
    Assert-Contains -Name 'support matrix' -Text $text -Expected 'Windows 7 SP1 through Windows 11 x86/x64'
}
Assert-Contains -Name 'workflow non-installing label' -Text $workflow -Expected 'without installing'

foreach ($expected in @('Windows 7 SP1 x86', 'Windows 7 SP1 x64', 'Windows 8 x86', 'Windows 8 x64', 'Windows 8.1 x86', 'Windows 8.1 x64', 'Windows 10 x86', 'Windows 10 x64', 'Windows 11 x64', 'Windows 11 26H1', 'KB4490628', 'KB4474419')) {
    Assert-Contains -Name 'Windows 7-11 support documentation' -Text $supportDoc -Expected $expected
}
Assert-NotContains -Name 'Windows 7-11 support documentation' -Text $supportDoc -Unexpected '32-bit Windows is not supported'
Assert-NotContains -Name 'Windows 7-11 PowerShell independence' -Text $supportDoc -Unexpected 'WMF 5.1'

foreach ($unexpected in @('powershell.exe', 'pwsh.exe', '.ps1', 'WMF 5.1')) {
    Assert-NotContains -Name 'zero-PowerShell customer installer' -Text $setupCmd -Unexpected $unexpected
}
foreach ($expected in @(
    'PROCESSOR_ARCHITECTURE',
    'PROCESSOR_ARCHITEW6432',
    'CurrentBuildNumber',
    'KB4490628',
    'KB4474419',
    'wmic.exe',
    'certutil.exe -hashfile',
    '--verify-bundle',
    'rustdesk-1.4.8-x86_64.exe',
    'rustdesk-1.4.8-x86-sciter.exe',
    'F0053229FA2A2459C8B86F326C3E7423018A72F010F9758DC21BE171B112D1B2',
    '10A14578ED3ADBAB66BFE5C8DAA0D49D07E002D48F69F303966EA349F58DFEA7'
)) {
    Assert-Contains -Name 'Command Prompt compatibility and payload preflight' -Text $setupCmd -Expected $expected
}

$verifyBundleStart = $setupCmd.IndexOf("`n:verify_bundle", [StringComparison]::Ordinal)
$runSetupStart = $setupCmd.IndexOf("`n:RunSetup", [StringComparison]::Ordinal)
$selectArchitectureStart = $setupCmd.IndexOf("`n:SelectArchitecture", [StringComparison]::Ordinal)
if ($verifyBundleStart -lt 0 -or $runSetupStart -le $verifyBundleStart -or $selectArchitectureStart -le $runSetupStart) {
    throw 'Windows support check failed: Command Prompt setup control-flow labels are missing or out of order.'
}
$verifyBundleStart++
$runSetupStart++
$selectArchitectureStart++
$verifyBundleBlock = $setupCmd.Substring($verifyBundleStart, $runSetupStart - $verifyBundleStart)
$runSetupBlock = $setupCmd.Substring($runSetupStart, $selectArchitectureStart - $runSetupStart)
Assert-NotContains -Name 'CI bundle verification client OS independence' -Text $verifyBundleBlock -Unexpected 'call :PreflightWindows'
Assert-Contains -Name 'real installation client OS preflight' -Text $runSetupBlock -Expected 'call :PreflightWindows'
Assert-Contains -Name 'real installation Windows Server rejection' -Text $setupCmd -Expected 'Windows Server is not certified.'

Assert-Contains -Name 'pilot bundle RustDesk version' -Text $bundleScript -Expected '$RustDeskVersion = ''1.4.8'''
foreach ($expected in @('rustdesk-1.4.8-x86_64.exe', 'rustdesk-1.4.8-x86-sciter.exe', '10a14578ed3adbab66bfe5c8daa0d49d07e002d48f69f303966ea349f58dfea7')) {
    Assert-Contains -Name 'pilot bundle architecture payloads' -Text $bundleScript -Expected $expected
}
Assert-Contains -Name 'pilot bundle pinned publisher' -Text $bundleScript -Expected '4230334F8A7DD84E50D0273EF379E8B4A82F5DA5'
foreach ($expected in @(
    'Antreva-Remote-Pilot-Setup.cmd',
    'packaging\pilot\README.md',
    '$PayloadStageDir',
    'Compress-Archive'
)) {
    Assert-Contains -Name 'Command Prompt bundle contents' -Text $bundleScript -Expected $expected
}
foreach ($unexpected in @('Configure-And-Launch-Antreva-Remote-Pilot.ps1', 'AntrevaDesk-PayloadValidation.ps1')) {
    Assert-NotContains -Name 'customer bundle PowerShell exclusion' -Text $bundleScript -Unexpected $unexpected
}
Assert-NotContains -Name 'active workflow NSIS dependency' -Text $workflow -Unexpected 'Install NSIS'
Assert-NotContains -Name 'active workflow GUI installer' -Text $workflow -Unexpected 'AntrevaDesk-Setup'
Assert-Contains -Name 'active workflow Command Prompt zip' -Text $workflow -Expected 'Antreva-Desk-1.0.4-Windows.zip'
Assert-Contains -Name 'active workflow CMD verification' -Text $workflow -Expected 'shell: cmd'
Assert-Contains -Name 'active workflow zero-PowerShell verification mode' -Text $workflow -Expected '--verify-bundle'
Assert-Contains -Name 'repository test wiring' -Text $repositoryTest -Expected 'Test-AntrevaDeskWindowsSupport.ps1'
Assert-Contains -Name 'release checklist certification' -Text $releaseChecklist -Expected 'Windows 7 SP1 through Windows 11 x86/x64 support matrix has been certified'

Write-Output 'Antreva Desk Windows 7-11 support verification passed.'
