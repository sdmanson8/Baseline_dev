<#
	.SYNOPSIS
	Internal release tool that creates the Baseline release zip containing only the setup executable.

	.DESCRIPTION
	Builds the Inno Setup installer (Baseline-setup-<version>.exe) via
	New-InstallerPackage.ps1 then wraps it in a zip archive
	(Baseline-<version>.zip) ready for GitHub Releases. This is an internal
	shipping step for maintainers and release automation.

	.EXAMPLE
	pwsh -File .\Tools\New-ReleasePackage.ps1

	.EXAMPLE
	pwsh -File .\Tools\New-ReleasePackage.ps1 -Version 4.0.0 -Force
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
	[string]$OutputDirectory,
	[string]$Version,
	[string]$ArchiveName,
	[string]$IsccPath,
	[switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot             = Split-Path -Path $PSScriptRoot -Parent
$moduleManifestPath   = Join-Path $repoRoot 'Module/Baseline.psd1'
$newInstallerScript   = Join-Path $repoRoot 'Tools/New-InstallerPackage.ps1'

# ── Resolve version ───────────────────────────────────────────────────────────

if ([string]::IsNullOrWhiteSpace($Version) -and (Test-Path -LiteralPath $moduleManifestPath -PathType Leaf))
{
	$manifest = Import-PowerShellDataFile -LiteralPath $moduleManifestPath
	if ($manifest -and $manifest.ModuleVersion) { $Version = [string]$manifest.ModuleVersion }
}
if ([string]::IsNullOrWhiteSpace($Version)) { $Version = 'dev' }

# ── Resolve output directory ──────────────────────────────────────────────────

$resolvedOutputDirectory = if ([string]::IsNullOrWhiteSpace($OutputDirectory))
{
	Join-Path $repoRoot 'dist'
}
elseif ([System.IO.Path]::IsPathRooted($OutputDirectory))
{
	$OutputDirectory
}
else
{
	Join-Path $repoRoot $OutputDirectory
}

if (-not (Test-Path -LiteralPath $resolvedOutputDirectory -PathType Container))
{
	New-Item -Path $resolvedOutputDirectory -ItemType Directory -Force | Out-Null
}

# ── Resolve archive name ──────────────────────────────────────────────────────

$resolvedArchiveName = if ([string]::IsNullOrWhiteSpace($ArchiveName))
{
	"Baseline-$Version.zip"
}
else
{
	$ArchiveName
}

$archivePath = Join-Path $resolvedOutputDirectory $resolvedArchiveName
if ((Test-Path -LiteralPath $archivePath -PathType Leaf) -and -not $Force)
{
	throw "Archive already exists: $archivePath. Re-run with -Force to overwrite it."
}
if (Test-Path -LiteralPath $archivePath -PathType Leaf)
{
	Remove-Item -LiteralPath $archivePath -Force -ErrorAction Stop
}

# ── Build installer ───────────────────────────────────────────────────────────

Write-Host "Building installer..." -ForegroundColor Cyan

$installerArgs = @{
	OutputDirectory = $resolvedOutputDirectory
	Version         = $Version
	Force           = $true
}
if (-not [string]::IsNullOrWhiteSpace($IsccPath)) { $installerArgs['IsccPath'] = $IsccPath }

$installerOutput = & $newInstallerScript @installerArgs
$installerResult = @($installerOutput) | Where-Object { $_ -is [pscustomobject] -and $_.PSObject.Properties['InstallerPath'] } | Select-Object -Last 1
$setupExePath    = $installerResult.InstallerPath

if ([string]::IsNullOrWhiteSpace($setupExePath) -or -not (Test-Path -LiteralPath $setupExePath -PathType Leaf))
{
	throw "Installer was not produced. Expected path: $setupExePath"
}

Write-Host "Installer built: $setupExePath" -ForegroundColor Green

# ── Wrap setup.exe in zip ─────────────────────────────────────────────────────

if ($PSCmdlet.ShouldProcess($archivePath, 'Create Baseline release zip'))
{
	$stageRoot   = Join-Path ([System.IO.Path]::GetTempPath()) ("BaselineRelease_" + [System.Guid]::NewGuid().ToString('N'))
	$stageFolder = Join-Path $stageRoot 'Baseline'

	try
	{
		New-Item -Path $stageFolder -ItemType Directory -Force | Out-Null
		Copy-Item -LiteralPath $setupExePath -Destination $stageFolder -Force
		Compress-Archive -LiteralPath $stageFolder -DestinationPath $archivePath -CompressionLevel Optimal -Force
	}
	finally
	{
		if (Test-Path -LiteralPath $stageRoot)
		{
			Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
		}
	}
}

$archiveItem = Get-Item -LiteralPath $archivePath -ErrorAction Stop
[pscustomobject]@{
	Path      = $archiveItem.FullName
	Version   = $Version
	SizeBytes = [int64]$archiveItem.Length
	Installer = $setupExePath
}
