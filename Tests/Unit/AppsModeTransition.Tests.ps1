Set-StrictMode -Version Latest

BeforeAll {
    $script:MainWindowXamlPath = Join-Path $PSScriptRoot '../../Module/GUI/MainWindow.xaml'
    $script:WindowSetupPath = Join-Path $PSScriptRoot '../../Module/GUI/WindowSetup.ps1'
    $script:ProgressNavChromePath = Join-Path $PSScriptRoot '../../Module/GUI/AppsModule/ProgressNavChrome.ps1'
    $script:MainWindowXamlContent = Get-Content -LiteralPath $script:MainWindowXamlPath -Raw -Encoding UTF8
    $script:WindowSetupContent = Get-Content -LiteralPath $script:WindowSetupPath -Raw -Encoding UTF8
    $script:ProgressNavChromeContent = Get-Content -LiteralPath $script:ProgressNavChromePath -Raw -Encoding UTF8
}

Describe 'Apps progress strip' {
    It 'does not declare the removed Apps progress strip in the UI' {
        $script:MainWindowXamlContent | Should -Not -Match 'Name="AppsProgressContainer"'
    }

    It 'does not wire the removed strip into window setup or Apps mode' {
        $script:WindowSetupContent | Should -Not -Match 'AppsProgressContainer'
        $script:ProgressNavChromeContent | Should -Not -Match 'Initialize-AppsProgressSection'
    }

    It 'keeps the Apps page status text without a dedicated strip container' {
        $script:ProgressNavChromeContent | Should -Match '\$Script:TxtAppsProgressText\.Text = \(Get-AppsCacheRefreshPromptText\)'
        $script:ProgressNavChromeContent | Should -Not -Match 'TxtAppCacheStatus'
    }
}
