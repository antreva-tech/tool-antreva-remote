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
