<#
	.SYNOPSIS
	Internal release tool that creates the Baseline release zip and companion SHA-256 manifest.

	.DESCRIPTION
	Builds the Inno Setup installer (Baseline-setup-<version>.exe) via
	New-InstallerPackage.ps1 then wraps it with the verified bootstrap handoff
	script and helpers in a zip archive (Baseline-<version>.zip) ready for
	GitHub Releases. It also emits
	(Baseline-<version>.zip.sha256.json), a manifest of SHA-256 hashes for the
	release zip and installer. This is an internal shipping step for maintainers
	and release automation.

	.EXAMPLE
	powershell -File .\Tools\New-ReleasePackage.ps1

	.EXAMPLE
	powershell -File .\Tools\New-ReleasePackage.ps1 -Version 4.0.0 -Force
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

function Get-ReleasePackageSha256
{
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path
	)

	if (Get-Command -Name 'Get-FileHash' -ErrorAction SilentlyContinue)
	{
		return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
	}

	$stream = [System.IO.File]::OpenRead($Path)
	try
	{
		$sha256 = [System.Security.Cryptography.SHA256]::Create()
		try
		{
			$hashBytes = $sha256.ComputeHash($stream)
		}
		finally
		{
			$sha256.Dispose()
		}
	}
	finally
	{
		$stream.Dispose()
	}

	return ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToUpperInvariant()
}

$repoRoot             = Split-Path -Path $PSScriptRoot -Parent
$moduleManifestPath   = Join-Path $repoRoot 'Module/Baseline.psd1'
$newInstallerScript   = Join-Path $repoRoot 'Tools/New-InstallerPackage.ps1'
$bootstrapInstallScript = Join-Path $repoRoot 'Bootstrap/Bootstrap.Install.ps1'
$bootstrapHelpersScript = Join-Path $repoRoot 'Bootstrap/Helpers/Bootstrap.Helpers.ps1'

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
$hashManifestPath = Join-Path $resolvedOutputDirectory ($resolvedArchiveName + '.sha256.json')
if ((Test-Path -LiteralPath $archivePath -PathType Leaf) -and -not $Force)
{
	throw "Archive already exists: $archivePath. Re-run with -Force to overwrite it."
}
if (Test-Path -LiteralPath $archivePath -PathType Leaf)
{
	Remove-Item -LiteralPath $archivePath -Force -ErrorAction Stop
}
if (Test-Path -LiteralPath $hashManifestPath -PathType Leaf)
{
	Remove-Item -LiteralPath $hashManifestPath -Force -ErrorAction Stop
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
if (-not (Test-Path -LiteralPath $bootstrapInstallScript -PathType Leaf))
{
	throw "Bootstrap install script was not found: $bootstrapInstallScript"
}
if (-not (Test-Path -LiteralPath $bootstrapHelpersScript -PathType Leaf))
{
	throw "Bootstrap helper script was not found: $bootstrapHelpersScript"
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
		$stageBootstrapRoot = Join-Path $stageFolder 'Bootstrap'
		$stageBootstrapHelpersRoot = Join-Path $stageBootstrapRoot 'Helpers'
		New-Item -Path $stageBootstrapHelpersRoot -ItemType Directory -Force | Out-Null
		Copy-Item -LiteralPath $bootstrapInstallScript -Destination $stageBootstrapRoot -Force
		Copy-Item -LiteralPath $bootstrapHelpersScript -Destination $stageBootstrapHelpersRoot -Force
		Compress-Archive -LiteralPath $stageFolder -DestinationPath $archivePath -CompressionLevel Optimal -Force
	}
	finally
	{
		if (Test-Path -LiteralPath $stageRoot)
		{
			Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
		}
	}

	# Only hash + emit the manifest when the archive actually exists. Under
	# -WhatIf the Compress-Archive call above is suppressed, so hashing
	# $archivePath would throw on a non-existent file.
	if ((Test-Path -LiteralPath $archivePath -PathType Leaf) -and (Test-Path -LiteralPath $setupExePath -PathType Leaf))
	{
		$releaseHashManifest = [ordered]@{
			schemaVersion = 1
			algorithm     = 'sha256'
			generatedUtc  = ([System.DateTime]::UtcNow.ToString('o'))
			version       = $Version
			files         = [ordered]@{
				$resolvedArchiveName                               = Get-ReleasePackageSha256 -Path $archivePath
				([System.IO.Path]::GetFileName($setupExePath))     = Get-ReleasePackageSha256 -Path $setupExePath
				'Bootstrap/Bootstrap.Install.ps1'                  = Get-ReleasePackageSha256 -Path $bootstrapInstallScript
				'Bootstrap/Helpers/Bootstrap.Helpers.ps1'          = Get-ReleasePackageSha256 -Path $bootstrapHelpersScript
			}
		}
		$releaseHashManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $hashManifestPath -Encoding UTF8

		$archiveItem = Get-Item -LiteralPath $archivePath -ErrorAction Stop
		[pscustomobject]@{
			Path             = $archiveItem.FullName
			Version          = $Version
			SizeBytes        = [int64]$archiveItem.Length
			Installer        = $setupExePath
			HashManifestPath = $hashManifestPath
		}
	}
}
