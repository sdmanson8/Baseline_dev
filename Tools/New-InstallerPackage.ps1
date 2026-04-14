<#
    .SYNOPSIS
    Internal build tool for creating the Baseline setup executable with Inno Setup.

    .DESCRIPTION
    Builds the portable release archive, extracts it as the installer payload,
    stamps version and path defines into the unified Baseline-Setup.iss script,
    then compiles it with ISCC.exe to produce a single Baseline-setup-<version>.exe.
    This is a maintainer-facing packaging script.

    .EXAMPLE
    pwsh -File .\Tools\New-InstallerPackage.ps1

    .EXAMPLE
    pwsh -File .\Tools\New-InstallerPackage.ps1 -GenerateScriptOnly
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$OutputDirectory,
    [string]$Version,
    [string]$IsccPath,
    [switch]$IncludeDocs,
    [switch]$GenerateScriptOnly,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ── Locate ISCC ───────────────────────────────────────────────────────────────

<#
    .SYNOPSIS
    Internal function Resolve-IsccPath.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Resolve-IsccPath
{
    param([string]$RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath))
    {
        if (-not (Test-Path -LiteralPath $RequestedPath -PathType Leaf))
        {
            throw "Specified ISCC path not found: $RequestedPath"
        }
        return $RequestedPath
    }

    $cmd = Get-Command -Name 'iscc.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd)
    {
        $cmdPath = $null
        $pathProperty = $cmd.PSObject.Properties['Path']
        if ($pathProperty)
        {
            $cmdPath = [string]$pathProperty.Value
        }

        if ([string]::IsNullOrWhiteSpace([string]$cmdPath))
        {
            $sourceProperty = $cmd.PSObject.Properties['Source']
            if ($sourceProperty)
            {
                $cmdPath = [string]$sourceProperty.Value
            }
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$cmdPath) -and (Test-Path -LiteralPath $cmdPath -PathType Leaf))
        {
            return [string]$cmdPath
        }
    }

    foreach ($root in @(${env:ProgramFiles(x86)}, $env:ProgramFiles) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    {
        $candidate = Join-Path -Path $root -ChildPath 'Inno Setup 6'
        $candidate = Join-Path -Path $candidate -ChildPath 'ISCC.exe'

        if (Test-Path -LiteralPath $candidate -PathType Leaf)
        {
            return $candidate
        }
    }

    return $null
}

<#
    .SYNOPSIS
    Internal function Get-InstallerLocalizationSource.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Get-InstallerLocalizationSource
{
    [CmdletBinding()]
    param()

    [ordered]@{
        'LangPage.Title'                = 'Choose Language'
        'LangPage.Desc'                 = 'Choose the display language for Baseline.'
        'LangPage.Search'               = 'Search languages:'
        'LangPage.Display'              = 'Display language:'
        'LangPage.NoResults'            = 'No matching languages found.'
        'LangPage.Help'                 = 'Search by English or native language name. You can change this later in Baseline.'
        'WizardTitle.Default'           = 'Baseline Setup'
        'WizardTitle.Install'           = 'Baseline Setup - Install'
        'WizardTitle.Portable'          = 'Baseline Setup - Portable'
        'PortableMode.AllUsersError'    = 'Portable mode writes to the current user''s profile and cannot be installed in all-users setup mode. Restart Setup and choose "Current user" on the install scope page, or rerun Setup with /CURRENTUSER.'
        'RestartAdminError'             = 'Setup could not be restarted with administrative privileges.'
        'InstallFolderDialog.Title'     = 'Select installation folder'
        'InstallPath.EmptyError'        = 'Please choose an installation folder.'
        'ModePage.Title'               = 'Installation Type'
        'ModePage.Desc'                = 'Specify whether you want to install Baseline or run it as a portable app.'
        'ModePage.Action'              = 'Select action:'
        'RbInstall.Caption'            = 'Install for this PC'
        'RbInstall.Desc'               = 'Baseline will be installed and registered in Programs and Features.'
        'RbPortable.Caption'           = 'Portable'
        'RbPortable.Desc'              = 'Run portable version (no installation needed).'
        'ScopePage.Title'              = 'Install Scope'
        'ScopePage.Desc'               = 'Choose who should be able to use Baseline.'
        'ScopePage.Heading'            = 'Select install scope:'
        'RbCurrentUser.Caption'        = 'Install for me only (recommended)'
        'RbCurrentUser.Desc'           = 'Installs Baseline for the current Windows account only.'
        'RbAllUsers.Caption'           = 'Install for all users'
        'RbAllUsers.Desc'              = 'Installs Baseline for every account on this PC and restarts Setup with administrative privileges if needed.'
        'LocPage.Title'                = 'Install Location'
        'LocPage.Desc'                 = 'Choose where Baseline should be installed.'
        'LocPage.Heading'              = 'Install location:'
        'BtnBrowse.Caption'            = 'Browse...'
        'LocPage.Note'                 = 'Baseline will be registered with Windows and can be uninstalled from Settings.'
        'ShortPage.Title'              = 'Shortcuts'
        'ShortPage.Desc'               = 'Choose which shortcuts to create for Baseline.'
        'ShortPage.Heading'            = 'Create these shortcuts:'
        'CbDesktop.Caption'            = 'Desktop shortcut'
        'CbStartMenu.Caption'          = 'Start menu shortcut'
        'FinishPage.Title'             = 'Setup Complete'
        'FinishPage.Desc'              = 'Baseline is ready to use.'
        'CbLaunch.Caption'             = 'Launch Baseline now'
        'FinishMsg.Install'            = 'Baseline has been installed to:'
        'FinishMsg.Portable'           = 'Baseline is ready in:'
        'FinishMsg.PortableShortcut'   = 'A desktop shortcut has been created.'
        'Btn.Next'                     = 'Next >'
        'Btn.Install'                  = 'Install'
        'Btn.Extract'                  = 'Extract'
        'Btn.Finish'                   = 'Finish'
    }
}

<#
    .SYNOPSIS
    Internal function Get-InstallerLocaleCodes.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Get-InstallerLocaleCodes
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TemplateContent
    )

    $matches = [regex]::Matches($TemplateContent, "LocaleEntries\[\d+\]\s*:=\s*'([^']+)';")
    $codes = foreach ($match in $matches)
    {
        $entry = [string]$match.Groups[1].Value
        $separator = $entry.LastIndexOf('|')
        if ($separator -ge 0)
        {
            $entry.Substring($separator + 1)
        }
        else
        {
            $entry
        }
    }

    $codes | Select-Object -Unique
}

<#
    .SYNOPSIS
    Internal function ConvertTo-InnoStringLiteral.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function ConvertTo-InnoStringLiteral
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $Value = $Value -replace "\r?\n", ' '
    "'" + $Value.Replace("'", "''") + "'"
}

<#
    .SYNOPSIS
    Internal function ConvertTo-StringMap.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function ConvertTo-StringMap
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$JsonObject
    )

    $map = [ordered]@{}
    foreach ($prop in $JsonObject.PSObject.Properties)
    {
        $map[$prop.Name] = [string]$prop.Value
    }

    return $map
}

<#
    .SYNOPSIS
    Internal function Initialize-InstallerLocalizationWorkspace.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Initialize-InstallerLocalizationWorkspace
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$SourceMap,

        [Parameter(Mandatory)]
        [string[]]$LocaleCodes
    )

    New-Item -Path $Root -ItemType Directory -Force | Out-Null

    $sourcePath = Join-Path $Root 'en.json'
    $SourceMap | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $sourcePath -Encoding UTF8

    foreach ($locale in $LocaleCodes)
    {
        if ($locale -like 'en*')
        {
            continue
        }

        $destinationPath = Join-Path $Root ("{0}.json" -f $locale)
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
    }

    return $sourcePath
}

<#
    .SYNOPSIS
    Internal function Get-InstallerLocalizationCacheKey.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Get-InstallerLocalizationCacheKey
{
    <#
        .SYNOPSIS
        Returns the SHA-256 hex of the installer's en.json source strings.
        Used as the cache directory name so translations are only regenerated
        when the English source strings actually change.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnJsonPath
    )

    $bytes  = [System.IO.File]::ReadAllBytes($EnJsonPath)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hash   = $sha256.ComputeHash($bytes)
    $sha256.Dispose()
    return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
}

<#
    .SYNOPSIS
    Internal function Invoke-InstallerLocalizationTranslation.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Invoke-InstallerLocalizationTranslation
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    # ── Cache check ──────────────────────────────────────────────────────────
    # The translated locale files are keyed by a hash of en.json.
    # If the cache folder for this hash already exists, copy from it and skip
    # the (slow, noisy) Google Translate pass entirely.

    $enJsonPath  = Join-Path $Root 'en.json'
    $cacheRoot   = Join-Path $repoRoot 'dist\installer-locale-cache'
    $cacheKey    = Get-InstallerLocalizationCacheKey -EnJsonPath $enJsonPath
    $cacheFolder = Join-Path $cacheRoot $cacheKey

    if (Test-Path -LiteralPath $cacheFolder -PathType Container)
    {
        Write-Host "  [locale-cache] Hit ($cacheKey) — skipping translation pass." -ForegroundColor DarkGray
        foreach ($cachedFile in Get-ChildItem -LiteralPath $cacheFolder -Filter '*.json')
        {
            if ($cachedFile.Name -eq 'en.json') { continue }
            Copy-Item -LiteralPath $cachedFile.FullName -Destination (Join-Path $Root $cachedFile.Name) -Force
        }
        return
    }

    Write-Host "  [locale-cache] Miss ($cacheKey) — running translation pass..." -ForegroundColor DarkGray

    # ── Translate ────────────────────────────────────────────────────────────
    $fillScript = Join-Path $repoRoot 'Tools/Fill-LocalizationLeaks.js'
    if (-not (Test-Path -LiteralPath $fillScript -PathType Leaf))
    {
        throw "Localization translation helper not found: $fillScript"
    }

    $oldRoot = $env:LOCALIZATION_ROOT
    $oldSource = $env:LOCALIZATION_SOURCE_FILE

    Push-Location $repoRoot
    try
    {
        $env:LOCALIZATION_ROOT = $Root
        $env:LOCALIZATION_SOURCE_FILE = 'en.json'
        & node $fillScript
        if ($LASTEXITCODE -ne 0)
        {
            throw "Localization translation helper failed with exit code $LASTEXITCODE."
        }
    }
    finally
    {
        if ($null -ne $oldRoot)
        {
            $env:LOCALIZATION_ROOT = $oldRoot
        }
        else
        {
            Remove-Item Env:LOCALIZATION_ROOT -ErrorAction SilentlyContinue
        }

        if ($null -ne $oldSource)
        {
            $env:LOCALIZATION_SOURCE_FILE = $oldSource
        }
        else
        {
            Remove-Item Env:LOCALIZATION_SOURCE_FILE -ErrorAction SilentlyContinue
        }

        Pop-Location
    }

    # ── Populate cache ───────────────────────────────────────────────────────
    # Evict any stale cache entries first so the folder stays tidy.
    if (Test-Path -LiteralPath $cacheRoot -PathType Container)
    {
        Get-ChildItem -LiteralPath $cacheRoot -Directory | Where-Object { $_.Name -ne $cacheKey } | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    New-Item -Path $cacheFolder -ItemType Directory -Force | Out-Null
    Get-ChildItem -LiteralPath $Root -Filter '*.json' | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $cacheFolder $_.Name) -Force
    }
    Write-Host "  [locale-cache] Saved translations to cache ($cacheKey)." -ForegroundColor DarkGray
}

<#
    .SYNOPSIS
    Internal function New-InstallerLocalizationFunction.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function New-InstallerLocalizationFunction
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$SourceMap,

        [Parameter(Mandatory)]
        [string[]]$LocaleCodes,

        [Parameter(Mandatory)]
        [string]$LocalizationRoot
    )

    $localeData = [ordered]@{}
    foreach ($locale in $LocaleCodes)
    {
        if ($locale -like 'en*')
        {
            continue
        }

        $localePath = Join-Path $LocalizationRoot ("{0}.json" -f $locale)
        if (-not (Test-Path -LiteralPath $localePath -PathType Leaf))
        {
            continue
        }

        $localeData[$locale.ToLowerInvariant()] = ConvertTo-StringMap -JsonObject (Get-Content -LiteralPath $localePath -Raw | ConvertFrom-Json)
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('function GetSetupString(Key: String): String;')
    [void]$sb.AppendLine('var')
    [void]$sb.AppendLine('  Lang: String;')
    [void]$sb.AppendLine('begin')
    [void]$sb.AppendLine('  Lang := Lowercase(GLocaleCode);')

    $firstLocale = $true
    $emittedLocaleBranch = $false
    foreach ($locale in ($localeData.Keys | Sort-Object))
    {
        $lines = [System.Collections.Generic.List[string]]::new()
        $translations = $localeData[$locale]
        foreach ($key in $SourceMap.Keys)
        {
            $sourceValue = [string]($SourceMap[$key])
            $localeValue = if ($translations.Contains($key)) { [string]$translations[$key] } else { '' }
            if ([string]::IsNullOrWhiteSpace($localeValue) -or $localeValue -eq $sourceValue)
            {
                continue
            }

            [void]$lines.Add(("    if Key = '{0}' then begin Result := {1}; Exit; end;" -f $key, (ConvertTo-InnoStringLiteral -Value $localeValue)))
        }

        if ($lines.Count -eq 0)
        {
            continue
        }

        if ($firstLocale)
        {
            [void]$sb.AppendLine(("  if Lang = '{0}' then" -f $locale))
            $firstLocale = $false
            $emittedLocaleBranch = $true
        }
        else
        {
            [void]$sb.AppendLine(("  else if Lang = '{0}' then" -f $locale))
        }

        [void]$sb.AppendLine('  begin')
        foreach ($line in $lines)
        {
            [void]$sb.AppendLine($line)
        }
        [void]$sb.AppendLine('  end')
    }

    if ($emittedLocaleBranch)
    {
        [void]$sb.AppendLine('  else')
        [void]$sb.AppendLine('  begin')
        foreach ($key in $SourceMap.Keys)
        {
            $sourceValue = [string]($SourceMap[$key])
            [void]$sb.AppendLine(("    if Key = '{0}' then begin Result := {1}; Exit; end;" -f $key, (ConvertTo-InnoStringLiteral -Value $sourceValue)))
        }
        [void]$sb.AppendLine('    Result := Key;')
        [void]$sb.AppendLine('  end;')
    }
    else
    {
        foreach ($key in $SourceMap.Keys)
        {
            $sourceValue = [string]($SourceMap[$key])
            [void]$sb.AppendLine(("  if Key = '{0}' then begin Result := {1}; Exit; end;" -f $key, (ConvertTo-InnoStringLiteral -Value $sourceValue)))
        }
        [void]$sb.AppendLine('  Result := Key;')
    }
    [void]$sb.AppendLine('end;')

    return $sb.ToString()
}

# ── Paths ─────────────────────────────────────────────────────────────────────

$repoRoot    = Split-Path -Path $PSScriptRoot -Parent
$templateIss = Join-Path $repoRoot 'dist\Baseline-Setup.iss'

if (-not (Test-Path -LiteralPath $templateIss -PathType Leaf))
{
    throw "Inno Setup template not found: $templateIss"
}

# ── Version ───────────────────────────────────────────────────────────────────

$moduleManifestPath = Join-Path $repoRoot 'Module\Baseline.psd1'
if ([string]::IsNullOrWhiteSpace($Version) -and (Test-Path -LiteralPath $moduleManifestPath -PathType Leaf))
{
    $manifest = Import-PowerShellDataFile -LiteralPath $moduleManifestPath
    if ($manifest -and $manifest.ModuleVersion) { $Version = [string]$manifest.ModuleVersion }
}
if ([string]::IsNullOrWhiteSpace($Version)) { $Version = 'dev' }

# ── Output dir ────────────────────────────────────────────────────────────────

$resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputDirectory))
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

if (-not (Test-Path -LiteralPath $resolvedOutput -PathType Container))
{
    New-Item -Path $resolvedOutput -ItemType Directory -Force | Out-Null
}

# ── Build launcher ────────────────────────────────────────────────────────────

$buildLauncherScript = Join-Path $PSScriptRoot 'Build-Launcher.ps1'
$repoExe             = Join-Path $repoRoot 'Baseline.exe'
$launcherProject     = Join-Path $repoRoot 'Launcher\RunLauncher.csproj'
$launcherSourceRoots  = @(
    (Join-Path $repoRoot 'Launcher')
    (Join-Path $repoRoot 'Bootstrap')
    (Join-Path $repoRoot 'Module')
    (Join-Path $repoRoot 'Localizations')
    (Join-Path $repoRoot 'Assets')
    (Join-Path $repoRoot 'Completion')
)

$needsBuild = -not (Test-Path -LiteralPath $repoExe -PathType Leaf)
if (-not $needsBuild -and (Test-Path -LiteralPath $launcherProject -PathType Leaf))
{
    $exeTime  = (Get-Item -LiteralPath $repoExe).LastWriteTimeUtc
    $srcFiles = @()
    foreach ($root in $launcherSourceRoots)
    {
        if (Test-Path -LiteralPath $root -PathType Container)
        {
            $srcFiles += Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue
        }
    }
    $srcFiles = $srcFiles | Where-Object {
        $_.FullName -notmatch '\\(bin|obj)\\'
    }
    $needsBuild = $srcFiles | Where-Object { $_.LastWriteTimeUtc -gt $exeTime } | Select-Object -First 1
}

if ($needsBuild)
{
    Write-Host 'Building launcher...' -ForegroundColor Cyan
    if (-not (Test-Path -LiteralPath $buildLauncherScript -PathType Leaf))
    {
        throw "Build-Launcher.ps1 not found: $buildLauncherScript"
    }
    & $buildLauncherScript -CopyToRepoRoot
    if ($LASTEXITCODE -ne 0) { throw "Build-Launcher.ps1 failed with exit code $LASTEXITCODE." }
}

if (-not (Test-Path -LiteralPath $repoExe -PathType Leaf))
{
    throw "Baseline.exe not found after launcher build: $repoExe"
}

# ── Build portable payload ────────────────────────────────────────────────────

$tempRoot    = Join-Path ([System.IO.Path]::GetTempPath()) ("BaselineInstaller_{0}" -f [System.Guid]::NewGuid().ToString('N'))
$tempDist    = Join-Path $tempRoot 'dist'
$tempExtract = Join-Path $tempRoot 'extract'
$tempScripts = Join-Path $tempRoot 'iss'
$archiveName = "Baseline-portable-$Version.zip"
$archivePath = Join-Path $tempDist $archiveName

try
{
    New-Item -Path $tempDist    -ItemType Directory -Force | Out-Null
    New-Item -Path $tempExtract -ItemType Directory -Force | Out-Null
    New-Item -Path $tempScripts -ItemType Directory -Force | Out-Null

    # Stage loose files and compress into the portable payload zip
    $stageRoot = Join-Path $tempRoot 'stage'
    $stageDir  = Join-Path $stageRoot 'Baseline'
    New-Item -Path $stageDir -ItemType Directory -Force | Out-Null

    foreach ($rel in @('Baseline.exe','Bootstrap','Module','Localizations','Assets','Completion','Tests','docs','README.md','LICENSE','CHANGELOG.md'))
    {
        $src = Join-Path $repoRoot $rel
        if (Test-Path -LiteralPath $src)
        {
            Copy-Item -LiteralPath $src -Destination $stageDir -Recurse -Force
        }
    }

    Get-ChildItem -LiteralPath $stageDir -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in @('.DS_Store','Thumbs.db') } |
        Remove-Item -Force -ErrorAction SilentlyContinue

    Compress-Archive -LiteralPath $stageDir -DestinationPath $archivePath -CompressionLevel Optimal -Force

    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf))
    {
        throw "Portable archive not created: $archivePath"
    }

    Expand-Archive -LiteralPath $archivePath -DestinationPath $tempExtract -Force
    $sourceRoot = Join-Path $tempExtract 'Baseline'
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container))
    {
        throw "Payload root missing after extraction: $sourceRoot"
    }

    # ── Stamp defines into a working copy of the .iss ────────────────────────

    $issContent = Get-Content -LiteralPath $templateIss -Raw
    $installerLocaleCodes = Get-InstallerLocaleCodes -TemplateContent $issContent
    $installerLocalizationRoot = Join-Path $tempRoot 'installer-localization'
    $installerLocalizationSource = Get-InstallerLocalizationSource

    Initialize-InstallerLocalizationWorkspace `
        -Root $installerLocalizationRoot `
        -SourceMap $installerLocalizationSource `
        -LocaleCodes $installerLocaleCodes

    Invoke-InstallerLocalizationTranslation -Root $installerLocalizationRoot

    # Inno Setup string constants treat backslashes literally, so keep paths raw here.
    $issContent = $issContent -replace '#define MyAppVersion\s+"[^"]*"',  "#define MyAppVersion `"$Version`""
    $issContent = $issContent -replace '#define MySourceRoot\s+"[^"]*"',  "#define MySourceRoot `"$sourceRoot`""
    $issContent = $issContent -replace '#define MyOutputDir\s+"[^"]*"',   "#define MyOutputDir  `"$resolvedOutput`""

    $generatedLocalization = New-InstallerLocalizationFunction `
        -SourceMap $installerLocalizationSource `
        -LocaleCodes $installerLocaleCodes `
        -LocalizationRoot $installerLocalizationRoot

    $functionStart = $issContent.IndexOf('function GetSetupString(Key: String): String;')
    $functionEnd   = $issContent.IndexOf('// Apply translated strings to all wizard pages after language is confirmed.')
    if (($functionStart -lt 0) -or ($functionEnd -lt 0) -or ($functionEnd -le $functionStart))
    {
        throw 'Unable to locate installer localization block in template.'
    }

    $issContent = $issContent.Substring(0, $functionStart) +
                  $generatedLocalization +
                  [Environment]::NewLine + [Environment]::NewLine +
                  $issContent.Substring($functionEnd)

    $stampedIss = Join-Path $tempScripts "Baseline-Setup-$Version.iss"
    [System.IO.File]::WriteAllText($stampedIss, $issContent, [System.Text.UTF8Encoding]::new($true))

    # ── Optionally persist the script only ───────────────────────────────────

    if ($GenerateScriptOnly)
    {
        $persistedPath = Join-Path $resolvedOutput "Baseline-Setup-$Version.iss"
        Copy-Item -LiteralPath $stampedIss -Destination $persistedPath -Force
        return [pscustomobject]@{
            ScriptPath    = $persistedPath
            InstallerPath = $null
            Version       = $Version
            Compiled      = $false
        }
    }

    # ── Compile ───────────────────────────────────────────────────────────────

    $resolvedIscc = Resolve-IsccPath -RequestedPath $IsccPath
    if ([string]::IsNullOrWhiteSpace($resolvedIscc))
    {
        throw 'Inno Setup compiler (ISCC.exe) not found. Install Inno Setup 6 or pass -IsccPath.'
    }

    $setupFileName = "Baseline-setup-$Version.exe"
    $setupPath     = Join-Path $resolvedOutput $setupFileName

    if ((Test-Path -LiteralPath $setupPath -PathType Leaf) -and -not $Force)
    {
        throw "Installer already exists: $setupPath. Re-run with -Force to overwrite."
    }
    if ((Test-Path -LiteralPath $setupPath -PathType Leaf) -and $Force)
    {
        Remove-Item -LiteralPath $setupPath -Force
    }

    if ($PSCmdlet.ShouldProcess($setupPath, 'Build Baseline setup executable'))
    {
        $process = Start-Process -FilePath $resolvedIscc -ArgumentList @('/Qp', "`"$stampedIss`"") `
                                 -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -ne 0)
        {
            throw "ISCC failed with exit code $($process.ExitCode)."
        }
    }

    if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf))
    {
        throw "Expected installer was not produced: $setupPath"
    }

    [pscustomobject]@{
        InstallerPath = $setupPath
        Version       = $Version
        SizeBytes     = [int64](Get-Item -LiteralPath $setupPath).Length
        Compiled      = $true
    }
}
finally
{
    if (Test-Path -LiteralPath $tempRoot)
    {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
