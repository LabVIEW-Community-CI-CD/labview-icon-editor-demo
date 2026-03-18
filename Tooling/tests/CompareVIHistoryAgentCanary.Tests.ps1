#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'CompareVI History agent canary toggle' {
    BeforeAll {
        $script:toggleScriptPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\Set-CompareVIHistoryAgentCanaryVariant.ps1')).Path
    }

    It 'toggles CanaryProbe.vi between variants and only mutates the dedicated canary path' {
        $repoRoot = Join-Path $TestDrive 'repo'
        $variantsRoot = Join-Path $repoRoot 'Tooling/comparevi-history-canary/variants'
        $resultsRoot = Join-Path $repoRoot 'tests/results/_agent/canary'
        New-Item -ItemType Directory -Path $variantsRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $resultsRoot -Force | Out-Null

        $targetPath = Join-Path $repoRoot 'Tooling/comparevi-history-canary/CanaryProbe.vi'
        $variantAPath = Join-Path $variantsRoot 'CanaryProbe-A.vi'
        $variantBPath = Join-Path $variantsRoot 'CanaryProbe-B.vi'

        'variant-a' | Set-Content -LiteralPath $variantAPath -Encoding utf8
        'variant-b' | Set-Content -LiteralPath $variantBPath -Encoding utf8
        Copy-Item -LiteralPath $variantAPath -Destination $targetPath -Force

        $toB = & $script:toggleScriptPath -Variant B -RepoRoot $repoRoot -ResultsDir $resultsRoot | ConvertFrom-Json -Depth 32
        $toB.schema | Should -Be 'labview-icon-editor-demo/comparevi-history-agent-canary-cycle@v1'
        $toB.variant | Should -Be 'B'
        $toB.relativeTargetPath | Should -Be 'Tooling/comparevi-history-canary/CanaryProbe.vi'
        $toB.relativeSelectedVariantPath | Should -Be 'Tooling/comparevi-history-canary/variants/CanaryProbe-B.vi'
        $toB.validation.onlyCanaryPathChanged | Should -BeTrue
        @($toB.validation.mutatedPaths) | Should -Be @('Tooling/comparevi-history-canary/CanaryProbe.vi')
        (Get-Content -LiteralPath $targetPath -Raw).Trim() | Should -Be 'variant-b'
        (Get-Content -LiteralPath $variantAPath -Raw).Trim() | Should -Be 'variant-a'
        (Get-Content -LiteralPath $variantBPath -Raw).Trim() | Should -Be 'variant-b'
        $toB.variantHashes.selected | Should -Be $toB.variantHashes.B
        $toB.targetHashes.after | Should -Be $toB.variantHashes.B

        $toA = & $script:toggleScriptPath -Variant A -RepoRoot $repoRoot -ResultsDir $resultsRoot | ConvertFrom-Json -Depth 32
        $toA.variant | Should -Be 'A'
        $toA.validation.onlyCanaryPathChanged | Should -BeTrue
        @($toA.validation.mutatedPaths) | Should -Be @('Tooling/comparevi-history-canary/CanaryProbe.vi')
        (Get-Content -LiteralPath $targetPath -Raw).Trim() | Should -Be 'variant-a'
        $toA.variantHashes.selected | Should -Be $toA.variantHashes.A
        $toA.targetHashes.after | Should -Be $toA.variantHashes.A
    }
}
