Set-StrictMode -Version Latest

BeforeAll {
    $script:DialogHelpersPath = Join-Path $PSScriptRoot '../../Module/GUI/DialogHelpers.ps1'
    $script:ActionHandlersPath = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers.ps1'
    $script:DialogHelpersContent = Get-Content -LiteralPath $script:DialogHelpersPath -Raw -Encoding UTF8
    $script:ActionHandlersContent = Get-Content -LiteralPath $script:ActionHandlersPath -Raw -Encoding UTF8
}

Describe 'Documentation viewer wiring' {
    It 'defines dedicated themed changelog and README viewers with installed-path resolvers' {
        $script:DialogHelpersContent | Should -Match 'function Resolve-BaselineChangelogPath'
        $script:DialogHelpersContent | Should -Match 'function Resolve-BaselineReadmePath'
        $script:DialogHelpersContent | Should -Match 'BASELINE_LAUNCHER_PATH'
        $script:DialogHelpersContent | Should -Match '\[System\.AppContext\]::BaseDirectory'
        $script:DialogHelpersContent | Should -Match 'function Show-ChangelogDialog'
        $script:DialogHelpersContent | Should -Match 'function Show-ReadmeDialog'
        $script:DialogHelpersContent | Should -Match 'TxtChangelogContent'
        $script:DialogHelpersContent | Should -Match 'TxtReadmeContent'
        $script:DialogHelpersContent | Should -Match 'ReadAllText'
    }

    It 'routes the Help menu changelog and documentation actions through themed dialogs instead of launching external apps' {
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Show-ChangelogDialog'"
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Show-ReadmeDialog'"
        $script:ActionHandlersContent | Should -Match '& \$showChangelogDialogCommand'
        $script:ActionHandlersContent | Should -Match '& \$showReadmeDialogCommand'
        $script:ActionHandlersContent | Should -Not -Match 'Start-Process -FilePath \$docsUrl'
    }

    It 'reapplies the README viewer theme through the shared popup theme registry' {
        $script:DialogHelpersContent | Should -Match 'Register-GuiPopupThemeWindow -Window \$dlg -ThemeCallback \$readmeThemeCallback'
        $script:DialogHelpersContent | Should -Match '\$readmeThemeCallback = \{'
        $script:DialogHelpersContent | Should -Match '& \$loadReadmeContent -ThemeOverride \$Theme'
        $script:DialogHelpersContent | Should -Match 'ReadmeHeaderBorder'
        $script:DialogHelpersContent | Should -Match 'ReadmeContentBorder'
        $script:DialogHelpersContent | Should -Match 'ReadmeFooterBorder'
    }
}
