[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('A', 'B')]
    [string]$Variant,

    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

    [string]$ResultsDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-AbsolutePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
}

function Get-FileHashString {
    param([Parameter(Mandatory = $true)][string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$repoRootResolved = Resolve-AbsolutePath -Path $RepoRoot -BasePath (Get-Location).Path
$canaryRoot = Join-Path $repoRootResolved 'Tooling/comparevi-history-canary'
$variantsRoot = Join-Path $canaryRoot 'variants'
$targetPath = Join-Path $canaryRoot 'CanaryProbe.vi'
$variantPaths = @{
    A = Join-Path $variantsRoot 'CanaryProbe-A.vi'
    B = Join-Path $variantsRoot 'CanaryProbe-B.vi'
}

foreach ($path in @($canaryRoot, $variantsRoot, $variantPaths.A, $variantPaths.B, $targetPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -and -not (Test-Path -LiteralPath $path -PathType Container)) {
        throw "Required canary path not found: $path"
    }
}

$resultsDirResolved = if ([string]::IsNullOrWhiteSpace($ResultsDir)) {
    Join-Path $repoRootResolved 'tests/results/_agent/canary'
} else {
    Resolve-AbsolutePath -Path $ResultsDir -BasePath $repoRootResolved
}
New-Item -ItemType Directory -Path $resultsDirResolved -Force | Out-Null

$selectedVariantPath = $variantPaths[$Variant]
$preHashes = [ordered]@{
    target = Get-FileHashString -Path $targetPath
    variantA = Get-FileHashString -Path $variantPaths.A
    variantB = Get-FileHashString -Path $variantPaths.B
}

Copy-Item -LiteralPath $selectedVariantPath -Destination $targetPath -Force

$postHashes = [ordered]@{
    target = Get-FileHashString -Path $targetPath
    variantA = Get-FileHashString -Path $variantPaths.A
    variantB = Get-FileHashString -Path $variantPaths.B
}

if ($preHashes.variantA -ne $postHashes.variantA) {
    throw 'Variant A hash changed unexpectedly during canary toggle.'
}
if ($preHashes.variantB -ne $postHashes.variantB) {
    throw 'Variant B hash changed unexpectedly during canary toggle.'
}

$selectedVariantHash = $postHashes.("variant$Variant")
if ($postHashes.target -ne $selectedVariantHash) {
    throw "Canary target hash does not match selected variant '$Variant'."
}

$relativeTargetPath = 'Tooling/comparevi-history-canary/CanaryProbe.vi'
$relativeSelectedVariantPath = "Tooling/comparevi-history-canary/variants/CanaryProbe-$Variant.vi"
$mutatedPaths = @()
if ($preHashes.target -ne $postHashes.target) {
    $mutatedPaths = @($relativeTargetPath)
}

$receiptPath = Join-Path $resultsDirResolved 'agent-canary-cycle.json'
$receipt = [ordered]@{
    schema = 'labview-icon-editor-demo/comparevi-history-agent-canary-cycle@v1'
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
    repoRoot = $repoRootResolved
    variant = $Variant
    targetPath = $targetPath
    selectedVariantPath = $selectedVariantPath
    relativeTargetPath = $relativeTargetPath
    relativeSelectedVariantPath = $relativeSelectedVariantPath
    variantHashes = [ordered]@{
        A = $postHashes.variantA
        B = $postHashes.variantB
        selected = $selectedVariantHash
    }
    targetHashes = [ordered]@{
        before = $preHashes.target
        after = $postHashes.target
    }
    validation = [ordered]@{
        onlyCanaryPathChanged = ($mutatedPaths.Count -le 1)
        mutatedPaths = @($mutatedPaths)
    }
}

$receipt | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $receiptPath -Encoding utf8
$receipt | ConvertTo-Json -Depth 32
