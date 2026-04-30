Set-StrictMode -Version Latest

BeforeAll {
    $stylePath = Join-Path $PSScriptRoot '../../Module/GUI/StyleManagement.ps1'
    $guiPath = Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1'
    $xamlPath = Join-Path $PSScriptRoot '../../Module/GUI/MainWindow.xaml'
    $applyThemePath = Join-Path $PSScriptRoot '../../Module/GUI/ApplyTheme.ps1'
    $windowSetupPath = Join-Path $PSScriptRoot '../../Module/GUI/WindowSetup.ps1'
    $buildTweakControlsPath = Join-Path $PSScriptRoot '../../Module/GUI/BuildTweakControls.ps1'
    $themeManagementPath = Join-Path $PSScriptRoot '../../Module/GUI/ThemeManagement.ps1'

    $script:StyleContent = Get-Content -LiteralPath $stylePath -Raw -Encoding UTF8
    $script:ThemeContent = Get-Content -LiteralPath $themeManagementPath -Raw -Encoding UTF8
    $script:WindowSetupContent = Get-Content -LiteralPath $windowSetupPath -Raw -Encoding UTF8
    $script:GuiContent = @(
        Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8
        Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
        Get-Content -LiteralPath $applyThemePath -Raw -Encoding UTF8
        $script:WindowSetupContent
        Get-Content -LiteralPath $buildTweakControlsPath -Raw -Encoding UTF8
    ) -join "`n"
}

Describe 'Footer and theme toggle layout' {
    It 'uses the icon pipeline for the primary footer action buttons without changing the whole window font' {
        $script:GuiContent | Should -Match '<Button Name="BtnPreviewRun" Content=""\s+FontFamily="FluentSystemIcons"'
        $script:GuiContent | Should -Match '<Button Name="BtnRun" Content=""\s+FontFamily="FluentSystemIcons"'
        $script:GuiContent | Should -Match 'Set-GuiButtonIconContent -Button \$Script:BtnPreviewRun\s+-IconName ''PreviewRun'''
        $script:GuiContent | Should -Match 'Set-GuiButtonIconContent -Button \$Script:BtnRun\s+-IconName ''RunTweaks'''
    }

    It 'clamps header-driven window width updates to the available work area' {
        $script:StyleContent | Should -Match '\$workArea = \[System\.Windows\.SystemParameters\]::WorkArea'
        $script:StyleContent | Should -Match '\$clampedMinWidth = \[Math\]::Min\(\[Math\]::Ceiling\(\$neededWidth\), \$workArea\.Width\)'
        $script:GuiContent | Should -Match 'Update-WindowMinWidthFromHeader'
    }

    It 'uses a dedicated theme palette for the Light Mode toggle' {
        $script:StyleContent | Should -Match "ValidateSet\('Default', 'Mode', 'Theme'\)"
        $script:StyleContent | Should -Match 'Set-HeaderToggleStyle -CheckBox \$ChkTheme -Palette Theme'
    }

    It 'routes seeded visible-if failures through Write-DebugSwallowedException' {
        $script:GuiContent | Should -Match "BuildTweakControls\.SeedControlVisibility\.VisibleIf"
    }

    It 'gives the footer a two-row action and status layout' {
        $script:GuiContent | Should -Match '<Border Name="BottomBorder" Grid.Row="6" Padding="10,14,10,8" BorderThickness="0,1,0,0">'
        $script:GuiContent | Should -Match '<StackPanel Name="ActionButtonBar" Grid.Column="0"\s+Orientation="Vertical"'
        $script:GuiContent | Should -Match '<TextBlock Name="RunPathContextLabel" Grid.Column="2"'
    }

    It 'styles the footer and secondary action group from opaque active theme surfaces' {
        $script:ThemeContent | Should -Match 'CardBg\s+= "#1E2433"'
        $script:ThemeContent | Should -Match 'CardBorder\s+= "#293044"'
        $script:ThemeContent | Should -Match 'CardHoverBg\s+= "#202638"'
        $script:ThemeContent | Should -Match 'CardBg\s+= "#FBFCFE"'
        $script:ThemeContent | Should -Match 'CardBorder\s+= "#E6EAF0"'
        $script:ThemeContent | Should -Match 'CardHoverBg\s+= "#F6F8FB"'
        $script:ThemeContent | Should -Match 'PresetPanelBg\s+= "#1E2433"'
        $script:ThemeContent | Should -Match 'StatusPillBg\s+= "#202638"'
        $script:GuiContent | Should -Match '\$BottomBorder\.Background = \$bc\.ConvertFromString\(\$Theme\.PanelBg\)'
        $script:GuiContent | Should -Match '\$BottomBorder\.BorderBrush = \$bc\.ConvertFromString\(\$Theme\.CardBorder\)'
        $script:GuiContent | Should -Match '\$Script:SecondaryActionGroupBorder\.Background = \$bc\.ConvertFromString\(\$Script:CurrentTheme\.CardBg\)'
        $script:GuiContent | Should -Match '\$Script:SecondaryActionGroupBorder\.BorderBrush = \$bc\.ConvertFromString\(\$Script:CurrentTheme\.CardBorder\)'
        $script:GuiContent | Should -Match '\$Script:SecondaryActionGroupBorder\.Opacity = 0\.85'
    }

    It 'uses subtle destructive chrome for restore defaults without making it a primary-danger action' {
        $script:ThemeContent | Should -Match 'DestructiveSubtleBorder = "#33FF6B8A"'
        $script:ThemeContent | Should -Match 'DestructiveSubtleHoverBg = "#10FF6B8A"'
        $script:StyleContent | Should -Match '(?s)''DangerSubtle''\s*\{.*DestructiveSubtleHoverBg.*DestructiveSubtlePressBg.*DestructiveSubtleBorder.*RiskHighBadge.*\$hoverBorder\s*=\s*\$foreground'
        $script:GuiContent | Should -Match 'Set-ButtonChrome -Button \$Script:BtnDefaults -Variant ''DangerSubtle'''
        $script:GuiContent | Should -Not -Match 'Set-ButtonChrome -Button \$Script:BtnDefaults -Variant ''Subtle'' -Muted'
    }

    It 'uses green only as a state accent instead of primary interaction chrome' {
        $script:ThemeContent | Should -Match 'StateAccent\s+= "#B34FD1A5"'
        $script:ThemeContent | Should -Match 'StateAccentStrong\s+= "#4FD1A5"'
        $selectionBlock = [regex]::Match($script:StyleContent, "(?s)'Selection'\s*\{(?<Body>.*?)\n\t\t\t\}")
        $selectionBlock.Success | Should -BeTrue
        $selectionBlock.Groups['Body'].Value | Should -Match 'AccentBlue'
        $selectionBlock.Groups['Body'].Value | Should -Match 'ActiveTabIndicator'
        $selectionBlock.Groups['Body'].Value | Should -Not -Match 'StateAccent'
    }

    It 'uses full subtle card borders in light theme instead of relying on shadows' {
        $tweakRowFactoryPath = Join-Path $PSScriptRoot '../../Module/GUI/TweakRowFactory.ps1'
        $metadataDetailsPath = Join-Path $PSScriptRoot '../../Module/GUI/TweakRowFactory/MetadataDetails.ps1'
        $rowFactoryContent = Get-Content -LiteralPath $tweakRowFactoryPath -Raw -Encoding UTF8
        $metadataContent = Get-Content -LiteralPath $metadataDetailsPath -Raw -Encoding UTF8

        $rowFactoryContent | Should -Match 'CardBorder\s+= \[System\.Windows\.Thickness\]::new\(1\)'
        $rowFactoryContent | Should -Match 'CardBorderFocus\s+= \[System\.Windows\.Thickness\]::new\(2\)'
        $metadataContent | Should -Match '\$shadow\.Opacity = if \(\$isLight\) \{ 0\.04 \} else \{ 0\.18 \}'
        $metadataContent | Should -Match 'Thickness1\s+= if \(\$isLight\) \{ \$Script:T\.CardBorder \} else \{ \$Script:T\.RowDivider \}'
    }

    It 'uses the muted progress palette for shared progress bars' {
        $progressChromePath = Join-Path $PSScriptRoot '../../Module/GUI/AppsModule/ProgressNavChrome.ps1'
        $progressChromeContent = Get-Content -LiteralPath $progressChromePath -Raw -Encoding UTF8

        $progressChromeContent | Should -Match 'ProgressGreen'
        $progressChromeContent | Should -Match 'ProgressGreenTrack'
        $progressChromeContent | Should -Not -Match '\$ProgressBar\.BarColor = \[System\.Drawing\.ColorTranslator\]::FromHtml\(\[string\]\$Theme\.AccentBlue\)'
    }

    It 'loads WPF theme resources and binds root surfaces with DynamicResource' {
        $script:GuiContent | Should -Match 'Set-GuiThemeResources -Target \(\[System\.Windows\.Application\]::Current\) -ThemeName'
        $script:GuiContent | Should -Match 'Set-GuiThemeResources -Target \$Form -ThemeName'
        $script:WindowSetupContent | Should -Match 'Set-GuiThemeResources -Target \(\[System\.Windows\.Application\]::Current\) -ThemeName'
        $script:WindowSetupContent.IndexOf('Set-GuiThemeResources -Target ([System.Windows.Application]::Current) -ThemeName') | Should -BeLessThan ($script:WindowSetupContent.IndexOf('[System.Windows.Markup.XamlReader]::Load'))
        $script:GuiContent | Should -Match 'Background="\{DynamicResource Brush\.WindowBg\}"\s+BorderBrush="\{DynamicResource Brush\.WindowBg\}"\s+BorderThickness="0"'
        $script:GuiContent | Should -Match '<Border Name="RootBorder"[^>]+Background="\{DynamicResource Brush\.WindowBg\}"[^>]+BorderBrush="\{DynamicResource Brush\.Border\}"[^>]+BorderThickness="1"[^>]+HorizontalAlignment="Stretch"[^>]+VerticalAlignment="Stretch"'
        $script:GuiContent | Should -Match '<Grid Background="\{DynamicResource Brush\.WindowBg\}" Margin="0">'
        $script:GuiContent | Should -Match '<Border Name="TitleBar"[^>]+Background="\{DynamicResource Brush\.HeaderBg\}"'
        $script:GuiContent | Should -Match 'Background="\{DynamicResource Brush\.WindowBg\}"'
        $script:GuiContent | Should -Match 'BorderBrush="\{DynamicResource Brush\.Border\}"'
        $script:GuiContent | Should -Match 'Foreground="\{DynamicResource Brush\.TextPrimary\}"'
    }
}
