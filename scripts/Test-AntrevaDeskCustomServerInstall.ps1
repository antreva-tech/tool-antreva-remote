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

$packagedSetup = Read-RepoFile 'packaging\pilot\Antreva-Remote-Pilot-Setup.cmd'
$repositoryTest = Read-RepoFile 'scripts\Test-Repository.ps1'
$policy = Get-Content -LiteralPath (Join-Path $Root 'config\antreva-client-policy.json') -Raw | ConvertFrom-Json

foreach ($expected in @(
    'INSTALL_WAIT_COUNT',
    'Waiting for installer finalization',
    'ShellExecute WScript.Arguments',
    '--elevated',
    'AntrevaDesk-Setup.log',
    '%ProgramData%\AntrevaDesk\Logs',
    'Setup did not finish successfully',
    'RustDesk.toml',
    '^[ ]*password[ ]*=',
    '^[ ]*salt[ ]*='
)) {
    Assert-Contains -Name 'Command Prompt setup reliability gate' -Text $packagedSetup -Expected $expected
}

foreach ($expected in @('--config', '%RUSTDESK_CONFIG_NAME%', 'rustdesk-host=%SERVER_HOST%', '--option "%~1"', 'VerifyRustDeskOption')) {
    Assert-Contains -Name 'packaged custom server import' -Text $packagedSetup -Expected $expected
}

foreach ($expected in @(
    'RustDesk2.toml',
    'FindRustDeskConfig',
    'VerifyConfigLine',
    '"custom-rendezvous-server" "%SERVER_HOST%" "required"',
    '"relay-server" "%SERVER_HOST%" "allow-blank"',
    '"key" "%SERVER_KEY%" "required"',
    'does not contain the required'
)) {
    Assert-Contains -Name 'persisted custom server verification' -Text $packagedSetup -Expected $expected
}

foreach ($property in $policy.rustdeskOptions.PSObject.Properties) {
    $expectedValue = switch ($property.Name) {
        'custom-rendezvous-server' { '%SERVER_HOST%' }
        'relay-server' { '%SERVER_HOST%' }
        'key' { '%SERVER_KEY%' }
        default { [string]$property.Value }
    }
    $expectedCommand = "call :SetRustDeskOption `"$($property.Name)`" `"$expectedValue`""
    Assert-Contains -Name "managed option $($property.Name)" -Text $packagedSetup -Expected $expectedCommand
}

foreach ($unexpected in @('powershell.exe', '.ps1', 'manual server')) {
    Assert-NotContains -Name 'zero-PowerShell configured install' -Text $packagedSetup -Unexpected $unexpected
}
Assert-Contains -Name 'repository test wiring' -Text $repositoryTest -Expected 'Test-AntrevaDeskCustomServerInstall.ps1'
Assert-Contains -Name 'payload validation test wiring' -Text $repositoryTest -Expected 'Test-AntrevaDeskPayloadValidation.ps1'

Write-Output 'Antreva Desk custom server install verification passed.'
