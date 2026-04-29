Set-StrictMode -Version Latest

BeforeAll {
    <#
        .SYNOPSIS
        Internal function Get-BaselineLocalizedString.
    #>

    function Get-BaselineLocalizedString {
        param(
            [string]$Key,
            [string]$Fallback,
            [object[]]$FormatArgs = @()
        )

        if ($FormatArgs.Count -gt 0)
        {
            return ($Fallback -f $FormatArgs)
        }

        return $Fallback
    }

    <#
        .SYNOPSIS
        Internal function Get-BaselineBilingualString.
    #>

    function Get-BaselineBilingualString {
        param(
            [string]$Key,
            [string]$Fallback,
            [object[]]$FormatArgs = @()
        )

        if ($FormatArgs.Count -gt 0)
        {
            return ($Fallback -f $FormatArgs)
        }

        return $Fallback
    }

    <#
        .SYNOPSIS
        Internal function LogInfo.
    #>

    function LogInfo { param([object]$Message) }
    <#
        .SYNOPSIS
        Internal function .
    #>
    function LogWarning { param([object]$Message) }
    <#
        .SYNOPSIS
        Internal function .
    #>
    function LogError { param([object]$Message) }
    <#
        .SYNOPSIS
        Internal function Write-DebugSwallowedException.
    #>
    function Write-DebugSwallowedException {
        param(
            [object]$ErrorRecord,
            [string]$Source
        )

        [void]$script:DebugSwallowedExceptionCalls.Add([pscustomobject]@{
            Source  = [string]$Source
            Message = if ($ErrorRecord -and $ErrorRecord.Exception) { [string]$ErrorRecord.Exception.Message } else { [string]$ErrorRecord }
        })
    }

    # Json helpers must load first — Environment.Helpers calls ConvertFrom-BaselineJson.
    . (Join-Path $PSScriptRoot '../../Module/SharedHelpers/Json.Helpers.ps1')

    $filePath = Join-Path $PSScriptRoot '../../Module/SharedHelpers/Environment.Helpers.ps1'
    $script:EnvironmentHelpersContent = Get-Content -LiteralPath $filePath -Raw -Encoding UTF8
    $script:EnglishLocalizationFiles = @(
        Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '../../Localizations') -Directory |
            Where-Object { $_.Name -like 'English*' } |
            ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter '*.json' -File }
    )
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $functions) {
        Invoke-Expression $fn.Extent.Text
    }

    <#
        .SYNOPSIS
        Internal function .
    #>
    function Set-DownloadSecurityProtocol { }

    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase -ErrorAction Stop
    if (-not ('TestSplashDispatcher' -as [type]))
    {
        Add-Type -TypeDefinition @'
using System;

public class TestSplashDispatcher
{
    public bool HasShutdownStarted { get; set; }

    public void Invoke(Action action)
    {
        if (action != null)
        {
            action();
        }
    }
}

public class TestSplashElement
{
    public object Text { get; set; }
    public object Visibility { get; set; }
    public object Foreground { get; set; }
    public object Stroke { get; set; }
    public object Fill { get; set; }
    public object RenderTransform { get; set; }
    public double Opacity { get; set; }

    public TestSplashElement()
    {
        Opacity = 1.0;
    }

    public void BeginAnimation(object property, object animation) { }
    public void BeginAnimation(object property, object animation, object handoffBehavior) { }
}

public class TestProgressBar
{
    public object Visibility { get; set; }
    public bool IsIndeterminate { get; set; }
    public double Maximum { get; set; }
    public double Value { get; set; }
    public double Width { get; set; }
    public double ActualWidth { get; set; }

    public TestProgressBar()
    {
        Maximum = 330.0;
        Width = 330.0;
        ActualWidth = 330.0;
    }

    public void BeginAnimation(object property, object animation)
    {
        ApplyAnimation(animation);
    }

    public void BeginAnimation(object property, object animation, object handoffBehavior)
    {
        ApplyAnimation(animation);
    }

    private void ApplyAnimation(object animation)
    {
        if (animation == null)
        {
            return;
        }

        var animationType = animation.GetType();
        var toProperty = animationType.GetProperty("To");
        if (toProperty == null)
        {
            return;
        }

        var toValue = toProperty.GetValue(animation, null);
        if (toValue is double)
        {
            Value = (double)toValue;
        }
    }
}
'@
    }

    $script:DebugSwallowedExceptionCalls = [System.Collections.Generic.List[object]]::new()
}

Describe 'Invoke-UCPDBypassed' {
    It 'throws on non-zero exit codes and still removes the temporary executable' {
        $tempPath = Join-Path $TestDrive 'powershell_temp.cmd'

        Mock Get-UCPDTemporaryPowerShellPath { $tempPath }
        Mock Copy-Item {
            param($Path, $Destination)
            Set-Content -LiteralPath $Destination -Value "@exit /b 5" -Encoding ASCII
        }
        Mock Remove-Item {}

        { Invoke-UCPDBypassed -ScriptBlock { 'noop' } } | Should -Throw '*exit code 5*'
        Assert-MockCalled Remove-Item -Times 1 -ParameterFilter {
            $Path -eq $tempPath -and $Force
        }
    }
}

Describe 'Get-UCPDTemporaryPowerShellPath' {
    It 'creates a GUID-suffixed executable path in the source directory' {
        $sourceDirectory = Join-Path $TestDrive 'WindowsPowerShell/v1.0'
        $null = New-Item -ItemType Directory -Path $sourceDirectory -Force
        $sourcePath = Join-Path $sourceDirectory 'powershell.exe'

        $path = Get-UCPDTemporaryPowerShellPath -SourcePath $sourcePath

        Split-Path -Path $path -Parent | Should -Be (Split-Path -Path $sourcePath -Parent)
        Split-Path -Path $path -Leaf | Should -Match '^powershell_[0-9a-f]{32}\.exe$'
    }

    It 'returns a unique path for each call' {
        $sourceDirectory = Join-Path $TestDrive 'WindowsPowerShell/v1.0'
        $null = New-Item -ItemType Directory -Path $sourceDirectory -Force
        $sourcePath = Join-Path $sourceDirectory 'powershell.exe'
        $first = Get-UCPDTemporaryPowerShellPath -SourcePath $sourcePath
        $second = Get-UCPDTemporaryPowerShellPath -SourcePath $sourcePath

        $first | Should -Not -Be $second
    }
}

Describe 'Get-BaselineDisplayVersion' {
    BeforeEach {
        $script:DebugSwallowedExceptionCalls.Clear()
    }

    It 'reads ModuleVersion from a module manifest and prefixes it with v' {
        $moduleRoot = Join-Path $TestDrive 'ModuleRoot'
        $null = New-Item -ItemType Directory -Path $moduleRoot -Force
        $manifestPath = Join-Path $moduleRoot 'Baseline.psd1'
        Set-Content -LiteralPath $manifestPath -Value "@{ ModuleVersion = '2.0.0' }" -Encoding ASCII

        $result = Get-BaselineDisplayVersion -ModuleRoot $moduleRoot

        $result | Should -Be 'v2.0.0'
    }

    It 'routes manifest parse failures through Write-DebugSwallowedException and returns null' {
        $moduleRoot = Join-Path $TestDrive 'BrokenModuleRoot'
        $null = New-Item -ItemType Directory -Path $moduleRoot -Force
        $manifestPath = Join-Path $moduleRoot 'Baseline.psd1'
        Set-Content -LiteralPath $manifestPath -Value "@{ ModuleVersion = '2.0.0' }" -Encoding ASCII

        Mock Import-EnvironmentPowerShellDataFile { throw 'manifest parse failed' } -ParameterFilter { $Path -eq $manifestPath }

        Get-BaselineDisplayVersion -ModuleRoot $moduleRoot | Should -BeNullOrEmpty
        $script:DebugSwallowedExceptionCalls.Count | Should -Be 1
        $script:DebugSwallowedExceptionCalls[0].Source | Should -Be 'Environment.GetBaselineDisplayVersion.LoadManifest'
    }
}

Describe 'Get-BaselineWindowsThemePreference' {
    BeforeEach {
        $script:DebugSwallowedExceptionCalls.Clear()
    }

    It 'routes registry read failures through Write-DebugSwallowedException and returns null' {
        Mock Get-ItemProperty { throw 'registry read failed' } -ParameterFilter {
            $LiteralPath -eq 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        }

        Get-BaselineWindowsThemePreference | Should -BeNullOrEmpty
        $script:DebugSwallowedExceptionCalls.Count | Should -Be 1
        $script:DebugSwallowedExceptionCalls[0].Source | Should -Be 'Environment.GetBaselineWindowsThemePreference.LoadTheme'
    }
}

Describe 'Get-BaselineStartupThemeName' {
    BeforeEach {
        $script:DebugSwallowedExceptionCalls.Clear()
    }

    It 'prefers the saved session theme over the Windows theme' {
        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -like '*Baseline-last-session.json' }
        Mock Get-Content { '{}' } -ParameterFilter { $LiteralPath -like '*Baseline-last-session.json' }
        Mock ConvertFrom-BaselineJson {
            [pscustomobject]@{
                State = @{
                    Theme = 'Dark'
                }
            }
        }

        Get-BaselineStartupThemeName | Should -Be 'Dark'
    }

    It 'falls back to the current Windows theme when no saved session exists' {
        Mock Test-Path { $false } -ParameterFilter { $LiteralPath -like '*Baseline-last-session.json' }
        Mock Get-BaselineWindowsThemePreference { 'Light' }

        Get-BaselineStartupThemeName | Should -Be 'Light'
    }

    It 'routes session read failures through Write-DebugSwallowedException and falls back to the Windows theme' {
        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -like '*Baseline-last-session.json' }
        Mock Get-Content { throw 'session read failed' } -ParameterFilter { $LiteralPath -like '*Baseline-last-session.json' }
        Mock Get-BaselineWindowsThemePreference { 'Dark' }

        Get-BaselineStartupThemeName | Should -Be 'Dark'
        $script:DebugSwallowedExceptionCalls.Count | Should -Be 1
        $script:DebugSwallowedExceptionCalls[0].Source | Should -Be 'Environment.GetBaselineStartupThemeName.LoadSession'
    }
}

Describe 'Compare-BaselineReleaseVersions' {
    It 'treats a newer major version as higher even when an older prerelease appears first' {
        (Compare-BaselineReleaseVersions -LeftVersion 'v4.0.0-beta' -RightVersion 'v3.0.0-beta') | Should -BeGreaterThan 0
    }

    It 'treats stable releases as newer than prereleases of the same core version' {
        (Compare-BaselineReleaseVersions -LeftVersion 'v4.0.0' -RightVersion 'v4.0.0-beta') | Should -BeGreaterThan 0
    }

    It 'treats rc builds as newer than beta builds of the same core version' {
        (Compare-BaselineReleaseVersions -LeftVersion 'v4.0.0-rc1' -RightVersion 'v4.0.0-beta') | Should -BeGreaterThan 0
    }

    It 'normalizes display-version prerelease text in parentheses' {
        (Compare-BaselineReleaseVersions -LeftVersion 'v4.0.0 (beta)' -RightVersion 'v4.0.0-beta') | Should -Be 0
    }
}

Describe 'Show-BootstrapLoadingSplash' {
    It 'shows the splash in the taskbar when minimized' {
        $script:EnvironmentHelpersContent | Should -Match 'ShowInTaskbar="True"'
        $script:EnvironmentHelpersContent | Should -Not -Match 'ShowInTaskbar="False"'
    }

    It 'can prime the updates step, status, and progress bar when the splash loads' {
        $script:EnvironmentHelpersContent | Should -Match '\[switch\]\$StartUpdatesPulse'
        $script:EnvironmentHelpersContent | Should -Match 'splashLocCheckingForUpdates'
        $script:EnvironmentHelpersContent | Should -Match 'bootstrapLoadingSplashStepCommand'
        $script:EnvironmentHelpersContent | Should -Match 'bootstrapLoadingSplashStateCommand'
        $script:EnvironmentHelpersContent | Should -Match '& \$bootstrapLoadingSplashStepCommand -Splash \$syncHash -StepId ''updates'' -Status ''in_progress'''
        $script:EnvironmentHelpersContent | Should -Match '& \$bootstrapLoadingSplashStateCommand -Splash \$syncHash -StatusText \$splashLocCheckingForUpdates -Indeterminate'
        $script:EnvironmentHelpersContent | Should -Match '\$splash\.Add_Loaded\(\{[\s\S]*& \$startUpdatesPulseAction'
    }

    It 'uses a value-driven progress bar template with standard named parts' {
        $script:EnvironmentHelpersContent | Should -Match '<ProgressBar Name="ProgressBar"'
        $script:EnvironmentHelpersContent | Should -Match 'x:Name="PART_Track"'
        $script:EnvironmentHelpersContent | Should -Match 'x:Name="PART_Indicator"'
        $script:EnvironmentHelpersContent | Should -Match 'x:Name="PART_GlowRect"'
        $script:EnvironmentHelpersContent | Should -Match 'Width="\{TemplateBinding Value\}"'
        $script:EnvironmentHelpersContent | Should -Not -Match '<Border Background="\{TemplateBinding Foreground\}" CornerRadius="2"\s*/>'
    }

    It 'scales splash progress values to the rendered bar width' {
        $script:EnvironmentHelpersContent | Should -Match 'function Get-BaselineSplashProgressWidth'
        $script:EnvironmentHelpersContent | Should -Match '\$barWidth = Get-BaselineSplashProgressWidth -ProgressBar \$progressBar'
        $script:EnvironmentHelpersContent | Should -Match '\$progressBar.Maximum = \$barWidth'
        $script:EnvironmentHelpersContent | Should -Match '\$progressBar.Value = \[Math\]::Round\(\(\(\$safeCompleted / \$safeTotal\) \* \$barWidth\), 3\)'
        $script:EnvironmentHelpersContent | Should -Match '\$snapTo = \(\[double\]\$activeIdx / \$stepCount\) \* \$barWidth'
        $script:EnvironmentHelpersContent | Should -Match '\$anim.To   = \(\[double\]\$completedCount / \$stepCount\) \* \$barWidth'
    }

    It 'routes splash icon failures through debug logging and chrome failures through launch tracing' {
        $script:EnvironmentHelpersContent | Should -Match 'function Show-BootstrapLoadingSplash'
        $script:EnvironmentHelpersContent | Should -Match 'Environment\.ShowBootstrapLoadingSplash\.LoadSplashIcon'
        $script:EnvironmentHelpersContent | Should -Match 'Bootstrap splash chrome setup failed'
    }

    It 'does not release startup until the splash content has rendered' {
        $script:EnvironmentHelpersContent | Should -Match 'WasLoaded\s*=\s*\$false'
        $script:EnvironmentHelpersContent | Should -Match 'WasRendered\s*=\s*\$false'
        $script:EnvironmentHelpersContent | Should -Match '\$splash\.Add_Loaded\(\{[\s\S]*\$syncHash\.WasLoaded = \$true'
        $script:EnvironmentHelpersContent | Should -Match '\$splash\.Add_ContentRendered\(\{[\s\S]*\$syncHash\.WasRendered = \$true[\s\S]*\$syncHash\.IsReady = \$true'
        $script:EnvironmentHelpersContent | Should -Match 'if \(\(-not \$syncHash\.IsAlive\) -or \(-not \$syncHash\.WasRendered\)\)'

        $loadedBlock = [regex]::Match(
            $script:EnvironmentHelpersContent,
            '(?s)\$splash\.Add_Loaded\(\{.*?\}\)\s*\r?\n\r?\n\s*\$splash\.Add_ContentRendered'
        ).Value
        $loadedSuccessBlock = [regex]::Match($loadedBlock, '(?s)try\s*\{(?<Body>.*?)\}\s*catch').Groups['Body'].Value
        $loadedSuccessBlock | Should -Not -Match '\$syncHash\.WasShown = \$true'
        $loadedSuccessBlock | Should -Not -Match '\$syncHash\.IsReady = \$true'
    }

    It 'records splash thread failures instead of reporting a successful splash' {
        $script:EnvironmentHelpersContent | Should -Match 'ErrorMessage\s*=\s*\$null'
        $script:EnvironmentHelpersContent | Should -Match 'Bootstrap splash runspace failed'
        $script:EnvironmentHelpersContent | Should -Match 'Bootstrap splash failed before it became visible'
    }
}

Describe 'Get-BaselineLatestReleaseEntry' {
    BeforeEach {
        $script:DebugSwallowedExceptionCalls.Clear()
    }

    It 'selects the highest non-draft release regardless of API ordering' {
        $releases = @(
            [pscustomobject]@{ draft = $false; tag_name = 'v3.0.0-beta'; published_at = '2026-03-01T00:00:00Z' }
            [pscustomobject]@{ draft = $false; tag_name = 'v4.0.0-beta'; published_at = '2026-04-01T00:00:00Z' }
        )

        $result = Get-BaselineLatestReleaseEntry -Releases $releases

        [string]$result.tag_name | Should -Be 'v4.0.0-beta'
    }

    It 'prefers a stable release over a prerelease with the same core version' {
        $releases = @(
            [pscustomobject]@{ draft = $false; tag_name = 'v4.0.0-beta'; published_at = '2026-04-01T00:00:00Z' }
            [pscustomobject]@{ draft = $false; tag_name = 'v4.0.0'; published_at = '2026-04-02T00:00:00Z' }
        )

        $result = Get-BaselineLatestReleaseEntry -Releases $releases

        [string]$result.tag_name | Should -Be 'v4.0.0'
    }

    It 'skips malformed published_at values after routing the parse error' {
        $releases = @(
            [pscustomobject]@{ draft = $false; tag_name = 'v3.0.0-beta'; published_at = 'not-a-date' }
            [pscustomobject]@{ draft = $false; tag_name = 'v4.0.0'; published_at = '2026-04-02T00:00:00Z' }
        )

        $result = Get-BaselineLatestReleaseEntry -Releases $releases

        [string]$result.tag_name | Should -Be 'v4.0.0'
        $script:DebugSwallowedExceptionCalls.Count | Should -Be 1
        $script:DebugSwallowedExceptionCalls[0].Source | Should -Be 'Environment.GetBaselineLatestReleaseEntry.ParsePublishedAt'
    }
}

Describe 'Get-BaselineValidationMatrixSummary' {
    It 'loads server coverage from the integration validation matrix' {
        $repoRoot = Join-Path $TestDrive 'RepoRoot'
        $matrixRoot = Join-Path $repoRoot 'Tests/Integration'
        $null = New-Item -ItemType Directory -Path $matrixRoot -Force
        $matrixPath = Join-Path $matrixRoot 'DesktopMatrixResults.json'
        Set-Content -LiteralPath $matrixPath -Encoding UTF8 -Value @'
{
  "summary": {
    "testedDesktopEditions": ["Windows 11 Pro (26100)"],
    "pendingDesktopEditions": ["Windows 10 22H2"],
    "serverEditions": ["Windows Server 2022 (CI only)"]
  }
}
'@

        $result = Get-BaselineValidationMatrixSummary -RepoRoot $repoRoot

        $result.Summary | Should -Be 'Validated: Windows 11 Pro (26100) | Pending: Windows 10 22H2 | Server: Windows Server 2022 (CI only)'
        $result.ServerValidationSummary | Should -Be 'CI only: Windows Server 2022 (CI only)'
        $result.ServerCoverageStatus | Should -Be 'CIOnly'
        $result.HasServerCoverage | Should -BeTrue
        $result.ServerCIOnly | Should -BeTrue
    }
}

Describe 'Get-BaselineValidationEvidenceReport' {
    It 'combines test report and validation matrix channels into a provenance summary' {
        $repoRoot = Join-Path $TestDrive 'RepoRoot'
        $testsRoot = Join-Path $repoRoot 'Tests'
        $integrationRoot = Join-Path $testsRoot 'Integration'
        $null = New-Item -ItemType Directory -Path $integrationRoot -Force

        Set-Content -LiteralPath (Join-Path $testsRoot 'TestReport.json') -Encoding UTF8 -Value @'
{
  "generated": "2026-04-14T14:38:31.7842438+02:00",
  "platform": {
    "os": "Microsoft Windows NT 10.0.26100.0",
    "edition": "Core",
    "psVersion": "7.6.0",
    "hostname": "SHELDON"
  },
  "layers": {
    "unit": {
      "result": "Passed",
      "passed": 2640,
      "failed": 0,
      "skipped": 4
    },
    "composition": {
      "result": "Passed",
      "passed": 27,
      "failed": 0,
      "skipped": 0
    }
  },
  "summary": {
    "overallResult": "Passed"
  }
}
'@

        Set-Content -LiteralPath (Join-Path $integrationRoot 'DesktopMatrixResults.json') -Encoding UTF8 -Value @'
{
  "summary": {
    "testedDesktopEditions": ["Windows 11 Pro (26100)"],
    "pendingDesktopEditions": [],
    "serverEditions": ["Windows Server 2022 (CI only)"]
  }
}
'@

        $result = Get-BaselineValidationEvidenceReport -RepoRoot $repoRoot

        $result.Schema | Should -Be 'Baseline.ValidationEvidence'
        $result.Summary | Should -Be 'unit-tested; desktop-session CI validated; server CI only'
        @($result.ValidationChannels).Count | Should -Be 3
        ($result.ValidationChannels | Where-Object Channel -eq 'unit-tested').Status | Should -Be 'Passed'
        ($result.ValidationChannels | Where-Object Channel -eq 'desktop-session CI validated').Status | Should -Be 'Passed'
        ($result.ValidationChannels | Where-Object Channel -eq 'server CI only').Status | Should -Be 'CI only'
    }
}

Describe 'Invoke-BaselineAutoUpdate' {
    BeforeEach {
        Remove-Item Env:\BASELINE_EMBEDDED_HOST -ErrorAction SilentlyContinue
        Remove-Item Env:\BASELINE_INSTALLER_MODE -ErrorAction SilentlyContinue
        Remove-Item Env:\BASELINE_SKIP_UPDATE -ErrorAction SilentlyContinue
        Remove-Item Env:\BASELINE_LAUNCHER_PATH -ErrorAction SilentlyContinue
        $script:loggedInfoMessages = [System.Collections.Generic.List[string]]::new()
        Mock LogInfo {
            param([object]$Message)
            [void]$script:loggedInfoMessages.Add([string]$Message)
        }
    }

    It 'stays idle when the launcher flag is missing' {
        Mock Invoke-RestMethod {
            throw 'release lookup should not run'
        }
        Mock Set-BootstrapLoadingSplashState {}
        Mock Close-LoadingSplashWindow {}

        { Invoke-BaselineAutoUpdate -CurrentVersion '4.0.0' } | Should -Not -Throw
        Assert-MockCalled Invoke-RestMethod -Times 0
    }

    It 'queries GitHub when Baseline.exe launches the updater' {
        $env:BASELINE_EMBEDDED_HOST = '1'
        $env:BASELINE_LAUNCHER_PATH = Join-Path $TestDrive 'Baseline.exe'
        Set-Content -LiteralPath $env:BASELINE_LAUNCHER_PATH -Value '' -Encoding ASCII

        Mock Set-DownloadSecurityProtocol {}
        Mock Invoke-RestMethod {
            [pscustomobject]@{
                draft    = $false
                tag_name = '4.0.0'
                assets   = @()
            }
        }
        Mock Set-BootstrapLoadingSplashState {}
        Mock Close-LoadingSplashWindow {}

        { Invoke-BaselineAutoUpdate -CurrentVersion '4.0.0' } | Should -Not -Throw
        Assert-MockCalled Set-DownloadSecurityProtocol -Times 1
        Assert-MockCalled Invoke-RestMethod -Times 1
    }

    It 'uses the highest non-draft release tag when deciding whether the current build is up to date' {
        $env:BASELINE_EMBEDDED_HOST = '1'
        $env:BASELINE_LAUNCHER_PATH = Join-Path $TestDrive 'Baseline.exe'
        Set-Content -LiteralPath $env:BASELINE_LAUNCHER_PATH -Value '' -Encoding ASCII

        Mock Set-DownloadSecurityProtocol {}
        Mock Invoke-RestMethod {
            @(
                [pscustomobject]@{
                    draft    = $false
                    tag_name = 'v3.0.0-beta'
                    assets   = @()
                }
                [pscustomobject]@{
                    draft    = $false
                    tag_name = 'v4.0.0-beta'
                    assets   = @()
                }
            )
        }
        Mock Set-BootstrapLoadingSplashState {}
        Mock Close-LoadingSplashWindow {}

        { Invoke-BaselineAutoUpdate -CurrentVersion 'v4.0.0 (beta)' } | Should -Not -Throw

        ($script:loggedInfoMessages -join "`n") | Should -Match 'Already up to date \(latest: v4\.0\.0-beta\)\.'
    }
}

Describe 'Get-LocalizedShellString' {
    It 'falls back and strips accelerators when the shell resource is unavailable' {
        $result = Get-LocalizedShellString -ResourceId 1 -Fallback '&Skip' -StripAccelerators

        $result | Should -Be 'Skip'
    }
}

Describe 'Baseline markdown runtime' {
    BeforeEach {
        $script:CachedBaselineMarkdownRuntimeLoaded = $false
        $script:DebugSwallowedExceptionCalls.Clear()
    }

    It 'uses loaded AppDomain assemblies instead of Type.GetType for Markdig readiness checks' {
        $content = Get-Content -LiteralPath $filePath -Raw -Encoding UTF8

        $content | Should -Match '\[System\.AppDomain\]::CurrentDomain\.GetAssemblies\(\)'
        $content | Should -Match 'GetType\(''Markdig\.Wpf\.Markdown'', \$false, \$false\)'
        $content | Should -Not -Match 'Type\]::GetType\(''Markdig\.Wpf\.Markdown, Markdig\.Wpf''\)'
    }

    It 'loads the bundled Markdig runtime and renders markdown to html' {
        $moduleRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../Module'))

        Initialize-BaselineMarkdownRuntime -ModuleRoot $moduleRoot | Should -BeTrue
        Test-BaselineMarkdownRuntimeReady | Should -BeTrue

        $html = ConvertFrom-BaselineMarkdownToHtml -Markdown '# Title'

        $html | Should -Match '<h1'
        $html | Should -Match 'Title'
    }

    It 'renders anchored FlowDocuments for README in-page links' {
        $moduleRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../Module'))

        Initialize-BaselineMarkdownRuntime -ModuleRoot $moduleRoot | Should -BeTrue
        Test-BaselineMarkdownRuntimeReady | Should -BeTrue

        $result = ConvertFrom-BaselineMarkdownToAnchoredFlowDocument -Markdown "# Title`r`n`r`n[Jump](#title)"

        $result.Document | Should -Not -BeNullOrEmpty
        $result.AnchorMap.ContainsKey('title') | Should -BeTrue
        @($result.Hyperlinks).Count | Should -BeGreaterThan 0
        [string]$result.Hyperlinks[0].NavigateUri.OriginalString | Should -Be '#title'
    }

    It 'routes assembly load failures through Write-DebugSwallowedException' {
        $moduleRoot = Join-Path $TestDrive 'MarkdownModuleRoot'
        $librariesRoot = Join-Path $moduleRoot 'Libraries'
        $null = New-Item -ItemType Directory -Path $librariesRoot -Force
        foreach ($dllName in @(
            'System.Buffers.dll',
            'System.Runtime.CompilerServices.Unsafe.dll',
            'System.Numerics.Vectors.dll',
            'System.Memory.dll',
            'Markdig.dll',
            'Markdig.Wpf.dll'
        ))
        {
            $null = New-Item -ItemType File -Path (Join-Path $librariesRoot $dllName) -Force
        }

        Mock Test-BaselineMarkdownRuntimeReady { $false }
        Initialize-BaselineMarkdownRuntime -ModuleRoot $moduleRoot | Should -BeFalse
        (@($script:DebugSwallowedExceptionCalls | Where-Object Source -eq 'Environment.InitializeBaselineMarkdownRuntime.AddAssembly')).Count | Should -Be 6
    }
}

Describe 'Baseline webview2 runtime' {
    BeforeEach {
        $script:CachedBaselineWebView2RuntimeLoaded = $false
        $script:DebugSwallowedExceptionCalls.Clear()
    }

    It 'routes assembly load failures through Write-DebugSwallowedException' {
        $moduleRoot = Join-Path $TestDrive 'WebView2ModuleRoot'
        $librariesRoot = Join-Path $moduleRoot 'Libraries'
        $null = New-Item -ItemType Directory -Path $librariesRoot -Force
        foreach ($dllName in @('Microsoft.Web.WebView2.Core.dll', 'Microsoft.Web.WebView2.WinForms.dll'))
        {
            $null = New-Item -ItemType File -Path (Join-Path $librariesRoot $dllName) -Force
        }

        Mock Test-Path { $true } -ParameterFilter {
            $LiteralPath -eq $moduleRoot -or
            $LiteralPath -eq $librariesRoot -or
            $LiteralPath -eq (Join-Path $librariesRoot 'Microsoft.Web.WebView2.Core.dll') -or
            $LiteralPath -eq (Join-Path $librariesRoot 'Microsoft.Web.WebView2.WinForms.dll')
        }

        Mock Test-BaselineWebView2RuntimeReady { $false }
        Initialize-BaselineWebView2Runtime -ModuleRoot $moduleRoot | Should -BeFalse
        (@($script:DebugSwallowedExceptionCalls | Where-Object Source -eq 'Environment.InitializeBaselineWebView2Runtime.AddAssembly')).Count | Should -Be 2
    }
}

Describe 'Bootstrap splash defaults' {
    It 'renders the custom splash title from the window title' {
        $script:EnvironmentHelpersContent | Should -Match 'Name="TitleText"'
        $script:EnvironmentHelpersContent | Should -Match 'Text="\{Binding RelativeSource=\{RelativeSource AncestorType=Window\}, Path=Title\}"'
    }

    It 'uses non-empty splash text fallbacks for initialization and idle restore' {
        ([regex]::Matches($script:EnvironmentHelpersContent, "Get-BaselineLocalizedString -Key 'GuiSplashLoading' -Fallback 'Please Wait\.\.\.'")).Count | Should -Be 3
        $script:EnvironmentHelpersContent | Should -Match "GuiSplashSubtitle' -Fallback 'Windows Optimization & Hardening'"
        $script:EnvironmentHelpersContent | Should -Not -Match 'GuiSplashAutoClose|autoCloseEsc|This window will close automatically when ready'
    }

    It 'keeps every English splash localization on the neutral loading text' {
        foreach ($localeFile in $script:EnglishLocalizationFiles) {
            $content = Get-Content -LiteralPath $localeFile.FullName -Raw -Encoding UTF8
            $content | Should -Match '"GuiSplashLoading": "(Please|Kindly) Wait\.\.\."'
        }
    }
}

Describe 'Bootstrap splash progress' {
    It 'preserves the current fill when an indeterminate status update arrives' {
        $dispatcher = [TestSplashDispatcher]::new()
        $statusText = [TestSplashElement]::new()
        $subActionPanel = [TestSplashElement]::new()
        $progressBar = [TestProgressBar]::new()
        $progressBar.Value = 132
        $progressBar.Maximum = 330
        $progressBar.IsIndeterminate = $false
        $progressBar.Visibility = [System.Windows.Visibility]::Collapsed

        $splash = @{
            Window = [pscustomobject]@{}
            Dispatcher = $dispatcher
            StatusText = $statusText
            SubActionPanel = $subActionPanel
            ProgressBar = $progressBar
        }

        Set-BootstrapLoadingSplashState -Splash $splash -StatusText 'Checking installation status...' -Indeterminate | Should -BeTrue

        $statusText.Text | Should -Be 'Checking installation status...'
        $subActionPanel.Visibility | Should -Be ([System.Windows.Visibility]::Visible)
        $progressBar.Visibility | Should -Be ([System.Windows.Visibility]::Visible)
        $progressBar.IsIndeterminate | Should -BeTrue
        $progressBar.Value | Should -Be 132
        $progressBar.Maximum | Should -Be 330
    }

    It 'shows the splash status line for indeterminate updates even when the status text is blank' {
        $dispatcher = [TestSplashDispatcher]::new()
        $statusText = [TestSplashElement]::new()
        $subActionPanel = [TestSplashElement]::new()
        $subActionPanel.Visibility = [System.Windows.Visibility]::Collapsed
        $progressBar = [TestProgressBar]::new()
        $progressBar.Visibility = [System.Windows.Visibility]::Collapsed
        $progressBar.IsIndeterminate = $false

        $splash = @{
            Window = [pscustomobject]@{}
            Dispatcher = $dispatcher
            StatusText = $statusText
            SubActionPanel = $subActionPanel
            ProgressBar = $progressBar
        }

        Set-BootstrapLoadingSplashState -Splash $splash -StatusText ([string]::Empty) -Indeterminate | Should -BeTrue

        $subActionPanel.Visibility | Should -Be ([System.Windows.Visibility]::Visible)
        $progressBar.Visibility | Should -Be ([System.Windows.Visibility]::Visible)
        $progressBar.IsIndeterminate | Should -BeTrue
    }

    It 'restores determinate mode before a splash step advances the bar' {
        $dispatcher = [TestSplashDispatcher]::new()
        $progressBar = [TestProgressBar]::new()
        $progressBar.IsIndeterminate = $true
        $progressBar.Value = 0
        $progressBar.Maximum = 1

        $stepIds = @('updates', 'system', 'winget', 'chocolatey', 'finalize')
        $stepGlyphs = @{}
        $stepIdleDots = @{}
        $stepPulseDots = @{}
        $stepChecks = @{}
        $stepLabels = @{}
        $stepStates = @{}
        foreach ($stepId in $stepIds)
        {
            $stepGlyphs[$stepId] = [TestSplashElement]::new()
            $stepIdleDots[$stepId] = [TestSplashElement]::new()
            $pulseDot = [TestSplashElement]::new()
            $pulseDot.RenderTransform = [System.Windows.Media.ScaleTransform]::new()
            $stepPulseDots[$stepId] = $pulseDot
            $stepChecks[$stepId] = [TestSplashElement]::new()
            $stepLabels[$stepId] = [TestSplashElement]::new()
            $stepStates[$stepId] = 'pending'
        }

        $splash = @{
            Window = [pscustomobject]@{}
            Dispatcher = $dispatcher
            StepGlyphs = $stepGlyphs
            StepIdleDots = $stepIdleDots
            StepPulseDots = $stepPulseDots
            StepChecks = $stepChecks
            StepLabels = $stepLabels
            StepStates = $stepStates
            ProgressBar = $progressBar
            SplashTheme = [pscustomobject]@{
                Muted   = '#6C7086'
                Sub     = '#A6ADC8'
                Primary = '#CDD6F4'
                Accent  = '#89B4FA'
            }
            StepOrder = $stepIds
        }

        Set-BootstrapLoadingSplashStep -Splash $splash -StepId 'system' -Status 'in_progress' -SubAction '' | Should -BeTrue

        $progressBar.IsIndeterminate | Should -BeFalse
        $progressBar.Value | Should -BeGreaterThan 0
        $progressBar.Maximum | Should -Be 330
    }
}

Describe 'Test-IsVirtualMachine' {
    It 'returns $true when Win32_ComputerSystem reports a virtual-machine model' {
        Mock Get-CimInstance {
            [pscustomobject]@{ Model = 'Virtual Machine' }
        } -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }

        Test-IsVirtualMachine | Should -BeTrue
    }

    It 'returns $true for known hypervisor signatures (VMware, VBOX)' {
        Mock Get-CimInstance {
            [pscustomobject]@{ Model = 'VMware Virtual Platform' }
        } -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }
        Test-IsVirtualMachine | Should -BeTrue

        Mock Get-CimInstance {
            [pscustomobject]@{ Model = 'VirtualBox (VBOX)' }
        } -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }
        Test-IsVirtualMachine | Should -BeTrue
    }

    It 'returns $false for a physical machine model' {
        Mock Get-CimInstance {
            [pscustomobject]@{ Model = 'OptiPlex 7090' }
        } -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }

        Test-IsVirtualMachine | Should -BeFalse
    }

    It 'returns $false when CIM lookup fails rather than throwing' {
        Mock Get-CimInstance { throw 'cim offline' } -ParameterFilter { $ClassName -eq 'Win32_ComputerSystem' }

        Test-IsVirtualMachine | Should -BeFalse
    }
}
