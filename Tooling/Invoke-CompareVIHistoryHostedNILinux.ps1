#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$BaseVi,
    [string]$HeadVi,
    [string]$OutputDir,
    [string]$LabVIEWExePath,
    [string]$LabVIEWBitness = '64',
    [string]$LVComparePath,
    [string[]]$Flags,
    [switch]$ReplaceFlags,
    [switch]$AllowSameLeaf,
    [switch]$RenderReport,
    [ValidateSet('html', 'xml', 'text')]
    [string[]]$ReportFormat = @('html'),
    [string]$JsonLogPath,
    [switch]$Quiet,
    [switch]$LeakCheck,
    [double]$LeakGraceSeconds = 0,
    [string]$LeakJsonPath,
    [string]$CaptureScriptPath,
    [switch]$Summary,
    [Nullable[int]]$TimeoutSeconds,
    [string]$NoiseProfile = 'full',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-AbsolutePath {
    param(
        [Parameter(Mandatory = $true)][string]$PathValue,
        [Parameter(Mandatory = $true)][string]$BasePath
    )

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $PathValue))
}

function Resolve-OutputDirectory {
    param([AllowNull()][string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        $tempRoot = [System.IO.Path]::GetTempPath()
        return Join-Path $tempRoot ("comparevi-history-linux-" + [guid]::NewGuid().ToString('N'))
    }

    return Resolve-AbsolutePath -PathValue $PathValue -BasePath (Get-Location).Path
}

function Resolve-HostedCompareReportType {
    param(
        [string[]]$ReportFormatValue,
        [switch]$RenderReportValue
    )

    foreach ($candidate in @($ReportFormatValue)) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            return $candidate.Trim().ToLowerInvariant()
        }
    }

    $envValue = [System.Environment]::GetEnvironmentVariable('COMPAREVI_REPORT_FORMAT', 'Process')
    if (-not [string]::IsNullOrWhiteSpace($envValue)) {
        return $envValue.Trim().ToLowerInvariant()
    }

    if ($RenderReportValue.IsPresent) {
        return 'html'
    }

    return 'html'
}

function Resolve-HostedCompareFlags {
    param(
        [string[]]$FlagValues,
        [switch]$ReplaceFlagsValue
    )

    $resolved = New-Object System.Collections.Generic.List[string]
    if (-not $ReplaceFlagsValue.IsPresent) {
        $envFlags = [System.Environment]::GetEnvironmentVariable('COMPAREVI_LVCOMPARE_FLAGS', 'Process')
        if (-not [string]::IsNullOrWhiteSpace($envFlags)) {
            foreach ($line in @($envFlags -split "(`r`n|`n|`r)")) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    $resolved.Add($line.Trim()) | Out-Null
                }
            }
        }
    }

    foreach ($flag in @($FlagValues)) {
        if (-not [string]::IsNullOrWhiteSpace($flag)) {
            $resolved.Add($flag.Trim()) | Out-Null
        }
    }

    return @($resolved | Select-Object -Unique)
}

function Resolve-HostedCompareScriptsRoot {
    $scriptsRoot = [System.Environment]::GetEnvironmentVariable('COMPAREVI_SCRIPTS_ROOT', 'Process')
    if ([string]::IsNullOrWhiteSpace($scriptsRoot)) {
        throw 'COMPAREVI_SCRIPTS_ROOT was not set by comparevi-history. This adapter must run through the facade.'
    }

    $resolved = [System.IO.Path]::GetFullPath($scriptsRoot)
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "COMPAREVI_SCRIPTS_ROOT does not exist: $resolved"
    }

    return $resolved
}

function Resolve-HostedCompareRunner {
    param([Parameter(Mandatory = $true)][string]$ScriptsRoot)

    $runnerScript = Join-Path $ScriptsRoot 'tools' 'Run-NILinuxContainerCompare.ps1'
    if (-not (Test-Path -LiteralPath $runnerScript -PathType Leaf)) {
        throw "Run-NILinuxContainerCompare.ps1 not found at '$runnerScript'."
    }

    return $runnerScript
}

function Resolve-ReportExtension {
    param([Parameter(Mandatory = $true)][string]$ReportTypeValue)

    switch ($ReportTypeValue) {
        'xml' { return 'xml' }
        'text' { return 'txt' }
        default { return 'html' }
    }
}

function Copy-IfExists {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
        return $false
    }

    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
    return $true
}

function Resolve-NormalizedCaptureSeconds {
    param([AllowNull()][psobject]$RunnerCapture)

    if ($null -eq $RunnerCapture) {
        return [double]0
    }

    foreach ($propertyName in @('seconds', 'durationSeconds', 'elapsedSeconds')) {
        if ($RunnerCapture.PSObject.Properties[$propertyName]) {
            try {
                return [double]$RunnerCapture.$propertyName
            }
            catch {
                return [double]0
            }
        }
    }

    return [double]0
}

function New-NormalizedCapture {
    param(
        [AllowNull()][psobject]$RunnerCapture,
        [Parameter(Mandatory = $true)][string]$Image,
        [Parameter(Mandatory = $true)][string]$BaseViPath,
        [Parameter(Mandatory = $true)][string]$HeadViPath,
        [Parameter(Mandatory = $true)][string]$ReportPathValue,
        [Parameter(Mandatory = $true)][string]$CapturePathValue,
        [Parameter(Mandatory = $true)][string]$StdOutPathValue,
        [Parameter(Mandatory = $true)][string]$StdErrPathValue,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ResolvedFlags
    )

    $reportSize = if (Test-Path -LiteralPath $ReportPathValue -PathType Leaf) {
        [int64](Get-Item -LiteralPath $ReportPathValue).Length
    } else {
        [int64]0
    }

    $isDiff = $false
    $seconds = Resolve-NormalizedCaptureSeconds -RunnerCapture $RunnerCapture
    if ($null -ne $RunnerCapture) {
        if ($RunnerCapture.PSObject.Properties['diff']) {
            $isDiff = [bool]$RunnerCapture.diff
        } elseif ($RunnerCapture.PSObject.Properties['isDiff']) {
            $isDiff = [bool]$RunnerCapture.isDiff
        } elseif ($RunnerCapture.PSObject.Properties['exitCode']) {
            $isDiff = ([int]$RunnerCapture.exitCode -eq 1)
        }
    }

    return [ordered]@{
        schema = 'lvcompare-capture/v1'
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        command = if ($null -ne $RunnerCapture -and $RunnerCapture.PSObject.Properties['command']) { [string]$RunnerCapture.command } else { '' }
        cliPath = "docker:$Image"
        exitCode = if ($null -ne $RunnerCapture -and $RunnerCapture.PSObject.Properties['exitCode']) { [int]$RunnerCapture.exitCode } else { $null }
        seconds = $seconds
        diff = $isDiff
        isDiff = $isDiff
        base = $BaseViPath
        head = $HeadViPath
        reportPath = $ReportPathValue
        stdoutPath = $StdOutPathValue
        stderrPath = $StdErrPathValue
        normalizedFrom = $CapturePathValue
        args = @($ResolvedFlags)
        environment = [ordered]@{
            cli = [ordered]@{
                image = $Image
                artifacts = [ordered]@{
                    imageCount = 0
                    images = @()
                    reportSizeBytes = $reportSize
                }
            }
        }
        runnerCapture = $RunnerCapture
    }
}

$scriptsRoot = Resolve-HostedCompareScriptsRoot
$runnerScript = Resolve-HostedCompareRunner -ScriptsRoot $scriptsRoot
$reportType = Resolve-HostedCompareReportType -ReportFormatValue $ReportFormat -RenderReportValue:$RenderReport
$reportExtension = Resolve-ReportExtension -ReportTypeValue $reportType
$outputDirResolved = Resolve-OutputDirectory -PathValue $OutputDir
$baseViResolved = Resolve-AbsolutePath -PathValue $BaseVi -BasePath (Get-Location).Path
$headViResolved = Resolve-AbsolutePath -PathValue $HeadVi -BasePath (Get-Location).Path
$reportPathResolved = Join-Path $outputDirResolved ("compare-report.{0}" -f $reportExtension)
$image = if ([string]::IsNullOrWhiteSpace($env:COMPAREVI_NI_LINUX_IMAGE)) {
    'nationalinstruments/labview:2026q1-linux'
} else {
    $env:COMPAREVI_NI_LINUX_IMAGE.Trim()
}

New-Item -ItemType Directory -Path $outputDirResolved -Force | Out-Null

$resolvedFlags = @(Resolve-HostedCompareFlags -FlagValues $Flags -ReplaceFlagsValue:$ReplaceFlags)
$runnerArgs = @{
    BaseVi = $baseViResolved
    HeadVi = $headViResolved
    Image = $image
    ReportPath = $reportPathResolved
    ReportType = $reportType
}
if ($null -ne $TimeoutSeconds -and [int]$TimeoutSeconds -gt 0) {
    $runnerArgs.TimeoutSeconds = [int]$TimeoutSeconds
}
if ($resolvedFlags.Count -gt 0) {
    $runnerArgs.Flags = @($resolvedFlags)
}
if ($Quiet.IsPresent) {
    $runnerArgs.HeartbeatSeconds = 30
}

$runnerCapture = & $runnerScript @runnerArgs -PassThru
$runnerExitCode = $LASTEXITCODE

$niCapturePath = Join-Path $outputDirResolved 'ni-linux-container-capture.json'
$niStdOutPath = Join-Path $outputDirResolved 'ni-linux-container-stdout.txt'
$niStdErrPath = Join-Path $outputDirResolved 'ni-linux-container-stderr.txt'
$lvCapturePath = Join-Path $outputDirResolved 'lvcompare-capture.json'
$lvStdOutPath = Join-Path $outputDirResolved 'lvcompare-stdout.txt'
$lvStdErrPath = Join-Path $outputDirResolved 'lvcompare-stderr.txt'

[void](Copy-IfExists -SourcePath $niStdOutPath -DestinationPath $lvStdOutPath)
[void](Copy-IfExists -SourcePath $niStdErrPath -DestinationPath $lvStdErrPath)

if ((Test-Path -LiteralPath $niCapturePath -PathType Leaf)) {
    try {
        $runnerCapture = Get-Content -LiteralPath $niCapturePath -Raw | ConvertFrom-Json -Depth 8
    } catch {
        # Keep the direct object if the file cannot be parsed.
    }
}

$normalizedCapture = New-NormalizedCapture `
    -RunnerCapture $runnerCapture `
    -Image $image `
    -BaseViPath $baseViResolved `
    -HeadViPath $headViResolved `
    -ReportPathValue $reportPathResolved `
    -CapturePathValue $niCapturePath `
    -StdOutPathValue $lvStdOutPath `
    -StdErrPathValue $lvStdErrPath `
    -ResolvedFlags $resolvedFlags

$normalizedCapture | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $lvCapturePath -Encoding utf8

if ($runnerExitCode -ne 0) {
    exit $runnerExitCode
}
