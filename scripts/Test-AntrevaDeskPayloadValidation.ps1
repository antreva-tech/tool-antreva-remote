[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = Resolve-Path (Join-Path $ScriptDir '..')
$ValidationScript = Join-Path $Root 'packaging\pilot\AntrevaDesk-PayloadValidation.ps1'
$ExpectedSignerThumbprint = '4230334F8A7DD84E50D0273EF379E8B4A82F5DA5'

if (-not (Test-Path -LiteralPath $ValidationScript)) {
    throw "Required AntrevaDesk payload validation helper is missing: $ValidationScript"
}

. $ValidationScript

function Assert-Decision {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$SignatureStatus,
        [Parameter(Mandatory = $true)][string]$ActualSignerThumbprint,
        [string[]]$ChainStatuses = @(),
        [Parameter(Mandatory = $true)][bool]$ExpectedAllowed,
        [Parameter(Mandatory = $true)][string]$ExpectedMode
    )

    $decision = Get-AntrevaDeskSignatureDecision `
        -SignatureStatus $SignatureStatus `
        -ActualSignerThumbprint $ActualSignerThumbprint `
        -ExpectedSignerThumbprint $ExpectedSignerThumbprint `
        -ChainStatuses $ChainStatuses

    if ($decision.Allowed -ne $ExpectedAllowed) {
        throw "Payload validation check failed: $Name expected Allowed=$ExpectedAllowed but got $($decision.Allowed)."
    }
    if ($decision.Mode -ne $ExpectedMode) {
        throw "Payload validation check failed: $Name expected Mode='$ExpectedMode' but got '$($decision.Mode)'."
    }
}

Assert-Decision `
    -Name 'fully trusted payload' `
    -SignatureStatus 'Valid' `
    -ActualSignerThumbprint $ExpectedSignerThumbprint `
    -ExpectedAllowed $true `
    -ExpectedMode 'Trusted'

foreach ($chainStatus in @('UntrustedRoot', 'PartialChain')) {
    Assert-Decision `
        -Name "offline-safe $chainStatus payload" `
        -SignatureStatus 'NotTrusted' `
        -ActualSignerThumbprint $ExpectedSignerThumbprint `
        -ChainStatuses @($chainStatus) `
        -ExpectedAllowed $true `
        -ExpectedMode 'PinnedOffline'
}

foreach ($chainStatus in @('UntrustedRoot', 'PartialChain')) {
    Assert-Decision `
        -Name "PowerShell 5.1 UnknownError $chainStatus payload" `
        -SignatureStatus 'UnknownError' `
        -ActualSignerThumbprint $ExpectedSignerThumbprint `
        -ChainStatuses @($chainStatus) `
        -ExpectedAllowed $true `
        -ExpectedMode 'PinnedOffline'
}

Assert-Decision `
    -Name 'combined allowed chain flags' `
    -SignatureStatus 'NotTrusted' `
    -ActualSignerThumbprint $ExpectedSignerThumbprint `
    -ChainStatuses @('UntrustedRoot, PartialChain') `
    -ExpectedAllowed $true `
    -ExpectedMode 'PinnedOffline'

Assert-Decision `
    -Name 'mixed unsafe chain status' `
    -SignatureStatus 'NotTrusted' `
    -ActualSignerThumbprint $ExpectedSignerThumbprint `
    -ChainStatuses @('UntrustedRoot', 'NotTimeValid') `
    -ExpectedAllowed $false `
    -ExpectedMode 'Blocked'

Assert-Decision `
    -Name 'UnknownError with unsafe chain status' `
    -SignatureStatus 'UnknownError' `
    -ActualSignerThumbprint $ExpectedSignerThumbprint `
    -ChainStatuses @('UntrustedRoot', 'NotTimeValid') `
    -ExpectedAllowed $false `
    -ExpectedMode 'Blocked'

Assert-Decision `
    -Name 'missing chain failure detail' `
    -SignatureStatus 'NotTrusted' `
    -ActualSignerThumbprint $ExpectedSignerThumbprint `
    -ChainStatuses @() `
    -ExpectedAllowed $false `
    -ExpectedMode 'Blocked'

foreach ($signatureStatus in @('HashMismatch', 'NotSigned', 'UnknownError')) {
    Assert-Decision `
        -Name "blocked signature status $signatureStatus" `
        -SignatureStatus $signatureStatus `
        -ActualSignerThumbprint $ExpectedSignerThumbprint `
        -ExpectedAllowed $false `
        -ExpectedMode 'Blocked'
}

Assert-Decision `
    -Name 'unexpected publisher certificate' `
    -SignatureStatus 'Valid' `
    -ActualSignerThumbprint '0000000000000000000000000000000000000000' `
    -ExpectedAllowed $false `
    -ExpectedMode 'Blocked'

$hashMismatchDetected = $false
try {
    Assert-AntrevaDeskPayloadAuthenticity `
        -Path $PSCommandPath `
        -ExpectedSha256 ('0' * 64) `
        -ExpectedSignerThumbprint $ExpectedSignerThumbprint | Out-Null
} catch {
    $hashMismatchDetected = $_.Exception.Message -match 'hash mismatch'
}
if (-not $hashMismatchDetected) {
    throw 'Payload validation check failed: altered payload hash was not rejected before signature validation.'
}

$unsignedPayloadDetected = $false
try {
    Assert-AntrevaDeskPayloadAuthenticity `
        -Path $PSCommandPath `
        -ExpectedSha256 (Get-AntrevaDeskSha256Hash -Path $PSCommandPath) `
        -ExpectedSignerThumbprint $ExpectedSignerThumbprint | Out-Null
} catch {
    $unsignedPayloadDetected = $_.Exception.Message -match 'pinned RustDesk publisher certificate'
}
if (-not $unsignedPayloadDetected) {
    throw 'Payload validation check failed: unsigned payload was not rejected.'
}

$foreignSignedPayload = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (Test-Path -LiteralPath $foreignSignedPayload) {
    $foreignPublisherDetected = $false
    try {
        Assert-AntrevaDeskPayloadAuthenticity `
            -Path $foreignSignedPayload `
            -ExpectedSha256 (Get-AntrevaDeskSha256Hash -Path $foreignSignedPayload) `
            -ExpectedSignerThumbprint $ExpectedSignerThumbprint | Out-Null
    } catch {
        $foreignPublisherDetected = $_.Exception.Message -match 'pinned RustDesk publisher certificate'
    }
    if (-not $foreignPublisherDetected) {
        throw 'Payload validation check failed: payload signed by an unexpected publisher was not rejected.'
    }
}

Write-Output 'Antreva Desk payload validation verification passed.'
