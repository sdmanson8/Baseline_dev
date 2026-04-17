Set-StrictMode -Version Latest

BeforeAll {
    $guiPath = Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1'
    $appsModulePath = Join-Path $PSScriptRoot '../../Module/GUI/AppsModule.ps1'
    $buildPrimaryTabsPath = Join-Path $PSScriptRoot '../../Module/GUI/BuildPrimaryTabs.ps1'
    $buildTabContentPath = Join-Path $PSScriptRoot '../../Module/GUI/BuildTabContent.ps1'
    $buildTweakControlsPath = Join-Path $PSScriptRoot '../../Module/GUI/BuildTweakControls.ps1'
    $applyThemePath = Join-Path $PSScriptRoot '../../Module/GUI/ApplyTheme.ps1'
    $mainWindowPath = Join-Path $PSScriptRoot '../../Module/GUI/MainWindow.xaml'
    $stylePath = Join-Path $PSScriptRoot '../../Module/GUI/StyleManagement.ps1'
    $applicationsViewPath = Join-Path $PSScriptRoot '../../Module/GUI/ApplicationsView.ps1'
    $presetUiPath = Join-Path $PSScriptRoot '../../Module/GUI/PresetUI.ps1'
    $actionHandlersPath = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers.ps1'
    $stateTransitionPath = Join-Path $PSScriptRoot '../../Module/GUI/StateTransitions.ps1'
    $gameModePath = Join-Path $PSScriptRoot '../../Module/GUI/GameModeUI.ps1'

    $script:GuiContent = @(
        Get-Content -LiteralPath $mainWindowPath -Raw -Encoding UTF8
        Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
        Get-Content -LiteralPath $appsModulePath -Raw -Encoding UTF8
        Get-Content -LiteralPath $buildPrimaryTabsPath -Raw -Encoding UTF8
        Get-Content -LiteralPath $buildTabContentPath -Raw -Encoding UTF8
        Get-Content -LiteralPath $buildTweakControlsPath -Raw -Encoding UTF8
        Get-Content -LiteralPath $applyThemePath -Raw -Encoding UTF8
    ) -join "`n"
    $script:StyleContent = Get-Content -LiteralPath $stylePath -Raw -Encoding UTF8
    $script:ApplicationsViewContent = Get-Content -LiteralPath $applicationsViewPath -Raw -Encoding UTF8
    $script:PresetUiContent = Get-Content -LiteralPath $presetUiPath -Raw -Encoding UTF8
    $script:ActionHandlersContent = Get-Content -LiteralPath $actionHandlersPath -Raw -Encoding UTF8
    $script:StateTransitionContent = Get-Content -LiteralPath $stateTransitionPath -Raw -Encoding UTF8
    $script:GameModeContent = Get-Content -LiteralPath $gameModePath -Raw -Encoding UTF8
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

    It 'captures apps callbacks through runtime commands instead of raw function names' {
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Start-AppsCacheRefresh'"
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Set-AppPackageSourcePreferenceState'"
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Start-AppsModuleActionAsync'"
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Start-AppsModuleBatchActionAsync'"
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Clear-AppSelectionState'"
        $script:GuiContent | Should -Match "Get-GuiRuntimeCommand -Name 'Set-AppSelectionState'"
        $script:GuiContent | Should -Match "Get-GuiRuntimeCommand -Name 'Start-AppsModuleActionAsync'"
        $script:GuiContent | Should -Match '& \$setAppSelectionStateCommand'
        $script:GuiContent | Should -Match '& \$startAppsModuleActionAsyncCommand'
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

    It 'renders an Apps-tab banner for when both package managers are unavailable' {
        $script:GuiContent | Should -Match '<Border Name="AppsPackageManagerBanner" Visibility="Collapsed"'
        $script:GuiContent | Should -Match '<TextBlock Name="TxtAppsPackageManagerBanner" VerticalAlignment="Center" TextWrapping="Wrap"/>'
        $script:GuiContent | Should -Match 'AppsPackageManagerBanner\.Background = \$bc\.ConvertFromString\(\$Theme\.CautionBg\)'
        $script:GuiContent | Should -Match 'TxtAppsPackageManagerBanner\.Foreground = \$bc\.ConvertFromString\(\$Theme\.CautionText\)'
    }

    It 'labels a cold apps cache without implying install is blocked' {
        $script:GuiContent | Should -Match 'Installed status not scanned'
    }

    It 'keeps app selection available even when the installed-app cache has not been scanned yet' {
        $script:GuiContent | Should -Match 'if \(\-not \$cacheReady\)'
        $script:GuiContent | Should -Match '\$refreshNotice = \[System\.Windows\.Controls\.TextBlock\]::new\(\)'
        $script:GuiContent | Should -Match 'if \(\-not \$cacheReady\)[\s\S]*?\[void\]\$stack\.Children\.Add\(\$refreshNotice\)[\s\S]*?\}\s*\$selectionRow = \[System\.Windows\.Controls\.DockPanel\]::new\(\)'
    }

    It 'keeps the per-app install action available before the installed-app cache has been scanned' {
        $script:GuiContent | Should -Match '\$primaryActionKind = if \(\$isInstalled\) \{ ''Uninstall'' \} else \{ ''Install'' \}'
        $script:GuiContent | Should -Match '\$primaryActionRequiresCache = \(\$primaryActionKind -ne ''Install''\)'
        $script:GuiContent | Should -Match '\$primaryButton\.IsEnabled = \(\-not \$Script:AppsOperationInProgress\) -and \(\-not \$Script:AppsCacheRefreshInProgress\) -and \(\-not \$isAppActionBusy\) -and \(\(\-not \$primaryActionRequiresCache\) -or \$cacheReady\)'
    }
}
