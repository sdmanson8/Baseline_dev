<#
    .SYNOPSIS
    Download and install Baseline from GitHub.

    .DESCRIPTION
    This script is designed to be hosted at a raw GitHub URL and executed with
    a one-liner such as:

        iwr https://raw.githubusercontent.com/sdmanson8/Baseline/main/Bootstrap/Bootstrap.ps1 -UseBasicParsing | iex

    It queries the GitHub Releases API for the latest non-draft release,
    downloads the release asset zip, extracts it to a folder under the user's
    Downloads directory, and runs the Inno Setup installer
    (Baseline-setup-<version>.exe) contained in the archive. After the
    installer exits, if an installed Baseline.exe can be located it is
    launched; when BASELINE_PRESET is set or -Preset is supplied, the preset
    is forwarded to the installed launcher.

    .NOTES
    SECURITY: This bootstrap uses pipe-to-IEX with no integrity verification
    (no hash check, signature validation, or certificate pinning). The download
    is protected by TLS 1.2 to GitHub over HTTPS, but a compromised DNS or TLS
    interception could serve modified code. For higher assurance, download the
    release zip manually from the Releases page, verify its checksum, and run
    the setup executable directly.
#>

[CmdletBinding()]
param(
    [string]$Owner = 'sdmanson8',
    [string]$Repository = 'Baseline',
    [string]$Preset,
    [string]$CacheRoot = (Join-Path (Join-Path ([System.Environment]::GetFolderPath('UserProfile')) 'Downloads') 'Baseline-Bootstrap')
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

<#
    .SYNOPSIS
    Internal function Enable-Tls12.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
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
    catch { $null = $_ }
}

<#
    .SYNOPSIS
    Internal function Resolve-BootstrapPreset.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Resolve-BootstrapPreset
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
    Internal function Invoke-DownloadFile.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Invoke-DownloadFile
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
    Internal function Find-BootstrapSetupExecutable.

    .DESCRIPTION
    Locates the Baseline-setup-<version>.exe installer inside the extracted
    release archive. Searches up to three directory levels so minor archive
    layout changes do not break the bootstrap.
#>

function Find-BootstrapSetupExecutable
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtractRoot
    )

    $match = Get-ChildItem -Path $ExtractRoot -Filter 'Baseline-setup-*.exe' -Recurse -File -Depth 3 -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $match)
    {
        return $null
    }

    return $match.FullName
}

<#
    .SYNOPSIS
    Internal function Find-InstalledBaselineExecutable.

    .DESCRIPTION
    Probes the common Inno Setup install locations produced by
    Baseline-Setup.iss (per-machine under Program Files, per-user under
    %LOCALAPPDATA%\Programs) and returns the first Baseline.exe it finds.
#>

function Find-InstalledBaselineExecutable
{
    $candidates = @()
    foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA 'Programs')))
    {
        if ([string]::IsNullOrWhiteSpace([string]$root)) { continue }
        $candidates += (Join-Path $root 'Baseline\Baseline.exe')
    }

    foreach ($candidate in $candidates)
    {
        if (Test-Path -LiteralPath $candidate -PathType Leaf)
        {
            return $candidate
        }
    }

    return $null
}

<#
    .SYNOPSIS
    Internal function Compare-BootstrapReleaseVersions.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
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
        $match = [regex]::Match($comparableText, '\d+(?:\.\d+){1,3}')
        if (-not $match.Success)
        {
            return [pscustomobject]@{
                OriginalText     = $trimmedText
                Parsed           = $false
                CoreVersion      = $null
                PrereleaseTokens = @()
                IsPrerelease     = $false
            }
        }

        $parts = $match.Value.Split('.')
        while ($parts.Count -lt 4) { $parts += '0' }
        if ($parts.Count -gt 4) { $parts = $parts[0..3] }

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

        $prereleaseText = $comparableText.Substring($match.Index + $match.Length).Trim()
        if ($prereleaseText -match '^\((.+)\)$')
        {
            $prereleaseText = [string]$Matches[1]
        }
        $prereleaseText = [regex]::Replace($prereleaseText, '^[\s\-\._\(\[\{]+', '')
        $prereleaseText = [regex]::Replace($prereleaseText, '[\s\)\]\}]+$', '')

        $prereleaseTokens = @()
        if (-not [string]::IsNullOrWhiteSpace([string]$prereleaseText))
        {
            $tokenMatches = [regex]::Matches($prereleaseText.ToLowerInvariant(), '[0-9]+|[A-Za-z]+')
            if ($tokenMatches.Count -gt 0)
            {
                $prereleaseTokens = @($tokenMatches | ForEach-Object { [string]$_.Value })
            }
            else
            {
                $prereleaseTokens = @([string]$prereleaseText.ToLowerInvariant())
            }
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
    Internal function Get-BootstrapLatestRelease.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
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
            catch { }
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

$Preset = Resolve-BootstrapPreset -Preset $Preset

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
        Remove-Item -LiteralPath $CacheRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    New-Item -ItemType Directory -Path $CacheRoot -Force | Out-Null

    $archivePath = Join-Path $CacheRoot "$Repository.zip"
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

    # The release asset is a zip whose payload is the Inno Setup installer.
    $asset = $latest.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
    if (-not $asset)
    {
        throw "Release $($latest.tag_name) does not expose a .zip asset at $apiUrl. The bootstrap expects the release-zip produced by Tools/New-ReleasePackage.ps1."
    }
    $downloadUrl = $asset.browser_download_url

    # Write-Host: intentional — bootstrap progress output
    Write-Host "Downloading $Repository $($latest.tag_name) from $downloadUrl"
    Invoke-DownloadFile -Uri $downloadUrl -OutFile $archivePath

    New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot -Force

    $setupExe = Find-BootstrapSetupExecutable -ExtractRoot $extractRoot
    if (-not $setupExe)
    {
        throw "Baseline-setup-*.exe was not found in the extracted archive under $extractRoot."
    }

    Write-Host "Running installer $setupExe..."
    $setupProcess = Start-Process -FilePath $setupExe -Wait -PassThru
    if ($setupProcess.ExitCode -ne 0)
    {
        throw "Baseline installer exited with code $($setupProcess.ExitCode)."
    }

    $installedExe = Find-InstalledBaselineExecutable
    if (-not $installedExe)
    {
        Write-Host "Baseline installed. Launch it from the Start Menu — no installed Baseline.exe found in the default locations."
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
}
catch
{
    Write-Error "Failed to bootstrap Baseline: $($_.Exception.Message)"
    throw
}
