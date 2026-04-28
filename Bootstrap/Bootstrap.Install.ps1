<#
    .SYNOPSIS
    Run the verified Baseline installer payload.

    .DESCRIPTION
    Runs from inside the verified release archive after Bootstrap.ps1 has
    downloaded the release zip, verified its SHA-256 manifest, and extracted
    the payload. This script locates the setup executable, verifies its hash
    against the same release manifest, runs the installer, and launches the
    installed Baseline executable when available.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExtractRoot,

    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [string]$Repository = 'Baseline',

    [string]$Preset
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$helpersPath = Join-Path $PSScriptRoot 'Helpers\Bootstrap.Helpers.ps1'
if (-not (Test-Path -LiteralPath $helpersPath -PathType Leaf))
{
    throw "Verified bootstrap helper file was not found: $helpersPath"
}

. $helpersPath

$Preset = Resolve-BootstrapPreset -Preset $Preset

$setupExe = Find-BootstrapSetupExecutable -ExtractRoot $ExtractRoot
if (-not $setupExe)
{
    throw "Baseline-setup-*.exe was not found in the extracted archive under $ExtractRoot."
}

$setupHash = Assert-BootstrapReleaseAssetHash -ManifestPath $ManifestPath -AssetName ([System.IO.Path]::GetFileName($setupExe)) -FilePath $setupExe -Label 'Setup executable'
Write-Host "Verified SHA-256 for $([System.IO.Path]::GetFileName($setupExe)): $setupHash"

Write-Host "Running installer $setupExe..."
$setupProcess = Start-Process -FilePath $setupExe -Wait -PassThru
if ($setupProcess.ExitCode -ne 0)
{
    throw "Baseline installer exited with code $($setupProcess.ExitCode)."
}

$installedExe = Find-InstalledBaselineExecutable
if (-not $installedExe)
{
    Write-Host "$Repository installed. Launch it from the Start Menu - no installed Baseline.exe found in the default locations."
    return
}

$previousPreset = $env:BASELINE_PRESET
$hadPreviousPreset = -not [string]::IsNullOrWhiteSpace([string]$previousPreset)
if (-not [string]::IsNullOrWhiteSpace([string]$Preset))
{
    $env:BASELINE_PRESET = $Preset
    Write-Host "Launching $installedExe with preset '$Preset'..."
}
else
{
    Write-Host "Launching $installedExe..."
}

try
{
    & $installedExe
}
finally
{
    if ($hadPreviousPreset)
    {
        $env:BASELINE_PRESET = $previousPreset
    }
    else
    {
        Remove-Item -Path Env:\BASELINE_PRESET -ErrorAction SilentlyContinue
    }
}
