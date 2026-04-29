Set-StrictMode -Version Latest

BeforeAll {
    . (Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1')

    $guiPath = Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1'
    $appsModulePath = Join-Path $PSScriptRoot '../../Module/GUI/AppsModule.ps1'
    $appsModuleSplitRoot = Join-Path $PSScriptRoot '../../Module/GUI/AppsModule'
    $buildPrimaryTabsPath = Join-Path $PSScriptRoot '../../Module/GUI/BuildPrimaryTabs.ps1'
    $buildTabContentPath = Join-Path $PSScriptRoot '../../Module/GUI/BuildTabContent.ps1'
    $buildTweakControlsPath = Join-Path $PSScriptRoot '../../Module/GUI/BuildTweakControls.ps1'
    $applyThemePath = Join-Path $PSScriptRoot '../../Module/GUI/ApplyTheme.ps1'
    $contentManagementPath = Join-Path $PSScriptRoot '../../Module/GUI/ContentManagement.ps1'
    $styledControlsSetupPath = Join-Path $PSScriptRoot '../../Module/GUI/StyledControlsSetup.ps1'
    $mainWindowPath = Join-Path $PSScriptRoot '../../Module/GUI/MainWindow.xaml'
    $stylePath = Join-Path $PSScriptRoot '../../Module/GUI/StyleManagement.ps1'
    $applicationsViewPath = Join-Path $PSScriptRoot '../../Module/GUI/ApplicationsView.ps1'
    $presetUiPath = Join-Path $PSScriptRoot '../../Module/GUI/PresetUI.ps1'
    $actionHandlersPath = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers.ps1'
    $actionHandlersSplitRoot = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers'
    $stateTransitionPath = Join-Path $PSScriptRoot '../../Module/GUI/StateTransitions.ps1'
    $gameModePath = Join-Path $PSScriptRoot '../../Module/GUI/GameModeUI.ps1'
    $updatesPanelPath = Join-Path $PSScriptRoot '../../Module/GUI/UpdatesPanel.ps1'

    $script:GuiContent = @(
        Get-Content -LiteralPath $mainWindowPath -Raw -Encoding UTF8
        Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
        Get-BaselineTestSourceText -Path @(
            $appsModulePath
            (Join-Path $appsModuleSplitRoot 'CatalogHelpers.ps1')
            (Join-Path $appsModuleSplitRoot 'SelectionQueueState.ps1')
            (Join-Path $appsModuleSplitRoot 'ProgressNavChrome.ps1')
        )
        Get-Content -LiteralPath $buildPrimaryTabsPath -Raw -Encoding UTF8
        Get-Content -LiteralPath $buildTabContentPath -Raw -Encoding UTF8
        Get-Content -LiteralPath $buildTweakControlsPath -Raw -Encoding UTF8
        Get-Content -LiteralPath $applyThemePath -Raw -Encoding UTF8
        Get-Content -LiteralPath $updatesPanelPath -Raw -Encoding UTF8
    ) -join "`n"
    $script:StyleContent = Get-Content -LiteralPath $stylePath -Raw -Encoding UTF8
    $script:ApplicationsViewContent = Get-Content -LiteralPath $applicationsViewPath -Raw -Encoding UTF8
    $script:ContentManagementContent = Get-Content -LiteralPath $contentManagementPath -Raw -Encoding UTF8
    $script:StyledControlsSetupContent = Get-Content -LiteralPath $styledControlsSetupPath -Raw -Encoding UTF8
    $script:PresetUiContent = Get-Content -LiteralPath $presetUiPath -Raw -Encoding UTF8
    $script:ActionHandlersContent = Get-BaselineTestSourceText -Path @(
        $actionHandlersPath
        (Join-Path $actionHandlersSplitRoot 'ThemeNavigationHandlers.ps1')
        (Join-Path $actionHandlersSplitRoot 'ButtonHandlers.ps1')
        (Join-Path $actionHandlersSplitRoot 'SystemScanFooterHandlers.ps1')
        (Join-Path $actionHandlersSplitRoot 'MenuHandlers.ps1')
    )
    $script:StateTransitionContent = Get-Content -LiteralPath $stateTransitionPath -Raw -Encoding UTF8
    $script:GameModeContent = Get-Content -LiteralPath $gameModePath -Raw -Encoding UTF8
    $script:UpdatesPanelContent = Get-Content -LiteralPath $updatesPanelPath -Raw -Encoding UTF8
}

Describe 'Focused GUI rebuilds' {
    It 'keeps idle tab prebuild available but makes it opt-in per rebuild' {
        $script:GuiContent | Should -Match 'function Build-TabContent'
        $script:GuiContent | Should -Match '\[switch\]\$SkipIdlePrebuild'
        $script:GuiContent | Should -Match 'if \(-not \$SkipIdlePrebuild -and \$PrimaryTabs -and \$PrimaryTabs\.Dispatcher\)'
        $script:GuiContent | Should -Match '\[System\.Windows\.Threading\.DispatcherPriority\]::ApplicationIdle'
    }

    It 'threads the focused rebuild flag through the current-tab refresh path' {
        $script:GuiContent | Should -Match 'function Update-CurrentTabContent'
        $script:GuiContent | Should -Match '& \$buildTabContentScript -PrimaryTab \$targetTab -SkipIdlePrebuild:\$SkipIdlePrebuild'
        $script:GuiContent | Should -Match '\$skipIdlePrebuild = \[bool\]\$Script:SkipIdlePrebuildOnNextPrimaryTabSelection'
        $script:GuiContent | Should -Match '& \$updateCurrentTabContentScript -SkipIdlePrebuild:\$skipIdlePrebuild'
    }

    It 'uses focused rebuilds for theme and shared mode transitions' {
        $script:GuiContent | Should -Match 'Build-TabContent -PrimaryTab \$Script:CurrentPrimaryTab -SkipIdlePrebuild'
        $script:StateTransitionContent | Should -Match '& \$Script:UpdateCurrentTabContentScript -SkipIdlePrebuild'
    }

    It 'routes Build-TabContent init cleanup failures through Write-DebugSwallowedException' {
        $script:GuiContent | Should -Match "BuildTabContent\.MainPanel\.BeginInit"
        $script:GuiContent | Should -Match "BuildTabContent\.MainPanel\.EndInit"
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''BuildTabContent\.Update-PrimaryTabHeaders'''
    }

    It 'routes dispatcher-yield failures in state transitions through Write-DebugSwallowedException' {
        $script:StateTransitionContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''StateTransitions\.Invoke-GuiStateTransition\.DispatcherYield'''
    }

    It 'routes nav-mode chrome and theme status lookups through Write-DebugSwallowedException' {
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Set-GuiAppsMode\.UpdateGuiNavModeChrome'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Build-AppsViewCards\.UpdateAppsPackageManagerBanner'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Set-GuiAppsMode\.UpdateAppsPackageManagerBanner'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Set-AppsActionControlsEnabled\.ControlEnabled'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ApplyTheme\.Set-GUITheme\.UpdateGuiNavModeChrome'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ApplyTheme\.Set-GUITheme\.ReadStatusText'''
    }

    It 'routes apps cache refresh and view cleanup failures through Write-DebugSwallowedException' {
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Get-ApplicationCacheSnapshot\.CacheSnapshot'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Get-BaselineApplicationsCatalog\.TestWinGetAvailable'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Get-BaselineApplicationsCatalog\.TestChocolateyAvailable'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Build-AppsViewCards\.SetButtonChrome\.Primary'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Build-AppsViewCards\.SetButtonChrome\.Update'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Start-AppsModuleQueuedActionAsync\.TimerStop'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Start-AppsModuleQueuedActionAsync\.TimerDispose'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Clear-AppSelectionState\.SelectionControlIsCheckedFalse'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Build-AppsViewCards\.UpdateAppsCategoryTabCounts'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Build-AppsViewCards\.AddCardHoverEffects'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Build-AppsViewCards\.DispatcherYield'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Start-AppsCacheRefresh\.WriteEntryTrace'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Start-AppsCacheRefresh\.LogWarning'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Start-AppsCacheRefresh\.DisposePowerShell'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''AppsModule\.Start-AppsCacheRefresh\.DisposeRunspace'''
    }

    It 'routes ContentManagement scroll failures through Write-DebugSwallowedException' {
        $script:ContentManagementContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ContentManagement\.ScrollToVerticalOffset'''
    }

    It 'routes force-close cleanup failures through Write-DebugSwallowedException' {
        $script:StyledControlsSetupContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''StyledControlsSetup\.ForceCloseExecutionFn\.TimerStop'''
        $script:StyledControlsSetupContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''StyledControlsSetup\.ForceCloseExecutionFn\.TimerDispose'''
        $script:StyledControlsSetupContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''StyledControlsSetup\.ForceCloseExecutionFn\.CloseMainWindow'''
        $script:StyledControlsSetupContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''StyledControlsSetup\.ForceCloseExecutionFn\.ShutdownApplication'''
        $script:StyledControlsSetupContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''StyledControlsSetup\.ForceCloseExecutionFn\.FallbackCloseMainWindow'''
    }

    It 'routes GUI region search refresh and splash-close cleanup through Write-DebugSwallowedException' {
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.SearchRefreshTimer\.Stop'''
        $script:GuiContent | Should -Match 'function Test-GuiStartupSplashLive'
        $script:GuiContent | Should -Match 'if \(-not \$Splash\.ContainsKey\(''WasRendered''\)\) \{ return \$false \}'
        $script:GuiContent | Should -Match 'return \(\[bool\]\$Splash\.IsAlive -and \[bool\]\$Splash\.WasRendered\)'
        $script:GuiContent | Should -Match '\$testGuiStartupSplashLiveBlock = \(Get-Item function:Test-GuiStartupSplashLive -ErrorAction Stop\)\.ScriptBlock'
        $script:GuiContent | Should -Match '\$hasLiveStartupSplash = & \$testGuiStartupSplashLiveBlock -Splash \$startupSplashHandle'
        $script:GuiContent | Should -Match 'if \(& \$testGuiStartupSplashLiveBlock -Splash \$splashHandle\)'
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.StartupVisibility\.Apply'''
        $script:GuiContent | Should -Match '\$Form\.ShowActivated = -not \$hasLiveStartupSplash'
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.SplashClose\.LogWarning\.MainWindowTaskbarOpacity'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.SplashClose\.LogWarning\.MainWindowActivate'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.SplashClose\.LogWarning\.DispatcherInvokeShutdown'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.SplashClose\.LogWarning\.PowerShellEndInvoke'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.SplashClose\.LogWarning\.RunspaceDispose'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.SplashClose\.LogWarning\.Orchestration'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.SplashClose\.Trace\.AppendAllText'''
    }

    It 'routes GUI module-base resolution fallbacks through Write-DebugSwallowedException' {
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.ResolveModuleBase\.ModuleBase'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.ResolveModuleBase\.PSCommandPath'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.ResolveModuleBase\.MyInvocationPath'''
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.ResolveModuleBase\.PSScriptRoot'''
    }

    It 'routes GUI DPI initialization failures through Write-DebugSwallowedException' {
        $script:GuiContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Regions\.GUI\.ShowTweakGUI\.InitializeGuiDpiAwareness'''
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
        $script:PresetUiContent | Should -Match "Get-GuiRuntimeCommand -Name 'New-GuiUpdatesRuntimePanel'"
        $script:UpdatesPanelContent | Should -Match 'function New-GuiUpdatesRuntimePanel'
        $script:UpdatesPanelContent | Should -Match 'function Start-GuiWindowsUpdateOperation'
        $script:UpdatesPanelContent | Should -Match "SharedHelpers\\WindowsUpdate\.Helpers\.ps1"
        $script:UpdatesPanelContent | Should -Match 'Get-WindowsUpdateList'
        $script:UpdatesPanelContent | Should -Match 'Download-WindowsUpdates'
        $script:UpdatesPanelContent | Should -Match 'Install-WindowsUpdates'
        $script:UpdatesPanelContent | Should -Match 'Get-WindowsUpdateHistory'
        $script:UpdatesPanelContent | Should -Match 'Scan for Updates'
        $script:UpdatesPanelContent | Should -Match 'Download Only'
        $script:UpdatesPanelContent | Should -Match 'Install Selected'
        $script:UpdatesPanelContent | Should -Match 'Restart required\.'
        $script:UpdatesPanelContent | Should -Not -Match '\$Script:TweakManifest'
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

    It 'routes menu-state sync fallbacks through Write-DebugSwallowedException' {
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

    It 'routes add-custom-app refresh and disconnect relay failures through Write-DebugSwallowedException' {
        $script:ActionHandlersContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.AddCustomApp\.RefreshCatalog'''
        $script:ActionHandlersContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ActionHandlers\.SyncMenuState\.MenuActionsDisconnect\.RaiseEvent'''
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

    It 'routes ApplicationsView UI-state catches through Write-DebugSwallowedException' {
        $script:ApplicationsViewContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsPackageManagerBanner\.Visibility'''
        $script:ApplicationsViewContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsPackageManagerBanner\.Text'''
        $script:ApplicationsViewContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsSourceFilterControls\.All'''
        $script:ApplicationsViewContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsSourceFilterControls\.WinGet'''
        $script:ApplicationsViewContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsSourceFilterControls\.Chocolatey'''
        $script:ApplicationsViewContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsViewModeControls\.Cards'''
        $script:ApplicationsViewContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsViewModeControls\.List'''
        $script:ApplicationsViewContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsCategoryTabs\.Foreground'''
        $script:ApplicationsViewContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppsCategoryTabs\.Background'''
        $script:ApplicationsViewContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppStatusFilterList\.SetChoiceComboStyle'''
        $script:ApplicationsViewContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppStatusFilterList\.Foreground'''
        $script:ApplicationsViewContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ApplicationsView\.Update-AppStatusFilterList\.ForegroundProperty'''
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

    It 'shows a refresh prompt and returns early when the installed-app cache has not been scanned yet' {
        $script:GuiContent | Should -Match 'if \(\-not \$cacheReady\)'
        $script:GuiContent | Should -Match '\$cacheRefreshPrompt ='
        $script:GuiContent | Should -Match '\$Script:TxtAppCacheStatus\.Text = \$cacheRefreshPrompt'
        $script:GuiContent | Should -Match 'Update-AppsSelectionSummary'
        $script:GuiContent | Should -Match 'return'
    }

    It 'keeps the per-app install action available before the installed-app cache has been scanned' {
        $script:GuiContent | Should -Match '\$primaryActionKind = if \(\$isInstalled\) \{ ''Uninstall'' \} else \{ ''Install'' \}'
        $script:GuiContent | Should -Match '\$primaryActionRequiresCache = \(\$primaryActionKind -ne ''Install''\)'
        $script:GuiContent | Should -Match '\$primaryButton\.IsEnabled = \(\-not \$Script:AppsOperationInProgress\) -and \(\-not \$Script:AppsCacheRefreshInProgress\) -and \(\-not \$isAppActionBusy\) -and \(\(\-not \$primaryActionRequiresCache\) -or \$cacheReady\)'
    }
}
