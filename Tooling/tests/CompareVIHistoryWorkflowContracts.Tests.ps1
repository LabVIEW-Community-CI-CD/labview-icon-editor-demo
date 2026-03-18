#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'CompareVI History workflow contracts' {
    BeforeAll {
        $repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:automaticPrWorkflowPath = Join-Path $repoRoot '.github/workflows/comparevi-history-pull-request-diagnostics.yml'
        $script:automaticPrPublishWorkflowPath = Join-Path $repoRoot '.github/workflows/comparevi-history-pull-request-diagnostics-publish.yml'
        $script:agentCanaryWorkflowPath = Join-Path $repoRoot '.github/workflows/comparevi-history-agent-canary-evaluate.yml'
        $script:manualWorkflowPath = Join-Path $repoRoot '.github/workflows/comparevi-history-manual-pr-diagnostics.yml'
        $script:manualExplorationWorkflowPath = Join-Path $repoRoot '.github/workflows/comparevi-history-manual-vi-exploration.yml'
        $script:corpusPilotWorkflowPath = Join-Path $repoRoot '.github/workflows/comparevi-history-corpus-evidence-pilot.yml'
        $script:commentWorkflowPath = Join-Path $repoRoot '.github/workflows/comparevi-history-comment-gated.yml'
        $script:automaticPrPolicyPath = Join-Path $repoRoot '.github/comparevi-history-pr-policy.json'
        $script:agentCanaryPolicyPath = Join-Path $repoRoot '.github/comparevi-history-agent-canary.json'
        $script:targetCatalogPath = Join-Path $repoRoot '.github/comparevi-history-targets.json'
        $script:agentCanaryToggleScriptPath = Join-Path $repoRoot 'Tooling/Set-CompareVIHistoryAgentCanaryVariant.ps1'
        $script:agentCanaryProbePath = Join-Path $repoRoot 'Tooling/comparevi-history-canary/CanaryProbe.vi'
        $script:agentCanaryVariantAPath = Join-Path $repoRoot 'Tooling/comparevi-history-canary/variants/CanaryProbe-A.vi'
        $script:agentCanaryVariantBPath = Join-Path $repoRoot 'Tooling/comparevi-history-canary/variants/CanaryProbe-B.vi'
        $script:docsPath = Join-Path $repoRoot 'docs/comparevi-history-diagnostics.md'

        foreach ($path in @(
            $script:automaticPrWorkflowPath,
            $script:automaticPrPublishWorkflowPath,
            $script:agentCanaryWorkflowPath,
            $script:manualWorkflowPath,
            $script:manualExplorationWorkflowPath,
            $script:corpusPilotWorkflowPath,
            $script:commentWorkflowPath,
            $script:automaticPrPolicyPath,
            $script:agentCanaryPolicyPath,
            $script:targetCatalogPath,
            $script:agentCanaryToggleScriptPath,
            $script:agentCanaryProbePath,
            $script:agentCanaryVariantAPath,
            $script:agentCanaryVariantBPath,
            $script:docsPath
        )) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                throw "Required comparevi-history contract file not found: $path"
            }
        }

        $script:automaticPrWorkflow = Get-Content -LiteralPath $script:automaticPrWorkflowPath -Raw
        $script:automaticPrPublishWorkflow = Get-Content -LiteralPath $script:automaticPrPublishWorkflowPath -Raw
        $script:agentCanaryWorkflow = Get-Content -LiteralPath $script:agentCanaryWorkflowPath -Raw
        $script:manualWorkflow = Get-Content -LiteralPath $script:manualWorkflowPath -Raw
        $script:manualExplorationWorkflow = Get-Content -LiteralPath $script:manualExplorationWorkflowPath -Raw
        $script:corpusPilotWorkflow = Get-Content -LiteralPath $script:corpusPilotWorkflowPath -Raw
        $script:commentWorkflow = Get-Content -LiteralPath $script:commentWorkflowPath -Raw
        $script:automaticPrPolicy = Get-Content -LiteralPath $script:automaticPrPolicyPath -Raw
        $script:agentCanaryPolicy = Get-Content -LiteralPath $script:agentCanaryPolicyPath -Raw
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

    It 'adds a thin automatic PR diagnostics wrapper pinned to an immutable comparevi-history ref' {
        $script:automaticPrWorkflow | Should -Match 'name:\s+CompareVI History Pull Request Diagnostics'
        $script:automaticPrWorkflow | Should -Match '(?m)^\s*pull_request:\s*$'
        $script:automaticPrWorkflow | Should -Match 'branches:\s*(?:\r?\n\s*-\s+main)(?:\r?\n\s*-\s+develop)(?:\r?\n\s*-\s+release/\*)(?:\r?\n\s*-\s+feature/\*)(?:\r?\n\s*-\s+hotfix/\*)'
        $script:automaticPrWorkflow | Should -Match 'types:\s*(?:\r?\n\s*-\s+opened)(?:\r?\n\s*-\s+synchronize)(?:\r?\n\s*-\s+reopened)(?:\r?\n\s*-\s+ready_for_review)'
        $script:automaticPrWorkflow | Should -Match 'uses:\s+LabVIEW-Community-CI-CD/comparevi-history/\.github/workflows/pull-request-diagnostics-auto\.yml@v1\.3\.10'
        $script:automaticPrWorkflow | Should -Match 'consumer_repository:\s+\$\{\{ github\.repository \}\}'
        $script:automaticPrWorkflow | Should -Match 'pr_policy_path:\s+\.github/comparevi-history-pr-policy\.json'
        $script:automaticPrWorkflow | Should -Match 'results_dir:\s+tests/results/pr-diagnostics/history'
        $script:automaticPrWorkflow | Should -Match 'platform_ref:\s+v1\.3\.10'
        $script:automaticPrWorkflow | Should -Not -Match 'actions/checkout@'
        $script:automaticPrWorkflow | Should -Not -Match 'invoke_script_path:'
        $script:automaticPrWorkflow | Should -Not -Match 'target_spec_path:'
    }

    It 'adds a thin automatic PR publication wrapper pinned to the same immutable comparevi-history ref' {
        $script:automaticPrPublishWorkflow | Should -Match 'name:\s+CompareVI History Pull Request Diagnostics Publish'
        $script:automaticPrPublishWorkflow | Should -Match '(?m)^\s*workflow_run:\s*$'
        $script:automaticPrPublishWorkflow | Should -Match 'CompareVI History Pull Request Diagnostics'
        $script:automaticPrPublishWorkflow | Should -Match 'pull-requests:\s+write'
        $script:automaticPrPublishWorkflow | Should -Match 'if:\s+\$\{\{\s*github\.event\.workflow_run\.event == ''pull_request'''
        $script:automaticPrPublishWorkflow | Should -Match 'uses:\s+LabVIEW-Community-CI-CD/comparevi-history/\.github/workflows/pull-request-diagnostics-publish\.yml@v1\.3\.10'
        $script:automaticPrPublishWorkflow | Should -Match 'consumer_repository:\s+\$\{\{ github\.repository \}\}'
        $script:automaticPrPublishWorkflow | Should -Match 'workflow_run_id:\s+\$\{\{ github\.event\.workflow_run\.id \}\}'
        $script:automaticPrPublishWorkflow | Should -Match 'artifact_name:\s+comparevi-history-pr-diagnostics-\$\{\{ github\.event\.workflow_run\.id \}\}'
        $script:automaticPrPublishWorkflow | Should -Match 'platform_ref:\s+v1\.3\.10'
        $script:automaticPrPublishWorkflow | Should -Not -Match 'actions/checkout@'
    }

    It 'adds a thin agent-canary evaluation wrapper pinned to the same immutable comparevi-history ref' {
        $script:agentCanaryWorkflow | Should -Match 'name:\s+CompareVI History Agent Canary Evaluate'
        $script:agentCanaryWorkflow | Should -Match '(?m)^\s*workflow_run:\s*$'
        $script:agentCanaryWorkflow | Should -Match 'CompareVI History Pull Request Diagnostics Publish'
        $script:agentCanaryWorkflow | Should -Match 'actions:\s+read'
        $script:agentCanaryWorkflow | Should -Match 'contents:\s+read'
        $script:agentCanaryWorkflow | Should -Match 'pull-requests:\s+read'
        $script:agentCanaryWorkflow | Should -Match 'uses:\s+LabVIEW-Community-CI-CD/comparevi-history/\.github/workflows/pull-request-diagnostics-canary-evaluate\.yml@v1\.3\.10'
        $script:agentCanaryWorkflow | Should -Match 'consumer_repository:\s+\$\{\{ github\.repository \}\}'
        $script:agentCanaryWorkflow | Should -Match 'workflow_run_id:\s+\$\{\{ github\.event\.workflow_run\.id \}\}'
        $script:agentCanaryWorkflow | Should -Match 'artifact_name:\s+comparevi-history-pr-diagnostics-publish-\$\{\{ github\.event\.workflow_run\.id \}\}'
        $script:agentCanaryWorkflow | Should -Match 'canary_policy_path:\s+\.github/comparevi-history-agent-canary\.json'
        $script:agentCanaryWorkflow | Should -Match 'platform_ref:\s+v1\.3\.10'
        $script:agentCanaryWorkflow | Should -Not -Match 'actions/checkout@'
    }

    It 'checks in a v2 automatic PR policy that selects dynamic raw VI paths' {
        $script:automaticPrPolicy | Should -Match '"schema"\s*:\s*"comparevi-history/pr-policy@v2"'
        $script:automaticPrPolicy | Should -Match '"selectionMode"\s*:\s*"dynamic-paths"'
        $script:automaticPrPolicy | Should -Match '"includePaths"\s*:\s*\[\s*"\*\*/\*\.vi"\s*\]'
        $script:automaticPrPolicy | Should -Match '"excludePaths"\s*:\s*\[\s*"Tooling/comparevi-history-canary/variants/\*\*/\*\.vi"\s*\]'
        $script:automaticPrPolicy | Should -Match '"maxChangedViCount"\s*:\s*10'
        $script:automaticPrPolicy | Should -Match '"overflowBehavior"\s*:\s*"block"'
        $script:automaticPrPolicy | Should -Match '"publicModes"\s*:\s*\[\s*"attributes"\s*,\s*"front-panel"\s*,\s*"block-diagram"\s*\]'
        $script:automaticPrPolicy | Should -Match '"noisePolicy"\s*:\s*"include"'
        $script:automaticPrPolicy | Should -Match '"sourceBranchRefStrategy"\s*:\s*"pull-request-base"'
        $script:automaticPrPolicy | Should -Match '"keepArtifactsOnNoDiff"\s*:\s*true'
        $script:automaticPrPolicy | Should -Match '"emitCommentBody"\s*:\s*true'
        $script:automaticPrPolicy | Should -Match '"emitStepSummary"\s*:\s*true'
        $script:automaticPrPolicy | Should -Match '"fullSurface"\s*:\s*"artifact-index"'
        $script:automaticPrPolicy | Should -Match '"forkBehavior"\s*:\s*"hosted-auto"'
    }

    It 'checks in an agent-canary policy bound to the dedicated canary VI' {
        $script:agentCanaryPolicy | Should -Match '"schema"\s*:\s*"comparevi-history/agent-canary-policy@v1"'
        $script:agentCanaryPolicy | Should -Match '"branchPrefix"\s*:\s*"agent-canary/"'
        $script:agentCanaryPolicy | Should -Match '"requiredLabels"\s*:\s*\[\s*"agent-canary"\s*\]'
        $script:agentCanaryPolicy | Should -Match '"canonicalPath"\s*:\s*"Tooling/comparevi-history-canary/CanaryProbe\.vi"'
        $script:agentCanaryPolicy | Should -Match '"expectedChangedViCount"\s*:\s*1'
        $script:agentCanaryPolicy | Should -Match '"expectedSelectedTargetCount"\s*:\s*1'
        $script:agentCanaryPolicy | Should -Match '"expectedNoisePolicy"\s*:\s*"include"'
        $script:agentCanaryPolicy | Should -Match '"expectedFullSurface"\s*:\s*"artifact-index"'
        $script:agentCanaryPolicy | Should -Match '"requiredStatus"\s*:\s*"succeeded"'
        $script:agentCanaryPolicy | Should -Match '"mergePolicy"\s*:\s*"manual-only"'
        $script:agentCanaryPolicy | Should -Match '"prMode"\s*:\s*"draft"'
    }

    It 'checks in the dedicated canary fixture assets and toggle script' {
        $script:agentCanaryProbePath | Should -Exist
        $script:agentCanaryVariantAPath | Should -Exist
        $script:agentCanaryVariantBPath | Should -Exist
        $script:agentCanaryToggleScriptPath | Should -Exist
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

    It 'adds a thin manual exploration wrapper pinned to the published reusable workflow' {
        $script:manualExplorationWorkflow | Should -Match '(?m)^\s*vi_path:\s*$'
        $script:manualExplorationWorkflow | Should -Match '(?m)^\s*ref:\s*$'
        $script:manualExplorationWorkflow | Should -Match 'default:\s+develop'
        $script:manualExplorationWorkflow | Should -Match '(?m)^\s*compare_modes:\s*$'
        $script:manualExplorationWorkflow | Should -Match 'default:\s+full'
        $script:manualExplorationWorkflow | Should -Match '(?m)^\s*include_merge_parents:\s*$'
        $script:manualExplorationWorkflow | Should -Match 'type:\s+boolean'
        $script:manualExplorationWorkflow | Should -Match '(?m)^\s*noise_policy:\s*$'
        $script:manualExplorationWorkflow | Should -Match 'default:\s+include'
        $script:manualExplorationWorkflow | Should -Match 'uses:\s+LabVIEW-Community-CI-CD/comparevi-history/\.github/workflows/manual-vi-exploration\.yml@v1\.3\.7'
        $script:manualExplorationWorkflow | Should -Match 'consumer_repository:\s+\$\{\{ github\.repository \}\}'
        $script:manualExplorationWorkflow | Should -Match 'consumer_ref:\s+\$\{\{ inputs\.ref \}\}'
        $script:manualExplorationWorkflow | Should -Match 'vi_path:\s+\$\{\{ inputs\.vi_path \}\}'
        $script:manualExplorationWorkflow | Should -Match 'modes:\s+\$\{\{ inputs\.compare_modes \}\}'
        $script:manualExplorationWorkflow | Should -Match 'include_merge_parents:\s+\$\{\{ inputs\.include_merge_parents \}\}'
        $script:manualExplorationWorkflow | Should -Match 'noise_policy:\s+\$\{\{ inputs\.noise_policy \}\}'
        $script:manualExplorationWorkflow | Should -Match 'platform_ref:\s+v1\.3\.7'
        $script:manualExplorationWorkflow | Should -Not -Match 'actions/checkout@'
        $script:manualExplorationWorkflow | Should -Not -Match 'target_spec_path:'
        $script:manualExplorationWorkflow | Should -Not -Match 'invoke_script_path:'
    }

    It 'adds a thin corpus pilot workflow pinned to released comparevi-history scripts' {
        $script:corpusPilotWorkflow | Should -Match 'name:\s+CompareVI History Corpus Evidence Pilot'
        $script:corpusPilotWorkflow | Should -Match '(?m)^\s*workflow_dispatch:\s*$'
        $script:corpusPilotWorkflow | Should -Match '(?m)^\s*ref:\s*$'
        $script:corpusPilotWorkflow | Should -Match 'default:\s+develop'
        $script:corpusPilotWorkflow | Should -Match 'PLATFORM_REF:\s+v1\.3\.8'
        $script:corpusPilotWorkflow | Should -Match 'PILOT_RESULTS_ROOT:\s+tests/results/ref-compare/history-exploration/corpus-pilot'
        $script:corpusPilotWorkflow | Should -Match 'repository:\s+LabVIEW-Community-CI-CD/comparevi-history'
        $script:corpusPilotWorkflow | Should -Match 'ref:\s+\$\{\{ env\.PLATFORM_REF \}\}'
        $script:corpusPilotWorkflow | Should -Match 'Write-CompareVIHistoryRevisionCatalog\.ps1'
        $script:corpusPilotWorkflow | Should -Match 'Invoke-CompareVIHistoryChunkExecution\.ps1'
        $script:corpusPilotWorkflow | Should -Match 'Write-CompareVIHistoryExplorationRun\.ps1'
        $script:corpusPilotWorkflow | Should -Match 'Write-CompareVIHistoryExplorationBundle\.ps1'
        $script:corpusPilotWorkflow | Should -Match 'Write-CompareVIHistoryCorpusIndex\.ps1'
        $script:corpusPilotWorkflow | Should -Match 'Tooling/deployment/VIP_Post-Install Custom Action\.vi'
        $script:corpusPilotWorkflow | Should -Match 'Tooling/deployment/VIP_Pre-Install Custom Action\.vi'
        $script:corpusPilotWorkflow | Should -Match 'corpus-index\.json'
        $script:corpusPilotWorkflow | Should -Match 'downstream-processing-manifest\.json'
        $script:corpusPilotWorkflow | Should -Match 'completeness\.isComplete'
        $script:corpusPilotWorkflow | Should -Match 'targetDigests'
        $script:corpusPilotWorkflow | Should -Match 'comparevi-history-corpus-evidence-pilot-\$\{\{ github\.run_id \}\}'
        $script:corpusPilotWorkflow | Should -Not -Match 'comparevi_repository:'
        $script:corpusPilotWorkflow | Should -Not -Match 'comparevi_ref:'
        $script:corpusPilotWorkflow | Should -Not -Match 'target_spec_path:'
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
        $script:docs | Should -Match '\.github/workflows/comparevi-history-pull-request-diagnostics\.yml'
        $script:docs | Should -Match '\.github/workflows/comparevi-history-pull-request-diagnostics-publish\.yml'
        $script:docs | Should -Match '\.github/workflows/comparevi-history-agent-canary-evaluate\.yml'
        $script:docs | Should -Match '\.github/comparevi-history-pr-policy\.json'
        $script:docs | Should -Match '\.github/comparevi-history-agent-canary\.json'
        $script:docs | Should -Match '\.github/comparevi-history-targets\.json'
        $script:docs | Should -Match 'Tooling/comparevi-history-canary/CanaryProbe\.vi'
        $script:docs | Should -Match 'Tooling/comparevi-history-canary/variants/\*\*/\*\.vi'
        $script:docs | Should -Match 'Tooling/Set-CompareVIHistoryAgentCanaryVariant\.ps1'
        $script:docs | Should -Match 'agent-canary/'
        $script:docs | Should -Match 'long-lived draft PR'
        $script:docs | Should -Match 'pull-requests:\s*read'
        $script:docs | Should -Match '\.github/workflows/comparevi-history-manual-vi-exploration\.yml'
        $script:docs | Should -Match '\.github/workflows/comparevi-history-corpus-evidence-pilot\.yml'
        $script:docs | Should -Match 'comparevi-history/changed-vi-discovery@v2'
        $script:docs | Should -Match 'comparevi-history/pr-run@v2'
        $script:docs | Should -Match 'comparevi-history/agent-canary-policy@v1'
        $script:docs | Should -Match 'comparevi-history/agent-canary-evaluation@v1'
        $script:docs | Should -Match 'workflow_run'
        $script:docs | Should -Match 'sticky PR comment'
        $script:docs | Should -Match 'same-repo pull requests'
        $script:docs | Should -Match 'fork pull requests'
        $script:docs | Should -Match 'changed-vi-discovery\.json'
        $script:docs | Should -Match 'pr-run\.json'
        $script:docs | Should -Match 'pr-comment\.md'
        $script:docs | Should -Match 'pr-step-summary\.md'
        $script:docs | Should -Match 'vip-post-install-custom-action'
        $script:docs | Should -Match 'vi_path'
        $script:docs | Should -Match 'revision-catalog\.json'
        $script:docs | Should -Match 'corpus-index\.json'
        $script:docs | Should -Match 'downstream-processing-manifest\.json'
        $script:docs | Should -Match 'VIP_Post-Install Custom Action\.vi'
        $script:docs | Should -Match 'VIP_Pre-Install Custom Action\.vi'
        $script:docs | Should -Match 'public-comment-path'
        $script:docs | Should -Match 'public-step-summary-path'
        $script:docs | Should -Match 'public-run-path'
        $script:docs | Should -Match 'LabVIEW-Community-CI-CD/comparevi-history@v1\.1\.0'
        $script:docs | Should -Match 'LabVIEW-Community-CI-CD/comparevi-history/\.github/workflows/pull-request-diagnostics-auto\.yml@v1\.3\.10'
        $script:docs | Should -Match 'LabVIEW-Community-CI-CD/comparevi-history/\.github/workflows/pull-request-diagnostics-publish\.yml@v1\.3\.10'
        $script:docs | Should -Match 'LabVIEW-Community-CI-CD/comparevi-history/\.github/workflows/pull-request-diagnostics-canary-evaluate\.yml@v1\.3\.10'
        $script:docs | Should -Match 'LabVIEW-Community-CI-CD/comparevi-history/\.github/workflows/manual-vi-exploration\.yml@v1\.3\.7'
        $script:docs | Should -Match 'LabVIEW-Community-CI-CD/comparevi-history@v1\.3\.10'
        $script:docs | Should -Match 'LabVIEW-Community-CI-CD/comparevi-history@v1\.3\.8'
        $script:docs | Should -Match 'index\.md'
        $script:docs | Should -Match 'index\.html'
        $script:docs | Should -Match 'manual-vi-exploration-bundle\.zip'
        $script:docs | Should -Not -Match 'default,attributes,front-panel,block-diagram'
    }
}
