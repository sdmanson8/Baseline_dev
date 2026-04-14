Set-StrictMode -Version Latest

BeforeAll {
    $guiCommonPath = Join-Path $PSScriptRoot '../../Module/GUICommon.psm1'
    $styleManagementPath = Join-Path $PSScriptRoot '../../Module/GUI/StyleManagement.ps1'
    $dialogHelpersPath = Join-Path $PSScriptRoot '../../Module/GUI/DialogHelpers.ps1'
    $executionSummaryDialogPath = Join-Path $PSScriptRoot '../../Module/GUI/ExecutionSummaryDialog.ps1'
    $guiPath = Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1'

    $guiCommonContent = Get-Content -LiteralPath $guiCommonPath -Raw -Encoding UTF8
    $styleManagementContent = Get-Content -LiteralPath $styleManagementPath -Raw -Encoding UTF8
    $dialogHelpersContent = Get-Content -LiteralPath $dialogHelpersPath -Raw -Encoding UTF8
    $executionSummaryDialogContent = Get-Content -LiteralPath $executionSummaryDialogPath -Raw -Encoding UTF8
    $guiContent = Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
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
