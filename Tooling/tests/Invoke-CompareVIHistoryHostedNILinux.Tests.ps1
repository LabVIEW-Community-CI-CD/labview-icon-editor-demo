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
  [switch]$PassThru
)
$outDir = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
'<html><body><details open><summary class="difference-heading">diff</summary></details></body></html>' | Set-Content -LiteralPath $ReportPath -Encoding utf8
'stdout' | Set-Content -LiteralPath (Join-Path $outDir 'ni-linux-container-stdout.txt') -Encoding utf8
'stderr' | Set-Content -LiteralPath (Join-Path $outDir 'ni-linux-container-stderr.txt') -Encoding utf8
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
            $capture.environment.cli.artifacts.reportSizeBytes | Should -BeGreaterThan 0
        }
        finally {
            Remove-Item Env:COMPAREVI_SCRIPTS_ROOT -ErrorAction SilentlyContinue
            Remove-Item Env:COMPAREVI_NI_LINUX_IMAGE -ErrorAction SilentlyContinue
        }
    }
}
