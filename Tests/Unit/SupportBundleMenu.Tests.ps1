Set-StrictMode -Version Latest

BeforeAll {
    $script:GuiPath = Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1'
    $script:MainWindowPath = Join-Path $PSScriptRoot '../../Module/GUI/MainWindow.xaml'
    $script:ActionHandlersPath = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers.ps1'
    $script:StyleManagementPath = Join-Path $PSScriptRoot '../../Module/GUI/StyleManagement.ps1'
    $script:GuiContent = (Get-Content -LiteralPath $script:GuiPath -Raw -Encoding UTF8) + "`n" + (Get-Content -LiteralPath $script:MainWindowPath -Raw -Encoding UTF8)
    $script:ActionHandlersContent = Get-Content -LiteralPath $script:ActionHandlersPath -Raw -Encoding UTF8
    $script:StyleManagementContent = Get-Content -LiteralPath $script:StyleManagementPath -Raw -Encoding UTF8
}

Describe 'Support bundle GUI wiring' {
    It 'exposes support bundle export in the menu and wires it through the action handlers' {
        $script:GuiContent | Should -Match 'MenuToolsExportSupportBundle'
        $script:GuiContent | Should -Match 'Export Support Bundle\.\.\.'
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Export-BaselineSupportBundle'"
        $script:ActionHandlersContent | Should -Match 'Register-GuiEventHandler -Source \$MenuToolsExportSupportBundle -EventName ''Click'''
        $script:ActionHandlersContent | Should -Match 'Export Support Bundle'
    }

    It 'keeps the support bundle label and enabled state in sync with the GUI theme and action state' {
        $script:StyleManagementContent | Should -Match 'MenuToolsExportSupportBundle'
        $script:StyleManagementContent | Should -Match "GuiMenuToolsExportSupportBundle"
        $script:StyleManagementContent | Should -Match 'Set-GuiActionButtonsEnabled'
        $script:StyleManagementContent | Should -Match 'MenuToolsExportSupportBundle\.IsEnabled = \$Enabled'
    }
}
