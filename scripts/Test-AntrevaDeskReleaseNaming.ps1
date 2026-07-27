[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = Resolve-Path (Join-Path $ScriptDir '..')

$expectedProduct = 'Antreva Desk'
$expectedVersion = '1.0.4'
$expectedReleaseTitle = "$expectedProduct $expectedVersion"
$expectedBundleName = "Antreva-Desk-$expectedVersion-Windows"
$expectedZipName = "$expectedBundleName.zip"
$expectedChecksumName = "$expectedBundleName.sha256.txt"
$expectedTagName = 'antreva-desk-1.0.4'
$retiredGuiName = 'AntrevaDesk-Setup'
$previousReleaseTag = 'antreva-desk-1.0.3'
$legacyBundleName = 'Antreva-Remote-Pilot-RustDesk-1.4.8'

$workflow = Get-Content -LiteralPath (Join-Path $Root '.github\workflows\build-and-release-installers.yml') -Raw
$releaseWorkflow = Get-Content -LiteralPath (Join-Path $Root '.github\workflows\release-antreva-desk.yml') -Raw
$buildScript = Get-Content -LiteralPath (Join-Path $Root 'scripts\Build-PilotBundle.ps1') -Raw
$setupCmd = Get-Content -LiteralPath (Join-Path $Root 'packaging\pilot\Antreva-Remote-Pilot-Setup.cmd.in') -Raw
$readme = Get-Content -LiteralPath (Join-Path $Root 'packaging\pilot\README.md') -Raw
$policy = Get-Content -LiteralPath (Join-Path $Root 'config\antreva-client-policy.json') -Raw | ConvertFrom-Json

$checks = @(
    @{ Name = 'manual workflow release title'; Passed = $releaseWorkflow.Contains("release_title: $expectedReleaseTitle") },
    @{ Name = 'workflow artifact name'; Passed = $workflow.Contains("name: $expectedBundleName") },
    @{ Name = 'workflow zip path'; Passed = $workflow.Contains("artifacts/$expectedZipName") },
    @{ Name = 'workflow checksum path'; Passed = $workflow.Contains("artifacts/$expectedChecksumName") },
    @{ Name = 'ordinary workflow read-only contents'; Passed = $workflow.Contains('contents: read') },
    @{ Name = 'ordinary workflow 30-day retention'; Passed = $workflow.Contains('retention-days: 30') },
    @{ Name = 'manual workflow release tag'; Passed = $releaseWorkflow.Contains("release_tag: $expectedTagName") },
    @{ Name = 'manual workflow protected environment'; Passed = $releaseWorkflow.Contains('environment: client-release') },
    @{ Name = 'manual workflow signer verification'; Passed = $releaseWorkflow.Contains('ANTREVA_SIGNER_THUMBPRINT') },
    @{ Name = 'manual workflow certification evidence'; Passed = $releaseWorkflow.Contains('certification_evidence_sha256') },
    @{ Name = 'build script bundle name'; Passed = $buildScript.Contains('$BundleName = "Antreva-Desk-$AntrevaDeskVersion-Windows"') },
    @{ Name = 'build script zip output'; Passed = $buildScript.Contains('$ZipPath = Join-Path $OutputDir "$BundleName.zip"') },
    @{ Name = 'setup command version placeholder'; Passed = $setupCmd.Contains('set "ANTREVA_VERSION=@@ANTREVA_VERSION@@"') },
    @{ Name = 'setup command product'; Passed = $setupCmd.Contains('Antreva Desk %ANTREVA_VERSION% managed-access setup') },
    @{ Name = 'pilot README title'; Passed = $readme.Contains("# $expectedReleaseTitle Managed Access") },
    @{ Name = 'policy product name'; Passed = $policy.productName -eq $expectedProduct }
)

foreach ($check in $checks) {
    if (-not $check.Passed) {
        throw "Antreva Desk release naming check failed: $($check.Name)"
    }
}

$combined = @($workflow, $releaseWorkflow, $buildScript) -join "`n"
if ($combined.Contains($legacyBundleName)) {
    throw "Antreva Desk release naming check failed: legacy bundle name is still present."
}
if ($combined.Contains($retiredGuiName)) {
    throw "Antreva Desk release naming check failed: retired GUI installer is still present on the active release surface."
}
if ($releaseWorkflow.Contains("release_tag: $previousReleaseTag")) {
    throw "Antreva Desk release naming check failed: the manual workflow still targets the previous release tag."
}
foreach ($forbiddenReleaseOperation in @('gh release create', 'gh release delete', 'git tag -f', 'git push -f')) {
    if ($workflow.Contains($forbiddenReleaseOperation)) {
        throw "Antreva Desk release naming check failed: ordinary workflow contains '$forbiddenReleaseOperation'."
    }
}
foreach ($forbiddenMutation in @('gh release delete', 'git tag -f', 'git push -f')) {
    if ($releaseWorkflow.Contains($forbiddenMutation)) {
        throw "Antreva Desk release naming check failed: manual workflow contains destructive mutation '$forbiddenMutation'."
    }
}

Write-Output "Antreva Desk release naming verification passed."
