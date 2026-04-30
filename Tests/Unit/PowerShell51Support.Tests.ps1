Set-StrictMode -Version Latest

BeforeAll {
    $script:ModuleManifestPath = Join-Path $PSScriptRoot '../../Module/Baseline.psd1'
    $script:ShortcutLauncherPath = Join-Path $PSScriptRoot '../../ShortcutLauncher/Program.cs'

    $script:RuntimeContractFiles = @(
        (Join-Path $PSScriptRoot '../../Module/SharedHelpers/ScenarioMode.Helpers.ps1')
        (Join-Path $PSScriptRoot '../../Module/GUI/SystemScan.ps1')
        (Join-Path $PSScriptRoot '../../Module/GUI/PresetManagement.ps1')
        (Join-Path $PSScriptRoot '../../Tools/Add-MissingMetadata.ps1')
        (Join-Path $PSScriptRoot '../../Tools/Generate-PresetFiles.ps1')
    )

    $script:ExampleFiles = @(
        (Join-Path $PSScriptRoot '../../Tools/Validate-ManifestData.ps1')
        (Join-Path $PSScriptRoot '../../Tools/Test-SmokeTest.ps1')
        (Join-Path $PSScriptRoot '../../Tools/Test-ReleaseSmoke.ps1')
        (Join-Path $PSScriptRoot '../../Tools/Test-ScreenshotDrift.ps1')
        (Join-Path $PSScriptRoot '../../Tools/Test-PresetGeneration.ps1')
        (Join-Path $PSScriptRoot '../../Tools/Test-DocumentationConsistency.ps1')
        (Join-Path $PSScriptRoot '../../Tools/New-ReleasePackage.ps1')
        (Join-Path $PSScriptRoot '../../Tools/New-InstallerPackage.ps1')
        (Join-Path $PSScriptRoot '../../Tools/New-IncidentReproductionPack.ps1')
        (Join-Path $PSScriptRoot '../../Tools/Invoke-LifecyclePlaybook.ps1')
        (Join-Path $PSScriptRoot '../../Tools/Get-EmbeddedRuntimeSurface.ps1')
        (Join-Path $PSScriptRoot '../../Tools/Generate-PresetFiles.ps1')
        (Join-Path $PSScriptRoot '../../Tools/Export-TestReport.ps1')
        (Join-Path $PSScriptRoot '../../Tests/README.md')
        (Join-Path $PSScriptRoot '../../Tests/Integration/README.md')
        (Join-Path $PSScriptRoot '../../Tests/Integration/IntegrationTest.ps1')
        (Join-Path $PSScriptRoot '../../Tests/Integration/Test-RegistryTweak.ps1')
    )

    $script:JsonCompatibilityFiles = @(
        (Join-Path $PSScriptRoot '../../Module/SharedHelpers/Preset.Helpers.ps1')
        (Join-Path $PSScriptRoot '../../Module/SharedHelpers/SupportBundle.Helpers.ps1')
        (Join-Path $PSScriptRoot '../../Module/Regions/ContextMenu.psm1')
    )
}

Describe 'PowerShell 5.1 support contract' {
    It 'marks the loader module as Windows PowerShell Desktop only' {
        $content = Get-Content -LiteralPath $script:ModuleManifestPath -Raw -Encoding UTF8

        $content | Should -Match "CompatiblePSEditions\s*=\s*@\('Desktop'\)"
        $content | Should -Match "PowerShellVersion\s*=\s*'5\.1'"
        $content | Should -Not -Match "CompatiblePSEditions\s*=\s*@\('Core'"
    }

    It 'keeps the shortcut launcher pinned to powershell.exe' {
        $content = Get-Content -LiteralPath $script:ShortcutLauncherPath -Raw -Encoding UTF8

        $content | Should -Match 'FindOnPath\("powershell\.exe"\)'
        $content | Should -Not -Match 'pwsh\.exe'
        $content | Should -Match 'Windows PowerShell 5\.1 \(powershell\.exe\) was not found\.'
    }

    It 'keeps runtime curation helpers from selecting PowerShell 7 as the Baseline host' {
        foreach ($path in $script:RuntimeContractFiles) {
            $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8

            $content | Should -Not -Match '\bpwsh(?:\.exe)?\b'
        }
    }

    It 'keeps maintainer examples on powershell.exe' {
        foreach ($path in $script:ExampleFiles) {
            $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8

            $content | Should -Not -Match '\bpwsh\b'
        }
    }

    It 'uses JSON helper calls instead of PowerShell major-version gates in runtime modules' {
        foreach ($path in $script:JsonCompatibilityFiles) {
            $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8

            $content | Should -Not -Match 'PSVersionTable\.PSVersion\.Major\s+-ge\s+6'
            $content | Should -Match 'ConvertFrom-BaselineJson\s+-Depth\s+\d+'
        }
    }
}
