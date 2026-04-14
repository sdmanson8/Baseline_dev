Set-StrictMode -Version Latest

BeforeAll {
    $script:GuiPath = Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1'
    $script:ActionHandlersPath = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers.ps1'
    $script:StyleManagementPath = Join-Path $PSScriptRoot '../../Module/GUI/StyleManagement.ps1'
    $script:SessionStatePath = Join-Path $PSScriptRoot '../../Module/GUI/SessionState.ps1'
    $script:DialogHelpersPath = Join-Path $PSScriptRoot '../../Module/GUI/DialogHelpers.ps1'
    $script:GuiContent = Get-Content -LiteralPath $script:GuiPath -Raw -Encoding UTF8
    $script:ActionHandlersContent = Get-Content -LiteralPath $script:ActionHandlersPath -Raw -Encoding UTF8
    $script:StyleManagementContent = Get-Content -LiteralPath $script:StyleManagementPath -Raw -Encoding UTF8
    $script:SessionStateContent = Get-Content -LiteralPath $script:SessionStatePath -Raw -Encoding UTF8
    $script:DialogHelpersContent = Get-Content -LiteralPath $script:DialogHelpersPath -Raw -Encoding UTF8
}

Describe 'Remote target approval menu' {
    It 'adds an explicit target approval action to the Tools menu and wires it through the GUI' {
        $script:GuiContent | Should -Match 'MenuToolsApproveRemoteTargets'
        $script:GuiContent | Should -Match 'Approve Target List\.{3}'
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Set-GuiRemoteTargetApprovalList'"
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Test-GuiRemoteTargetApproval'"
        $script:ActionHandlersContent | Should -Match 'Register-GuiEventHandler -Source \$MenuToolsApproveRemoteTargets -EventName ''Click'''
        $script:ActionHandlersContent | Should -Match 'Approve this exact target list for the current session'
    }

    It 'stores approved target lists in session state and clears them on disconnect' {
        $script:SessionStateContent | Should -Match 'ApprovedTargetComputers'
        $script:SessionStateContent | Should -Match 'ApprovedAt'
        $script:SessionStateContent | Should -Match 'ApprovalMessage'
        $script:SessionStateContent | Should -Match 'PinnedBaselineVersion'
        $script:SessionStateContent | Should -Match 'SchemaVersion = 15'
        $script:SessionStateContent | Should -Match 'function Test-GuiRemoteTargetApproval'
        $script:SessionStateContent | Should -Match 'function Set-GuiRemoteTargetApprovalList'
        $script:SessionStateContent | Should -Match 'function Clear-GuiRemoteTargetApprovalList'
        $script:SessionStateContent | Should -Match 'function Export-GuiRemoteTargetApprovalPolicy'
        $script:SessionStateContent | Should -Match 'function Import-GuiRemoteTargetApprovalPolicy'
        $script:SessionStateContent | Should -Match 'Clear-BaselineRemoteSessionCache'
    }

    It 'keeps the approval menu label and enabled state synced with styling' {
        $script:StyleManagementContent | Should -Match 'MenuToolsApproveRemoteTargets'
        $script:StyleManagementContent | Should -Match "GuiMenuToolsApproveRemoteTargets"
        $script:StyleManagementContent | Should -Match "New-GuiLabeledIconContent -IconName 'Shield'"
        $script:StyleManagementContent | Should -Match "New-GuiLabeledIconContent -IconName 'WindowConsole'"
        $script:StyleManagementContent | Should -Match "New-GuiLabeledIconContent -IconName 'WindowSettings'"
        $script:StyleManagementContent | Should -Match 'MenuToolsApproveRemoteTargets\.IsEnabled = \(\$Enabled'
        $script:StyleManagementContent | Should -Match 'MenuToolsSaveRemoteApprovalPolicy'
        $script:StyleManagementContent | Should -Match 'MenuToolsLoadRemoteApprovalPolicy'
        $script:StyleManagementContent | Should -Match 'MenuToolsRemoteConsole'
        $script:StyleManagementContent | Should -Match 'GuiMenuToolsRemoteConsole'
        $script:StyleManagementContent | Should -Match 'GuiMenuToolsSaveRemoteApprovalPolicy'
        $script:StyleManagementContent | Should -Match 'GuiMenuToolsLoadRemoteApprovalPolicy'
    }

    It 'adds a remote console dialog with orchestration controls' {
        $script:DialogHelpersContent | Should -Match 'function Show-GuiRemoteConsoleDialog'
        $script:DialogHelpersContent | Should -Match 'Remote Console'
        $script:DialogHelpersContent | Should -Match 'BtnConnect'
        $script:DialogHelpersContent | Should -Match 'BtnApprove'
        $script:DialogHelpersContent | Should -Match 'BtnSavePolicy'
        $script:DialogHelpersContent | Should -Match 'BtnLoadPolicy'
        $script:DialogHelpersContent | Should -Match 'BtnPreflight'
        $script:DialogHelpersContent | Should -Match 'Test-BaselineRemoteConnectivity'
        $script:DialogHelpersContent | Should -Match 'TxtRecentOrchestration'
        $script:DialogHelpersContent | Should -Match 'Get-BaselineRemoteOrchestrationSummary'
    }

    It 'adds a release status dialog and wires it through the Help menu' {
        $script:DialogHelpersContent | Should -Match 'function Show-GuiReleaseStatusDialog'
        $script:DialogHelpersContent | Should -Match 'Release Status'
        $script:DialogHelpersContent | Should -Match 'Pinned version:'
        $script:DialogHelpersContent | Should -Match 'Pin Current Version'
        $script:DialogHelpersContent | Should -Match 'Clear Pin'
        $script:DialogHelpersContent | Should -Match 'Icon system:'
        $script:DialogHelpersContent | Should -Match 'Validation matrix:'
        $script:GuiContent | Should -Match 'MenuHelpReleaseStatus'
        $script:GuiContent | Should -Match 'Release Status\.{3}'
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Show-GuiReleaseStatusDialog'"
        $script:ActionHandlersContent | Should -Match 'Register-GuiEventHandler -Source \$MenuHelpReleaseStatus -EventName ''Click'''
        $script:ActionHandlersContent | Should -Match 'GuiMenuHelpReleaseStatus'
        $script:StyleManagementContent | Should -Match 'MenuHelpReleaseStatus'
        $script:StyleManagementContent | Should -Match 'GuiMenuHelpReleaseStatus'
    }

    It 'adds a troubleshooting guide dialog and wires it through the Help menu' {
        $script:DialogHelpersContent | Should -Match 'function Show-GuiTroubleshootingGuideDialog'
        $script:DialogHelpersContent | Should -Match 'Troubleshooting Guide'
        $script:DialogHelpersContent | Should -Match 'GUI-STARTUP-004'
        $script:DialogHelpersContent | Should -Match 'Export Support Bundle'
        $script:DialogHelpersContent | Should -Match 'BtnExportBundle'
        $script:GuiContent | Should -Match 'MenuHelpTroubleshooting'
        $script:GuiContent | Should -Match 'Troubleshooting Guide\.{3}'
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Show-GuiTroubleshootingGuideDialog'"
        $script:ActionHandlersContent | Should -Match 'Register-GuiEventHandler -Source \$MenuHelpTroubleshooting -EventName ''Click'''
        $script:ActionHandlersContent | Should -Match 'GuiMenuHelpTroubleshooting'
        $script:StyleManagementContent | Should -Match 'MenuHelpTroubleshooting'
        $script:StyleManagementContent | Should -Match 'GuiMenuHelpTroubleshooting'
    }
}
