Set-StrictMode -Version Latest

BeforeAll {
    $script:GuiPath = Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1'
    $script:ActionHandlersPath = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers.ps1'
    $script:StyleManagementPath = Join-Path $PSScriptRoot '../../Module/GUI/StyleManagement.ps1'
    $script:GuiContent = Get-Content -LiteralPath $script:GuiPath -Raw -Encoding UTF8
    $script:ActionHandlersContent = Get-Content -LiteralPath $script:ActionHandlersPath -Raw -Encoding UTF8
    $script:StyleManagementContent = Get-Content -LiteralPath $script:StyleManagementPath -Raw -Encoding UTF8
}

Describe 'Remote session status menu' {
    It 'exposes a remote session status entry in the Tools menu' {
        $script:GuiContent | Should -Match 'MenuToolsRemoteSessionStatus'
        $script:GuiContent | Should -Match 'Remote Session Status\.{3}'
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Get-BaselineRemoteSessionSummary'"
        $script:ActionHandlersContent | Should -Match 'Register-GuiEventHandler -Source \$MenuToolsRemoteSessionStatus -EventName ''Click'''
        $script:ActionHandlersContent | Should -Match 'Viewed remote session status'
    }

    It 'keeps the label and enabled state in sync with GUI styling' {
        $script:StyleManagementContent | Should -Match 'MenuToolsRemoteSessionStatus'
        $script:StyleManagementContent | Should -Match "GuiMenuToolsRemoteSessionStatus"
        $script:StyleManagementContent | Should -Match 'MenuToolsRemoteSessionStatus\.IsEnabled = \$Enabled'
    }
}
