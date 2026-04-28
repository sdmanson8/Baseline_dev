Set-StrictMode -Version Latest

BeforeAll {
    . (Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1')

    $guiCommonPath = Join-Path $PSScriptRoot '../../Module/GUICommon.psm1'
    $dialogsPath = Join-Path $PSScriptRoot '../../Module/GUICommon/Dialogs.ps1'
    $windowChromePath = Join-Path $PSScriptRoot '../../Module/GUICommon/WindowChrome.ps1'
    $dpiAwarenessPath = Join-Path $PSScriptRoot '../../Module/GUICommon/DpiAwareness.ps1'
    $popupWindowsPath = Join-Path $PSScriptRoot '../../Module/GUICommon/PopupWindows.ps1'
    $executionSummaryDialogCommonPath = Join-Path $PSScriptRoot '../../Module/GUICommon/ExecutionSummaryDialog.ps1'
    $utilitiesPath = Join-Path $PSScriptRoot '../../Module/GUICommon/Utilities.ps1'
    $styleManagementPath = Join-Path $PSScriptRoot '../../Module/GUI/StyleManagement.ps1'
    $dialogHelpersPath = Join-Path $PSScriptRoot '../../Module/GUI/DialogHelpers.ps1'
    $dialogHelpersSplitRoot = Join-Path $PSScriptRoot '../../Module/GUI/DialogHelpers'
    $executionSummaryDialogPath = Join-Path $PSScriptRoot '../../Module/GUI/ExecutionSummaryDialog.ps1'
    $guiPath = Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1'
    $applyThemePath = Join-Path $PSScriptRoot '../../Module/GUI/ApplyTheme.ps1'

    $guiCommonContent = @(
        Get-Content -LiteralPath $guiCommonPath -Raw -Encoding UTF8
        Get-Content -LiteralPath $dialogsPath -Raw -Encoding UTF8
        Get-Content -LiteralPath $utilitiesPath -Raw -Encoding UTF8
        Get-Content -LiteralPath $windowChromePath -Raw -Encoding UTF8
        Get-Content -LiteralPath $dpiAwarenessPath -Raw -Encoding UTF8
        Get-Content -LiteralPath $popupWindowsPath -Raw -Encoding UTF8
    ) -join "`n"
    $styleManagementContent = Get-Content -LiteralPath $styleManagementPath -Raw -Encoding UTF8
    $dialogHelpersContent = Get-BaselineTestSourceText -Path @(
        $dialogHelpersPath
        (Join-Path $dialogHelpersSplitRoot 'DialogThemeHelpers.ps1')
        (Join-Path $dialogHelpersSplitRoot 'SettingsDialogs.ps1')
        (Join-Path $dialogHelpersSplitRoot 'RemoteDialogs.ps1')
        (Join-Path $dialogHelpersSplitRoot 'ContentDialogs.ps1')
        (Join-Path $dialogHelpersSplitRoot 'AuditOperatorDialogs.ps1')
    )
    $executionSummaryDialogContent = Get-Content -LiteralPath $executionSummaryDialogPath -Raw -Encoding UTF8
    $executionSummaryDialogCommonContent = Get-Content -LiteralPath $executionSummaryDialogCommonPath -Raw -Encoding UTF8
    $dpiAwarenessContent = Get-Content -LiteralPath $dpiAwarenessPath -Raw -Encoding UTF8
    $guiContent = (Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8) + "`n" + (Get-Content -LiteralPath $applyThemePath -Raw -Encoding UTF8)
}

Describe 'GUI window chrome theming' {
    It 'defines and exports a shared window chrome theming helper' {
        $guiCommonContent | Should -Match 'function Set-GuiWindowChromeTheme'
        $guiCommonContent | Should -Match 'DwmSetWindowAttribute'
        $guiCommonContent | Should -Match "'Set-GuiWindowChromeTheme'"
    }

    It 'defines and exports a shared popup chrome helper with minimize and close controls' {
        $guiCommonContent | Should -Match 'function Add-GuiPopupWindowChrome'
        $guiCommonContent | Should -Match "'Add-GuiPopupWindowChrome'"
        $guiCommonContent | Should -Match 'Minimize'
        $guiCommonContent | Should -Match 'Close'
        $guiCommonContent | Should -Match '\$RootBorder\.Child = \$null'
    }

    It 'normalizes dark mode values before shared chrome theming runs' {
        $guiCommonContent | Should -Match 'function Get-GuiBooleanValue'
        $guiCommonContent | Should -Match 'Get-GuiBooleanValue -Value \$UseDarkMode -Default \$true -Context ''Set-GuiWindowChromeTheme'''
        $guiCommonContent | Should -Match 'Get-GuiBooleanValue -Value \$UseDarkMode -Default \$true -Context ''Add-GuiPopupWindowChrome'''
    }

    It 'defines the miniature popup progress helpers' {
        $guiCommonContent | Should -Match 'function Set-GuiPopupWindowProgress'
        $guiCommonContent | Should -Match 'function Set-GuiPopupWindowTheme'
        $guiCommonContent | Should -Match 'function Update-GuiPopupWindowThemes'
        $guiCommonContent | Should -Match 'function Start-GuiPopupCommandAsync'
        $guiCommonContent | Should -Match 'GuiPopupProgressHost'
        $guiCommonContent | Should -Match 'GuiPopupProgressBar'
        $guiCommonContent | Should -Match 'RowDefinitions\.Insert'
        $guiCommonContent | Should -Match 'Grid]::SetRow\(\$progressHost, \$insertRowIndex\)'
    }

    It 'allows popup windows to register custom theme repaint callbacks' {
        $guiCommonContent | Should -Match 'function Register-GuiPopupThemeWindow'
        $guiCommonContent | Should -Match "'Register-GuiPopupThemeWindow'"
        $guiCommonContent | Should -Match 'GuiPopupThemeCallback'
        $guiCommonContent | Should -Match 'Register-GuiPopupThemeWindow -Window \$Window'
    }

    It 'threads the active dark mode state through shared dialog wrappers' {
        $styleManagementContent | Should -Match '-UseDarkMode \(\$Script:CurrentThemeName -eq ''Dark''\)'
        $dialogHelpersContent | Should -Match '-UseDarkMode \(\$Script:CurrentThemeName -eq ''Dark''\)'
        $executionSummaryDialogContent | Should -Match '-UseDarkMode \(\$Script:CurrentThemeName -eq ''Dark''\)'
    }

    It 'applies native window chrome theming when the main theme changes' {
        $guiContent | Should -Match 'GUICommon\\Set-GuiWindowChromeTheme -Window \$Form -UseDarkMode \(\$Script:CurrentThemeName -eq ''Dark''\)'
    }

    It 'restyles custom caption buttons from the active theme' {
        $styleManagementContent | Should -Match 'function Set-WindowCaptionButtonStyle'
        $guiContent | Should -Match 'Set-WindowCaptionButtonStyle -Button \$BtnMinimize'
        $guiContent | Should -Match 'Set-WindowCaptionButtonStyle -Button \$BtnMaximize'
        $guiContent | Should -Match 'Set-WindowCaptionButtonStyle -Button \$BtnClose -Variant ''Close'''
    }

    It 'routes header toggle and menu sync fallback failures through Write-DebugSwallowedException' {
        $styleManagementContent | Should -Match "StyleManagement\.Set-HeaderToggleControlsStyle\.ApplyChrome"
        $styleManagementContent | Should -Match "StyleManagement\.Set-HeaderToggleStyle\.LoadTemplate"
        $styleManagementContent | Should -Match "StyleManagement\.Update-HeaderModeStateText\.SyncMenuViewTheme"
        $styleManagementContent | Should -Match "StyleManagement\.Update-HeaderModeStateText\.UpdateMainFormTitle"
        $styleManagementContent | Should -Match "StyleManagement\.Update-GuiMenuBarTheme\.UpdateMenuBarBorder"
    }

    It 'routes style template cleanup failures through Write-DebugSwallowedException' {
        $styleManagementContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''StyleManagement\.Set-HeaderToggleStyle\.TemplateReaderDispose'''
        $styleManagementContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''StyleManagement\.Set-ChoiceComboStyle\.TemplateReaderDispose'''
    }

    It 'routes style theme logger failures through Write-DebugSwallowedException' {
        $styleManagementContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''StyleManagement\.Update-GuiMenuBarTheme\.LogWarning'''
        $styleManagementContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''StyleManagement\.Update-GuiScrollBarTheme\.LogWarning'''
    }

    It 'routes popup window cleanup failures through Write-DebugSwallowedException' {
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Start-GuiPopupCommandAsync\.DisposePowerShell'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Start-GuiPopupCommandAsync\.DisposeRunspace'''
    }

    It 'routes popup window styling and progress cleanup failures through Write-DebugSwallowedException' {
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Add-GuiPopupWindowChrome\.SetMinimizeButtonStyle'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Add-GuiPopupWindowChrome\.SetCloseButtonStyle'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Add-GuiPopupWindowChrome\.ResolveThemeColor'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.SetWindowBackground'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.SetWindowForeground'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.ResolveThemeColor'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.SetRootBorderBackground'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.SetRootBorderBorderBrush'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.SetRootBorderThickness'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.SetTitleBarBackground'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.SetTitleBarBorderBrush'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.SetTitleBarBorderThickness'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.SetTitleTextForeground'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.SetPanelContainerBackground'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.SetProgressHostBackground'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.SetProgressBarBrushes'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.SetPopupMinimizeButtonStyle'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.SetPopupCloseButtonStyle'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Set-GuiPopupWindowTheme\.ApplyChrome'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Start-GuiPopupCommandAsync\.InitializeOperationState'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''PopupWindows\.Start-GuiPopupCommandAsync\.CompleteOperationState'''
    }

    It 'routes window chrome cleanup failures through Write-DebugSwallowedException' {
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''WindowChrome\.Restore-WindowSystemMenu\.ApplySystemMenu'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''WindowChrome\.Restore-WindowSystemMenu\.BuildContextMenu'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''WindowChrome\.Invoke-GuiWindowChromeThemeUpdate\.ApplyRoundedCorners'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''WindowChrome\.Invoke-GuiWindowChromeThemeUpdate\.RepaintChrome'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''WindowChrome\.Set-GuiWindowChromeTheme\.SetUseDarkModeProperty'''
        $guiCommonContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''WindowChrome\.Set-GuiWindowChromeTheme\.SetSourceInitializedHandlerProperty'''
    }

    It 'routes Dpi awareness bootstrap failures through Write-DebugSwallowedException' {
        $dpiAwarenessContent.Contains('Write-DebugSwallowedException -ErrorRecord $_ -Source ''DpiAwareness.Initialize-GuiDpiAwareness.Enable''') | Should -BeTrue
    }

    It 'routes execution summary layout-init failures through Write-DebugSwallowedException' {
        $executionSummaryDialogCommonContent | Should -Match 'Write-DebugSwallowedException[\s\S]*ExecutionSummaryDialog\.Show-ExecutionSummaryDialog\.ListStackBeginInit'
        $executionSummaryDialogCommonContent | Should -Match 'Write-DebugSwallowedException[\s\S]*ExecutionSummaryDialog\.Show-ExecutionSummaryDialog\.CapturedListStackBeginInit'
        $executionSummaryDialogCommonContent | Should -Match 'Write-DebugSwallowedException[\s\S]*ExecutionSummaryDialog\.Show-ExecutionSummaryDialog\.CapturedListStackEndInit'
        $executionSummaryDialogCommonContent | Should -Match 'Write-DebugSwallowedException[\s\S]*ExecutionSummaryDialog\.Show-ExecutionSummaryDialog\.ListStackEndInit'
    }

    It 'applies native window chrome theming to custom XAML dialogs' {
        $dialogHelpersContent | Should -Match 'GUICommon\\Set-GuiWindowChromeTheme -Window \$dlg -UseDarkMode \(\$Script:CurrentThemeName -eq ''Dark''\)'
    }

    It 'uses the shared popup chrome helper in the borderless picker windows' {
        $uwpAppsContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Module/Regions/UWPApps.psm1') -Raw -Encoding UTF8
        $systemFeaturesContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Module/Regions/System/System.WindowsFeatures.psm1') -Raw -Encoding UTF8
        $telemetryContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Module/Regions/PrivacyTelemetry/PrivacyTelemetry.TelemetryServices.psm1') -Raw -Encoding UTF8

        ([regex]::Matches($uwpAppsContent, 'GUICommon\\Add-GuiPopupWindowChrome -Window \$Form -RootBorder \$RootBorder -PanelContainer \$PanelContainer -Theme \$currentTheme -UseDarkMode \$isDarkMode')).Count | Should -Be 2
        ([regex]::Matches($systemFeaturesContent, 'GUICommon\\Add-GuiPopupWindowChrome -Window \$Form -RootBorder \$RootBorder -PanelContainer \$PanelContainer -Theme \$Theme -UseDarkMode \$UseDarkMode')).Count | Should -Be 2
        ([regex]::Matches($telemetryContent, 'GUICommon\\Add-GuiPopupWindowChrome -Window \$Form -RootBorder \$RootBorder -PanelContainer \$PanelContainer -Theme \$Theme -UseDarkMode \$UseDarkMode')).Count | Should -Be 1
    }

    It 'repairs the Windows feature picker theme before applying chrome' {
        $systemFeaturesContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Module/Regions/System/System.WindowsFeatures.psm1') -Raw -Encoding UTF8

        $systemFeaturesContent | Should -Match '\$UseDarkMode = \$false'
        $systemFeaturesContent | Should -Match 'Repair-GuiThemePalette -Theme \$Theme -ThemeName'
    }

    It 'routes popup actions through the shared async runner' {
        $systemFeaturesContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Module/Regions/System/System.WindowsFeatures.psm1') -Raw -Encoding UTF8
        $telemetryContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Module/Regions/PrivacyTelemetry/PrivacyTelemetry.TelemetryServices.psm1') -Raw -Encoding UTF8

        ([regex]::Matches($systemFeaturesContent, 'GUICommon\\Start-GuiPopupCommandAsync -Window \$Form -ModulePath \$modulePath -CommandName ''WindowsCapabilities''')).Count | Should -Be 1
        ([regex]::Matches($systemFeaturesContent, 'GUICommon\\Start-GuiPopupCommandAsync -Window \$Form -ModulePath \$modulePath -CommandName ''WindowsFeatures''')).Count | Should -Be 1
        ([regex]::Matches($telemetryContent, 'GUICommon\\Start-GuiPopupCommandAsync -Window \$Form -ModulePath \$modulePath -CommandName ''ScheduledTasks''')).Count | Should -Be 1
    }

    It 'repaints open popup windows when the main theme changes' {
        $guiContent | Should -Match 'GUICommon\\Update-GuiPopupWindowThemes -Theme \$Theme -UseDarkMode \(\$Script:CurrentThemeName -eq ''Dark''\)'
    }

    It 'marks Close actions as cancel semantics in shared dialogs' {
        $guiCommonContent | Should -Match '\$btn\.IsCancel = \$true'
        $dialogHelpersContent | Should -Match '\$btnClose\.IsCancel = \$true'
    }
}
