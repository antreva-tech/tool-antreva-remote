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

function Get-RustDeskConfigPath {
    $candidateRoots = @(
        [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData),
        $env:APPDATA,
        [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData),
        $env:ProgramData,
        [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData),
        $env:LOCALAPPDATA
    )
    $candidates = @()
    foreach ($root in $candidateRoots) {
        if (-not [string]::IsNullOrWhiteSpace($root)) {
            $candidates += (Join-Path $root 'RustDesk\config\RustDesk2.toml')
        }
    }

    $seen = @{}
    foreach ($candidate in $candidates) {
        if ($seen.ContainsKey($candidate)) {
            continue
        }
        $seen[$candidate] = $true
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    throw "RustDesk2.toml was not found. Checked: $($seen.Keys -join '; ')"
}

function Read-RustDeskConfigOptions {
    param([Parameter(Mandatory = $true)][string]$Path)

    $options = @{}
    $inOptionsSection = $false
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\[(.+)\]$') {
            $inOptionsSection = ($matches[1] -eq 'options')
            continue
        }
        if (-not $inOptionsSection -or [string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }
        if ($trimmed -match '^\s*([^=\s]+)\s*=\s*(.*?)\s*$') {
            $name = $matches[1]
            $value = $matches[2].Trim()
            if ($value.Length -ge 2) {
                if (($value.StartsWith("'") -and $value.EndsWith("'")) -or ($value.StartsWith('"') -and $value.EndsWith('"'))) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
            }
            $options[$name] = $value
        }
    }

    return $options
}

function Assert-RustDeskConfigOption {
    param(
        [Parameter(Mandatory = $true)][hashtable]$ConfigOptions,
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ExpectedValue
    )

    $actual = ''
    if ($ConfigOptions.ContainsKey($Name)) {
        $actual = [string]$ConfigOptions[$Name]
    }
    if ($actual -ne $ExpectedValue) {
        throw "RustDesk option '$Name' did not verify in RustDesk2.toml at $ConfigPath. Expected '$ExpectedValue' but got '$actual'."
    }
}

function Assert-RustDeskServerOptions {
    param(
        [Parameter(Mandatory = $true)][string]$RustDeskExe,
        [Parameter(Mandatory = $true)]$Options
    )

    $lastError = ''
    $deadline = (Get-Date).AddSeconds(15)
    while ((Get-Date) -lt $deadline) {
        try {
            $configPath = Get-RustDeskConfigPath
            $configOptions = Read-RustDeskConfigOptions -Path $configPath
            Assert-RustDeskConfigOption -ConfigOptions $configOptions -ConfigPath $configPath -Name 'custom-rendezvous-server' -ExpectedValue ([string]$Options.'custom-rendezvous-server')
            Assert-RustDeskConfigOption -ConfigOptions $configOptions -ConfigPath $configPath -Name 'relay-server' -ExpectedValue ([string]$Options.'relay-server')
            Assert-RustDeskConfigOption -ConfigOptions $configOptions -ConfigPath $configPath -Name 'key' -ExpectedValue ([string]$Options.key)
            Write-Output "Verified Antreva server configuration in RustDesk2.toml: $configPath"
            return
        } catch {
            $lastError = $_.Exception.Message
        }

        Start-Sleep -Seconds 1
    }

    throw $lastError
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
