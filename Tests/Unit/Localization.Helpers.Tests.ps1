Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Module/SharedHelpers/Localization.Helpers.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

    foreach ($fn in $functions) {
        if ($fn.Name -in @('Resolve-BaselineLocalizationDirectory', 'Get-BaselineLocalizedString', 'Get-BaselineBilingualString')) {
            Invoke-Expression $fn.Extent.Text
        }
    }

    $script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    $script:ExpectedLocalizationPath = Join-Path $script:RepoRoot 'Localizations'
}

Describe 'Resolve-BaselineLocalizationDirectory' {
    It 'finds the localization directory from the repository root' {
        Resolve-BaselineLocalizationDirectory -BasePath $script:RepoRoot | Should -Be $script:ExpectedLocalizationPath
    }

    It 'finds the localization directory from the module root' {
        $moduleRoot = Join-Path $script:RepoRoot 'Module'

        Resolve-BaselineLocalizationDirectory -BasePath $moduleRoot | Should -Be $script:ExpectedLocalizationPath
    }

    It 'finds the localization directory from the GUI region root' {
        $moduleRoot = Join-Path $script:RepoRoot 'Module/Regions'

        Resolve-BaselineLocalizationDirectory -BasePath $moduleRoot | Should -Be $script:ExpectedLocalizationPath
    }

    It 'finds the localization directory from the extracted GUI script root' {
        $moduleRoot = Join-Path $script:RepoRoot 'Module/GUI'

        Resolve-BaselineLocalizationDirectory -BasePath $moduleRoot | Should -Be $script:ExpectedLocalizationPath
    }

    It 'allows empty fallback strings in the localization helpers' {
        $result = Get-BaselineLocalizedString -Key 'Missing_Key' -Fallback ''
        $bilingual = Get-BaselineBilingualString -Key 'Missing_Key' -Fallback ''

        $result | Should -Be ''
        $bilingual | Should -Be ''
    }
}
