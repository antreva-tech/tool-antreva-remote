function Normalize-AntrevaDeskCertificateThumbprint {
    param([string]$Thumbprint)

    return ([string]$Thumbprint -replace '\s', '').ToUpperInvariant()
}

function Get-AntrevaDeskSha256Hash {
    param([Parameter(Mandatory = $true)][string]$Path)

    $sha256 = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hashBytes = $sha256.ComputeHash($stream)
        return -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
    } finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
        if ($null -ne $sha256) {
            $sha256.Dispose()
        }
    }
}

function Get-AntrevaDeskSignatureDecision {
    param(
        [Parameter(Mandatory = $true)][string]$SignatureStatus,
        [string]$ActualSignerThumbprint,
        [Parameter(Mandatory = $true)][string]$ExpectedSignerThumbprint,
        [string[]]$ChainStatuses = @()
    )

    $actualThumbprint = Normalize-AntrevaDeskCertificateThumbprint -Thumbprint $ActualSignerThumbprint
    $expectedThumbprint = Normalize-AntrevaDeskCertificateThumbprint -Thumbprint $ExpectedSignerThumbprint
    if ([string]::IsNullOrWhiteSpace($actualThumbprint) -or $actualThumbprint -ne $expectedThumbprint) {
        return [pscustomobject]@{
            Allowed = $false
            Mode = 'Blocked'
            Reason = 'The embedded payload was not signed by the pinned RustDesk publisher certificate.'
        }
    }

    if ($SignatureStatus -eq 'Valid') {
        return [pscustomobject]@{
            Allowed = $true
            Mode = 'Trusted'
            Reason = 'Windows validated the complete Authenticode trust chain.'
        }
    }

    if ($SignatureStatus -ne 'NotTrusted') {
        return [pscustomobject]@{
            Allowed = $false
            Mode = 'Blocked'
            Reason = "Windows reported Authenticode status '$SignatureStatus'."
        }
    }

    $allowedChainStatuses = @{
        UntrustedRoot = $true
        PartialChain = $true
    }
    $normalizedChainStatuses = @(
        $ChainStatuses |
            ForEach-Object { ([string]$_) -split ',' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    if ($normalizedChainStatuses.Count -eq 0) {
        return [pscustomobject]@{
            Allowed = $false
            Mode = 'Blocked'
            Reason = 'Windows did not provide a missing-root or partial-chain reason for the untrusted signature.'
        }
    }

    foreach ($chainStatus in $normalizedChainStatuses) {
        if (-not $allowedChainStatuses.ContainsKey($chainStatus)) {
            return [pscustomobject]@{
                Allowed = $false
                Mode = 'Blocked'
                Reason = "The Authenticode chain contains disallowed status '$chainStatus'."
            }
        }
    }

    return [pscustomobject]@{
        Allowed = $true
        Mode = 'PinnedOffline'
        Reason = "Windows could not reach a trusted root ($($normalizedChainStatuses -join ', ')); the exact pinned payload hash and publisher certificate matched."
    }
}

function Get-AntrevaDeskCertificateChainStatuses {
    param([Parameter(Mandatory = $true)][Security.Cryptography.X509Certificates.X509Certificate2]$SignerCertificate)

    $chain = New-Object Security.Cryptography.X509Certificates.X509Chain
    try {
        $chain.ChainPolicy.RevocationMode = [Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
        $chain.ChainPolicy.VerificationFlags = [Security.Cryptography.X509Certificates.X509VerificationFlags]::NoFlag
        [void]$chain.Build($SignerCertificate)
        return @($chain.ChainStatus | ForEach-Object { $_.Status.ToString() })
    } finally {
        $chain.Reset()
    }
}

function Assert-AntrevaDeskPayloadAuthenticity {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256,
        [Parameter(Mandatory = $true)][string]$ExpectedSignerThumbprint
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "AntrevaDesk payload is missing: $Path"
    }

    $actualHash = Get-AntrevaDeskSha256Hash -Path $Path
    if ($actualHash -ne $ExpectedSha256.ToLowerInvariant()) {
        throw "AntrevaDesk payload hash mismatch. Expected $ExpectedSha256 but got $actualHash."
    }

    $signature = Get-AuthenticodeSignature -FilePath $Path
    $signatureStatus = $signature.Status.ToString()
    $signerThumbprint = if ($null -ne $signature.SignerCertificate) {
        [string]$signature.SignerCertificate.Thumbprint
    } else {
        ''
    }
    $chainStatuses = @()
    if ($signatureStatus -eq 'NotTrusted' -and $null -ne $signature.SignerCertificate) {
        $chainStatuses = Get-AntrevaDeskCertificateChainStatuses -SignerCertificate $signature.SignerCertificate
    }

    $decision = Get-AntrevaDeskSignatureDecision `
        -SignatureStatus $signatureStatus `
        -ActualSignerThumbprint $signerThumbprint `
        -ExpectedSignerThumbprint $ExpectedSignerThumbprint `
        -ChainStatuses $chainStatuses

    if (-not $decision.Allowed) {
        throw "AntrevaDesk payload signature validation failed. $($decision.Reason) $($signature.StatusMessage)"
    }
    if ($decision.Mode -eq 'PinnedOffline') {
        Write-Warning "Offline-safe payload validation accepted the pinned RustDesk payload. $($decision.Reason)"
    } else {
        Write-Output $decision.Reason
    }

    return $decision
}
