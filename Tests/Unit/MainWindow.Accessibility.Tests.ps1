Set-StrictMode -Version Latest

BeforeAll {
    $script:xamlPath = Join-Path $PSScriptRoot '../../Module/GUI/MainWindow.xaml'
    $script:xamlText = Get-Content -LiteralPath $script:xamlPath -Raw
    $script:buildTweakControlsPath = Join-Path $PSScriptRoot '../../Module/GUI/BuildTweakControls.ps1'
    $script:buildTweakControlsText = Get-Content -LiteralPath $script:buildTweakControlsPath -Raw
}

Describe 'MainWindow.xaml accessibility coverage' {
    It 'XAML loads without parser errors after annotations' {
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName PresentationCore
        $rendered = $script:xamlText -replace '__GuiWindowMinWidth__', '900' -replace '__GuiWindowMinHeight__', '600'
        $reader = [System.Xml.XmlReader]::Create((New-Object System.IO.StringReader $rendered))
        try {
            $obj = [System.Windows.Markup.XamlReader]::Load($reader)
            $obj | Should -Not -BeNullOrEmpty
            $obj.GetType().FullName | Should -Be 'System.Windows.Window'
        } finally {
            $reader.Dispose()
        }
    }

    It 'starts as a real taskbar window while the startup splash stays topmost' {
        $script:xamlText | Should -Match 'Opacity="1"'
        $script:xamlText | Should -Match 'ShowInTaskbar="True"'
        $script:xamlText | Should -Match 'MenuFileSettings'
        $script:xamlText | Should -Not -Match 'MenuViewTheme'
    }

    It 'uses one dynamic Safe or Expert label on the header mode toggle' {
        $script:xamlText | Should -Not -Match 'TxtSafeModeLabel|TxtExpertModeLabel'
        $script:xamlText | Should -Match 'Name="SafeModeGroup"[^>]+Orientation="Horizontal"[^>]+Margin="0,0,12,0"[^>]+VerticalAlignment="Center"'
        $script:xamlText | Should -Match 'Name="ChkSafeMode"[^>]+Content="Safe Mode"'
        $script:xamlText | Should -Match 'Name="ChkSafeMode"[^>]+VerticalContentAlignment="Center"'
        $script:xamlText | Should -Match 'AutomationProperties.Name="Safe / Expert mode"'
        $script:xamlText | Should -Match 'Name="TxtAdvancedModeState"[^>]+Visibility="Collapsed"'
    }

    It 'keeps the duplicate header log button hidden by default' {
        $script:xamlText | Should -Match 'Name="BtnLog"[^>]+Visibility="Collapsed"'
        $script:xamlText | Should -Match 'Name="BtnLog"[^>]+IsTabStop="False"'
    }

    It 'keeps tweak filters split into dropdown and view rows' {
        $script:xamlText | Should -Match '<StackPanel Name="FilterOptionsPanel"[^>]+Orientation="Vertical"'
        $script:xamlText | Should -Match '<WrapPanel Name="FilterDropdownRow"'
        $script:xamlText | Should -Match '<WrapPanel Name="FilterViewRow"[^>]+Margin="0,8,0,0"'
        $script:xamlText.IndexOf('Name="FilterDropdownRow"') | Should -BeLessThan $script:xamlText.IndexOf('Name="FilterViewRow"')
    }
}

Describe 'MainWindow tab order coverage' {
    It 'keeps Set-StaticControlTabOrder aligned with the intended interactive control order' {
        $match = [regex]::Match($script:buildTweakControlsText, '(?s)foreach\s*\(\$control\s+in\s+@\((.*?)\)\)')
        $match.Success | Should -BeTrue

        $orderedNames = New-Object System.Collections.Generic.List[string]
        foreach ($line in ($match.Groups[1].Value -split '\r?\n'))
        {
            $trimmed = $line.Trim().TrimEnd(',')
            if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }

            $nameMatch = [regex]::Match($trimmed, '^\$(?:Script:)?(?<Name>[A-Za-z0-9_]+)$')
            if (-not $nameMatch.Success)
            {
                throw "Unexpected tab-order entry: $trimmed"
            }

            [void]$orderedNames.Add($nameMatch.Groups['Name'].Value)
        }

        $expectedNames = @(
            'BtnHelp',
            'BtnLog',
            'ChkScan',
            'ChkSafeMode',
            'ChkTheme',
            'BtnLanguage',
            'TxtSearch',
            'BtnClearSearch',
            'CmbRiskFilter',
            'CmbCategoryFilter',
            'CmbPlatformFilter',
            'ChkHideUnavailableItems',
            'ChkSelectedOnly',
            'ChkHighRiskOnly',
            'ChkRestorableOnly',
            'ChkGamingOnly',
            'BtnDefaults',
            'BtnExportSettings',
            'BtnImportSettings',
            'BtnRestoreSnapshot',
            'BtnPreviewRun',
            'BtnRun',
            'BtnUpdateAllApps',
            'BtnAppsFilterToggle',
            'AppsCategoryTabs',
            'CmbAppsStatusFilter',
            'BtnAppsSourceFilterAll',
            'BtnAppsSourceFilterWinGet',
            'BtnAppsSourceFilterChocolatey',
            'BtnInstallSelectedApps',
            'BtnUninstallSelectedApps',
            'BtnUpdateSelectedApps',
            'BtnApplyQueuedActions',
            'BtnClearQueuedActions',
            'BtnScanInstalledApps'
        )

        $orderedNames.Count | Should -Be $expectedNames.Count
        for ($i = 0; $i -lt $expectedNames.Count; $i++)
        {
            $orderedNames[$i] | Should -Be $expectedNames[$i]
        }

        ($orderedNames | Sort-Object -Unique).Count | Should -Be $orderedNames.Count
    }
}
