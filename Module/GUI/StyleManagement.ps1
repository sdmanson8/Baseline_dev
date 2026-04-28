# Style helper utilities for Baseline UI themes and visual defaults.

<#
	    .SYNOPSIS
	    Internal function Set-ButtonChrome.
	#>

	function Set-ButtonChrome
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[System.Windows.Controls.Primitives.ButtonBase]$Button,
			[ValidateSet('Primary', 'Preview', 'Danger', 'DangerSubtle', 'Secondary', 'Subtle', 'Selection', 'SegmentNeutral')]
			[string]$Variant = 'Secondary',
			[switch]$Compact,
			[switch]$Muted
		)

		if (-not $Button) { return }

		$bc = New-SafeBrushConverter -Context 'Set-ButtonChrome'
		$theme = $Script:CurrentTheme
		$getSafeColor = {
			param (
				[string]$ColorName,
				[string]$DefaultColor
			)

			if (-not $theme) { return $DefaultColor }

			$color = if ($theme.ContainsKey($ColorName)) { [string]$theme[$ColorName] } else { $null }
			if ([string]::IsNullOrWhiteSpace($color))
			{
				return $DefaultColor
			}

			return $color
		}.GetNewClosure()
		$borderThickness = 1
		switch ($Variant)
		{
			'Selection'
			{
				$normalBg     = & $getSafeColor -ColorName 'AccentBlue' -DefaultColor '#3B82F6'
				$hoverBg      = & $getSafeColor -ColorName 'AccentHover' -DefaultColor '#60A5FA'
				$pressBg      = & $getSafeColor -ColorName 'AccentPress' -DefaultColor '#2563EB'
				$normalBorder = & $getSafeColor -ColorName 'ActiveTabIndicator' -DefaultColor '#4ADE80'
				$foreground   = '#FFFFFF'
				$borderThickness = 2
			}
			'Primary'
			{
				$normalBg     = & $getSafeColor -ColorName 'AccentBlue' -DefaultColor '#3B82F6'
				$hoverBg      = & $getSafeColor -ColorName 'AccentHover' -DefaultColor '#60A5FA'
				$pressBg      = & $getSafeColor -ColorName 'AccentPress' -DefaultColor '#2563EB'
				$normalBorder = & $getSafeColor -ColorName 'AccentHover' -DefaultColor '#60A5FA'
				$foreground   = '#FFFFFF'
			}
			'Preview'
			{
				$normalBg     = & $getSafeColor -ColorName 'SecondaryButtonBg' -DefaultColor '#30374A'
				$hoverBg      = & $getSafeColor -ColorName 'SecondaryButtonHoverBg' -DefaultColor '#39415A'
				$pressBg      = & $getSafeColor -ColorName 'SecondaryButtonPressBg' -DefaultColor '#262D3E'
				$normalBorder = & $getSafeColor -ColorName 'AccentBlue' -DefaultColor '#3B82F6'
				$foreground   = & $getSafeColor -ColorName 'AccentBlue' -DefaultColor '#3B82F6'
			}
			'Danger'
			{
				$normalBg     = & $getSafeColor -ColorName 'DestructiveBg' -DefaultColor '#C0325A'
				$hoverBg      = & $getSafeColor -ColorName 'DestructiveHover' -DefaultColor '#A6294E'
				$pressBg      = & $getSafeColor -ColorName 'CautionBorder' -DefaultColor '#F38BA8'
				$normalBorder = & $getSafeColor -ColorName 'CautionBorder' -DefaultColor '#F38BA8'
				$foreground   = '#FFFFFF'
			}
			'DangerSubtle'
			{
				$normalBg     = & $getSafeColor -ColorName 'SecondaryButtonBg' -DefaultColor '#30374A'
				$hoverBg      = & $getSafeColor -ColorName 'DestructiveHover' -DefaultColor '#A6294E'
				$pressBg      = & $getSafeColor -ColorName 'DestructiveBg' -DefaultColor '#C0325A'
				$normalBorder = & $getSafeColor -ColorName 'CautionBorder' -DefaultColor '#F38BA8'
				$foreground   = & $getSafeColor -ColorName 'CautionBorder' -DefaultColor '#F38BA8'
			}
			'Subtle'
			{
				if ($Muted)
				{
					# Passive / unselected Subtle — keep the existing weak chrome so
					# Clear Search, Refresh, footer buttons, unselected filter pills,
					# etc. don't grow heavier.
					$normalBg     = & $getSafeColor -ColorName 'TabBg' -DefaultColor '#2F3445'
					$hoverBg      = & $getSafeColor -ColorName 'TabHoverBg' -DefaultColor '#3670B8'
					$pressBg      = & $getSafeColor -ColorName 'TabActiveBg' -DefaultColor '#3670B8'
					$normalBorder = & $getSafeColor -ColorName 'BorderColor' -DefaultColor '#4C556D'
					$foreground   = & $getSafeColor -ColorName 'TextSecondary' -DefaultColor '#9CA3AF'
				}
				else
				{
					# Non-muted Subtle — used as the selected-neutral pill (Source=All,
					# View=Cards, View=List). TabBg + BorderColor is too close to the
					# parent panel to read as a pill, so step the fill one shade
					# brighter and use a distinctly stronger neutral-cool border at
					# 2px so the silhouette is unmistakable without going accent.
					$normalBg     = & $getSafeColor -ColorName 'SecondaryButtonHoverBg' -DefaultColor '#39415A'
					$hoverBg      = & $getSafeColor -ColorName 'TabHoverBg' -DefaultColor '#3670B8'
					$pressBg      = & $getSafeColor -ColorName 'TabActiveBg' -DefaultColor '#3670B8'
					$normalBorder = & $getSafeColor -ColorName 'ActiveTabBorder' -DefaultColor '#89B4FA'
					$foreground   = & $getSafeColor -ColorName 'TextPrimary' -DefaultColor '#CDD6F4'
					$borderThickness = 2
				}
			}
			'SegmentNeutral'
			{
				# Neutral "selected" state for segmented controls (e.g. Source=All,
				# View=Cards/List). Must still read as a real pill — distinct
				# fill AND visible border — but non-accent so WinGet/Chocolatey
				# keep the accent to themselves. Use a stronger neutral-selected
				# fill than the generic secondary chrome so "All" never blends
				# into the panel.
				$normalBg     = & $getSafeColor -ColorName 'SecondaryButtonHoverBg' -DefaultColor '#39415A'
				$hoverBg      = & $getSafeColor -ColorName 'SecondaryButtonHoverBg' -DefaultColor '#39415A'
				$pressBg      = & $getSafeColor -ColorName 'SecondaryButtonHoverBg' -DefaultColor '#39415A'
				$normalBorder = & $getSafeColor -ColorName 'ActiveTabBorder' -DefaultColor '#89B4FA'
				$foreground   = & $getSafeColor -ColorName 'TextPrimary' -DefaultColor '#CDD6F4'
				$borderThickness = 2
			}
			default
			{
				$normalBg     = & $getSafeColor -ColorName 'SecondaryButtonBg' -DefaultColor '#30374A'
				$hoverBg      = & $getSafeColor -ColorName 'SecondaryButtonHoverBg' -DefaultColor '#39415A'
				$pressBg      = & $getSafeColor -ColorName 'SecondaryButtonPressBg' -DefaultColor '#262D3E'
				$normalBorder = & $getSafeColor -ColorName 'SecondaryButtonBorder' -DefaultColor '#5F6984'
				$foreground   = & $getSafeColor -ColorName 'SecondaryButtonFg' -DefaultColor '#E5EAF7'
			}
		}

		$cornerRadius = if ($Compact) { 5 } else { 6 }
		$paddingValue = if ($Button.Padding -and ($Button.Padding.Left -ne 0 -or $Button.Padding.Top -ne 0 -or $Button.Padding.Right -ne 0 -or $Button.Padding.Bottom -ne 0)) {
			$Button.Padding
		} elseif ($Compact) {
			[System.Windows.Thickness]::new(10, 4, 10, 4)
		} else {
			[System.Windows.Thickness]::new(12, 6, 12, 6)
		}

		$normalBgBrush = $bc.ConvertFromString($normalBg)
		$hoverBgBrush = $bc.ConvertFromString($hoverBg)
		$pressBgBrush = $bc.ConvertFromString($pressBg)
		$normalBorderBrush = $bc.ConvertFromString($normalBorder)
		$focusBorderBrush = $bc.ConvertFromString((& $getSafeColor -ColorName 'FocusRing' -DefaultColor '#C9DEFF'))
		$foregroundBrush = $bc.ConvertFromString($foreground)

		$Button.Foreground = $foregroundBrush
		$Button.Background = $normalBgBrush
		$Button.BorderBrush = $normalBorderBrush
		$Button.BorderThickness = New-SafeThickness -Uniform $borderThickness
		$Button.FocusVisualStyle = $null
		$Button.Cursor = [System.Windows.Input.Cursors]::Hand
		$Button.Template = $null

		$buttonType = $Button.GetType()
		$tmpl = New-Object System.Windows.Controls.ControlTemplate($buttonType)
		$bd = New-Object System.Windows.FrameworkElementFactory([System.Windows.Controls.Border])
		$bd.Name = 'Bd'
		$bd.SetValue([System.Windows.Controls.Border]::CornerRadiusProperty, [System.Windows.CornerRadius]::new($cornerRadius))
		$bd.SetValue([System.Windows.Controls.Border]::PaddingProperty, $paddingValue)
		$bd.SetValue([System.Windows.Controls.Border]::BackgroundProperty, $normalBgBrush)
		$bd.SetValue([System.Windows.Controls.Border]::BorderBrushProperty, $normalBorderBrush)
		$bd.SetValue([System.Windows.Controls.Border]::BorderThicknessProperty, (New-SafeThickness -Uniform $borderThickness))
		$cp = New-Object System.Windows.FrameworkElementFactory([System.Windows.Controls.ContentPresenter])
		$cp.SetValue([System.Windows.Controls.ContentPresenter]::HorizontalAlignmentProperty, [System.Windows.HorizontalAlignment]::Center)
		$cp.SetValue([System.Windows.Controls.ContentPresenter]::VerticalAlignmentProperty, [System.Windows.VerticalAlignment]::Center)
		$bd.AppendChild($cp)
		$tmpl.VisualTree = $bd

		$hoverTrigger = New-Object System.Windows.Trigger
		$hoverTrigger.Property = [System.Windows.UIElement]::IsMouseOverProperty
		$hoverTrigger.Value = $true
		[void]($hoverTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::BackgroundProperty) -Value $hoverBgBrush -TargetName 'Bd')))
		[void]($hoverTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::BorderBrushProperty) -Value $focusBorderBrush -TargetName 'Bd')))
		[void]($tmpl.Triggers.Add($hoverTrigger))
		$focusTrigger = New-Object System.Windows.Trigger
		$focusTrigger.Property = [System.Windows.UIElement]::IsKeyboardFocusedProperty
		$focusTrigger.Value = $true
		[void]($focusTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::BorderBrushProperty) -Value $focusBorderBrush -TargetName 'Bd')))
		[void]($focusTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::BorderThicknessProperty) -Value (New-SafeThickness -Uniform 2) -TargetName 'Bd')))
		[void]($tmpl.Triggers.Add($focusTrigger))
		$pressTrigger = New-Object System.Windows.Trigger
		$pressTrigger.Property = [System.Windows.Controls.Primitives.ButtonBase]::IsPressedProperty
		$pressTrigger.Value = $true
		[void]($pressTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::BackgroundProperty) -Value $pressBgBrush -TargetName 'Bd')))
		[void]($pressTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::BorderBrushProperty) -Value $focusBorderBrush -TargetName 'Bd')))
		[void]($tmpl.Triggers.Add($pressTrigger))
		$disabledTrigger = New-Object System.Windows.Trigger
		$disabledTrigger.Property = [System.Windows.UIElement]::IsEnabledProperty
		$disabledTrigger.Value = $false
		[void]($disabledTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::OpacityProperty) -Value 0.55 -TargetName 'Bd')))
		[void]($tmpl.Triggers.Add($disabledTrigger))
		if ($Button -is [System.Windows.Controls.Primitives.ToggleButton])
		{
			# Keep checked ToggleButtons in their declared variant chrome instead of
			# overriding them with the generic pressed/focus styling. Without this,
			# neutral segmented selections (e.g. Source=All, View=Cards) lose their
			# pill silhouette and read like plain text.
			$checkedTrigger = New-Object System.Windows.Trigger
			$checkedTrigger.Property = [System.Windows.Controls.Primitives.ToggleButton]::IsCheckedProperty
			$checkedTrigger.Value = $true
			[void]($checkedTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::BackgroundProperty) -Value $normalBgBrush -TargetName 'Bd')))
			[void]($checkedTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::BorderBrushProperty) -Value $normalBorderBrush -TargetName 'Bd')))
			[void]($checkedTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::BorderThicknessProperty) -Value (New-SafeThickness -Uniform $borderThickness) -TargetName 'Bd')))
			[void]($tmpl.Triggers.Add($checkedTrigger))
		}
		$Button.Template = $tmpl
	}

	<#
	    .SYNOPSIS
	    Internal function Set-WindowCaptionButtonStyle.
	#>

	function Set-WindowCaptionButtonStyle
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[System.Windows.Controls.Button]$Button,
			[ValidateSet('Standard', 'Close')]
			[string]$Variant = 'Standard'
		)

		if (-not $Button) { return }

		$bc = New-SafeBrushConverter -Context 'Set-WindowCaptionButtonStyle'
		$theme = $Script:CurrentTheme
		$getSafeColor = {
			param (
				[string]$ColorName,
				[string]$DefaultColor
			)

			if (-not $theme) { return $DefaultColor }

			$color = if ($theme.ContainsKey($ColorName)) { [string]$theme[$ColorName] } else { $null }
			if ([string]::IsNullOrWhiteSpace($color))
			{
				return $DefaultColor
			}

			return $color
		}.GetNewClosure()

		$foreground = & $getSafeColor -ColorName 'TextPrimary' -DefaultColor '#CDD6F4'
		$normalBgBrush = [System.Windows.Media.Brushes]::Transparent
		$hoverBg = if ($Variant -eq 'Close') {
			& $getSafeColor -ColorName 'DestructiveHover' -DefaultColor '#A6294E'
		} else {
			& $getSafeColor -ColorName 'SecondaryButtonHoverBg' -DefaultColor '#39415A'
		}
		$pressBg = if ($Variant -eq 'Close') {
			& $getSafeColor -ColorName 'DestructiveBg' -DefaultColor '#C0325A'
		} else {
			& $getSafeColor -ColorName 'SecondaryButtonPressBg' -DefaultColor '#262D3E'
		}
		$hoverForeground = if ($Variant -eq 'Close') { '#FFFFFF' } else { $foreground }

		$foregroundBrush = $bc.ConvertFromString($foreground)
		$hoverForegroundBrush = $bc.ConvertFromString($hoverForeground)
		$hoverBgBrush = $bc.ConvertFromString($hoverBg)
		$pressBgBrush = $bc.ConvertFromString($pressBg)
		$focusBorderBrush = $bc.ConvertFromString((& $getSafeColor -ColorName 'FocusRing' -DefaultColor '#C9DEFF'))

		$Button.Foreground = $foregroundBrush
		$Button.Background = $normalBgBrush
		$Button.BorderBrush = [System.Windows.Media.Brushes]::Transparent
		$Button.BorderThickness = New-SafeThickness -Uniform 0
		$Button.FocusVisualStyle = $null
		$Button.Cursor = [System.Windows.Input.Cursors]::Hand
		$Button.Padding = New-SafeThickness -Uniform 0
		$Button.Template = $null

		$tmpl = New-Object System.Windows.Controls.ControlTemplate([System.Windows.Controls.Button])
		$bd = New-Object System.Windows.FrameworkElementFactory([System.Windows.Controls.Border])
		$bd.Name = 'CaptionBd'
		$bd.SetValue([System.Windows.Controls.Border]::BackgroundProperty, $normalBgBrush)
		$bd.SetValue([System.Windows.Controls.Border]::BorderBrushProperty, [System.Windows.Media.Brushes]::Transparent)
		$bd.SetValue([System.Windows.Controls.Border]::BorderThicknessProperty, (New-SafeThickness -Uniform 0))
		$bd.SetValue([System.Windows.Controls.Border]::CornerRadiusProperty, [System.Windows.CornerRadius]::new(6))
		$bd.SetValue([System.Windows.Controls.Border]::SnapsToDevicePixelsProperty, $true)

		$cp = New-Object System.Windows.FrameworkElementFactory([System.Windows.Controls.ContentPresenter])
		$cp.SetValue([System.Windows.Controls.ContentPresenter]::HorizontalAlignmentProperty, [System.Windows.HorizontalAlignment]::Center)
		$cp.SetValue([System.Windows.Controls.ContentPresenter]::VerticalAlignmentProperty, [System.Windows.VerticalAlignment]::Center)
		$cp.SetValue([System.Windows.Controls.ContentPresenter]::RecognizesAccessKeyProperty, $true)
		$bd.AppendChild($cp)
		$tmpl.VisualTree = $bd

		$hoverTrigger = New-Object System.Windows.Trigger
		$hoverTrigger.Property = [System.Windows.UIElement]::IsMouseOverProperty
		$hoverTrigger.Value = $true
		[void]($hoverTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::BackgroundProperty) -Value $hoverBgBrush -TargetName 'CaptionBd')))
		[void]($hoverTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Control]::ForegroundProperty) -Value $hoverForegroundBrush)))
		[void]($tmpl.Triggers.Add($hoverTrigger))

		$focusTrigger = New-Object System.Windows.Trigger
		$focusTrigger.Property = [System.Windows.UIElement]::IsKeyboardFocusedProperty
		$focusTrigger.Value = $true
		[void]($focusTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::BorderBrushProperty) -Value $focusBorderBrush -TargetName 'CaptionBd')))
		[void]($focusTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::BorderThicknessProperty) -Value (New-SafeThickness -Uniform 1) -TargetName 'CaptionBd')))
		[void]($tmpl.Triggers.Add($focusTrigger))

		$pressTrigger = New-Object System.Windows.Trigger
		$pressTrigger.Property = [System.Windows.Controls.Primitives.ButtonBase]::IsPressedProperty
		$pressTrigger.Value = $true
		[void]($pressTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::BackgroundProperty) -Value $pressBgBrush -TargetName 'CaptionBd')))
		[void]($pressTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Control]::ForegroundProperty) -Value $hoverForegroundBrush)))
		[void]($tmpl.Triggers.Add($pressTrigger))

		$disabledTrigger = New-Object System.Windows.Trigger
		$disabledTrigger.Property = [System.Windows.UIElement]::IsEnabledProperty
		$disabledTrigger.Value = $false
		[void]($disabledTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::OpacityProperty) -Value 0.45 -TargetName 'CaptionBd')))
		[void]($tmpl.Triggers.Add($disabledTrigger))

		$Button.Template = $tmpl
	}

	<#
	    .SYNOPSIS
	    Internal function Set-HeaderToggleStyle.
	#>

	function Set-HeaderToggleStyle
	{
		param (
			[System.Windows.Controls.CheckBox]$CheckBox,
			[ValidateSet('Default', 'Mode', 'Theme')]
			[string]$Palette = 'Default'
		)

		if (-not $CheckBox) { return }

		$existingMargin = $CheckBox.Margin
		$theme = $Script:CurrentTheme

		# Helper to ensure a color is a valid hex string
		$ensureHexColor = {
			param($Color, $Default = '#89B4FA')
			if ([string]::IsNullOrWhiteSpace($Color)) { return $Default }
			if ($Color -match '^#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{4}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$') { return $Color }
			return $Default
		}

		$trackOffBg = $null
		$trackOffBorder = $null
		$trackOnBg = $null
		$trackOnBorder = $null
		$thumbOffFill = '#FFFFFF'
		$thumbOnFill = '#FFFFFF'
		$hoverOffBorder = $null
		$hoverOnBorder = $null
		$focusBorder  = & $ensureHexColor $theme.FocusRing      '#C9DEFF'

		switch ($Palette)
		{
			'Mode'
			{
				$trackOffBg = & $ensureHexColor $theme.ToggleOff '#B02040'
				$trackOffBorder = $trackOffBg
				$trackOnBg = '#FFFFFF'
				$trackOnBorder = & $ensureHexColor $theme.ToggleOn '#1A7A2A'
				$thumbOffFill = '#FFFFFF'
				$thumbOnFill = & $ensureHexColor $theme.ToggleOn '#1A7A2A'
				$hoverOffBorder = $trackOffBorder
				$hoverOnBorder = $trackOnBorder
				break
			}
			'Theme'
			{
				$lightSurface = & $ensureHexColor $(if ($Script:LightTheme) { $Script:LightTheme.CardBg } else { $null }) '#FFFFFF'
				$lightBorder = & $ensureHexColor $(if ($Script:LightTheme) { $Script:LightTheme.BorderColor } else { $null }) '#A7B0C0'
				$lightAccent = & $ensureHexColor $(if ($Script:LightTheme) { $Script:LightTheme.AccentBlue } else { $null }) '#1550AA'
				$darkSurface = & $ensureHexColor $(if ($Script:DarkTheme) { $Script:DarkTheme.CardBg } else { $null }) '#272B3A'
				$darkBorder = & $ensureHexColor $(if ($Script:DarkTheme) { $Script:DarkTheme.BorderColor } else { $null }) '#4C556D'

				$trackOffBg = $darkSurface
				$trackOffBorder = $darkBorder
				$trackOnBg = $lightSurface
				$trackOnBorder = $lightAccent
				$thumbOffFill = '#FFFFFF'
				$thumbOnFill = $lightAccent
				$hoverOffBorder = $focusBorder
				$hoverOnBorder = $lightAccent
				break
			}
			default
			{
				$trackOffBg = & $ensureHexColor $theme.SearchBorder '#6B7280'
				$trackOffBorder = & $ensureHexColor $theme.BorderColor '#6B7280'
				$trackOnBg = & $ensureHexColor $theme.AccentBlue '#3B82F6'
				$trackOnBorder = & $ensureHexColor $theme.ActiveTabBorder '#3B82F6'
				$thumbOffFill = '#FFFFFF'
				$thumbOnFill = '#FFFFFF'
				$hoverOffBorder = & $ensureHexColor $theme.AccentHover '#60A5FA'
				$hoverOnBorder = $hoverOffBorder
			}
		}

		if (-not $Script:HeaderToggleTemplates)
		{
			$Script:HeaderToggleTemplates = @{}
		}
		if (-not $Script:HeaderToggleTemplateLoadFailures)
		{
			$Script:HeaderToggleTemplateLoadFailures = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
		}

		$templateCacheKey = '{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}' -f `
			$Script:CurrentThemeName, `
			$Palette, `
			$trackOffBg, `
			$trackOffBorder, `
			$trackOnBg, `
			$trackOnBorder, `
			$thumbOffFill, `
			$thumbOnFill, `
			$focusBorder

		if (
			-not $Script:HeaderToggleTemplates.ContainsKey($templateCacheKey) -and
			-not $Script:HeaderToggleTemplateLoadFailures.Contains($templateCacheKey)
		)
		{
			$templateXaml = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                 TargetType="{x:Type CheckBox}">
    <Grid SnapsToDevicePixels="True">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <ContentPresenter Grid.Column="0"
                          Margin="0,0,10,0"
                          VerticalAlignment="Center"
                          RecognizesAccessKey="True"
                          ContentSource="Content" />

        <Border x:Name="SwitchTrack"
                Grid.Column="1"
                Width="42"
                Height="24"
                CornerRadius="12"
                Background="$trackOffBg"
                BorderBrush="$trackOffBorder"
                BorderThickness="1"
                VerticalAlignment="Center">
            <Grid Margin="2">
                <Ellipse x:Name="SwitchThumb"
                         Width="18"
                         Height="18"
                         Fill="$thumbOffFill"
                         HorizontalAlignment="Left"
                         VerticalAlignment="Center" />
            </Grid>
        </Border>
    </Grid>

    <ControlTemplate.Triggers>
        <Trigger Property="IsChecked" Value="True">
            <Setter TargetName="SwitchTrack" Property="Background" Value="$trackOnBg" />
            <Setter TargetName="SwitchTrack" Property="BorderBrush" Value="$trackOnBorder" />
            <Setter TargetName="SwitchThumb" Property="Fill" Value="$thumbOnFill" />
            <Setter TargetName="SwitchThumb" Property="HorizontalAlignment" Value="Right" />
        </Trigger>
        <MultiTrigger>
            <MultiTrigger.Conditions>
                <Condition Property="IsChecked" Value="False" />
                <Condition Property="IsMouseOver" Value="True" />
            </MultiTrigger.Conditions>
            <Setter TargetName="SwitchTrack" Property="BorderBrush" Value="$hoverOffBorder" />
        </MultiTrigger>
        <MultiTrigger>
            <MultiTrigger.Conditions>
                <Condition Property="IsChecked" Value="True" />
                <Condition Property="IsMouseOver" Value="True" />
            </MultiTrigger.Conditions>
            <Setter TargetName="SwitchTrack" Property="BorderBrush" Value="$hoverOnBorder" />
        </MultiTrigger>
        <Trigger Property="IsKeyboardFocused" Value="True">
            <Setter TargetName="SwitchTrack" Property="BorderBrush" Value="$focusBorder" />
        </Trigger>
        <Trigger Property="IsEnabled" Value="False">
            <Setter TargetName="SwitchTrack" Property="Opacity" Value="0.55" />
            <Setter Property="Opacity" Value="0.65" />
        </Trigger>
    </ControlTemplate.Triggers>
</ControlTemplate>
"@
			$templateReader = $null
			try {
				$templateReader = New-Object System.Xml.XmlNodeReader ([xml]$templateXaml)
				$Script:HeaderToggleTemplates[$templateCacheKey] = [System.Windows.Markup.XamlReader]::Load($templateReader)
			}
			catch {
				$Script:HeaderToggleTemplates[$templateCacheKey] = $null
				[void]$Script:HeaderToggleTemplateLoadFailures.Add($templateCacheKey)
				Write-GuiRuntimeWarning -Context 'Set-HeaderToggleStyle' -Message ("Failed to load header toggle template '{0}': {1}" -f $templateCacheKey, $_.Exception.Message)
				Write-DebugSwallowedException -ErrorRecord $_ -Source 'StyleManagement.Set-HeaderToggleStyle.LoadTemplate'
			}
			finally {
				if ($templateReader)
				{
					try { $templateReader.Dispose() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'StyleManagement.Set-HeaderToggleStyle.TemplateReaderDispose' }
				}
			}
		}

		try {
			$bc = New-SafeBrushConverter -Context 'Set-HeaderToggleStyle'
			$headerToggleTemplate = if ($Script:HeaderToggleTemplates.ContainsKey($templateCacheKey)) { $Script:HeaderToggleTemplates[$templateCacheKey] } else { $null }
			if ($headerToggleTemplate)
			{
				$CheckBox.Template = $headerToggleTemplate
			}
			$CheckBox.Cursor = [System.Windows.Input.Cursors]::Hand
			$CheckBox.FocusVisualStyle = $null
			$CheckBox.Background = [System.Windows.Media.Brushes]::Transparent
			$CheckBox.BorderBrush = [System.Windows.Media.Brushes]::Transparent
			$CheckBox.BorderThickness = [System.Windows.Thickness]::new(0)
			$CheckBox.Padding = [System.Windows.Thickness]::new(0)
			$CheckBox.Margin = $existingMargin
			$CheckBox.MinHeight = 24
			$CheckBox.VerticalContentAlignment = [System.Windows.VerticalAlignment]::Center
			$CheckBox.Foreground = $bc.ConvertFromString($(if ($Palette -eq 'Theme') { $theme.TextPrimary } else { $theme.TextSecondary }))
		}
		catch {
			Write-DebugSwallowedException -ErrorRecord $_ -Source 'StyleManagement.Set-HeaderToggleStyle.ApplyChrome'
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-HeaderToggleControlsStyle.
	#>

	function Set-HeaderToggleControlsStyle
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		try
		{
			if ($ChkSafeMode) { Set-HeaderToggleStyle -CheckBox $ChkSafeMode -Palette Mode }
			if ($ChkTheme) { Set-HeaderToggleStyle -CheckBox $ChkTheme -Palette Theme }
		}
		catch
		{
			Write-DebugSwallowedException -ErrorRecord $_ -Source 'StyleManagement.Set-HeaderToggleControlsStyle.ApplyChrome'
		}
	}

	<#
	    .SYNOPSIS
	    Internal function .
	#>
	function Update-WindowMinWidthFromHeader
	{
		<#
		.SYNOPSIS Re-measures the header row and raises MinWidth so toggle controls are never clipped.
		#>
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()
		try
		{
			if (-not $HeaderBorder -or $HeaderBorder.ActualWidth -le 0) { return }
			$headerGrid = $HeaderBorder.Child
			if (-not ($headerGrid -is [System.Windows.Controls.Grid]) -or $headerGrid.Children.Count -eq 0) { return }
			$topRow = $headerGrid.Children[0]
			if (-not ($topRow -is [System.Windows.Controls.Grid])) { return }
			$topRow.Measure([System.Windows.Size]::new([double]::PositiveInfinity, [double]::PositiveInfinity))
			$neededWidth = $topRow.DesiredSize.Width + 56  # header padding (32) + safety margin (24)
			$workArea = [System.Windows.SystemParameters]::WorkArea
			$clampedMinWidth = [Math]::Min([Math]::Ceiling($neededWidth), $workArea.Width)
			if ($clampedMinWidth -gt $Form.MinWidth)
			{
				$Form.MinWidth = $clampedMinWidth
			}
			if ($Form.Width -gt $workArea.Width)
			{
				$Form.Width = $workArea.Width
			}
		}
		catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'StyleManagement.Update-WindowMinWidthFromHeader' }
	}

	<#
	    .SYNOPSIS
	    Internal function Update-HeaderModeStateText.
	#>

	function Update-HeaderModeStateText
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		$lightEnabled = if ($ChkTheme) { ($ChkTheme.IsChecked -eq $true) } else { ($Script:CurrentThemeName -eq 'Light') }
		$themeMenuLabel = if ($lightEnabled) { (Get-UxLocalizedString -Key 'GuiMenuViewSwitchToDarkMode' -Fallback 'Switch to Dark Mode') } else { (Get-UxLocalizedString -Key 'GuiMenuViewSwitchToLightMode' -Fallback 'Switch to Light Mode') }
		if ($Script:MenuViewTheme)
		{
			try { $Script:MenuViewTheme.IsChecked = $lightEnabled } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'StyleManagement.Update-HeaderModeStateText.SyncMenuViewTheme' }
			$Script:MenuViewTheme.Header = $themeMenuLabel
		}

		$bc = New-SafeBrushConverter -Context 'Update-HeaderModeStateText'
		$safeEnabled = [bool]$Script:SafeMode
		$advancedEnabled = [bool]$Script:AdvancedMode
		if ($TxtAdvancedModeState)
		{
			if ($advancedEnabled)
			{
				$TxtAdvancedModeState.Text = (Get-UxLocalizedString -Key 'GuiExpertModeOn' -Fallback 'Expert Mode: On')
			}
			else
			{
				$TxtAdvancedModeState.Text = ''
			}
			$TxtAdvancedModeState.Foreground = $bc.ConvertFromString($(if ($advancedEnabled) { $Script:CurrentTheme.ToggleOn } else { $Script:CurrentTheme.TextMuted }))
		}
		if ($ChkSafeMode)
		{
			$ChkSafeMode.Content = (Get-UxLocalizedString -Key 'GuiChkSafeMode' -Fallback 'Safe Mode')
		}
		if ($TitleBarText -and $Form)
		{
			try
			{
				$windowTitle = Get-UxLocalizedString -Key 'GuiMainWindowTitleFormat' -Fallback 'Baseline | Utility for {0}' -FormatArgs @((Get-OSInfo).OSName)
				$Form.Title = $windowTitle
				$TitleBarText.Text = $windowTitle
			}
			catch
			{
				Write-DebugSwallowedException -ErrorRecord $_ -Source 'StyleManagement.Update-HeaderModeStateText.UpdateMainFormTitle'
			}
		}
		if ($TxtThemeState)
		{
			$themeLabel = if ($lightEnabled) { (Get-UxLocalizedString -Key 'GuiThemeLight' -Fallback 'Theme: Light') } else { (Get-UxLocalizedString -Key 'GuiThemeDark' -Fallback 'Theme: Dark') }
			$TxtThemeState.Text = $themeLabel
			$TxtThemeState.Foreground = $bc.ConvertFromString($(if ($lightEnabled) { $Script:CurrentTheme.AccentBlue } else { $Script:CurrentTheme.TextMuted }))
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Update-GuiMenuBarLocalization.
	#>

	function Update-GuiMenuBarLocalization
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		if ($Script:MenuFile)                    { $Script:MenuFile.Header                    = (Get-UxLocalizedString -Key 'GuiMenuFile' -Fallback '_File') }
		if ($Script:MenuActions)                 { $Script:MenuActions.Header                 = (Get-UxLocalizedString -Key 'GuiMenuActions' -Fallback '_Actions') }
		if ($Script:MenuView)                    { $Script:MenuView.Header                    = (Get-UxLocalizedString -Key 'GuiMenuView' -Fallback '_View') }
		if ($Script:MenuTools)                   { $Script:MenuTools.Header                   = (Get-UxLocalizedString -Key 'GuiMenuTools' -Fallback '_Tools') }
		if ($Script:MenuHelp)                    { $Script:MenuHelp.Header                    = (Get-UxLocalizedString -Key 'GuiMenuHelp' -Fallback '_Help') }
		if ($Script:MenuActionsConnectToComputer){ $Script:MenuActionsConnectToComputer.Header = (Get-UxLocalizedString -Key 'GuiMenuActionsConnectToComputer' -Fallback 'Connect to Computer...') }
		if ($Script:MenuActionsDisconnect)       { $Script:MenuActionsDisconnect.Header       = (Get-UxLocalizedString -Key 'GuiMenuActionsDisconnect' -Fallback 'Disconnect') }
		if ($Script:MenuFileImportSettings)      { $Script:MenuFileImportSettings.Header      = (Get-UxLocalizedString -Key 'GuiMenuFileImportSettings' -Fallback 'Import Settings...') }
		if ($Script:MenuFileExportSettings)      { $Script:MenuFileExportSettings.Header      = (Get-UxLocalizedString -Key 'GuiMenuFileExportSettings' -Fallback 'Export Settings...') }
		if ($Script:MenuFileAuditSettings)       { $Script:MenuFileAuditSettings.Header       = (Get-UxLocalizedString -Key 'GuiMenuFileAuditSettings' -Fallback 'Audit Settings...') }
		if ($Script:MenuFileExportConfigProfile) { $Script:MenuFileExportConfigProfile.Header = (Get-UxLocalizedString -Key 'GuiMenuFileExportConfigProfile' -Fallback 'Export Config Profile...') }
		if ($Script:MenuFileExportSystemState)   { $Script:MenuFileExportSystemState.Header   = (Get-UxLocalizedString -Key 'GuiMenuFileExportSystemState' -Fallback 'Export System State...') }
		if ($Script:MenuActionsPreviewRun)       { $Script:MenuActionsPreviewRun.Header       = (Get-UxLocalizedString -Key 'GuiMenuActionsPreviewRun' -Fallback 'Preview Run') }
		if ($Script:MenuActionsRunTweaks)        { $Script:MenuActionsRunTweaks.Header        = (Get-UxLocalizedString -Key 'GuiMenuActionsRunTweaks' -Fallback 'Run Tweaks') }
		if ($Script:MenuActionsUndoLastRun)      { $Script:MenuActionsUndoLastRun.Header      = (Get-UxLocalizedString -Key 'GuiMenuActionsUndoLastRun' -Fallback 'Undo Last Run') }
		if ($Script:MenuActionsRestoreDefaults)  { $Script:MenuActionsRestoreDefaults.Header  = (Get-UxLocalizedString -Key 'GuiMenuActionsRestoreDefaults' -Fallback 'Restore Defaults') }
		if ($Script:MenuActionsCheckCompliance)  { $Script:MenuActionsCheckCompliance.Header  = (Get-UxLocalizedString -Key 'GuiMenuActionsCheckCompliance' -Fallback 'Check Compliance...') }
		if ($Script:MenuActionsScanSystem)       { $Script:MenuActionsScanSystem.Header       = (Get-UxLocalizedString -Key 'GuiMenuActionsScanSystem' -Fallback 'Scan System') }
		if ($Script:MenuActionsAuditLog)         { $Script:MenuActionsAuditLog.Header         = (Get-UxLocalizedString -Key 'GuiMenuActionsAuditLog' -Fallback 'Audit Log...') }
		if ($Script:MenuViewSafeMode)            { $Script:MenuViewSafeMode.Header            = (Get-UxLocalizedString -Key 'GuiChkSafeMode' -Fallback 'Safe Mode') }
		if ($Script:MenuViewFilters)             { $Script:MenuViewFilters.Header             = (Get-UxLocalizedString -Key 'GuiMenuViewFilters' -Fallback 'Show Filters Panel') }
		if ($Script:MenuViewLogsPanel)           { $Script:MenuViewLogsPanel.Header           = (Get-UxLocalizedString -Key 'GuiMenuViewOpenLogs' -Fallback 'Open Logs') }
		Update-HeaderModeStateText
		if ($Script:MenuToolsAppsManager)        { $Script:MenuToolsAppsManager.Header        = (Get-UxLocalizedString -Key 'GuiMenuToolsAppsManager' -Fallback 'Apps Manager') }
		if ($Script:MenuToolsUpdateAllApps)      { $Script:MenuToolsUpdateAllApps.Header      = (Get-UxLocalizedString -Key 'GuiMenuToolsUpdateAllApps' -Fallback 'Update All Applications') }
		if ($Script:MenuToolsExportSupportBundle){ $Script:MenuToolsExportSupportBundle.Header = (New-GuiLabeledIconContent -IconName 'Archive' -Text (Get-UxLocalizedString -Key 'GuiMenuToolsExportSupportBundle' -Fallback 'Export Support Bundle...') -IconSize 12 -Gap 6 -TextFontSize 12 -AllowTextOnlyFallback) }
		if ($Script:MenuToolsApproveRemoteTargets){ $Script:MenuToolsApproveRemoteTargets.Header = (New-GuiLabeledIconContent -IconName 'Shield' -Text (Get-UxLocalizedString -Key 'GuiMenuToolsApproveRemoteTargets' -Fallback 'Approve Target List...') -IconSize 12 -Gap 6 -TextFontSize 12 -AllowTextOnlyFallback) }
		if ($Script:MenuToolsSaveRemoteApprovalPolicy){ $Script:MenuToolsSaveRemoteApprovalPolicy.Header = (New-GuiLabeledIconContent -IconName 'Document' -Text (Get-UxLocalizedString -Key 'GuiMenuToolsSaveRemoteApprovalPolicy' -Fallback 'Save Remote Approval Policy...') -IconSize 12 -Gap 6 -TextFontSize 12 -AllowTextOnlyFallback) }
		if ($Script:MenuToolsLoadRemoteApprovalPolicy){ $Script:MenuToolsLoadRemoteApprovalPolicy.Header = (New-GuiLabeledIconContent -IconName 'Document' -Text (Get-UxLocalizedString -Key 'GuiMenuToolsLoadRemoteApprovalPolicy' -Fallback 'Load Remote Approval Policy...') -IconSize 12 -Gap 6 -TextFontSize 12 -AllowTextOnlyFallback) }
		if ($Script:MenuToolsRemoteConsole) { $Script:MenuToolsRemoteConsole.Header = (New-GuiLabeledIconContent -IconName 'WindowConsole' -Text (Get-UxLocalizedString -Key 'GuiMenuToolsRemoteConsole' -Fallback 'Remote Console...') -IconSize 12 -Gap 6 -TextFontSize 12 -AllowTextOnlyFallback) }
		if ($Script:MenuToolsRemoteSessionStatus){ $Script:MenuToolsRemoteSessionStatus.Header = (New-GuiLabeledIconContent -IconName 'PhoneDesktop' -Text (Get-UxLocalizedString -Key 'GuiMenuToolsRemoteSessionStatus' -Fallback 'Remote Session Status...') -IconSize 12 -Gap 6 -TextFontSize 12 -AllowTextOnlyFallback) }
		if ($Script:MenuHelpStartGuide)          { $Script:MenuHelpStartGuide.Header          = (Get-UxLocalizedString -Key 'GuiMenuHelpStartGuide' -Fallback 'Getting Started') }
		if ($Script:MenuHelpReadme)               { $Script:MenuHelpReadme.Header               = (New-GuiLabeledIconContent -IconName 'Document' -Text (Get-UxLocalizedString -Key 'GuiMenuHelpReadme' -Fallback 'Readme') -IconSize 12 -Gap 6 -TextFontSize 12 -AllowTextOnlyFallback) }
		if ($Script:MenuHelpFAQ)                  { $Script:MenuHelpFAQ.Header                  = (New-GuiLabeledIconContent -IconName 'Help' -Text (Get-UxLocalizedString -Key 'GuiMenuHelpFAQ' -Fallback 'FAQ') -IconSize 12 -Gap 6 -TextFontSize 12 -AllowTextOnlyFallback) }
		if ($Script:MenuHelpChangelog)           { $Script:MenuHelpChangelog.Header           = (Get-UxLocalizedString -Key 'GuiMenuHelpChangelog' -Fallback 'Changelog') }
		if ($Script:MenuHelpCheckForUpdate)      { $Script:MenuHelpCheckForUpdate.Header      = (Get-UxLocalizedString -Key 'GuiMenuHelpCheckForUpdate' -Fallback 'Check for Updates...') }
		if ($Script:MenuHelpReleaseStatus)       { $Script:MenuHelpReleaseStatus.Header       = (New-GuiLabeledIconContent -IconName 'WindowSettings' -Text (Get-UxLocalizedString -Key 'GuiMenuHelpReleaseStatus' -Fallback 'Release Status...') -IconSize 12 -Gap 6 -TextFontSize 12 -AllowTextOnlyFallback) }
		if ($Script:MenuHelpTroubleshooting)     { $Script:MenuHelpTroubleshooting.Header     = (New-GuiLabeledIconContent -IconName 'Toolbox' -Text (Get-UxLocalizedString -Key 'GuiMenuHelpTroubleshooting' -Fallback 'Troubleshooting Guide...') -IconSize 12 -Gap 6 -TextFontSize 12 -AllowTextOnlyFallback) }
		if ($Script:MenuHelpAbout)               { $Script:MenuHelpAbout.Header               = (New-GuiLabeledIconContent -IconName 'Help' -Text (Get-UxLocalizedString -Key 'GuiMenuHelpAbout' -Fallback 'About Baseline') -IconSize 12 -Gap 6 -TextFontSize 12 -AllowTextOnlyFallback) }
	}

	<#
	    .SYNOPSIS
	    Internal function Update-GuiMenuBarTheme.
	#>

	function Update-GuiMenuBarTheme
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		if (-not $Script:MainMenuBar) { return }
		$theme = $Script:CurrentTheme
		if (-not $theme) { return }
		$bc = New-SafeBrushConverter -Context 'Update-GuiMenuBarTheme'
		$resources = $Script:MainMenuBar.Resources
		if (-not $resources) { return }
		$setMenuBrushResource = {
			param(
				[string]$Key,
				[string]$ColorValue
			)

			$resolvedBrush = $bc.ConvertFromString($ColorValue)
			if (-not $resolvedBrush) { return }

			$existingBrush = $resources[$Key]
			if ($existingBrush -is [System.Windows.Media.SolidColorBrush] -and $resolvedBrush -is [System.Windows.Media.SolidColorBrush])
			{
				$targetColor = $resolvedBrush.Color
				if ($existingBrush.Color -ne $targetColor)
				{
					if ($existingBrush.IsFrozen)
					{
						$replacement = [System.Windows.Media.SolidColorBrush]::new($targetColor)
						if ($replacement.CanFreeze) { $replacement.Freeze() }
						$resources[$Key] = $replacement
					}
					else
					{
						$existingBrush.Color = $targetColor
					}
				}
				return
			}

			$resources[$Key] = $resolvedBrush
		}.GetNewClosure()
		try
		{
			& $setMenuBrushResource -Key 'MenuBarBackground'  -ColorValue $theme.HeaderBg
			& $setMenuBrushResource -Key 'MenuBarBorder'      -ColorValue $theme.BorderColor
			& $setMenuBrushResource -Key 'MenuBarForeground'  -ColorValue $theme.TextPrimary
			& $setMenuBrushResource -Key 'MenuBarHoverBg'     -ColorValue $theme.TabHoverBg
			& $setMenuBrushResource -Key 'MenuBarHoverFg'     -ColorValue $theme.TextPrimary
			& $setMenuBrushResource -Key 'MenuSubmenuBg'      -ColorValue $theme.CardBg
			& $setMenuBrushResource -Key 'MenuSubmenuBorder'  -ColorValue $theme.BorderColor
			& $setMenuBrushResource -Key 'MenuSeparatorBrush' -ColorValue $theme.BorderColor
		}
		catch
		{
			try { LogWarning ("Menu bar theme update failed: {0}" -f $_.Exception.Message) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'StyleManagement.Update-GuiMenuBarTheme.LogWarning' }
		}
		if ($Script:MenuBarBorder)
		{
			try
			{
				$Script:MenuBarBorder.Background = $bc.ConvertFromString($theme.HeaderBg)
				$Script:MenuBarBorder.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
			}
			catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'StyleManagement.Update-GuiMenuBarTheme.UpdateMenuBarBorder' }
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Update-GuiScrollBarTheme.
	#>

	function Update-GuiScrollBarTheme
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		$border = $Script:WindowBorder
		if (-not $border) { $border = $Script:MainWindowRootBorder }
		if (-not $border) { return }
		$resources = $border.Resources
		if (-not $resources) { return }
		$theme = $Script:CurrentTheme
		if (-not $theme) { return }
		$bc = New-SafeBrushConverter -Context 'Update-GuiScrollBarTheme'

		$setBrush = {
			param(
				[string]$Key,
				[string]$ColorValue
			)
			if ([string]::IsNullOrWhiteSpace([string]$ColorValue)) { return }
			$resolvedBrush = $bc.ConvertFromString($ColorValue)
			if (-not $resolvedBrush) { return }
			$existing = $resources[$Key]
			if ($existing -is [System.Windows.Media.SolidColorBrush] -and $resolvedBrush -is [System.Windows.Media.SolidColorBrush])
			{
				$targetColor = $resolvedBrush.Color
				if ($existing.Color -ne $targetColor)
				{
					if ($existing.IsFrozen)
					{
						$replacement = [System.Windows.Media.SolidColorBrush]::new($targetColor)
						if ($replacement.CanFreeze) { $replacement.Freeze() }
						$resources[$Key] = $replacement
					}
					else
					{
						$existing.Color = $targetColor
					}
				}
				return
			}
			$resources[$Key] = $resolvedBrush
		}.GetNewClosure()

		try
		{
			& $setBrush -Key 'ScrollBarTrackBrush'       -ColorValue $theme.ScrollBg
			& $setBrush -Key 'ScrollBarThumbBrush'       -ColorValue $theme.ScrollThumb
			& $setBrush -Key 'ScrollBarThumbHoverBrush'  -ColorValue $(if ($theme.ScrollThumbHover)  { $theme.ScrollThumbHover }  else { $theme.ScrollThumb })
			& $setBrush -Key 'ScrollBarThumbActiveBrush' -ColorValue $(if ($theme.ScrollThumbActive) { $theme.ScrollThumbActive } else { $theme.ScrollThumb })
			# Tokens consumed by AppsFilterRadioStyle (MainWindow.xaml). Kept in
			# this resource-push path so the radio dials track the active theme.
			& $setBrush -Key 'RadioForeground'   -ColorValue $theme.TextPrimary
			& $setBrush -Key 'RadioRingNormal'   -ColorValue $theme.BorderColor
			& $setBrush -Key 'RadioRingHover'    -ColorValue $(if ($theme.AccentHover) { $theme.AccentHover } else { $theme.AccentBlue })
			& $setBrush -Key 'RadioRingChecked'  -ColorValue $theme.AccentBlue
			& $setBrush -Key 'RadioDotFill'      -ColorValue $theme.AccentBlue
		}
		catch
		{
			try { LogWarning ("Scrollbar theme update failed: {0}" -f $_.Exception.Message) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'StyleManagement.Update-GuiScrollBarTheme.LogWarning' }
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Update-GuiDuplicateActionVisibility.
	#>

	function Update-GuiDuplicateActionVisibility
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		$collapsed = [System.Windows.Visibility]::Collapsed
		foreach ($control in @(
			$Script:BtnExportSettings,
			$Script:BtnImportSettings,
			$Script:BtnExportConfigProfile,
			$Script:BtnExportSystemState,
			$Script:BtnCheckCompliance,
			$Script:BtnAuditLog
		))
		{
			if ($control) { $control.Visibility = $collapsed }
		}

		if ($BtnLog) { $BtnLog.Visibility = $collapsed }
	}

	<#
	    .SYNOPSIS
	    Internal function Update-GuiLocalizationStrings.
	#>

	function Update-GuiLocalizationStrings
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		# Buttons
		if ($Script:BtnStartHere)
		{
			Set-GuiButtonIconContent -Button $Script:BtnStartHere -IconName 'QuickStart' -Text (Get-UxStartGuideButtonLabel) -ToolTip (Get-UxLocalizedString -Key 'GuiActionStartGuideTooltip' -Fallback 'Open the getting started guide.')
		}
		if ($Script:BtnHelp)
		{
			Set-GuiButtonIconContent -Button $Script:BtnHelp -IconName 'Help' -Text (Get-UxLocalizedString -Key 'GuiBtnHelp' -Fallback 'Help') -ToolTip (Get-UxLocalizedString -Key 'GuiActionOpenHelpTooltip' -Fallback 'Open help and usage guidance.')
		}
		if ($BtnLog)
		{
			Set-GuiButtonIconContent -Button $BtnLog -IconName 'OpenLog' -Text (Get-UxLocalizedString -Key 'GuiBtnLog' -Fallback 'Open Log') -ToolTip (Get-UxLocalizedString -Key 'GuiActionLogTooltip' -Fallback 'Open the detailed execution log.')
		}
		if ($Script:BtnClearSearch)
		{
			Set-GuiButtonIconContent -Button $Script:BtnClearSearch -IconName 'Clear' -Text (Get-UxLocalizedString -Key 'GuiBtnClearSearch' -Fallback 'Clear') -ToolTip (Get-UxLocalizedString -Key 'GuiActionClearSearchTooltip' -Fallback 'Clear search text and active filters.') -IconSize 14 -Gap 6 -TextFontSize 11
		}
		if ($BtnLanguage)
		{
			Set-GuiButtonIconContent -Button $BtnLanguage -IconName 'Language' -Text (Get-UxLocalizedString -Key 'GuiBtnLanguage' -Fallback 'Language') -ToolTip (Get-UxLocalizedString -Key 'GuiBtnLanguageTooltip' -Fallback 'Change language') -IconSize 14 -Gap 6 -TextFontSize 11
		}
		if ($TitleBarText -and $Form)
		{
			$windowTitle = Get-UxLocalizedString -Key 'GuiMainWindowTitleFormat' -Fallback 'Baseline | Utility for {0}' -FormatArgs @((Get-OSInfo).OSName)
			$Form.Title = $windowTitle
			$TitleBarText.Text = $windowTitle
		}
		if ($ScanLabel)
		{
			$ScanLabel.Text = (Get-UxLocalizedString -Key 'GuiSystemScanButton' -Fallback 'System Scan')
		}
		if ($Script:NavModeTweaks)
		{
			$tweaksTip = (Get-UxLocalizedString -Key 'Nav_OptimizeTooltip' -Fallback "Configure Windows system behavior.`nStage changes, preview the plan, then apply in a controlled run.")
			Set-GuiButtonIconContent -Button $Script:NavModeTweaks -IconName 'SystemTab' -Text (Get-UxLocalizedString -Key 'Nav_Optimize' -Fallback 'System Tweaks') -ToolTip $tweaksTip -IconSize 14 -Gap 6 -TextFontSize 11
			[System.Windows.Controls.ToolTipService]::SetInitialShowDelay($Script:NavModeTweaks, 350)
			[System.Windows.Controls.ToolTipService]::SetShowDuration($Script:NavModeTweaks, 15000)
		}
		if ($Script:NavModeApps)
		{
			$appsTip = (Get-UxLocalizedString -Key 'Nav_SoftwareAndAppsTooltip' -Fallback "Install, update, or uninstall applications via WinGet or Chocolatey.`nQueue actions across many apps, then Apply Changes as a batch.")
			Set-GuiButtonIconContent -Button $Script:NavModeApps -IconName 'AppsTab' -Text (Get-UxLocalizedString -Key 'Nav_SoftwareAndApps' -Fallback 'Software & Apps') -ToolTip $appsTip -IconSize 14 -Gap 6 -TextFontSize 11
			[System.Windows.Controls.ToolTipService]::SetInitialShowDelay($Script:NavModeApps, 350)
			[System.Windows.Controls.ToolTipService]::SetShowDuration($Script:NavModeApps, 15000)
		}
		if ($Script:ModeSubtitle)
		{
			$modeSubtitleKey = if ($Script:AppsModeActive) { 'Nav_SoftwareAndAppsSubtitle' } else { 'Nav_OptimizeSubtitle' }
			$modeSubtitleFallback = if ($Script:AppsModeActive) { 'Manage installed applications' } else { 'Configure system behavior' }
			$Script:ModeSubtitle.Text = (Get-UxLocalizedString -Key $modeSubtitleKey -Fallback $modeSubtitleFallback)
			$Script:ModeSubtitle.HorizontalAlignment = if ($Script:AppsModeActive) { [System.Windows.HorizontalAlignment]::Right } else { [System.Windows.HorizontalAlignment]::Left }
		}
		if ($Script:BtnUpdateAllApps)
		{
			Set-GuiButtonIconContent -Button $Script:BtnUpdateAllApps -IconName 'ArrowSync' -Text (Get-UxLocalizedString -Key 'GuiUpdateAllApps' -Fallback 'Update All Installed') -ToolTip (Get-UxLocalizedString -Key 'Tooltip_UpdateAllApplications' -Fallback 'Update all installed applications. You will be asked to confirm.') -IconSize 14 -Gap 6 -TextFontSize 11
		}
		if ($Script:BtnInstallSelectedApps)
		{
			Set-GuiButtonIconContent -Button $Script:BtnInstallSelectedApps -IconName 'ArrowDownload' -Text (Get-UxLocalizedString -Key 'GuiAppsQueueInstall' -Fallback 'Queue Install') -ToolTip (Get-UxLocalizedString -Key 'GuiAppsQueueInstallTip' -Fallback 'Stage installs for every checked app. They run when you click Apply Changes.') -IconSize 14 -Gap 6 -TextFontSize 11
		}
		if ($Script:BtnUninstallSelectedApps)
		{
			Set-GuiButtonIconContent -Button $Script:BtnUninstallSelectedApps -IconName 'Delete' -Text (Get-UxLocalizedString -Key 'GuiAppsQueueUninstall' -Fallback 'Queue Uninstall') -ToolTip (Get-UxLocalizedString -Key 'GuiAppsQueueUninstallTip' -Fallback 'Stage uninstalls for every checked app. They run when you click Apply Changes.') -IconSize 14 -Gap 6 -TextFontSize 11
		}
		if ($Script:BtnUpdateSelectedApps)
		{
			Set-GuiButtonIconContent -Button $Script:BtnUpdateSelectedApps -IconName 'ArrowSync' -Text (Get-UxLocalizedString -Key 'GuiAppsQueueUpdate' -Fallback 'Queue Update') -ToolTip (Get-UxLocalizedString -Key 'GuiAppsQueueUpdateTip' -Fallback 'Stage updates for every checked app. They run when you click Apply Changes.') -IconSize 14 -Gap 6 -TextFontSize 11
		}
		if ($Script:BtnScanInstalledApps)
		{
			Set-GuiButtonIconContent -Button $Script:BtnScanInstalledApps -IconName 'Search' -Text (Get-UxLocalizedString -Key 'GuiAppsScanInstalledApps' -Fallback 'Scan Installed Apps') -ToolTip (Get-UxLocalizedString -Key 'GuiAppsScanInstalledAppsTip' -Fallback 'Scan installed apps to update install status.') -IconSize 14 -Gap 6 -TextFontSize 11
		}
		if ($Script:AppsSourceLabel)
		{
			$Script:AppsSourceLabel.Text = (Get-UxLocalizedString -Key 'GuiAppsSourceLabel' -Fallback 'Source') + ':'
		}
		if (Get-Command -Name 'Update-AppSourceFilterControls' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-AppSourceFilterControls
		}
		if ($Script:AppsViewModeLabel)
		{
			$Script:AppsViewModeLabel.Text = (Get-UxLocalizedString -Key 'GuiAppsViewModeLabel' -Fallback 'View') + ':'
		}
		if ($Script:BtnAppsViewCards)
		{
			$Script:BtnAppsViewCards.ToolTip = (Get-UxLocalizedString -Key 'GuiAppsViewModeCardsTip' -Fallback 'Show apps as a grid of cards.')
		}
		if ($Script:BtnAppsViewList)
		{
			$Script:BtnAppsViewList.ToolTip = (Get-UxLocalizedString -Key 'GuiAppsViewModeListTip' -Fallback 'Show apps in a vertical list.')
		}
		if (Get-Command -Name 'Update-AppsViewModeControls' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-AppsViewModeControls
		}

		# Search area
		if ($Script:SearchLabel)          { $Script:SearchLabel.Text = (Get-UxLocalizedString -Key 'GuiSearchLabel' -Fallback 'Search') }
		if ($Script:TxtSearchPlaceholder) { $Script:TxtSearchPlaceholder.Text = (Get-UxLocalizedString -Key 'GuiSearchPlaceholder' -Fallback 'Search by name, tag, category, or package ID...') }
		if ($TxtLanguageSearch)
		{
			$TxtLanguageSearch.ToolTip = (Get-UxLocalizedString -Key 'GuiLanguageSearchTooltip' -Fallback 'Search available languages')
		}
		if ($TxtLanguageSearchPlaceholder)
		{
			$TxtLanguageSearchPlaceholder.Text = (Get-UxLocalizedString -Key 'GuiLanguageSearchPlaceholder' -Fallback 'Search languages...')
		}
		if ($Script:AppsStatusLabel)
		{
			$Script:AppsStatusLabel.Text = (Get-UxLocalizedString -Key 'GuiAppsStatusFilterLabel' -Fallback 'Installed') + ':'
		}
		if ($Script:CmbAppsStatusFilter)
		{
			$Script:CmbAppsStatusFilter.ToolTip = (Get-UxLocalizedString -Key 'GuiAppsStatusFilterTooltip' -Fallback 'Filter applications by installed or update-available status.')
		}

		# Checkboxes
		if ($ChkTheme) { $ChkTheme.Content = (Get-UxLocalizedString -Key 'GuiChkLightMode' -Fallback 'Light Mode') }
		if ($Script:ChkSelectedOnly)
		{
			$Script:ChkSelectedOnly.Content = (Get-UxLocalizedString -Key 'GuiChkSelectedOnly' -Fallback 'Selected only')
			$Script:ChkSelectedOnly.ToolTip = (Get-UxLocalizedString -Key 'GuiChkSelectedOnlyTip' -Fallback 'Show only tweaks that are currently selected in the GUI.')
		}
		if ($Script:ChkHighRiskOnly)
		{
			$Script:ChkHighRiskOnly.Content = (Get-UxLocalizedString -Key 'GuiChkHighRiskOnly' -Fallback 'High-risk only')
			$Script:ChkHighRiskOnly.ToolTip = (Get-UxLocalizedString -Key 'GuiChkHighRiskOnlyTip' -Fallback 'Show only high-risk tweaks.')
		}
		if ($Script:ChkRestorableOnly)
		{
			$Script:ChkRestorableOnly.Content = (Get-UxLocalizedString -Key 'GuiChkRestorableOnly' -Fallback 'Restorable only')
			$Script:ChkRestorableOnly.ToolTip = (Get-UxLocalizedString -Key 'GuiChkRestorableOnlyTip' -Fallback 'Hide tweaks that require manual recovery.')
		}
		if ($Script:ChkGamingOnly)
		{
			$Script:ChkGamingOnly.Content = (Get-UxLocalizedString -Key 'GuiChkGamingOnly' -Fallback 'Gaming-related')
			$Script:ChkGamingOnly.ToolTip = (Get-UxLocalizedString -Key 'GuiChkGamingOnlyTip' -Fallback 'Show tweaks that relate to gaming performance, compatibility, or gaming quality-of-life.')
		}

		if (Get-Command -Name 'Update-AppsSelectionSummary' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-AppsSelectionSummary
		}
		if (Get-Command -Name 'Update-AppPackageSourcePreferenceControls' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-AppPackageSourcePreferenceControls
		}
		if (Get-Command -Name 'Update-AppSourceFilterControls' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-AppSourceFilterControls
		}

		# Filter labels
		if ($Script:RiskFilterLabel)     { $Script:RiskFilterLabel.Text = (Get-UxLocalizedString -Key 'GuiRiskFilterLabel' -Fallback 'Risk') }
		if ($Script:CategoryFilterLabel) { $Script:CategoryFilterLabel.Text = (Get-UxLocalizedString -Key 'GuiCategoryFilterLabel' -Fallback 'Category') }
		if ($Script:ViewFilterLabel)     { $Script:ViewFilterLabel.Text = (Get-UxLocalizedString -Key 'GuiViewLabel' -Fallback 'View') }

		# Filter toggle button (preserve arrow direction)
		if ($Script:BtnFilterToggle)
		{
			$filtersText = (Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters')
			$arrow = if ($Script:FilterOptionsPanel -and $Script:FilterOptionsPanel.Visibility -eq [System.Windows.Visibility]::Visible) { [char]0x25BE } else { [char]0x25B8 }
			$Script:BtnFilterToggle.Content = $(
				$fc = if ($Script:HasLabeledIconContent) { New-GuiLabeledIconContent -IconName 'Filter' -Text "$filtersText $arrow" -IconSize 14 -Gap 6 -TextFontSize 11 -AllowTextOnlyFallback } else { $null }
				if ($fc) { $fc } else { "$filtersText $arrow" }
			)
		}

		# Apps filter toggle button
		if ($Script:BtnAppsFilterToggle)
		{
			$appsFiltersText = (Get-UxLocalizedString -Key 'GuiBtnAppsFilterToggle' -Fallback 'Filter')
			$appsArrow = if ($Script:AppsFilterOptionsPanel -and $Script:AppsFilterOptionsPanel.Visibility -eq [System.Windows.Visibility]::Visible) { [char]0x25BE } else { [char]0x25B8 }
			$Script:BtnAppsFilterToggle.Content = $(
				$fc = if ($Script:HasLabeledIconContent) { New-GuiLabeledIconContent -IconName 'Filter' -Text "$appsFiltersText $appsArrow" -IconSize 14 -Gap 6 -TextFontSize 11 -AllowTextOnlyFallback } else { $null }
				if ($fc) { $fc } else { "$appsFiltersText $appsArrow" }
			)
		}

		# Bottom bar - skip Run/Preview (handled by Sync-UxActionButtonText with execution guards)
		if ($Script:BtnDefaults -and -not (& $Script:TestGuiRunInProgressScript))
		{
			Set-GuiButtonIconContent -Button $Script:BtnDefaults -IconName 'RestoreDefaults' -Text (Get-UxLocalizedString -Key 'GuiBtnRestoreAllTweaks' -Fallback 'Restore all tweaks to Windows Defaults') -ToolTip (Get-UxLocalizedString -Key 'GuiActionRestoreDefaultsTooltip' -Fallback 'Restore supported settings to Windows defaults.')
		}
		if ($Script:BtnExportSettings)
		{
			$Script:BtnExportSettings.Content = (Get-UxLocalizedString -Key 'GuiFooterExportSettings' -Fallback 'Export Settings')
			$Script:BtnExportSettings.ToolTip = (Get-UxLocalizedString -Key 'GuiActionExportSettingsTooltip' -Fallback 'Export the current GUI selections to a JSON profile.')
		}
		if ($Script:BtnImportSettings)
		{
			$Script:BtnImportSettings.Content = (Get-UxLocalizedString -Key 'GuiFooterImportSettings' -Fallback 'Import Settings')
			$Script:BtnImportSettings.ToolTip = (Get-UxLocalizedString -Key 'GuiActionImportSettingsTooltip' -Fallback 'Import a saved JSON profile and restore the selected GUI state.')
		}
		if ($Script:BtnRestoreSnapshot)
		{
			$Script:BtnRestoreSnapshot.Content = (Get-UxUndoSelectionActionLabel)
			$Script:BtnRestoreSnapshot.ToolTip = (Get-UxLocalizedString -Key 'GuiActionUndoSelectionTooltip' -Fallback 'Restore the last captured UI snapshot before an import or preset change.')
		}
		if ($Script:BtnExportSystemState)
		{
			$Script:BtnExportSystemState.Content = (Get-UxLocalizedString -Key 'GuiFooterExportSystemState' -Fallback 'Export System State')
			$Script:BtnExportSystemState.ToolTip = (Get-UxLocalizedString -Key 'GuiActionExportStateTooltip' -Fallback 'Capture a snapshot of current system settings and save to a JSON file.')
		}
		if ($Script:BtnExportConfigProfile)
		{
			$Script:BtnExportConfigProfile.Content = (Get-UxLocalizedString -Key 'GuiFooterExportConfigProfile' -Fallback 'Export Config Profile')
			$Script:BtnExportConfigProfile.ToolTip = (Get-UxLocalizedString -Key 'GuiActionExportProfileTooltip' -Fallback 'Export current tweak selections as a portable configuration profile.')
		}
		if ($Script:BtnExportFirstLogonCommand)
		{
			$Script:BtnExportFirstLogonCommand.Content = (Get-UxLocalizedString -Key 'GuiFooterExportFirstLogonCommand' -Fallback 'Export First-Logon Command')
			$Script:BtnExportFirstLogonCommand.ToolTip = (Get-UxLocalizedString -Key 'GuiActionExportFirstLogonTooltip' -Fallback 'Export an autounattend FirstLogonCommands XML snippet that runs Baseline with a saved configuration profile.')
		}
		if ($Script:BtnUndoLastRun)
		{
			$Script:BtnUndoLastRun.Content = (Get-UxLocalizedString -Key 'GuiFooterUndoLastRun' -Fallback 'Undo Last Run')
			$Script:BtnUndoLastRun.ToolTip = (Get-UxLocalizedString -Key 'GuiActionUndoLastRunTooltip' -Fallback 'Reverse the changes from your most recent run')
		}
		if ($Script:BtnCheckCompliance)
		{
			$Script:BtnCheckCompliance.Content = (Get-UxLocalizedString -Key 'GuiFooterCheckCompliance' -Fallback 'Check Compliance')
			$Script:BtnCheckCompliance.ToolTip = (Get-UxLocalizedString -Key 'GuiActionComplianceTooltip' -Fallback 'Check current system state against a saved profile or snapshot for compliance drift.')
		}
		if ($Script:BtnAuditLog)
		{
			$Script:BtnAuditLog.Content = (Get-UxLocalizedString -Key 'GuiFooterAuditLog' -Fallback 'Audit Log')
			$Script:BtnAuditLog.ToolTip = (Get-UxLocalizedString -Key 'GuiActionAuditTooltip' -Fallback 'View the audit trail of all Baseline execution runs and compliance checks.')
		}
		if ($Script:TxtUpdateDescription) { $Script:TxtUpdateDescription.Text = (Get-UxLocalizedString -Key 'GuiUpdateDialogDescription' -Fallback 'A new version of Baseline is available from GitHub. Do you want to download and extract it now?') }
		if ($Script:TxtDownloadProgressLabel -and [string]::IsNullOrWhiteSpace([string]$Script:TxtDownloadProgressLabel.Text))
		{
			$Script:TxtDownloadProgressLabel.Text = (Get-UxLocalizedString -Key 'GuiUpdateDialogReady' -Fallback 'Ready to download.')
		}
		if ($Script:BtnDownloadNo) { $Script:BtnDownloadNo.Content = (Get-UxLocalizedString -Key 'GuiBtnCancel' -Fallback 'Cancel') }
		if ($Script:BtnDownloadYes) { $Script:BtnDownloadYes.Content = (Get-UxLocalizedString -Key 'GuiUpdateDialogDownload' -Fallback 'Download Update') }

		# Expert mode banner
		if ($Script:ExpertModeBanner -and $Script:ExpertModeBanner.Child -is [System.Windows.Controls.TextBlock])
		{
			$Script:ExpertModeBanner.Child.Text = (Get-UxLocalizedString -Key 'GuiExpertModeBanner' -Fallback 'EXPERT MODE — all presets and advanced tweaks are available')
		}

		# Update mode/theme state indicators
		Update-HeaderModeStateText

		# Top menu bar labels
		if (Get-Command -Name 'Update-GuiMenuBarLocalization' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-GuiMenuBarLocalization
		}
	}

	#region Themed Dialog
	<#
	    .SYNOPSIS
	    Internal function Show-ThemedDialog.
	#>

	function Show-ThemedDialog
	{
		param(
			[string]$Title,
			[string]$Message,
			[string[]]$Buttons = @('OK'),
			[string]$AccentButton = $null,
			[string]$DestructiveButton = $null
		)

		return (GUICommon\Show-ThemedDialog `
			-Theme $Script:CurrentTheme `
			-ApplyButtonChrome ${function:Set-ButtonChrome} `
			-OwnerWindow $Form `
			-Title $Title `
			-Message $Message `
			-Buttons $Buttons `
			-UseDarkMode ($Script:CurrentThemeName -eq 'Dark') `
			-AccentButton $AccentButton `
			-DestructiveButton $DestructiveButton)
	}

	<#
	    .SYNOPSIS
	    Internal function Set-SearchInputStyle.
	#>

	function Set-SearchInputStyle
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()
		if (-not $TxtSearch) { return }
		$bc = New-SafeBrushConverter -Context 'Set-SearchInputStyle'
		$TxtSearch.Background = $bc.ConvertFromString($(if ($TxtSearch.IsKeyboardFocusWithin) { $Script:CurrentTheme.InputHoverBg } else { $Script:CurrentTheme.SearchBg }))
		$TxtSearch.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextPrimary)
		$TxtSearch.BorderBrush = $bc.ConvertFromString($(if ($TxtSearch.IsKeyboardFocusWithin) { $Script:CurrentTheme.FocusRing } else { $Script:CurrentTheme.SearchBorder }))
		$TxtSearch.BorderThickness = [System.Windows.Thickness]::new($(if ($TxtSearch.IsKeyboardFocusWithin) { 2 } else { 1 }))
		$TxtSearch.CaretBrush = $bc.ConvertFromString($Script:CurrentTheme.AccentBlue)
		if ($SearchLabel)
		{
			$SearchLabel.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextSecondary)
		}
		if ($TxtSearchPlaceholder)
		{
			$TxtSearchPlaceholder.Foreground = $bc.ConvertFromString($Script:CurrentTheme.SearchPlaceholder)
			$TxtSearchPlaceholder.Visibility = if ([string]::IsNullOrWhiteSpace($TxtSearch.Text)) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
		}
		if ($BtnClearSearch)
		{
			$BtnClearSearch.Visibility = if ([string]::IsNullOrWhiteSpace($TxtSearch.Text)) { [System.Windows.Visibility]::Collapsed } else { [System.Windows.Visibility]::Visible }
			Set-ButtonChrome -Button $BtnClearSearch -Variant 'Subtle' -Compact -Muted
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-LanguageSearchInputStyle.
	#>

	function Set-LanguageSearchInputStyle
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()
		if (-not $TxtLanguageSearch) { return }
		$bc = New-SafeBrushConverter -Context 'Set-LanguageSearchInputStyle'
		$TxtLanguageSearch.Background = $bc.ConvertFromString($(if ($TxtLanguageSearch.IsKeyboardFocusWithin) { $Script:CurrentTheme.InputHoverBg } else { $Script:CurrentTheme.SearchBg }))
		$TxtLanguageSearch.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextPrimary)
		$TxtLanguageSearch.BorderBrush = $bc.ConvertFromString($(if ($TxtLanguageSearch.IsKeyboardFocusWithin) { $Script:CurrentTheme.FocusRing } else { $Script:CurrentTheme.SearchBorder }))
		$TxtLanguageSearch.BorderThickness = [System.Windows.Thickness]::new($(if ($TxtLanguageSearch.IsKeyboardFocusWithin) { 2 } else { 1 }))
		$TxtLanguageSearch.CaretBrush = $bc.ConvertFromString($Script:CurrentTheme.AccentBlue)
		if ($TxtLanguageSearchPlaceholder)
		{
			$TxtLanguageSearchPlaceholder.Foreground = $bc.ConvertFromString($Script:CurrentTheme.SearchPlaceholder)
			$TxtLanguageSearchPlaceholder.Visibility = if ([string]::IsNullOrWhiteSpace($TxtLanguageSearch.Text)) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-ChoiceComboStyle.
	#>

	function Set-ChoiceComboStyle
	{
		param ([System.Windows.Controls.ComboBox]$Combo)
		if (-not $Combo) { return }

		$theme = $Script:CurrentTheme
		$bc = New-SafeBrushConverter -Context 'Set-ChoiceComboStyle'

		# Helper to ensure a color is a valid hex string
		$ensureHexColor = {
			param($Color, $Default = '#89B4FA')
			if ([string]::IsNullOrWhiteSpace($Color)) { return $Default }
			if ($Color -match '^#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{4}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$') { return $Color }
			return $Default
		}

		$inputBg       = & $ensureHexColor $theme.InputBg       '#313244'
		$textPrimary   = & $ensureHexColor $theme.TextPrimary   '#CDD6F4'
		$borderBrush   = & $ensureHexColor $theme.SearchBorder  '#585B70'
		$hoverBg       = & $ensureHexColor $theme.CardHoverBg   '#323A4E'
		$activeBg      = & $ensureHexColor $theme.TabActiveBg   '#3670B8'
		$activeBorder  = & $ensureHexColor $theme.ActiveTabBorder '#89B4FA'
		if (-not $Script:ChoiceComboTemplateLoadFailures)
		{
			$Script:ChoiceComboTemplateLoadFailures = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
		}
		$comboTemplateFailedForTheme = $Script:ChoiceComboTemplateLoadFailures.Contains($Script:CurrentThemeName)

		if (
			-not $comboTemplateFailedForTheme -and
			(-not $Script:ChoiceComboTemplate -or $Script:ChoiceComboTemplateTheme -ne $Script:CurrentThemeName)
		)
		{
			$comboTemplateXaml = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                 TargetType="{x:Type ComboBox}">
    <Grid SnapsToDevicePixels="True"
          TextElement.Foreground="{TemplateBinding Foreground}">
        <Border Background="$inputBg"
                BorderBrush="$borderBrush"
                BorderThickness="1"
                CornerRadius="6"
                SnapsToDevicePixels="True" />

        <ContentPresenter x:Name="ContentSite"
                          Margin="{TemplateBinding Padding}"
                          HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                          VerticalAlignment="{TemplateBinding VerticalContentAlignment}"
                          Content="{TemplateBinding SelectionBoxItem}"
                          ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                          ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
                          ContentStringFormat="{TemplateBinding SelectionBoxItemStringFormat}"
                          IsHitTestVisible="False"
                          RecognizesAccessKey="True"
                          SnapsToDevicePixels="{TemplateBinding SnapsToDevicePixels}" />

        <ToggleButton x:Name="ToggleButton"
                      Focusable="False"
                      ClickMode="Press"
                      Background="Transparent"
                      BorderBrush="Transparent"
                      BorderThickness="0"
                      IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}"
                      HorizontalAlignment="Stretch"
                      VerticalAlignment="Stretch">
            <ToggleButton.Template>
                <ControlTemplate TargetType="{x:Type ToggleButton}">
                    <Border Background="Transparent"
                            BorderBrush="Transparent"
                            BorderThickness="0"
                            SnapsToDevicePixels="True" />
                </ControlTemplate>
            </ToggleButton.Template>
        </ToggleButton>

        <Path HorizontalAlignment="Right"
              VerticalAlignment="Center"
              Margin="0,0,10,0"
              Data="M 0 0 L 4 4 L 8 0"
              Stroke="{TemplateBinding Foreground}"
              StrokeThickness="1.6"
              StrokeStartLineCap="Round"
              StrokeEndLineCap="Round"
              Stretch="Fill"
              Width="8"
              Height="4"
              IsHitTestVisible="False" />

        <Popup x:Name="Popup"
               Placement="Bottom"
               AllowsTransparency="True"
               Focusable="False"
               IsOpen="{TemplateBinding IsDropDownOpen}"
               PopupAnimation="Slide"
               PlacementTarget="{Binding RelativeSource={RelativeSource TemplatedParent}}">
            <Border Width="{Binding PlacementTarget.ActualWidth, RelativeSource={RelativeSource AncestorType={x:Type Popup}}}"
                    Background="$inputBg"
                    BorderBrush="$borderBrush"
                    BorderThickness="1"
                    CornerRadius="6"
                    SnapsToDevicePixels="True">
                <ScrollViewer Margin="4,6,4,6"
                              SnapsToDevicePixels="True">
                    <ItemsPresenter KeyboardNavigation.DirectionalNavigation="Contained" />
                </ScrollViewer>
            </Border>
        </Popup>
    </Grid>
</ControlTemplate>
"@
			$comboTemplateReader = $null
			try {
				$comboTemplateReader = New-Object System.Xml.XmlNodeReader ([xml]$comboTemplateXaml)
				$Script:ChoiceComboTemplate = [System.Windows.Markup.XamlReader]::Load($comboTemplateReader)
				$Script:ChoiceComboTemplateTheme = $Script:CurrentThemeName
			}
			catch {
				$Script:ChoiceComboTemplate = $null
				$Script:ChoiceComboTemplateTheme = $null
				[void]$Script:ChoiceComboTemplateLoadFailures.Add($Script:CurrentThemeName)
				Write-GuiRuntimeWarning -Context 'Set-ChoiceComboStyle' -Message ("Failed to load combo box template for theme '{0}': {1}" -f $Script:CurrentThemeName, $_.Exception.Message)
			}
			finally {
				if ($comboTemplateReader)
				{
					try { $comboTemplateReader.Dispose() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'StyleManagement.Set-ChoiceComboStyle.TemplateReaderDispose' }
				}
			}
		}

		# Apply the template and styles (with error swallowing)
		try {
			$Combo.Resources[[System.Windows.SystemColors]::WindowBrushKey] = $bc.ConvertFromString($inputBg)
			$Combo.Resources[[System.Windows.SystemColors]::WindowTextBrushKey] = $bc.ConvertFromString($textPrimary)
			$Combo.Resources[[System.Windows.SystemColors]::ControlBrushKey] = $bc.ConvertFromString($inputBg)
			$Combo.Resources[[System.Windows.SystemColors]::ControlTextBrushKey] = $bc.ConvertFromString($textPrimary)
			$Combo.Resources[[System.Windows.SystemColors]::HighlightBrushKey] = $bc.ConvertFromString($activeBg)
			$Combo.Resources[[System.Windows.SystemColors]::HighlightTextBrushKey] = $bc.ConvertFromString($textPrimary)
			$Combo.Resources[[System.Windows.SystemColors]::MenuBrushKey] = $bc.ConvertFromString($inputBg)
			$Combo.Resources[[System.Windows.SystemColors]::MenuTextBrushKey] = $bc.ConvertFromString($textPrimary)

			$itemStyle = New-Object System.Windows.Style([System.Windows.Controls.ComboBoxItem])
			[void]($itemStyle.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Control]::BackgroundProperty) -Value ($bc.ConvertFromString($inputBg)))))
			[void]($itemStyle.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Control]::ForegroundProperty) -Value ($bc.ConvertFromString($textPrimary)))))
			[void]($itemStyle.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Control]::BorderBrushProperty) -Value ($bc.ConvertFromString($borderBrush)))))
			[void]($itemStyle.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Control]::BorderThicknessProperty) -Value ([System.Windows.Thickness]::new(0)))))
			[void]($itemStyle.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Control]::PaddingProperty) -Value ([System.Windows.Thickness]::new(10, 4, 10, 4)))))
			[void]($itemStyle.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Control]::HorizontalContentAlignmentProperty) -Value ([System.Windows.HorizontalAlignment]::Stretch))))
			$hoverTrigger = New-Object System.Windows.Trigger
			$hoverTrigger.Property = [System.Windows.Controls.ComboBoxItem]::IsMouseOverProperty
			$hoverTrigger.Value = $true
			[void]($hoverTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Control]::BackgroundProperty) -Value ($bc.ConvertFromString($hoverBg)))))
			[void]($hoverTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Control]::BorderBrushProperty) -Value ($bc.ConvertFromString($activeBorder)))))
			[void]($itemStyle.Triggers.Add($hoverTrigger))
			$selectedTrigger = New-Object System.Windows.Trigger
			$selectedTrigger.Property = [System.Windows.Controls.ComboBoxItem]::IsSelectedProperty
			$selectedTrigger.Value = $true
			[void]($selectedTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Control]::BackgroundProperty) -Value ($bc.ConvertFromString($activeBg)))))
			[void]($selectedTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Control]::ForegroundProperty) -Value ($bc.ConvertFromString($textPrimary)))))
			[void]($selectedTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Control]::BorderBrushProperty) -Value ($bc.ConvertFromString($activeBorder)))))
			[void]($selectedTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Control]::BorderThicknessProperty) -Value ([System.Windows.Thickness]::new(1.5, 0, 0, 0)))))
			[void]($itemStyle.Triggers.Add($selectedTrigger))
			$Combo.ItemContainerStyle = $itemStyle
			$Combo.Background = $bc.ConvertFromString($inputBg)
			$Combo.Foreground = $bc.ConvertFromString($textPrimary)
			$Combo.SetValue([System.Windows.Documents.TextElement]::ForegroundProperty, $bc.ConvertFromString($textPrimary))
			$Combo.BorderBrush = $bc.ConvertFromString($borderBrush)
			$Combo.BorderThickness = [System.Windows.Thickness]::new(1)
			if ($Script:ChoiceComboTemplate -and $Script:ChoiceComboTemplateTheme -eq $Script:CurrentThemeName)
			{
				$Combo.OverridesDefaultStyle = $true
				$Combo.Template = $Script:ChoiceComboTemplate
			}
			else
			{
				$Combo.OverridesDefaultStyle = $false
				$Combo.ClearValue([System.Windows.Controls.Control]::TemplateProperty)
			}
			$Combo.Padding = [System.Windows.Thickness]::new(10, 4, 10, 4)
			$Combo.MinWidth = 190
			$Combo.Height = 30
		}
		catch {
			# Silently ignore any remaining errors - the combo will still work
			return
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-FilterControlStyle.
	#>

	function Set-FilterControlStyle
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()
		$bc = New-SafeBrushConverter -Context 'Set-FilterControlStyle'
		$sharedFilterLabelFontSize = 12
		$sharedFilterLabelFontWeight = [System.Windows.FontWeights]::SemiBold
		if ($RiskFilterLabel) { $RiskFilterLabel.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextSecondary) }
		if ($CategoryFilterLabel) { $CategoryFilterLabel.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextSecondary) }
		if ($Script:AppsStatusLabel)
		{
			$Script:AppsStatusLabel.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextPrimary)
			$Script:AppsStatusLabel.FontSize = $sharedFilterLabelFontSize
			$Script:AppsStatusLabel.FontWeight = $sharedFilterLabelFontWeight
		}
		if ($Script:AppsSourceLabel)
		{
			$Script:AppsSourceLabel.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextPrimary)
			$Script:AppsSourceLabel.FontSize = $sharedFilterLabelFontSize
			$Script:AppsSourceLabel.FontWeight = $sharedFilterLabelFontWeight
		}
		if ($Script:AppsViewModeLabel)
		{
			$Script:AppsViewModeLabel.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextPrimary)
			$Script:AppsViewModeLabel.FontSize = $sharedFilterLabelFontSize
			$Script:AppsViewModeLabel.FontWeight = $sharedFilterLabelFontWeight
		}
		if ($Script:AppsFilterViewDivider) { $Script:AppsFilterViewDivider.Background = $bc.ConvertFromString($Script:CurrentTheme.BorderColor) }
		if ($Script:AppsActionSeparator1) { $Script:AppsActionSeparator1.Background = $bc.ConvertFromString($Script:CurrentTheme.BorderColor) }
		if ($ChkSelectedOnly) { $ChkSelectedOnly.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextSecondary) }
		if ($ChkHighRiskOnly) { $ChkHighRiskOnly.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextSecondary) }
		if ($ChkRestorableOnly) { $ChkRestorableOnly.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextSecondary) }
		if ($ChkGamingOnly) { $ChkGamingOnly.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextSecondary) }
		if ($ChkSafeMode) { $ChkSafeMode.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextSecondary) }
		if ($ChkGameMode) { $ChkGameMode.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextSecondary) }
		if ($BtnFilterToggle) { $BtnFilterToggle.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextSecondary) }
		if ($Script:BtnAppsFilterToggle) { $Script:BtnAppsFilterToggle.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextSecondary) }
		if ($CmbRiskFilter) { Set-ChoiceComboStyle -Combo $CmbRiskFilter }
		if ($CmbCategoryFilter) { Set-ChoiceComboStyle -Combo $CmbCategoryFilter }
		if ($CmbAppsStatusFilter) { Set-ChoiceComboStyle -Combo $CmbAppsStatusFilter }
		if ($TxtLanguageState) { $TxtLanguageState.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextSecondary) }
		if ($LanguagePopupBorder)
		{
			$LanguagePopupBorder.Background = $bc.ConvertFromString($Script:CurrentTheme.InputBg)
			$LanguagePopupBorder.BorderBrush = $bc.ConvertFromString($Script:CurrentTheme.SearchBorder)
		}
		if ($TxtLanguageSearch) { Set-LanguageSearchInputStyle }
		if ($LanguageListPanel)
		{
			foreach ($child in $LanguageListPanel.Children)
			{
				if ($child -is [System.Windows.Controls.Button])
				{
					$child.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextPrimary)
				}
				elseif ($child -is [System.Windows.Controls.TextBlock])
				{
					$child.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextSecondary)
				}
			}
		}
		if ($PrimaryTabDropdown) { Set-ChoiceComboStyle -Combo $PrimaryTabDropdown }
	}

	<#
	    .SYNOPSIS
	    Internal function Set-SearchControlsEnabled.
	#>

	function Set-SearchControlsEnabled
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ([bool]$Enabled)
		if ($Script:TxtSearch) { $Script:TxtSearch.IsEnabled = $Enabled }
		if ($Script:BtnClearSearch) { $Script:BtnClearSearch.IsEnabled = $Enabled }
		if ($CmbRiskFilter) { $CmbRiskFilter.IsEnabled = $Enabled }
		if ($CmbCategoryFilter) { $CmbCategoryFilter.IsEnabled = $Enabled }
		if ($ChkSelectedOnly) { $ChkSelectedOnly.IsEnabled = $Enabled }
		if ($ChkHighRiskOnly) { $ChkHighRiskOnly.IsEnabled = $Enabled }
		if ($ChkRestorableOnly) { $ChkRestorableOnly.IsEnabled = $Enabled }
		if ($ChkGamingOnly) { $ChkGamingOnly.IsEnabled = $Enabled }
		if ($ChkSafeMode) { $ChkSafeMode.IsEnabled = $Enabled }
		if ($ChkGameMode) { $ChkGameMode.IsEnabled = $Enabled }
		Set-SearchInputStyle
	}

	<#
	    .SYNOPSIS
	    Internal function Set-GuiActionButtonsEnabled.
	#>

	function Set-GuiActionButtonsEnabled
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ([bool]$Enabled)
		$isRemoteConnected = $false
		$remoteTargetContext = $null
		if (Get-Command -Name 'Test-GuiRemoteTargetConnected' -CommandType Function -ErrorAction SilentlyContinue)
		{
			try { $isRemoteConnected = [bool](Test-GuiRemoteTargetConnected) } catch { $isRemoteConnected = $false }
		}
		if (Get-Command -Name 'Get-GuiRemoteTargetContext' -CommandType Function -ErrorAction SilentlyContinue)
		{
			try { $remoteTargetContext = Get-GuiRemoteTargetContext } catch { $remoteTargetContext = $null }
		}
		$isRemoteApprovalReady = $false
		if ($isRemoteConnected -and (Get-Command -Name 'Test-GuiRemoteTargetApproval' -CommandType Function -ErrorAction SilentlyContinue) -and $remoteTargetContext)
		{
			try { $isRemoteApprovalReady = [bool](Test-GuiRemoteTargetApproval -ComputerName @($remoteTargetContext.TargetComputers)) } catch { $isRemoteApprovalReady = $false }
		}
		if ($Script:BtnDefaults) { $Script:BtnDefaults.IsEnabled = $Enabled }
		if ($Script:BtnExportSettings) { $Script:BtnExportSettings.IsEnabled = $Enabled }
		if ($Script:BtnImportSettings) { $Script:BtnImportSettings.IsEnabled = $Enabled }
		if ($Script:BtnRestoreSnapshot) { $Script:BtnRestoreSnapshot.IsEnabled = ($Enabled -and $null -ne $Script:UiSnapshotUndo) }
		if ($Script:BtnExportSystemState) { $Script:BtnExportSystemState.IsEnabled = $Enabled }
		if ($Script:BtnExportConfigProfile) { $Script:BtnExportConfigProfile.IsEnabled = $Enabled }
		if ($Script:BtnExportFirstLogonCommand) { $Script:BtnExportFirstLogonCommand.IsEnabled = $Enabled }
		if ($Script:MenuFileAuditSettings) { $Script:MenuFileAuditSettings.IsEnabled = $Enabled }
		if ($Script:MenuToolsExportSupportBundle) { $Script:MenuToolsExportSupportBundle.IsEnabled = $Enabled }
		if ($Script:MenuToolsApproveRemoteTargets) { $Script:MenuToolsApproveRemoteTargets.IsEnabled = ($Enabled -and $isRemoteConnected) }
		if ($Script:MenuToolsSaveRemoteApprovalPolicy) { $Script:MenuToolsSaveRemoteApprovalPolicy.IsEnabled = ($Enabled -and $isRemoteConnected -and $isRemoteApprovalReady) }
		if ($Script:MenuToolsLoadRemoteApprovalPolicy) { $Script:MenuToolsLoadRemoteApprovalPolicy.IsEnabled = ($Enabled -and $isRemoteConnected) }
		if ($Script:MenuToolsRemoteConsole) { $Script:MenuToolsRemoteConsole.IsEnabled = $Enabled }
		if ($Script:MenuToolsRemoteSessionStatus) { $Script:MenuToolsRemoteSessionStatus.IsEnabled = $Enabled }
		if ($Script:MenuHelpReleaseStatus) { $Script:MenuHelpReleaseStatus.IsEnabled = $Enabled }
		if ($Script:MenuHelpTroubleshooting) { $Script:MenuHelpTroubleshooting.IsEnabled = $Enabled }
		if ($Script:BtnUndoLastRun) { $Script:BtnUndoLastRun.IsEnabled = $Enabled }
		if ($Script:BtnCheckCompliance) { $Script:BtnCheckCompliance.IsEnabled = $Enabled }
		if ($Script:BtnAuditLog) { $Script:BtnAuditLog.IsEnabled = $Enabled }
		if ($Script:MenuActionsConnectToComputer) { $Script:MenuActionsConnectToComputer.IsEnabled = $Enabled }
		if ($Script:MenuActionsDisconnect) { $Script:MenuActionsDisconnect.IsEnabled = ($Enabled -and $isRemoteConnected) }
	}
