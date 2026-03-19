#Requires -Version 7.0
#Requires -Modules Pester

Describe 'Invoke-CompareVIHistoryHostedNILinux.ps1' -Tag 'Unit' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:ScriptPath = Join-Path $script:RepoRoot 'Invoke-CompareVIHistoryHostedNILinux.ps1'
        if (-not (Test-Path -LiteralPath $script:ScriptPath -PathType Leaf)) {
            throw "Invoke-CompareVIHistoryHostedNILinux.ps1 not found at $script:ScriptPath"
        }
    }

    It 'normalizes NI Linux container artifacts into the lvcompare capture surface' {
        $toolsRoot = Join-Path $TestDrive 'comparevi-tools'
        $backendTools = Join-Path $toolsRoot 'tools'
        $runnerScript = Join-Path $backendTools 'Run-NILinuxContainerCompare.ps1'
        $outputDir = Join-Path $TestDrive 'out'
        $baseVi = Join-Path $TestDrive 'Base.vi'
        $headVi = Join-Path $TestDrive 'Head.vi'

        New-Item -ItemType Directory -Path $backendTools -Force | Out-Null
        Set-Content -LiteralPath $baseVi -Value 'base' -Encoding utf8
        Set-Content -LiteralPath $headVi -Value 'head' -Encoding utf8
        Set-Content -LiteralPath $runnerScript -Encoding utf8 -Value @'
param(
  [string]$BaseVi,
  [string]$HeadVi,
  [string]$Image,
  [string]$ReportPath,
  [string]$ReportType,
  [int]$TimeoutSeconds,
  [string[]]$Flags,
  [string]$ReuseContainerName,
  [string]$ReuseRepoHostPath,
  [string]$ReuseRepoContainerPath,
  [string]$ReuseResultsHostPath,
  [string]$ReuseResultsContainerPath,
  [switch]$PassThru
)
$outDir = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
'<html><body><details open><summary class="difference-heading">diff</summary></details></body></html>' | Set-Content -LiteralPath $ReportPath -Encoding utf8
'stdout' | Set-Content -LiteralPath (Join-Path $outDir 'ni-linux-container-stdout.txt') -Encoding utf8
'stderr' | Set-Content -LiteralPath (Join-Path $outDir 'ni-linux-container-stderr.txt') -Encoding utf8
[ordered]@{
  reuseContainerName = $ReuseContainerName
  reuseRepoHostPath = $ReuseRepoHostPath
  reuseRepoContainerPath = $ReuseRepoContainerPath
  reuseResultsHostPath = $ReuseResultsHostPath
  reuseResultsContainerPath = $ReuseResultsContainerPath
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $outDir 'runner-args.json') -Encoding utf8
[ordered]@{
  schema = 'ni-linux-container-compare/v1'
  command = 'docker run test'
  exitCode = 1
  seconds = 3.25
  isDiff = $true
  reportPath = $ReportPath
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $outDir 'ni-linux-container-capture.json') -Encoding utf8
if ($PassThru) {
  [pscustomobject]@{
    command = 'docker run test'
    exitCode = 1
    seconds = 3.25
    isDiff = $true
  }
}
exit 1
'@

        $env:COMPAREVI_SCRIPTS_ROOT = $toolsRoot
        $env:COMPAREVI_NI_LINUX_IMAGE = 'nationalinstruments/labview:2026q1-linux'
        try {
            & pwsh -NoLogo -NoProfile -File $script:ScriptPath `
                -BaseVi $baseVi `
                -HeadVi $headVi `
                -OutputDir $outputDir `
                -Quiet

            $LASTEXITCODE | Should -Be 1

            $capturePath = Join-Path $outputDir 'lvcompare-capture.json'
            $stdoutPath = Join-Path $outputDir 'lvcompare-stdout.txt'
            $stderrPath = Join-Path $outputDir 'lvcompare-stderr.txt'

            $capturePath | Should -Exist
            $stdoutPath | Should -Exist
            $stderrPath | Should -Exist

            $capture = Get-Content -LiteralPath $capturePath -Raw | ConvertFrom-Json -Depth 10
            $capture.exitCode | Should -Be 1
            $capture.seconds | Should -Be 3.25
            $capture.diff | Should -BeTrue
            $capture.cliPath | Should -Be 'docker:nationalinstruments/labview:2026q1-linux'
            $capture.environment.cli.runtime.profile | Should -BeNullOrEmpty
            $capture.environment.cli.runtime.reuseContainerName | Should -BeNullOrEmpty
            $capture.environment.cli.artifacts.reportSizeBytes | Should -BeGreaterThan 0
        }
        finally {
            Remove-Item Env:COMPAREVI_SCRIPTS_ROOT -ErrorAction SilentlyContinue
            Remove-Item Env:COMPAREVI_NI_LINUX_IMAGE -ErrorAction SilentlyContinue
        }
    }

    It 'forwards warm-runtime reuse inputs into Run-NILinuxContainerCompare' {
        $toolsRoot = Join-Path $TestDrive 'comparevi-tools-reuse'
        $backendTools = Join-Path $toolsRoot 'tools'
        $runnerScript = Join-Path $backendTools 'Run-NILinuxContainerCompare.ps1'
        $outputDir = Join-Path $TestDrive 'out-reuse'
        $baseVi = Join-Path $TestDrive 'BaseReuse.vi'
        $headVi = Join-Path $TestDrive 'HeadReuse.vi'

        New-Item -ItemType Directory -Path $backendTools -Force | Out-Null
        Set-Content -LiteralPath $baseVi -Value 'base' -Encoding utf8
        Set-Content -LiteralPath $headVi -Value 'head' -Encoding utf8
        Set-Content -LiteralPath $runnerScript -Encoding utf8 -Value @'
param(
  [string]$BaseVi,
  [string]$HeadVi,
  [string]$Image,
  [string]$ReportPath,
  [string]$ReportType,
  [int]$TimeoutSeconds,
  [string[]]$Flags,
  [string]$ReuseContainerName,
  [string]$ReuseRepoHostPath,
  [string]$ReuseRepoContainerPath,
  [string]$ReuseResultsHostPath,
  [string]$ReuseResultsContainerPath,
  [switch]$PassThru
)
$outDir = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
'<html><body>reuse</body></html>' | Set-Content -LiteralPath $ReportPath -Encoding utf8
[ordered]@{
  reuseContainerName = $ReuseContainerName
  reuseRepoHostPath = $ReuseRepoHostPath
  reuseRepoContainerPath = $ReuseRepoContainerPath
  reuseResultsHostPath = $ReuseResultsHostPath
  reuseResultsContainerPath = $ReuseResultsContainerPath
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $outDir 'runner-args.json') -Encoding utf8
[ordered]@{
  schema = 'ni-linux-container-compare/v1'
  command = 'docker exec test'
  exitCode = 0
  seconds = 1.25
  isDiff = $false
  reportPath = $ReportPath
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $outDir 'ni-linux-container-capture.json') -Encoding utf8
if ($PassThru) {
  [pscustomobject]@{
    command = 'docker exec test'
    exitCode = 0
    seconds = 1.25
    isDiff = $false
  }
}
exit 0
'@

        $env:COMPAREVI_SCRIPTS_ROOT = $toolsRoot
        $env:COMPAREVI_NI_LINUX_IMAGE = 'comparevi-vi-history-dev:local'
        $env:COMPAREVI_VI_HISTORY_LOCAL_PROFILE = 'warm-dev'
        $env:COMPAREVI_VI_HISTORY_REUSE_CONTAINER_NAME = 'comparevi-history-runtime'
        $env:COMPAREVI_VI_HISTORY_REUSE_REPO_HOST_PATH = 'C:\repo'
        $env:COMPAREVI_VI_HISTORY_REUSE_REPO_CONTAINER_PATH = '/opt/comparevi/source'
        $env:COMPAREVI_VI_HISTORY_REUSE_RESULTS_HOST_PATH = 'C:\results'
        $env:COMPAREVI_VI_HISTORY_REUSE_RESULTS_CONTAINER_PATH = '/opt/comparevi/vi-history/results'
        try {
            & pwsh -NoLogo -NoProfile -File $script:ScriptPath `
                -BaseVi $baseVi `
                -HeadVi $headVi `
                -OutputDir $outputDir `
                -Quiet

            $LASTEXITCODE | Should -Be 0

            $runnerArgsPath = Join-Path $outputDir 'runner-args.json'
            $runnerArgsPath | Should -Exist
            $runnerArgs = Get-Content -LiteralPath $runnerArgsPath -Raw | ConvertFrom-Json -Depth 8
            $runnerArgs.reuseContainerName | Should -Be 'comparevi-history-runtime'
            $runnerArgs.reuseRepoHostPath | Should -Be 'C:\repo'
            $runnerArgs.reuseRepoContainerPath | Should -Be '/opt/comparevi/source'
            $runnerArgs.reuseResultsHostPath | Should -Be 'C:\results'
            $runnerArgs.reuseResultsContainerPath | Should -Be '/opt/comparevi/vi-history/results'

            $capture = Get-Content -LiteralPath (Join-Path $outputDir 'lvcompare-capture.json') -Raw | ConvertFrom-Json -Depth 10
            $capture.cliPath | Should -Be 'docker:comparevi-vi-history-dev:local'
            $capture.environment.cli.runtime.profile | Should -Be 'warm-dev'
            $capture.environment.cli.runtime.reuseContainerName | Should -Be 'comparevi-history-runtime'
        }
        finally {
            Remove-Item Env:COMPAREVI_SCRIPTS_ROOT -ErrorAction SilentlyContinue
            Remove-Item Env:COMPAREVI_NI_LINUX_IMAGE -ErrorAction SilentlyContinue
            Remove-Item Env:COMPAREVI_VI_HISTORY_LOCAL_PROFILE -ErrorAction SilentlyContinue
            Remove-Item Env:COMPAREVI_VI_HISTORY_REUSE_CONTAINER_NAME -ErrorAction SilentlyContinue
            Remove-Item Env:COMPAREVI_VI_HISTORY_REUSE_REPO_HOST_PATH -ErrorAction SilentlyContinue
            Remove-Item Env:COMPAREVI_VI_HISTORY_REUSE_REPO_CONTAINER_PATH -ErrorAction SilentlyContinue
            Remove-Item Env:COMPAREVI_VI_HISTORY_REUSE_RESULTS_HOST_PATH -ErrorAction SilentlyContinue
            Remove-Item Env:COMPAREVI_VI_HISTORY_REUSE_RESULTS_CONTAINER_PATH -ErrorAction SilentlyContinue
        }
    }
}
