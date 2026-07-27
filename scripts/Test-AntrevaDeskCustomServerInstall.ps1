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

$generatedSetupPath = Join-Path ([System.IO.Path]::GetTempPath()) "AntrevaDesk-CustomServer-$PID.cmd"
& (Join-Path $ScriptDir 'New-AntrevaDeskInstaller.ps1') `
    -PolicyPath (Join-Path $Root 'config\antreva-client-policy.json') `
    -TemplatePath (Join-Path $Root 'packaging\pilot\Antreva-Remote-Pilot-Setup.cmd.in') `
    -OutputPath $generatedSetupPath `
    -Version '1.0.4' | Out-Null
$packagedSetup = Get-Content -LiteralPath $generatedSetupPath -Raw
Remove-Item -LiteralPath $generatedSetupPath -Force
$repositoryTest = Read-RepoFile 'scripts\Test-Repository.ps1'
$policy = Get-Content -LiteralPath (Join-Path $Root 'config\antreva-client-policy.json') -Raw | ConvertFrom-Json

foreach ($expected in @(
    'INSTALL_VERIFY_COUNT',
    '180-second completion timeout',
    'AntrevaDesk-Elevate.vbs',
    '--elevated',
    'AntrevaDesk-Setup.log',
    '%ProgramData%\AntrevaDesk\Logs',
    'Setup did not finish successfully',
    'RustDesk.toml',
    'RustDesk daemon did not acknowledge',
    'AntrevaDesk-VerifyConfig.vbs'
)) {
    Assert-Contains -Name 'Command Prompt setup reliability gate' -Text $packagedSetup -Expected $expected
}

foreach ($expected in @('--config', '%RUSTDESK_CONFIG_NAME%', 'rustdesk-host=%SERVER_HOST%', '--option "%~1"', 'VerifyRustDeskOption')) {
    Assert-Contains -Name 'packaged custom server import' -Text $packagedSetup -Expected $expected
}

foreach ($expected in @(
    'RustDesk2.toml',
    'VerifyServiceProfileOptions',
    '"custom-rendezvous-server" "104.184.67.190"',
    '"relay-server" "104.184.67.190"',
    '"key" "YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg="',
    'did not persist exactly'
)) {
    Assert-Contains -Name 'persisted custom server verification' -Text $packagedSetup -Expected $expected
}

foreach ($property in $policy.rustdeskOptions.PSObject.Properties) {
    $expectedValue = [string]$property.Value
    $expectedCommand = "call :SetRustDeskOption `"$($property.Name)`" `"$expectedValue`""
    Assert-Contains -Name "managed option $($property.Name)" -Text $packagedSetup -Expected $expectedCommand
}

foreach ($unexpected in @('powershell.exe', '.ps1', 'manual server')) {
    Assert-NotContains -Name 'zero-PowerShell configured install' -Text $packagedSetup -Unexpected $unexpected
}
Assert-Contains -Name 'repository test wiring' -Text $repositoryTest -Expected 'Test-AntrevaDeskCustomServerInstall.ps1'
Assert-Contains -Name 'payload validation test wiring' -Text $repositoryTest -Expected 'Test-AntrevaDeskPayloadValidation.ps1'

Write-Output 'Antreva Desk custom server install verification passed.'
