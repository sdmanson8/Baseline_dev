Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Tools/New-InstallerPackage.ps1'
    $script:RepoRoot = Split-Path -Path (Split-Path -Path $filePath -Parent) -Parent
    $script:OriginalBaselineLanguage = [System.Environment]::GetEnvironmentVariable('BASELINE_LANGUAGE', 'Process')

    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $functions) {
        Invoke-Expression $fn.Extent.Text
    }
}

AfterAll {
    [System.Environment]::SetEnvironmentVariable('BASELINE_LANGUAGE', $script:OriginalBaselineLanguage, 'Process')
}

Describe 'Get-InstallerLocalizationSource' {
    BeforeEach {
        $script:LocalizationRoot = Join-Path $TestDrive 'Localizations'
        $englishDir = Join-Path $script:LocalizationRoot 'English (United States)'
        $frenchDir = Join-Path $script:LocalizationRoot 'French'

        New-Item -ItemType Directory -Path $englishDir -Force | Out-Null
        New-Item -ItemType Directory -Path $frenchDir -Force | Out-Null

        Set-Content -LiteralPath (Join-Path $englishDir 'en-US.json') -Encoding UTF8 -Value @'
{
  "Installer_LangPage_Title": "Choose Language",
  "Installer_LangPage_Desc": "Choose the display language for Baseline."
}
'@

        Set-Content -LiteralPath (Join-Path $frenchDir 'fr.json') -Encoding UTF8 -Value @'
{
  "Installer_LangPage_Title": "Choisir la langue"
}
'@
    }

    It 'uses explicit locale translations and leaves missing non-English strings blank' {
        $result = Get-InstallerLocalizationSource -UICulture 'fr-FR' -RepoRoot $script:RepoRoot -LocalizationRoot $script:LocalizationRoot

        $result['LangPage.Title'] | Should -Be 'Choisir la langue'
        $result['LangPage.Desc'] | Should -Be ''
        $result['Btn.Next'] | Should -Be ''
    }

    It 'keeps english fallback strings for english cultures' {
        $result = Get-InstallerLocalizationSource -UICulture 'en-US' -RepoRoot $script:RepoRoot -LocalizationRoot $script:LocalizationRoot

        $result['LangPage.Title'] | Should -Be 'Choose Language'
        $result['LangPage.Desc'] | Should -Be 'Choose the display language for Baseline.'
        $result['Btn.Next'] | Should -Be 'Next >'
    }
}

Describe 'Initialize-InstallerLocalizationWorkspace' {
    BeforeEach {
        $script:LocalizationRoot = Join-Path $TestDrive 'Localizations'
        $englishDir = Join-Path $script:LocalizationRoot 'English (United States)'
        $frenchDir = Join-Path $script:LocalizationRoot 'French'

        New-Item -ItemType Directory -Path $englishDir -Force | Out-Null
        New-Item -ItemType Directory -Path $frenchDir -Force | Out-Null

        Set-Content -LiteralPath (Join-Path $frenchDir 'fr.json') -Encoding UTF8 -Value @'
{
  "Installer_LangPage_Title": "Choisir la langue",
  "Installer_Btn_Next": "Suivant >"
}
'@
    }

    It 'writes locale-specific installer files instead of copying english to every locale' {
        $workspaceRoot = Join-Path $TestDrive 'installer-workspace'
        $sourceMap = Get-InstallerLocalizationSource -UICulture 'en-US' -RepoRoot $script:RepoRoot -LocalizationRoot $script:LocalizationRoot

        Initialize-InstallerLocalizationWorkspace `
            -Root $workspaceRoot `
            -SourceMap $sourceMap `
            -LocaleCodes @('en', 'fr', 'de') `
            -RepoRoot $script:RepoRoot `
            -LocalizationRoot $script:LocalizationRoot | Out-Null

        $englishJson = Get-Content -LiteralPath (Join-Path $workspaceRoot 'en.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $frenchJson = Get-Content -LiteralPath (Join-Path $workspaceRoot 'fr.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $germanJson = Get-Content -LiteralPath (Join-Path $workspaceRoot 'de.json') -Raw -Encoding UTF8 | ConvertFrom-Json

        $englishJson.'LangPage.Title' | Should -Be 'Choose Language'
        $frenchJson.'LangPage.Title' | Should -Be 'Choisir la langue'
        $frenchJson.'Btn.Next' | Should -Be 'Suivant >'
        $frenchJson.'LangPage.Desc' | Should -Be ''
        $germanJson.'LangPage.Title' | Should -Be ''
        $germanJson.'Btn.Next' | Should -Be ''
    }
}
