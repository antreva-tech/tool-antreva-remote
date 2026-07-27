[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = Resolve-Path (Join-Path $ScriptDir '..')

Push-Location $Root
try {
    git submodule status --recursive | Out-Null
    Get-Content -LiteralPath 'config\antreva-client-policy.json' -Raw | ConvertFrom-Json | Out-Null
    & (Join-Path $ScriptDir 'Validate-AntrevaRemote.ps1') -AllowPlaceholders | Out-Null
    & (Join-Path $ScriptDir 'Test-AntrevaDeskReleaseNaming.ps1') | Out-Null
    & (Join-Path $ScriptDir 'Test-AntrevaDeskWindowsSupport.ps1') | Out-Null
    & (Join-Path $ScriptDir 'Test-AntrevaDeskCustomServerInstall.ps1') | Out-Null
    & (Join-Path $ScriptDir 'Test-AntrevaDeskPayloadValidation.ps1') | Out-Null
    & (Join-Path $ScriptDir 'Test-AntrevaDeskInstallerScenarios.ps1') | Out-Null

    $required = @(
        'README.md',
        'infra\office-server\docker-compose.yml',
        'docs\security\MANAGED-ACCESS-POLICY.md',
        'docs\compliance\AGPL-SOURCE-OFFER.md',
        'docs\compliance\RELEASE-CHECKLIST.md',
        'docs\operations\TEST-PLAN.md',
        'scripts\Apply-AntrevaClientPolicy.ps1',
        'scripts\Test-AntrevaDeskReleaseNaming.ps1',
        'scripts\Test-AntrevaDeskWindowsSupport.ps1',
        'scripts\Test-AntrevaDeskCustomServerInstall.ps1',
        'scripts\Test-AntrevaDeskPayloadValidation.ps1',
        'scripts\Test-AntrevaDeskInstallerScenarios.ps1',
        'scripts\New-AntrevaDeskInstaller.ps1',
        'packaging\pilot\AntrevaDesk-PayloadValidation.ps1',
        'packaging\pilot\Antreva-Remote-Pilot-Setup.cmd.in',
        'packaging\pilot\AntrevaDesk-Elevate.vbs',
        'packaging\pilot\AntrevaDesk-ProcessWrapper.vbs',
        'packaging\pilot\AntrevaDesk-VerifyService.vbs',
        'packaging\pilot\AntrevaDesk-VerifyConfig.vbs',
        'scripts\Build-WindowsRelease.ps1'
    )

    foreach ($path in $required) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Required repository file is missing: $path"
        }
    }

    Write-Output "Repository verification passed."
}
finally {
    Pop-Location
}
