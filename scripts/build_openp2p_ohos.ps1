[CmdletBinding()]
param([string]$ReferenceOhos = '', [switch]$VerifyOnly)

# Prepare the same prebuilt runtime as the reference. Native Go compilation is a Linux task.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ReferenceOhos)) {
    $ReferenceOhos = Join-Path (Split-Path -Parent $projectRoot) 'openp2p-master\ohos'
}
$sourceDirectory = Join-Path $ReferenceOhos 'entry\libs\arm64-v8a'
$destinationDirectory = Join-Path $projectRoot 'ohos\entry\libs\arm64-v8a'
$names = @('libopenp2p_ohos.so', 'libopenp2p_ohos.h')
foreach ($name in $names) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceDirectory $name) -PathType Leaf)) {
        throw "The reference runtime pair is incomplete: $name"
    }
}
$elfPath = Join-Path $sourceDirectory $names[0]
$stream = [System.IO.File]::OpenRead($elfPath)
try {
    $header = New-Object byte[] 20
    $read = $stream.Read($header, 0, $header.Length)
    if ($read -ne 20 -or $header[0] -ne 127 -or $header[1] -ne 69 -or $header[2] -ne 76 -or
        $header[3] -ne 70 -or $header[4] -ne 2 -or $header[18] -ne 183 -or $header[19] -ne 0) {
        throw 'The reference runtime is not an AArch64 ELF64 library'
    }
} finally { $stream.Dispose() }
$api = Get-Content -LiteralPath (Join-Path $sourceDirectory $names[1]) -Raw
foreach ($symbol in @('OpenP2PStartWithNode', 'OpenP2PStop', 'OpenP2PIsRunning', 'OpenP2PGetHealth')) {
    if ($api -notmatch [regex]::Escape($symbol)) { throw "Missing reference API: $symbol" }
}
$hashes = @{}
foreach ($name in $names) {
    $source = Join-Path $sourceDirectory $name
    $destination = Join-Path $destinationDirectory $name
    $hashes[$name] = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
    if (-not $VerifyOnly) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination "$destination.tmp" -Force
        Move-Item -LiteralPath "$destination.tmp" -Destination $destination -Force
    }
    if (-not (Test-Path -LiteralPath $destination) -or
        (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hashes[$name]) {
        throw "The project runtime differs from the reference: $name"
    }
}
if (-not $VerifyOnly) {
    @{ source = 'openp2p-master/ohos'; architecture = 'arm64-v8a'; minimumApi = 24; sha256 = $hashes } |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $destinationDirectory 'runtime.json') -Encoding UTF8
}
Write-Host 'Verified: the OpenP2P library/header pair matches the reference.'
