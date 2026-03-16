#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'CompareVI History workflow contracts' {
    BeforeAll {
        $repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:manualWorkflowPath = Join-Path $repoRoot '.github/workflows/comparevi-history-manual-pr-diagnostics.yml'
        $script:commentWorkflowPath = Join-Path $repoRoot '.github/workflows/comparevi-history-comment-gated.yml'
        $script:targetCatalogPath = Join-Path $repoRoot '.github/comparevi-history-targets.json'
        $script:docsPath = Join-Path $repoRoot 'docs/comparevi-history-diagnostics.md'

        foreach ($path in @($script:manualWorkflowPath, $script:commentWorkflowPath, $script:targetCatalogPath, $script:docsPath)) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                throw "Required comparevi-history contract file not found: $path"
            }
        }

        $script:manualWorkflow = Get-Content -LiteralPath $script:manualWorkflowPath -Raw
        $script:commentWorkflow = Get-Content -LiteralPath $script:commentWorkflowPath -Raw
        $script:targetCatalog = Get-Content -LiteralPath $script:targetCatalogPath -Raw
        $script:docs = Get-Content -LiteralPath $script:docsPath -Raw
    }

    It 'checks in a v1 consumer target catalog with an explicit public-mode contract' {
        $script:targetCatalog | Should -Match '"schema"\s*:\s*"comparevi-history/consumer-targets@v1"'
        $script:targetCatalog | Should -Match '"defaultTargetId"\s*:\s*"vip-post-install-custom-action"'
        $script:targetCatalog | Should -Match '"path"\s*:\s*"Tooling/deployment/VIP_Post-Install Custom Action\.vi"'
        $script:targetCatalog | Should -Match '"publicModes"\s*:\s*\[\s*"attributes"\s*,\s*"front-panel"\s*,\s*"block-diagram"\s*\]'
        $script:targetCatalog | Should -Match '"commentCommand"\s*:\s*"/comparevi-history vip-post-install-custom-action --modes attributes,front-panel,block-diagram"'
        $script:targetCatalog | Should -Not -Match '"default"'
        $script:targetCatalog | Should -Not -Match '"full"'
        $script:targetCatalog | Should -Not -Match '"all"'
    }

    It 'keeps the manual workflow on target ids and action-owned summaries' {
        $script:manualWorkflow | Should -Match '(?m)^\s*target_id:\s*$'
        $script:manualWorkflow | Should -Match 'uses:\s+LabVIEW-Community-CI-CD/comparevi-history@v1\.1\.0'
        $script:manualWorkflow | Should -Match 'Checkout trusted consumer contract'
        $script:manualWorkflow | Should -Match 'path:\s+trusted-consumer'
        $script:manualWorkflow | Should -Match 'Checkout PR head repository'
        $script:manualWorkflow | Should -Match 'path:\s+pr-head'
        $script:manualWorkflow | Should -Match 'repository_root:\s+pr-head'
        $script:manualWorkflow | Should -Match 'target_spec_path:\s+\$\{\{ github\.workspace \}\}/trusted-consumer/\.github/comparevi-history-targets\.json'
        $script:manualWorkflow | Should -Match 'target_id:\s+\$\{\{ inputs\.target_id \}\}'
        $script:manualWorkflow | Should -Match 'source_branch_ref:\s+\$\{\{ steps\.pr\.outputs\[''head-ref''\] \}\}'
        $script:manualWorkflow | Should -Match 'reviewer_surface:\s+manual'
        $script:manualWorkflow | Should -Match 'invoke_script_path:\s+\$\{\{ github\.workspace \}\}/trusted-consumer/Tooling/Invoke-CompareVIHistoryHostedNILinux\.ps1'
        $script:manualWorkflow | Should -Match 'public-step-summary-path'
        $script:manualWorkflow | Should -Match 'Test-Path -LiteralPath \$env:PUBLIC_STEP_SUMMARY_PATH -PathType Leaf'
        $script:manualWorkflow | Should -Not -Match '(?m)^\s*target_path:\s*$'
        $script:manualWorkflow | Should -Not -Match 'default,attributes,front-panel,block-diagram'
    }

    It 'keeps the comment-gated workflow on target ids and action-owned comment bodies' {
        $script:commentWorkflow | Should -Match 'FACADE_REF:\s+v1\.1\.0'
        $script:commentWorkflow | Should -Match 'Usage:\s+/comparevi-history <target-id> \[--modes attributes,front-panel,block-diagram\]'
        $script:commentWorkflow | Should -Match 'target-id=\$targetId'
        $script:commentWorkflow | Should -Match 'Checkout trusted consumer contract'
        $script:commentWorkflow | Should -Match 'path:\s+trusted-consumer'
        $script:commentWorkflow | Should -Match 'Checkout PR head repository'
        $script:commentWorkflow | Should -Match 'path:\s+pr-head'
        $script:commentWorkflow | Should -Match 'repository_root:\s+pr-head'
        $script:commentWorkflow | Should -Match 'target_spec_path:\s+\$\{\{ github\.workspace \}\}/trusted-consumer/\.github/comparevi-history-targets\.json'
        $script:commentWorkflow | Should -Match 'target_id:\s+\$\{\{ steps\.request\.outputs\[''target-id''\] \}\}'
        $script:commentWorkflow | Should -Match 'reviewer_surface:\s+comment-gated'
        $script:commentWorkflow | Should -Match 'invoke_script_path:\s+\$\{\{ github\.workspace \}\}/trusted-consumer/Tooling/Invoke-CompareVIHistoryHostedNILinux\.ps1'
        $script:commentWorkflow | Should -Match 'public-comment-path'
        $script:commentWorkflow | Should -Match 'public-step-summary-path'
        $script:commentWorkflow | Should -Match 'Test-Path -LiteralPath \$env:PUBLIC_STEP_SUMMARY_PATH -PathType Leaf'
        $script:commentWorkflow | Should -Match 'Test-Path -LiteralPath \$env:COMMENT_PATH -PathType Leaf'
        $script:commentWorkflow | Should -Not -Match 'target-path=\$targetPath'
        $script:commentWorkflow | Should -Not -Match 'default,attributes,front-panel,block-diagram'
    }

    It 'documents the target catalog and action-owned public outputs' {
        $script:docs | Should -Match '\.github/comparevi-history-targets\.json'
        $script:docs | Should -Match 'vip-post-install-custom-action'
        $script:docs | Should -Match 'public-comment-path'
        $script:docs | Should -Match 'public-step-summary-path'
        $script:docs | Should -Match 'public-run-path'
        $script:docs | Should -Match 'LabVIEW-Community-CI-CD/comparevi-history@v1\.1\.0'
        $script:docs | Should -Not -Match 'default,attributes,front-panel,block-diagram'
    }
}
