Set-StrictMode -Version Latest

BeforeAll {
    . (Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1')

    $guiPath = Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1'
    $appsModulePath = Join-Path $PSScriptRoot '../../Module/GUI/AppsModule.ps1'
    $appsModuleSplitRoot = Join-Path $PSScriptRoot '../../Module/GUI/AppsModule'
    $showTweakGuiSplitRoot = Join-Path $PSScriptRoot '../../Module/GUI/Show-TweakGUI'
    $buildPrimaryTabsPath = Join-Path $PSScriptRoot '../../Module/GUI/BuildPrimaryTabs.ps1'
    $buildTabContentPath = Join-Path $PSScriptRoot '../../Module/GUI/BuildTabContent.ps1'
    $buildTweakControlsPath = Join-Path $PSScriptRoot '../../Module/GUI/BuildTweakControls.ps1'
    $applyThemePath = Join-Path $PSScriptRoot '../../Module/GUI/ApplyTheme.ps1'
    $contentManagementPath = Join-Path $PSScriptRoot '../../Module/GUI/ContentManagement.ps1'
    $styledControlsSetupPath = Join-Path $PSScriptRoot '../../Module/GUI/StyledControlsSetup.ps1'
    $dialogHelpersPath = Join-Path $PSScriptRoot '../../Module/GUI/DialogHelpers.ps1'
    $mainWindowPath = Join-Path $PSScriptRoot '../../Module/GUI/MainWindow.xaml'
    $stylePath = Join-Path $PSScriptRoot '../../Module/GUI/StyleManagement.ps1'
    $applicationsViewPath = Join-Path $PSScriptRoot '../../Module/GUI/ApplicationsView.ps1'
    $deploymentMediaBuilderViewPath = Join-Path $PSScriptRoot '../../Module/GUI/DeploymentMediaBuilderView.ps1'
    $presetUiPath = Join-Path $PSScriptRoot '../../Module/GUI/PresetUI.ps1'
    $actionHandlersPath = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers.ps1'
    $actionHandlersSplitRoot = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers'
    $stateTransitionPath = Join-Path $PSScriptRoot '../../Module/GUI/StateTransitions.ps1'
    $sessionStatePath = Join-Path $PSScriptRoot '../../Module/GUI/SessionState.ps1'
    $gameModePath = Join-Path $PSScriptRoot '../../Module/GUI/GameModeUI.ps1'
    $updatesPanelPath = Join-Path $PSScriptRoot '../../Module/GUI/UpdatesPanel.ps1'
    $searchFilterHandlersPath = Join-Path $PSScriptRoot '../../Module/GUI/SearchFilterHandlers.ps1'

    $script:GuiContent = @(
        Get-BaselineTestSourceText -Path $mainWindowPath
        Get-BaselineTestSourceText -Path $guiPath
        Get-BaselineTestSourceText -Path $deploymentMediaBuilderViewPath
        Get-BaselineTestSourceText -Path @(
            (Join-Path $showTweakGuiSplitRoot 'ContentRenderedStartupCompletion.ps1')
            (Join-Path $showTweakGuiSplitRoot 'FirstRunAndSplashHandoff.ps1')
            (Join-Path $showTweakGuiSplitRoot 'ShowDialogErrorHandling.ps1')
        )
        Get-BaselineTestSourceText -Path @(
            $appsModulePath
            (Join-Path $appsModuleSplitRoot 'CatalogHelpers.ps1')
            (Join-Path $appsModuleSplitRoot 'SelectionQueueState.ps1')
            (Join-Path $appsModuleSplitRoot 'ProgressNavChrome.ps1')
        )
        Get-BaselineTestSourceText -Path $buildPrimaryTabsPath
        Get-BaselineTestSourceText -Path $buildTabContentPath
        Get-BaselineTestSourceText -Path $buildTweakControlsPath
        Get-BaselineTestSourceText -Path $applyThemePath
        Get-BaselineTestSourceText -Path $updatesPanelPath
        Get-BaselineTestSourceText -Path $searchFilterHandlersPath
    ) -join "`n"
    $script:MainWindowContent = Get-BaselineTestSourceText -Path $mainWindowPath
    $script:BuildPrimaryTabsContent = Get-BaselineTestSourceText -Path $buildPrimaryTabsPath
    $script:BuildTabContentContent = Get-BaselineTestSourceText -Path $buildTabContentPath
    $script:StyleContent = Get-BaselineTestSourceText -Path $stylePath
    $script:ApplicationsViewContent = Get-BaselineTestSourceText -Path $applicationsViewPath
    $script:DeploymentMediaBuilderViewContent = Get-BaselineTestSourceText -Path $deploymentMediaBuilderViewPath
    $script:ContentManagementContent = Get-BaselineTestSourceText -Path $contentManagementPath
    $script:StyledControlsSetupContent = Get-BaselineTestSourceText -Path $styledControlsSetupPath
    $script:DialogHelpersContent = Get-BaselineTestSourceText -Path $dialogHelpersPath
    $script:PresetUiContent = Get-BaselineTestSourceText -Path $presetUiPath
    $script:ActionHandlersContent = Get-BaselineTestSourceText -Path @(
        $actionHandlersPath
        (Join-Path $actionHandlersSplitRoot 'ThemeNavigationHandlers.ps1')
        (Join-Path $actionHandlersSplitRoot 'ButtonHandlers.ps1')
        (Join-Path $actionHandlersSplitRoot 'SystemScanFooterHandlers.ps1')
        (Join-Path $actionHandlersSplitRoot 'MenuHandlers.ps1')
    )
    $script:StateTransitionContent = Get-BaselineTestSourceText -Path $stateTransitionPath
    $script:SessionStateContent = Get-BaselineTestSourceText -Path $sessionStatePath
    $script:GameModeContent = Get-BaselineTestSourceText -Path $gameModePath
    $script:UpdatesPanelContent = Get-BaselineTestSourceText -Path $updatesPanelPath
}

Describe 'Focused GUI rebuilds' {
    It 'keeps idle tab prebuild available but makes it opt-in per rebuild' {
        $script:GuiContent | Should -Match 'function Build-TabContent'
        $script:GuiContent | Should -Match '\[switch\]\$SkipIdlePrebuild'
        $script:GuiContent | Should -Match 'if \(-not \$SkipIdlePrebuild -and \$PrimaryTabs -and \$PrimaryTabs\.Dispatcher\)'
        $script:GuiContent | Should -Match '\[System\.Windows\.Threading\.DispatcherPriority\]::ApplicationIdle'
    }

    It 'keeps the splash until startup tab content is hydrated' {
        $script:GuiContent | Should -Match '# Signal GuiReady NOW'
        $script:GuiContent | Should -Match 'Set-BootstrapLoadingSplashStep'' -CommandType Function'
        $script:GuiContent | Should -Match "-StepId 'finalize' -Status 'completed'"
        $script:GuiContent | Should -Match '\$Splash\.GuiReady = \$true'
        $script:GuiContent | Should -Match '\$null = Invoke-GuiDispatcherAction -Dispatcher \$PrimaryTabs\.Dispatcher -PriorityUsage ''Immediate'' -Action \{'
        $script:GuiContent | Should -Match '\$PrimaryTabs\.Dispatcher\.BeginInvoke\(\s*\[System\.Action\]\$initialTabBuildAction,\s*\[System\.Windows\.Threading\.DispatcherPriority\]::Background'
        $script:GuiContent | Should -Match 'if \(-not \$startupRestoreSessionPending\)'
        $script:BuildPrimaryTabsContent | Should -Not -Match '\$Global:LoadingSplash\.GuiReady = \$true'
        $script:BuildPrimaryTabsContent | Should -Not -Match '\$Script:MainForm\.Visibility = \[System\.Windows\.Visibility\]::Visible'
        $script:BuildTabContentContent | Should -Match 'Test-GuiStartupSplashAbortRequested -Splash \$Splash'
        $script:BuildTabContentContent | Should -Match 'BuildTabContent aborted before GuiReady because startup splash was closed'
        $script:GuiContent | Should -Match '\$startGuiPerfScopeScript = Get-GuiFunctionCapture -Name ''Start-GuiPerfScope'''
        $script:GuiContent | Should -Match '\$stopGuiPerfScopeScript = Get-GuiFunctionCapture -Name ''Stop-GuiPerfScope'''
    }

    It 'releases the splash when cached startup tab content short-circuits the build' {
        $script:BuildTabContentContent | Should -Match '(?s)if \(Restore-CachedTabContent -PrimaryTab \$PrimaryTab\)\s*\{\s*Invoke-GuiStartupReadySignal'
    }

    It 'releases the splash when restored top navigation modes are already active' {
        $script:GuiContent | Should -Match 'if \(\$Script:AppsModeActive -or \$Script:DeploymentMediaModeActive\)'
        $script:GuiContent | Should -Match 'Test-GuiStartupSplashLive -Splash \$startupSplash'
        $script:GuiContent | Should -Match "Get-Command -Name 'Invoke-GuiStartupReadySignal'"
        $script:GuiContent | Should -Match '& \$startupReadySignalScript'
    }

    It 'initializes perf tracing before the dialog helpers load' {
        $script:DialogHelpersContent | Should -Match '\. \(Join-Path \$Script:DialogHelpersRoot ''PerfTrace\.ps1''\)'
        $script:DialogHelpersContent | Should -Match 'Initialize-GuiPerfTrace'
    }

    It 'loads the durable user preference store before settings-dependent GUI modules' {
        $script:GuiContent | Should -Match '(?s)\. \(Join-Path \$Script:GuiExtractedRoot ''UxPolicy\.ps1''\)\s*\. \(Join-Path \$Script:GuiExtractedRoot ''UserPreferences\.ps1''\)\s*\. \(Join-Path \$Script:GuiExtractedRoot ''UIDensity\.ps1''\)\s*\. \(Join-Path \$Script:GuiExtractedRoot ''SessionState\.ps1''\)'
    }

    It 'threads the focused rebuild flag through the current-tab refresh path' {
        $script:GuiContent | Should -Match 'function Update-CurrentTabContent'
        $script:GuiContent | Should -Match '& \$buildTabContentScript -PrimaryTab \$targetTab -SkipIdlePrebuild:\$SkipIdlePrebuild'
        $script:GuiContent | Should -Match '\$skipIdlePrebuild = \[bool\]\$Script:SkipIdlePrebuildOnNextPrimaryTabSelection'
        $script:GuiContent | Should -Match '& \$updateCurrentTabContentScript -SkipIdlePrebuild:\$skipIdlePrebuild'
    }

    It 'invokes page reset through a captured script-scope handler for WPF events' {
        $script:ActionHandlersContent | Should -Match '\$Script:InvokePageResetToDefaultsScript = \{'
        $script:ActionHandlersContent | Should -Match '& \$Script:InvokePageResetToDefaultsScript -Category \$Category'
        $script:PresetUiContent | Should -Match '\$invokePageResetToDefaultsCapture = if \(\$Script:InvokePageResetToDefaultsScript\)'
        $script:PresetUiContent | Should -Match '& \$invokePageResetToDefaultsCapture -Category \$pageCategory'
        $script:PresetUiContent | Should -Not -Match 'Invoke-PageResetToDefaults -Category \$pageCategory'
    }

    It 'keeps the Safe UX Quick Start preset scoped to Initial Setup' {
        $script:PresetUiContent | Should -Match 'function Test-ShouldShowQuickStartPresetButton'
        $script:PresetUiContent | Should -Match 'return \[string\]::Equals\(\$normalizedPrimaryTab, ''Initial Setup'''
        $script:PresetUiContent | Should -Match 'Get-TabPresetButtonDefinitions -IsSafeUx:\(Test-IsSafeModeUX\) -PrimaryTab \(\[string\]\$BuildContext\.PrimaryTab\)'
        $script:PresetUiContent | Should -Match 'if \(Test-ShouldShowQuickStartPresetButton -PrimaryTab \$PrimaryTab\)'
    }

    It 'uses focused rebuilds for theme and shared mode transitions' {
        $script:GuiContent | Should -Match 'Build-TabContent -PrimaryTab \$Script:CurrentPrimaryTab -SkipIdlePrebuild'
        $script:StateTransitionContent | Should -Match '& \$Script:UpdateCurrentTabContentScript -SkipIdlePrebuild'
    }

    It 'skips duplicate content rebuild during initial startup theme application' {
        $script:GuiContent | Should -Match 'Apply-BaselineThemePreference -Preference \$initialThemePreference -SkipContentRebuild'
        $script:GuiContent | Should -Match 'param \(\s*\[hashtable\]\$Theme,\s*\[switch\]\$SkipContentRebuild\s*\)'
        $script:GuiContent | Should -Match 'if \(-not \$SkipContentRebuild\)\s*\{\s*# Rebuild content for current tab to pick up new theme colors\.'
    }

    It 'hydrates the restored startup tab before the GUI is revealed' {
        $script:SessionStateContent | Should -Match '\$refreshCurrentTabContentScript = \$\{function:Update-CurrentTabContent\}'
        $script:SessionStateContent | Should -Match '\$startGuiPerfScopeScript = Get-GuiFunctionCapture -Name ''Start-GuiPerfScope'''
        $script:SessionStateContent | Should -Match '\$stopGuiPerfScopeScript = Get-GuiFunctionCapture -Name ''Stop-GuiPerfScope'''
        $script:SessionStateContent | Should -Match '\$__perf = if \(\$startGuiPerfScopeScript\) \{ & \$startGuiPerfScopeScript -Name ''RestoreGuiSessionState\.TabHydrate'' \} else \{ \$null \}'
        $script:SessionStateContent | Should -Match '& \$refreshCurrentTabContentScript -SkipIdlePrebuild'
        $script:SessionStateContent | Should -Match '\$Script:StartupRestoreSessionPending = \$false'
        $script:SessionStateContent | Should -Not -Match '\$Script:MainForm\.Dispatcher\.BeginInvoke\(\s*\[System\.Action\]\$refreshCurrentTabContentAction'
    }

    It 'keeps restored inline search results as the active refresh target' {
        $script:GuiContent | Should -Match '\$activeSearchQuery = if \(\$null -eq \$Script:SearchText\)'
        $script:GuiContent | Should -Match '\$activeSearchQuery = \$activeSearchQuery\.Trim\(\)'
        $script:GuiContent | Should -Match 'if \(-not \[string\]::IsNullOrWhiteSpace\(\$activeSearchQuery\)\)'
        $script:GuiContent | Should -Match '\$targetTab = \$Script:SearchResultsTabTag'
    }

    It 'clears inline search results back to the selected tweak tab immediately' {
        $script:GuiContent | Should -Match '\$Script:SearchText\s*=\s*'''''
        $script:GuiContent | Should -Match '\$Script:SearchRefreshTimer\.Stop\(\)'
        $script:GuiContent | Should -Match 'Update-SearchResultsTabState'
        $script:GuiContent | Should -Match 'Update-CurrentTabContent -SkipIdlePrebuild'
    }

    It 'loads the AppData startup session snapshot before primary tab hydration' {
        $script:GuiContent | Should -Match '\$Script:StartupSessionSnapshot = \$null'
        $script:GuiContent | Should -Match 'GUICommon\\Read-GuiSessionStateDocument -AppName ''Baseline'' -ExpectedSchema ''Baseline\.GuiSettings'''
        $script:GuiContent | Should -Match '\$Script:UIDensity = if \(Get-Command -Name ''Normalize-BaselineUiDensity'''
        $script:GuiContent | Should -Match '\$Script:StartupHydratePrimaryTab = \$desiredTab'
        $script:GuiContent | Should -Match '\$Script:StartupHydratePrimaryTab = \$desiredLast'
        $script:GuiContent | Should -Match '\$startupHydratePrimaryTab = if \(-not \[string\]::IsNullOrWhiteSpace\(\[string\]\$Script:StartupHydratePrimaryTab\)\)'
        $script:GuiContent | Should -Match '\$startupRestoreSessionPending = \[bool\]\$Script:StartupRestoreSessionPending'
    }

    It 'restores the startup session before the splash can close' {
        $script:GuiContent | Should -Match '\$restoredSessionAction = \{'
        $script:GuiContent | Should -Not -Match 'Regions\.GUI\.RestoreLastSessionAsync'
        $script:GuiContent | Should -Not -Match '\$Form\.Dispatcher\.BeginInvoke\(\s*\[System\.Action\]\$restoredSessionAction'
        $script:GuiContent | Should -Match '\$restoredSessionStatusText = Get-UxLocalizedString -Key ''GuiLogSessionRestoredPreviousState'''
        $script:GuiContent | Should -Match '\$restoreGuiSessionStateScript = Get-GuiFunctionCapture -Name ''Restore-GuiSessionState'''
        $script:GuiContent | Should -Match '\$setGuiStatusTextScript = Get-GuiFunctionCapture -Name ''Set-GuiStatusText'''
        $script:GuiContent | Should -Match '& \$restoreGuiSessionStateScript -Snapshot \$Script:StartupSessionSnapshot'
        $script:SessionStateContent | Should -Match 'param \(\s*\[object\]\s*\$Snapshot = \$null\s*\)'
    }

    It 'routes Build-TabContent init cleanup failures through Write-SwallowedException' {
        $script:GuiContent | Should -Match "BuildTabContent\.MainPanel\.BeginInit"
        $script:GuiContent | Should -Match "BuildTabContent\.MainPanel\.EndInit"
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''BuildTabContent\.Update-PrimaryTabHeaders'''
    }

    It 'captures the startup orchestrator before deferring it to the dispatcher' {
        $script:GuiContent | Should -Match '\$invokeBaselineStartupOrchestratorScript = Get-GuiFunctionCapture -Name ''Invoke-BaselineStartupOrchestrator'''
        $script:GuiContent | Should -Match '& \$invokeBaselineStartupOrchestratorScript -TweakManifest'
    }

    It 'routes dispatcher-yield failures in state transitions through Write-SwallowedException' {
        $script:StateTransitionContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''StateTransitions\.Invoke-GuiStateTransition\.DispatcherYield'''
    }

    It 'routes nav-mode chrome and theme status lookups through Write-SwallowedException' {
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Set-GuiAppsMode\.UpdateGuiNavModeChrome'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Build-AppsViewCards\.UpdateAppsPackageManagerBanner'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Set-GuiAppsMode\.UpdateAppsPackageManagerBanner'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Set-AppsActionControlsEnabled\.ControlEnabled'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ApplyTheme\.Set-GUITheme\.UpdateGuiNavModeChrome'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ApplyTheme\.Set-GUITheme\.ReadStatusText'''
    }

    It 'routes apps cache refresh and view cleanup failures through Write-SwallowedException' {
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Get-ApplicationCacheSnapshot\.CacheSnapshot'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Get-BaselineApplicationsCatalog\.TestWinGetAvailable'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Get-BaselineApplicationsCatalog\.TestChocolateyAvailable'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Build-AppsViewCards\.SetButtonChrome\.Primary'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Build-AppsViewCards\.SetButtonChrome\.Update'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Start-AppsModuleQueuedActionAsync\.TimerStop'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Start-AppsModuleQueuedActionAsync\.TimerDispose'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Clear-AppSelectionState\.SelectionControlIsCheckedFalse'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Build-AppsViewCards\.UpdateAppsCategoryTabCounts'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Build-AppsViewCards\.AddCardHoverEffects'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Build-AppsViewCards\.DispatcherYield'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Start-AppsCacheRefresh\.WriteEntryTrace'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Start-AppsCacheRefresh\.LogWarning'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Start-AppsCacheRefresh\.DisposePowerShell'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Start-AppsCacheRefresh\.DisposeRunspace'''
    }

    It 'routes ContentManagement scroll failures through Write-SwallowedException' {
        $script:ContentManagementContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ContentManagement\.ScrollToVerticalOffset'''
    }

    It 'routes force-close cleanup failures through Write-SwallowedException' {
        $script:StyledControlsSetupContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''StyledControlsSetup\.ForceCloseExecutionFn\.TimerStop'''
        $script:StyledControlsSetupContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''StyledControlsSetup\.ForceCloseExecutionFn\.TimerDispose'''
        $script:StyledControlsSetupContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''StyledControlsSetup\.ForceCloseExecutionFn\.CloseMainWindow'''
        $script:StyledControlsSetupContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''StyledControlsSetup\.ForceCloseExecutionFn\.ShutdownApplication'''
        $script:StyledControlsSetupContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''StyledControlsSetup\.ForceCloseExecutionFn\.FallbackCloseMainWindow'''
    }

    It 'routes GUI region search refresh and splash-close cleanup through logged paths' {
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.SearchRefreshTimer\.Stop'''
        $script:GuiContent | Should -Match 'function Test-GuiStartupSplashLive'
        $script:GuiContent | Should -Match 'function Test-GuiStartupSplashAbortRequested'
        $script:GuiContent | Should -Match 'function Stop-GuiStartupSplashAbortProcess'
        $script:GuiContent | Should -Match 'function Start-GuiStartupSplashAbortWatchdog'
        $script:GuiContent | Should -Match 'if \(Test-GuiStartupSplashAbortRequested -Splash \$Splash\) \{ return \$false \}'
        $script:GuiContent | Should -Match 'if \(-not \[bool\]\$Splash\.IsAlive\) \{ return \$false \}'
        $script:GuiContent | Should -Match 'if \(\$Splash\.ContainsKey\(''WasRendered''\) -and \[bool\]\$Splash\.WasRendered\) \{ return \$true \}'
        $script:GuiContent | Should -Match 'if \(\$Splash\.ContainsKey\(''Dispatcher''\) -and \$null -ne \$Splash\.Dispatcher\) \{ return \$true \}'
        $script:GuiContent | Should -Match '\$testGuiStartupSplashLiveBlock = \(Get-Item function:Test-GuiStartupSplashLive -ErrorAction Stop\)\.ScriptBlock'
        $script:GuiContent | Should -Match '\$testGuiStartupSplashAbortBlock = \(Get-Item function:Test-GuiStartupSplashAbortRequested -ErrorAction Stop\)\.ScriptBlock'
        $script:GuiContent | Should -Match '\$hasLiveStartupSplash = & \$testGuiStartupSplashLiveBlock -Splash \$startupSplashHandle'
        $script:GuiContent | Should -Match 'Start-GuiStartupSplashAbortWatchdog -Splash \$startupSplashHandle'
        $script:GuiContent | Should -Match '\$Form\.ShowInTaskbar = \$false'
        $script:GuiContent | Should -Match '\$Form\.Opacity = 0'
        $script:GuiContent | Should -Match 'if \(& \$testGuiStartupSplashLiveBlock -Splash \$splashHandle\)'
        $script:GuiContent | Should -Match 'Show-TweakGUI aborted before ShowDialog because startup splash was closed'
        $script:GuiContent | Should -Match 'StartupSplashAbortWatchdog: startup splash closed before GuiReady; aborting process'
        $script:GuiContent | Should -Match 'SplashClose runspace: startup splash closed before GuiReady; aborting process'
        $script:GuiContent | Should -Match '\[System\.Diagnostics\.Process\]::GetCurrentProcess\(\)\.Kill\(\)'
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.StartupVisibility\.Apply'''
        $script:GuiContent | Should -Match '\$Form\.ShowActivated = -not \$hasLiveStartupSplash'
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.StartupSplashAbortWatchdog\.RunspaceDispose'''
        $script:GuiContent | Should -Match 'SplashClose runspace: mainWindow taskbar/opacity transition failed'
        $script:GuiContent | Should -Not -Match 'SplashClose runspace: mainWindow\.Activate failed'
        $script:GuiContent | Should -Match 'SplashClose runspace: dispatcher InvokeShutdown failed'
        $script:GuiContent | Should -Match 'SplashClose runspace: PowerShell\.EndInvoke failed'
        $script:GuiContent | Should -Match 'SplashClose runspace: Runspace\.Dispose failed'
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.SplashClose\.LogWarning\.Orchestration'''
        $script:GuiContent | Should -Match '\$stream\.Write\(\$bytes, 0, \$bytes\.Length\)'
        $script:GuiContent | Should -Match 'finally \{ \$stream\.Dispose\(\) \}'
    }

    It 'routes GUI module-base resolution fallbacks through Write-SwallowedException' {
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.ResolveModuleBase\.ModuleBase'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.ResolveModuleBase\.PSCommandPath'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.ResolveModuleBase\.MyInvocationPath'''
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.ResolveModuleBase\.PSScriptRoot'''
    }

    It 'routes GUI DPI initialization failures through Write-SwallowedException' {
        $script:GuiContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.ShowTweakGUI\.InitializeGuiDpiAwareness'''
    }

    It 'preserves primitive WPF setter values when unwrapping PSObjects' {
        $script:GuiContent | Should -Match '\$unwrappedValue = \$resolvedValue\.psobject\.BaseObject'
        $script:GuiContent | Should -Match 'if \(\$null -ne \$unwrappedValue\)'
        $script:GuiContent | Should -Not -Match '\$resolvedValue = \$resolvedValue\.BaseObject'
    }

    It 'uses focused rebuilds for game mode refreshes' {
        $script:GameModeContent | Should -Match '& \$Script:UpdateCurrentTabContentScript -SkipIdlePrebuild'
        $script:GameModeContent | Should -Match '& \$updateCurrentTabContentScript -SkipIdlePrebuild'
        $script:GameModeContent | Should -Match '\$Script:SkipIdlePrebuildOnNextPrimaryTabSelection = \$true'
    }

    It 'does not auto-refresh the apps cache when entering Apps mode' {
        $script:GuiContent | Should -Match 'function Set-GuiAppsMode'
        $script:GuiContent | Should -Not -Match 'function Set-GuiAppsMode[\s\S]*Start-AppsCacheRefresh'
    }

    It 'lazy-loads Software and Apps categories from the selected category only' {
        $script:GuiContent | Should -Match 'function Get-AppsDefaultCatalogCategory'
        $script:GuiContent | Should -Match "return 'Browsers'"
        $script:GuiContent | Should -Not -Match 'AppsProgressContainer'
        $script:GuiContent | Should -Match 'function New-GuiExecutionProgressBarTemplate'
        $script:GuiContent | Should -Match '\$progressBar = New-Object System\.Windows\.Controls\.ProgressBar'
        $script:GuiContent | Should -Match '\$progressBar\.Template = New-GuiExecutionProgressBarTemplate'
        $script:GuiContent | Should -Not -Match 'New-SharedProgressBarHost[\s\S]{0,900}WindowsFormsHost'
        $script:GuiContent | Should -Match 'function Get-AppsCatalogFilesForCategory'
        $script:GuiContent | Should -Match '\$catalogFiles = @\(Get-AppsCatalogFilesForCategory -Category \$effectiveCategory\)'
        $script:GuiContent | Should -Match '\$Script:BaselineApplicationsCatalogByCategory'
        $script:GuiContent | Should -Match '\$Script:AppsCategoryFilter = Resolve-AppsCatalogCategory -Category \$Script:AppsCategoryFilter'
        $script:ApplicationsViewContent | Should -Match 'Get-AppsCatalogCategoryNames'
        $script:ApplicationsViewContent | Should -Not -Match 'Get-AppCategoryFilterValues[\s\S]{0,500}Get-BaselineApplicationsCatalog'
        $script:SessionStateContent | Should -Match 'AppsCategoryFilter = if \(\$Script:AppsCategoryFilter\) \{ \[string\]\$Script:AppsCategoryFilter \} else \{ ''Browsers'' \}'
        $script:SessionStateContent | Should -Match 'NavigationMode = \$currentNavigationMode'
        $script:SessionStateContent | Should -Match '\$desiredNavigationMode = if \(\(Test-GuiObjectField -Object \$Snapshot -FieldName ''NavigationMode''\)'
        $script:SessionStateContent | Should -Match '\$desiredSearchText = if \(\$desiredNavigationMode -eq ''Apps''\)'
        $script:SessionStateContent | Should -Match 'Set-GuiAppsMode -Enable:\$true'
        $script:SessionStateContent | Should -Match 'Set-GuiUpdatesMode -Enable:\$true'
    }

    It 'keeps the visible window title version-free and leaves the version for Help content' {
        $script:StyleContent | Should -Not -Match '\$headerTitle = "\{0\} \{1\}" -f \$windowTitle, \$Script:GuiDisplayVersion'
        $script:GuiContent | Should -Not -Match '\$headerTitle = "\{0\} \{1\}" -f \$headerTitle, \$Script:GuiDisplayVersion'
    }

    It 'routes the dedicated system scan button directly to the scan command instead of the scan checkbox' {
        $script:PresetUiContent | Should -Match 'function New-SystemScanActionRow'
        $script:PresetUiContent | Should -Match '& \$invokeGuiSystemScanCommand'
        $script:ActionHandlersContent | Should -Match 'Register-GuiEventHandler -Source \$BtnScanInstalledApps -EventName ''Click'''
    }

    It 'wires the Updates tab runtime workflow outside manifest execution' {
        $script:GuiContent | Should -Match "UpdatesPanel\.ps1"
        $script:PresetUiContent | Should -Match "Get-GuiRuntimeCommand -Name 'New-GuiWindowsUpdateLeadCardsPanel'"
        $script:UpdatesPanelContent | Should -Match 'function New-GuiUpdatesRuntimePanel'
        $script:UpdatesPanelContent | Should -Match 'function Show-GuiWindowsUpdateRuntimeView'
        $script:UpdatesPanelContent | Should -Match 'GUICommon\\Add-GuiSharedScrollBarResources -Target \$window -Theme \$theme'
        $script:UpdatesPanelContent | Should -Match '\$scrollViewer\.HorizontalScrollBarVisibility = \[System\.Windows\.Controls\.ScrollBarVisibility\]::Auto'
        $script:UpdatesPanelContent | Should -Match 'function New-GuiWindowsUpdateLeadCardsPanel'
        $script:UpdatesPanelContent | Should -Match 'function Set-GuiWindowsUpdatePresetSelection'
        $script:UpdatesPanelContent | Should -Match 'function Start-GuiWindowsUpdateOperation'
        $script:UpdatesPanelContent | Should -Match 'function Sync-GuiWindowsUpdateSelectionEntry'
        $script:UpdatesPanelContent | Should -Match "SharedHelpers\\WindowsUpdate\.Helpers\.ps1"
        $script:UpdatesPanelContent | Should -Match 'Get-WindowsUpdateList'
        $script:UpdatesPanelContent | Should -Match 'Download-WindowsUpdates'
        $script:UpdatesPanelContent | Should -Match 'Install-WindowsUpdates'
        $script:UpdatesPanelContent | Should -Match 'Get-WindowsUpdateHistory'
        $script:UpdatesPanelContent | Should -Match 'Scan for Updates'
        $script:UpdatesPanelContent | Should -Match 'Download Only'
        $script:UpdatesPanelContent | Should -Match 'Install Selected'
        $script:UpdatesPanelContent | Should -Match 'Open Update Runner'
        $script:UpdatesPanelContent | Should -Match 'Disable Updates'
        $script:UpdatesPanelContent | Should -Match 'Load Disable Selection'
        $script:UpdatesPanelContent | Should -Match 'Update Settings Presets'
        $script:UpdatesPanelContent | Should -Match "WindowsUpdateDisableAll -Enable"
        $script:UpdatesPanelContent | Should -Match "WindowsUpdateDisableAll -Disable"
        $script:UpdatesPanelContent | Should -Match "QualityUpdateDeferral -FourDays"
        $script:UpdatesPanelContent | Should -Match 'ButtonVariant ''DangerSubtle'''
        $script:UpdatesPanelContent | Should -Match 'BorderColor \$theme\.DangerText'
        $script:UpdatesPanelContent | Should -Match 'Temporarily enabling Windows Update service for manual update run'
        $script:UpdatesPanelContent | Should -Match 'Disabling Windows Update service after manual update run'
        $script:UpdatesPanelContent | Should -Match 'function Set-BaselineWindowsUpdateManualRunServiceState'
        $script:UpdatesPanelContent | Should -Match '\$invokeGuiSafeActionScript = \$\{function:Invoke-GuiSafeAction\}'
        $script:UpdatesPanelContent | Should -Match '& \$invokeGuiSafeActionScript -Context ''WindowsUpdate\.RuntimePanel'''
        $script:UpdatesPanelContent | Should -Match '& \$invokeGuiSafeActionScript -Context \(''WindowsUpdate\.Card\.\{0\}'''
        $script:UpdatesPanelContent | Should -Match '& \$invokeGuiSafeActionScript -Context \(''WindowsUpdate\.Preset\.\{0\}'''
        $script:UpdatesPanelContent | Should -Match '\$showGuiWindowsUpdateRuntimeViewScript = \$\{function:Show-GuiWindowsUpdateRuntimeView\}'
        $script:UpdatesPanelContent | Should -Match '\$openUpdateRunnerAction = \{[\s\S]*& \$showGuiWindowsUpdateRuntimeViewScript'
        $script:UpdatesPanelContent | Should -Match '\$setGuiWindowsUpdatePresetSelectionScript = \$\{function:Set-GuiWindowsUpdatePresetSelection\}'
        $script:UpdatesPanelContent | Should -Match '\$applyPresetAction = \{[\s\S]*& \$setGuiWindowsUpdatePresetSelectionScript -PresetName \$presetName'
        $script:UpdatesPanelContent | Should -Match '\$loadDisableUpdatesPresetAction = \{[\s\S]*& \$setGuiWindowsUpdatePresetSelectionScript -PresetName ''DisableAll'''
        $script:UpdatesPanelContent | Should -Match '-ShowDialog -Action \$applyPresetAction'
        $script:UpdatesPanelContent | Should -Match '\$setGuiWindowsUpdateStatusScript = \$\{function:Set-GuiWindowsUpdateStatus\}'
        $script:UpdatesPanelContent | Should -Match '\$completeGuiWindowsUpdateOperationScript = \$\{function:Complete-GuiWindowsUpdateOperation\}'
        $script:UpdatesPanelContent | Should -Match '\$updateGuiWindowsUpdateActionStateScript = \$\{function:Update-GuiWindowsUpdateActionState\}'
        $script:UpdatesPanelContent | Should -Match '\$syncGuiWindowsUpdateSelectionEntryScript = \$\{function:Sync-GuiWindowsUpdateSelectionEntry\}'
        $script:UpdatesPanelContent | Should -Match '\$Script:GuiWindowsUpdateOperationInvoker = \{'
        $script:UpdatesPanelContent | Should -Match '& \$setGuiWindowsUpdateStatusScript -Message'
        $script:UpdatesPanelContent | Should -Match '& \$completeGuiWindowsUpdateOperationScript -Payload'
        $script:UpdatesPanelContent | Should -Match '& \$updateGuiWindowsUpdateActionStateScript'
        $script:UpdatesPanelContent | Should -Match '& \$syncGuiWindowsUpdateSelectionEntryScript -SelectionEntry \$selectionEntry'
        $script:UpdatesPanelContent | Should -Match 'EventName ''Click'' -Handler \(\{ & \$syncGuiWindowsUpdateSelectionEntryScript'
        $script:UpdatesPanelContent | Should -Match '& \$Script:GuiWindowsUpdateOperationInvoker -Action'
        $script:UpdatesPanelContent | Should -Match 'Restart required\.'
        $script:UpdatesPanelContent | Should -Match '\[object\[\]\]\$Script:WindowsUpdateAvailableUpdates\.ToArray\(\)'
        $script:UpdatesPanelContent | Should -Match '\[object\[\]\]\$Script:WindowsUpdateHistoryEntries\.ToArray\(\)'
        $script:UpdatesPanelContent | Should -Not -Match '\$Script:TweakManifest'
    }

    It 'keeps GUI error and warning logs from collapsing exceptions to message-only text' {
        $guiSource = Get-BaselineTestSourceText -Path @(
            (Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1')
            (Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '../../Module/GUI') -Recurse -File -Include '*.ps1','*.psm1' | Select-Object -ExpandProperty FullName)
        )

        $guiSource | Should -Not -Match 'LogWarning\s*\([^\r\n]*Exception\.Message'
        $guiSource | Should -Not -Match 'LogError\s*\([^\r\n]*Exception\.Message'
        $guiSource | Should -Not -Match 'Write-Warning\s*\([^\r\n]*Exception\.Message'
    }

    It 'exposes Windows Updates as a top navigation mode rather than a primary tab' {
        $script:GuiContent | Should -Match 'Name="NavModeUpdates"'
        $script:GuiContent | Should -Match '(?s)Name="NavModeTweaks".*Name="NavModeUpdates".*Name="NavModeDeploymentMedia".*Name="NavModeApps"'
        $script:GuiContent | Should -Match 'function Set-GuiUpdatesMode'
        $script:GuiContent | Should -Match 'Build-TabContent -PrimaryTab ''Updates'' -SkipIdlePrebuild'
        $script:GuiContent | Should -Match 'if \(\$Script:UpdatesModeActive\)\s*\{\s*\$targetTab = ''Updates'''
        $script:GuiContent | Should -Match '\$Script:ModeSubtitle\.HorizontalAlignment = if \(\$Enable\) \{ \[System\.Windows\.HorizontalAlignment\]::Center \} else \{ \[System\.Windows\.HorizontalAlignment\]::Left \}'
        $script:GuiContent | Should -Match '\$Script:PrimaryTabHost\.Visibility = if \(\$Enable\) \{ \$collapsed \} else \{ \$visible \}'
        $script:GuiContent | Should -Match 'if \(\$Script:SafeModeGroup\) \{ \$Script:SafeModeGroup\.Visibility = \$visible \}'
        $script:GuiContent | Should -Not -Match '"Updates"\s+=\s+@\(\)'
    }

    It 'exposes Deployment Media Builder as a top navigation GUI without view-level search or filters' {
        $script:GuiContent | Should -Match 'Name="NavModeDeploymentMedia"'
        $script:GuiContent | Should -Match 'Name="DeploymentMediaView"'
        $script:GuiContent | Should -Match 'function Set-GuiDeploymentMediaMode'
        $script:GuiContent | Should -Match 'Initialize-GuiDeploymentMediaBuilderView'
        $script:GuiContent | Should -Match 'Sync-GuiDeploymentMediaBuilderViewText'
        $script:GuiContent | Should -Match '\$Script:TxtSearch, \$Script:TxtSearchPlaceholder, \$Script:BtnClearSearch'
        $script:GuiContent | Should -Match 'Name="BtnDeploymentMediaDetectIso"'
        $script:GuiContent | Should -Match 'Name="BtnDeploymentMediaPreviewPlan"'
        $script:GuiContent | Should -Match 'Name="BtnDeploymentMediaStartBuild"'

        $idxStart = $script:MainWindowContent.IndexOf('<Grid Name="DeploymentMediaView"')
        $idxStart | Should -BeGreaterThan -1
        $idxEnd = $script:MainWindowContent.IndexOf('<Grid Name="AppsView"', $idxStart)
        $idxEnd | Should -BeGreaterThan $idxStart
        $deploymentViewXaml = $script:MainWindowContent.Substring($idxStart, $idxEnd - $idxStart)
        $deploymentViewXaml | Should -Match 'Setup checklist'
        $deploymentViewXaml | Should -Match 'TxtDeploymentMediaPlanPreview'
        $deploymentViewXaml | Should -Not -Match 'Search'
        $deploymentViewXaml | Should -Not -Match 'Filter'
    }

    It 'themes the platform filter ComboBox with the same popup style as other filters' {
        $script:StyleContent | Should -Match 'if \(\$CmbPlatformFilter\) \{ Set-ChoiceComboStyle -Combo \$CmbPlatformFilter \}'
    }

    It 'reapplies shared combo styling to live tweak-row dropdowns during theme refresh' {
        $script:StyleContent | Should -Match 'function Update-ChoiceComboStyles'
        $script:StyleContent | Should -Match '\$entry -is \[System\.Windows\.Controls\.ComboBox\]'
        $script:StyleContent | Should -Match 'Test-GuiObjectField -Object \$entry -FieldName ''ComboBox'''
        $script:StyleContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''StyleManagement\.Update-ChoiceComboStyles\.SetChoiceComboStyle'''
        $script:StyleContent | Should -Match 'if \(\$CmbAppsStatusFilter\) \{ Set-ChoiceComboStyle -Combo \$CmbAppsStatusFilter \}\s*Update-ChoiceComboStyles'
    }

    It 'captures apps callbacks through runtime commands instead of raw function names' {
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Start-AppsCacheRefresh'"
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Set-AppPackageSourcePreferenceState'"
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Start-AppsModuleActionAsync'"
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Start-AppsModuleBatchActionAsync'"
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Clear-AppSelectionState'"
        $script:GuiContent | Should -Match "Get-GuiRuntimeCommand -Name 'Set-AppSelectionState'"
        $script:GuiContent | Should -Match "Get-GuiRuntimeCommand -Name 'Start-AppsModuleActionAsync'"
        $script:GuiContent | Should -Match '& \$setAppSelectionStateCommand'
        $script:ActionHandlersContent | Should -Match '& \$startAppsModuleActionAsyncCommand'
    }

    It 'routes menu-state sync fallbacks through Write-SwallowedException' {
        $script:ActionHandlersContent | Should -Match 'ActionHandlers\.SyncMenuState\.MenuActionsScanSystem\.SetChecked'
        $script:ActionHandlersContent | Should -Match 'ActionHandlers\.SyncMenuState\.MenuActionsScanSystem\.SyncClick'
        $script:ActionHandlersContent | Should -Match 'ActionHandlers\.SyncMenuState\.MenuActionsScanSystem\.Checked'
        $script:ActionHandlersContent | Should -Match 'ActionHandlers\.SyncMenuState\.MenuActionsScanSystem\.Unchecked'
        $script:ActionHandlersContent | Should -Match 'ActionHandlers\.SyncMenuState\.MenuViewFilters\.SetChecked'
        $script:ActionHandlersContent | Should -Match 'ActionHandlers\.SyncMenuState\.MenuViewTheme\.SetChecked'
        $script:ActionHandlersContent | Should -Match 'ActionHandlers\.SyncMenuState\.MenuViewTheme\.SyncClick'
        $script:ActionHandlersContent | Should -Match 'ActionHandlers\.SyncMenuState\.MenuViewTheme\.Checked'
        $script:ActionHandlersContent | Should -Match 'ActionHandlers\.SyncMenuState\.MenuViewTheme\.Unchecked'
        $script:ActionHandlersContent | Should -Match 'ActionHandlers\.SyncMenuState\.MenuToolsAppsManager\.Checked'
        $script:ActionHandlersContent | Should -Match 'ActionHandlers\.SyncMenuState\.MenuToolsUpdateAllApps\.Checked'
    }

    It 'routes add-custom-app refresh and disconnect relay failures through Write-SwallowedException' {
        $script:ActionHandlersContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.AddCustomApp\.RefreshCatalog'''
        $script:ActionHandlersContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.SyncMenuState\.MenuActionsDisconnect\.RaiseEvent'''
    }

    It 'exposes a dedicated apps scan button instead of repurposing the main run button' {
        $script:GuiContent | Should -Match '<Button Name="BtnScanInstalledApps"'
        $script:ActionHandlersContent | Should -Match 'Register-GuiEventHandler -Source \$BtnScanInstalledApps -EventName ''Click'''
        $script:ActionHandlersContent | Should -Not -Match 'Set-GuiButtonIconContent -Button \$Script:BtnRun -IconName ''ArrowSync'''
    }

    It 'uses the neutral installed-status prompt while the cache is cold' {
        $script:ApplicationsViewContent | Should -Match 'GuiAppsCacheRefreshRequired'
        $script:ApplicationsViewContent | Should -Match 'Installed status not scanned'
    }

    It 'includes the installed-app cache in the apps render signature' {
        $script:ApplicationsViewContent | Should -Match 'function Get-ApplicationCacheSignature'
        $script:ApplicationsViewContent | Should -Match '"Cache=\$cacheSignature"'
    }

    It 'includes package-manager availability in the apps render signature' {
        $script:ApplicationsViewContent | Should -Match 'function Get-AppsPackageManagerAvailabilityState'
        $script:ApplicationsViewContent | Should -Match 'function Update-AppsPackageManagerBanner'
        $script:ApplicationsViewContent | Should -Match '"PackageManagers=\$packageManagerAvailabilitySignature"'
    }

    It 'routes ApplicationsView UI-state catches through Write-SwallowedException' {
        $script:ApplicationsViewContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsPackageManagerBanner\.Visibility'''
        $script:ApplicationsViewContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsPackageManagerBanner\.Text'''
        $script:ApplicationsViewContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsSourceFilterControls\.All'''
        $script:ApplicationsViewContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsSourceFilterControls\.WinGet'''
        $script:ApplicationsViewContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsSourceFilterControls\.Chocolatey'''
        $script:ApplicationsViewContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsViewModeControls\.Cards'''
        $script:ApplicationsViewContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsViewModeControls\.List'''
        $script:ApplicationsViewContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsCategoryTabs\.Foreground'''
        $script:ApplicationsViewContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsCategoryTabs\.Background'''
        $script:ApplicationsViewContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppStatusFilterList\.SetChoiceComboStyle'''
        $script:ApplicationsViewContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppStatusFilterList\.Foreground'''
        $script:ApplicationsViewContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppStatusFilterList\.ForegroundProperty'''
    }

    It 'renders an Apps-tab banner for when both package managers are unavailable' {
        $script:GuiContent | Should -Match '<Border Name="AppsPackageManagerBanner" Visibility="Collapsed"'
        $script:GuiContent | Should -Match '<TextBlock Name="TxtAppsPackageManagerBanner" VerticalAlignment="Center" TextWrapping="Wrap"/>'
        $script:GuiContent | Should -Match 'AppsPackageManagerBanner\.Background = \$bc\.ConvertFromString\(\$Theme\.CautionBg\)'
        $script:GuiContent | Should -Match 'TxtAppsPackageManagerBanner\.Foreground = \$bc\.ConvertFromString\(\$Theme\.CautionText\)'
    }

    It 'labels a cold apps cache without implying install is blocked' {
        $script:GuiContent | Should -Match 'Installed status not scanned'
    }

    It 'returns early when the installed-app cache has not been scanned yet' {
        $script:GuiContent | Should -Match 'if \(\-not \$cacheReady\)'
        $script:GuiContent | Should -Match '\$cacheRefreshPrompt ='
        $script:GuiContent | Should -Match 'Update-AppsSelectionSummary'
        $script:GuiContent | Should -Match 'return'
    }

    It 'keeps the per-app install action available before the installed-app cache has been scanned' {
        $script:GuiContent | Should -Match '\$primaryActionKind = if \(\$isInstalled\) \{ ''Uninstall'' \} else \{ ''Install'' \}'
        $script:GuiContent | Should -Match '\$primaryActionRequiresCache = \(\$primaryActionKind -ne ''Install''\)'
        $script:GuiContent | Should -Match '\$primaryButton\.IsEnabled = \(\-not \$Script:AppsOperationInProgress\) -and \(\-not \$Script:AppsCacheRefreshInProgress\) -and \(\-not \$isAppActionBusy\) -and \(\(\-not \$primaryActionRequiresCache\) -or \$cacheReady\)'
    }
}
