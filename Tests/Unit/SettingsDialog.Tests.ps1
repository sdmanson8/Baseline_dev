Set-StrictMode -Version Latest

BeforeAll {
    . (Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1')

    $script:DialogHelpersPath = Join-Path $PSScriptRoot '../../Module/GUI/DialogHelpers.ps1'
    $script:DialogHelpersSplitRoot = Join-Path $PSScriptRoot '../../Module/GUI/DialogHelpers'
    $script:MenuHandlersPath = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers/MenuHandlers.ps1'
    $script:ActionHandlersSplitRoot = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers'
    $script:WindowSetupPath = Join-Path $PSScriptRoot '../../Module/GUI/WindowSetup.ps1'

    $script:DialogHelpersContent = Get-BaselineTestSourceText -Path @(
        $script:DialogHelpersPath
        (Join-Path $script:DialogHelpersSplitRoot 'DialogThemeHelpers.ps1')
        (Join-Path $script:DialogHelpersSplitRoot 'SettingsDialogs.ps1')
        (Join-Path $script:DialogHelpersSplitRoot 'RemoteDialogs.ps1')
        (Join-Path $script:DialogHelpersSplitRoot 'ContentDialogs.ps1')
        (Join-Path $script:DialogHelpersSplitRoot 'AuditOperatorDialogs.ps1')
    )
    $script:SettingsDialogContent = Get-BaselineTestSourceText -Path (Join-Path $script:DialogHelpersSplitRoot 'SettingsDialogs.ps1')

    $script:MenuHandlersContent = Get-BaselineTestSourceText -Path @(
        $script:MenuHandlersPath
        (Join-Path $script:ActionHandlersSplitRoot 'ThemeNavigationHandlers.ps1')
        (Join-Path $script:ActionHandlersSplitRoot 'ButtonHandlers.ps1')
        (Join-Path $script:ActionHandlersSplitRoot 'SystemScanFooterHandlers.ps1')
        (Join-Path $script:ActionHandlersSplitRoot 'MenuHandlers.ps1')
    )
    $script:WindowSetupContent = Get-BaselineTestSourceText -Path $script:WindowSetupPath
}

Describe 'Settings dialog wiring' {
    It 'restores the tabbed settings dialog and searchable language picker' {
        $script:DialogHelpersContent | Should -Match 'function Show-GuiSettingsDialog'
        $script:DialogHelpersContent | Should -Match 'TabControl Name="SettingsTabs"'
        $script:DialogHelpersContent | Should -Match 'Name="BtnSettingsLanguage"'
        $script:DialogHelpersContent | Should -Match 'Name="SettingsLanguagePopup"'
        $script:DialogHelpersContent | Should -Match '<Popup Name="SettingsLanguagePopup"[^>]*StaysOpen="True"'
        $script:DialogHelpersContent | Should -Match 'Name="SettingsLanguageListPanel"'
        $script:DialogHelpersContent | Should -Match 'Name="ChkDesignMode"'
        $script:DialogHelpersContent | Should -Match '\$settingsLanguageState\.Code = ''en-US'''
        $script:DialogHelpersContent | Should -Match '\$nativeBlock\.Text = \[string\]\$entry\.NativeName'
        $script:DialogHelpersContent | Should -Match '\$engBlock\.Text = \[string\]\$entry\.EnglishName'
        $script:DialogHelpersContent | Should -Match '\$langBtn\.Template = \$langTemplate'
        $script:DialogHelpersContent | Should -Match '\$searchIndex\.IndexOf\(\$normalizedFilter, \[System\.StringComparison\]::OrdinalIgnoreCase\) -ge 0'
        $script:DialogHelpersContent | Should -Match '\$txtSettingsLanguageSearch\.Add_TextChanged'
        $script:DialogHelpersContent | Should -Match '& \$languageUiState\.Render \(\[string\]\$txtSettingsLanguageSearch\.Text\)'
        $script:DialogHelpersContent | Should -Match '\$getUxLocalizedStringCapture = \$\{function:Get-UxLocalizedString\}'
        $script:DialogHelpersContent | Should -Match '& \$getUxLocalizedStringCapture -Key ''GuiLanguageSearchNoResults'''
        $script:DialogHelpersContent | Should -Not -Match '\[string\]\$textSender\.Text'
        $script:DialogHelpersContent | Should -Not -Match 'Name="CmbLanguage"'
        $script:DialogHelpersContent | Should -Not -Match '\[string\]\$_\.SearchIndex -like "\*\$normalizedFilter\*"'
    }

    It 'themes settings input controls through the shared surface tokens' {
        $script:SettingsDialogContent | Should -Match '\$surfaceControl = if \(\$theme\.InputBg\)'
        $script:SettingsDialogContent | Should -Match '<SolidColorBrush x:Key="\{x:Static SystemColors\.WindowBrushKey\}" Color="\$surfaceControl"/>'
        $script:SettingsDialogContent | Should -Match '<SolidColorBrush x:Key="\{x:Static SystemColors\.ControlTextBrushKey\}" Color="\$textPrimary"/>'
        $script:SettingsDialogContent | Should -Match '(?s)<Style TargetType="ComboBox" x:Key="SettingsCombo">.*<Setter Property="Background" Value="\$surfaceControl"/>.*<Setter Property="Foreground" Value="\$textPrimary"/>.*<Setter Property="BorderBrush" Value="\$controlBorder"/>.*<Setter Property="OverridesDefaultStyle" Value="True"/>.*<Setter Property="ItemContainerStyle" Value="\{StaticResource SettingsComboItem\}"/>.*<ControlTemplate TargetType="\{x:Type ComboBox\}">.*<ToggleButton x:Name="DropDownToggle".*IsChecked="\{Binding IsDropDownOpen, RelativeSource=\{RelativeSource TemplatedParent\}, Mode=TwoWay\}".*<Popup x:Name="Popup"'
        $script:SettingsDialogContent | Should -Match '(?s)<Style TargetType="TextBox" x:Key="SettingsTextBox">.*<Setter Property="Background" Value="\$surfaceControl"/>.*<Setter Property="Foreground" Value="\$textPrimary"/>.*<Setter Property="BorderBrush" Value="\$controlBorder"/>.*<Setter Property="CaretBrush" Value="\$textPrimary"/>.*<Trigger Property="IsEnabled" Value="False">.*<Setter Property="Opacity" Value="1"/>'
        $script:SettingsDialogContent | Should -Match 'ConvertTo-GuiBrush -Color \$surfaceControl -Context ''DialogHelpers\.ShowGuiSettingsDialog\.InputBg'''
        $script:SettingsDialogContent | Should -Match 'ConvertTo-GuiBrush -Color \$selectionSurface -Context ''DialogHelpers\.ShowGuiSettingsDialog\.Selection'''
        $script:SettingsDialogContent | Should -Match '\$control\.Resources\[\[System\.Windows\.SystemColors\]::WindowBrushKey\] = \$settingsInputBgBrush'
        $script:SettingsDialogContent | Should -Match '\$control\.Resources\[\[System\.Windows\.SystemColors\]::ControlTextBrushKey\] = \$settingsTextPrimaryBrush'
        $script:SettingsDialogContent | Should -Match '\$control\.OverridesDefaultStyle = \$true'
        $script:SettingsDialogContent | Should -Not -Match 'Set-ChoiceComboStyle -Combo \$control'
        $script:SettingsDialogContent | Should -Match '& \$applySettingsComboItemTheme \$ci'
        $script:SettingsDialogContent | Should -Not -Match 'Background="#FFFFFF"|Foreground="#1A1C2E"|BorderBrush="#A7B0C0"|CaretBrush="#1A1C2E"|#CCE4F7|#EDF2FA'
    }

    It 'threads design mode through the settings save handler' {
        $script:SettingsDialogContent | Should -Match '\$chkDesignMode = \$dlg\.FindName\(''ChkDesignMode''\)'
        $script:SettingsDialogContent | Should -Match 'if \(\$chkDesignMode\) \{ \$chkDesignMode\.IsEnabled = \$true \}'
        $script:MenuHandlersContent | Should -Match "DesignMode = if \(Get-Command -Name 'Get-BaselineUserPreference'"
        $script:MenuHandlersContent | Should -Match 'if \(\$result.ContainsKey\(''DesignMode''\)\)'
        $script:MenuHandlersContent | Should -Match 'Set-DesignModeState -Enabled \$desiredDesignMode'
    }

    It 'shows log folder actions and gates custom log folders behind Expert mode' {
        $script:SettingsDialogContent | Should -Match 'Name="TxtLogFolderPath"'
        $script:SettingsDialogContent | Should -Match 'Name="BtnOpenLogFolder"'
        $script:SettingsDialogContent | Should -Match 'Name="BtnCopyLogFolderPath"'
        $script:SettingsDialogContent | Should -Match 'Name="BtnClearOldLogs"'
        $script:SettingsDialogContent | Should -Match 'Name="BtnLogFolderBrowse".*Visibility="Collapsed"'
        $script:SettingsDialogContent | Should -Match '\$btnLogFolderBrowse\.Visibility = if \(\$expertEnabled\)'
        $script:SettingsDialogContent | Should -Match 'LogFileDirectory = if \(\$chkAdvancedMode'
        $script:SettingsDialogContent | Should -Not -Match 'Name="TxtLogFilePath"'
    }

    It 'persists custom log folders and applies them to the active logger' {
        $script:MenuHandlersContent | Should -Match "Get-BaselineUserPreference -Key 'LogFileDirectory'"
        $script:MenuHandlersContent | Should -Match "Set-BaselineUserPreference -Key 'LogFileDirectory'"
        $script:MenuHandlersContent | Should -Match 'Resolve-BaselineLogDirectory -RequestedDirectory \$requestedLogDirectory'
        $script:MenuHandlersContent | Should -Match '\$global:LogFilePath = \$nextLogPath'
        $script:MenuHandlersContent | Should -Match 'Set-LogFile -Path \$global:LogFilePath'
    }

    It 'restores persisted debug mode instead of reopening settings from runtime-only state' {
        $script:MenuHandlersContent | Should -Match 'Get-BaselineUserPreference -Key ''DebugLoggingEnabled'' -Default \$runtimeDebugLoggingEnabled'
        $script:MenuHandlersContent | Should -Match 'Set-BaselineUserPreference -Key ''DebugLoggingEnabled'' -Value \$debugWanted'
        $script:MenuHandlersContent | Should -Match '\$Script:DebugLoggingEnabled = \$debugWanted'
        $script:WindowSetupContent | Should -Match 'Get-BaselineUserPreference -Key ''DebugLoggingEnabled'' -Default \$false'
        $script:WindowSetupContent | Should -Match 'Set-BaselineDebugLogging -Enabled \(\[bool\]\$Script:DebugLoggingEnabled\)'
        $script:WindowSetupContent | Should -Match '\$env:BASELINE_PERF_LOG = ''1'''
    }

    It 'persists package source preference and reopens settings from stored state' {
        $script:MenuHandlersContent | Should -Match 'Get-BaselineUserPreference -Key ''AppsPackageSourcePreference'' -Default \$runtimeAppsPackageSourcePreference'
        $script:MenuHandlersContent | Should -Match 'Set-BaselineUserPreference -Key ''AppsPackageSourcePreference'' -Value \$appsPackageSourcePreferenceWanted'
        $script:MenuHandlersContent | Should -Match '\$appsPackageSourcePreference = if \(Get-Command -Name ''Get-BaselineUserPreference'''
        $script:WindowSetupContent | Should -Match 'Get-BaselineUserPreference -Key ''AppsPackageSourcePreference'' -Default \$Script:AppsPackageSourcePreference'
    }

    It 'persists default startup mode from Settings save' {
        $script:MenuHandlersContent | Should -Match '\$Script:DefaultStartupMode = \[string\]\$result\.DefaultStartupMode'
        $script:MenuHandlersContent | Should -Match 'Set-BaselineUserPreference -Key ''DefaultStartupMode'' -Value \$Script:DefaultStartupMode'
    }
}
