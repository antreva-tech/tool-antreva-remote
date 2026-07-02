[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = Resolve-Path (Join-Path $ScriptDir '..')

$expectedProduct = 'Antreva Desk'
$expectedVersion = '0.1.0'
$expectedReleaseTitle = "$expectedProduct $expectedVersion"
$expectedBundleName = 'Antreva-Desk-0.1.0-Windows'
$expectedZipName = "$expectedBundleName.zip"
$legacyBundleName = 'Antreva-Remote-Pilot-RustDesk-1.4.8'

$workflow = Get-Content -LiteralPath (Join-Path $Root '.github\workflows\build-and-release-installers.yml') -Raw
$buildScript = Get-Content -LiteralPath (Join-Path $Root 'scripts\Build-PilotBundle.ps1') -Raw
$setupScript = Get-Content -LiteralPath (Join-Path $Root 'packaging\pilot\Configure-And-Launch-Antreva-Remote-Pilot.ps1') -Raw
$setupCmd = Get-Content -LiteralPath (Join-Path $Root 'packaging\pilot\Antreva-Remote-Pilot-Setup.cmd') -Raw
$readme = Get-Content -LiteralPath (Join-Path $Root 'packaging\pilot\README.md') -Raw
$policy = Get-Content -LiteralPath (Join-Path $Root 'config\antreva-client-policy.json') -Raw | ConvertFrom-Json

$checks = @(
    @{ Name = 'workflow release title'; Passed = $workflow.Contains("RELEASE_TITLE: $expectedReleaseTitle") },
    @{ Name = 'workflow artifact name'; Passed = $workflow.Contains("name: $expectedBundleName") },
    @{ Name = 'workflow zip path'; Passed = $workflow.Contains("artifacts/$expectedZipName") },
    @{ Name = 'build script bundle name'; Passed = $buildScript.Contains('$BundleName = "Antreva-Desk-$AntrevaDeskVersion-Windows"') },
    @{ Name = 'setup script product name'; Passed = $setupScript.Contains("$expectedReleaseTitle Managed Access setup") },
    @{ Name = 'setup command launch text'; Passed = $setupCmd.Contains("Starting $expectedReleaseTitle setup...") },
    @{ Name = 'pilot README title'; Passed = $readme.Contains("# $expectedReleaseTitle Managed Access") },
    @{ Name = 'policy product name'; Passed = $policy.productName -eq $expectedProduct }
)

foreach ($check in $checks) {
    if (-not $check.Passed) {
        throw "Antreva Desk release naming check failed: $($check.Name)"
    }
}

$combined = @($workflow, $buildScript) -join "`n"
if ($combined.Contains($legacyBundleName)) {
    throw "Antreva Desk release naming check failed: legacy bundle name is still present."
}

Write-Output "Antreva Desk release naming verification passed."
