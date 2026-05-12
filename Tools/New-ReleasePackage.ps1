<#
	.SYNOPSIS
	Internal release tool that creates the Baseline release zip and companion SHA-256 manifest.

	.DESCRIPTION
	Builds the Inno Setup installer (Baseline-setup-<version>-<channel>.exe) via
	New-InstallerPackage.ps1, then wraps that setup executable with the verified
	bootstrap handoff script and helpers in a release zip (Baseline-<version>-<channel>.zip)
	ready for GitHub Releases. The zip is a distribution wrapper only; the setup
	executable inside it still provides both install and portable modes.

	It also emits Baseline-<version>-<channel>.zip.sha256.json, a manifest of SHA-256 hashes
	for the release zip, setup executable, and bootstrap handoff files.

	.EXAMPLE
	powershell -File .\Tools\New-ReleasePackage.ps1

	.EXAMPLE
	powershell -File .\Tools\New-ReleasePackage.ps1 -Version 4.0.0 -Force
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
	[string]$OutputDirectory,
	[string]$Version,
	[string]$BuildChannel,
	[string]$Prerelease,
	[string]$ArchiveName,
	[string]$IsccPath,
	[switch]$Force
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Zip.Helpers.ps1')

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

function Get-BaselineReleaseChannelSuffix
{
	[CmdletBinding()]
	param (
		[string]$Branch,
		[string]$Prerelease
	)

	if ([string]::Equals($Branch, 'Beta', [System.StringComparison]::OrdinalIgnoreCase))
	{
		return 'beta'
	}

	if (-not [string]::IsNullOrWhiteSpace($Prerelease))
	{
		if ($Prerelease -match '(?i)beta')
		{
			return 'beta'
		}
	}

	return 'stable'
}

function Get-BaselineReleaseZipName
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Version,

		[string]$Branch,

		[string]$Prerelease
	)

	$cleanVersion = $Version.Trim()

	if ($cleanVersion.StartsWith('v', [System.StringComparison]::OrdinalIgnoreCase))
	{
		$cleanVersion = $cleanVersion.Substring(1)
	}

	# Asset name carries the channel at the end.
	# Strip prerelease labels from the version segment to avoid names like Baseline-4.0.0-beta-beta.zip.
	$cleanVersion = $cleanVersion -replace '-(?:alpha|beta|preview|rc)(?:[.-]?\d+)?$', ''

	$channel = Get-BaselineReleaseChannelSuffix -Branch $Branch -Prerelease $Prerelease

	return "Baseline-$cleanVersion-$channel.zip"
}

function New-BaselineReleaseZip
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$SourceDirectory,

		[Parameter(Mandatory = $true)]
        [string]$DestinationZip
	)

	[void](New-BaselineZipArchive `
		-SourceDirectory $SourceDirectory `
		-DestinationZip $DestinationZip)
}

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$moduleManifestPath = Join-Path $repoRoot 'Module/Baseline.psd1'
$newInstallerScript = Join-Path $repoRoot 'Tools/New-InstallerPackage.ps1'
$bootstrapInstallScript = Join-Path $repoRoot 'Bootstrap/Bootstrap.Install.ps1'
$bootstrapHelpersScript = Join-Path $repoRoot 'Bootstrap/Helpers/Bootstrap.Helpers.ps1'

$manifest = $null
if (Test-Path -LiteralPath $moduleManifestPath -PathType Leaf)
{
	$manifest = Import-PowerShellDataFile -LiteralPath $moduleManifestPath
	if ([string]::IsNullOrWhiteSpace($Version) -and $manifest -and $manifest.ModuleVersion) { $Version = [string]$manifest.ModuleVersion }
}
if ([string]::IsNullOrWhiteSpace($Version)) { $Version = 'dev' }
if ([string]::IsNullOrWhiteSpace($Prerelease) -and $manifest -and $manifest.PrivateData -and $manifest.PrivateData.Prerelease)
{
	$Prerelease = [string]$manifest.PrivateData.Prerelease
}
if ([string]::IsNullOrWhiteSpace($BuildChannel))
{
	$BuildChannel = if (-not [string]::IsNullOrWhiteSpace($Prerelease)) { 'Beta' } else { 'Stable' }
}

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

$resolvedArchiveName = if ([string]::IsNullOrWhiteSpace($ArchiveName))
{
	Get-BaselineReleaseZipName -Version $Version -Branch $BuildChannel -Prerelease $Prerelease
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

Write-Host "Building installer..." -ForegroundColor Cyan

$installerArgs = @{
	OutputDirectory = $resolvedOutputDirectory
	Version         = $Version
	Force           = $true
}
if (-not [string]::IsNullOrWhiteSpace($IsccPath)) { $installerArgs['IsccPath'] = $IsccPath }

$installerOutput = & $newInstallerScript @installerArgs
$installerResult = @($installerOutput) | Where-Object { $_ -is [pscustomobject] -and $_.PSObject.Properties['InstallerPath'] } | Select-Object -Last 1
$setupExePath = [string]$installerResult.InstallerPath

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

if ($PSCmdlet.ShouldProcess($archivePath, 'Create Baseline release zip'))
{
	$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("BaselineRelease_" + [System.Guid]::NewGuid().ToString('N'))
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
		New-BaselineReleaseZip -SourceDirectory $stageFolder -DestinationZip $archivePath
	}
	finally
	{
		if (Test-Path -LiteralPath $stageRoot)
		{
			Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
		}
	}

	if ((Test-Path -LiteralPath $archivePath -PathType Leaf) -and (Test-Path -LiteralPath $setupExePath -PathType Leaf))
	{
		$releaseHashManifest = [ordered]@{
			schemaVersion = 1
			algorithm     = 'sha256'
			generatedUtc  = ([System.DateTime]::UtcNow.ToString('o'))
			version       = $Version
			files         = [ordered]@{
				$resolvedArchiveName = Get-ReleasePackageSha256 -Path $archivePath
				([System.IO.Path]::GetFileName($setupExePath)) = Get-ReleasePackageSha256 -Path $setupExePath
				'Bootstrap/Bootstrap.Install.ps1' = Get-ReleasePackageSha256 -Path $bootstrapInstallScript
				'Bootstrap/Helpers/Bootstrap.Helpers.ps1' = Get-ReleasePackageSha256 -Path $bootstrapHelpersScript
			}
		}
		$releaseHashManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $hashManifestPath -Encoding UTF8

		$repoArchivePath = Join-Path $repoRoot $resolvedArchiveName
		$repoHashManifestPath = Join-Path $repoRoot ([System.IO.Path]::GetFileName($hashManifestPath))

		if (-not [string]::Equals([System.IO.Path]::GetFullPath($archivePath), [System.IO.Path]::GetFullPath($repoArchivePath), [System.StringComparison]::OrdinalIgnoreCase))
		{
			Copy-Item -LiteralPath $archivePath -Destination $repoArchivePath -Force
		}
		if (-not [string]::Equals([System.IO.Path]::GetFullPath($hashManifestPath), [System.IO.Path]::GetFullPath($repoHashManifestPath), [System.StringComparison]::OrdinalIgnoreCase))
		{
			Copy-Item -LiteralPath $hashManifestPath -Destination $repoHashManifestPath -Force
		}

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
