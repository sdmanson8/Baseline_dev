Set-StrictMode -Version Latest

BeforeAll {
    . (Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1')

    $script:DialogHelpersPath = Join-Path $PSScriptRoot '../../Module/GUI/DialogHelpers.ps1'
    $script:DialogHelpersSplitRoot = Join-Path $PSScriptRoot '../../Module/GUI/DialogHelpers'
    $script:MenuHandlersPath = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers/MenuHandlers.ps1'
    $script:ActionHandlersSplitRoot = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers'
    $script:BuildPrimaryTabsPath = Join-Path $PSScriptRoot '../../Module/GUI/BuildPrimaryTabs.ps1'
    $script:WindowSetupPath = Join-Path $PSScriptRoot '../../Module/GUI/WindowSetup.ps1'
    $script:EnUsLocalizationPath = Join-Path $PSScriptRoot '../../Localizations/English (United States)/en-US.json'

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
    $script:BuildPrimaryTabsContent = Get-BaselineTestSourceText -Path $script:BuildPrimaryTabsPath
    $script:EnUsLocalizationContent = Get-BaselineTestSourceText -Path $script:EnUsLocalizationPath
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
        $script:BuildPrimaryTabsContent | Should -Match '\$Script:SetSelectedGuiLanguageScript = \$setSelectedGuiLanguageCommand'
        $script:MenuHandlersContent | Should -Match '& \$Script:SetSelectedGuiLanguageScript -langCode \$desiredLanguage'
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

    It 'applies hide-unavailable changes to live filter state before session snapshots are saved' {
        $script:SettingsDialogContent | Should -Match 'Name="ChkHideUnavailableItems"'
        $script:MenuHandlersContent | Should -Match '\$hideUnavailWanted = \[bool\]\$result\.HideUnavailableItems'
        $script:MenuHandlersContent | Should -Match 'Set-HideUnavailableItemsState -HideUnavailableItems \$hideUnavailWanted'
        $script:MenuHandlersContent | Should -Match '\$Script:HideUnavailableItems = \$hideUnavailWanted'
        $script:MenuHandlersContent | Should -Match 'Set-BaselineUserPreference -Key ''HideUnavailableItems'' -Value \$hideUnavailWanted'
    }

    It 'persists launch system scan as an opt-in user preference' {
        $script:SettingsDialogContent | Should -Match 'Name="ChkAutoScanOnLaunch"'
        $script:SettingsDialogContent | Should -Match 'Scan system state on launch'
        $script:MenuHandlersContent | Should -Match 'Get-BaselineUserPreference -Key ''AutoScanOnLaunch'' -Default \$false'
        $script:MenuHandlersContent | Should -Match 'Set-BaselineUserPreference -Key ''AutoScanOnLaunch'' -Value \$autoScanWanted'
        $script:WindowSetupContent | Should -Match '\$Script:AutoScanOnLaunch = \$false'
        $script:WindowSetupContent | Should -Match '\$Script:ScanEnabled = \$false'
        $script:WindowSetupContent | Should -Match 'Get-BaselineUserPreference -Key ''AutoScanOnLaunch'' -Default \$false'
    }

    It 'adds Advanced storage and cache controls with safe clear defaults' {
        $script:SettingsDialogContent | Should -Match 'Name="TxtStorageUsage"'
        $script:SettingsDialogContent | Should -Match 'Name="TxtStorageLocation"'
        $script:SettingsDialogContent | Should -Match 'Name="BtnRefreshStorageUsage"'
        $script:SettingsDialogContent | Should -Match 'Name="BtnClearCache"'
        $script:SettingsDialogContent | Should -Match 'function Show-GuiClearCacheDialog'
        $script:SettingsDialogContent | Should -Match 'Name="ChkTemporaryCacheFiles" Content="\$temporaryCacheFilesLabelXaml" IsChecked="True"'
        $script:SettingsDialogContent | Should -Match 'Name="ChkWorkingFiles" Content="\$workingFilesLabelXaml" IsChecked="True"'
        $script:SettingsDialogContent | Should -Match 'Name="ChkLogs" Content="\$logsLabelXaml" IsChecked="False"'
        $script:SettingsDialogContent | Should -Match 'Name="ChkAuditHistory" Content="\$auditHistoryLabelXaml" IsChecked="False"'
        $script:SettingsDialogContent | Should -Match 'Name="ChkSavedSessionState" Content="\$savedSessionStateLabelXaml" IsChecked="False"'
        $script:SettingsDialogContent | Should -Match 'Set-ButtonChrome -Button \$btnClearCache -Variant ''Secondary'''
        $script:SettingsDialogContent | Should -Match '\$applyButtonChrome = \$\{function:Set-ButtonChrome\}'
        $script:SettingsDialogContent | Should -Match '& \$applyButtonChrome -Button \$btnClearSelected -Variant ''Danger'''
        $script:SettingsDialogContent | Should -Match '& \$applyButtonChrome -Button \$btnClearSelected -Variant ''Primary'''
        $script:SettingsDialogContent | Should -Match '\$removeGuiWorkingCache = \{'
        $script:SettingsDialogContent | Should -Match '\$Script:GuiExtractedRoot'
        $script:SettingsDialogContent | Should -Match '\$getGuiBaselineTempStorageRoot = \{'
        $script:SettingsDialogContent | Should -Match '& \$removeGuiWorkingCache -Root \$tempRoot'
        $script:SettingsDialogContent | Should -Match 'GuiSettingsStorageUsageAppData'
        $script:SettingsDialogContent | Should -Match 'GuiSettingsStorageUsageTemp'
        $script:SettingsDialogContent | Should -Match 'GuiSettingsStorageUsageTotal'
        $script:SettingsDialogContent | Should -Not -Match 'Backups / restore points'
    }

    It 'routes visible settings dialog copy through en-US localization keys' {
        foreach ($key in @(
            'GuiSettingsGeneralSection',
            'GuiSettingsLanguageLabel',
            'GuiSettingsAutoScanOnLaunchLabel',
            'GuiSettingsHideUnavailableLabel',
            'GuiSettingsUiDensityLabel',
            'GuiSettingsPackageSourceLabel',
            'GuiSettingsLoggingEnabledLabel',
            'GuiSettingsOpenLogFolderLabel',
            'GuiSettingsClearOldLogsLabel',
            'GuiSettingsAdvancedModeLabel',
            'GuiSettingsDesignModeLabel',
            'GuiSettingsStorageCacheSection',
            'GuiSettingsStorageUsageHeader',
            'GuiSettingsStorageUsageAppData',
            'GuiSettingsStorageUsageTemp',
            'GuiSettingsStorageUsageTotal',
            'GuiSettingsStorageLocationHeader',
            'GuiSettingsStorageRefreshLabel',
            'GuiSettingsClearCacheLabel',
            'GuiSettingsClearCacheDialogTitle',
            'GuiSettingsClearCacheTemporaryFilesLabel',
            'GuiSettingsClearCacheWorkingFilesLabel',
            'GuiSettingsClearCacheLogsLabel',
            'GuiSettingsClearCacheAuditHistoryLabel',
            'GuiSettingsClearCacheSavedSessionLabel',
            'GuiSettingsClearCacheSavedSessionDescription',
            'GuiSettingsClearSelectedLabel'
        )) {
            $script:SettingsDialogContent | Should -Match "Get-UxLocalizedString -Key '$key'"
            $script:EnUsLocalizationContent | Should -Match "`"$key`":"
        }

        $script:SettingsDialogContent | Should -Not -Match 'Text="General preferences"'
        $script:SettingsDialogContent | Should -Not -Match 'Content="Scan system state on launch"'
        $script:SettingsDialogContent | Should -Not -Match 'Content="Open Log Folder"'
    }
}
