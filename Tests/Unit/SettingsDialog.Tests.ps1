Set-StrictMode -Version Latest

BeforeAll {
    . (Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1')

    $script:DialogHelpersPath = Join-Path $PSScriptRoot '../../Module/GUI/DialogHelpers.ps1'
    $script:DialogHelpersSplitRoot = Join-Path $PSScriptRoot '../../Module/GUI/DialogHelpers'
    $script:MenuHandlersPath = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers/MenuHandlers.ps1'
    $script:ActionHandlersSplitRoot = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers'

    $script:DialogHelpersContent = Get-BaselineTestSourceText -Path @(
        $script:DialogHelpersPath
        (Join-Path $script:DialogHelpersSplitRoot 'DialogThemeHelpers.ps1')
        (Join-Path $script:DialogHelpersSplitRoot 'SettingsDialogs.ps1')
        (Join-Path $script:DialogHelpersSplitRoot 'RemoteDialogs.ps1')
        (Join-Path $script:DialogHelpersSplitRoot 'ContentDialogs.ps1')
        (Join-Path $script:DialogHelpersSplitRoot 'AuditOperatorDialogs.ps1')
    )

    $script:MenuHandlersContent = Get-BaselineTestSourceText -Path @(
        $script:MenuHandlersPath
        (Join-Path $script:ActionHandlersSplitRoot 'ThemeNavigationHandlers.ps1')
        (Join-Path $script:ActionHandlersSplitRoot 'ButtonHandlers.ps1')
        (Join-Path $script:ActionHandlersSplitRoot 'SystemScanFooterHandlers.ps1')
        (Join-Path $script:ActionHandlersSplitRoot 'MenuHandlers.ps1')
    )
}

Describe 'Settings dialog wiring' {
    It 'restores the tabbed settings dialog and searchable language picker' {
        $script:DialogHelpersContent | Should -Match 'function Show-GuiSettingsDialog'
        $script:DialogHelpersContent | Should -Match 'TabControl Name="SettingsTabs"'
        $script:DialogHelpersContent | Should -Match 'Name="BtnSettingsLanguage"'
        $script:DialogHelpersContent | Should -Match 'Name="SettingsLanguagePopup"'
        $script:DialogHelpersContent | Should -Match 'Name="SettingsLanguageListPanel"'
        $script:DialogHelpersContent | Should -Match 'Name="ChkDesignMode"'
        $script:DialogHelpersContent | Should -Match '\$settingsLanguageState\.Code = ''en-US'''
        $script:DialogHelpersContent | Should -Match '\$nativeBlock\.Text = \[string\]\$entry\.NativeName'
        $script:DialogHelpersContent | Should -Match '\$engBlock\.Text = \[string\]\$entry\.EnglishName'
        $script:DialogHelpersContent | Should -Match '\$langBtn\.Template = \$langTemplate'
        $script:DialogHelpersContent | Should -Not -Match 'Name="CmbLanguage"'
    }

    It 'threads design mode through the settings save handler' {
        $script:MenuHandlersContent | Should -Match "DesignMode = if \(Get-Command -Name 'Get-BaselineUserPreference'"
        $script:MenuHandlersContent | Should -Match 'if \(\$result.ContainsKey\(''DesignMode''\)\)'
        $script:MenuHandlersContent | Should -Match 'Set-DesignModeState -Enabled \$desiredDesignMode'
    }
}
