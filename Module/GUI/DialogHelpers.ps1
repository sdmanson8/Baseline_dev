# ──────────────────────────────────────────────────────────────────
# DialogHelpers.ps1
# Shared dialog builders and dialog-scoped UI helpers extracted from
# Show-TweakGUI (GUI.psm1). Dot-sourced inside Show-TweakGUI so all
# $Script: and local UI variables remain in scope.
# Planned decomposition path: extract log-viewer, risk/help dialogs,
# and reusable XAML/style builders into focused peer files as they
# stabilize behind their current helper boundaries.
# ──────────────────────────────────────────────────────────────────
#
# Dialog helper functions: risk decision, help, and log viewer dialogs

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
	    Internal function Resolve-BaselineChangelogPath.
	#>

	function Resolve-BaselineChangelogPath
	{
		$candidates = [System.Collections.Generic.List[string]]::new()

		$launcherPath = [string]([System.Environment]::GetEnvironmentVariable('BASELINE_LAUNCHER_PATH'))
		if (-not [string]::IsNullOrWhiteSpace($launcherPath))
		{
			try
			{
				[void]$candidates.Add((Join-Path -Path (Split-Path -Path $launcherPath -Parent) -ChildPath 'CHANGELOG.md'))
			}
			catch { }
		}

		try
		{
			$appBaseDirectory = [System.AppContext]::BaseDirectory
			if (-not [string]::IsNullOrWhiteSpace([string]$appBaseDirectory))
			{
				[void]$candidates.Add((Join-Path -Path $appBaseDirectory -ChildPath 'CHANGELOG.md'))
			}
		}
		catch { }

		if (-not [string]::IsNullOrWhiteSpace([string]$Script:GuiModuleBasePath))
		{
			try
			{
				[void]$candidates.Add((Join-Path -Path (Split-Path -Path $Script:GuiModuleBasePath -Parent) -ChildPath 'CHANGELOG.md'))
			}
			catch { }
		}

		if (-not [string]::IsNullOrWhiteSpace([string]$PSScriptRoot))
		{
			try
			{
				$dialogHelpersRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
				if (-not [string]::IsNullOrWhiteSpace([string]$dialogHelpersRoot))
				{
					[void]$candidates.Add((Join-Path -Path $dialogHelpersRoot -ChildPath 'CHANGELOG.md'))
				}
			}
			catch { }
		}

		try
		{
			$currentDirectory = (Get-Location).Path
			if (-not [string]::IsNullOrWhiteSpace([string]$currentDirectory))
			{
				[void]$candidates.Add((Join-Path -Path $currentDirectory -ChildPath 'CHANGELOG.md'))
			}
		}
		catch { }

		foreach ($candidate in @($candidates | Select-Object -Unique))
		{
			if ([string]::IsNullOrWhiteSpace([string]$candidate))
			{
				continue
			}

			try
			{
				if (Test-Path -LiteralPath $candidate -PathType Leaf)
				{
					return [System.IO.Path]::GetFullPath($candidate)
				}
			}
			catch { }
		}

		return ($candidates | Select-Object -First 1)
	}

	<#
	    .SYNOPSIS
	    Internal function Resolve-BaselineReadmePath.
	#>

	function Resolve-BaselineReadmePath
	{
		$candidates = [System.Collections.Generic.List[string]]::new()

		$launcherPath = [string]([System.Environment]::GetEnvironmentVariable('BASELINE_LAUNCHER_PATH'))
		if (-not [string]::IsNullOrWhiteSpace($launcherPath))
		{
			try
			{
				[void]$candidates.Add((Join-Path -Path (Split-Path -Path $launcherPath -Parent) -ChildPath 'README.md'))
			}
			catch { }
		}

		try
		{
			$appBaseDirectory = [System.AppContext]::BaseDirectory
			if (-not [string]::IsNullOrWhiteSpace([string]$appBaseDirectory))
			{
				[void]$candidates.Add((Join-Path -Path $appBaseDirectory -ChildPath 'README.md'))
			}
		}
		catch { }

		if (-not [string]::IsNullOrWhiteSpace([string]$Script:GuiModuleBasePath))
		{
			try
			{
				[void]$candidates.Add((Join-Path -Path (Split-Path -Path $Script:GuiModuleBasePath -Parent) -ChildPath 'README.md'))
			}
			catch { }
		}

		if (-not [string]::IsNullOrWhiteSpace([string]$PSScriptRoot))
		{
			try
			{
				$dialogHelpersRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
				if (-not [string]::IsNullOrWhiteSpace([string]$dialogHelpersRoot))
				{
					[void]$candidates.Add((Join-Path -Path $dialogHelpersRoot -ChildPath 'README.md'))
				}
			}
			catch { }
		}

		try
		{
			$currentDirectory = (Get-Location).Path
			if (-not [string]::IsNullOrWhiteSpace([string]$currentDirectory))
			{
				[void]$candidates.Add((Join-Path -Path $currentDirectory -ChildPath 'README.md'))
			}
		}
		catch { }

		foreach ($candidate in @($candidates | Select-Object -Unique))
		{
			if ([string]::IsNullOrWhiteSpace([string]$candidate))
			{
				continue
			}

			try
			{
				if (Test-Path -LiteralPath $candidate -PathType Leaf)
				{
					return [System.IO.Path]::GetFullPath($candidate)
				}
			}
			catch { }
		}

		return ($candidates | Select-Object -First 1)
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

	<#
	    .SYNOPSIS
	    Internal function Show-RiskDecisionDialog.
	#>

	function Show-RiskDecisionDialog
	{
		param(
			[string]$Title = 'Warning',
			[string]$Message,
			[object[]]$SummaryCards = @(),
			[string[]]$Buttons = @('Cancel', 'Continue Anyway'),
			[string]$AccentButton = $null,
			[string]$DestructiveButton = $null
		)

		return (GUICommon\Show-RiskDecisionDialog `
			-Theme $Script:CurrentTheme `
			-ApplyButtonChrome ${function:Set-ButtonChrome} `
			-OwnerWindow $Form `
			-Title $Title `
			-Message $Message `
			-SummaryCards $SummaryCards `
			-Buttons $Buttons `
			-UseDarkMode ($Script:CurrentThemeName -eq 'Dark') `
			-AccentButton $AccentButton `
			-DestructiveButton $DestructiveButton)
	}

	<#
	    .SYNOPSIS
	    Internal function Show-GuiSettingsImportDialog.
	#>

	function Show-GuiSettingsImportDialog
	{
		param (
			[string]$AppName = 'Baseline'
		)

		$theme = $Script:CurrentTheme
		if (-not $theme)
		{
			return $null
		}

		$bc = New-SafeBrushConverter -Context 'DialogHelpers-ImportSettings'
		$windowTitle = Get-UxLocalizedString -Key 'GuiImportSettings' -Fallback 'Import Settings'
		$windowSubtitle = Get-UxLocalizedString -Key 'GuiImportSettingsSubtitle' -Fallback 'Choose where to load Baseline settings from.'
		$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'

		[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$windowTitle"
	Width="820" Height="560"
	MinWidth="680" MinHeight="480"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="FluentSystemIcons"
	FontSize="12"
	Background="Transparent"
	WindowStyle="None"
	AllowsTransparency="True">
	<Border Name="RootBorder" CornerRadius="8">
		<Grid>
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="*"/>
				<RowDefinition Height="Auto"/>
			</Grid.RowDefinitions>

			<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="12,8,8,8" Cursor="Arrow">
				<Grid>
					<TextBlock Text="$windowTitle" VerticalAlignment="Center" FontSize="12" Foreground="$($theme.TextPrimary)"/>
					<Button Name="BtnDlgClose" Content="x" FontFamily="Arial" FontSize="12" Width="32" Height="28"
						Background="Transparent" Foreground="$($theme.TextPrimary)" BorderThickness="0" Cursor="Hand"
						HorizontalAlignment="Right" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
				</Grid>
			</Border>

			<Border Grid.Row="1" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,0,0,1"
					Padding="20,14,20,14">
				<StackPanel>
					<TextBlock Name="TxtDialogTitle" Text="$windowTitle" FontSize="16" FontWeight="SemiBold"
							   Foreground="$($theme.TextPrimary)"/>
					<TextBlock Name="TxtDialogSubtitle" Text="$windowSubtitle"
							   FontSize="12" Foreground="$($theme.TextMuted)" Margin="0,2,0,0" TextWrapping="Wrap"/>
				</StackPanel>
			</Border>

			<ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="20,18,20,18">
				<WrapPanel Name="CardPanel" HorizontalAlignment="Stretch"/>
			</ScrollViewer>

			<Border Grid.Row="3" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0"
					Padding="20,10,20,10">
				<Grid>
					<Button Name="BtnCancel" Content="" HorizontalAlignment="Right" Padding="20,6" FontSize="13"/>
				</Grid>
			</Border>
		</Grid>
	</Border>
</Window>
"@

		$reader = [System.Xml.XmlNodeReader]::new($xaml)
		$dlg = [Windows.Markup.XamlReader]::Load($reader)
		$dlg.Owner = $Form

		$rootBorder = $dlg.FindName('RootBorder')
		if ($rootBorder)
		{
			$rootBorder.Background = $bc.ConvertFromString($theme.WindowBg)
			$rootBorder.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
			$rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
		}

		[void](GUICommon\Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))

		$dlgTitleBar = $dlg.FindName('DlgTitleBar')
		$btnDlgClose = $dlg.FindName('BtnDlgClose')
		$cardPanel = $dlg.FindName('CardPanel')
		$btnCancel = $dlg.FindName('BtnCancel')
		$resultRef = @{ Value = $null }

		if ($dlgTitleBar)
		{
			$dlgTitleBar.Add_MouseLeftButtonDown({ $dlg.DragMove() }.GetNewClosure())
			$dlgCtx = New-Object System.Windows.Controls.ContextMenu
			$dlgCtxClose = New-Object System.Windows.Controls.MenuItem
			$dlgCtxClose.Header = $closeLabel
			$dlgCtxClose.InputGestureText = 'Alt+F4'
			$dlgCtxClose.FontWeight = [System.Windows.FontWeights]::Bold
			$dlgRefForContext = $dlg
			$dlgCtxClose.Add_Click({ $dlgRefForContext.Close() }.GetNewClosure())
			[void]$dlgCtx.Items.Add($dlgCtxClose)
			$dlgTitleBar.ContextMenu = $dlgCtx
		}
		if ($btnDlgClose) { $btnDlgClose.Add_Click({ $dlg.Close() }.GetNewClosure()) }

		$cardDefinitions = @(
			[pscustomobject]@{
				Token = 'Own'
				Title = (Get-UxLocalizedString -Key 'GuiImportSettingsOwnTitle' -Fallback 'Saved profile')
				Detail = (Get-UxLocalizedString -Key 'GuiImportSettingsOwnDetail' -Fallback ("Open a Baseline settings profile from the {0} settings folder." -f $AppName))
				Icon = 'Folder'
			}
			[pscustomobject]@{
				Token = 'Recommended'
				Title = (Get-UxLocalizedString -Key 'GuiImportSettingsRecommendedTitle' -Fallback 'Last run')
				Detail = (Get-UxLocalizedString -Key 'GuiImportSettingsRecommendedDetail' -Fallback 'Load the profile saved after Baseline finished its last run.')
				Icon = 'RestoreDefaults'
			}
			[pscustomobject]@{
				Token = 'Backup'
				Title = (Get-UxLocalizedString -Key 'GuiImportSettingsBackupTitle' -Fallback 'Session backup')
				Detail = (Get-UxLocalizedString -Key 'GuiImportSettingsBackupDetail' -Fallback 'Load the current session-state backup used for undo and restore.')
				Icon = 'Archive'
			}
			[pscustomobject]@{
				Token = 'Custom'
				Title = (Get-UxLocalizedString -Key 'GuiImportSettingsCustomTitle' -Fallback 'Custom file')
				Detail = (Get-UxLocalizedString -Key 'GuiImportSettingsCustomDetail' -Fallback 'Browse to any compatible Baseline settings JSON file.')
				Icon = 'Search'
			}
		)

		foreach ($cardDef in $cardDefinitions)
		{
			$button = New-Object System.Windows.Controls.Button
			$button.HorizontalAlignment = 'Stretch'
			$button.VerticalAlignment = 'Stretch'
			$button.MinWidth = 168
			$button.Width = 168
			$button.Height = 164
			$button.Margin = [System.Windows.Thickness]::new(0, 0, 12, 12)
			$button.Padding = [System.Windows.Thickness]::new(16, 14, 16, 14)
			$button.Cursor = [System.Windows.Input.Cursors]::Hand
			$button.HorizontalContentAlignment = 'Stretch'
			$button.VerticalContentAlignment = 'Stretch'
			Set-ButtonChrome -Button $button -Variant 'Subtle'

			$stack = New-Object System.Windows.Controls.StackPanel
			$stack.Orientation = 'Vertical'
			$stack.HorizontalAlignment = 'Stretch'
			$stack.VerticalAlignment = 'Stretch'

			if (Get-Command -Name 'New-GuiIconTextBlock' -CommandType Function -ErrorAction SilentlyContinue)
			{
				$icon = New-GuiIconTextBlock -IconName ([string]$cardDef.Icon) -Size 26 -Foreground $bc.ConvertFromString($theme.AccentBlue) -VerticalAlignment 'Center'
				if ($icon)
				{
					$icon.HorizontalAlignment = 'Left'
					$icon.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
					[void]($stack.Children.Add($icon))
				}
			}

			$titleBlock = New-Object System.Windows.Controls.TextBlock
			$titleBlock.Text = [string]$cardDef.Title
			$titleBlock.FontSize = 14
			$titleBlock.FontWeight = [System.Windows.FontWeights]::SemiBold
			$titleBlock.Foreground = $bc.ConvertFromString($theme.TextPrimary)
			$titleBlock.TextWrapping = 'Wrap'
			$titleBlock.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)
			[void]($stack.Children.Add($titleBlock))

			$detailBlock = New-Object System.Windows.Controls.TextBlock
			$detailBlock.Text = [string]$cardDef.Detail
			$detailBlock.FontSize = 11
			$detailBlock.Foreground = $bc.ConvertFromString($theme.TextSecondary)
			$detailBlock.TextWrapping = 'Wrap'
			[void]($stack.Children.Add($detailBlock))

			$button.Content = $stack
			$buttonToken = [string]$cardDef.Token
			$dlgRef = $dlg
			$resRef = $resultRef
			$button.Add_Click({
				$resRef.Value = $buttonToken
				$dlgRef.Close()
			}.GetNewClosure())
			[void]($cardPanel.Children.Add($button))
		}

		if ($btnCancel)
		{
			$btnCancel.Content = $closeLabel
			Set-ButtonChrome -Button $btnCancel -Variant 'Primary' -Compact
			$btnCancel.IsDefault = $true
			$btnCancel.IsCancel = $true
			$btnCancel.Add_Click({ $dlg.Close() }.GetNewClosure())
		}

		$dlg.Add_KeyDown({
			$eventArgs = $args[1]

			if ($eventArgs.Key -eq [System.Windows.Input.Key]::Escape)
			{
				$dlg.Close()
			}
		})

		[void]($dlg.ShowDialog())
		return $resultRef.Value
	}

	<#
	    .SYNOPSIS
	    Internal function Show-GuiAuditSettingsDialog.
	#>

	function Show-GuiAuditSettingsDialog
	{
		param (
			[int]$InitialRetentionDays = 90
		)

		$theme = $Script:CurrentTheme
		if (-not $theme)
		{
			return $null
		}

		$bc = New-SafeBrushConverter -Context 'DialogHelpers-AuditSettings'
		$windowTitle = Get-UxLocalizedString -Key 'GuiAuditSettings' -Fallback 'Audit Settings'
		$windowSubtitle = Get-UxLocalizedString -Key 'GuiAuditSettingsSubtitle' -Fallback 'Choose the retention window used by audit exports, cleanup, and support bundles.'
		$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'
		$saveLabel = Get-UxLocalizedString -Key 'GuiSaveButton' -Fallback 'Save'

		[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$windowTitle"
	Width="640" Height="360"
	MinWidth="560" MinHeight="320"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="FluentSystemIcons"
	FontSize="12"
	Background="Transparent"
	WindowStyle="None"
	AllowsTransparency="True">
	<Border Name="RootBorder" CornerRadius="8">
		<Grid>
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="*"/>
				<RowDefinition Height="Auto"/>
			</Grid.RowDefinitions>

			<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="12,8,8,8" Cursor="Arrow">
				<Grid>
					<TextBlock Text="$windowTitle" VerticalAlignment="Center" FontSize="12" Foreground="$($theme.TextPrimary)"/>
					<Button Name="BtnDlgClose" Content="x" FontFamily="Arial" FontSize="12" Width="32" Height="28"
						Background="Transparent" Foreground="$($theme.TextPrimary)" BorderThickness="0" Cursor="Hand"
						HorizontalAlignment="Right" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
				</Grid>
			</Border>

			<Border Grid.Row="1" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,0,0,1"
					Padding="20,14,20,14">
				<StackPanel>
					<TextBlock Name="TxtDialogTitle" Text="$windowTitle" FontSize="16" FontWeight="SemiBold"
							   Foreground="$($theme.TextPrimary)"/>
					<TextBlock Name="TxtDialogSubtitle" Text="$windowSubtitle"
							   FontSize="12" Foreground="$($theme.TextMuted)" Margin="0,2,0,0" TextWrapping="Wrap"/>
				</StackPanel>
			</Border>

			<Grid Grid.Row="2" Margin="20,18,20,18">
				<Grid.RowDefinitions>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="*"/>
				</Grid.RowDefinitions>

				<TextBlock Name="TxtRetentionLabel" Grid.Row="0" Text="" Margin="0,0,0,8" FontSize="13" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
				<ComboBox Name="CmbAuditRetention" Grid.Row="1" Height="32" HorizontalAlignment="Left" MinWidth="220"/>
				<TextBlock Name="TxtRetentionHelp" Grid.Row="2" Text="" Margin="0,12,0,0" TextWrapping="Wrap" Foreground="$($theme.TextSecondary)"/>
			</Grid>

			<Border Grid.Row="3" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0"
					Padding="20,10,20,10">
				<Grid>
					<Button Name="BtnCancel" Content="" HorizontalAlignment="Right" Padding="20,6" FontSize="13" Margin="0,0,8,0"/>
					<Button Name="BtnSave" Content="" HorizontalAlignment="Right" Padding="20,6" FontSize="13"/>
				</Grid>
			</Border>
		</Grid>
	</Border>
</Window>
"@

		$reader = [System.Xml.XmlNodeReader]::new($xaml)
		$dlg = [Windows.Markup.XamlReader]::Load($reader)
		$dlg.Owner = $Form

		$rootBorder = $dlg.FindName('RootBorder')
		if ($rootBorder)
		{
			$rootBorder.Background = $bc.ConvertFromString($theme.WindowBg)
			$rootBorder.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
			$rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
		}

		[void](GUICommon\Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))

		$dlgTitleBar = $dlg.FindName('DlgTitleBar')
		$btnDlgClose = $dlg.FindName('BtnDlgClose')
		$btnCancel = $dlg.FindName('BtnCancel')
		$btnSave = $dlg.FindName('BtnSave')
		$cmbAuditRetention = $dlg.FindName('CmbAuditRetention')
		$txtRetentionLabel = $dlg.FindName('TxtRetentionLabel')
		$txtRetentionHelp = $dlg.FindName('TxtRetentionHelp')
		$resultRef = @{ Value = $null }
		$selectedRetentionRef = @{ Value = [int]$InitialRetentionDays }

		if ($txtRetentionLabel)
		{
			$txtRetentionLabel.Text = (Get-UxLocalizedString -Key 'GuiAuditSettingsRetentionLabel' -Fallback 'Retention window')
		}
		if ($txtRetentionHelp)
		{
			$txtRetentionHelp.Text = (Get-UxLocalizedString -Key 'GuiAuditSettingsRetentionHelp' -Fallback 'This window is used for audit exports, log cleanup, support bundles, and other retention-aware actions.')
		}

		$items = @(
			[pscustomobject]@{ Days = 30;  Label = '30 days' }
			[pscustomobject]@{ Days = 90;  Label = '90 days' }
			[pscustomobject]@{ Days = 180; Label = '180 days' }
			[pscustomobject]@{ Days = 365; Label = '365 days' }
		)

		if ($cmbAuditRetention)
		{
			foreach ($item in $items)
			{
				$comboItem = New-Object System.Windows.Controls.ComboBoxItem
				$comboItem.Content = $item.Label
				$comboItem.Tag = $item.Days
				[void]$cmbAuditRetention.Items.Add($comboItem)
			}

			$selectedIndex = 1
			for ($i = 0; $i -lt $cmbAuditRetention.Items.Count; $i++)
			{
				$item = $cmbAuditRetention.Items[$i]
				if ([int]$item.Tag -eq $selectedRetentionRef.Value)
				{
					$selectedIndex = $i
					break
				}
			}
			$cmbAuditRetention.SelectedIndex = $selectedIndex
			$selectedRetentionRef.Value = [int]$cmbAuditRetention.SelectedItem.Tag

			$cmbAuditRetention.Add_SelectionChanged({
				$selected = $cmbAuditRetention.SelectedItem
				if ($selected -and $selected.Tag -ne $null)
				{
					$selectedRetentionRef.Value = [int]$selected.Tag
				}
			}.GetNewClosure())
		}

		if ($dlgTitleBar)
		{
			$dlgTitleBar.Add_MouseLeftButtonDown({ $dlg.DragMove() }.GetNewClosure())
		}
		if ($btnDlgClose) { $btnDlgClose.Add_Click({ $dlg.Close() }.GetNewClosure()) }
		if ($btnCancel)
		{
			$btnCancel.Content = $closeLabel
			Set-ButtonChrome -Button $btnCancel -Variant 'Secondary' -Compact
			$btnCancel.IsCancel = $true
			$btnCancel.Add_Click({ $dlg.Close() }.GetNewClosure())
		}
		if ($btnSave)
		{
			$btnSave.Content = $saveLabel
			Set-ButtonChrome -Button $btnSave -Variant 'Primary' -Compact
			$btnSave.IsDefault = $true
			$btnSave.Add_Click({
				$resultRef.Value = [int]$selectedRetentionRef.Value
				$dlg.Close()
			}.GetNewClosure())
		}

		$dlg.Add_KeyDown({
			$eventArgs = $args[1]
			if ($eventArgs.Key -eq [System.Windows.Input.Key]::Escape)
			{
				$dlg.Close()
			}
		})

		[void]($dlg.ShowDialog())
		return $resultRef.Value
	}

	<#
	    .SYNOPSIS
	    Internal function Show-GuiRemoteConsoleDialog.
	#>

	function Show-GuiRemoteConsoleDialog
	{
		$theme = $Script:CurrentTheme
		if (-not $theme)
		{
			return $null
		}

		$bc = New-SafeBrushConverter -Context 'DialogHelpers-RemoteConsole'
		$windowTitle = Get-UxLocalizedString -Key 'GuiRemoteConsole' -Fallback 'Remote Console'
		$windowSubtitle = Get-UxLocalizedString -Key 'GuiRemoteConsoleSubtitle' -Fallback 'Monitor and control the current remote orchestration context.'
		$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'
		$refreshLabel = Get-UxLocalizedString -Key 'GuiRefreshButton' -Fallback 'Refresh'
		$preflightLabel = Get-UxLocalizedString -Key 'GuiPlanPreflightChecks' -Fallback 'Preflight'

		[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$windowTitle"
	Width="920" Height="640"
	MinWidth="760" MinHeight="560"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="FluentSystemIcons"
	FontSize="12"
	Background="Transparent"
	WindowStyle="None"
	AllowsTransparency="True">
	<Border Name="RootBorder" CornerRadius="8">
		<Grid>
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="*"/>
				<RowDefinition Height="Auto"/>
			</Grid.RowDefinitions>

			<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="12,8,8,8" Cursor="Arrow">
				<Grid>
					<TextBlock Text="$windowTitle" VerticalAlignment="Center" FontSize="12" Foreground="$($theme.TextPrimary)"/>
					<Button Name="BtnDlgClose" Content="x" FontFamily="Arial" FontSize="12" Width="32" Height="28"
						Background="Transparent" Foreground="$($theme.TextPrimary)" BorderThickness="0" Cursor="Hand"
						HorizontalAlignment="Right" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
				</Grid>
			</Border>

			<Border Grid.Row="1" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,0,0,1"
					Padding="20,14,20,14">
				<StackPanel>
					<TextBlock Name="TxtDialogTitle" Text="$windowTitle" FontSize="16" FontWeight="SemiBold"
							   Foreground="$($theme.TextPrimary)"/>
					<TextBlock Name="TxtDialogSubtitle" Text="$windowSubtitle"
							   FontSize="12" Foreground="$($theme.TextMuted)" Margin="0,2,0,0" TextWrapping="Wrap"/>
				</StackPanel>
			</Border>

			<ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="20,18,20,18">
				<Grid>
					<Grid.RowDefinitions>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
					</Grid.RowDefinitions>
					<TextBlock Name="TxtConnectedTargets" Grid.Row="0" Text="" Margin="0,0,0,8" TextWrapping="Wrap" Foreground="$($theme.TextPrimary)"/>
					<TextBlock Name="TxtApprovedTargets" Grid.Row="1" Text="" Margin="0,0,0,8" TextWrapping="Wrap" Foreground="$($theme.TextSecondary)"/>
					<TextBlock Name="TxtConnectedAt" Grid.Row="2" Text="" Margin="0,0,0,8" TextWrapping="Wrap" Foreground="$($theme.TextSecondary)"/>
					<TextBlock Name="TxtApprovalMessage" Grid.Row="3" Text="" Margin="0,0,0,8" TextWrapping="Wrap" Foreground="$($theme.TextSecondary)"/>
					<TextBlock Name="TxtCachedSessions" Grid.Row="4" Text="" Margin="0,0,0,8" TextWrapping="Wrap" Foreground="$($theme.TextSecondary)"/>
					<Border Grid.Row="5" Background="$($theme.InputBg)" BorderBrush="$($theme.BorderColor)" BorderThickness="1" CornerRadius="6" Padding="12,10,12,10" Margin="0,0,0,8">
						<StackPanel>
							<Grid Margin="0,0,0,8">
								<Grid.ColumnDefinitions>
									<ColumnDefinition Width="*"/>
									<ColumnDefinition Width="Auto"/>
								</Grid.ColumnDefinitions>
								<TextBlock Grid.Column="0" Text="Recent remote runs" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)" VerticalAlignment="Center"/>
								<TextBox Name="TxtFilterRuns" Grid.Column="1" Width="200" Padding="4" VerticalAlignment="Center"/>
							</Grid>
							<ListView Name="LstRecentRemoteRuns" BorderThickness="0" Background="Transparent" Height="180">
								<ListView.View>
									<GridView>
										<GridViewColumn Header="Date" Width="155" DisplayMemberBinding="{Binding Timestamp, StringFormat='yyyy-MM-dd HH:mm:ss'}"/>
										<GridViewColumn Header="Operation" Width="120" DisplayMemberBinding="{Binding Operation}"/>
										<GridViewColumn Header="State" Width="90" DisplayMemberBinding="{Binding TerminalState}"/>
										<GridViewColumn Header="Targets" Width="70" DisplayMemberBinding="{Binding TargetCount}"/>
										<GridViewColumn Header="Counts" Width="240" DisplayMemberBinding="{Binding CountsSummary}"/>
										<GridViewColumn Header="Summary" Width="420" DisplayMemberBinding="{Binding Summary}"/>
									</GridView>
								</ListView.View>
							</ListView>
						</StackPanel>
					</Border>
					<TextBlock Name="TxtConsoleHint" Grid.Row="6" Text="" Margin="0,6,0,0" TextWrapping="Wrap" Foreground="$($theme.TextMuted)"/>
				</Grid>
			</ScrollViewer>

			<Border Grid.Row="3" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0"
					Padding="20,10,20,10">
				<WrapPanel HorizontalAlignment="Right">
					<Button Name="BtnConnect" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnDisconnect" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnApprove" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnSavePolicy" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnLoadPolicy" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnPreflight" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnRefresh" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnClose" Content="" Padding="16,6" FontSize="13"/>
				</WrapPanel>
			</Border>
		</Grid>
	</Border>
</Window>
"@

		$reader = [System.Xml.XmlNodeReader]::new($xaml)
		$dlg = [Windows.Markup.XamlReader]::Load($reader)
		$dlg.Owner = $Form

		$rootBorder = $dlg.FindName('RootBorder')
		if ($rootBorder)
		{
			$rootBorder.Background = $bc.ConvertFromString($theme.WindowBg)
			$rootBorder.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
			$rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
		}

		[void](GUICommon\Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))

		$dlgTitleBar = $dlg.FindName('DlgTitleBar')
		$btnDlgClose = $dlg.FindName('BtnDlgClose')
		$btnConnect = $dlg.FindName('BtnConnect')
		$btnDisconnect = $dlg.FindName('BtnDisconnect')
		$btnApprove = $dlg.FindName('BtnApprove')
		$btnSavePolicy = $dlg.FindName('BtnSavePolicy')
		$btnLoadPolicy = $dlg.FindName('BtnLoadPolicy')
		$btnPreflight = $dlg.FindName('BtnPreflight')
		$btnRefresh = $dlg.FindName('BtnRefresh')
		$btnClose = $dlg.FindName('BtnClose')
		$txtConnectedTargets = $dlg.FindName('TxtConnectedTargets')
		$txtApprovedTargets = $dlg.FindName('TxtApprovedTargets')
		$txtConnectedAt = $dlg.FindName('TxtConnectedAt')
		$txtApprovalMessage = $dlg.FindName('TxtApprovalMessage')
		$txtCachedSessions = $dlg.FindName('TxtCachedSessions')
		$lstRecentRemoteRuns = $dlg.FindName('LstRecentRemoteRuns')
		$txtConsoleHint = $dlg.FindName('TxtConsoleHint')
		$txtFilterRuns = $dlg.FindName('TxtFilterRuns')

		$promptRemoteTargetConnectionCommand = Get-GuiRuntimeCommand -Name 'Prompt-GuiRemoteTargetConnection' -CommandType 'Function'
		$setRemoteTargetContextCommand = Get-GuiRuntimeCommand -Name 'Set-GuiRemoteTargetContext' -CommandType 'Function'
		$getRemoteTargetContextCommand = Get-GuiRuntimeCommand -Name 'Get-GuiRemoteTargetContext' -CommandType 'Function'
		$clearRemoteTargetContextCommand = Get-GuiRuntimeCommand -Name 'Clear-GuiRemoteTargetContext' -CommandType 'Function'
		$setRemoteTargetApprovalCommand = Get-GuiRuntimeCommand -Name 'Set-GuiRemoteTargetApprovalList' -CommandType 'Function'
		$testRemoteTargetApprovalCommand = Get-GuiRuntimeCommand -Name 'Test-GuiRemoteTargetApproval' -CommandType 'Function'
		$exportRemoteTargetApprovalPolicyCommand = Get-GuiRuntimeCommand -Name 'Export-GuiRemoteTargetApprovalPolicy' -CommandType 'Function'
		$importRemoteTargetApprovalPolicyCommand = Get-GuiRuntimeCommand -Name 'Import-GuiRemoteTargetApprovalPolicy' -CommandType 'Function'
		$getRemoteSessionSummaryCommand = Get-GuiRuntimeCommand -Name 'Get-BaselineRemoteSessionSummary' -CommandType 'Function'
		$getRemoteRunSummariesCommand = Get-GuiRuntimeCommand -Name 'Get-BaselineRemoteRunSummaries' -CommandType 'Function'
		$getRemoteOrchestrationDetailsCommand = Get-GuiRuntimeCommand -Name 'Get-BaselineRemoteOrchestrationDetails' -CommandType 'Function'
		$getRemoteOrchestrationSummaryCommand = Get-GuiRuntimeCommand -Name 'Get-BaselineRemoteOrchestrationSummary' -CommandType 'Function'
		$exportSupportBundleCommand = Get-GuiRuntimeCommand -Name 'Export-BaselineSupportBundle' -CommandType 'Function'
		$showGuiFileSaveDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiFileSaveDialog' -CommandType 'Function'
		$getGuiSettingsSnapshotCommand = Get-GuiRuntimeCommand -Name 'Get-GuiSettingsSnapshot' -CommandType 'Function'
		$testRemoteConnectivityCommand = Get-GuiRuntimeCommand -Name 'Test-BaselineRemoteConnectivity' -CommandType 'Function'
		$testInteractiveHostCapture = Get-GuiFunctionCapture -Name 'Test-InteractiveHost'
		$showRemoteConsoleError = {
			param(
				[string]$Title,
				[string]$Message
			)

			$canShowDialog = $false
			try
			{
				if ($testInteractiveHostCapture)
				{
					$canShowDialog = [bool](& $testInteractiveHostCapture)
				}
			}
			catch
			{
				$canShowDialog = $false
			}

			if ($canShowDialog)
			{
				[void](Show-ThemedDialog -Title $Title -Message $Message -Buttons @('OK') -AccentButton 'OK')
				return
			}

			LogWarn ($Title + ': ' + $Message)
		}.GetNewClosure()

		if ($txtFilterRuns -and (Get-Command -Name 'Set-GuiWatermarkText' -CommandType Function -ErrorAction SilentlyContinue))
		{
			Set-GuiWatermarkText -TextBox $txtFilterRuns -Text 'Filter runs...'
		}

		$remoteRunsCtx = New-Object System.Windows.Controls.ContextMenu
		$ctxOpenLog = New-Object System.Windows.Controls.MenuItem
		$ctxOpenLog.Header = 'Open Log...'
		$ctxExportBundle = New-Object System.Windows.Controls.MenuItem
		$ctxExportBundle.Header = 'Export Support Bundle...'
		$ctxIncidentPack = New-Object System.Windows.Controls.MenuItem
		$ctxIncidentPack.Header = 'Generate Incident Repro Pack...'
		$ctxExportDeepLinkedBundle = New-Object System.Windows.Controls.MenuItem
		$ctxExportDeepLinkedBundle.Header = 'Export Deep-Linked Support Bundle...'
		$ctxRetryFailed = New-Object System.Windows.Controls.MenuItem
		$ctxRetryFailed.Header = 'Retry Failed Targets'
		$ctxExportFailed = New-Object System.Windows.Controls.MenuItem
		$ctxExportFailed.Header = 'Export Failed Target List...'
		
		[void]$remoteRunsCtx.Items.Add($ctxOpenLog)
		[void]$remoteRunsCtx.Items.Add($ctxExportBundle)
		[void]$remoteRunsCtx.Items.Add($ctxIncidentPack)
		[void]$remoteRunsCtx.Items.Add($ctxExportDeepLinkedBundle)
		[void]$remoteRunsCtx.Items.Add((New-Object System.Windows.Controls.Separator))
		[void]$remoteRunsCtx.Items.Add($ctxRetryFailed)
		[void]$remoteRunsCtx.Items.Add($ctxExportFailed)
		if ($lstRecentRemoteRuns) { $lstRecentRemoteRuns.ContextMenu = $remoteRunsCtx }

		$remoteRunsCtx.Add_Opened({
			$selected = $lstRecentRemoteRuns.SelectedItem
			if (-not $selected)
			{
				$ctxOpenLog.IsEnabled = $false
				$ctxExportBundle.IsEnabled = $false
				$ctxIncidentPack.IsEnabled = $false
				$ctxRetryFailed.IsEnabled = $false
				$ctxExportFailed.IsEnabled = $false
			}
			else
			{
				$hasLog = (Test-GuiObjectField -Object $selected -FieldName 'LogPath') -and -not [string]::IsNullOrWhiteSpace($selected.LogPath)
				$hasBundle = (Test-GuiObjectField -Object $selected -FieldName 'BundlePath') -and -not [string]::IsNullOrWhiteSpace($selected.BundlePath)
				$hasFailed = (Test-GuiObjectField -Object $selected -FieldName 'FailedCount') -and $selected.FailedCount -gt 0
				$canDeepLink = (Test-GuiObjectField -Object $selected -FieldName 'RunId') -and -not [string]::IsNullOrWhiteSpace([string]$selected.RunId) -and $hasFailed

				$ctxOpenLog.IsEnabled = $hasLog
				$ctxExportBundle.IsEnabled = $hasBundle
				$ctxIncidentPack.IsEnabled = ($hasBundle -and [string]$selected.TerminalState -match '(?i)Failed')
				$ctxExportDeepLinkedBundle.IsEnabled = $canDeepLink
				$ctxRetryFailed.IsEnabled = $hasFailed
				$ctxExportFailed.IsEnabled = $hasFailed
			}
		}.GetNewClosure())

		$ctxOpenLog.Add_Click({
			$selected = $lstRecentRemoteRuns.SelectedItem
			if ($selected -and (Test-GuiObjectField -Object $selected -FieldName 'LogPath') -and -not [string]::IsNullOrWhiteSpace($selected.LogPath))
			{
				Show-LogDialog -LogPath $selected.LogPath
			}
		}.GetNewClosure())

		$ctxExportBundle.Add_Click({
			$selected = $lstRecentRemoteRuns.SelectedItem
			if ($selected -and (Test-GuiObjectField -Object $selected -FieldName 'BundlePath') -and -not [string]::IsNullOrWhiteSpace($selected.BundlePath))
			{
				try { [System.Diagnostics.Process]::Start('explorer.exe', "/select,`"$($selected.BundlePath)`"") } catch { & $showRemoteConsoleError -Title 'Remote Console' -Message "Failed to show bundle: $($_.Exception.Message)" }
			}
		}.GetNewClosure())

		$ctxIncidentPack.Add_Click({
			$selected = $lstRecentRemoteRuns.SelectedItem
			if ($selected -and (Test-GuiObjectField -Object $selected -FieldName 'BundlePath') -and -not [string]::IsNullOrWhiteSpace($selected.BundlePath))
			{
				try
				{
					$incidentPackCmd = Get-GuiRuntimeCommand -Name 'New-IncidentReproductionPack' -CommandType 'Function'
					if ($incidentPackCmd)
					{
						& $incidentPackCmd -SupportBundlePath $selected.BundlePath
					}
				}
				catch
				{
					& $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to generate incident reproduction pack.`n`n{0}" -f $_.Exception.Message)
				}
			}
		}.GetNewClosure())

		$ctxExportDeepLinkedBundle.Add_Click({
			$selected = $lstRecentRemoteRuns.SelectedItem
			if (-not $selected) { return }
			if (-not (Test-GuiObjectField -Object $selected -FieldName 'RunId') -or [string]::IsNullOrWhiteSpace([string]$selected.RunId)) { return }
			if (-not (Test-GuiObjectField -Object $selected -FieldName 'FailedCount') -or [int]$selected.FailedCount -le 0) { return }
			if (-not $exportSupportBundleCommand -or -not $showGuiFileSaveDialogCommand)
			{
				& $showRemoteConsoleError -Title 'Remote Console' -Message 'Support bundle export is unavailable in this runtime.'
				return
			}

			try
			{
				$defaultFileName = 'Baseline-SupportBundle-{0}-{1}.zip' -f ((Get-Date -Format 'yyyyMMdd-HHmmss')), ([string]$selected.ComputerName -replace '[^A-Za-z0-9._-]', '_')
				$savePath = & $showGuiFileSaveDialogCommand -Title 'Export Deep-Linked Support Bundle' -Filter 'ZIP Files (*.zip)|*.zip|All Files (*.*)|*.*' -DefaultExtension 'zip' -FileName $defaultFileName
				if ([string]::IsNullOrWhiteSpace($savePath)) { return }

				$sessionSnapshot = $null
				try { if ($getGuiSettingsSnapshotCommand) { $sessionSnapshot = & $getGuiSettingsSnapshotCommand } } catch { $sessionSnapshot = $null }
				$sessionStatePath = Join-Path ([System.IO.Path]::GetTempPath()) ('BaselineSupportBundleSession_{0}.json' -f [guid]::NewGuid().ToString('N'))
				try
				{
					$sessionPayload = [ordered]@{
						Schema = 'Baseline.GuiSession'
						SchemaVersion = 1
						SavedAt = (Get-Date).ToString('o')
						State = $sessionSnapshot
					}
					($sessionPayload | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $sessionStatePath -Encoding UTF8 -Force

					$systemSnapshot = $null
					try { $systemSnapshot = New-SystemStateSnapshot -Manifest $Script:TweakManifest } catch { $systemSnapshot = $null }

					$result = & $exportSupportBundleCommand -OutputPath $savePath -ProfilePath $sessionStatePath -SystemSnapshot $systemSnapshot -Manifest $Script:TweakManifest -IncludeAuditLog -IncludeTestReport -DeepLinkRunId @([string]$selected.RunId) -DeepLinkComputerName @([string]$selected.ComputerName) -DeepLinkOperation @([string]$selected.Operation)
					LogInfo ("Exported deep-linked support bundle to {0}" -f $result.OutputPath)
					try { [System.Diagnostics.Process]::Start('explorer.exe', "/select,`"$($result.OutputPath)`"") | Out-Null } catch { }
				}
				finally
				{
					if (Test-Path -LiteralPath $sessionStatePath)
					{
						try { Remove-Item -LiteralPath $sessionStatePath -Force -ErrorAction SilentlyContinue } catch { }
					}
				}
			}
			catch
			{
				& $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to export deep-linked support bundle.`n`n{0}" -f $_.Exception.Message)
			}
		}.GetNewClosure())

		$ctxRetryFailed.Add_Click({
			$selected = $lstRecentRemoteRuns.SelectedItem
			if ($selected -and (Test-GuiObjectField -Object $selected -FieldName 'FailedCount') -and $selected.FailedCount -gt 0)
			{
				$targets = if (Test-GuiObjectField -Object $selected -FieldName 'FailedTargets') { @($selected.FailedTargets) } else { @() }
				if ($targets.Count -gt 0)
				{
					try
					{
						$ctx = Invoke-CapturedFunction -Name 'Get-GuiRemoteTargetContext'
						$cred = if ($ctx) { $ctx.Credential } else { $null }
						$null = Invoke-CapturedFunction -Name 'Set-GuiRemoteTargetContext' -Parameters @{
							ComputerName = $targets
							Credential = $cred
							StatusMessage = 'Context updated to retry failed targets.'
						}
						& $refreshConsole
					}
					catch
					{
						& $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to stage retry targets.`n`n{0}" -f $_.Exception.Message)
					}
				}
				else
				{
					& $showRemoteConsoleError -Title 'Remote Console' -Message "Failed target list not available in this summary."
				}
			}
		}.GetNewClosure())

		$ctxExportFailed.Add_Click({
			$selected = $lstRecentRemoteRuns.SelectedItem
			if ($selected -and (Test-GuiObjectField -Object $selected -FieldName 'FailedCount') -and $selected.FailedCount -gt 0)
			{
				$targets = if (Test-GuiObjectField -Object $selected -FieldName 'FailedTargets') { @($selected.FailedTargets) } else { @() }
				if ($targets.Count -gt 0)
				{
					$dialog = New-Object Microsoft.Win32.SaveFileDialog
					$dialog.Title = 'Export Failed Targets'
					$dialog.Filter = 'Text Files (*.txt)|*.txt|All Files (*.*)|*.*'
					$dialog.DefaultExt = 'txt'
					$dialog.FileName = ('FailedTargets-{0}.txt' -f $selected.Timestamp.ToString('yyyyMMdd-HHmmss'))
					if ($dialog.ShowDialog($dlg) -eq $true)
					{
						try { [System.IO.File]::WriteAllLines($dialog.FileName, $targets) } catch { & $showRemoteConsoleError -Title 'Export Failed' -Message ("Failed to write file.`n`n{0}" -f $_.Exception.Message) }
					}
				}
				else { & $showRemoteConsoleError -Title 'Remote Console' -Message "Failed target list not available in this summary." }
			}
		}.GetNewClosure())

		$refreshConsole = {
			$context = $null
			try { $context = Invoke-CapturedFunction -Name 'Get-GuiRemoteTargetContext' } catch { $context = $null }
			$sessions = @()
			try { $sessions = @((Invoke-CapturedFunction -Name 'Get-BaselineRemoteSessionSummary')) } catch { $sessions = @() }
			$recentRuns = @()
			try
			{
				if ($getRemoteRunSummariesCommand)
				{
					$recentRuns = @((Invoke-CapturedFunction -Name 'Get-BaselineRemoteRunSummaries' -Parameters @{ MaxRecords = 5 }))
				}
				elseif (Get-GuiFunctionCapture -Name 'Get-BaselineRemoteOrchestrationDetails')
				{
					$recentRuns = @((Invoke-CapturedFunction -Name 'Get-BaselineRemoteOrchestrationDetails' -Parameters @{ MaxRecords = 5 }))
				}
				else
				{
					$recentRuns = @((Invoke-CapturedFunction -Name 'Get-BaselineRemoteOrchestrationSummary' -Parameters @{ MaxRecords = 5 }))
				}
			}
			catch
			{
				$recentRuns = @()
			}

			$recentRunRows = @()
			if ($recentRuns.Count -gt 0)
			{
				$recentRunRows = @($recentRuns | ForEach-Object {
					$timestamp = $null
					try { $timestamp = [datetime]::Parse([string]$_.Timestamp) } catch { $timestamp = [datetime]::UtcNow }
					$succeededCount = if ($_.PSObject.Properties['SucceededCount']) { [int]$_.SucceededCount } else { 0 }
					$failedCount = if ($_.PSObject.Properties['FailedCount']) { [int]$_.FailedCount } else { 0 }
					$skippedCount = if ($_.PSObject.Properties['SkippedCount']) { [int]$_.SkippedCount } else { 0 }
					$retryingCount = if ($_.PSObject.Properties['RetryingCount']) { [int]$_.RetryingCount } else { 0 }
					$cancelledCount = if ($_.PSObject.Properties['CancelledCount']) { [int]$_.CancelledCount } else { 0 }
					$attempts = if ($_.PSObject.Properties['TotalAttempts']) { [int]$_.TotalAttempts } else { 0 }
					$retries = if ($_.PSObject.Properties['TotalRetries']) { [int]$_.TotalRetries } else { 0 }

					[pscustomobject]@{
						Timestamp      = $timestamp
						Operation      = if ($_.PSObject.Properties['Operation']) { [string]$_.Operation } else { 'Remote' }
						TerminalState  = if ($_.PSObject.Properties['TerminalState']) { [string]$_.TerminalState } else { 'Unknown' }
						TargetCount    = if ($_.PSObject.Properties['TargetCount']) { [int]$_.TargetCount } else { 0 }
						FailedCount    = $failedCount
						FailedTargets  = if ($_.PSObject.Properties['FailedTargets']) { @($_.FailedTargets) } else { @() }
						CountsSummary  = ('Success={0}, Failed={1}, Skipped={2}, Retrying={3}, Cancelled={4}, Attempts={5}, Retries={6}' -f $succeededCount, $failedCount, $skippedCount, $retryingCount, $cancelledCount, $attempts, $retries)
						Summary        = if ($_.PSObject.Properties['Summary']) { [string]$_.Summary } else { ('{0} | {1} | Run {2}' -f $timestamp.ToString('yyyy-MM-dd HH:mm:ss'), (if ($_.PSObject.Properties['Operation']) { [string]$_.Operation } else { 'Remote' }), (if ($_.PSObject.Properties['RunId']) { [string]$_.RunId } else { 'n/a' })) }
						LogPath        = if ($_.PSObject.Properties['LogPath']) { [string]$_.LogPath } else { $null }
						BundlePath     = if ($_.PSObject.Properties['BundlePath']) { [string]$_.BundlePath } else { $null }
					}
				})
			}

			if ($txtFilterRuns -and -not [string]::IsNullOrWhiteSpace($txtFilterRuns.Text))
			{
				$filter = $txtFilterRuns.Text
				$recentRunRows = @($recentRunRows | Where-Object {
					$_.Operation -match $filter -or
					$_.TerminalState -match $filter -or
					$_.Summary -match $filter
				})
			}

			if ($txtConnectedTargets)
			{
				if ($context -and $context.Connected -and $context.TargetComputers.Count -gt 0)
				{
					$txtConnectedTargets.Text = ('Connected targets: {0}' -f ($context.TargetComputers -join ', '))
				}
				else
				{
					$txtConnectedTargets.Text = 'Connected targets: none'
				}
			}

			if ($txtApprovedTargets)
			{
				if ($context -and $context.ApprovedTargetComputers -and $context.ApprovedTargetComputers.Count -gt 0)
				{
					$txtApprovedTargets.Text = ('Approved targets: {0}' -f ($context.ApprovedTargetComputers -join ', '))
				}
				else
				{
					$txtApprovedTargets.Text = 'Approved targets: none'
				}
			}

			if ($txtConnectedAt)
			{
				$txtConnectedAt.Text = if ($context -and $context.ConnectedAt) { ('Connected at (UTC): {0}' -f $context.ConnectedAt) } else { 'Connected at (UTC): n/a' }
			}

			if ($txtApprovalMessage)
			{
				$txtApprovalMessage.Text = if ($context -and $context.ApprovalMessage) { ('Approval message: {0}' -f $context.ApprovalMessage) } else { 'Approval message: n/a' }
			}

			if ($txtCachedSessions)
			{
				if ($sessions.Count -gt 0)
				{
					$txtCachedSessions.Text = ('Cached sessions: {0}' -f (($sessions | ForEach-Object { '{0} [{1}]' -f $_.ComputerName, $_.State }) -join '; '))
				}
				else
				{
					$txtCachedSessions.Text = 'Cached sessions: none'
				}
			}

			if ($lstRecentRemoteRuns)
			{
				$lstRecentRemoteRuns.ItemsSource = $recentRunRows
				if ($recentRunRows.Count -eq 0)
				{
					$lstRecentRemoteRuns.IsEnabled = $false
				}
				else
				{
					$lstRecentRemoteRuns.IsEnabled = $true
				}
			}

			if ($txtConsoleHint)
			{
				$txtConsoleHint.Text = 'Use the controls below to connect, approve, save policy, and load policy for the current remote context.'
			}

			if ($btnDisconnect) { $btnDisconnect.IsEnabled = [bool]($context -and $context.Connected -and $context.TargetComputers.Count -gt 0) }
			if ($btnApprove) { $btnApprove.IsEnabled = [bool]($context -and $context.Connected -and $context.TargetComputers.Count -gt 0) }
			if ($btnSavePolicy) { $btnSavePolicy.IsEnabled = [bool]($context -and $context.Connected -and $context.TargetComputers.Count -gt 0 -and $context.ApprovedTargetComputers.Count -gt 0) }
			if ($btnLoadPolicy) { $btnLoadPolicy.IsEnabled = [bool]($context -and $context.Connected -and $context.TargetComputers.Count -gt 0) }
			if ($btnPreflight) { $btnPreflight.IsEnabled = [bool]($context -and $context.Connected -and $context.TargetComputers.Count -gt 0) }
		}.GetNewClosure()

		if ($dlgTitleBar) { $dlgTitleBar.Add_MouseLeftButtonDown({ $dlg.DragMove() }.GetNewClosure()) }
		if ($btnDlgClose) { $btnDlgClose.Add_Click({ $dlg.Close() }.GetNewClosure()) }
		if ($btnClose)
		{
			$btnClose.Content = $closeLabel
			Set-ButtonChrome -Button $btnClose -Variant 'Primary' -Compact
			$btnClose.IsDefault = $true
			$btnClose.IsCancel = $true
			$btnClose.Add_Click({ $dlg.Close() }.GetNewClosure())
		}
		if ($btnRefresh)
		{
			$btnRefresh.Content = $refreshLabel
			Set-ButtonChrome -Button $btnRefresh -Variant 'Secondary' -Compact
			$btnRefresh.Add_Click({
				& $refreshConsole
			}.GetNewClosure())
		}
		if ($btnConnect)
		{
			$btnConnect.Content = (Get-UxLocalizedString -Key 'GuiRemoteConnectTitle' -Fallback 'Connect to Computer')
			Set-ButtonChrome -Button $btnConnect -Variant 'Secondary' -Compact
			$btnConnect.Add_Click({
				try
				{
					$request = Invoke-CapturedFunction -Name 'Prompt-GuiRemoteTargetConnection'
					if (-not $request) { return }
					$null = Invoke-CapturedFunction -Name 'Set-GuiRemoteTargetContext' -Parameters @{
						ComputerName = $request.ComputerName
						Credential = $request.Credential
						StatusMessage = 'Remote target connected.'
					}
					& $refreshConsole
				}
				catch
				{
					& $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to connect to remote target.`n`n{0}" -f $_.Exception.Message)
				}
			}.GetNewClosure())
		}
		if ($btnDisconnect)
		{
			$btnDisconnect.Content = (Get-UxLocalizedString -Key 'GuiRemoteDisconnectTitle' -Fallback 'Disconnect')
			Set-ButtonChrome -Button $btnDisconnect -Variant 'Secondary' -Compact
			$btnDisconnect.Add_Click({
				try
				{
					$null = Invoke-CapturedFunction -Name 'Clear-GuiRemoteTargetContext'
					& $refreshConsole
				}
				catch
				{
					& $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to disconnect remote target.`n`n{0}" -f $_.Exception.Message)
				}
			}.GetNewClosure())
		}
		if ($btnApprove)
		{
			$btnApprove.Content = (Get-UxLocalizedString -Key 'GuiMenuToolsApproveRemoteTargets' -Fallback 'Approve Target List...')
			Set-ButtonChrome -Button $btnApprove -Variant 'Secondary' -Compact
			$btnApprove.Add_Click({
				try
				{
					$context = Invoke-CapturedFunction -Name 'Get-GuiRemoteTargetContext'
					if (-not $context -or -not $context.Connected -or $context.TargetComputers.Count -eq 0) { return }
					$targets = @($context.TargetComputers)
					$null = Invoke-CapturedFunction -Name 'Set-GuiRemoteTargetApprovalList' -Parameters @{
						ComputerName = $targets
						ApprovalMessage = 'Remote target list approved from Remote Console.'
					}
					& $refreshConsole
				}
				catch
				{
					& $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to approve target list.`n`n{0}" -f $_.Exception.Message)
				}
			}.GetNewClosure())
		}
		if ($btnSavePolicy)
		{
			$btnSavePolicy.Content = (Get-UxLocalizedString -Key 'GuiMenuToolsSaveRemoteApprovalPolicy' -Fallback 'Save Remote Approval Policy...')
			Set-ButtonChrome -Button $btnSavePolicy -Variant 'Secondary' -Compact
			if (-not $exportRemoteTargetApprovalPolicyCommand) { $btnSavePolicy.IsEnabled = $false }
			$btnSavePolicy.Add_Click({
				if (-not $exportRemoteTargetApprovalPolicyCommand)
				{
					& $showRemoteConsoleError -Title 'Remote Console' -Message 'Remote approval policy export is unavailable in this runtime.'
					return
				}
				try { $null = Invoke-CapturedFunction -Name 'Export-GuiRemoteTargetApprovalPolicy' } catch { & $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to save remote approval policy.`n`n{0}" -f $_.Exception.Message) }
			}.GetNewClosure())
		}
		if ($btnLoadPolicy)
		{
			$btnLoadPolicy.Content = (Get-UxLocalizedString -Key 'GuiMenuToolsLoadRemoteApprovalPolicy' -Fallback 'Load Remote Approval Policy...')
			Set-ButtonChrome -Button $btnLoadPolicy -Variant 'Secondary' -Compact
			if (-not $importRemoteTargetApprovalPolicyCommand) { $btnLoadPolicy.IsEnabled = $false }
			$btnLoadPolicy.Add_Click({
				if (-not $importRemoteTargetApprovalPolicyCommand)
				{
					& $showRemoteConsoleError -Title 'Remote Console' -Message 'Remote approval policy import is unavailable in this runtime.'
					return
				}
				try { $null = Invoke-CapturedFunction -Name 'Import-GuiRemoteTargetApprovalPolicy'; & $refreshConsole } catch { & $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to load remote approval policy.`n`n{0}" -f $_.Exception.Message) }
			}.GetNewClosure())
		}
		if ($btnPreflight)
		{
			$btnPreflight.Content = $preflightLabel
			Set-ButtonChrome -Button $btnPreflight -Variant 'Secondary' -Compact
			$btnPreflight.Add_Click({
				try
				{
					$context = Invoke-CapturedFunction -Name 'Get-GuiRemoteTargetContext'
					if (-not $context -or -not $context.Connected -or $context.TargetComputers.Count -eq 0) { return }
					if (-not (Get-GuiFunctionCapture -Name 'Invoke-PreflightChecks')) { throw 'Preflight helper is not available.' }

					$results = Invoke-CapturedFunction -Name 'Invoke-PreflightChecks' -Parameters @{
						RemoteTargets = @($context.TargetComputers)
					}
					$lines = [System.Collections.Generic.List[string]]::new()
					[void]$lines.Add('Remote preflight results:')
					if ($results -and $results.SupportedEnvironmentClassification -and $results.SupportedEnvironmentClassification.Summary)
					{
						[void]$lines.Add($results.SupportedEnvironmentClassification.Summary)
					}
					if ($results -and $results.WinRMReachability -and $results.WinRMReachability.Summary)
					{
						[void]$lines.Add(('WinRM reachability: {0}' -f $results.WinRMReachability.Summary))
					}
					if ($results -and $results.Credentials -and $results.Credentials.Summary)
					{
						[void]$lines.Add(('Credentials: {0}' -f $results.Credentials.Summary))
					}
					if ($results -and $results.PolicyConflictSignals -and $results.PolicyConflictSignals.Summary)
					{
						[void]$lines.Add(('Policy signals: {0}' -f $results.PolicyConflictSignals.Summary))
					}

					$remoteCategories = @()
					if ($results -and $results.PSObject.Properties['RiskCategories'] -and $results.RiskCategories)
					{
						$remoteCategories = @($results.RiskCategories | Where-Object { $_ -and [string]$_.Status -ne 'Passed' })
					}
					elseif ($results -and $results.PolicyConflictSignals -and $results.PolicyConflictSignals.PSObject.Properties['Categories'])
					{
						$remoteCategories = @($results.PolicyConflictSignals.Categories | Where-Object { $_ -and [string]$_.Status -ne 'Passed' })
					}
					if ($remoteCategories.Count -gt 0)
					{
						[void]$lines.Add(' ')
						[void]$lines.Add('Risk categories:')
						foreach ($cat in $remoteCategories)
						{
							$statusMark = if ([string]$cat.Status -eq 'Failed') { '!' } else { '*' }
							[void]$lines.Add(('{0} {1} ({2}): {3}' -f $statusMark, $cat.Name, $cat.Status, $cat.Summary))
							if ($cat.RemediationActions -and @($cat.RemediationActions).Count -gt 0)
							{
								foreach ($action in $cat.RemediationActions)
								{
									if (-not [string]::IsNullOrWhiteSpace([string]$action))
									{
										[void]$lines.Add(('    -> {0}' -f [string]$action))
									}
								}
							}
							if (-not [string]::IsNullOrWhiteSpace([string]$cat.DocumentationPath))
							{
								[void]$lines.Add(('    Remediation guide: {0}' -f [string]$cat.DocumentationPath))
							}
							if (-not [string]::IsNullOrWhiteSpace([string]$cat.LogHint))
							{
								[void]$lines.Add(('    Logs: {0}' -f [string]$cat.LogHint))
							}
						}
					}

					[void]$lines.Add(' ')
					[void]$lines.Add('Checks:')
					foreach ($result in @($results.AllResults))
					{
						if (-not $result) { continue }
						$line = '{0} -> {1}: {2}' -f $result.Name, $result.Status, $result.Message
						if ($result.PSObject.Properties['Key'] -and -not [string]::IsNullOrWhiteSpace([string]$result.Key))
						{
							$line += " | Key: $($result.Key)"
						}
						if ($result.PSObject.Properties['Category'] -and -not [string]::IsNullOrWhiteSpace([string]$result.Category))
						{
							$line += " | Category: $($result.Category)"
						}
						if ($result.PSObject.Properties['RemediationActions'] -and $result.RemediationActions)
						{
							$actions = @($result.RemediationActions)
							if ($actions.Count -gt 0)
							{
								$line += " | Remediation: $($actions -join '; ')"
							}
						}
						[void]$lines.Add($line)

						if ($result.PSObject.Properties['Details'] -and $result.Details)
						{
							if ($result.Details -is [System.Collections.IDictionary])
							{
								foreach ($detailKey in @($result.Details.Keys | Sort-Object))
								{
									[void]$lines.Add(('  - {0}: {1}' -f $detailKey, $result.Details[$detailKey]))
								}
							}
							elseif ($result.Details.PSObject.Properties.Count -gt 0)
							{
								foreach ($detailProp in @($result.Details.PSObject.Properties | Sort-Object Name))
								{
									[void]$lines.Add(('  - {0}: {1}' -f $detailProp.Name, $detailProp.Value))
								}
							}
						}
					}
					[void](Show-ThemedDialog -Title 'Remote Console Preflight' -Message ($lines -join [Environment]::NewLine) -Buttons @('OK') -AccentButton 'OK')
				}
				catch
				{
					& $showRemoteConsoleError -Title 'Remote Console Preflight' -Message ("Failed to run remote preflight.`n`n{0}" -f $_.Exception.Message)
				}
			}.GetNewClosure())
		}

		$dlg.Add_ContentRendered({
			& $refreshConsole
		})
		$dlg.Add_KeyDown({
			$eventArgs = $args[1]
			if ($eventArgs.Key -eq [System.Windows.Input.Key]::Escape)
			{
				$dlg.Close()
			}
		})

		[void]($dlg.ShowDialog())
		return $null
	}

	<#
	    .SYNOPSIS
	    Internal function Show-GuiOperatorConsoleDialog.

	    .DESCRIPTION
	    Operator-facing safeguards console: per-run cap, concurrency, change
	    window, kill switch, allow/deny lists, and the live policy decision for
	    the currently connected target list. Backed by the OperatorPolicy helpers
	    in Module\SharedHelpers\OperatorPolicy.Helpers.ps1.
	#>

	function Show-GuiOperatorConsoleDialog
	{
		$theme = $Script:CurrentTheme
		if (-not $theme)
		{
			return $null
		}

		$bc = New-SafeBrushConverter -Context 'DialogHelpers-OperatorConsole'
		$windowTitle = Get-UxLocalizedString -Key 'GuiOperatorConsoleTitle' -Fallback 'Operator Console'
		$windowSubtitle = Get-UxLocalizedString -Key 'GuiOperatorConsoleSubtitle' -Fallback 'Multi-target safeguards: caps, change window, kill switch, allow/deny lists.'
		$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'
		$refreshLabel = Get-UxLocalizedString -Key 'GuiRefreshButton' -Fallback 'Refresh'
		$saveLabel = Get-UxLocalizedString -Key 'GuiOperatorPolicySave' -Fallback 'Save Policy...'
		$loadLabel = Get-UxLocalizedString -Key 'GuiOperatorPolicyLoad' -Fallback 'Load Policy...'
		$evaluateLabel = Get-UxLocalizedString -Key 'GuiOperatorPolicyEvaluate' -Fallback 'Evaluate'
		$killEngageLabel = Get-UxLocalizedString -Key 'GuiOperatorKillEngage' -Fallback 'Engage Kill Switch'
		$killClearLabel = Get-UxLocalizedString -Key 'GuiOperatorKillClear' -Fallback 'Clear Kill Switch'

		[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$windowTitle"
	Width="940" Height="680"
	MinWidth="780" MinHeight="600"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="FluentSystemIcons"
	FontSize="12"
	Background="Transparent"
	WindowStyle="None"
	AllowsTransparency="True">
	<Border Name="RootBorder" CornerRadius="8">
		<Grid>
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="*"/>
				<RowDefinition Height="Auto"/>
			</Grid.RowDefinitions>

			<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="12,8,8,8" Cursor="Arrow">
				<Grid>
					<TextBlock Text="$windowTitle" VerticalAlignment="Center" FontSize="12" Foreground="$($theme.TextPrimary)"/>
					<Button Name="BtnDlgClose" Content="x" FontFamily="Arial" FontSize="12" Width="32" Height="28"
						Background="Transparent" Foreground="$($theme.TextPrimary)" BorderThickness="0" Cursor="Hand"
						HorizontalAlignment="Right" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
				</Grid>
			</Border>

			<Border Grid.Row="1" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,0,0,1"
					Padding="20,14,20,14">
				<StackPanel>
					<TextBlock Name="TxtDialogTitle" Text="$windowTitle" FontSize="16" FontWeight="SemiBold"
							   Foreground="$($theme.TextPrimary)"/>
					<TextBlock Name="TxtDialogSubtitle" Text="$windowSubtitle"
							   FontSize="12" Foreground="$($theme.TextMuted)" Margin="0,2,0,0" TextWrapping="Wrap"/>
				</StackPanel>
			</Border>

			<ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="20,16,20,16">
				<Grid>
					<Grid.RowDefinitions>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
					</Grid.RowDefinitions>

					<!-- Caps -->
					<Border Grid.Row="0" Background="$($theme.InputBg)" BorderBrush="$($theme.BorderColor)" BorderThickness="1" CornerRadius="6" Padding="14,12,14,12" Margin="0,0,0,12">
						<Grid>
							<Grid.ColumnDefinitions>
								<ColumnDefinition Width="*"/>
								<ColumnDefinition Width="*"/>
							</Grid.ColumnDefinitions>
							<StackPanel Grid.Column="0">
								<TextBlock Text="Per-run target cap" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
								<TextBox Name="TxtMaxTargets" Margin="0,4,8,0" Padding="6,4,6,4"/>
							</StackPanel>
							<StackPanel Grid.Column="1">
								<TextBlock Text="Max concurrent targets" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
								<TextBox Name="TxtMaxConcurrent" Margin="0,4,0,0" Padding="6,4,6,4"/>
							</StackPanel>
						</Grid>
					</Border>

					<!-- Change window -->
					<Border Grid.Row="1" Background="$($theme.InputBg)" BorderBrush="$($theme.BorderColor)" BorderThickness="1" CornerRadius="6" Padding="14,12,14,12" Margin="0,0,0,12">
						<StackPanel>
							<TextBlock Text="Change window" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
							<TextBlock Name="TxtChangeWindowHint" Text="Comma-separated days (Mon,Tue,...) and HH:mm start/end. Empty = always allowed." Foreground="$($theme.TextMuted)" TextWrapping="Wrap" Margin="0,2,0,6"/>
							<Grid>
								<Grid.ColumnDefinitions>
									<ColumnDefinition Width="2*"/>
									<ColumnDefinition Width="*"/>
									<ColumnDefinition Width="*"/>
								</Grid.ColumnDefinitions>
								<TextBox Name="TxtChangeDays" Margin="0,0,8,0" Padding="6,4,6,4"/>
								<TextBox Name="TxtChangeStart" Grid.Column="1" Margin="0,0,8,0" Padding="6,4,6,4"/>
								<TextBox Name="TxtChangeEnd" Grid.Column="2" Padding="6,4,6,4"/>
							</Grid>
							<TextBlock Name="TxtChangeWindowState" Text="" Foreground="$($theme.TextSecondary)" Margin="0,8,0,0" TextWrapping="Wrap"/>
						</StackPanel>
					</Border>

					<!-- Allow/Deny -->
					<Border Grid.Row="2" Background="$($theme.InputBg)" BorderBrush="$($theme.BorderColor)" BorderThickness="1" CornerRadius="6" Padding="14,12,14,12" Margin="0,0,0,12">
						<Grid>
							<Grid.ColumnDefinitions>
								<ColumnDefinition Width="*"/>
								<ColumnDefinition Width="*"/>
								<ColumnDefinition Width="*"/>
							</Grid.ColumnDefinitions>
							<StackPanel Grid.Column="0">
								<TextBlock Text="Allowed targets (one per line, empty = all)" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
								<TextBox Name="TxtAllowedTargets" Margin="0,4,8,0" Padding="6,4,6,4" Height="80" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
							</StackPanel>
							<StackPanel Grid.Column="1">
								<TextBlock Text="Denied targets (one per line)" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
								<TextBox Name="TxtDeniedTargets" Margin="0,4,8,0" Padding="6,4,6,4" Height="80" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
							</StackPanel>
							<StackPanel Grid.Column="2">
								<TextBlock Text="Denied functions (one per line)" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
								<TextBox Name="TxtDeniedFunctions" Margin="0,4,0,0" Padding="6,4,6,4" Height="80" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
							</StackPanel>
						</Grid>
					</Border>

					<!-- Kill switch -->
					<Border Grid.Row="3" Background="$($theme.InputBg)" BorderBrush="$($theme.BorderColor)" BorderThickness="1" CornerRadius="6" Padding="14,12,14,12" Margin="0,0,0,12">
						<StackPanel>
							<TextBlock Text="Kill switch" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
							<TextBlock Name="TxtKillSwitchPath" Text="" Foreground="$($theme.TextMuted)" Margin="0,2,0,6" TextWrapping="Wrap"/>
							<TextBlock Name="TxtKillSwitchState" Text="" Foreground="$($theme.TextSecondary)" Margin="0,0,0,8" TextWrapping="Wrap"/>
							<WrapPanel>
								<Button Name="BtnKillEngage" Content="" Margin="0,0,8,0" Padding="14,6"/>
								<Button Name="BtnKillClear" Content="" Padding="14,6"/>
							</WrapPanel>
						</StackPanel>
					</Border>

					<!-- Decision -->
					<Border Grid.Row="4" Background="$($theme.InputBg)" BorderBrush="$($theme.BorderColor)" BorderThickness="1" CornerRadius="6" Padding="14,12,14,12">
						<StackPanel>
							<TextBlock Text="Current policy decision" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
							<TextBlock Name="TxtDecisionTargets" Text="" Foreground="$($theme.TextMuted)" Margin="0,2,0,6" TextWrapping="Wrap"/>
							<TextBlock Name="TxtDecisionSummary" Text="" FontFamily="Consolas, Menlo, monospace" Foreground="$($theme.TextPrimary)" TextWrapping="Wrap"/>
						</StackPanel>
					</Border>
				</Grid>
			</ScrollViewer>

			<Border Grid.Row="3" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0"
					Padding="20,10,20,10">
				<WrapPanel HorizontalAlignment="Right">
					<Button Name="BtnEvaluate" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnSavePolicy" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnLoadPolicy" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnRefresh" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnClose" Content="" Padding="16,6" FontSize="13"/>
				</WrapPanel>
			</Border>
		</Grid>
	</Border>
</Window>
"@

		$reader = [System.Xml.XmlNodeReader]::new($xaml)
		$dlg = [Windows.Markup.XamlReader]::Load($reader)
		$dlg.Owner = $Form

		$rootBorder = $dlg.FindName('RootBorder')
		if ($rootBorder)
		{
			$rootBorder.Background = $bc.ConvertFromString($theme.WindowBg)
			$rootBorder.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
			$rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
		}

		[void](GUICommon\Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))

		$dlgTitleBar       = $dlg.FindName('DlgTitleBar')
		$btnDlgClose       = $dlg.FindName('BtnDlgClose')
		$txtMaxTargets     = $dlg.FindName('TxtMaxTargets')
		$txtMaxConcurrent  = $dlg.FindName('TxtMaxConcurrent')
		$txtChangeDays     = $dlg.FindName('TxtChangeDays')
		$txtChangeStart    = $dlg.FindName('TxtChangeStart')
		$txtChangeEnd      = $dlg.FindName('TxtChangeEnd')
		$txtChangeState    = $dlg.FindName('TxtChangeWindowState')
		$txtAllowed        = $dlg.FindName('TxtAllowedTargets')
		$txtDenied         = $dlg.FindName('TxtDeniedTargets')
		$txtDeniedFns      = $dlg.FindName('TxtDeniedFunctions')
		$txtKillPath       = $dlg.FindName('TxtKillSwitchPath')
		$txtKillState      = $dlg.FindName('TxtKillSwitchState')
		$txtDecisionTgts   = $dlg.FindName('TxtDecisionTargets')
		$txtDecisionSummary= $dlg.FindName('TxtDecisionSummary')
		$btnKillEngage     = $dlg.FindName('BtnKillEngage')
		$btnKillClear      = $dlg.FindName('BtnKillClear')
		$btnEvaluate       = $dlg.FindName('BtnEvaluate')
		$btnSavePolicy     = $dlg.FindName('BtnSavePolicy')
		$btnLoadPolicy     = $dlg.FindName('BtnLoadPolicy')
		$btnRefresh        = $dlg.FindName('BtnRefresh')
		$btnClose          = $dlg.FindName('BtnClose')

		# Resolve helpers via runtime command lookup so this dialog stays
		# loadable in test harnesses where SharedHelpers may not be imported.
		$newPolicyCmd     = Get-GuiRuntimeCommand -Name 'New-BaselineOperatorPolicy' -CommandType 'Function'
		$testRunCmd       = Get-GuiRuntimeCommand -Name 'Test-BaselineOperatorRunPolicy' -CommandType 'Function'
		$formatDecisionCmd= Get-GuiRuntimeCommand -Name 'Format-BaselineOperatorPolicyDecision' -CommandType 'Function'
		$testKillCmd      = Get-GuiRuntimeCommand -Name 'Test-BaselineKillSwitch' -CommandType 'Function'
		$engageKillCmd    = Get-GuiRuntimeCommand -Name 'Invoke-BaselineKillSwitch' -CommandType 'Function'
		$clearKillCmd     = Get-GuiRuntimeCommand -Name 'Clear-BaselineKillSwitch' -CommandType 'Function'
		$getRemoteCtxCmd  = Get-GuiRuntimeCommand -Name 'Get-GuiRemoteTargetContext' -CommandType 'Function'

		# Per-dialog policy state. We seed from the helper defaults so the
		# operator sees the same caps the CLI honours.
		$policy = $null
		try { $policy = & $newPolicyCmd } catch { $policy = [pscustomobject]@{ MaxTargetsPerRun = 25; MaxConcurrentTargets = 5; DeniedFunctions = @(); DeniedTargets = @(); AllowedTargets = @(); ChangeWindow = @{}; KillSwitchPath = (Join-Path ([System.IO.Path]::GetTempPath()) 'BASELINE_KILL_SWITCH'); CreatedAt = [DateTimeOffset]::UtcNow } }

		$splitLines = {
			param([string]$Text)
			if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
			$arr = [System.Collections.Generic.List[string]]::new()
			foreach ($l in ($Text -split "`r?`n"))
			{
				$t = $l.Trim()
				if (-not [string]::IsNullOrWhiteSpace($t)) { [void]$arr.Add($t) }
			}
			return ,$arr.ToArray()
		}

		$loadPolicyIntoUi = {
			param($p)
			if (-not $p) { return }
			if ($txtMaxTargets) { $txtMaxTargets.Text = [string]$p.MaxTargetsPerRun }
			if ($txtMaxConcurrent) { $txtMaxConcurrent.Text = [string]$p.MaxConcurrentTargets }
			if ($txtAllowed) { $txtAllowed.Text = (@($p.AllowedTargets) -join [Environment]::NewLine) }
			if ($txtDenied) { $txtDenied.Text = (@($p.DeniedTargets) -join [Environment]::NewLine) }
			if ($txtDeniedFns) { $txtDeniedFns.Text = (@($p.DeniedFunctions) -join [Environment]::NewLine) }
			if ($txtKillPath) { $txtKillPath.Text = ('Sentinel: {0}' -f $p.KillSwitchPath) }
			$cw = $p.ChangeWindow
			if ($cw -and $cw.Count -gt 0)
			{
				if ($txtChangeDays) { $txtChangeDays.Text = if ($cw['Days']) { (@($cw['Days']) -join ',') } else { '' } }
				if ($txtChangeStart) { $txtChangeStart.Text = if ($cw['StartTime']) { [string]$cw['StartTime'] } else { '' } }
				if ($txtChangeEnd) { $txtChangeEnd.Text = if ($cw['EndTime']) { [string]$cw['EndTime'] } else { '' } }
			}
		}.GetNewClosure()

		$readPolicyFromUi = {
			$max = 25; $conc = 5
			if ($txtMaxTargets -and -not [string]::IsNullOrWhiteSpace($txtMaxTargets.Text)) { [void][int]::TryParse($txtMaxTargets.Text, [ref]$max) }
			if ($txtMaxConcurrent -and -not [string]::IsNullOrWhiteSpace($txtMaxConcurrent.Text)) { [void][int]::TryParse($txtMaxConcurrent.Text, [ref]$conc) }

			$allowed = if ($txtAllowed) { & $splitLines $txtAllowed.Text } else { @() }
			$denied  = if ($txtDenied) { & $splitLines $txtDenied.Text } else { @() }
			$dfns    = if ($txtDeniedFns) { & $splitLines $txtDeniedFns.Text } else { @() }

			$cw = @{}
			$daysText = if ($txtChangeDays) { $txtChangeDays.Text } else { '' }
			if (-not [string]::IsNullOrWhiteSpace($daysText))
			{
				$days = @(($daysText -split ',') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
				if ($days.Count -gt 0) { $cw['Days'] = $days }
			}
			$startText = if ($txtChangeStart) { $txtChangeStart.Text.Trim() } else { '' }
			$endText   = if ($txtChangeEnd) { $txtChangeEnd.Text.Trim() } else { '' }
			if (-not [string]::IsNullOrWhiteSpace($startText) -and -not [string]::IsNullOrWhiteSpace($endText))
			{
				$cw['StartTime'] = $startText
				$cw['EndTime']   = $endText
			}

			return (& $newPolicyCmd -MaxTargetsPerRun $max -MaxConcurrentTargets $conc -DeniedFunctions $dfns -DeniedTargets $denied -AllowedTargets $allowed -ChangeWindow $cw)
		}.GetNewClosure()

		$refreshKillState = {
			if (-not $policy) { return }
			$engaged = $false
			try { $engaged = [bool](& $testKillCmd -Path $policy.KillSwitchPath) } catch { $engaged = $false }
			if ($txtKillState) { $txtKillState.Text = if ($engaged) { 'Status: ENGAGED - new runs will be blocked.' } else { 'Status: clear - runs allowed.' } }
			if ($btnKillEngage) { $btnKillEngage.IsEnabled = -not $engaged }
			if ($btnKillClear) { $btnKillClear.IsEnabled = $engaged }
		}.GetNewClosure()

		$evaluateDecision = {
			$policy = & $readPolicyFromUi
			$targets = @()
			try
			{
				$ctx = & $getRemoteCtxCmd
				if ($ctx -and $ctx.Connected -and $ctx.TargetComputers) { $targets = @($ctx.TargetComputers) }
			}
			catch { $targets = @() }

			if ($txtDecisionTgts)
			{
				$txtDecisionTgts.Text = if ($targets.Count -gt 0) { ('Planned targets: {0}' -f ($targets -join ', ')) } else { 'Planned targets: none (connect or stage targets in Remote Console).' }
			}

			if ($targets.Count -eq 0)
			{
				if ($txtDecisionSummary) { $txtDecisionSummary.Text = 'No planned targets - decision evaluation skipped.' }
				return
			}

			try
			{
				$decision = & $testRunCmd -Policy $policy -Targets $targets -Apply:$true
				if ($txtDecisionSummary) { $txtDecisionSummary.Text = (& $formatDecisionCmd -Decision $decision) }
			}
			catch
			{
				if ($txtDecisionSummary) { $txtDecisionSummary.Text = ('Failed to evaluate policy: {0}' -f $_.Exception.Message) }
			}
		}.GetNewClosure()

		$refreshAll = {
			& $loadPolicyIntoUi $policy
			& $refreshKillState
			if ($txtChangeState) { $txtChangeState.Text = 'Empty values mean the change window is always allowed.' }
			& $evaluateDecision
		}.GetNewClosure()

		if ($dlgTitleBar) { $dlgTitleBar.Add_MouseLeftButtonDown({ $dlg.DragMove() }.GetNewClosure()) }
		if ($btnDlgClose) { $btnDlgClose.Add_Click({ $dlg.Close() }.GetNewClosure()) }
		if ($btnClose)
		{
			$btnClose.Content = $closeLabel
			Set-ButtonChrome -Button $btnClose -Variant 'Primary' -Compact
			$btnClose.IsDefault = $true
			$btnClose.IsCancel = $true
			$btnClose.Add_Click({ $dlg.Close() }.GetNewClosure())
		}
		if ($btnRefresh)
		{
			$btnRefresh.Content = $refreshLabel
			Set-ButtonChrome -Button $btnRefresh -Variant 'Secondary' -Compact
			$btnRefresh.Add_Click({ & $refreshAll }.GetNewClosure())
		}
		if ($btnEvaluate)
		{
			$btnEvaluate.Content = $evaluateLabel
			Set-ButtonChrome -Button $btnEvaluate -Variant 'Secondary' -Compact
			$btnEvaluate.Add_Click({ & $evaluateDecision }.GetNewClosure())
		}
		if ($btnKillEngage)
		{
			$btnKillEngage.Content = $killEngageLabel
			Set-ButtonChrome -Button $btnKillEngage -Variant 'Secondary' -Compact
			$btnKillEngage.Add_Click({
				try { $script:policy = & $readPolicyFromUi; & $engageKillCmd -Path $script:policy.KillSwitchPath -Reason 'Operator console' } catch { [void](Show-ThemedDialog -Title 'Operator Console' -Message ("Failed to engage kill switch.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK') }
				& $refreshKillState
				& $evaluateDecision
			}.GetNewClosure())
		}
		if ($btnKillClear)
		{
			$btnKillClear.Content = $killClearLabel
			Set-ButtonChrome -Button $btnKillClear -Variant 'Secondary' -Compact
			$btnKillClear.Add_Click({
				try { $script:policy = & $readPolicyFromUi; & $clearKillCmd -Path $script:policy.KillSwitchPath } catch { [void](Show-ThemedDialog -Title 'Operator Console' -Message ("Failed to clear kill switch.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK') }
				& $refreshKillState
				& $evaluateDecision
			}.GetNewClosure())
		}
		if ($btnSavePolicy)
		{
			$btnSavePolicy.Content = $saveLabel
			Set-ButtonChrome -Button $btnSavePolicy -Variant 'Secondary' -Compact
			$btnSavePolicy.Add_Click({
				$dialog = New-Object Microsoft.Win32.SaveFileDialog
				$dialog.Title = $saveLabel
				$dialog.Filter = 'Operator Policy (*.json)|*.json|All Files (*.*)|*.*'
				$dialog.DefaultExt = 'json'
				$dialog.FileName = ('Baseline-OperatorPolicy-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
				if ($dialog.ShowDialog($dlg) -ne $true) { return }
				try
				{
					$current = & $readPolicyFromUi
					$payload = [ordered]@{
						MaxTargetsPerRun     = [int]$current.MaxTargetsPerRun
						MaxConcurrentTargets = [int]$current.MaxConcurrentTargets
						DeniedFunctions      = @($current.DeniedFunctions)
						DeniedTargets        = @($current.DeniedTargets)
						AllowedTargets       = @($current.AllowedTargets)
						ChangeWindow         = $current.ChangeWindow
						KillSwitchPath       = [string]$current.KillSwitchPath
					}
					$json = ConvertTo-Json -InputObject $payload -Depth 6
					[System.IO.File]::WriteAllText($dialog.FileName, $json)
				}
				catch
				{
					[void](Show-ThemedDialog -Title 'Operator Console' -Message ("Failed to save operator policy.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
				}
			}.GetNewClosure())
		}
		if ($btnLoadPolicy)
		{
			$btnLoadPolicy.Content = $loadLabel
			Set-ButtonChrome -Button $btnLoadPolicy -Variant 'Secondary' -Compact
			$btnLoadPolicy.Add_Click({
				$dialog = New-Object Microsoft.Win32.OpenFileDialog
				$dialog.Title = $loadLabel
				$dialog.Filter = 'Operator Policy (*.json)|*.json|All Files (*.*)|*.*'
				if ($dialog.ShowDialog($dlg) -ne $true) { return }
				try
				{
					$raw = Get-Content -LiteralPath $dialog.FileName -Raw -Encoding UTF8 | ConvertFrom-BaselineJson -Depth 16 -ErrorAction Stop
					$cw = @{}
					if ($raw.ChangeWindow)
					{
						foreach ($prop in $raw.ChangeWindow.PSObject.Properties) { $cw[$prop.Name] = $prop.Value }
					}
					$script:policy = & $newPolicyCmd `
						-MaxTargetsPerRun ([int]$raw.MaxTargetsPerRun) `
						-MaxConcurrentTargets ([int]$raw.MaxConcurrentTargets) `
						-DeniedFunctions @($raw.DeniedFunctions) `
						-DeniedTargets @($raw.DeniedTargets) `
						-AllowedTargets @($raw.AllowedTargets) `
						-ChangeWindow $cw
					if ($raw.KillSwitchPath -and -not [string]::IsNullOrWhiteSpace([string]$raw.KillSwitchPath))
					{
						$script:policy.KillSwitchPath = [string]$raw.KillSwitchPath
					}
					& $refreshAll
				}
				catch
				{
					[void](Show-ThemedDialog -Title 'Operator Console' -Message ("Failed to load operator policy.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
				}
			}.GetNewClosure())
		}

		$dlg.Add_ContentRendered({ & $refreshAll })
		$dlg.Add_KeyDown({
			$eventArgs = $args[1]
			if ($eventArgs.Key -eq [System.Windows.Input.Key]::Escape) { $dlg.Close() }
		})

		[void]($dlg.ShowDialog())
		return $null
	}

	<#
	    .SYNOPSIS
	    Internal function Show-GuiHistoryViewerDialog.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline. Shows historical run
	    data with query, filter, and export capabilities.
	#>

	function Show-GuiHistoryViewerDialog
	{
		$theme = $Script:CurrentTheme
		if (-not $theme)
		{
			return $null
		}

		$bc = New-SafeBrushConverter -Context 'DialogHelpers-HistoryViewer'
		$windowTitle = Get-UxLocalizedString -Key 'GuiHistoryViewerTitle' -Fallback 'History Viewer'
		$windowSubtitle = Get-UxLocalizedString -Key 'GuiHistoryViewerSubtitle' -Fallback 'Review, query, and export historical run data.'
		$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'
		$refreshLabel = Get-UxLocalizedString -Key 'GuiRefreshButton' -Fallback 'Refresh'
		$viewDetailsLabel = Get-UxLocalizedString -Key 'GuiHistoryViewDetails' -Fallback 'View Details...'
		$exportBundleLabel = Get-UxLocalizedString -Key 'GuiHistoryExportBundle' -Fallback 'Export Bundle...'

		[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$windowTitle"
	Width="960" Height="720"
	MinWidth="800" MinHeight="600"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="FluentSystemIcons"
	FontSize="12"
	Background="Transparent"
	WindowStyle="None"
	AllowsTransparency="True">
	<Border Name="RootBorder" CornerRadius="8">
		<Grid>
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="*"/>
				<RowDefinition Height="Auto"/>
			</Grid.RowDefinitions>

			<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="12,8,8,8" Cursor="Arrow">
				<Grid>
					<TextBlock Text="$windowTitle" VerticalAlignment="Center" FontSize="12" Foreground="$($theme.TextPrimary)"/>
					<Button Name="BtnDlgClose" Content="x" FontFamily="Arial" FontSize="12" Width="32" Height="28"
						Background="Transparent" Foreground="$($theme.TextPrimary)" BorderThickness="0" Cursor="Hand"
						HorizontalAlignment="Right" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
				</Grid>
			</Border>

			<Border Grid.Row="1" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,0,0,1"
					Padding="20,14,20,14">
				<StackPanel>
					<TextBlock Name="TxtDialogTitle" Text="$windowTitle" FontSize="16" FontWeight="SemiBold"
							   Foreground="$($theme.TextPrimary)"/>
					<TextBlock Name="TxtDialogSubtitle" Text="$windowSubtitle"
							   FontSize="12" Foreground="$($theme.TextMuted)" Margin="0,2,0,0" TextWrapping="Wrap"/>
				</StackPanel>
			</Border>

			<Grid Grid.Row="2" Margin="20,16,20,16">
				<Grid.RowDefinitions>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="*"/>
					<RowDefinition Height="Auto"/>
				</Grid.RowDefinitions>

				<Grid Grid.Row="0" Margin="0,0,0,12">
					<Grid.ColumnDefinitions>
						<ColumnDefinition Width="*"/>
						<ColumnDefinition Width="Auto"/>
					</Grid.ColumnDefinitions>
					<TextBox Name="TxtSearch" Grid.Column="0" Padding="6,4,6,4" VerticalContentAlignment="Center"/>
					<Button Name="BtnRefresh" Grid.Column="1" Content="$refreshLabel" Margin="8,0,0,0" Padding="16,6" FontSize="13"/>
				</Grid>

				<ListView Name="HistoryList" Grid.Row="1" BorderThickness="1" BorderBrush="$($theme.BorderColor)">
					<ListView.View>
						<GridView>
							<GridViewColumn Header="Date" Width="160" DisplayMemberBinding="{Binding Timestamp, StringFormat='yyyy-MM-dd HH:mm:ss'}"/>
							<GridViewColumn Header="Operation" Width="120" DisplayMemberBinding="{Binding Operation}"/>
							<GridViewColumn Header="Targets" Width="180" DisplayMemberBinding="{Binding Targets}"/>
							<GridViewColumn Header="Result" Width="100" DisplayMemberBinding="{Binding Result}"/>
							<GridViewColumn Header="Summary" Width="350" DisplayMemberBinding="{Binding Summary}"/>
						</GridView>
					</ListView.View>
				</ListView>

				<TextBlock Name="TxtStatus" Grid.Row="2" Margin="0,8,0,0" Foreground="$($theme.TextMuted)"/>
			</Grid>

			<Border Grid.Row="3" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0"
					Padding="20,10,20,10">
				<WrapPanel HorizontalAlignment="Right">
					<Button Name="BtnViewDetails" Content="$viewDetailsLabel" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnExportBundle" Content="$exportBundleLabel" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnClose" Content="$closeLabel" Padding="16,6" FontSize="13"/>
				</WrapPanel>
			</Border>
		</Grid>
	</Border>
</Window>
"@

		$reader = [System.Xml.XmlNodeReader]::new($xaml)
		$dlg = [Windows.Markup.XamlReader]::Load($reader)
		$dlg.Owner = $Form

		$rootBorder = $dlg.FindName('RootBorder')
		if ($rootBorder)
		{
			$rootBorder.Background = $bc.ConvertFromString($theme.WindowBg)
			$rootBorder.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
			$rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
		}

		[void](GUICommon\Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))

		$dlgTitleBar     = $dlg.FindName('DlgTitleBar')
		$btnDlgClose     = $dlg.FindName('BtnDlgClose')
		$txtSearch       = $dlg.FindName('TxtSearch')
		$historyList     = $dlg.FindName('HistoryList')
		$txtStatus       = $dlg.FindName('TxtStatus')
		$btnRefresh      = $dlg.FindName('BtnRefresh')
		$btnViewDetails  = $dlg.FindName('BtnViewDetails')
		$btnExportBundle = $dlg.FindName('BtnExportBundle')
		$btnClose        = $dlg.FindName('BtnClose')

		$getHistoryCmd = Get-GuiRuntimeCommand -Name 'Get-BaselineRemoteOrchestrationDetails' -CommandType 'Function'
		$allHistoryItems = @()

		$updateActionButtons = {
			$selected = $historyList.SelectedItem
			if ($btnViewDetails) { $btnViewDetails.IsEnabled = ($null -ne $selected -and (Test-GuiObjectField -Object $selected -FieldName 'LogPath') -and -not [string]::IsNullOrWhiteSpace($selected.LogPath)) }
			if ($btnExportBundle) { $btnExportBundle.IsEnabled = ($null -ne $selected -and (Test-GuiObjectField -Object $selected -FieldName 'BundlePath') -and -not [string]::IsNullOrWhiteSpace($selected.BundlePath)) }
		}.GetNewClosure()

		$refreshHistory = {
			if (-not $getHistoryCmd)
			{
				$historyList.ItemsSource = @()
				$txtStatus.Text = 'History query service is not available.'
				return
			}

			try
			{
				$script:allHistoryItems = @((& $getHistoryCmd))
			}
			catch
			{
				$script:allHistoryItems = @()
				$txtStatus.Text = "Failed to load history: $($_.Exception.Message)"
			}

			$filterText = $txtSearch.Text
			$filteredItems = if ([string]::IsNullOrWhiteSpace($filterText))
			{
				$script:allHistoryItems
			}
			else
			{
				@($script:allHistoryItems | Where-Object {
					$_.Targets -match $filterText -or
					$_.Operation -match $filterText -or
					$_.Result -match $filterText -or
					$_.Summary -match $filterText
				})
			}

			$historyList.ItemsSource = $filteredItems
			if ($filteredItems.Count -eq 0)
			{
				$txtStatus.Text = (Get-UxLocalizedString -Key 'GuiHistoryNoRunsFound' -Fallback 'No historical runs found.')
			}
			else
			{
				$txtStatus.Text = (Get-UxLocalizedString -Key 'GuiHistoryStatus' -Fallback 'Showing {0} of {1} runs.' -FormatArgs @($filteredItems.Count, $script:allHistoryItems.Count))
			}
			& $updateActionButtons
		}.GetNewClosure()

		if ($dlgTitleBar) { $dlgTitleBar.Add_MouseLeftButtonDown({ $dlg.DragMove() }.GetNewClosure()) }
		if ($btnDlgClose) { $btnDlgClose.Add_Click({ $dlg.Close() }.GetNewClosure()) }

		if ($txtSearch)
		{
			$txtSearch.Add_TextChanged({ & $refreshHistory }.GetNewClosure())
			if (Get-Command -Name 'Set-GuiWatermarkText' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Set-GuiWatermarkText -TextBox $txtSearch -Text (Get-UxLocalizedString -Key 'GuiHistoryFilterByTarget' -Fallback 'Filter by target, operation, result...')
			}
		}

		if ($historyList)
		{
			$historyList.Add_SelectionChanged({ & $updateActionButtons }.GetNewClosure())
		}

		if ($btnRefresh)
		{
			Set-ButtonChrome -Button $btnRefresh -Variant 'Secondary' -Compact
			$btnRefresh.Add_Click({ & $refreshHistory }.GetNewClosure())
		}

		if ($btnViewDetails)
		{
			Set-ButtonChrome -Button $btnViewDetails -Variant 'Secondary' -Compact
			$btnViewDetails.Add_Click({
				$selected = $historyList.SelectedItem
				if ($null -ne $selected -and (Test-GuiObjectField -Object $selected -FieldName 'LogPath') -and -not [string]::IsNullOrWhiteSpace($selected.LogPath))
				{
					Show-LogDialog -LogPath $selected.LogPath
				}
			}.GetNewClosure())
		}

		if ($btnExportBundle)
		{
			Set-ButtonChrome -Button $btnExportBundle -Variant 'Secondary' -Compact
			$btnExportBundle.Add_Click({
				$selected = $historyList.SelectedItem
				if ($null -ne $selected -and (Test-GuiObjectField -Object $selected -FieldName 'BundlePath') -and -not [string]::IsNullOrWhiteSpace($selected.BundlePath))
				{
					try { [System.Diagnostics.Process]::Start($selected.BundlePath) } catch { [void](Show-ThemedDialog -Title $windowTitle -Message "Failed to open bundle: $($_.Exception.Message)") }
				}
			}.GetNewClosure())
		}

		if ($btnClose)
		{
			Set-ButtonChrome -Button $btnClose -Variant 'Primary' -Compact
			$btnClose.IsDefault = $true
			$btnClose.IsCancel = $true
			$btnClose.Add_Click({ $dlg.Close() }.GetNewClosure())
		}

		$dlg.Add_ContentRendered({ & $refreshHistory })
		$dlg.Add_KeyDown({
			param($s, $e)
			if ($e.Key -eq [System.Windows.Input.Key]::Escape) { $dlg.Close() }
		})

		[void]($dlg.ShowDialog())
		return $null
	}

	<#
	    .SYNOPSIS
	    Internal function Show-GuiReleaseStatusDialog.
	#>

	function Show-GuiReleaseStatusDialog
	{
		$theme = $Script:CurrentTheme
		if (-not $theme)
		{
			return $null
		}

		$bc = New-SafeBrushConverter -Context 'DialogHelpers-ReleaseStatus'
		$windowTitle = Get-UxLocalizedString -Key 'GuiReleaseStatusTitle' -Fallback 'Release Status'
		$windowSubtitle = Get-UxLocalizedString -Key 'GuiReleaseStatusSubtitle' -Fallback 'Current build, signing, and artifact posture.'
		$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'
		$resolvedModuleRoot = $null
		$resolvedRepoRoot = $null
		try
		{
			if (-not [string]::IsNullOrWhiteSpace([string]$Script:SharedHelpersModuleRoot))
			{
				$resolvedModuleRoot = [string]$Script:SharedHelpersModuleRoot
			}
			elseif ($PSScriptRoot)
			{
				$resolvedModuleRoot = Split-Path -Parent $PSScriptRoot
			}
		}
		catch { }
		try
		{
			if (-not [string]::IsNullOrWhiteSpace([string]$Script:SharedHelpersRepoRoot))
			{
				$resolvedRepoRoot = [string]$Script:SharedHelpersRepoRoot
			}
			elseif ($resolvedModuleRoot)
			{
				$resolvedRepoRoot = Split-Path -Parent $resolvedModuleRoot
			}
			elseif ($PSScriptRoot)
			{
				$resolvedRepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
			}
		}
		catch { }

		$version = 'unknown'
		try { $version = Get-BaselineDisplayVersion } catch { }
		$moduleManifestPath = if ($resolvedModuleRoot) { Join-Path $resolvedModuleRoot 'Baseline.psd1' } else { $null }
		$manifestText = if ($moduleManifestPath -and (Test-Path -LiteralPath $moduleManifestPath)) { Get-Content -LiteralPath $moduleManifestPath -Raw -Encoding UTF8 } else { $null }
		$prerelease = if ($manifestText -match "Prerelease\s*=\s*'([^']+)'") { $Matches[1] } else { 'unknown' }
		$iconStatus = 'Unknown'
		$iconFontPath = $null
		try
		{
			if (Get-Command -Name 'Test-GuiIconsAvailable' -CommandType Function -ErrorAction SilentlyContinue)
			{
				$iconStatus = if (Test-GuiIconsAvailable) { 'Enabled' } else { 'Fallback' }
			}
			if (Get-Command -Name 'Get-GuiIconFontPath' -CommandType Function -ErrorAction SilentlyContinue)
			{
				if ($resolvedRepoRoot)
				{
					$iconFontPath = Get-GuiIconFontPath -ModuleRoot $resolvedRepoRoot
				}
			}
		}
		catch
		{
			$iconStatus = 'Unknown'
		}
		$matrixSummary = 'Unavailable'
		$serverValidationSummary = 'Unavailable'
		try
		{
			if (Get-Command -Name 'Get-BaselineValidationMatrixSummary' -CommandType Function -ErrorAction SilentlyContinue)
			{
				$matrix = Get-BaselineValidationMatrixSummary -RepoRoot $resolvedRepoRoot
				if ($matrix)
				{
					if ($matrix.Summary)
					{
						$matrixSummary = [string]$matrix.Summary
					}
					if ($matrix.ServerValidationSummary)
					{
						$serverValidationSummary = [string]$matrix.ServerValidationSummary
					}
				}
			}
		}
		catch
		{
			$matrixSummary = 'Unavailable'
			$serverValidationSummary = 'Unavailable'
		}
		$validationEvidenceSummary = 'Unavailable'
		$validationEvidenceChannels = 'Unavailable'
		$validationEvidenceProvenance = 'Unavailable'
		try
		{
			if (Get-Command -Name 'Get-BaselineValidationEvidenceReport' -CommandType Function -ErrorAction SilentlyContinue)
			{
				$validationEvidence = Get-BaselineValidationEvidenceReport -RepoRoot $resolvedRepoRoot
				if ($validationEvidence)
				{
					if ($validationEvidence.Summary)
					{
						$validationEvidenceSummary = [string]$validationEvidence.Summary
					}
					if ($validationEvidence.ValidationChannels)
					{
						$validationEvidenceChannels = (@($validationEvidence.ValidationChannels | ForEach-Object { [string]$_.Channel }) -join ', ')
					}

					$provenanceParts = [System.Collections.Generic.List[string]]::new()
					if ($validationEvidence.Build)
					{
						if ($validationEvidence.Build.BaselineVersion) { [void]$provenanceParts.Add(('version {0}' -f [string]$validationEvidence.Build.BaselineVersion)) }
						if ($validationEvidence.Build.TestReportGeneratedAt) { [void]$provenanceParts.Add(('test report {0}' -f [string]$validationEvidence.Build.TestReportGeneratedAt)) }
						if ($validationEvidence.Build.TestPlatform) { [void]$provenanceParts.Add(('platform {0}' -f [string]$validationEvidence.Build.TestPlatform)) }
					}
					if ($validationEvidence.SourcePath)
					{
						if ($validationEvidence.SourcePath.TestReport) { [void]$provenanceParts.Add(('report {0}' -f [string]$validationEvidence.SourcePath.TestReport)) }
						if ($validationEvidence.SourcePath.ValidationMatrix) { [void]$provenanceParts.Add(('matrix {0}' -f [string]$validationEvidence.SourcePath.ValidationMatrix)) }
					}
					if ($provenanceParts.Count -gt 0)
					{
						$validationEvidenceProvenance = ($provenanceParts -join ' | ')
					}
				}
			}
		}
		catch
		{
			$validationEvidenceSummary = 'Unavailable'
			$validationEvidenceChannels = 'Unavailable'
			$validationEvidenceProvenance = 'Unavailable'
		}
		$featureMaturitySummary = 'Unavailable'
		$enterpriseGateSummary = 'Unavailable'
		try
		{
			$featureMaturityCmd = Get-GuiRuntimeCommand -Name 'Get-BaselineFeatureMaturityReport' -CommandType 'Function'
			if ($featureMaturityCmd)
			{
				$featureMaturityReport = & $featureMaturityCmd -Manifest $Script:TweakManifest
				if ($featureMaturityReport -and $featureMaturityReport.Summary)
				{
					$featureMaturitySummary = @(
						('Implemented={0}' -f [int]$featureMaturityReport.Summary.Implemented),
						('Tested={0}' -f [int]$featureMaturityReport.Summary.Tested),
						('CI-validated={0}' -f [int]$featureMaturityReport.Summary.'CI-validated'),
						('Production-validated={0}' -f [int]$featureMaturityReport.Summary.'Production-validated')
					) -join ', '

					$gateParts = @(
						@($featureMaturityReport.EnterpriseActions | ForEach-Object {
							('{0}: {1} (required {2}) [{3}]' -f [string]$_.FeatureName, [string]$_.CurrentMaturity, [string]$_.RequiredMaturity, $(if ([bool]$_.Allowed) { 'Open' } else { 'Blocked' }))
						})
					)
					if ($gateParts.Count -gt 0)
					{
						$enterpriseGateSummary = ($gateParts -join ' | ')
					}
				}
			}
		}
		catch
		{
			$featureMaturitySummary = 'Unavailable'
			$enterpriseGateSummary = 'Unavailable'
		}
		$pinnedVersion = $null
		try
		{
			if ($Script:Ctx -and $Script:Ctx.ContainsKey('UI') -and $Script:Ctx.UI.PSObject.Properties['PinnedBaselineVersion'])
			{
				$pinnedVersion = [string]$Script:Ctx.UI.PinnedBaselineVersion
			}
			elseif ($Script:PinnedBaselineVersion)
			{
				$pinnedVersion = [string]$Script:PinnedBaselineVersion
			}
		}
		catch
		{
			$pinnedVersion = $null
		}
		$exePaths = @(
			$(if ($resolvedRepoRoot) { Join-Path $resolvedRepoRoot 'Baseline.exe' }),
			$(if ($resolvedRepoRoot) { Join-Path $resolvedRepoRoot 'Baseline-setup-4.0.0.exe' }),
			$(if ($resolvedRepoRoot) { Join-Path $resolvedRepoRoot 'Baseline-4.0.0.zip' })
		)
		$artifactVerificationCmd = Get-GuiRuntimeCommand -Name 'Get-BaselineReleaseArtifactVerification' -CommandType 'Function'

		[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$windowTitle"
	Width="780" Height="520"
	MinWidth="680" MinHeight="460"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="FluentSystemIcons"
	FontSize="12"
	Background="Transparent"
	WindowStyle="None"
	AllowsTransparency="True">
	<Border Name="RootBorder" CornerRadius="8">
		<Grid>
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="*"/>
				<RowDefinition Height="Auto"/>
			</Grid.RowDefinitions>

			<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="12,8,8,8" Cursor="Arrow">
				<Grid>
					<TextBlock Text="$windowTitle" VerticalAlignment="Center" FontSize="12" Foreground="$($theme.TextPrimary)"/>
					<Button Name="BtnDlgClose" Content="x" FontFamily="Arial" FontSize="12" Width="32" Height="28"
						Background="Transparent" Foreground="$($theme.TextPrimary)" BorderThickness="0" Cursor="Hand"
						HorizontalAlignment="Right" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
				</Grid>
			</Border>

			<Border Grid.Row="1" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,0,0,1"
					Padding="20,14,20,14">
				<StackPanel>
					<TextBlock Text="$windowTitle" FontSize="16" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
					<TextBlock Text="$windowSubtitle" FontSize="12" Foreground="$($theme.TextMuted)" Margin="0,2,0,0" TextWrapping="Wrap"/>
				</StackPanel>
			</Border>

			<ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="20,18,20,18">
				<StackPanel Name="ContentPanel"/>
			</ScrollViewer>

			<Border Grid.Row="3" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0"
					Padding="20,10,20,10">
				<Grid>
					<StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
						<Button Name="BtnPinVersion" Content="" Padding="18,6" FontSize="13" Margin="0,0,8,0"/>
						<Button Name="BtnClearPin" Content="" Padding="18,6" FontSize="13"/>
					</StackPanel>
					<Button Name="BtnClose" Content="" HorizontalAlignment="Right" Padding="20,6" FontSize="13"/>
				</Grid>
			</Border>
		</Grid>
	</Border>
</Window>
"@

		$reader = [System.Xml.XmlNodeReader]::new($xaml)
		$dlg = [Windows.Markup.XamlReader]::Load($reader)
		$dlg.Owner = $Form

		$rootBorder = $dlg.FindName('RootBorder')
		if ($rootBorder)
		{
			$rootBorder.Background = $bc.ConvertFromString($theme.WindowBg)
			$rootBorder.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
			$rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
		}

		[void](GUICommon\Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))

		$btnClose = $dlg.FindName('BtnClose')
		$btnPinVersion = $dlg.FindName('BtnPinVersion')
		$btnClearPin = $dlg.FindName('BtnClearPin')
		$contentPanel = $dlg.FindName('ContentPanel')
		if ($btnClose)
		{
			$btnClose.Content = $closeLabel
			Set-ButtonChrome -Button $btnClose -Variant 'Primary' -Compact
			$btnClose.IsDefault = $true
			$btnClose.IsCancel = $true
			$btnClose.Add_Click({ $dlg.Close() }.GetNewClosure())
		}
		if ($btnPinVersion)
		{
			$pinLabel = Get-UxLocalizedString -Key 'GuiReleaseStatusPinCurrent' -Fallback 'Pin Current Version'
			$btnPinVersion.Content = $pinLabel
			Set-ButtonChrome -Button $btnPinVersion -Variant 'Subtle' -Compact
			$btnPinVersion.Add_Click({
				try
				{
					$currentVersion = $null
					try { $currentVersion = Get-BaselineDisplayVersion } catch { $currentVersion = $null }
					if ([string]::IsNullOrWhiteSpace($currentVersion))
					{
						return
					}
					$Script:PinnedBaselineVersion = [string]$currentVersion
					if ($Script:Ctx -and $Script:Ctx.ContainsKey('UI'))
					{
						$Script:Ctx.UI.PinnedBaselineVersion = [string]$currentVersion
					}
					[void](Show-ThemedDialog -Title $windowTitle -Message (('Pinned release version: {0}' -f [string]$currentVersion)) -Buttons @('OK') -AccentButton 'OK')
					$dlg.Close()
				}
				catch
				{
					[void](Show-ThemedDialog -Title $windowTitle -Message ("Failed to pin the current version.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
				}
			}.GetNewClosure())
		}
		if ($btnClearPin)
		{
			$clearPinLabel = Get-UxLocalizedString -Key 'GuiReleaseStatusClearPin' -Fallback 'Clear Pin'
			$btnClearPin.Content = $clearPinLabel
			Set-ButtonChrome -Button $btnClearPin -Variant 'Subtle' -Compact
			$btnClearPin.Add_Click({
				try
				{
					$Script:PinnedBaselineVersion = $null
					if ($Script:Ctx -and $Script:Ctx.ContainsKey('UI'))
					{
						$Script:Ctx.UI.PinnedBaselineVersion = $null
					}
					[void](Show-ThemedDialog -Title $windowTitle -Message 'Pinned release version cleared.' -Buttons @('OK') -AccentButton 'OK')
					$dlg.Close()
				}
				catch
				{
					[void](Show-ThemedDialog -Title $windowTitle -Message ("Failed to clear the pinned version.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
				}
			}.GetNewClosure())
		}

		$lines = [System.Collections.Generic.List[string]]::new()
		[void]$lines.Add(("Version: {0}" -f $version))
		[void]$lines.Add(("Prerelease: {0}" -f $prerelease))
		[void]$lines.Add(("Pinned version: {0}" -f ($(if ($pinnedVersion) { $pinnedVersion } else { 'none' }))))
		[void]$lines.Add(("Icon system: {0}" -f $iconStatus))
		if ($iconFontPath)
		{
			[void]$lines.Add(("Icon font: {0}" -f $iconFontPath))
		}
		[void]$lines.Add(("Validation matrix: {0}" -f $matrixSummary))
		[void]$lines.Add(("Server validation outside CI: {0}" -f $serverValidationSummary))
		[void]$lines.Add(("Validation evidence: {0}" -f $validationEvidenceSummary))
		[void]$lines.Add(("Validation channels: {0}" -f $validationEvidenceChannels))
		[void]$lines.Add(("Build/test provenance: {0}" -f $validationEvidenceProvenance))
		[void]$lines.Add(("Feature maturity: {0}" -f $featureMaturitySummary))
		[void]$lines.Add(("Enterprise gates: {0}" -f $enterpriseGateSummary))
		[void]$lines.Add('Artifact verification:')
		foreach ($path in @($exePaths))
		{
			$verification = $null
			try
			{
				if ($artifactVerificationCmd)
				{
					$verification = Invoke-CapturedFunction -Name 'Get-BaselineReleaseArtifactVerification' -Parameters @{ Path = $path }
				}
			}
			catch
			{
				$verification = $null
			}

			if (-not $verification)
			{
				$status = if (Test-Path -LiteralPath $path) { 'Present' } else { 'Missing' }
				$verification = [pscustomobject]@{
					VerificationState = if ($status -eq 'Present') { 'Unavailable' } else { 'Missing' }
					SignatureStatus   = $status
					TimestampStatus   = 'Unavailable'
					SignerSubject     = $null
					TimestampSubject  = $null
					FileHash          = $null
					VerificationMessage = if ($status -eq 'Present') { 'Artifact verification helper is not available.' } else { 'Artifact not found.' }
				}
			}

			[void]$lines.Add(("Artifact: {0}" -f $path))
			[void]$lines.Add(("Verification: {0} | Signature: {1} | Timestamp: {2}" -f $verification.VerificationState, $verification.SignatureStatus, $verification.TimestampStatus))
			[void]$lines.Add(("Signer: {0} | Timestamp signer: {1} | SHA256: {2}" -f ($(if ($verification.SignerSubject) { $verification.SignerSubject } else { 'n/a' })), ($(if ($verification.TimestampSubject) { $verification.TimestampSubject } else { 'n/a' })), ($(if ($verification.FileHash) { $verification.FileHash } else { 'n/a' }))))
			[void]$lines.Add(("Result: {0}" -f $verification.VerificationMessage))
		}

		foreach ($line in $lines)
		{
			$txt = New-Object System.Windows.Controls.TextBlock
			$txt.Text = $line
			$txt.TextWrapping = 'Wrap'
			$txt.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
			$txt.Foreground = $bc.ConvertFromString($theme.TextPrimary)
			[void]$contentPanel.Children.Add($txt)
		}

		$dlg.Add_KeyDown({
			$eventArgs = $args[1]
			if ($eventArgs.Key -eq [System.Windows.Input.Key]::Escape) { $dlg.Close() }
		})

		[void]($dlg.ShowDialog())
		return $null
	}

	<#
	    .SYNOPSIS
	    Internal function Show-GuiTroubleshootingGuideDialog.
	#>

	function Show-GuiTroubleshootingGuideDialog
	{
		$theme = $Script:CurrentTheme
		if (-not $theme)
		{
			return $null
		}

		$bc = New-SafeBrushConverter -Context 'DialogHelpers-Troubleshooting'
		$windowTitle = Get-UxLocalizedString -Key 'GuiTroubleshootingTitle' -Fallback 'Troubleshooting Guide'
		$windowSubtitle = Get-UxLocalizedString -Key 'GuiTroubleshootingSubtitle' -Fallback 'Use this guide to reproduce, capture, and report issues.'
		$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'
		$bundleLabel = Get-UxLocalizedString -Key 'GuiMenuToolsExportSupportBundle' -Fallback 'Export Support Bundle...'

		$errorCatalog = $null
		try
		{
			if (Get-Command -Name 'Get-BaselineErrorCatalog' -CommandType Function -ErrorAction SilentlyContinue)
			{
				$errorCatalog = Get-BaselineErrorCatalog
			}
		}
		catch
		{
			$errorCatalog = $null
		}
		if (-not $errorCatalog)
		{
			$errorCatalog = @{}
		}

		$sections = [System.Collections.Generic.List[object]]::new()
		$sections.Add([pscustomobject]@{
			Title = '1. Reproduce the issue'
			Lines = @(
				'Repeat the same action in the same mode (local, connected remote, or apply / preview).',
				'Keep the same target list, profile, and approval state if the issue is remote.',
				'Note the exact time, command, and any dialog that appears.'
			)
		}) | Out-Null
		$sections.Add([pscustomobject]@{
			Title = '2. Capture evidence'
			Lines = @(
				'Open Release Status to confirm the running build, artifact state, and validation matrix.',
				'Export a support bundle so the log, snapshot, and audit trail are captured together.',
				'Include the error code shown below if Baseline surfaces one.'
			)
		}) | Out-Null
		$guiStartError004Message = if ($errorCatalog.ContainsKey('GUI-STARTUP-004')) { [string]$errorCatalog['GUI-STARTUP-004'].Message } else { 'Installation looks incomplete.' }
		$guiStartError005Message = if ($errorCatalog.ContainsKey('GUI-STARTUP-005')) { [string]$errorCatalog['GUI-STARTUP-005'].Message } else { 'Missing or empty startup data.' }
		$guiGenericErrorMessage = if ($errorCatalog.ContainsKey('GUI-GENERIC-001')) { [string]$errorCatalog['GUI-GENERIC-001'].Message } else { 'Unexpected problem.' }

		$sections.Add([pscustomobject]@{
			Title = '3. Common error codes'
			Lines = @(
				('GUI-STARTUP-004 - {0}' -f $guiStartError004Message),
				('GUI-STARTUP-005 - {0}' -f $guiStartError005Message),
				('GUI-GENERIC-001 - {0}' -f $guiGenericErrorMessage)
			)
		}) | Out-Null
		$sections.Add([pscustomobject]@{
			Title = '4. Next steps for support'
			Lines = @(
				'Send the support bundle, the error code, and the exact reproduction steps to the operator or IT admin.',
				'If the issue is remote, include the approved target list and the remote console status.',
				'If the issue follows a policy change, include the release-status report and audit time window.'
			)
		}) | Out-Null
		$sections.Add([pscustomobject]@{
			Title = '5. Managed endpoint review'
			Lines = @(
				'Managed endpoints can surface domain join status and active policy hives in preflight.',
				'If the policy environment is flagged, review GPO-enforced settings before a remote apply run and confirm the GPO scope in the remote console.',
				'Export the relevant policy hives or document enforced settings before any high-risk change.',
				'Use the preflight output together with the support bundle to confirm the endpoint state.'
			)
		}) | Out-Null

		[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$windowTitle"
	Width="820" Height="620"
	MinWidth="720" MinHeight="520"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="FluentSystemIcons"
	FontSize="12"
	Background="Transparent"
	WindowStyle="None"
	AllowsTransparency="True">
	<Border Name="RootBorder" CornerRadius="8">
		<Grid>
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="*"/>
				<RowDefinition Height="Auto"/>
			</Grid.RowDefinitions>

			<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="12,8,8,8" Cursor="Arrow">
				<Grid>
					<TextBlock Text="$windowTitle" VerticalAlignment="Center" FontSize="12" Foreground="$($theme.TextPrimary)"/>
					<Button Name="BtnDlgClose" Content="x" FontFamily="Arial" FontSize="12" Width="32" Height="28"
						Background="Transparent" Foreground="$($theme.TextPrimary)" BorderThickness="0" Cursor="Hand"
						HorizontalAlignment="Right" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
				</Grid>
			</Border>

			<Border Grid.Row="1" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,0,0,1"
					Padding="20,14,20,14">
				<StackPanel>
					<TextBlock Text="$windowTitle" FontSize="16" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
					<TextBlock Text="$windowSubtitle" FontSize="12" Foreground="$($theme.TextMuted)" Margin="0,2,0,0" TextWrapping="Wrap"/>
				</StackPanel>
			</Border>

			<ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="20,18,20,18">
				<StackPanel Name="ContentPanel"/>
			</ScrollViewer>

			<Border Grid.Row="3" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0"
					Padding="20,10,20,10">
				<Grid>
					<Button Name="BtnExportBundle" Content="" HorizontalAlignment="Left" Padding="18,6" FontSize="13"/>
					<Button Name="BtnClose" Content="" HorizontalAlignment="Right" Padding="20,6" FontSize="13"/>
				</Grid>
			</Border>
		</Grid>
	</Border>
</Window>
"@

		$reader = [System.Xml.XmlNodeReader]::new($xaml)
		$dlg = [Windows.Markup.XamlReader]::Load($reader)
		$dlg.Owner = $Form

		$rootBorder = $dlg.FindName('RootBorder')
		if ($rootBorder)
		{
			$rootBorder.Background = $bc.ConvertFromString($theme.WindowBg)
			$rootBorder.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
			$rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
		}

		[void](GUICommon\Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))

		$btnClose = $dlg.FindName('BtnClose')
		$btnExportBundle = $dlg.FindName('BtnExportBundle')
		$contentPanel = $dlg.FindName('ContentPanel')
		if ($btnClose)
		{
			$btnClose.Content = $closeLabel
			Set-ButtonChrome -Button $btnClose -Variant 'Primary' -Compact
			$btnClose.IsDefault = $true
			$btnClose.IsCancel = $true
			$btnClose.Add_Click({ $dlg.Close() }.GetNewClosure())
		}
		if ($btnExportBundle)
		{
			$btnExportBundle.Content = $bundleLabel
			Set-ButtonChrome -Button $btnExportBundle -Variant 'Primary' -Compact
			$btnExportBundle.Add_Click({
				try
				{
					if ($Script:MenuToolsExportSupportBundle)
					{
						$eventArgs = [System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent)
						$Script:MenuToolsExportSupportBundle.RaiseEvent($eventArgs)
					}
				}
				catch { }
			}.GetNewClosure())
		}

		foreach ($section in $sections)
		{
			$card = New-Object System.Windows.Controls.Border
			$card.CornerRadius = [System.Windows.CornerRadius]::new(6)
			$card.BorderThickness = [System.Windows.Thickness]::new(1)
			$card.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
			$card.Background = $bc.ConvertFromString($theme.CardBg)
			$card.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
			$card.Padding = [System.Windows.Thickness]::new(14, 12, 14, 12)

			$stack = New-Object System.Windows.Controls.StackPanel
			$title = New-Object System.Windows.Controls.TextBlock
			$title.Text = [string]$section.Title
			$title.FontSize = 13
			$title.FontWeight = 'SemiBold'
			$title.Foreground = $bc.ConvertFromString($theme.TextPrimary)
			$title.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
			[void]$stack.Children.Add($title)

			foreach ($line in @($section.Lines))
			{
				$txt = New-Object System.Windows.Controls.TextBlock
				$txt.Text = [string]$line
				$txt.TextWrapping = 'Wrap'
				$txt.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)
				$txt.Foreground = $bc.ConvertFromString($theme.TextPrimary)
				[void]$stack.Children.Add($txt)
			}

			$card.Child = $stack
			[void]$contentPanel.Children.Add($card)
		}

		$dlg.Add_KeyDown({
			$eventArgs = $args[1]
			if ($eventArgs.Key -eq [System.Windows.Input.Key]::Escape) { $dlg.Close() }
		})

		[void]($dlg.ShowDialog())
		return $null
	}

	<#
	    .SYNOPSIS
	    Internal function Show-GuiFaqDialog.
	#>

	function Show-GuiFaqDialog
	{
		$theme = $Script:CurrentTheme
		if (-not $theme)
		{
			return $null
		}

		$bc = New-SafeBrushConverter -Context 'DialogHelpers-FAQ'
		$windowTitle = Get-UxLocalizedString -Key 'GuiMenuHelpFAQ' -Fallback 'FAQ'
		$windowSubtitle = Get-UxLocalizedString -Key 'GuiMenuHelpFAQSubtitle' -Fallback 'Common questions and quick answers.'
		$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'

		$faqItems = @(
			[pscustomobject]@{
				Title = 'Which preset should I start with?'
				Lines = @(
					'In Safe Mode, start with Minimal for the most conservative first run.',
					'Outside Safe Mode, Basic remains the default recommendation for most users.'
				)
			}
			[pscustomobject]@{
				Title = 'When should I use Advanced?'
				Lines = @(
					'Use Advanced only after reviewing Preview Run and after you are comfortable with harder-to-reverse changes.',
					'Keep a recovery plan ready before applying it.'
				)
			}
			[pscustomobject]@{
				Title = 'A tweak failed. What should I try first?'
				Lines = @(
					'Rerun Baseline as administrator, reboot if needed, and review Preview Run plus the detailed log before trying again.'
				)
			}
			[pscustomobject]@{
				Title = 'Can Baseline automatically undo everything?'
				Lines = @(
					'No. Some changes expose direct undo commands, some revert to supported Windows defaults, and some still rely on restore points or manual recovery.'
				)
			}
			[pscustomobject]@{
				Title = 'How do I run a compliance check?'
				Lines = @(
					'Export a configuration profile from the GUI or create one from a preset, then run the compliance check against that profile.'
				)
			}
		)

		[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$windowTitle"
	Width="820" Height="620"
	MinWidth="720" MinHeight="520"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="FluentSystemIcons"
	FontSize="12"
	Background="Transparent"
	WindowStyle="None"
	AllowsTransparency="True">
	<Border Name="RootBorder" CornerRadius="8">
		<Grid>
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="*"/>
				<RowDefinition Height="Auto"/>
			</Grid.RowDefinitions>

			<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="12,8,8,8" Cursor="Arrow">
				<Grid>
					<TextBlock Text="$windowTitle" VerticalAlignment="Center" FontSize="12" Foreground="$($theme.TextPrimary)"/>
					<Button Name="BtnDlgClose" Content="x" FontFamily="Arial" FontSize="12" Width="32" Height="28"
						Background="Transparent" Foreground="$($theme.TextPrimary)" BorderThickness="0" Cursor="Hand"
						HorizontalAlignment="Right" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
				</Grid>
			</Border>

			<Border Grid.Row="1" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,0,0,1"
					Padding="20,14,20,14">
				<StackPanel>
					<TextBlock Text="$windowTitle" FontSize="16" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
					<TextBlock Text="$windowSubtitle" FontSize="12" Foreground="$($theme.TextMuted)" Margin="0,2,0,0" TextWrapping="Wrap"/>
				</StackPanel>
			</Border>

			<ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="20,18,20,18">
				<StackPanel Name="ContentPanel"/>
			</ScrollViewer>

			<Border Grid.Row="3" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0"
					Padding="20,10,20,10">
				<Grid>
					<Button Name="BtnClose" Content="" HorizontalAlignment="Right" Padding="20,6" FontSize="13"/>
				</Grid>
			</Border>
		</Grid>
	</Border>
</Window>
"@

		$reader = [System.Xml.XmlNodeReader]::new($xaml)
		$dlg = [Windows.Markup.XamlReader]::Load($reader)
		$dlg.Owner = $Form

		$rootBorder = $dlg.FindName('RootBorder')
		if ($rootBorder)
		{
			$rootBorder.Background = $bc.ConvertFromString($theme.WindowBg)
			$rootBorder.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
			$rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
		}

		[void](GUICommon\Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))

		$dlgTitleBar = $dlg.FindName('DlgTitleBar')
		$btnDlgClose = $dlg.FindName('BtnDlgClose')
		$contentPanel = $dlg.FindName('ContentPanel')
		$btnClose = $dlg.FindName('BtnClose')
		if ($dlgTitleBar)
		{
			$dlgTitleBar.Add_MouseLeftButtonDown({ $dlg.DragMove() }.GetNewClosure())
			$faqCtx = New-Object System.Windows.Controls.ContextMenu
			$faqCtxClose = New-Object System.Windows.Controls.MenuItem
			$faqCtxClose.Header = $closeLabel
			$faqCtxClose.InputGestureText = 'Alt+F4'
			$faqCtxClose.FontWeight = [System.Windows.FontWeights]::Bold
			$faqCtxClose.Add_Click({ $dlg.Close() }.GetNewClosure())
			[void]$faqCtx.Items.Add($faqCtxClose)
			$dlgTitleBar.ContextMenu = $faqCtx
		}
		if ($btnDlgClose) { $btnDlgClose.Add_Click({ $dlg.Close() }.GetNewClosure()) }
		$btnClose.Content = $closeLabel
		Set-ButtonChrome -Button $btnClose -Variant 'Primary' -Compact
		$btnClose.IsDefault = $true
		$btnClose.IsCancel = $true
		$btnClose.Add_Click({ $dlg.Close() }.GetNewClosure())

		foreach ($item in $faqItems)
		{
			$card = New-Object System.Windows.Controls.Border
			$card.CornerRadius = [System.Windows.CornerRadius]::new(6)
			$card.BorderThickness = [System.Windows.Thickness]::new(1)
			$card.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
			$card.Background = $bc.ConvertFromString($theme.CardBg)
			$card.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
			$card.Padding = [System.Windows.Thickness]::new(14, 12, 14, 12)

			$stack = New-Object System.Windows.Controls.StackPanel
			$title = New-Object System.Windows.Controls.TextBlock
			$title.Text = [string]$item.Title
			$title.FontSize = 13
			$title.FontWeight = 'SemiBold'
			$title.Foreground = $bc.ConvertFromString($theme.TextPrimary)
			$title.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
			[void]$stack.Children.Add($title)

			foreach ($line in @($item.Lines))
			{
				$txt = New-Object System.Windows.Controls.TextBlock
				$txt.Text = [string]$line
				$txt.TextWrapping = 'Wrap'
				$txt.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)
				$txt.Foreground = $bc.ConvertFromString($theme.TextPrimary)
				[void]$stack.Children.Add($txt)
			}

			$card.Child = $stack
			[void]$contentPanel.Children.Add($card)
		}

		$dlg.Add_KeyDown({
			$eventArgs = $args[1]
			if ($eventArgs.Key -eq [System.Windows.Input.Key]::Escape) { $dlg.Close() }
		})

		[void]($dlg.ShowDialog())
		return $null
	}

	<#
	    .SYNOPSIS
	    Internal function Show-HelpDialog.
	#>

	function Show-HelpDialog
	{
		param (
			[switch]$StartUpdateCheck
		)

		$theme = $Script:CurrentTheme
		$bc = New-SafeBrushConverter -Context 'DialogHelpers-AboutPanel'
		$scrollBarStyleXaml = Get-BaselineScrollBarStyleXaml -Theme $theme
		$helpDialogTitle = Get-UxHelpDialogTitle
		$helpDialogSubtitle = Get-UxHelpDialogSubtitle
		$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'
		$downloadLabel = Get-UxLocalizedString -Key 'GuiDownloadBaselineButton' -Fallback 'Check for Update'
		$downloadFailedTitle = Get-UxLocalizedString -Key 'GuiDownloadBaselineFailedTitle' -Fallback 'Download Failed'
		$downloadCompletedTitle = Get-UxLocalizedString -Key 'GuiDownloadBaselineCompletedTitle' -Fallback 'Download Complete'
		$downloadingLabel = Get-UxLocalizedString -Key 'GuiDownloadBaselineInProgress' -Fallback 'Downloading...'
		$downloadPreparingLabel = Get-UxLocalizedString -Key 'GuiDownloadBaselinePreparing' -Fallback 'Preparing download...'
		$downloadProgressLabel = Get-UxLocalizedString -Key 'GuiDownloadBaselineProgressLabel' -Fallback 'Downloading Baseline...'
		$downloadCompleteLabel = Get-UxLocalizedString -Key 'GuiDownloadBaselineProgressComplete' -Fallback 'Download complete.'
		$downloadFailedLabel = Get-UxLocalizedString -Key 'GuiDownloadBaselineProgressFailed' -Fallback 'Download failed.'
		$okLabel = Get-UxLocalizedString -Key 'GuiOkButton' -Fallback 'OK'
		$getBaselineBilingualString = ${function:Get-BaselineBilingualString}

		$sections = Get-UxHelpSections
		if ($null -eq $sections)
		{
			$sections = [ordered]@{
				(Get-UxLocalizedString -Key 'GuiHelpSectionStartGuide' -Fallback 'Start Guide') = @(Get-UxQuickStartSteps)
				(Get-UxLocalizedString -Key 'GuiHelpSectionUndoRestore' -Fallback 'Undo and Restore') = @(Get-UxUndoAndRestoreLines)
				(Get-UxLocalizedString -Key 'GuiHelpSectionImportExport' -Fallback 'Import / Export') = @(Get-UxImportExportLines)
			}
		}

		[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$helpDialogTitle"
	Width="$($Script:GuiLayout.HelpDialogWidth)" Height="$($Script:GuiLayout.HelpDialogHeight)"
	MinWidth="$($Script:GuiLayout.HelpDialogMinWidth)" MinHeight="$($Script:GuiLayout.HelpDialogMinHeight)"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="FluentSystemIcons"
	FontSize="12"
	Background="Transparent"
	WindowStyle="None"
	AllowsTransparency="True">
	<Border Name="RootBorder" CornerRadius="8">
	<Border.Resources>
		$scrollBarStyleXaml
	</Border.Resources>
	<Grid>
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>

		<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="12,8,8,8" Cursor="Arrow">
			<Grid>
				<TextBlock Text="$helpDialogTitle" VerticalAlignment="Center" FontSize="12" Foreground="$($theme.TextPrimary)"/>
				<Button Name="BtnDlgClose" Content="x" FontFamily="Arial" FontSize="12" Width="32" Height="28"
					Background="Transparent" Foreground="$($theme.TextPrimary)" BorderThickness="0" Cursor="Hand"
					HorizontalAlignment="Right" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
			</Grid>
		</Border>

		<Border Grid.Row="1" Background="$($theme.HeaderBg)"
				BorderBrush="$($theme.BorderColor)" BorderThickness="0,0,0,1"
				Padding="20,14,20,14">
			<StackPanel>
				<TextBlock Text="$helpDialogTitle" FontSize="16" FontWeight="SemiBold"
						   Foreground="$($theme.TextPrimary)"/>
				<TextBlock Text="$helpDialogSubtitle"
						   FontSize="12" Foreground="$($theme.TextMuted)" Margin="0,2,0,0"/>
			</StackPanel>
		</Border>

		<ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto"
					  HorizontalScrollBarVisibility="Disabled"
					  Padding="0,0,4,0">
			<StackPanel Name="ContentPanel" Margin="20,16,20,16"/>
		</ScrollViewer>

		<Border Grid.Row="3" Background="$($theme.HeaderBg)"
				BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0"
				Padding="20,10,20,10">
			<StackPanel>
				<StackPanel Name="DownloadProgressPanel" Margin="0,0,0,10" Visibility="Collapsed">
					<Grid>
						<Grid.ColumnDefinitions>
							<ColumnDefinition Width="*"/>
							<ColumnDefinition Width="Auto"/>
						</Grid.ColumnDefinitions>
						<TextBlock Name="TxtDownloadProgressLabel" Grid.Column="0" Text="" FontSize="12" Foreground="$($theme.TextSecondary)"/>
						<TextBlock Name="TxtDownloadProgressPct" Grid.Column="1" Text="0%" FontSize="12" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
					</Grid>
					<ProgressBar Name="DownloadProgressBar" Height="18" Minimum="0" Maximum="100" Value="0" Margin="0,6,0,0"/>
				</StackPanel>
				<Grid>
					<Grid.ColumnDefinitions>
						<ColumnDefinition Width="Auto"/>
						<ColumnDefinition Width="*"/>
						<ColumnDefinition Width="Auto"/>
					</Grid.ColumnDefinitions>
					<Button Name="BtnDownloadBaseline" Grid.Column="0" Content=""
							HorizontalAlignment="Left"
							Padding="20,6" FontSize="13" Margin="0,0,8,0"/>
					<Button Name="BtnClose" Grid.Column="2" Content=""
							HorizontalAlignment="Right"
							Padding="20,6" FontSize="13"/>
				</Grid>
			</StackPanel>
		</Border>
	</Grid>
	</Border>
</Window>
"@

		$reader = [System.Xml.XmlNodeReader]::new($xaml)
		$dlg = [Windows.Markup.XamlReader]::Load($reader)
		$dlg.Owner = $Form

		$rootBorder = $dlg.FindName('RootBorder')
		$useDarkMode = if (Test-Path -Path Variable:\Script:CurrentThemeName) { $Script:CurrentThemeName -eq 'Dark' } else { $false }
		if (Test-Path -Path Variable:\Script:CurrentTheme)
		{
			$theme = $Script:CurrentTheme
			if ($rootBorder)
			{
				$rootBorder.Background = [System.Windows.Media.Brush](New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.Color]::FromArgb(255, [System.Convert]::ToInt32($theme.WindowBg.Substring(1, 2), 16), [System.Convert]::ToInt32($theme.WindowBg.Substring(3, 2), 16), [System.Convert]::ToInt32($theme.WindowBg.Substring(5, 2), 16))))
				$rootBorder.BorderBrush = [System.Windows.Media.Brush](New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.Color]::FromArgb(255, [System.Convert]::ToInt32($theme.BorderColor.Substring(1, 2), 16), [System.Convert]::ToInt32($theme.BorderColor.Substring(3, 2), 16), [System.Convert]::ToInt32($theme.BorderColor.Substring(5, 2), 16))))
				$rootBorder.BorderThickness = '1'
			}
		}
		else
		{
			if ($rootBorder)
			{
				$rootBorder.Background = [System.Windows.Media.Brush](New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.Color]::FromArgb(255, 241, 241, 241)))
				$rootBorder.BorderBrush = [System.Windows.Media.Brush](New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.Color]::FromArgb(255, 200, 200, 200)))
				$rootBorder.BorderThickness = '1'
			}
		}
		if (Test-Path -Path Function:\Set-GuiWindowChromeTheme)
		{
			[void](GUICommon\Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode $useDarkMode)
		}

		# Wire help dialog title bar
		$dlgTitleBar = $dlg.FindName('DlgTitleBar')
		$btnDlgClose = $dlg.FindName('BtnDlgClose')
		if ($dlgTitleBar) {
			$dlgTitleBar.Add_MouseLeftButtonDown({ $dlg.DragMove() }.GetNewClosure())
			$dhCtx = New-Object System.Windows.Controls.ContextMenu
			$dhCtxClose = New-Object System.Windows.Controls.MenuItem
			$dhCtxClose.Header = $closeLabel; $dhCtxClose.InputGestureText = 'Alt+F4'; $dhCtxClose.FontWeight = [System.Windows.FontWeights]::Bold
			$dhCtxRef = $dlg
			$dhCtxClose.Add_Click({ $dhCtxRef.Close() }.GetNewClosure())
			[void]$dhCtx.Items.Add($dhCtxClose)
			$dlgTitleBar.ContextMenu = $dhCtx
		}
		if ($btnDlgClose) { $btnDlgClose.Add_Click({ $dlg.Close() }.GetNewClosure()) }

		$panel = $dlg.FindName('ContentPanel')
		$btnClose = $dlg.FindName('BtnClose')
		$btnDownloadBaseline = $dlg.FindName('BtnDownloadBaseline')
		$downloadProgressPanel = $dlg.FindName('DownloadProgressPanel')
		$txtDownloadProgressLabel = $dlg.FindName('TxtDownloadProgressLabel')
		$txtDownloadProgressPct = $dlg.FindName('TxtDownloadProgressPct')
		$downloadProgressBar = $dlg.FindName('DownloadProgressBar')
		$btnClose.Content = $closeLabel

		Set-ButtonChrome -Button $btnClose -Variant 'Subtle' -Compact
		$btnClose.IsDefault = $true
		$btnClose.IsCancel = $true

		if ($btnDownloadBaseline)
		{
			# "Check for Update" has been moved to the Help menu. Hide the in-dialog button.
			$btnDownloadBaseline.Visibility = [System.Windows.Visibility]::Collapsed
			$btnDownloadBaseline.Content = $downloadLabel
			Set-ButtonChrome -Button $btnDownloadBaseline -Variant 'Primary' -Compact
			Register-GuiEventHandler -Source $btnDownloadBaseline -EventName 'Click' -Handler ({
				$btnDownloadBaseline.IsEnabled = $false
				$btnDownloadBaseline.Content = $downloadingLabel
				$btnClose.IsEnabled = $false

				if ($downloadProgressPanel)
				{
					$downloadProgressPanel.Visibility = [System.Windows.Visibility]::Visible
				}
				if ($downloadProgressBar)
				{
					$downloadProgressBar.Value = 0
				}
				if ($txtDownloadProgressPct)
				{
					$txtDownloadProgressPct.Text = '0%'
				}
				if ($txtDownloadProgressLabel)
				{
					$txtDownloadProgressLabel.Text = $downloadPreparingLabel
				}

				try
				{
					$destinationPath = Join-Path (Join-Path ([System.Environment]::GetFolderPath('UserProfile')) 'Downloads\Baseline') 'Baseline.exe'
					$destinationDirectory = Split-Path -Path $destinationPath -Parent
					if (-not (Test-Path -LiteralPath $destinationDirectory))
					{
						New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
					}

					if (Test-Path -LiteralPath $destinationPath)
					{
						Remove-Item -LiteralPath $destinationPath -Force -ErrorAction SilentlyContinue
					}

					$releaseAsset = Get-BaselineLatestReleaseAssetUrl -Owner 'sdmanson8' -Repository 'Baseline' -AssetName 'Baseline.exe'
					$expectedBytes = if ($releaseAsset.PSObject.Properties['SizeBytes']) { [long]$releaseAsset.SizeBytes } else { 0L }

					$writePackageHelperWarningDefinition = (Get-Command -Name 'Write-PackageHelperWarning' -CommandType Function -ErrorAction Stop).Definition
					$setDownloadSecurityProtocolDefinition = (Get-Command -Name 'Set-DownloadSecurityProtocol' -CommandType Function -ErrorAction Stop).Definition
					$invokeDownloadFileDefinition = (Get-Command -Name 'Invoke-DownloadFile' -CommandType Function -ErrorAction Stop).Definition
					$downloadScript = @(
						$writePackageHelperWarningDefinition
						$setDownloadSecurityProtocolDefinition
						$invokeDownloadFileDefinition
						'param([string]$dlUri, [string]$dlPath)'
						'Invoke-DownloadFile -Uri $dlUri -OutFile $dlPath'
					) -join [System.Environment]::NewLine

					$runspace = [runspacefactory]::CreateRunspace()
					$runspace.Open()
					$downloadPowerShell = [powershell]::Create()
					$downloadPowerShell.Runspace = $runspace
					$null = $downloadPowerShell.AddScript($downloadScript).AddArgument([string]$releaseAsset.DownloadUrl).AddArgument([string]$destinationPath)
					$downloadHandle = $downloadPowerShell.BeginInvoke()

					$downloadTimer = [System.Windows.Threading.DispatcherTimer]::new()
					$downloadTimer.Interval = [System.TimeSpan]::FromMilliseconds(250)
					$downloadTimer.Add_Tick({
						if (Test-Path -LiteralPath $destinationPath)
						{
							$currentBytes = (Get-Item -LiteralPath $destinationPath).Length
							$pct = 0
							if ($expectedBytes -gt 0)
							{
								$pct = [int][Math]::Min(100, [Math]::Round(($currentBytes / $expectedBytes) * 100))
							}

							if ($downloadProgressBar)
							{
								$downloadProgressBar.Value = $pct
							}
							if ($txtDownloadProgressPct)
							{
								$txtDownloadProgressPct.Text = "$pct%"
							}

							if ($txtDownloadProgressLabel)
							{
								if ($expectedBytes -gt 0)
								{
									$currentMB = [Math]::Round($currentBytes / 1MB, 1)
									$totalMB = [Math]::Round($expectedBytes / 1MB, 1)
									$txtDownloadProgressLabel.Text = "${downloadProgressLabel} ($currentMB MB / $totalMB MB)"
								}
								else
								{
									$currentMB = [Math]::Round($currentBytes / 1MB, 1)
									$txtDownloadProgressLabel.Text = "${downloadProgressLabel} ($currentMB MB)"
								}
							}
						}

						if ($downloadHandle.IsCompleted)
						{
							$downloadTimer.Stop()
							try
							{
								$downloadPowerShell.EndInvoke($downloadHandle) | Out-Null
								if ($downloadProgressBar)
								{
									$downloadProgressBar.Value = 100
								}
								if ($txtDownloadProgressPct)
								{
									$txtDownloadProgressPct.Text = '100%'
								}
								if ($txtDownloadProgressLabel)
								{
									$txtDownloadProgressLabel.Text = $downloadCompleteLabel
								}

								$downloadMessage = (& $getBaselineBilingualString -Key 'GuiDownloadBaselineCompletedMessage' -Fallback 'Saved {0} ({1}) to:`n`n{2}' -FormatArgs @($releaseAsset.AssetName, $releaseAsset.TagName, $destinationPath))
								Show-ThemedDialog -Title $downloadCompletedTitle -Message $downloadMessage -Buttons @($okLabel) -AccentButton $okLabel
							}
							catch
							{
								if ($downloadProgressBar)
								{
									$downloadProgressBar.Value = 0
								}
								if ($txtDownloadProgressPct)
								{
									$txtDownloadProgressPct.Text = $downloadFailedLabel
								}
								if ($txtDownloadProgressLabel)
								{
									$txtDownloadProgressLabel.Text = $downloadFailedLabel
								}

								$downloadErrorMessage = (& $getBaselineBilingualString -Key 'GuiDownloadBaselineFailedMessage' -Fallback 'Failed to download the latest Baseline.exe release asset.`n`n{0}' -FormatArgs @($_.Exception.Message))
								Show-ThemedDialog -Title $downloadFailedTitle -Message $downloadErrorMessage -Buttons @($okLabel) -AccentButton $okLabel
							}
							finally
							{
								$downloadPowerShell.Dispose()
								$runspace.Dispose()
								$btnDownloadBaseline.IsEnabled = $true
								$btnClose.IsEnabled = $true
								$btnDownloadBaseline.Content = $downloadLabel
							}
						}
					}.GetNewClosure())
					$downloadTimer.Start()
				}
				catch
				{
					$downloadErrorMessage = (& $getBaselineBilingualString -Key 'GuiDownloadBaselineFailedMessage' -Fallback 'Failed to download the latest Baseline.exe release asset.`n`n{0}' -FormatArgs @($_.Exception.Message))
					Show-ThemedDialog -Title $downloadFailedTitle -Message $downloadErrorMessage -Buttons @($okLabel) -AccentButton $okLabel
					$btnDownloadBaseline.IsEnabled = $true
					$btnClose.IsEnabled = $true
					$btnDownloadBaseline.Content = $downloadLabel
				}
			}.GetNewClosure())
			if ($StartUpdateCheck)
			{
				$dlg.Add_ContentRendered({
					try
					{
						$btnDownloadBaseline.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, $btnDownloadBaseline))
					}
					catch { }
				}.GetNewClosure())
			}
		}

		foreach ($sectionTitle in $sections.Keys)
		{
			$heading = [System.Windows.Controls.TextBlock]::new()
			$heading.Text = $sectionTitle
			$heading.FontSize = $Script:GuiLayout.FontSizeSubheading
			$heading.FontWeight = [System.Windows.FontWeights]::SemiBold
			$heading.Foreground = $bc.ConvertFromString($theme.AccentBlue)
			$heading.Margin = [System.Windows.Thickness]::new(0, 12, 0, 4)
			[void]($panel.Children.Add($heading))
			$sep = [System.Windows.Controls.Separator]::new()
			$sep.Background = $bc.ConvertFromString($theme.BorderColor)
			$sep.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)
			[void]($panel.Children.Add($sep))
			foreach ($line in $sections[$sectionTitle])
			{
				$row = [System.Windows.Controls.Grid]::new()
				$col1 = [System.Windows.Controls.ColumnDefinition]::new()
				$col1.Width = [System.Windows.GridLength]::Auto
				$col2 = [System.Windows.Controls.ColumnDefinition]::new()
				$col2.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
				[void]($row.ColumnDefinitions.Add($col1))
				[void]($row.ColumnDefinitions.Add($col2))
				$row.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)

				$bullet = [System.Windows.Controls.TextBlock]::new()
				$bullet.Text = [char]0xF4B4
				$bullet.FontFamily = [System.Windows.Media.FontFamily]::new('FluentSystemIcons')
				$bullet.FontSize = $Script:GuiLayout.FontSizeSubheading
				$bullet.Foreground = $bc.ConvertFromString($theme.AccentBlue)
				$bullet.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
				$bullet.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
				[System.Windows.Controls.Grid]::SetColumn($bullet, 0)

				$text = [System.Windows.Controls.TextBlock]::new()
				$text.Text = $line
				$text.FontSize = $Script:GuiLayout.FontSizeSubheading
				$text.Foreground = $bc.ConvertFromString($theme.TextSecondary)
				$text.TextWrapping = [System.Windows.TextWrapping]::Wrap
				[System.Windows.Controls.Grid]::SetColumn($text, 1)

				[void]($row.Children.Add($bullet))
				[void]($row.Children.Add($text))
				[void]($panel.Children.Add($row))
			}
		}

		Register-GuiEventHandler -Source $btnClose -EventName 'Click' -Handler { $dlg.Close() }
		Register-GuiEventHandler -Source $dlg -EventName 'KeyDown' -Handler {
			param($s, $e)
			if ($e.Key -eq [System.Windows.Input.Key]::Escape) { $dlg.Close() }
		}

		[void]($dlg.ShowDialog())
	}

	<#
	    .SYNOPSIS
	    Internal function Show-FirstRunWelcomeDialog.
	#>

	function Show-FirstRunWelcomeDialog
	{
		param (
			[string]$RecommendedPreset,
			[string]$PrimaryActionLabel,
			[string]$WelcomeMessage,
			[string]$DialogTitle,
			[object]$ShowThemedDialogCapture,
			[scriptblock]$OpenHelpAction,
			[scriptblock]$ChooseRecommendedPresetAction,
			[scriptblock]$GuidedSetupAction,
			[hashtable]$Theme,
			[scriptblock]$ApplyButtonChrome,
			[object]$OwnerWindow,
			[object]$UseDarkMode = $true
		)

		$resolvedUseDarkMode = GUICommon\Get-GuiBooleanValue -Value $UseDarkMode -Default $(if (Test-Path -Path Variable:\Script:CurrentThemeName) { $Script:CurrentThemeName -eq 'Dark' } else { $true }) -Context 'Show-FirstRunWelcomeDialog'

		$guidedSetupLabel = Get-UxLocalizedString -Key 'GuiGuidedSetupButton' -Fallback 'Guided Setup'
		$chooseButton  = if ([string]::IsNullOrWhiteSpace($PrimaryActionLabel)) { (Get-UxLocalizedString -Key 'GuiFirstRunStartWith' -Fallback "Start with {0}" -FormatArgs @($RecommendedPreset)) } else { $PrimaryActionLabel }
		$resolvedTitle = if ([string]::IsNullOrWhiteSpace($DialogTitle)) { (Get-UxLocalizedString -Key 'GuiFirstRunDialogTitle' -Fallback 'Welcome to Baseline') } else { $DialogTitle }
		$closeLabel    = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'
		$openHelpLabel = Get-UxLocalizedString -Key 'GuiOpenHelpActionLabel' -Fallback 'Open Help'

		# Guided Setup is the primary CTA on first run; preset shortcut is secondary
		$choice = & $ShowThemedDialogCapture -Title $resolvedTitle `
			-Message $WelcomeMessage `
			-Buttons @($closeLabel, $openHelpLabel, $chooseButton, $guidedSetupLabel) `
			-AccentButton $guidedSetupLabel `
			-Theme $Theme `
			-ApplyButtonChrome $ApplyButtonChrome `
			-OwnerWindow $OwnerWindow `
			-UseDarkMode $resolvedUseDarkMode

		switch ($choice)
		{
			$openHelpLabel
			{
				if ($OpenHelpAction) { & $OpenHelpAction }
				break
			}
			$guidedSetupLabel
			{
				if ($GuidedSetupAction) { & $GuidedSetupAction }
				break
			}
			default
			{
				if ($choice -eq $chooseButton -and $ChooseRecommendedPresetAction)
				{
					& $ChooseRecommendedPresetAction
				}
				break
			}
		}

		return $choice
	}

	<#
	    .SYNOPSIS
	    Internal function Show-LogDialog.
	#>

	function Show-LogDialog
	{
		param([string]$LogPath)

		$theme = $Script:CurrentTheme
		$bc = New-SafeBrushConverter -Context 'DialogHelpers-PresetWarning'
		$scrollBarStyleXaml = Get-BaselineScrollBarStyleXaml -Theme $theme
		$logViewerTitle = Get-UxLocalizedString -Key 'GuiLogViewerTitle' -Fallback 'Log Viewer'
		$refreshLabel = Get-UxLocalizedString -Key 'GuiRefreshButton' -Fallback 'Refresh'
		$openExternalLabel = Get-UxLocalizedString -Key 'GuiOpenInNotepad' -Fallback 'Open in Notepad'
		$successLabel = Get-UxLocalizedString -Key 'GuiLogSuccess' -Fallback 'success'
		$failedLabel = Get-UxLocalizedString -Key 'GuiLogFailed' -Fallback 'failed'
		$skippedWarningLabel = Get-UxLocalizedString -Key 'GuiLogSkippedWarning' -Fallback 'skipped / warning'
		$infoLabel = Get-UxLocalizedString -Key 'GuiLogInfo' -Fallback 'info'
		$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'

		[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$logViewerTitle"
	Width="$($Script:GuiLayout.LogDialogWidth)" Height="$($Script:GuiLayout.LogDialogHeight)"
	MinWidth="$($Script:GuiLayout.LogDialogMinWidth)" MinHeight="$($Script:GuiLayout.LogDialogMinHeight)"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="FluentSystemIcons"
	FontSize="12"
	Background="Transparent"
	WindowStyle="None"
	AllowsTransparency="True">
	<Border Name="RootBorder" CornerRadius="8">
	<Border.Resources>
		$scrollBarStyleXaml
	</Border.Resources>
	<Grid>
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>

		<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="12,8,8,8" Cursor="Arrow">
			<Grid>
				<TextBlock Text="$logViewerTitle" VerticalAlignment="Center" FontSize="12" Foreground="$($theme.TextPrimary)"/>
				<Button Name="BtnDlgClose" Content="x" FontFamily="Arial" FontSize="12" Width="32" Height="28"
					Background="Transparent" Foreground="$($theme.TextPrimary)" BorderThickness="0" Cursor="Hand"
					HorizontalAlignment="Right" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
			</Grid>
		</Border>

		<Border Grid.Row="1" Background="$($theme.HeaderBg)"
				BorderBrush="$($theme.BorderColor)" BorderThickness="0,0,0,1"
				Padding="20,14,20,14">
			<Grid>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="Auto"/>
				</Grid.ColumnDefinitions>
				<StackPanel Grid.Column="0">
					<TextBlock Text="$logViewerTitle" FontSize="16" FontWeight="SemiBold"
							   Foreground="$($theme.TextPrimary)"/>
					<TextBlock Name="TxtLogPath" FontSize="11"
							   Foreground="$($theme.TextMuted)" Margin="0,2,0,0"
							   TextTrimming="CharacterEllipsis"/>
				</StackPanel>
				<StackPanel Grid.Column="1" Orientation="Horizontal"
							VerticalAlignment="Center" HorizontalAlignment="Right">
					<Button Name="BtnRefresh" Content="$refreshLabel" Margin="0,0,8,0"
							Padding="12,5" FontSize="12"/>
					<Button Name="BtnOpenExternal" Content="$openExternalLabel"
							Padding="12,5" FontSize="12"/>
				</StackPanel>
			</Grid>
		</Border>

		<ScrollViewer Name="LogScroll" Grid.Row="2"
					  VerticalScrollBarVisibility="Auto"
					  HorizontalScrollBarVisibility="Auto"
					  Background="$($theme.SearchBg)"
					  Padding="0,0,4,0">
			<StackPanel Name="LogPanel" Margin="16,12,16,12"/>
		</ScrollViewer>

		<Border Grid.Row="3" Background="$($theme.HeaderBg)"
				BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0"
				Padding="20,10,20,10">
			<Grid>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="Auto"/>
				</Grid.ColumnDefinitions>
				<StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
					<Ellipse Width="8" Height="8" Fill="$($theme.LowRiskBadge)" Margin="0,0,5,0"/>
					<TextBlock Text="$successLabel" FontSize="11" Foreground="$($theme.TextMuted)" Margin="0,0,14,0"/>
					<Ellipse Width="8" Height="8" Fill="$($theme.RiskHighBadge)" Margin="0,0,5,0"/>
					<TextBlock Text="$failedLabel" FontSize="11" Foreground="$($theme.TextMuted)" Margin="0,0,14,0"/>
					<Ellipse Width="8" Height="8" Fill="$($theme.RiskMediumBadge)" Margin="0,0,5,0"/>
					<TextBlock Text="$skippedWarningLabel" FontSize="11" Foreground="$($theme.TextMuted)" Margin="0,0,14,0"/>
					<Ellipse Width="8" Height="8" Fill="$($theme.TextMuted)" Margin="0,0,5,0"/>
					<TextBlock Text="$infoLabel" FontSize="11" Foreground="$($theme.TextMuted)"/>
				</StackPanel>
				<Button Name="BtnClose" Grid.Column="1" Content=""
						Padding="20,6" FontSize="13"/>
			</Grid>
		</Border>
	</Grid>
	</Border>
</Window>
"@

		$reader = [System.Xml.XmlNodeReader]::new($xaml)
		$dlg = [Windows.Markup.XamlReader]::Load($reader)
		$dlg.Owner = $Form

		$rootBorder = $dlg.FindName('RootBorder')
		$useDarkMode = if (Test-Path -Path Variable:\Script:CurrentThemeName) { $Script:CurrentThemeName -eq 'Dark' } else { $false }
		if (Test-Path -Path Variable:\Script:CurrentTheme)
		{
			$theme = $Script:CurrentTheme
			if ($rootBorder)
			{
				$rootBorder.Background = [System.Windows.Media.Brush](New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.Color]::FromArgb(255, [System.Convert]::ToInt32($theme.WindowBg.Substring(1, 2), 16), [System.Convert]::ToInt32($theme.WindowBg.Substring(3, 2), 16), [System.Convert]::ToInt32($theme.WindowBg.Substring(5, 2), 16))))
				$rootBorder.BorderBrush = [System.Windows.Media.Brush](New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.Color]::FromArgb(255, [System.Convert]::ToInt32($theme.BorderColor.Substring(1, 2), 16), [System.Convert]::ToInt32($theme.BorderColor.Substring(3, 2), 16), [System.Convert]::ToInt32($theme.BorderColor.Substring(5, 2), 16))))
				$rootBorder.BorderThickness = '1'
			}
		}
		else
		{
			if ($rootBorder)
			{
				$rootBorder.Background = [System.Windows.Media.Brush](New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.Color]::FromArgb(255, 241, 241, 241)))
				$rootBorder.BorderBrush = [System.Windows.Media.Brush](New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.Color]::FromArgb(255, 200, 200, 200)))
				$rootBorder.BorderThickness = '1'
			}
		}
		if (Test-Path -Path Function:\Set-GuiWindowChromeTheme)
		{
			[void](GUICommon\Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode $useDarkMode)
		}

		# Wire log dialog title bar
		$dlgTitleBar = $dlg.FindName('DlgTitleBar')
		$btnDlgClose = $dlg.FindName('BtnDlgClose')
		if ($dlgTitleBar) {
			$dlgTitleBar.Add_MouseLeftButtonDown({ $dlg.DragMove() }.GetNewClosure())
			$dhCtx = New-Object System.Windows.Controls.ContextMenu
			$dhCtxClose = New-Object System.Windows.Controls.MenuItem
			$dhCtxClose.Header = $closeLabel; $dhCtxClose.InputGestureText = 'Alt+F4'; $dhCtxClose.FontWeight = [System.Windows.FontWeights]::Bold
			$dhCtxRef = $dlg
			$dhCtxClose.Add_Click({ $dhCtxRef.Close() }.GetNewClosure())
			[void]$dhCtx.Items.Add($dhCtxClose)
			$dlgTitleBar.ContextMenu = $dhCtx
		}
		if ($btnDlgClose) { $btnDlgClose.Add_Click({ $dlg.Close() }.GetNewClosure()) }

		$logPanel = $dlg.FindName('LogPanel')
		$logScroll = $dlg.FindName('LogScroll')
		$txtLogPath = $dlg.FindName('TxtLogPath')
		$btnClose = $dlg.FindName('BtnClose')
		$btnRefresh = $dlg.FindName('BtnRefresh')
		$btnExternal = $dlg.FindName('BtnOpenExternal')

		$btnClose.Content = $closeLabel
		Set-ButtonChrome -Button $btnClose -Variant 'Primary' -Compact
		Set-ButtonChrome -Button $btnRefresh -Variant 'Subtle' -Compact -Muted
		Set-ButtonChrome -Button $btnExternal -Variant 'Subtle' -Compact -Muted
		$btnClose.IsCancel = $true

		$txtLogPath.Text = $LogPath

		$colorRules = @(
			@{ Pattern = '- success[!]?$';          Color = $theme.LowRiskBadge    }
			@{ Pattern = '- failed[!]?$';           Color = $theme.RiskHighBadge   }
			@{ Pattern = '- skipped[.]?$';          Color = $theme.RiskMediumBadge }
			@{ Pattern = '- already applied[.]?$';  Color = $theme.AccentBlue      }
			@{ Pattern = '\bERROR\b|\bFAIL\b';      Color = $theme.RiskHighBadge   }
			@{ Pattern = '\bWARN\b|\bWARNING\b';    Color = $theme.RiskMediumBadge }
			@{ Pattern = '^={3}';                   Color = $theme.AccentBlue      }
		)

		$logFontSizeLabel = $Script:GuiLayout.FontSizeLabel
		$logFontSizeSubheading = $Script:GuiLayout.FontSizeSubheading
		$loadLogContent = {
			$logPanel.Children.Clear()

			if (-not $LogPath -or -not (Test-Path -LiteralPath $LogPath -ErrorAction SilentlyContinue))
			{
				$tb = [System.Windows.Controls.TextBlock]::new()
				$tb.Text = (& $getBaselineBilingualString -Key 'GuiActionLogNotFound' -Fallback "Log file not found.`n{0}" -FormatArgs @($LogPath))
				$tb.FontSize = $logFontSizeSubheading
				$tb.Foreground = $bc.ConvertFromString($theme.RiskHighBadge)
				$tb.Margin = [System.Windows.Thickness]::new(0, 4, 0, 4)
				[void]($logPanel.Children.Add($tb))
				return
			}

			try
			{
				$lines = [System.IO.File]::ReadAllLines($LogPath)
			}
			catch
			{
				$tb = [System.Windows.Controls.TextBlock]::new()
				$tb.Text = "Failed to read log file: $($_.Exception.Message)"
				$tb.FontSize = $logFontSizeSubheading
				$tb.Foreground = $bc.ConvertFromString($theme.RiskHighBadge)
				$tb.Margin = [System.Windows.Thickness]::new(0, 4, 0, 4)
				[void]($logPanel.Children.Add($tb))
				return
			}

			foreach ($line in $lines)
			{
				$color = $theme.TextSecondary
				foreach ($rule in $colorRules)
				{
					if ($line -match $rule.Pattern)
					{
						$color = $rule.Color
						break
					}
				}

				$row = [System.Windows.Controls.Grid]::new()
				$colIcon = [System.Windows.Controls.ColumnDefinition]::new()
				$colIcon.Width = [System.Windows.GridLength]::Auto
				$colText = [System.Windows.Controls.ColumnDefinition]::new()
				$colText.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
				[void]$row.ColumnDefinitions.Add($colIcon)
				[void]$row.ColumnDefinitions.Add($colText)
				$row.Margin = [System.Windows.Thickness]::new(0, 1, 0, 1)

				$icon = [System.Windows.Controls.TextBlock]::new()
				$icon.Text = [char]0xF4F5
				$icon.FontFamily = [System.Windows.Media.FontFamily]::new('FluentSystemIcons')
				$icon.FontSize = $logFontSizeLabel
				$icon.Foreground = $bc.ConvertFromString($color)
				$icon.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
				$icon.Margin = [System.Windows.Thickness]::new(0, 1, 6, 0)
				[System.Windows.Controls.Grid]::SetColumn($icon, 0)

				$tb = [System.Windows.Controls.TextBlock]::new()
				$tb.Text = $line
				$tb.FontFamily = [System.Windows.Media.FontFamily]::new('Consolas, Courier New')
				$tb.FontSize = $logFontSizeLabel
				$tb.Foreground = $bc.ConvertFromString($color)
				$tb.TextWrapping = [System.Windows.TextWrapping]::NoWrap
				$tb.Margin = [System.Windows.Thickness]::new(0)
				[System.Windows.Controls.Grid]::SetColumn($tb, 1)

				[void]$row.Children.Add($icon)
				[void]$row.Children.Add($tb)
				[void]($logPanel.Children.Add($row))
			}

			$logScroll.ScrollToEnd()
		}.GetNewClosure()

		& $loadLogContent

		Register-GuiEventHandler -Source $btnClose -EventName 'Click' -Handler { $dlg.Close() }
		Register-GuiEventHandler -Source $btnRefresh -EventName 'Click' -Handler ({
			& $loadLogContent
			$txtLogPath.Text = $LogPath
		}.GetNewClosure())
		Register-GuiEventHandler -Source $btnExternal -EventName 'Click' -Handler ({
			if ($LogPath -and (Test-Path -LiteralPath $LogPath -ErrorAction SilentlyContinue))
			{
				Start-Process -FilePath 'notepad.exe' -ArgumentList $LogPath -ErrorAction SilentlyContinue
			}
		}.GetNewClosure())
		Register-GuiEventHandler -Source $dlg -EventName 'KeyDown' -Handler {
			param($s, $e)
			if ($e.Key -eq [System.Windows.Input.Key]::Escape) { $dlg.Close() }
		}

		[void]($dlg.ShowDialog())
	}

	<#
	    .SYNOPSIS
	    Internal function Show-ChangelogDialog.
	#>

	function Show-ChangelogDialog
	{
		param (
			[string]$ChangelogPath = $(Resolve-BaselineChangelogPath)
		)

		$theme = $Script:CurrentTheme
		$bc = New-SafeBrushConverter -Context 'DialogHelpers-ChangelogViewer'
		$scrollBarStyleXaml = Get-BaselineScrollBarStyleXaml -Theme $theme
		$changelogTitle = Get-UxLocalizedString -Key 'GuiMenuHelpChangelog' -Fallback 'Changelog'
		$refreshLabel = Get-UxLocalizedString -Key 'GuiRefreshButton' -Fallback 'Refresh'
		$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'
		$missingMessage = Get-UxLocalizedString -Key 'GuiMenuHelpChangelogMissing' -Fallback 'Changelog file not found.'

		[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$changelogTitle"
	Width="$($Script:GuiLayout.LogDialogWidth)" Height="$($Script:GuiLayout.LogDialogHeight)"
	MinWidth="$($Script:GuiLayout.LogDialogMinWidth)" MinHeight="$($Script:GuiLayout.LogDialogMinHeight)"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="FluentSystemIcons"
	FontSize="12"
	Background="Transparent"
	WindowStyle="None"
	AllowsTransparency="True">
	<Border Name="RootBorder" CornerRadius="8">
	<Border.Resources>
		$scrollBarStyleXaml
	</Border.Resources>
	<Grid>
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>

		<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="12,8,8,8" Cursor="Arrow">
			<Grid>
				<TextBlock Text="$changelogTitle" VerticalAlignment="Center" FontSize="12" Foreground="$($theme.TextPrimary)"/>
				<Button Name="BtnDlgClose" Content="x" FontFamily="Arial" FontSize="12" Width="32" Height="28"
					Background="Transparent" Foreground="$($theme.TextPrimary)" BorderThickness="0" Cursor="Hand"
					HorizontalAlignment="Right" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
			</Grid>
		</Border>

		<Border Grid.Row="1" Background="$($theme.HeaderBg)"
				BorderBrush="$($theme.BorderColor)" BorderThickness="0,0,0,1"
				Padding="20,14,20,14">
			<Grid>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="Auto"/>
				</Grid.ColumnDefinitions>
				<StackPanel Grid.Column="0">
					<TextBlock Text="$changelogTitle" FontSize="16" FontWeight="SemiBold"
							   Foreground="$($theme.TextPrimary)"/>
					<TextBlock Name="TxtChangelogPath" FontSize="11"
							   Foreground="$($theme.TextMuted)" Margin="0,2,0,0"
							   TextWrapping="Wrap"/>
				</StackPanel>
				<Button Name="BtnRefresh" Grid.Column="1" Content="$refreshLabel"
						Padding="12,5" FontSize="12" VerticalAlignment="Center"/>
			</Grid>
		</Border>

		<Border Grid.Row="2" Background="$($theme.SearchBg)" Padding="16,12,16,12">
			<TextBox Name="TxtChangelogContent"
					 IsReadOnly="True"
					 AcceptsReturn="True"
					 AcceptsTab="True"
					 TextWrapping="Wrap"
					 VerticalScrollBarVisibility="Auto"
					 HorizontalScrollBarVisibility="Disabled"
					 Background="Transparent"
					 BorderThickness="0"
					 Foreground="$($theme.TextSecondary)"
					 FontFamily="Consolas"
					 FontSize="$($Script:GuiLayout.FontSizeLabel)"/>
		</Border>

		<Border Grid.Row="3" Background="$($theme.HeaderBg)"
				BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0"
				Padding="20,10,20,10">
			<Grid>
				<Button Name="BtnClose" Content=""
						HorizontalAlignment="Right"
						Padding="20,6" FontSize="13"/>
			</Grid>
		</Border>
	</Grid>
	</Border>
</Window>
"@

		$reader = [System.Xml.XmlNodeReader]::new($xaml)
		$dlg = [Windows.Markup.XamlReader]::Load($reader)
		$dlg.Owner = $Form

		$rootBorder = $dlg.FindName('RootBorder')
		if ($rootBorder)
		{
			$rootBorder.Background = $bc.ConvertFromString($theme.WindowBg)
			$rootBorder.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
			$rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
		}

		[void](GUICommon\Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))

		$dlgTitleBar = $dlg.FindName('DlgTitleBar')
		$btnDlgClose = $dlg.FindName('BtnDlgClose')
		$txtChangelogPath = $dlg.FindName('TxtChangelogPath')
		$txtChangelogContent = $dlg.FindName('TxtChangelogContent')
		$btnRefresh = $dlg.FindName('BtnRefresh')
		$btnClose = $dlg.FindName('BtnClose')

		if ($dlgTitleBar)
		{
			$dlgTitleBar.Add_MouseLeftButtonDown({ $dlg.DragMove() }.GetNewClosure())
			$dlgCtx = New-Object System.Windows.Controls.ContextMenu
			$dlgCtxClose = New-Object System.Windows.Controls.MenuItem
			$dlgCtxClose.Header = $closeLabel
			$dlgCtxClose.InputGestureText = 'Alt+F4'
			$dlgCtxClose.FontWeight = [System.Windows.FontWeights]::Bold
			$dlgRefForContext = $dlg
			$dlgCtxClose.Add_Click({ $dlgRefForContext.Close() }.GetNewClosure())
			[void]$dlgCtx.Items.Add($dlgCtxClose)
			$dlgTitleBar.ContextMenu = $dlgCtx
		}
		if ($btnDlgClose) { $btnDlgClose.Add_Click({ $dlg.Close() }.GetNewClosure()) }

		$btnClose.Content = $closeLabel
		Set-ButtonChrome -Button $btnRefresh -Variant 'Subtle' -Compact -Muted
		Set-ButtonChrome -Button $btnClose -Variant 'Primary' -Compact
		$btnClose.IsCancel = $true

		$resolveCurrentChangelogVersion = {
			try
			{
				$versionCmd = Get-Command -Name 'Get-BaselineDisplayVersion' -CommandType Function -ErrorAction SilentlyContinue
				if ($versionCmd)
				{
					$displayVersion = & $versionCmd
					if (-not [string]::IsNullOrWhiteSpace([string]$displayVersion))
					{
						$m = [regex]::Match([string]$displayVersion, 'v?(\d+\.\d+\.\d+)(?:\s*\(([^)]+)\))?')
						if ($m.Success)
						{
							$base = $m.Groups[1].Value
							if ($m.Groups[2].Success -and -not [string]::IsNullOrWhiteSpace($m.Groups[2].Value))
							{
								return ('{0}-{1}' -f $base, $m.Groups[2].Value.Trim())
							}
							return $base
						}
					}
				}
			}
			catch { $null = $_ }
			return $null
		}

		$extractChangelogVersionSection = {
			param (
				[string]$Raw,
				[string]$Version
			)
			if ([string]::IsNullOrWhiteSpace($Raw) -or [string]::IsNullOrWhiteSpace($Version))
			{
				return $Raw
			}
			$lines = $Raw -split "`r?`n"
			$escaped = [regex]::Escape($Version)
			$startPattern = '^##\s+' + $escaped + '(?=\s|\||$)'
			$nextPattern = '^##\s+'
			$startIdx = -1
			for ($i = 0; $i -lt $lines.Length; $i++)
			{
				if ($lines[$i] -match $startPattern) { $startIdx = $i; break }
			}
			if ($startIdx -lt 0) { return $Raw }
			$endIdx = $lines.Length - 1
			for ($j = $startIdx + 1; $j -lt $lines.Length; $j++)
			{
				if ($lines[$j] -match $nextPattern) { $endIdx = $j - 1; break }
			}
			while ($endIdx -gt $startIdx -and ($lines[$endIdx].Trim() -eq '---' -or [string]::IsNullOrWhiteSpace($lines[$endIdx])))
			{
				$endIdx--
			}
			return ($lines[$startIdx..$endIdx] -join "`r`n")
		}

		$loadChangelogContent = {
			$resolvedPath = if ([string]::IsNullOrWhiteSpace([string]$ChangelogPath)) { Resolve-BaselineChangelogPath } else { $ChangelogPath }
			$txtChangelogPath.Text = if ([string]::IsNullOrWhiteSpace([string]$resolvedPath)) { '' } else { $resolvedPath }

			if ([string]::IsNullOrWhiteSpace([string]$resolvedPath) -or -not (Test-Path -LiteralPath $resolvedPath -PathType Leaf -ErrorAction SilentlyContinue))
			{
				$txtChangelogContent.Foreground = $bc.ConvertFromString($theme.RiskHighBadge)
				$txtChangelogContent.Text = if ([string]::IsNullOrWhiteSpace([string]$resolvedPath))
				{
					$missingMessage
				}
				else
				{
					"{0}`r`n`r`n{1}" -f $missingMessage, $resolvedPath
				}
				return
			}

			try
			{
				$resolvedFullPath = [System.IO.Path]::GetFullPath($resolvedPath)
				$txtChangelogPath.Text = $resolvedFullPath
				$txtChangelogContent.Foreground = $bc.ConvertFromString($theme.TextSecondary)
				$rawContent = [System.IO.File]::ReadAllText($resolvedFullPath)
				$currentVersion = & $resolveCurrentChangelogVersion
				$displayContent = if (-not [string]::IsNullOrWhiteSpace([string]$currentVersion))
				{
					& $extractChangelogVersionSection -Raw $rawContent -Version $currentVersion
				}
				else
				{
					$rawContent
				}
				$txtChangelogContent.Text = $displayContent
				$txtChangelogContent.ScrollToHome()
			}
			catch
			{
				$txtChangelogContent.Foreground = $bc.ConvertFromString($theme.RiskHighBadge)
				$txtChangelogContent.Text = "Failed to read changelog.`r`n`r`n$($_.Exception.Message)"
			}
		}.GetNewClosure()

		& $loadChangelogContent

		Register-GuiEventHandler -Source $btnRefresh -EventName 'Click' -Handler ({
			$ChangelogPath = Resolve-BaselineChangelogPath
			& $loadChangelogContent
		}.GetNewClosure())
		Register-GuiEventHandler -Source $btnClose -EventName 'Click' -Handler { $dlg.Close() }
		Register-GuiEventHandler -Source $dlg -EventName 'KeyDown' -Handler {
			param($s, $e)
			if ($e.Key -eq [System.Windows.Input.Key]::Escape) { $dlg.Close() }
		}

		[void]($dlg.ShowDialog())
	}

	<#
	    .SYNOPSIS
	    Internal function Show-ReadmeDialog.
	#>

	function Show-ReadmeDialog
	{
		param (
			[string]$ReadmePath = $(Resolve-BaselineReadmePath)
		)

		$theme = $Script:CurrentTheme
		$bc = New-SafeBrushConverter -Context 'DialogHelpers-ReadmeViewer'
		$scrollBarStyleXaml = Get-BaselineScrollBarStyleXaml -Theme $theme
		$readmeTitle = Get-UxLocalizedString -Key 'GuiMenuHelpReadme' -Fallback 'Readme'
		$readmeFontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeLabel' -Default 11
		$refreshLabel = Get-UxLocalizedString -Key 'GuiRefreshButton' -Fallback 'Refresh'
		$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'
		$missingMessage = Get-UxLocalizedString -Key 'GuiMenuHelpReadmeMissing' -Fallback 'README.md file not found.'

		[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	xmlns:wfi="clr-namespace:System.Windows.Forms.Integration;assembly=WindowsFormsIntegration"
	Title="$readmeTitle"
	Width="$($Script:GuiLayout.LogDialogWidth)" Height="$($Script:GuiLayout.LogDialogHeight)"
	MinWidth="$($Script:GuiLayout.LogDialogMinWidth)" MinHeight="$($Script:GuiLayout.LogDialogMinHeight)"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="FluentSystemIcons"
	FontSize="12"
	Background="Transparent"
	WindowStyle="None"
	AllowsTransparency="True">
	<Border Name="RootBorder" CornerRadius="8">
	<Border.Resources>
		$scrollBarStyleXaml
	</Border.Resources>
	<Grid>
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>

		<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="12,8,8,8" Cursor="Arrow">
			<Grid>
				<TextBlock Name="TxtDlgTitle" Text="$readmeTitle" VerticalAlignment="Center" FontSize="12" Foreground="$($theme.TextPrimary)"/>
				<Button Name="BtnDlgClose" Content="x" FontFamily="Arial" FontSize="12" Width="32" Height="28"
					Background="Transparent" Foreground="$($theme.TextPrimary)" BorderThickness="0" Cursor="Hand"
					HorizontalAlignment="Right" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
			</Grid>
		</Border>

		<Border Name="ReadmeHeaderBorder" Grid.Row="1" Background="$($theme.HeaderBg)"
				BorderBrush="$($theme.BorderColor)" BorderThickness="0,0,0,1"
				Padding="20,14,20,14">
			<Grid>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="Auto"/>
				</Grid.ColumnDefinitions>
				<StackPanel Grid.Column="0">
					<TextBlock Name="TxtReadmeTitle" Text="$readmeTitle" FontSize="16" FontWeight="SemiBold"
							   Foreground="$($theme.TextPrimary)"/>
					<TextBlock Name="TxtReadmePath" FontSize="11"
							   Foreground="$($theme.TextMuted)" Margin="0,2,0,0"
							   TextWrapping="Wrap"/>
				</StackPanel>
				<Button Name="BtnRefresh" Grid.Column="1" Content="$refreshLabel"
						Padding="12,5" FontSize="12" VerticalAlignment="Center"/>
			</Grid>
		</Border>

		<Border Name="ReadmeContentBorder" Grid.Row="2" Background="$($theme.SearchBg)" Padding="16,12,16,12">
			<Grid>
				<wfi:WindowsFormsHost Name="ReadmeWebHost" Visibility="Collapsed"/>
				<FlowDocumentScrollViewer Name="ReadmeFlowViewer"
										  IsToolBarVisible="False"
										  Background="Transparent"
										  BorderThickness="0"
										  VerticalScrollBarVisibility="Auto"
										  HorizontalScrollBarVisibility="Disabled"
										  Visibility="Visible"/>
			</Grid>
		</Border>

		<Border Name="ReadmeFooterBorder" Grid.Row="3" Background="$($theme.HeaderBg)"
				BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0"
				Padding="20,10,20,10">
			<Grid>
				<Button Name="BtnClose" Content=""
						HorizontalAlignment="Right"
						Padding="20,6" FontSize="13"/>
			</Grid>
		</Border>
	</Grid>
	</Border>
</Window>
"@

		$reader = [System.Xml.XmlNodeReader]::new($xaml)
		$dlg = [Windows.Markup.XamlReader]::Load($reader)
		$dlg.Owner = $Form

		$rootBorder = $dlg.FindName('RootBorder')
		if ($rootBorder)
		{
			$rootBorder.Background = $bc.ConvertFromString($theme.WindowBg)
			$rootBorder.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
			$rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
		}

		[void](GUICommon\Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))

		$dlgTitleBar = $dlg.FindName('DlgTitleBar')
		$btnDlgClose = $dlg.FindName('BtnDlgClose')
		$txtDlgTitle = $dlg.FindName('TxtDlgTitle')
		$readmeHeaderBorder = $dlg.FindName('ReadmeHeaderBorder')
		$txtReadmeTitle = $dlg.FindName('TxtReadmeTitle')
		$txtReadmePath = $dlg.FindName('TxtReadmePath')
		$txtReadmeContent = $null
		$readmeContentBorder = $dlg.FindName('ReadmeContentBorder')
		$readmeWebHost = $dlg.FindName('ReadmeWebHost')
		$readmeFlowViewer = $dlg.FindName('ReadmeFlowViewer')
		$readmeFooterBorder = $dlg.FindName('ReadmeFooterBorder')
		$btnRefresh = $dlg.FindName('BtnRefresh')
		$btnClose = $dlg.FindName('BtnClose')

		if ($dlgTitleBar)
		{
			$dlgTitleBar.Add_MouseLeftButtonDown({ $dlg.DragMove() }.GetNewClosure())
			$dlgCtx = New-Object System.Windows.Controls.ContextMenu
			$dlgCtxClose = New-Object System.Windows.Controls.MenuItem
			$dlgCtxClose.Header = $closeLabel
			$dlgCtxClose.InputGestureText = 'Alt+F4'
			$dlgCtxClose.FontWeight = [System.Windows.FontWeights]::Bold
			$dlgCtxClose.Add_Click({ $dlg.Close() }.GetNewClosure())
			[void]$dlgCtx.Items.Add($dlgCtxClose)
			$dlgTitleBar.ContextMenu = $dlgCtx
		}
		if ($btnDlgClose) { $btnDlgClose.Add_Click({ $dlg.Close() }.GetNewClosure()) }

		$btnClose.Content = $closeLabel
		Set-ButtonChrome -Button $btnRefresh -Variant 'Subtle' -Compact -Muted
		Set-ButtonChrome -Button $btnClose -Variant 'Primary' -Compact
		$btnClose.IsCancel = $true

		$getReadmeTheme = {
			param([hashtable]$ThemeOverride = $null)

			if ($ThemeOverride -and ($ThemeOverride -is [System.Collections.IDictionary]) -and $ThemeOverride.Count -gt 0)
			{
				return $ThemeOverride
			}

			if (Test-Path -Path Variable:\Script:CurrentTheme)
			{
				return $Script:CurrentTheme
			}

			return $theme
		}.GetNewClosure()

		$applyReadmeDialogTheme = {
			param([hashtable]$ThemeOverride = $null)

			$activeTheme = & $getReadmeTheme -ThemeOverride $ThemeOverride

			if ($rootBorder)
			{
				$rootBorder.Background = $bc.ConvertFromString($activeTheme.WindowBg)
				$rootBorder.BorderBrush = $bc.ConvertFromString($activeTheme.BorderColor)
				$rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
			}
			if ($dlgTitleBar)
			{
				$dlgTitleBar.Background = $bc.ConvertFromString($activeTheme.HeaderBg)
			}
			if ($txtDlgTitle)
			{
				$txtDlgTitle.Foreground = $bc.ConvertFromString($activeTheme.TextPrimary)
			}
			if ($btnDlgClose)
			{
				$btnDlgClose.Background = [System.Windows.Media.Brushes]::Transparent
				$btnDlgClose.Foreground = $bc.ConvertFromString($activeTheme.TextPrimary)
			}
			if ($readmeHeaderBorder)
			{
				$readmeHeaderBorder.Background = $bc.ConvertFromString($activeTheme.HeaderBg)
				$readmeHeaderBorder.BorderBrush = $bc.ConvertFromString($activeTheme.BorderColor)
				$readmeHeaderBorder.BorderThickness = [System.Windows.Thickness]::new(0, 0, 0, 1)
			}
			if ($txtReadmeTitle)
			{
				$txtReadmeTitle.Foreground = $bc.ConvertFromString($activeTheme.TextPrimary)
			}
			if ($txtReadmePath)
			{
				$txtReadmePath.Foreground = $bc.ConvertFromString($activeTheme.TextMuted)
			}
			if ($readmeContentBorder)
			{
				$readmeContentBorder.Background = $bc.ConvertFromString($activeTheme.SearchBg)
			}
			if ($readmeFlowViewer)
			{
				$readmeFlowViewer.Background = $bc.ConvertFromString($activeTheme.SearchBg)
			}
			if ($readmeFooterBorder)
			{
				$readmeFooterBorder.Background = $bc.ConvertFromString($activeTheme.HeaderBg)
				$readmeFooterBorder.BorderBrush = $bc.ConvertFromString($activeTheme.BorderColor)
				$readmeFooterBorder.BorderThickness = [System.Windows.Thickness]::new(0, 1, 0, 0)
			}
			if ($btnRefresh)
			{
				Set-ButtonChrome -Button $btnRefresh -Variant 'Subtle' -Compact -Muted
			}
			if ($btnClose)
			{
				Set-ButtonChrome -Button $btnClose -Variant 'Primary' -Compact
			}
		}.GetNewClosure()

		# Force the rendered markdown's foreground/opacity back to theme values.
		# Without this, Markdig.Wpf can emit block-level brushes (or residual
		# opacity) from its default stylesheet that render as unreadable washed
		# text against the dialog surface. Applied after every render and
		# rerun when the popup theme registry repaints an open README window.
		$setMarkdownViewerTheme = {
			param(
				[System.Windows.Controls.FlowDocumentScrollViewer]$Viewer,
				[string]$ForegroundHex,
				[hashtable]$ThemeOverride = $null
			)

			if (-not $Viewer) { return }
			$activeTheme = & $getReadmeTheme -ThemeOverride $ThemeOverride
			$Viewer.Background = $bc.ConvertFromString($activeTheme.SearchBg)
			if (-not $Viewer.Document) { return }

			$foregroundBrush = $bc.ConvertFromString($ForegroundHex)
			$Viewer.Document.Foreground = $foregroundBrush

			foreach ($block in $Viewer.Document.Blocks)
			{
				try
				{
					$block.Foreground = $foregroundBrush
					$block.Opacity    = 1.0
				}
				catch { $null = $_ }
			}
		}.GetNewClosure()

		$showReadmeAsText = {
			param(
				[string]$Content,
				[string]$ForegroundHex,
				[hashtable]$ThemeOverride = $null
			)
			$paragraph = [System.Windows.Documents.Paragraph]::new()
			$paragraph.Margin = [System.Windows.Thickness]::new(0)
			$run = [System.Windows.Documents.Run]::new($Content)
			$run.Foreground = $bc.ConvertFromString($ForegroundHex)
			$paragraph.Inlines.Add($run) | Out-Null
			$document = [System.Windows.Documents.FlowDocument]::new()
			$document.Background = [System.Windows.Media.Brushes]::Transparent
			$document.Foreground = $bc.ConvertFromString($ForegroundHex)
			$document.PagePadding = [System.Windows.Thickness]::new(0)
			$document.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe UI')
			$document.FontSize = [double]$readmeFontSize
			$document.Blocks.Add($paragraph) | Out-Null
			$readmeFlowViewer.Document = $document
			$readmeFlowViewer.Visibility = [System.Windows.Visibility]::Visible
			if ($readmeWebHost) { $readmeWebHost.Visibility = [System.Windows.Visibility]::Collapsed }
			& $setMarkdownViewerTheme -Viewer $readmeFlowViewer -ForegroundHex $ForegroundHex -ThemeOverride $ThemeOverride
		}.GetNewClosure()

		$showReadmeAsFlowDocument = {
			param(
				[System.Windows.Documents.FlowDocument]$Document,
				[hashtable]$ThemeOverride = $null
			)
			$activeTheme = & $getReadmeTheme -ThemeOverride $ThemeOverride
			$Document.Background = [System.Windows.Media.Brushes]::Transparent
			$Document.Foreground = $bc.ConvertFromString($activeTheme.TextPrimary)
			$Document.PagePadding = [System.Windows.Thickness]::new(0)
			$Document.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe UI')
			$Document.FontSize = [double]$readmeFontSize
			Set-BaselineReadmeFlowDocumentTheme -Document $Document -ActiveTheme $activeTheme -BrushConverter $bc -ReadmeFontSize $readmeFontSize
			$readmeFlowViewer.Document = $Document
			$readmeFlowViewer.Visibility = [System.Windows.Visibility]::Visible
			if ($readmeWebHost) { $readmeWebHost.Visibility = [System.Windows.Visibility]::Collapsed }
			& $setMarkdownViewerTheme -Viewer $readmeFlowViewer -ForegroundHex $activeTheme.TextPrimary -ThemeOverride $activeTheme
		}.GetNewClosure()

		$webView2Ready = $false
		$readmeWebView = $null
		try
		{
			$webView2RuntimeLoaded = Test-BaselineWebView2RuntimeReady
			if (-not $webView2RuntimeLoaded)
			{
				[void](Initialize-BaselineWebView2Runtime)
			}
			if (Test-BaselineWebView2RuntimeReady -and $readmeWebHost)
			{
				$readmeWebView = New-Object Microsoft.Web.WebView2.WinForms.WebView2
				$readmeWebView.Dock = [System.Windows.Forms.DockStyle]::Fill
				$readmeWebHost.Child = $readmeWebView
				$null = $readmeWebView.EnsureCoreWebView2Async().GetAwaiter().GetResult()
				$webView2Ready = $true
			}
		}
		catch
		{
			$webView2Ready = $false
			$readmeWebView = $null
		}

		$showReadmeAsWebView = {
			param([string]$Html)

			if ($webView2Ready -and $readmeWebView)
			{
				$readmeFlowViewer.Document = $null
				$readmeFlowViewer.Visibility = [System.Windows.Visibility]::Collapsed
				$readmeWebHost.Visibility = [System.Windows.Visibility]::Visible
				$readmeWebView.NavigateToString($Html)
				return $true
			}

			return $false
		}.GetNewClosure()

		$loadReadmeContent = {
			param([hashtable]$ThemeOverride = $null)

			$activeTheme = & $getReadmeTheme -ThemeOverride $ThemeOverride
			& $applyReadmeDialogTheme -ThemeOverride $activeTheme

			$resolvedPath = if ([string]::IsNullOrWhiteSpace([string]$ReadmePath)) { Resolve-BaselineReadmePath } else { $ReadmePath }
			$txtReadmePath.Text = if ([string]::IsNullOrWhiteSpace([string]$resolvedPath)) { '' } else { $resolvedPath }

			if ([string]::IsNullOrWhiteSpace([string]$resolvedPath) -or -not (Test-Path -LiteralPath $resolvedPath -PathType Leaf -ErrorAction SilentlyContinue))
			{
				$message = if ([string]::IsNullOrWhiteSpace([string]$resolvedPath))
				{
					$missingMessage
				}
				else
				{
					"{0}`r`n`r`n{1}" -f $missingMessage, $resolvedPath
				}
				& $showReadmeAsText -Content $message -ForegroundHex $activeTheme.RiskHighBadge -ThemeOverride $activeTheme
				return
			}

			try
			{
				$resolvedFullPath = [System.IO.Path]::GetFullPath($resolvedPath)
				$txtReadmePath.Text = $resolvedFullPath
				$markdownText = [System.IO.File]::ReadAllText($resolvedFullPath)
				$html = ConvertFrom-BaselineMarkdownToHtml `
					-Markdown $markdownText `
					-BackgroundColor $activeTheme.SearchBg `
					-ForegroundColor $activeTheme.TextPrimary `
					-MutedForegroundColor $activeTheme.TextMuted `
					-LinkColor $activeTheme.AccentBlue `
					-CodeBackgroundColor $activeTheme.HeaderBg

				if (-not (& $showReadmeAsWebView -Html $html))
				{
					$flowDocument = $null
					if (Test-BaselineMarkdownRuntimeReady)
					{
						try { $flowDocument = [Markdig.Wpf.Markdown]::ToFlowDocument($markdownText) }
						catch { $flowDocument = $null }
					}

					if ($flowDocument)
					{
						& $showReadmeAsFlowDocument -Document $flowDocument -ThemeOverride $activeTheme
					}
					else
					{
						& $showReadmeAsText -Content $markdownText -ForegroundHex $activeTheme.TextSecondary -ThemeOverride $activeTheme
					}
				}
			}
			catch
			{
				& $showReadmeAsText -Content ("Failed to read README.`r`n`r`n{0}" -f $_.Exception.Message) -ForegroundHex $activeTheme.RiskHighBadge -ThemeOverride $activeTheme
			}
		}.GetNewClosure()

		$readmeThemeCallback = {
			param(
				[System.Windows.Window]$Window,
				[hashtable]$Theme,
				[object]$UseDarkMode
			)

			$null = $Window
			$null = $UseDarkMode
			& $loadReadmeContent -ThemeOverride $Theme
		}.GetNewClosure()

		[void](GUICommon\Register-GuiPopupThemeWindow -Window $dlg -ThemeCallback $readmeThemeCallback)
		& $loadReadmeContent

		Register-GuiEventHandler -Source $btnRefresh -EventName 'Click' -Handler ({
			$ReadmePath = Resolve-BaselineReadmePath
			& $loadReadmeContent
		}.GetNewClosure())
		Register-GuiEventHandler -Source $btnClose -EventName 'Click' -Handler { $dlg.Close() }
		Register-GuiEventHandler -Source $dlg -EventName 'KeyDown' -Handler {
			param($s, $e)
			if ($e.Key -eq [System.Windows.Input.Key]::Escape) { $dlg.Close() }
		}

		[void]($dlg.ShowDialog())
	}

	# Guided Setup wizard: goal selection -> impact summary -> load preset.
	# Launched from the first-run welcome dialog CTA and the Start Guide button.
	# Steps: 1) Choose goal  2) Review impact  3) Preset loaded, user continues in main UI.
	<#
	    .SYNOPSIS
	    Internal function Show-GuidedSetupWizard.
	#>

	function Show-GuidedSetupWizard
	{
		param (
			[object]$ShowThemedDialogCapture,
			[scriptblock]$SetGuiPresetSelectionAction,
			[scriptblock]$SetGuiStatusTextAction,
			[hashtable]$Theme,
			[scriptblock]$ApplyButtonChrome,
			[object]$OwnerWindow,
			[object]$UseDarkMode = $true
		)

		$resolvedUseDarkMode = GUICommon\Get-GuiBooleanValue -Value $UseDarkMode -Default $(if (Test-Path -Path Variable:\Script:CurrentThemeName) { $Script:CurrentThemeName -eq 'Dark' } else { $true }) -Context 'Show-GuidedSetupWizard'

		# -- Step 1: Goal selection -----------------------------------------------
		$privacyLabel     = Get-UxLocalizedString -Key 'GuiGuidedGoalPrivacy'    -Fallback 'Privacy first'
		$performanceLabel = Get-UxLocalizedString -Key 'GuiGuidedGoalPerformance' -Fallback 'Performance first'
		$balancedLabel    = Get-UxLocalizedString -Key 'GuiGuidedGoalBalanced'   -Fallback 'Balanced'
		$cancelLabel      = Get-UxLocalizedString -Key 'GuiCloseButton'          -Fallback 'Close'
		$step1Title       = Get-UxLocalizedString -Key 'GuiGuidedStep1Title'     -Fallback 'Guided Setup - Step 1 of 2'
		$step1Message     = Get-UxLocalizedString -Key 'GuiGuidedStep1Message'   -Fallback "What is your main goal?`n`n- Privacy first - disable telemetry, advertising IDs, activity tracking, and data collection`n- Performance first - tune system responsiveness, visual effects, and background services`n- Balanced - a broad selection covering privacy, performance, and quality-of-life improvements"

		$goalChoice = & $ShowThemedDialogCapture `
			-Title $step1Title `
			-Message $step1Message `
			-Buttons @($cancelLabel, $privacyLabel, $performanceLabel, $balancedLabel) `
			-AccentButton $balancedLabel `
			-Theme $Theme `
			-ApplyButtonChrome $ApplyButtonChrome `
			-OwnerWindow $OwnerWindow `
			-UseDarkMode $resolvedUseDarkMode

		if ([string]::IsNullOrWhiteSpace([string]$goalChoice) -or [string]$goalChoice -eq $cancelLabel)
		{
			return
		}

		# Map goal -> preset and impact description
		$presetName = switch ([string]$goalChoice)
		{
			{ $_ -eq $privacyLabel }     { 'Minimal' }
			{ $_ -eq $performanceLabel } { 'Basic'   }
			default                      { 'Basic'   }
		}

		$impactLines = switch ([string]$goalChoice)
		{
			{ $_ -eq $privacyLabel } {
				Get-UxLocalizedString -Key 'GuiGuidedImpactPrivacy' -Fallback "The Minimal preset will be loaded.`n`n- Disables telemetry and diagnostic data collection`n- Removes advertising ID and activity history`n- Turns off location tracking and app launch tracking`n- Low risk - all changes are reversible`n`nCategories touched: Privacy & Telemetry, Initial Setup"
			}
			{ $_ -eq $performanceLabel } {
				Get-UxLocalizedString -Key 'GuiGuidedImpactPerformance' -Fallback "The Basic preset will be loaded.`n`n- Includes all privacy tweaks from Minimal`n- Tunes visual effects and background services`n- Reduces startup overhead and notification noise`n- Low-to-medium risk - most changes are reversible`n`nCategories touched: Privacy & Telemetry, System, UI & Personalization"
			}
			default {
				Get-UxLocalizedString -Key 'GuiGuidedImpactBalanced' -Fallback "The Basic preset will be loaded.`n`n- Covers privacy, performance, and quality-of-life improvements`n- Broader selection than Privacy first, safer than Advanced`n- Low-to-medium risk - most changes are reversible`n`nCategories touched: Privacy & Telemetry, System, UI & Personalization, Initial Setup"
			}
		}

		# -- Step 2: Impact summary -----------------------------------------------
		$backLabel  = Get-UxLocalizedString -Key 'GuiGuidedBack'       -Fallback '<- Back'
		$applyLabel = Get-UxLocalizedString -Key 'GuiGuidedLoadPreset' -Fallback 'Load preset'
		$step2Title = Get-UxLocalizedString -Key 'GuiGuidedStep2Title' -Fallback 'Guided Setup - Step 2 of 2'

		$impactChoice = & $ShowThemedDialogCapture `
			-Title $step2Title `
			-Message $impactLines `
			-Buttons @($cancelLabel, $backLabel, $applyLabel) `
			-AccentButton $applyLabel `
			-Theme $Theme `
			-ApplyButtonChrome $ApplyButtonChrome `
			-OwnerWindow $OwnerWindow `
			-UseDarkMode $resolvedUseDarkMode

		if ([string]$impactChoice -eq $backLabel)
		{
			Show-GuidedSetupWizard `
				-ShowThemedDialogCapture $ShowThemedDialogCapture `
				-SetGuiPresetSelectionAction $SetGuiPresetSelectionAction `
				-SetGuiStatusTextAction $SetGuiStatusTextAction `
				-Theme $Theme `
				-ApplyButtonChrome $ApplyButtonChrome `
				-OwnerWindow $OwnerWindow `
				-UseDarkMode $resolvedUseDarkMode
			return
		}

		if ([string]::IsNullOrWhiteSpace([string]$impactChoice) -or [string]$impactChoice -eq $cancelLabel)
		{
			return
		}

		# -- Step 3: Load preset ---------------------------------------------------
		if ($SetGuiPresetSelectionAction)
		{
			& $SetGuiPresetSelectionAction -PresetName $presetName
		}

		if ($SetGuiStatusTextAction)
		{
			$statusText = Get-UxPresetLoadedStatusText -PresetName $presetName
			& $SetGuiStatusTextAction -Text $statusText -Tone 'accent'
		}
	}
	#endregion Themed Dialog
