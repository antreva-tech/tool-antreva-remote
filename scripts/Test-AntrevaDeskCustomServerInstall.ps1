[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = Resolve-Path (Join-Path $ScriptDir '..')

function Read-RepoFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = Join-Path $Root $Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "Required custom server install file is missing: $Path"
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
        throw "Custom server install check failed: $Name must contain '$Expected'."
    }
}

$packagedSetup = Read-RepoFile 'packaging\pilot\Configure-And-Launch-Antreva-Remote-Pilot.ps1'
$repoSetup = Read-RepoFile 'scripts\Setup-WindowsPilot.ps1'
$applyPolicy = Read-RepoFile 'scripts\Apply-AntrevaClientPolicy.ps1'
$repositoryTest = Read-RepoFile 'scripts\Test-Repository.ps1'

foreach ($script in @($packagedSetup, $repoSetup)) {
    Assert-Contains -Name 'installer finalization wait' -Text $script -Expected '$installCompletionDeadline'
    Assert-Contains -Name 'installer finalization message' -Text $script -Expected 'Waiting for RustDesk installer finalization'
    Assert-Contains -Name 'elevated setup wrapper' -Text $script -Expected 'Start-ElevatedSetup'
    Assert-Contains -Name 'setup transcript log' -Text $script -Expected 'AntrevaDesk-Setup.log'
    Assert-Contains -Name 'elevated failure pause' -Text $script -Expected 'Press any key to close this window'
    Assert-Contains -Name 'elevated failure exit code' -Text $script -Expected 'Antreva Desk setup failed with exit code'
}

foreach ($expected in @('Import-RustDeskCustomServerConfig', '--config', 'Split-Path -Leaf $PortableExe')) {
    Assert-Contains -Name 'packaged custom server import' -Text $packagedSetup -Expected $expected
}

foreach ($script in @($packagedSetup, $applyPolicy)) {
    Assert-Contains -Name 'custom server readback helper' -Text $script -Expected 'Assert-RustDeskOption'
    Assert-Contains -Name 'custom rendezvous readback' -Text $script -Expected 'custom-rendezvous-server'
    Assert-Contains -Name 'relay readback' -Text $script -Expected 'relay-server'
    Assert-Contains -Name 'key readback' -Text $script -Expected 'Get-RustDeskOption'
}

Assert-Contains -Name 'packaged managed options verification' -Text $packagedSetup -Expected 'Assert-RustDeskManagedOptions'
Assert-Contains -Name 'repository test wiring' -Text $repositoryTest -Expected 'Test-AntrevaDeskCustomServerInstall.ps1'

Write-Output 'Antreva Desk custom server install verification passed.'
