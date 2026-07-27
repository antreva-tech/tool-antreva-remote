[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PolicyPath,
    [Parameter(Mandatory = $true)][string]$TemplatePath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [string]$Version = '1.0.4',
    [string]$X64PayloadHash = 'f0053229fa2a2459c8b86f326c3e7423018a72f010f9758dc21be171b112d1b2',
    [string]$X86PayloadHash = '10a14578ed3adbab66bfe5c8daa0d49d07e002d48f69f303966ea349f58dfea7'
)

$ErrorActionPreference = 'Stop'

function Assert-CmdSafeValue {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowEmptyString()][string]$Value,
        [switch]$AllowEmpty
    )

    if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($Value)) {
        throw "Policy value '$Name' must not be blank."
    }
    if ($Value -match '[\x00-\x1f\x7f"&|<>^%!]' -or $Value -notmatch '^[A-Za-z0-9@._:+/=\-]*$') {
        throw "Policy value '$Name' contains characters that are unsafe for the generated Command Prompt installer."
    }
}

$policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
$properties = @($policy.rustdeskOptions.PSObject.Properties)
if ($properties.Count -eq 0) {
    throw 'Policy rustdeskOptions must contain managed options.'
}

$requiredNames = @('custom-rendezvous-server', 'relay-server', 'key')
foreach ($requiredName in $requiredNames) {
    if ($requiredName -notin $properties.Name) {
        throw "Policy rustdeskOptions is missing required option '$requiredName'."
    }
}

$configureLines = [System.Collections.Generic.List[string]]::new()
$verifyCliLines = [System.Collections.Generic.List[string]]::new()
$verifyConfigArguments = [System.Collections.Generic.List[string]]::new()

foreach ($property in $properties) {
    $name = [string]$property.Name
    $value = [string]$property.Value
    if ($name -notmatch '^[a-z0-9-]+$') {
        throw "Policy option name '$name' is unsafe for the generated Command Prompt installer."
    }
    Assert-CmdSafeValue -Name $name -Value $value
    $configureLines.Add("call :SetRustDeskOption `"$name`" `"$value`"")
    $configureLines.Add('if errorlevel 1 exit /b 1')
    $verifyCliLines.Add("call :VerifyRustDeskOption `"$name`" `"$value`"")
    $verifyCliLines.Add('if errorlevel 1 exit /b 1')
    $verifyConfigArguments.Add("`"$name`" `"$value`"")
}

$serverHost = [string]$policy.rustdeskOptions.'custom-rendezvous-server'
$relayHost = [string]$policy.rustdeskOptions.'relay-server'
$serverKey = [string]$policy.rustdeskOptions.key
Assert-CmdSafeValue -Name 'custom-rendezvous-server' -Value $serverHost
Assert-CmdSafeValue -Name 'relay-server' -Value $relayHost
Assert-CmdSafeValue -Name 'key' -Value $serverKey
foreach ($payloadHash in @($X64PayloadHash, $X86PayloadHash)) {
    if ($payloadHash -notmatch '^[a-fA-F0-9]{64}$') {
        throw "Payload SHA-256 '$payloadHash' is invalid."
    }
}

$template = Get-Content -LiteralPath $TemplatePath -Raw
$replacements = [ordered]@{
    '@@ANTREVA_VERSION@@' = $Version
    '@@SERVER_HOST@@' = $serverHost
    '@@RELAY_HOST@@' = $relayHost
    '@@SERVER_KEY@@' = $serverKey
    '@@X64_PAYLOAD_HASH@@' = $X64PayloadHash.ToUpperInvariant()
    '@@X86_PAYLOAD_HASH@@' = $X86PayloadHash.ToUpperInvariant()
    '@@CONFIGURE_OPTIONS@@' = ($configureLines -join "`r`n")
    '@@VERIFY_CLI_OPTIONS@@' = ($verifyCliLines -join "`r`n")
    '@@VERIFY_CONFIG_ARGS@@' = ($verifyConfigArguments -join ' ')
}

foreach ($replacement in $replacements.GetEnumerator()) {
    if (-not $template.Contains($replacement.Key)) {
        throw "Installer template is missing placeholder $($replacement.Key)."
    }
    $template = $template.Replace($replacement.Key, $replacement.Value)
}
if ($template -match '@@[A-Z0-9_]+@@') {
    throw "Installer template still contains unresolved placeholder '$($Matches[0])'."
}

$parent = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}
Set-Content -LiteralPath $OutputPath -Value $template -Encoding ASCII
Write-Output "Generated Command Prompt installer: $OutputPath"
