# Dialog helper split file loaded by Module\GUI\DialogHelpers.ps1.

<#
	    .SYNOPSIS
	    Internal function Get-BaselineScrollBarStyleXaml.
	#>

	function Get-BaselineScrollBarStyleXaml
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[Parameter(Mandatory)]
			[hashtable]$Theme
		)

		$track  = if ($Theme.ScrollBg)          { $Theme.ScrollBg }          else { '#1E1E2E' }
		$thumb  = if ($Theme.ScrollThumb)       { $Theme.ScrollThumb }       else { '#4A4D5E' }
		$hover  = if ($Theme.ScrollThumbHover)  { $Theme.ScrollThumbHover }  else { $thumb }
		$active = if ($Theme.ScrollThumbActive) { $Theme.ScrollThumbActive } else { $thumb }

		return @"
<Style x:Key="BaselineDialogScrollThumbStyle" TargetType="Thumb">
	<Setter Property="OverridesDefaultStyle" Value="True"/>
	<Setter Property="IsTabStop" Value="False"/>
	<Setter Property="Focusable" Value="False"/>
	<Setter Property="Template">
		<Setter.Value>
			<ControlTemplate TargetType="Thumb">
				<Border x:Name="ThumbBorder" Background="$thumb" CornerRadius="4" Margin="2" Opacity="0.55"/>
				<ControlTemplate.Triggers>
					<Trigger Property="IsMouseOver" Value="True">
						<Setter TargetName="ThumbBorder" Property="Background" Value="$hover"/>
						<Setter TargetName="ThumbBorder" Property="Opacity" Value="0.85"/>
					</Trigger>
					<Trigger Property="IsDragging" Value="True">
						<Setter TargetName="ThumbBorder" Property="Background" Value="$active"/>
						<Setter TargetName="ThumbBorder" Property="Opacity" Value="1.0"/>
					</Trigger>
				</ControlTemplate.Triggers>
			</ControlTemplate>
		</Setter.Value>
	</Setter>
</Style>
<Style x:Key="BaselineDialogScrollRepeatButtonStyle" TargetType="RepeatButton">
	<Setter Property="OverridesDefaultStyle" Value="True"/>
	<Setter Property="Background" Value="Transparent"/>
	<Setter Property="IsTabStop" Value="False"/>
	<Setter Property="Focusable" Value="False"/>
	<Setter Property="Template">
		<Setter.Value>
			<ControlTemplate TargetType="RepeatButton">
				<Border Background="Transparent"/>
			</ControlTemplate>
		</Setter.Value>
	</Setter>
</Style>
<Style TargetType="ScrollBar">
	<Setter Property="Background" Value="$track"/>
	<Setter Property="BorderThickness" Value="0"/>
	<Setter Property="SnapsToDevicePixels" Value="True"/>
	<Style.Triggers>
		<Trigger Property="Orientation" Value="Vertical">
			<Setter Property="Width" Value="8"/>
			<Setter Property="MinWidth" Value="8"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="ScrollBar">
						<Grid Background="Transparent">
							<Border Background="{TemplateBinding Background}" Opacity="0.30" CornerRadius="4"/>
							<Track Name="PART_Track" IsDirectionReversed="True">
								<Track.DecreaseRepeatButton>
									<RepeatButton Style="{StaticResource BaselineDialogScrollRepeatButtonStyle}" Command="ScrollBar.PageUpCommand"/>
								</Track.DecreaseRepeatButton>
								<Track.Thumb>
									<Thumb Style="{StaticResource BaselineDialogScrollThumbStyle}" MinHeight="30"/>
								</Track.Thumb>
								<Track.IncreaseRepeatButton>
									<RepeatButton Style="{StaticResource BaselineDialogScrollRepeatButtonStyle}" Command="ScrollBar.PageDownCommand"/>
								</Track.IncreaseRepeatButton>
							</Track>
						</Grid>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
		</Trigger>
		<Trigger Property="Orientation" Value="Horizontal">
			<Setter Property="Height" Value="8"/>
			<Setter Property="MinHeight" Value="8"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="ScrollBar">
						<Grid Background="Transparent">
							<Border Background="{TemplateBinding Background}" Opacity="0.30" CornerRadius="4"/>
							<Track Name="PART_Track" IsDirectionReversed="False">
								<Track.DecreaseRepeatButton>
									<RepeatButton Style="{StaticResource BaselineDialogScrollRepeatButtonStyle}" Command="ScrollBar.PageLeftCommand"/>
								</Track.DecreaseRepeatButton>
								<Track.Thumb>
									<Thumb Style="{StaticResource BaselineDialogScrollThumbStyle}" MinWidth="30"/>
								</Track.Thumb>
								<Track.IncreaseRepeatButton>
									<RepeatButton Style="{StaticResource BaselineDialogScrollRepeatButtonStyle}" Command="ScrollBar.PageRightCommand"/>
								</Track.IncreaseRepeatButton>
							</Track>
						</Grid>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
		</Trigger>
	</Style.Triggers>
</Style>
"@
	}

	<#
	    .SYNOPSIS
	    Internal function Set-BaselineReadmeInlineTheme.
	#>

	function Set-BaselineReadmeInlineTheme
	{
		param(
			[object]$Inline,
			[System.Windows.Media.Brush]$TextPrimaryBrush,
			[System.Windows.Media.Brush]$CodeBackgroundBrush,
			[System.Windows.Media.Brush]$CodeForegroundBrush,
			[System.Windows.Media.FontFamily]$MonoFont,
			[bool]$WithinCodeBlock = $false
		)

		if (-not $Inline) { return }

		$isCodeInline = (-not $WithinCodeBlock) -and $Inline.PSObject.Properties['Background'] -and ($null -ne $Inline.Background)
		if ($WithinCodeBlock -or $isCodeInline)
		{
			if ($Inline.PSObject.Properties['Background'])
			{
				$Inline.Background = if ($WithinCodeBlock) { [System.Windows.Media.Brushes]::Transparent } else { $CodeBackgroundBrush }
			}
			if ($Inline.PSObject.Properties['Foreground'])
			{
				$Inline.Foreground = $CodeForegroundBrush
			}
			if ($Inline.PSObject.Properties['FontFamily'])
			{
				$Inline.FontFamily = $MonoFont
			}
		}
		elseif ($Inline.PSObject.Properties['Foreground'])
		{
			$Inline.Foreground = $TextPrimaryBrush
		}

		if ($Inline.PSObject.Properties['Inlines'] -and $Inline.Inlines)
		{
			foreach ($childInline in @($Inline.Inlines))
			{
				Set-BaselineReadmeInlineTheme `
					-Inline $childInline `
					-TextPrimaryBrush $TextPrimaryBrush `
					-CodeBackgroundBrush $CodeBackgroundBrush `
					-CodeForegroundBrush $CodeForegroundBrush `
					-MonoFont $MonoFont `
					-WithinCodeBlock:$WithinCodeBlock
			}
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-BaselineReadmeBlockTheme.
	#>

	function Set-BaselineReadmeBlockTheme
	{
		param(
			[object]$Block,
			[System.Windows.Media.Brush]$TextPrimaryBrush,
			[System.Windows.Media.Brush]$CodeBackgroundBrush,
			[System.Windows.Media.Brush]$CodeForegroundBrush,
			[System.Windows.Media.Brush]$BorderBrush,
			[System.Windows.Media.FontFamily]$MonoFont
		)

		if (-not $Block) { return }

		$isCodeBlock = ($Block -is [System.Windows.Documents.Paragraph]) -and $Block.PSObject.Properties['Background'] -and ($null -ne $Block.Background)
		if ($isCodeBlock)
		{
			$Block.Background = $CodeBackgroundBrush
			$Block.Foreground = $CodeForegroundBrush
			$Block.FontFamily = $MonoFont
			if ($Block.PSObject.Properties['BorderBrush']) { $Block.BorderBrush = $BorderBrush }
			if ($Block.PSObject.Properties['BorderThickness']) { $Block.BorderThickness = [System.Windows.Thickness]::new(1) }
			if ($Block.PSObject.Properties['Padding']) { $Block.Padding = [System.Windows.Thickness]::new(8) }
		}
		elseif ($Block.PSObject.Properties['Foreground'])
		{
			$Block.Foreground = $TextPrimaryBrush
		}

		if ($Block -is [System.Windows.Documents.Paragraph])
		{
			foreach ($inline in @($Block.Inlines))
			{
				Set-BaselineReadmeInlineTheme `
					-Inline $inline `
					-TextPrimaryBrush $TextPrimaryBrush `
					-CodeBackgroundBrush $CodeBackgroundBrush `
					-CodeForegroundBrush $CodeForegroundBrush `
					-MonoFont $MonoFont `
					-WithinCodeBlock:$isCodeBlock
			}
		}

		if ($Block.PSObject.Properties['Blocks'] -and $Block.Blocks)
		{
			foreach ($childBlock in @($Block.Blocks))
			{
				Set-BaselineReadmeBlockTheme `
					-Block $childBlock `
					-TextPrimaryBrush $TextPrimaryBrush `
					-CodeBackgroundBrush $CodeBackgroundBrush `
					-CodeForegroundBrush $CodeForegroundBrush `
					-BorderBrush $BorderBrush `
					-MonoFont $MonoFont
			}
		}

		if ($Block -is [System.Windows.Documents.List])
		{
			foreach ($listItem in @($Block.ListItems))
			{
				foreach ($childBlock in @($listItem.Blocks))
				{
					Set-BaselineReadmeBlockTheme `
						-Block $childBlock `
						-TextPrimaryBrush $TextPrimaryBrush `
						-CodeBackgroundBrush $CodeBackgroundBrush `
						-CodeForegroundBrush $CodeForegroundBrush `
						-BorderBrush $BorderBrush `
						-MonoFont $MonoFont
				}
			}
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-BaselineReadmeFlowDocumentTheme.
	#>

	function Set-BaselineReadmeFlowDocumentTheme
	{
		param(
			[System.Windows.Documents.FlowDocument]$Document,
			[hashtable]$ActiveTheme,
			[object]$BrushConverter,
			[double]$ReadmeFontSize
		)

		if (-not $Document -or -not $ActiveTheme -or -not $BrushConverter) { return }

		# Markdig.Wpf resolves its code styles during ToFlowDocument(), so changing
		# resource keys after the document is created is too late. Force the final
		# theme onto the rendered document directly so inline code and fenced blocks
		# stay readable on both refresh and theme changes.
		$textPrimaryBrush = $BrushConverter.ConvertFromString($ActiveTheme.TextPrimary)
		$codeBackgroundBrush = $BrushConverter.ConvertFromString($ActiveTheme.HeaderBg)
		$codeForegroundBrush = $BrushConverter.ConvertFromString($ActiveTheme.TextPrimary)
		$borderBrush = $BrushConverter.ConvertFromString($ActiveTheme.BorderColor)
		$monoFont = [System.Windows.Media.FontFamily]::new('Consolas, Courier New')
		$uiFont = [System.Windows.Media.FontFamily]::new('Segoe UI')

		$Document.Background = [System.Windows.Media.Brushes]::Transparent
		$Document.Foreground = $textPrimaryBrush
		$Document.PagePadding = [System.Windows.Thickness]::new(0)
		$Document.FontFamily = $uiFont
		$Document.FontSize = [double]$ReadmeFontSize

		foreach ($topLevelBlock in @($Document.Blocks))
		{
			Set-BaselineReadmeBlockTheme `
				-Block $topLevelBlock `
				-TextPrimaryBrush $textPrimaryBrush `
				-CodeBackgroundBrush $codeBackgroundBrush `
				-CodeForegroundBrush $codeForegroundBrush `
				-BorderBrush $borderBrush `
				-MonoFont $monoFont
		}
	}

