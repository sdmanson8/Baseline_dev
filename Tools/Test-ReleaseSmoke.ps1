<#
    .SYNOPSIS
    Release smoke-test entry point for Baseline artifact validation.

    .DESCRIPTION
    Runs the standard smoke suite with built-launcher checks enabled. Use this
    after building the launcher or before packaging a release.

    .EXAMPLE
    powershell -File .\Tools\Test-ReleaseSmoke.ps1

    .EXAMPLE
    powershell -File .\Tools\Test-ReleaseSmoke.ps1 -IncludeGUI

    .EXAMPLE
    powershell -File .\Tools\Test-ReleaseSmoke.ps1 -AllowUnsignedPreview
#>

[CmdletBinding()]
param (
    [switch]$IncludeGUI,
    [switch]$AllowUnsignedPreview
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$releaseGateFailures = 0

function Write-ReleaseGateResult
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Pass', 'Fail', 'Skip')]
        [string]$Result,

        [string]$Detail = ''
    )

    $prefix = switch ($Result)
    {
        'Pass' { '[PASS]' }
        'Fail' { '[FAIL]'; $script:releaseGateFailures++ }
        'Skip' { '[SKIP]' }
    }

    $line = "  $prefix $Name"
    if (-not [string]::IsNullOrWhiteSpace($Detail))
    {
        $line = "$line -- $Detail"
    }

    Write-Host $line
}

function Test-UnsignedPreviewAllowed
{
    [CmdletBinding()]
    param()

    if ($AllowUnsignedPreview) { return $true }
    $value = [string][Environment]::GetEnvironmentVariable('BASELINE_PREVIEW_UNSIGNED')
    return ($value -match '^(?i:1|true|yes|on)$')
}

function Test-ReleaseArtifactSignature
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string[]]$AllowedSignerSubjects = @()
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf))
    {
        Write-ReleaseGateResult -Name "Authenticode: $Path" -Result Fail -Detail 'Artifact missing'
        return
    }

    if (-not (Get-Command -Name 'Get-AuthenticodeSignature' -ErrorAction SilentlyContinue))
    {
        Write-ReleaseGateResult -Name "Authenticode: $([System.IO.Path]::GetFileName($Path))" -Result Fail -Detail 'Get-AuthenticodeSignature is unavailable'
        return
    }

    $signature = Get-AuthenticodeSignature -FilePath $Path -ErrorAction Stop
    if ($signature.Status -ne 'Valid')
    {
        if (($signature.Status -eq 'NotSigned') -and (Test-UnsignedPreviewAllowed))
        {
            Write-ReleaseGateResult -Name "Authenticode: $([System.IO.Path]::GetFileName($Path))" -Result Pass -Detail 'Unsigned preview explicitly allowed'
            return
        }

        Write-ReleaseGateResult -Name "Authenticode: $([System.IO.Path]::GetFileName($Path))" -Result Fail -Detail "Status: $($signature.Status)"
        return
    }

    $subject = if ($signature.SignerCertificate) { [string]$signature.SignerCertificate.Subject } else { '' }
    if ($AllowedSignerSubjects.Count -gt 0 -and $subject -notin $AllowedSignerSubjects)
    {
        Write-ReleaseGateResult -Name "Authenticode: $([System.IO.Path]::GetFileName($Path))" -Result Fail -Detail "Unexpected signer: $subject"
        return
    }

    if (-not $signature.TimeStamperCertificate)
    {
        Write-ReleaseGateResult -Name "Authenticode: $([System.IO.Path]::GetFileName($Path))" -Result Fail -Detail 'Missing RFC 3161 timestamp'
        return
    }

    Write-ReleaseGateResult -Name "Authenticode: $([System.IO.Path]::GetFileName($Path))" -Result Pass -Detail $subject
}

function Test-ReleaseAuthenticodeGate
{
    [CmdletBinding()]
    param()

    Write-Host "`n=== Release Authenticode Gate ===" -ForegroundColor Cyan

    $artifactPaths = New-Object System.Collections.Generic.List[string]
    $baselineExePath = Join-Path $repoRoot 'Baseline.exe'
    [void]$artifactPaths.Add($baselineExePath)

    foreach ($searchRoot in @($repoRoot, (Join-Path $repoRoot 'dist')))
    {
        if (-not (Test-Path -LiteralPath $searchRoot -PathType Container)) { continue }
        foreach ($setup in @(Get-ChildItem -LiteralPath $searchRoot -Filter 'Baseline-setup-*.exe' -File -ErrorAction SilentlyContinue))
        {
            if (-not $artifactPaths.Contains($setup.FullName))
            {
                [void]$artifactPaths.Add($setup.FullName)
            }
        }
    }

    $setupCount = @($artifactPaths | Where-Object { [System.IO.Path]::GetFileName($_) -like 'Baseline-setup-*.exe' }).Count
    if ($setupCount -eq 0)
    {
        Write-ReleaseGateResult -Name 'Authenticode: setup artifact presence' -Result Fail -Detail 'No Baseline-setup-*.exe artifact found in repo root or dist'
    }

    foreach ($artifactPath in $artifactPaths)
    {
        Test-ReleaseArtifactSignature -Path $artifactPath
    }
}

function Get-ReleaseGateInputFile
{
    [CmdletBinding()]
    param()

    $roots = @('Module', 'Bootstrap', 'Launcher', 'ShortcutLauncher', 'Tools', 'dist', 'dev_docs', 'Assets', 'Completion', 'Localizations')
    foreach ($rootName in $roots)
    {
        $rootPath = Join-Path $repoRoot $rootName
        if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) { continue }

        Get-ChildItem -LiteralPath $rootPath -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch '\\vendor\\' -and
                $_.FullName -notmatch '\\(bin|obj)\\' -and
                $_.FullName -notmatch '\\\.git\\' -and
                $_.FullName -notmatch '\\\.artifacts\\'
            }
    }

    foreach ($fileName in @('README.md', 'CHANGELOG.md', 'Baseline.exe'))
    {
        $path = Join-Path $repoRoot $fileName
        if (Test-Path -LiteralPath $path -PathType Leaf)
        {
            Get-Item -LiteralPath $path
        }
    }
}

function Test-StaleTestReportGate
{
    [CmdletBinding()]
    param()

    Write-Host "`n=== Test Report Freshness Gate ===" -ForegroundColor Cyan

    $reportPath = Join-Path $repoRoot 'Tests/TestReport.json'
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf))
    {
        Write-ReleaseGateResult -Name 'Tests/TestReport.json freshness' -Result Fail -Detail 'Report missing'
        return
    }

    try
    {
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $generatedUtc = ([datetimeoffset]::Parse([string]$report.generated)).UtcDateTime
    }
    catch
    {
        Write-ReleaseGateResult -Name 'Tests/TestReport.json freshness' -Result Fail -Detail $_.Exception.Message
        return
    }

    $latestInput = Get-ReleaseGateInputFile |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if (-not $latestInput)
    {
        Write-ReleaseGateResult -Name 'Tests/TestReport.json freshness' -Result Fail -Detail 'No release input files found'
        return
    }

    if ($generatedUtc -lt $latestInput.LastWriteTimeUtc)
    {
        $relativePath = $latestInput.FullName.Substring($repoRoot.Length + 1)
        Write-ReleaseGateResult -Name 'Tests/TestReport.json freshness' -Result Fail -Detail ("Report {0:o} predates {1} ({2:o})" -f $generatedUtc, $relativePath, $latestInput.LastWriteTimeUtc)
        return
    }

    Write-ReleaseGateResult -Name 'Tests/TestReport.json freshness' -Result Pass -Detail ("Generated {0:o}" -f $generatedUtc)
}

function Test-ReleaseZipHygieneGate
{
    [CmdletBinding()]
    param()

    Write-Host "`n=== Release Zip Hygiene Gate ===" -ForegroundColor Cyan

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $zipFiles = @()
    foreach ($searchRoot in @($repoRoot, (Join-Path $repoRoot 'dist')))
    {
        if (-not (Test-Path -LiteralPath $searchRoot -PathType Container)) { continue }
        $zipFiles += @(Get-ChildItem -LiteralPath $searchRoot -Filter 'Baseline-*.zip' -File -ErrorAction SilentlyContinue)
    }
    $zipFiles = @($zipFiles | Sort-Object FullName -Unique)

    if ($zipFiles.Count -eq 0)
    {
        Write-ReleaseGateResult -Name 'Release zip hygiene' -Result Skip -Detail 'No Baseline-*.zip artifact found'
        return
    }

    foreach ($zipFile in $zipFiles)
    {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($zipFile.FullName)
        try
        {
            $badEntries = @(
                $archive.Entries |
                    Where-Object {
                        $entryName = [string]$_.FullName
                        $entryName -match '(^|/)(bin|obj)/' -or
                        $entryName -match '\.FileListAbsolute\.txt$' -or
                        $entryName -match '\.cache$' -or
                        $entryName -match '^[A-Za-z]:' -or
                        $entryName -match '\\'
                    } |
                    Select-Object -First 5 -ExpandProperty FullName
            )

            if ($badEntries.Count -gt 0)
            {
                Write-ReleaseGateResult -Name "Release zip hygiene: $($zipFile.Name)" -Result Fail -Detail ($badEntries -join ', ')
            }
            else
            {
                Write-ReleaseGateResult -Name "Release zip hygiene: $($zipFile.Name)" -Result Pass
            }
        }
        finally
        {
            $archive.Dispose()
        }
    }
}

$smokeTestPath = Join-Path $PSScriptRoot 'Test-SmokeTest.ps1'
if (-not (Test-Path -LiteralPath $smokeTestPath -PathType Leaf))
{
    throw "Smoke-test script not found: $smokeTestPath"
}

& $smokeTestPath -RequireReleaseArtifacts -IncludeGUI:$IncludeGUI
$smokeExitCode = $LASTEXITCODE
if ($smokeExitCode -ne 0)
{
    exit $smokeExitCode
}

Test-ReleaseAuthenticodeGate
Test-StaleTestReportGate
Test-ReleaseZipHygieneGate

if ($releaseGateFailures -gt 0)
{
    Write-Host "`n  RELEASE SMOKE TEST FAILED" -ForegroundColor Red
    exit 1
}

Write-Host "`n  RELEASE GATES PASSED" -ForegroundColor Green
exit 0
