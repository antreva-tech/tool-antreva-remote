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

function Assert-NotContains {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Unexpected
    )

    if ($Text.Contains($Unexpected)) {
        throw "Custom server install check failed: $Name must not contain '$Unexpected'."
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

foreach ($script in @($packagedSetup, $repoSetup, $applyPolicy)) {
    Assert-Contains -Name 'RustDesk GUI CLI nullable exit code handling' -Text $script -Expected '$null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0'
}

foreach ($script in @($packagedSetup, $repoSetup)) {
    Assert-Contains -Name 'permanent password config path helper' -Text $script -Expected 'Get-RustDeskMainConfigPath'
    Assert-Contains -Name 'permanent password config parser' -Text $script -Expected 'Read-RustDeskMainConfig'
    Assert-Contains -Name 'permanent password persisted state assertion' -Text $script -Expected 'Assert-RustDeskPermanentPasswordState'
    Assert-Contains -Name 'permanent password persisted config file' -Text $script -Expected 'RustDesk.toml'
    Assert-NotContains -Name 'permanent password stdout Done requirement' -Text $script -Unexpected "text -notmatch 'Done!'"
}

foreach ($expected in @('Import-RustDeskCustomServerConfig', '--config', '$RustDeskConfigName', 'rustdesk-host=$($ManagedOptions')) {
    Assert-Contains -Name 'packaged custom server import' -Text $packagedSetup -Expected $expected
}

foreach ($script in @($packagedSetup, $applyPolicy)) {
    Assert-Contains -Name 'custom server config path helper' -Text $script -Expected 'Get-RustDeskConfigPath'
    Assert-Contains -Name 'custom server config parser' -Text $script -Expected 'Read-RustDeskConfigOptions'
    Assert-Contains -Name 'custom server config assertion helper' -Text $script -Expected 'Assert-RustDeskConfigOption'
    Assert-Contains -Name 'custom server relay fallback helper' -Text $script -Expected 'Assert-RustDeskRelayOption'
    Assert-Contains -Name 'custom server blank relay same-host fallback' -Text $script -Expected 'Test-RustDeskBlankRelayUsesCustomServerFallback'
    Assert-Contains -Name 'custom server relay fallback message' -Text $script -Expected 'relay-server is using the custom rendezvous server fallback'
    Assert-Contains -Name 'custom server persisted config file' -Text $script -Expected 'RustDesk2.toml'
    Assert-Contains -Name 'custom server options section parser' -Text $script -Expected "-eq 'options'"
    Assert-Contains -Name 'custom rendezvous persisted config verification' -Text $script -Expected 'custom-rendezvous-server'
    Assert-Contains -Name 'relay persisted config verification' -Text $script -Expected 'relay-server'
    Assert-Contains -Name 'key persisted config verification' -Text $script -Expected 'Assert-RustDeskConfigOption'
    Assert-Contains -Name 'custom server-only persisted config verification' -Text $script -Expected 'Assert-RustDeskServerOptions'
    Assert-NotContains -Name 'custom server verification via CLI readback' -Text $script -Unexpected 'Get-RustDeskOption -RustDeskExe $RustDeskExe -Name $Name'
    Assert-NotContains -Name 'custom server strict relay TOML requirement' -Text $script -Unexpected "Assert-RustDeskConfigOption -ConfigOptions `$configOptions -ConfigPath `$configPath -Name 'relay-server'"
}

Assert-NotContains -Name 'packaged all-option verification' -Text $packagedSetup -Unexpected 'Assert-RustDeskManagedOptions'
Assert-Contains -Name 'repository test wiring' -Text $repositoryTest -Expected 'Test-AntrevaDeskCustomServerInstall.ps1'

Write-Output 'Antreva Desk custom server install verification passed.'
