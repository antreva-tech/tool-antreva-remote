[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RustDeskExe,

    [string]$PolicyPath,
    [switch]$AllowPlaceholders
)

$ErrorActionPreference = 'Stop'

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if ([string]::IsNullOrWhiteSpace($PolicyPath)) {
    $PolicyPath = Join-Path $ScriptDir '..\config\antreva-client-policy.json'
}

& (Join-Path $ScriptDir 'Validate-AntrevaRemote.ps1') -PolicyPath $PolicyPath -AllowPlaceholders:$AllowPlaceholders

if (-not (Test-Path -LiteralPath $RustDeskExe)) {
    throw "RustDesk executable not found: $RustDeskExe"
}

$policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
$options = $policy.rustdeskOptions

function Get-RustDeskOption {
    param(
        [Parameter(Mandatory = $true)][string]$RustDeskExe,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $output = & $RustDeskExe --option $Name 2>&1
    $text = ($output | Out-String).Trim()
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Failed to read RustDesk option '$Name' with exit code $LASTEXITCODE. $text"
    }
    if ($text -match 'Installation and administrative privileges required|Settings are disabled') {
        throw "Failed to read RustDesk option '$Name'. $text"
    }

    return $text
}

function Assert-RustDeskOption {
    param(
        [Parameter(Mandatory = $true)][string]$RustDeskExe,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ExpectedValue
    )

    $actual = ''
    $deadline = (Get-Date).AddSeconds(15)
    while ((Get-Date) -lt $deadline) {
        $actual = Get-RustDeskOption -RustDeskExe $RustDeskExe -Name $Name
        if ($actual -eq $ExpectedValue) {
            return
        }

        Start-Sleep -Seconds 1
    }

    throw "RustDesk option '$Name' did not verify. Expected '$ExpectedValue' but got '$actual'."
}

function Assert-RustDeskServerOptions {
    param(
        [Parameter(Mandatory = $true)][string]$RustDeskExe,
        [Parameter(Mandatory = $true)]$Options
    )

    Assert-RustDeskOption -RustDeskExe $RustDeskExe -Name 'custom-rendezvous-server' -ExpectedValue ([string]$Options.'custom-rendezvous-server')
    Assert-RustDeskOption -RustDeskExe $RustDeskExe -Name 'relay-server' -ExpectedValue ([string]$Options.'relay-server')
    Assert-RustDeskOption -RustDeskExe $RustDeskExe -Name 'key' -ExpectedValue ([string]$Options.key)
}

foreach ($property in $options.PSObject.Properties) {
    $name = $property.Name
    $value = [string]$property.Value
    Write-Output "Applying RustDesk option: $name"
    $output = & $RustDeskExe --option $name $value 2>&1
    $text = ($output | Out-String).Trim()
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Failed to apply RustDesk option '$name' with exit code $LASTEXITCODE. $text"
    }
    if ($text -match 'Installation and administrative privileges required|Settings are disabled') {
        throw "Failed to apply RustDesk option '$name'. $text"
    }
}

Assert-RustDeskServerOptions -RustDeskExe $RustDeskExe -Options $options

Write-Output "Antreva Desk client policy applied."
