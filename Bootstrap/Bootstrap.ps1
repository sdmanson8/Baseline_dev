<#
    .SYNOPSIS
    Download and install Baseline from GitHub.

    .DESCRIPTION
    This script is designed to be hosted at a raw GitHub URL, downloaded to a
    local file, inspected if desired, and executed as a script file:

        Invoke-WebRequest -Uri https://raw.githubusercontent.com/sdmanson8/Baseline/main/Bootstrap/Bootstrap.ps1 -OutFile "$env:TEMP\Baseline.Bootstrap.ps1" -UseBasicParsing
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\Baseline.Bootstrap.ps1"

    It queries the GitHub Releases API for the latest non-draft release,
    downloads the release zip, verifies it, extracts it to a folder under the
    user's Downloads directory, and then runs Bootstrap.Install.ps1 from inside
    the verified archive. The packaged installer script locates and verifies
    Baseline-setup-<version>-<channel>.exe before running it. When BASELINE_PRESET is
    set or -Preset is supplied, the preset is forwarded to the installed launcher.

    .NOTES
    SECURITY: Do not execute remote bootstrap content directly from a pipeline.
    This bootstrap script itself is not signature-validated or hash-pinned.
    Release payload integrity is enforced by downloading the companion
    <release-zip>.sha256.json manifest from the GitHub Release and verifying
    SHA-256 for both the zip and the extracted setup executable before launch.
    For higher assurance, download the release assets manually from the
    Releases page, verify the hash manifest yourself, and run the setup
    executable directly.
#>

[CmdletBinding()]
param(
    [string]$Owner = 'sdmanson8',
    [string]$Repository = 'Baseline',
    [string]$Preset,
    [ValidateSet('stable', 'beta')]
    [string]$ReleaseChannel,
    [string]$CacheRoot = (Join-Path (Join-Path ([System.Environment]::GetFolderPath('UserProfile')) 'Downloads') 'Baseline-Bootstrap')
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

<#
    .SYNOPSIS
#>

function Write-BootstrapSwallowedException
{
    param(
        [Parameter(Mandatory = $true)]
        [object]$ErrorRecord,

        [Parameter(Mandatory = $true)]
        [string]$Source,

        [ValidateSet('Debug', 'Warning', 'Error')]
        [string]$Severity = 'Debug'
    )

    if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
    {
        Write-SwallowedException -ErrorRecord $ErrorRecord -Source $Source -Severity $Severity
        return
    }

    $message = '[swallow] {0}: {1}' -f $Source, $ErrorRecord.Exception.Message
    switch ($Severity)
    {
        'Warning' { Write-Warning $message }
        'Error' { Write-Error $message -ErrorAction Continue }
        default { Write-Verbose $message }
    }
}

<#
    .SYNOPSIS
#>

function Enable-Tls12
{
    try
    {
        # Ensure no prior script has disabled certificate validation (MITM risk).
        if ($null -ne [System.Net.ServicePointManager]::ServerCertificateValidationCallback)
        {
            Write-Warning "ServerCertificateValidationCallback was overridden by a prior script - resetting to default."
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }

        $current = [System.Net.ServicePointManager]::SecurityProtocol
        $tls12 = [System.Net.SecurityProtocolType]::Tls12
        if (($current -band $tls12) -ne $tls12)
        {
            [System.Net.ServicePointManager]::SecurityProtocol = $current -bor $tls12
        }
    }
    catch { Write-BootstrapSwallowedException -ErrorRecord $_ -Source 'Bootstrap.Enable-Tls12' -Severity Warning }
}

<#
    .SYNOPSIS
#>

function Resolve-RawBootstrapPreset
{
    param(
        [string]$Preset,
        [string]$EnvironmentPreset = $env:BASELINE_PRESET
    )

    $candidate = if ([string]::IsNullOrWhiteSpace($Preset)) { $EnvironmentPreset } else { $Preset }
    if ([string]::IsNullOrWhiteSpace($candidate))
    {
        return $null
    }

    if ($candidate -notmatch '^[A-Za-z0-9_.-]+$')
    {
        throw ("Invalid preset token '{0}'. Use letters, numbers, dots, underscores, or hyphens only." -f $candidate)
    }

	return [string]$candidate
}

<#
    .SYNOPSIS
#>

function Invoke-RawBootstrapDownloadFile
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$OutFile
    )

    $invokeParams = @{
        Uri         = $Uri
        OutFile     = $OutFile
        TimeoutSec  = 30
        ErrorAction = 'Stop'
    }

    $iwrCommand = Get-Command Invoke-WebRequest -ErrorAction Stop
    if ($iwrCommand.Parameters.ContainsKey('UseBasicParsing'))
    {
        $invokeParams.UseBasicParsing = $true
    }

	Invoke-WebRequest @invokeParams | Out-Null
}

<#
    .SYNOPSIS
#>

function Get-RawBootstrapFileSha256
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf))
    {
        throw "File was not found: $Path"
    }

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

<#
    .SYNOPSIS
#>

function Get-RawBootstrapReleaseIntegrityManifest
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf))
    {
        throw "Release integrity manifest was not found: $ManifestPath"
    }

    $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$manifest.algorithm -ne 'sha256')
    {
        throw "Unsupported release integrity manifest algorithm '$([string]$manifest.algorithm)'."
    }

    if (-not $manifest.PSObject.Properties['files'] -or -not $manifest.files)
    {
        throw "Release integrity manifest does not contain a files map: $ManifestPath"
    }

    return $manifest
}

<#
    .SYNOPSIS
#>

function Get-RawBootstrapReleaseAssetSha256
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,

        [Parameter(Mandatory = $true)]
        [string]$AssetName
    )

    $manifest = Get-RawBootstrapReleaseIntegrityManifest -ManifestPath $ManifestPath
    $assetProperty = $manifest.files.PSObject.Properties[$AssetName]
    if (-not $assetProperty -or [string]::IsNullOrWhiteSpace([string]$assetProperty.Value))
    {
        throw "Release integrity manifest '$ManifestPath' does not contain a SHA-256 entry for '$AssetName'."
    }

    return ([string]$assetProperty.Value).Trim().ToUpperInvariant()
}

<#
    .SYNOPSIS
#>

function Assert-RawBootstrapReleaseAssetHash
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,

        [Parameter(Mandatory = $true)]
        [string]$AssetName,

        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string]$Label = 'Downloaded file'
    )

    $expected = Get-RawBootstrapReleaseAssetSha256 -ManifestPath $ManifestPath -AssetName $AssetName
    $actual = Get-RawBootstrapFileSha256 -Path $FilePath
    if ($actual -ne $expected)
    {
        throw "$Label failed SHA-256 verification. Expected $expected but received $actual."
    }

    return $actual
}

<#
    .SYNOPSIS
    Finds the verified bootstrap install script in an extracted release archive.

    .DESCRIPTION
    Requires exactly one Bootstrap.Install.ps1 file under the verified release archive so the raw bootstrap can hand off to packaged install logic without downloading helper scripts from raw GitHub.
#>
function Find-BootstrapInstallScript
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtractRoot
    )

    $matches = @(Get-ChildItem -Path $ExtractRoot -Filter 'Bootstrap.Install.ps1' -Recurse -File -Depth 4 -ErrorAction SilentlyContinue)
    if ($matches.Count -ne 1)
    {
        throw "Expected exactly one Bootstrap.Install.ps1 under $ExtractRoot. Found $($matches.Count)."
    }

    return $matches[0].FullName
}
<#
    .SYNOPSIS
#>

function Compare-BootstrapReleaseVersions
{
    param(
        [AllowNull()]
        [string]$LeftVersion,

        [AllowNull()]
        [string]$RightVersion
    )

    $parseVersionInfo = {
        param([AllowNull()][string]$VersionText)

        if ([string]::IsNullOrWhiteSpace([string]$VersionText))
        {
            return $null
        }

        $trimmedText = ([string]$VersionText).Trim()
        $comparableText = $trimmedText.Split('+')[0].Trim()
        $versionPattern = '^v?(?<Major>\d+)\.(?<Minor>\d+)\.(?<Patch>\d+)(?:-(?<Prerelease>[0-9A-Za-z][0-9A-Za-z.-]*))?$'
        if ($comparableText -notmatch $versionPattern)
        {
            return [pscustomobject]@{
                OriginalText     = $trimmedText
                Parsed           = $false
                CoreVersion      = $null
                PrereleaseTokens = @()
                IsPrerelease     = $false
            }
        }

        $parts = @($Matches['Major'], $Matches['Minor'], $Matches['Patch'], '0')

        $coreVersion = $null
        try
        {
            $coreVersion = [System.Version]($parts -join '.')
        }
        catch
        {
            return [pscustomobject]@{
                OriginalText     = $trimmedText
                Parsed           = $false
                CoreVersion      = $null
                PrereleaseTokens = @()
                IsPrerelease     = $false
            }
        }

        $prereleaseTokens = @()

        if (-not [string]::IsNullOrWhiteSpace($Matches['Prerelease']))
        {
            $prereleaseTokens = @([string]$Matches['Prerelease'] -split '[.-]' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }

        return [pscustomobject]@{
            OriginalText     = $trimmedText
            Parsed           = $true
            CoreVersion      = $coreVersion
            PrereleaseTokens = $prereleaseTokens
            IsPrerelease     = ($prereleaseTokens.Count -gt 0)
        }
    }

    $leftInfo = & $parseVersionInfo $LeftVersion
    $rightInfo = & $parseVersionInfo $RightVersion

    if ($null -eq $leftInfo -and $null -eq $rightInfo) { return 0 }
    if ($null -eq $leftInfo) { return -1 }
    if ($null -eq $rightInfo) { return 1 }

    if (-not $leftInfo.Parsed -and -not $rightInfo.Parsed)
    {
        return [Math]::Sign([string]::Compare($leftInfo.OriginalText, $rightInfo.OriginalText, [System.StringComparison]::OrdinalIgnoreCase))
    }
    if (-not $leftInfo.Parsed) { return -1 }
    if (-not $rightInfo.Parsed) { return 1 }

    $coreComparison = $leftInfo.CoreVersion.CompareTo($rightInfo.CoreVersion)
    if ($coreComparison -ne 0)
    {
        return [Math]::Sign($coreComparison)
    }

    if ($leftInfo.IsPrerelease -and -not $rightInfo.IsPrerelease) { return -1 }
    if (-not $leftInfo.IsPrerelease -and $rightInfo.IsPrerelease) { return 1 }
    if (-not $leftInfo.IsPrerelease -and -not $rightInfo.IsPrerelease) { return 0 }

    $maxTokenCount = [Math]::Max($leftInfo.PrereleaseTokens.Count, $rightInfo.PrereleaseTokens.Count)
    for ($index = 0; $index -lt $maxTokenCount; $index++)
    {
        if ($index -ge $leftInfo.PrereleaseTokens.Count) { return -1 }
        if ($index -ge $rightInfo.PrereleaseTokens.Count) { return 1 }

        $leftToken = [string]$leftInfo.PrereleaseTokens[$index]
        $rightToken = [string]$rightInfo.PrereleaseTokens[$index]
        $leftTokenIsNumber = ($leftToken -match '^\d+$')
        $rightTokenIsNumber = ($rightToken -match '^\d+$')

        if ($leftTokenIsNumber -and $rightTokenIsNumber)
        {
            $leftNumber = [int64]$leftToken
            $rightNumber = [int64]$rightToken
            if ($leftNumber -ne $rightNumber)
            {
                return [Math]::Sign($leftNumber.CompareTo($rightNumber))
            }
            continue
        }

        if ($leftTokenIsNumber -and -not $rightTokenIsNumber) { return -1 }
        if (-not $leftTokenIsNumber -and $rightTokenIsNumber) { return 1 }

        $tokenComparison = [string]::Compare($leftToken, $rightToken, [System.StringComparison]::OrdinalIgnoreCase)
        if ($tokenComparison -ne 0)
        {
            return [Math]::Sign($tokenComparison)
        }
    }

    return 0
}

<#
    .SYNOPSIS
#>

function Get-BootstrapLatestRelease
{
    param(
        [AllowNull()]
        [object[]]$Releases
    )

    $bestRelease = $null
    $bestPublishedAt = [DateTimeOffset]::MinValue

    foreach ($release in @($Releases))
    {
        if ($null -eq $release -or [bool]$release.draft)
        {
            continue
        }

        $candidateTag = [string]$release.tag_name
        if ([string]::IsNullOrWhiteSpace([string]$candidateTag))
        {
            continue
        }

        $candidatePublishedAt = [DateTimeOffset]::MinValue
        foreach ($propertyName in @('published_at', 'created_at'))
        {
            $rawPublishedAt = [string]$release.$propertyName
            if ([string]::IsNullOrWhiteSpace([string]$rawPublishedAt))
            {
                continue
            }

            try
            {
                $candidatePublishedAt = [DateTimeOffset]::Parse($rawPublishedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                break
            }
            catch { Write-BootstrapSwallowedException -ErrorRecord $_ -Source 'Bootstrap.Get-BootstrapLatestRelease.ParsePublishedAt' -Severity Debug }
        }

        if ($null -eq $bestRelease)
        {
            $bestRelease = $release
            $bestPublishedAt = $candidatePublishedAt
            continue
        }

        $comparison = Compare-BootstrapReleaseVersions -LeftVersion $candidateTag -RightVersion ([string]$bestRelease.tag_name)
        if ($comparison -gt 0 -or ($comparison -eq 0 -and $candidatePublishedAt -gt $bestPublishedAt))
        {
            $bestRelease = $release
            $bestPublishedAt = $candidatePublishedAt
        }
    }

    return $bestRelease
}

$Preset = Resolve-RawBootstrapPreset -Preset $Preset

try
{
    Enable-Tls12

    $resolvedCache = [System.IO.Path]::GetFullPath($CacheRoot)
    $resolvedDownloads = [System.IO.Path]::GetFullPath((Join-Path ([System.Environment]::GetFolderPath('UserProfile')) 'Downloads')).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedCache.StartsWith($resolvedDownloads, [System.StringComparison]::OrdinalIgnoreCase))
    {
        throw "CacheRoot must be under $resolvedDownloads. Received: $CacheRoot"
    }

    if (Test-Path -LiteralPath $CacheRoot)
    {
        try
        {
            Remove-Item -LiteralPath $CacheRoot -Recurse -Force -ErrorAction Stop
        }
        catch
        {
            Write-Error "Failed to clean bootstrap cache '$CacheRoot'. Stale or locked content could affect extraction: $($_.Exception.Message)"
            throw
        }
    }

    New-Item -ItemType Directory -Path $CacheRoot -Force | Out-Null

    $archivePath = Join-Path $CacheRoot 'Baseline-release.zip'
    $extractRoot = Join-Path $CacheRoot 'extract'

    # Resolve the latest release (including pre-releases) via the GitHub API.
    $apiUrl = "https://api.github.com/repos/$Owner/$Repository/releases"
    Write-Host "Querying GitHub releases..."
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add('User-Agent', "Bootstrap/$Repository")
    $releasesJson = $wc.DownloadString($apiUrl)
    $releases = $releasesJson | ConvertFrom-Json
    if (-not $releases -or $releases.Count -eq 0)
    {
        throw "No releases found at $apiUrl"
    }
    $latest = Get-BootstrapLatestRelease -Releases $releases
    if (-not $latest)
    {
        throw "No non-draft releases found at $apiUrl"
    }

    # Deterministic release asset selection: exactly one release zip and one
    # matching SHA-256 manifest must be present. Enforces a 1:1 contract so a
    # release with multiple zips (or a stray manifest) is treated as a hard
    # contract violation rather than silently picking "the first match".
    $releaseChannel = if (-not [string]::IsNullOrWhiteSpace($ReleaseChannel)) { $ReleaseChannel } elseif ([string]::Equals($Repository, 'Baseline_dev', [System.StringComparison]::OrdinalIgnoreCase)) { 'beta' } else { 'stable' }
    $expectedZipPattern = "^Baseline-\d+\.\d+\.\d+-$releaseChannel\.zip$"
    $expectedManifestPattern = "^Baseline-\d+\.\d+\.\d+-$releaseChannel\.zip\.sha256\.json$"

    $releaseAssets   = @($latest.assets)
    $releaseZip      = @($releaseAssets | Where-Object { [string]$_.name -match $expectedZipPattern })
    $releaseManifest = @($releaseAssets | Where-Object { [string]$_.name -match $expectedManifestPattern })

    if ($releaseZip.Count -ne 1 -or $releaseManifest.Count -ne 1)
    {
        throw "Release contract violation for $($latest.tag_name): expected exactly one zip matching '$expectedZipPattern' and one SHA-256 manifest matching '$expectedManifestPattern'. Found zip assets=$($releaseZip.Count), manifest assets=$($releaseManifest.Count)."
    }

    $asset                = $releaseZip[0]
    $integrityAsset       = $releaseManifest[0]
    $downloadUrl          = [string]$asset.browser_download_url
    $integrityUrl         = [string]$integrityAsset.browser_download_url
    $archivePath          = Join-Path $CacheRoot ([string]$asset.name)
    $integrityManifestPath = Join-Path $CacheRoot ([string]$integrityAsset.name)

    # Write-Host: intentional bootstrap progress output.
    Write-Host "Downloading $Repository $($latest.tag_name) from $downloadUrl"
    Invoke-RawBootstrapDownloadFile -Uri $downloadUrl -OutFile $archivePath
    Write-Host "Downloading release integrity manifest from $integrityUrl"
    Invoke-RawBootstrapDownloadFile -Uri $integrityUrl -OutFile $integrityManifestPath
    $archiveHash = Assert-RawBootstrapReleaseAssetHash -ManifestPath $integrityManifestPath -AssetName ([string]$asset.name) -FilePath $archivePath -Label 'Release archive'
    Write-Host "Verified SHA-256 for $($asset.name): $archiveHash"

    New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot -Force

    $installScript = Find-BootstrapInstallScript -ExtractRoot $extractRoot
    Write-Host "Running verified bootstrap installer script $installScript..."
    & $installScript -ExtractRoot $extractRoot -ManifestPath $integrityManifestPath -Repository $Repository -Preset $Preset
}
catch
{
    Write-Error "Failed to bootstrap Baseline: $($_.Exception.Message)"
    throw
}
