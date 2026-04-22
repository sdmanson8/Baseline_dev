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
    It 'reads ModuleVersion from a module manifest and prefixes it with v' {
        $moduleRoot = Join-Path $TestDrive 'ModuleRoot'
        $null = New-Item -ItemType Directory -Path $moduleRoot -Force
        $manifestPath = Join-Path $moduleRoot 'Baseline.psd1'
        Set-Content -LiteralPath $manifestPath -Value "@{ ModuleVersion = '2.0.0' }" -Encoding ASCII

        $result = Get-BaselineDisplayVersion -ModuleRoot $moduleRoot

        $result | Should -Be 'v2.0.0'
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
}

Describe 'Get-BaselineLatestReleaseEntry' {
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
}

Describe 'Bootstrap splash defaults' {
    It 'renders the custom splash title from the window title' {
        $script:EnvironmentHelpersContent | Should -Match 'Name="TitleText"'
        $script:EnvironmentHelpersContent | Should -Match 'Text="\{Binding RelativeSource=\{RelativeSource AncestorType=Window\}, Path=Title\}"'
    }

    It 'uses non-empty splash text fallbacks for initialization and idle restore' {
        ([regex]::Matches($script:EnvironmentHelpersContent, "Get-BaselineLocalizedString -Key 'GuiSplashLoading' -Fallback 'Please Wait\.\.\.'")).Count | Should -Be 3
        $script:EnvironmentHelpersContent | Should -Match "GuiSplashAutoClose' -Fallback 'This window will close automatically when ready\.'"
        $script:EnvironmentHelpersContent | Should -Match "GuiSplashSubtitle' -Fallback 'Windows Optimization & Hardening'"
    }

    It 'keeps every English splash localization on the neutral loading text' {
        foreach ($localeFile in $script:EnglishLocalizationFiles) {
            $content = Get-Content -LiteralPath $localeFile.FullName -Raw -Encoding UTF8
            $content | Should -Match '"GuiSplashLoading": "Please Wait\.\.\."'
        }
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
