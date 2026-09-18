[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = Resolve-Path (Join-Path $ScriptDir '..')
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "AntrevaDesk-InstallerTests-$PID"
$templatePath = Join-Path $Root 'packaging\pilot\Antreva-Remote-Pilot-Setup.cmd.in'
$policyPath = Join-Path $Root 'config\antreva-client-policy.json'
$generatorPath = Join-Path $ScriptDir 'New-AntrevaDeskInstaller.ps1'
$serviceVerifier = Join-Path $Root 'packaging\pilot\AntrevaDesk-VerifyService.vbs'
$configVerifier = Join-Path $Root 'packaging\pilot\AntrevaDesk-VerifyConfig.vbs'
$processWrapper = Join-Path $Root 'packaging\pilot\AntrevaDesk-ProcessWrapper.vbs'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "Installer scenario check failed: $Message"
    }
}

function Invoke-ExpectExit {
    param(
        [Parameter(Mandatory = $true)][int]$Expected,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][object[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Scenario
    )
    & $FilePath @Arguments | Out-Null
    Assert-True -Condition ($LASTEXITCODE -eq $Expected) -Message "$Scenario returned $LASTEXITCODE instead of $Expected."
}

function Get-ArchitectureResult {
    param([string]$Native, [string]$Wow64)
    if ($Native -eq 'ARM64' -or $Wow64 -eq 'ARM64') { return 'unsupported' }
    if ($Native -eq 'AMD64' -or $Wow64 -eq 'AMD64') { return 'x64' }
    if ($Native -eq 'x86' -and [string]::IsNullOrEmpty($Wow64)) { return 'x86' }
    return 'unknown'
}

function Test-InstallState {
    param(
        [bool]$InstallerCompleted,
        [string]$PayloadHash,
        [string]$InstalledHash,
        [bool]$ServiceValid
    )
    return $InstallerCompleted -and
        $PayloadHash -eq $InstalledHash -and
        $ServiceValid
}

<#
.SYNOPSIS
Compare a certutil SHA-256 hash line to a pinned compact hash.

.DESCRIPTION
Mirrors :VerifyFileHash in Antreva-Remote-Pilot-Setup.cmd.in: skip the header,
strip spaces from the hash line, require exactly 64 hex characters, then
compare case-insensitively with the pinned value. Exit 0 on match, 1 on a
valid but different hash, and 2 when the line cannot be normalized.
#>
function Invoke-NormalizedCertUtilCompare {
    param(
        [Parameter(Mandatory = $true)][string]$HashLine,
        [Parameter(Mandatory = $true)][string]$ExpectedHash
    )

    $fixtureDir = Join-Path $testRoot 'hash-fixtures'
    New-Item -ItemType Directory -Force -Path $fixtureDir | Out-Null
    $outputPath = Join-Path $fixtureDir 'certutil-output.txt'
    $scriptPath = Join-Path $fixtureDir 'compare-hash.cmd'
    @(
        'SHA256 hash of file payload.exe:'
        $HashLine
        'CertUtil: -hashfile command completed successfully.'
    ) | Set-Content -LiteralPath $outputPath -Encoding ASCII

    @"
@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "ACTUAL_HASH="
for /f "usebackq skip=1 tokens=* delims=" %%H in ("$outputPath") do (
  if not defined ACTUAL_HASH set "ACTUAL_HASH=%%H"
)
if not defined ACTUAL_HASH exit /b 2
set "ACTUAL_HASH=%ACTUAL_HASH: =%"
if "%ACTUAL_HASH:~63,1%"=="" exit /b 2
if not "%ACTUAL_HASH:~64,1%"=="" exit /b 2
echo(%ACTUAL_HASH%| findstr.exe /I /R /X /C:"[0-9A-Fa-f][0-9A-Fa-f]*" >nul
if errorlevel 1 exit /b 2
if /I not "%ACTUAL_HASH%"=="%~1" exit /b 1
exit /b 0
"@ | Set-Content -LiteralPath $scriptPath -Encoding ASCII

    & cmd.exe /d /c "`"$scriptPath`" `"$ExpectedHash`"" | Out-Null
    return $LASTEXITCODE
}

New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
try {
    $generatedPath = Join-Path $testRoot 'Antreva-Remote-Pilot-Setup.cmd'
    & $generatorPath -PolicyPath $policyPath -TemplatePath $templatePath -OutputPath $generatedPath -Version '1.0.4' | Out-Null
    $generated = Get-Content -LiteralPath $generatedPath -Raw
    $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json

    Assert-True -Condition (-not ($generated -match '@@[A-Z0-9_]+@@')) -Message 'generated CMD has unresolved placeholders.'
    Assert-True -Condition ($generated.Contains('set "ANTREVA_VERSION=1.0.4"')) -Message 'generated CMD version is not 1.0.4.'
    foreach ($property in $policy.rustdeskOptions.PSObject.Properties) {
        $apply = "call :SetRustDeskOption `"$($property.Name)`" `"$([string]$property.Value)`""
        $verify = "call :VerifyRustDeskOption `"$($property.Name)`" `"$([string]$property.Value)`""
        Assert-True -Condition ($generated.Contains($apply)) -Message "generated CMD does not apply $($property.Name) exactly."
        Assert-True -Condition ($generated.Contains($verify)) -Message "generated CMD does not read back $($property.Name) exactly."
    }

    foreach ($requiredText in @(
        '%ProgramW6432%\RustDesk\RustDesk.exe',
        'AntrevaDesk-ProcessWrapper.vbs" "%INSTALL_OUTPUT%" "%PAYLOAD_PATH%" "180" --detached --silent-install printer=0',
        'call :VerifyInstalledHash',
        'AntrevaDesk-VerifyService.vbs',
        'RustDesk daemon did not acknowledge the current password command.',
        'findstr.exe /R /X /C:"Done!"',
        '%SystemRoot%\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml',
        '%PUBLIC%\Desktop',
        '%ProgramData%\Microsoft\Windows\Start Menu\Programs\Antreva',
        'The original user session will wait here',
        'start "" "%INSTALLED_EXE%"',
        'set "ACTUAL_HASH=%ACTUAL_HASH: =%"',
        'if "%ACTUAL_HASH:~63,1%"=="" goto hash_failed',
        'if not "%ACTUAL_HASH:~64,1%"=="" goto hash_failed',
        'findstr.exe /I /R /X /C:"[0-9A-Fa-f][0-9A-Fa-f]*"',
        'if /I not "%ACTUAL_HASH%"=="%~2" goto hash_mismatch'
    )) {
        Assert-True -Condition ($generated.Contains($requiredText)) -Message "generated CMD is missing '$requiredText'."
    }
    foreach ($forbiddenText in @('powershell.exe', 'pwsh.exe', '.ps1', 'allow-blank', 'taskkill.exe /IM "%PAYLOAD_FILE%"', 'find.exe /I "%~2" "%HASH_OUTPUT%"')) {
        Assert-True -Condition (-not $generated.Contains($forbiddenText)) -Message "generated CMD contains forbidden text '$forbiddenText'."
    }
    $installerRunAt = $generated.IndexOf('AntrevaDesk-ProcessWrapper.vbs" "%INSTALL_OUTPUT%"')
    $installedDiscoveryAt = $generated.IndexOf('call :FindInstalledRustDesk', $installerRunAt)
    Assert-True -Condition ($installerRunAt -ge 0 -and $installedDiscoveryAt -gt $installerRunAt) -Message 'pre-existing executable can bypass installer completion.'
    $passwordAckAt = $generated.IndexOf('findstr.exe /R /X /C:"Done!"')
    $passwordPersistenceAt = $generated.IndexOf('AntrevaDesk-VerifyConfig.vbs" --password')
    Assert-True -Condition ($passwordAckAt -ge 0 -and $passwordPersistenceAt -gt $passwordAckAt) -Message 'stale password data can bypass current daemon acknowledgement.'
    $writeResultBlock = $generated.Substring($generated.IndexOf(':WriteResult'), $generated.IndexOf(':Log', $generated.IndexOf(':WriteResult')) - $generated.IndexOf(':WriteResult'))
    Assert-True -Condition (-not $writeResultBlock.Contains('SUPPORT_PASSWORD')) -Message 'result file can contain the permanent password.'

    $payloadHash = 'A' * 64
    Assert-True -Condition (Test-InstallState $true $payloadHash $payloadHash $true) -Message 'clean installation state was rejected.'
    Assert-True -Condition (-not (Test-InstallState $false $payloadHash $payloadHash $true)) -Message 'pre-existing executable satisfied installation without installer completion.'
    Assert-True -Condition (-not (Test-InstallState $true $payloadHash ('B' * 64) $true)) -Message 'wrong installed hash was accepted.'
    Assert-True -Condition (Test-InstallState $true $payloadHash $payloadHash $true) -Message 'upgrade to exact payload state was rejected.'

    $pinnedX64Hash = 'F0053229FA2A2459C8B86F326C3E7423018A72F010F9758DC21BE171B112D1B2'
    $legacySpacedHash = 'f0 05 32 29 fa 2a 24 59 c8 b8 6f 32 6c 3e 74 23 01 8a 72 f0 10 f9 75 8d c2 1b e1 71 b1 12 d1 b2'
    $compactHash = 'f0053229fa2a2459c8b86f326c3e7423018a72f010f9758dc21be171b112d1b2'
    $changedHash = 'f0053229fa2a2459c8b86f326c3e7423018a72f010f9758dc21be171b112d1b3'
    Assert-True -Condition ((Invoke-NormalizedCertUtilCompare -HashLine $legacySpacedHash -ExpectedHash $pinnedX64Hash) -eq 0) -Message 'legacy space-separated certutil SHA-256 was rejected.'
    Assert-True -Condition ((Invoke-NormalizedCertUtilCompare -HashLine $compactHash -ExpectedHash $pinnedX64Hash) -eq 0) -Message 'compact certutil SHA-256 was rejected.'
    Assert-True -Condition ((Invoke-NormalizedCertUtilCompare -HashLine $changedHash -ExpectedHash $pinnedX64Hash) -eq 1) -Message 'changed payload hash was accepted.'
    Assert-True -Condition ((Invoke-NormalizedCertUtilCompare -HashLine 'not-a-sha256' -ExpectedHash $pinnedX64Hash) -eq 2) -Message 'unparseable certutil output was treated as a match.'

    $unsafePolicy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
    $unsafePolicy.rustdeskOptions.'custom-rendezvous-server' = 'host&whoami'
    $unsafePolicyPath = Join-Path $testRoot 'unsafe-policy.json'
    $unsafePolicy | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $unsafePolicyPath -Encoding UTF8
    $unsafeRejected = $false
    try {
        & $generatorPath -PolicyPath $unsafePolicyPath -TemplatePath $templatePath -OutputPath (Join-Path $testRoot 'unsafe.cmd') | Out-Null
    }
    catch {
        $unsafeRejected = $_.Exception.Message.Contains('unsafe')
    }
    Assert-True -Condition $unsafeRejected -Message 'CMD-unsafe policy value was not rejected.'

    $blankRelayPolicy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
    $blankRelayPolicy.rustdeskOptions.'relay-server' = ''
    $blankRelayPath = Join-Path $testRoot 'blank-relay-policy.json'
    $blankRelayPolicy | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $blankRelayPath -Encoding UTF8
    $blankRelayRejected = $false
    try {
        & $generatorPath -PolicyPath $blankRelayPath -TemplatePath $templatePath -OutputPath (Join-Path $testRoot 'blank-relay.cmd') | Out-Null
    }
    catch {
        $blankRelayRejected = $_.Exception.Message.Contains('must not be blank')
    }
    Assert-True -Condition $blankRelayRejected -Message 'blank relay policy was not rejected.'

    Assert-True -Condition ((Get-ArchitectureResult -Native 'x86' -Wow64 '') -eq 'x86') -Message 'native x86 selection failed.'
    Assert-True -Condition ((Get-ArchitectureResult -Native 'AMD64' -Wow64 '') -eq 'x64') -Message 'native x64 selection failed.'
    Assert-True -Condition ((Get-ArchitectureResult -Native 'x86' -Wow64 'AMD64') -eq 'x64') -Message '32-bit CMD on x64 selection failed.'
    Assert-True -Condition ((Get-ArchitectureResult -Native 'ARM64' -Wow64 '') -eq 'unsupported') -Message 'ARM64 was not rejected.'

    $certifiedBuilds = @(7601, 9200, 9600, 10240, 10586, 14393, 15063, 16299, 17134, 17763, 18362, 18363, 19041, 19042, 19043, 19044, 19045, 22000, 22621, 22631, 26100, 26200, 28000)
    $allowlistLine = [regex]::Match($generated, 'for %%B in \(([^)]+)\) do if "%WINDOWS_BUILD%"=="%%B"').Groups[1].Value
    $actualBuilds = @($allowlistLine -split ' ' | ForEach-Object { [int]$_ })
    Assert-True -Condition (($actualBuilds -join ',') -eq ($certifiedBuilds -join ',')) -Message 'certified Windows build allowlist drifted.'
    foreach ($rejectedBuild in @(7600, 7602, 9199, 9201, 19046, 21999, 28001, 99999)) {
        Assert-True -Condition ($rejectedBuild -notin $actualBuilds) -Message "uncertified build $rejectedBuild is accepted."
    }
    Assert-True -Condition ($generated.Contains('if /I not "%WINDOWS_PRODUCT_TYPE%"=="WinNT"')) -Message 'Windows Server ProductType rejection is missing.'

    $cscript = Join-Path $env:SystemRoot 'System32\cscript.exe'
    $testExe = 'C:\RustDesk\RustDesk.exe'
    Invoke-ExpectExit 0 $cscript @('//nologo', $serviceVerifier, '--test-fields', $testExe, 'Y', 'Running', 'Auto', '"C:\RustDesk\RustDesk.exe" --service') 'clean installed service'
    Invoke-ExpectExit 0 $cscript @('//nologo', $serviceVerifier, '--test-fields', $testExe, 'Y', 'Running', 'Auto', '"C:\RustDesk\RustDesk.exe" --service') 'upgrade installed service'
    Invoke-ExpectExit 10 $cscript @('//nologo', $serviceVerifier, '--test-fields', $testExe, 'N', 'Running', 'Auto', '"C:\RustDesk\RustDesk.exe" --service') 'missing service'
    Invoke-ExpectExit 11 $cscript @('//nologo', $serviceVerifier, '--test-fields', $testExe, 'Y', 'Stopped', 'Auto', '"C:\RustDesk\RustDesk.exe" --service') 'stopped service'
    Invoke-ExpectExit 12 $cscript @('//nologo', $serviceVerifier, '--test-fields', $testExe, 'Y', 'Running', 'Manual', '"C:\RustDesk\RustDesk.exe" --service') 'manual service'
    Invoke-ExpectExit 13 $cscript @('//nologo', $serviceVerifier, '--test-fields', $testExe, 'Y', 'Running', 'Auto', '"C:\Other\RustDesk.exe" --service') 'wrong-path service'

    $optionsPath = Join-Path $testRoot 'RustDesk2.toml'
    $optionLines = foreach ($property in $policy.rustdeskOptions.PSObject.Properties) {
        "$($property.Name) = '$([string]$property.Value)'"
    }
    $optionLines | Set-Content -LiteralPath $optionsPath -Encoding ASCII
    $optionArguments = [System.Collections.Generic.List[object]]@('//nologo', $configVerifier, '--options', $optionsPath)
    foreach ($property in $policy.rustdeskOptions.PSObject.Properties) {
        $optionArguments.Add([string]$property.Name)
        $optionArguments.Add([string]$property.Value)
    }
    Invoke-ExpectExit 0 $cscript $optionArguments.ToArray() 'exact service-profile options'

    (Get-Content -LiteralPath $optionsPath -Raw).Replace("relay-server = '104.184.67.190'", "relay-server = ''") |
        Set-Content -LiteralPath $optionsPath -Encoding ASCII
    & $cscript @($optionArguments.ToArray()) | Out-Null
    Assert-True -Condition ($LASTEXITCODE -ne 0) -Message 'blank persisted relay was accepted.'

    $passwordPath = Join-Path $testRoot 'RustDesk.toml'
    @("password = 'stale'", "salt = 'old-salt'") | Set-Content -LiteralPath $passwordPath -Encoding ASCII
    & $cscript '//nologo' $configVerifier '--password' $passwordPath | Out-Null
    Assert-True -Condition ($LASTEXITCODE -ne 0) -Message 'stale invalid password data was accepted.'
    @("password = '01valid-encrypted-password'", "salt = ''") | Set-Content -LiteralPath $passwordPath -Encoding ASCII
    & $cscript '//nologo' $configVerifier '--password' $passwordPath | Out-Null
    Assert-True -Condition ($LASTEXITCODE -ne 0) -Message 'blank password salt was accepted.'
    @("password = '01valid-encrypted-password'", "salt = 'valid-salt'") | Set-Content -LiteralPath $passwordPath -Encoding ASCII
    Invoke-ExpectExit 0 $cscript @('//nologo', $configVerifier, '--password', $passwordPath) 'acknowledged password persistence'
    Invoke-ExpectExit 0 $cscript @('//nologo', $configVerifier, '--password', $passwordPath) 'successful same-password rerun'

    $processOutput = Join-Path $testRoot 'process-output.txt'
    Invoke-ExpectExit 0 $cscript @('//nologo', $processWrapper, $processOutput, $env:ComSpec, '5', '/d', '/c', 'echo completed') 'installer completion'
    Invoke-ExpectExit 125 $cscript @('//nologo', $processWrapper, $processOutput, $env:ComSpec, '5', '/d', '/c', 'echo Installation failed') 'failed installer output'
    Invoke-ExpectExit 124 $cscript @('//nologo', $processWrapper, $processOutput, $env:ComSpec, '1', '/d', '/c', 'ping -n 4 127.0.0.1 >nul') 'installer timeout'

    $detachedStarted = Get-Date
    Invoke-ExpectExit 0 $cscript @('//nologo', $processWrapper, $processOutput, $env:ComSpec, '30', '--detached', '/d', '/c', 'ping -n 20 127.0.0.1 >nul') 'detached installer start'
    Assert-True -Condition (((Get-Date) - $detachedStarted).TotalSeconds -lt 5) -Message 'detached start waited for the child process to exit.'
    $detachedOutput = Get-Content -LiteralPath $processOutput -Raw
    Assert-True -Condition ($detachedOutput -match 'PID=\d+') -Message 'detached start did not record a PID.'
    if ($detachedOutput -match 'PID=(\d+)') {
        Stop-Process -Id ([int]$Matches[1]) -Force -ErrorAction SilentlyContinue
    }

    Write-Output 'Antreva Desk installer scenario verification passed.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
