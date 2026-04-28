Set-StrictMode -Version Latest

BeforeAll {
    . (Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1')

    $stylePath = Join-Path $PSScriptRoot '../../Module/GUI/StyleManagement.ps1'
    $actionPath = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers.ps1'
    $actionSplitRoot = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers'
    $executionPath = Join-Path $PSScriptRoot '../../Module/GUI/ExecutionOrchestration.ps1'
    $executionSplitRoot = Join-Path $PSScriptRoot '../../Module/GUI/ExecutionOrchestration'

    $script:StyleContent = Get-Content -LiteralPath $stylePath -Raw -Encoding UTF8
    $script:ActionContent = Get-BaselineTestSourceText -Path @(
        $actionPath
        (Join-Path $actionSplitRoot 'ThemeNavigationHandlers.ps1')
        (Join-Path $actionSplitRoot 'ButtonHandlers.ps1')
        (Join-Path $actionSplitRoot 'SystemScanFooterHandlers.ps1')
        (Join-Path $actionSplitRoot 'MenuHandlers.ps1')
    )
    $script:ExecutionContent = Get-BaselineTestSourceText -Path @(
        $executionPath
        (Join-Path $executionSplitRoot 'ExecutionStateSummary.ps1')
        (Join-Path $executionSplitRoot 'ExecutionView.ps1')
        (Join-Path $executionSplitRoot 'ExecutionRunOrchestration.ps1')
    )
}

Describe 'Action button icon content' {
    It 'keeps localized toolbar and footer buttons on the shared icon pipeline' {
        $script:StyleContent | Should -Match 'Set-GuiButtonIconContent -Button \$Script:BtnDefaults -IconName ''RestoreDefaults'''
        $script:StyleContent | Should -Match 'Set-GuiButtonIconContent -Button \$BtnLog -IconName ''OpenLog'''
        $script:StyleContent | Should -Match 'Set-GuiButtonIconContent -Button \$BtnLanguage -IconName ''Language'''
        $script:StyleContent | Should -Match 'Set-GuiButtonIconContent -Button \$Script:BtnClearSearch -IconName ''Clear'''
        $script:StyleContent | Should -Match 'Set-GuiButtonIconContent -Button \$Script:BtnScanInstalledApps -IconName ''Search'''
    }

    It 'preserves Preview Run and Run Tweaks icons during UX text refreshes' {
        $script:ActionContent | Should -Match 'Set-GuiButtonIconContent -Button \$Script:BtnRun -IconName ''RunTweaks'''
        $script:ActionContent | Should -Match 'Set-GuiButtonIconContent -Button \$Script:BtnPreviewRun -IconName ''PreviewRun'''
        $script:ActionContent | Should -Match 'Set-GuiButtonIconContent -Button \$Script:BtnStartHere -IconName ''QuickStart'''
        $script:ActionContent | Should -Match 'Set-GuiButtonIconContent -Button \$Script:BtnHelp -IconName ''Help'''
    }

    It 'drops the old Apps refresh label from the main run button' {
        $script:ActionContent | Should -Not -Match 'GuiRefreshButton'
        $script:ActionContent | Should -Not -Match 'Tooltip_RefreshInstallationStatus'
    }

    It 'routes ActionHandlers UI cleanup swallows through Write-DebugSwallowedException' {
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.UpdateRunPathContextLabel\.Foreground'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.ExportSupportBundle\.RemoveSessionStatePath'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.MenuFileExit\.CloseMainForm'''
    }

    It 'routes ActionHandlers help menu logger failures through Write-DebugSwallowedException' {
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.MenuClickRouting\.LogWarning'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.MenuHelpGettingStarted\.LogWarning'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.MenuHelpReadme\.LogWarning'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.MenuHelpReadme\.ShowThemedDialog'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.MenuHelpFAQ\.LogWarning'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.MenuHelpChangelog\.LogWarning'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.MenuHelpUpdateCheck\.LogWarning'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.MenuHelpReleaseStatus\.LogWarning'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.MenuHelpTroubleshooting\.LogWarning'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.MenuHelpAbout\.ShowThemedDialog'''
    }

    It 'routes ActionHandlers help/about text fallbacks through Write-DebugSwallowedException' {
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.ExportConfigProfile\.GetDisplayVersion'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.ImportConfigProfile\.GetDisplayVersion'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.MenuHelpStartGuide\.GetQuickStartSteps'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.MenuHelpStartGuide\.GetOnboardingMode'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.MenuHelpStartGuide\.GetHelpLines'''
        $script:ActionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.MenuHelpAbout\.GetDisplayVersion'''
    }

    It 'restores normal action labels through Sync-UxActionButtonText after execution view resets' {
        $script:ExecutionContent | Should -Match "Get-Command -Name 'Sync-UxActionButtonText' -CommandType Function -ErrorAction SilentlyContinue"
        $script:ExecutionContent | Should -Match 'Sync-UxActionButtonText'
    }
}
