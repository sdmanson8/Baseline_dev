# Dialog helper split file loaded by Module\GUI\DialogHelpers.ps1.

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
	    Internal function Show-GuiSettingsDialog.
	    Presents the unified Settings dialog and returns a hashtable of updated
	    preferences when the user clicks Save, or $null when cancelled.
	#>

function Show-GuiSettingsDialog
{
	param (
		[hashtable]$Current
	)

	$__perf = Start-GuiPerfScope -Name 'Show-GuiSettingsDialog.Open'
	$theme = $Script:CurrentTheme
	if (-not $theme)
	{
		Stop-GuiPerfScope -Scope $__perf -ExtraNote 'no-theme'
		return $null
	}

	if (-not $Current) { $Current = @{} }

	$bc = New-SafeBrushConverter -Context 'DialogHelpers-Settings'
	$windowTitle = Get-UxLocalizedString -Key 'GuiSettings' -Fallback 'Settings'
	$windowSubtitle = Get-UxLocalizedString -Key 'GuiSettingsSubtitle' -Fallback 'Configure how Baseline looks and behaves. These are user preferences only.'
	$cancelLabel = Get-UxLocalizedString -Key 'GuiCancelButton' -Fallback 'Cancel'
	$saveLabel = Get-UxLocalizedString -Key 'GuiSaveButton' -Fallback 'Save'
	$exportSupportBundleLabel = Get-UxLocalizedString -Key 'GuiMenuToolsExportSupportBundle' -Fallback 'Export Support Bundle...'
	$openExportBundleButtonLabel = Get-UxLocalizedString -Key 'GuiSettingsOpenExportBundleTool' -Fallback 'Open Export Support Bundle tool'
	$debugExportHint = "Need to send diagnostics? Enable debug mode, reproduce the issue, then use Tools -> $exportSupportBundleLabel."

	$generalHeading = Get-UxLocalizedString -Key 'GuiSettingsGroupGeneral' -Fallback 'General'
	$appearanceHeading = Get-UxLocalizedString -Key 'GuiSettingsGroupAppearance' -Fallback 'Appearance'
	$safetyHeading = Get-UxLocalizedString -Key 'GuiSettingsGroupSafety' -Fallback 'Safety / Execution'
	$appsHeading = Get-UxLocalizedString -Key 'GuiSettingsGroupApplications' -Fallback 'Applications'
	$loggingHeading = Get-UxLocalizedString -Key 'GuiSettingsGroupLogging' -Fallback 'Logging'
	$advancedHeading = Get-UxLocalizedString -Key 'GuiSettingsGroupAdvanced' -Fallback 'Advanced'

	$cardBg = if ($theme.CardBg) { [string]$theme.CardBg } else { [string]$theme.PanelBg }
	$cardBorder = if ($theme.CardBorder) { [string]$theme.CardBorder } else { [string]$theme.BorderColor }
	$tabHoverBg = if ($theme.InputHoverBg) { [string]$theme.InputHoverBg } else { [string]$theme.CardBg }
	$textPrimary = if ($theme.TextPrimary) { [string]$theme.TextPrimary } else { '#F4F7FF' }
	$textSecondary = if ($theme.TextSecondary) { [string]$theme.TextSecondary } else { '#B8C1D9' }
	$textMuted = if ($theme.TextMuted) { [string]$theme.TextMuted } else { '#828AA2' }
	$accentBlue = if ($theme.AccentBlue) { [string]$theme.AccentBlue } else { '#7CB7FF' }
	$activeBorder = if ($theme.ActiveTabBorder) { [string]$theme.ActiveTabBorder } else { $accentBlue }
	$surfaceControl = if ($theme.InputBg) { [string]$theme.InputBg } elseif ($theme.SearchBg) { [string]$theme.SearchBg } else { '#262D40' }
	$surfaceHover = if ($theme.InputHoverBg) { [string]$theme.InputHoverBg } elseif ($theme.CardHoverBg) { [string]$theme.CardHoverBg } else { '#30384E' }
	$controlBorder = if ($theme.SearchBorder) { [string]$theme.SearchBorder } elseif ($theme.BorderColor) { [string]$theme.BorderColor } else { '#293044' }
	$selectionSurface = if ($theme.StatusPillBg) { [string]$theme.StatusPillBg } elseif ($theme.TabActiveBg) { [string]$theme.TabActiveBg } else { $surfaceHover }

	[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$windowTitle"
	Width="880" Height="660"
	MinWidth="760" MinHeight="560"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="Segoe UI"
	FontSize="12"
	Background="Transparent"
	WindowStyle="None"
	AllowsTransparency="True">
	<Window.Resources>
		<SolidColorBrush x:Key="{x:Static SystemColors.WindowBrushKey}" Color="$surfaceControl"/>
		<SolidColorBrush x:Key="{x:Static SystemColors.WindowTextBrushKey}" Color="$textPrimary"/>
		<SolidColorBrush x:Key="{x:Static SystemColors.ControlBrushKey}" Color="$surfaceControl"/>
		<SolidColorBrush x:Key="{x:Static SystemColors.ControlTextBrushKey}" Color="$textPrimary"/>
		<SolidColorBrush x:Key="{x:Static SystemColors.HighlightBrushKey}" Color="$selectionSurface"/>
		<SolidColorBrush x:Key="{x:Static SystemColors.HighlightTextBrushKey}" Color="$textPrimary"/>
		<SolidColorBrush x:Key="{x:Static SystemColors.MenuBrushKey}" Color="$surfaceControl"/>
		<SolidColorBrush x:Key="{x:Static SystemColors.MenuTextBrushKey}" Color="$textPrimary"/>
		<Style TargetType="TextBlock" x:Key="SectionHeading">
			<Setter Property="FontSize" Value="14"/>
			<Setter Property="FontWeight" Value="SemiBold"/>
			<Setter Property="Foreground" Value="$textPrimary"/>
			<Setter Property="Margin" Value="0,0,0,4"/>
		</Style>
		<Style TargetType="TextBlock" x:Key="SectionSubtitle">
			<Setter Property="FontSize" Value="11"/>
			<Setter Property="Foreground" Value="$textMuted"/>
			<Setter Property="Margin" Value="0,0,0,16"/>
			<Setter Property="TextWrapping" Value="Wrap"/>
		</Style>
		<Style TargetType="TextBlock" x:Key="FieldLabel">
			<Setter Property="FontSize" Value="12"/>
			<Setter Property="FontWeight" Value="Medium"/>
			<Setter Property="Foreground" Value="$textPrimary"/>
			<Setter Property="Margin" Value="0,0,0,6"/>
		</Style>
		<Style TargetType="TextBlock" x:Key="HelperText">
			<Setter Property="FontSize" Value="11"/>
			<Setter Property="Foreground" Value="$textMuted"/>
			<Setter Property="Margin" Value="0,4,0,0"/>
			<Setter Property="TextWrapping" Value="Wrap"/>
		</Style>
		<Style TargetType="CheckBox" x:Key="SettingsCheck">
			<Setter Property="Foreground" Value="$textPrimary"/>
			<Setter Property="FontSize" Value="12"/>
			<Setter Property="FontWeight" Value="Medium"/>
			<Setter Property="Margin" Value="0,0,0,10"/>
			<Style.Triggers>
				<Trigger Property="IsEnabled" Value="False">
					<Setter Property="Foreground" Value="$textSecondary"/>
					<Setter Property="Opacity" Value="1"/>
				</Trigger>
			</Style.Triggers>
		</Style>
		<Style TargetType="{x:Type ComboBoxItem}" x:Key="SettingsComboItem">
			<Setter Property="Background" Value="$surfaceControl"/>
			<Setter Property="Foreground" Value="$textPrimary"/>
			<Setter Property="Padding" Value="10,4"/>
			<Setter Property="HorizontalContentAlignment" Value="Stretch"/>
			<Setter Property="MinHeight" Value="28"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="{x:Type ComboBoxItem}">
						<Border x:Name="ItemRoot"
								Background="{TemplateBinding Background}"
								BorderBrush="{TemplateBinding BorderBrush}"
								BorderThickness="{TemplateBinding BorderThickness}"
								Padding="{TemplateBinding Padding}"
								SnapsToDevicePixels="True">
							<ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
											  VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
						</Border>
						<ControlTemplate.Triggers>
							<Trigger Property="IsMouseOver" Value="True">
								<Setter TargetName="ItemRoot" Property="Background" Value="$surfaceHover"/>
							</Trigger>
							<Trigger Property="IsSelected" Value="True">
								<Setter TargetName="ItemRoot" Property="Background" Value="$selectionSurface"/>
							</Trigger>
						</ControlTemplate.Triggers>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
			<Style.Triggers>
				<Trigger Property="IsMouseOver" Value="True">
					<Setter Property="Background" Value="$surfaceHover"/>
					<Setter Property="Foreground" Value="$textPrimary"/>
				</Trigger>
				<Trigger Property="IsSelected" Value="True">
					<Setter Property="Background" Value="$selectionSurface"/>
					<Setter Property="Foreground" Value="$textPrimary"/>
				</Trigger>
			</Style.Triggers>
		</Style>
		<Style TargetType="ComboBox" x:Key="SettingsCombo">
			<Setter Property="Width" Value="320"/>
			<Setter Property="HorizontalAlignment" Value="Left"/>
			<Setter Property="Margin" Value="0,0,0,18"/>
			<Setter Property="Padding" Value="10,4"/>
			<Setter Property="MinHeight" Value="30"/>
			<Setter Property="Background" Value="$surfaceControl"/>
			<Setter Property="Foreground" Value="$textPrimary"/>
			<Setter Property="BorderBrush" Value="$controlBorder"/>
			<Setter Property="BorderThickness" Value="1"/>
			<Setter Property="Opacity" Value="1"/>
			<Setter Property="OverridesDefaultStyle" Value="True"/>
			<Setter Property="ItemContainerStyle" Value="{StaticResource SettingsComboItem}"/>
			<Setter Property="TextElement.Foreground" Value="$textPrimary"/>
			<Setter Property="HorizontalContentAlignment" Value="Left"/>
			<Setter Property="VerticalContentAlignment" Value="Center"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="{x:Type ComboBox}">
						<Grid SnapsToDevicePixels="True" TextElement.Foreground="{TemplateBinding Foreground}">
							<Border x:Name="ComboRoot"
									Background="{TemplateBinding Background}"
									BorderBrush="{TemplateBinding BorderBrush}"
									BorderThickness="{TemplateBinding BorderThickness}"
									CornerRadius="4"
									SnapsToDevicePixels="True"/>
							<ToggleButton x:Name="DropDownToggle"
										  Focusable="False"
										  ClickMode="Press"
										  Background="Transparent"
										  BorderBrush="Transparent"
										  BorderThickness="0"
										  HorizontalAlignment="Stretch"
										  VerticalAlignment="Stretch"
										  IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}">
								<ToggleButton.Template>
									<ControlTemplate TargetType="{x:Type ToggleButton}">
										<Border Background="Transparent"/>
									</ControlTemplate>
								</ToggleButton.Template>
							</ToggleButton>
							<ContentPresenter x:Name="ContentSite"
											  Margin="{TemplateBinding Padding}"
											  HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
											  VerticalAlignment="{TemplateBinding VerticalContentAlignment}"
											  Content="{TemplateBinding SelectionBoxItem}"
											  ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
											  ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
											  ContentStringFormat="{TemplateBinding SelectionBoxItemStringFormat}"
											  IsHitTestVisible="False"
											  RecognizesAccessKey="True"/>
							<Path x:Name="Arrow"
								  HorizontalAlignment="Right"
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
								  IsHitTestVisible="False"/>
							<Popup x:Name="Popup"
								   Placement="Bottom"
								   PlacementTarget="{Binding RelativeSource={RelativeSource TemplatedParent}}"
								   AllowsTransparency="True"
								   Focusable="False"
								   IsOpen="{TemplateBinding IsDropDownOpen}"
								   PopupAnimation="Slide">
								<Border MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}"
										Background="$surfaceControl"
										BorderBrush="$controlBorder"
										BorderThickness="1"
										CornerRadius="6"
										SnapsToDevicePixels="True">
									<ScrollViewer Margin="4,6,4,6" MaxHeight="260" SnapsToDevicePixels="True">
										<ItemsPresenter KeyboardNavigation.DirectionalNavigation="Contained"/>
									</ScrollViewer>
								</Border>
							</Popup>
						</Grid>
						<ControlTemplate.Triggers>
							<Trigger Property="IsMouseOver" Value="True">
								<Setter TargetName="ComboRoot" Property="Background" Value="$surfaceHover"/>
								<Setter TargetName="ComboRoot" Property="BorderBrush" Value="$activeBorder"/>
							</Trigger>
							<Trigger Property="IsKeyboardFocusWithin" Value="True">
								<Setter TargetName="ComboRoot" Property="Background" Value="$surfaceHover"/>
								<Setter TargetName="ComboRoot" Property="BorderBrush" Value="$activeBorder"/>
							</Trigger>
							<Trigger Property="IsDropDownOpen" Value="True">
								<Setter TargetName="ComboRoot" Property="Background" Value="$surfaceHover"/>
								<Setter TargetName="ComboRoot" Property="BorderBrush" Value="$activeBorder"/>
							</Trigger>
							<Trigger Property="IsEnabled" Value="False">
								<Setter Property="Foreground" Value="$textSecondary"/>
								<Setter TargetName="ComboRoot" Property="Background" Value="$surfaceControl"/>
								<Setter TargetName="ComboRoot" Property="BorderBrush" Value="$controlBorder"/>
								<Setter TargetName="Arrow" Property="Stroke" Value="$textSecondary"/>
							</Trigger>
						</ControlTemplate.Triggers>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
			<Style.Triggers>
				<Trigger Property="IsKeyboardFocusWithin" Value="True">
					<Setter Property="Background" Value="$surfaceHover"/>
					<Setter Property="BorderBrush" Value="$activeBorder"/>
				</Trigger>
				<Trigger Property="IsDropDownOpen" Value="True">
					<Setter Property="Background" Value="$surfaceHover"/>
					<Setter Property="BorderBrush" Value="$activeBorder"/>
				</Trigger>
				<Trigger Property="IsEnabled" Value="False">
					<Setter Property="Background" Value="$surfaceControl"/>
					<Setter Property="Foreground" Value="$textSecondary"/>
					<Setter Property="Opacity" Value="1"/>
				</Trigger>
			</Style.Triggers>
		</Style>
		<Style TargetType="TextBox" x:Key="SettingsTextBox">
			<Setter Property="HorizontalAlignment" Value="Left"/>
			<Setter Property="Margin" Value="0,0,0,18"/>
			<Setter Property="Padding" Value="8,6"/>
			<Setter Property="MinHeight" Value="30"/>
			<Setter Property="Background" Value="$surfaceControl"/>
			<Setter Property="Foreground" Value="$textPrimary"/>
			<Setter Property="BorderBrush" Value="$controlBorder"/>
			<Setter Property="BorderThickness" Value="1"/>
			<Setter Property="CaretBrush" Value="$textPrimary"/>
			<Setter Property="SelectionBrush" Value="$selectionSurface"/>
			<Setter Property="Opacity" Value="1"/>
			<Style.Triggers>
				<Trigger Property="IsKeyboardFocusWithin" Value="True">
					<Setter Property="Background" Value="$surfaceHover"/>
					<Setter Property="BorderBrush" Value="$activeBorder"/>
				</Trigger>
				<Trigger Property="IsEnabled" Value="False">
					<Setter Property="Background" Value="$surfaceControl"/>
					<Setter Property="Foreground" Value="$textSecondary"/>
					<Setter Property="Opacity" Value="1"/>
				</Trigger>
			</Style.Triggers>
		</Style>
		<Style TargetType="TabItem">
			<Setter Property="Padding" Value="18,10"/>
			<Setter Property="Margin" Value="0,0,4,0"/>
			<Setter Property="FontSize" Value="13"/>
			<Setter Property="FontWeight" Value="Normal"/>
			<Setter Property="Foreground" Value="$textMuted"/>
			<Setter Property="Background" Value="Transparent"/>
			<Setter Property="Cursor" Value="Hand"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="TabItem">
						<Border Name="TabRoot"
								Background="{TemplateBinding Background}"
								BorderBrush="Transparent"
								BorderThickness="0,0,0,3"
								Padding="{TemplateBinding Padding}"
								CornerRadius="4,4,0,0"
								SnapsToDevicePixels="True">
							<ContentPresenter ContentSource="Header"
											  HorizontalAlignment="Center"
											  VerticalAlignment="Center"
											  RecognizesAccessKey="True"/>
						</Border>
						<ControlTemplate.Triggers>
							<Trigger Property="IsMouseOver" Value="True">
								<Setter Property="Foreground" Value="$textPrimary"/>
								<Setter TargetName="TabRoot" Property="Background" Value="$tabHoverBg"/>
							</Trigger>
							<Trigger Property="IsSelected" Value="True">
								<Setter Property="Foreground" Value="$textPrimary"/>
								<Setter Property="FontWeight" Value="SemiBold"/>
								<Setter TargetName="TabRoot" Property="Background" Value="$cardBg"/>
								<Setter TargetName="TabRoot" Property="BorderBrush" Value="$activeBorder"/>
							</Trigger>
						</ControlTemplate.Triggers>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
		</Style>
	</Window.Resources>
	<Border Name="RootBorder" CornerRadius="8">
		<Grid>
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="*"/>
				<RowDefinition Height="Auto"/>
			</Grid.RowDefinitions>

			<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="14,8,8,8" Cursor="Arrow">
				<Grid>
					<TextBlock Text="$windowTitle" VerticalAlignment="Center" FontSize="12" Foreground="$($theme.TextPrimary)"/>
					<Button Name="BtnDlgClose" Content="x" FontFamily="Arial" FontSize="12" Width="32" Height="28"
						Background="Transparent" Foreground="$($theme.TextPrimary)" BorderThickness="0" Cursor="Hand"
						HorizontalAlignment="Right" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
				</Grid>
			</Border>

			<Border Grid.Row="1" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,0,0,1"
					Padding="24,16,24,16">
				<StackPanel>
					<TextBlock Text="$windowTitle" FontSize="18" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
					<TextBlock Text="$windowSubtitle" FontSize="12" Foreground="$($theme.TextMuted)" Margin="0,4,0,0" TextWrapping="Wrap"/>
				</StackPanel>
			</Border>

			<TabControl Name="SettingsTabs" Grid.Row="2" Margin="20,14,20,14"
						Background="Transparent" BorderThickness="0" Padding="0">

				<TabItem Header="$generalHeading">
					<Border Background="$cardBg" BorderBrush="$cardBorder" BorderThickness="1" CornerRadius="6" Margin="0,8,0,0">
						<ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0">
							<StackPanel Margin="24,20,24,20" MaxWidth="640" HorizontalAlignment="Left">
								<TextBlock Style="{StaticResource SectionHeading}" Text="General preferences"/>
								<TextBlock Style="{StaticResource SectionSubtitle}" Text="Startup behavior and language."/>

								<TextBlock Style="{StaticResource FieldLabel}" Name="LblLanguage" Text="Language"/>
								<Grid Width="360" HorizontalAlignment="Left" Margin="0,0,0,18">
									<ToggleButton Name="BtnSettingsLanguage" Height="30" Padding="10,4" Cursor="Hand"
											HorizontalContentAlignment="Stretch" VerticalContentAlignment="Center"
											Background="$surfaceControl" Foreground="$textPrimary"
											BorderBrush="$controlBorder" BorderThickness="1">
										<ToggleButton.Template>
											<ControlTemplate TargetType="{x:Type ToggleButton}">
												<Border x:Name="LangBtnBorder" CornerRadius="4"
														Background="{TemplateBinding Background}"
														BorderBrush="{TemplateBinding BorderBrush}"
														BorderThickness="{TemplateBinding BorderThickness}"
														Padding="{TemplateBinding Padding}">
													<ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
																	  VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
												</Border>
												<ControlTemplate.Triggers>
													<Trigger Property="IsMouseOver" Value="True">
														<Setter TargetName="LangBtnBorder" Property="Background" Value="$surfaceHover"/>
														<Setter TargetName="LangBtnBorder" Property="BorderBrush" Value="$activeBorder"/>
													</Trigger>
													<Trigger Property="IsChecked" Value="True">
														<Setter TargetName="LangBtnBorder" Property="Background" Value="$surfaceHover"/>
														<Setter TargetName="LangBtnBorder" Property="BorderBrush" Value="$activeBorder"/>
													</Trigger>
												</ControlTemplate.Triggers>
											</ControlTemplate>
										</ToggleButton.Template>
										<Grid>
											<Grid.ColumnDefinitions>
												<ColumnDefinition Width="*"/>
												<ColumnDefinition Width="Auto"/>
											</Grid.ColumnDefinitions>
											<TextBlock Name="TxtSettingsLanguageDisplay" Grid.Column="0" VerticalAlignment="Center" HorizontalAlignment="Left" TextTrimming="CharacterEllipsis" Foreground="$textPrimary" Text=""/>
											<Path Grid.Column="1" Margin="8,0,2,0" VerticalAlignment="Center" Data="M 0 0 L 4 4 L 8 0" Stroke="$textPrimary" StrokeThickness="1.6" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Stretch="Fill" Width="8" Height="4" IsHitTestVisible="False"/>
										</Grid>
									</ToggleButton>
									<Popup Name="SettingsLanguagePopup" StaysOpen="False" Placement="Bottom" PlacementTarget="{Binding ElementName=BtnSettingsLanguage}" AllowsTransparency="True" IsOpen="{Binding IsChecked, ElementName=BtnSettingsLanguage, Mode=TwoWay}">
										<Border Background="$cardBg" BorderBrush="$controlBorder" BorderThickness="1" CornerRadius="6" Padding="6">
											<StackPanel Width="360">
												<TextBox Name="TxtSettingsLanguageSearch" Height="28" Padding="10,4" Margin="0,0,0,6" VerticalContentAlignment="Center"
														Background="$surfaceControl" Foreground="$textPrimary"
														BorderBrush="$controlBorder" BorderThickness="1" CaretBrush="$textPrimary"/>
												<ScrollViewer VerticalScrollBarVisibility="Auto" MaxHeight="320">
													<StackPanel Name="SettingsLanguageListPanel"/>
												</ScrollViewer>
											</StackPanel>
										</Border>
									</Popup>
								</Grid>
								<TextBlock Style="{StaticResource HelperText}" Text="Choose the UI language used throughout Baseline."/>

								<TextBlock Style="{StaticResource FieldLabel}" Name="LblDefaultStartupMode" Text="Default startup mode"/>
								<ComboBox Style="{StaticResource SettingsCombo}" Name="CmbDefaultStartupMode"/>

								<Border Background="$($theme.BorderColor)" Height="1" Margin="0,4,0,18" Opacity="0.35"/>

								<CheckBox Style="{StaticResource SettingsCheck}" Name="ChkRestoreLastSession" Content="Restore last session on launch"/>
								<CheckBox Style="{StaticResource SettingsCheck}" Name="ChkAutoScanOnLaunch" Content="Auto-scan system on launch"/>
								<CheckBox Style="{StaticResource SettingsCheck}" Name="ChkHideUnavailableItems" Content="Hide items not available on this system"/>
								<TextBlock Style="{StaticResource HelperText}" Text="When off, items that don't apply to this system are shown greyed-out with a badge instead of being hidden."/>
							</StackPanel>
						</ScrollViewer>
					</Border>
				</TabItem>

				<TabItem Header="$appearanceHeading">
					<Border Background="$cardBg" BorderBrush="$cardBorder" BorderThickness="1" CornerRadius="6" Margin="0,8,0,0">
						<ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0">
							<StackPanel Margin="24,20,24,20" MaxWidth="640" HorizontalAlignment="Left">
								<TextBlock Style="{StaticResource SectionHeading}" Text="Appearance"/>
								<TextBlock Style="{StaticResource SectionSubtitle}" Text="Theme and UI density."/>

								<TextBlock Style="{StaticResource FieldLabel}" Name="LblTheme" Text="Theme"/>
								<ComboBox Style="{StaticResource SettingsCombo}" Name="CmbTheme"/>

								<TextBlock Style="{StaticResource FieldLabel}" Name="LblUIDensity" Text="UI density"/>
								<ComboBox Style="{StaticResource SettingsCombo}" Name="CmbUIDensity"/>
								<TextBlock Style="{StaticResource HelperText}" Text="Compact reduces padding around rows and controls."/>
							</StackPanel>
						</ScrollViewer>
					</Border>
				</TabItem>

				<TabItem Header="$safetyHeading">
					<Border Background="$cardBg" BorderBrush="$cardBorder" BorderThickness="1" CornerRadius="6" Margin="0,8,0,0">
						<ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0">
							<StackPanel Margin="24,20,24,20" MaxWidth="640" HorizontalAlignment="Left">
								<TextBlock Style="{StaticResource SectionHeading}" Text="Run behavior"/>
								<TextBlock Style="{StaticResource SectionSubtitle}" Text="Defaults that apply before tweaks are executed."/>

								<CheckBox Style="{StaticResource SettingsCheck}" Name="ChkSafeModeDefault" Content="Enable Safe Mode by default"/>
								<CheckBox Style="{StaticResource SettingsCheck}" Name="ChkRequireRunConfirmation" Content="Require confirmation before Run"/>
								<CheckBox Style="{StaticResource SettingsCheck}" Name="ChkPreviewBeforeRunDefault" Content="Show preview before Run by default"/>

								<Border Background="$($theme.BorderColor)" Height="1" Margin="0,12,0,20" Opacity="0.35"/>

								<TextBlock Style="{StaticResource SectionHeading}" Text="Audit retention"/>
								<TextBlock Style="{StaticResource SectionSubtitle}" Text="Used by audit exports, log cleanup, and support bundles."/>

								<TextBlock Style="{StaticResource FieldLabel}" Name="LblAuditRetention" Text="Retention window"/>
								<ComboBox Style="{StaticResource SettingsCombo}" Name="CmbAuditRetention"/>
							</StackPanel>
						</ScrollViewer>
					</Border>
				</TabItem>

				<TabItem Header="$appsHeading">
					<Border Background="$cardBg" BorderBrush="$cardBorder" BorderThickness="1" CornerRadius="6" Margin="0,8,0,0">
						<ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0">
							<StackPanel Margin="24,20,24,20" MaxWidth="640" HorizontalAlignment="Left">
								<TextBlock Style="{StaticResource SectionHeading}" Text="Application management"/>
								<TextBlock Style="{StaticResource SectionSubtitle}" Text="Installer preferences for managed apps."/>

								<TextBlock Style="{StaticResource FieldLabel}" Name="LblPackageSource" Text="Preferred package source"/>
								<ComboBox Style="{StaticResource SettingsCombo}" Name="CmbPackageSource"/>
								<Border Background="$($theme.BorderColor)" Height="1" Margin="0,4,0,18" Opacity="0.35"/>
								<CheckBox Style="{StaticResource SettingsCheck}" Name="ChkAppsSilentInstall" Content="Silent install when supported"/>
								<CheckBox Style="{StaticResource SettingsCheck}" Name="ChkAppsAutoUpdate" Content="Automatically update managed apps"/>
							</StackPanel>
						</ScrollViewer>
					</Border>
				</TabItem>

				<TabItem Header="$loggingHeading">
					<Border Background="$cardBg" BorderBrush="$cardBorder" BorderThickness="1" CornerRadius="6" Margin="0,8,0,0">
						<ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0">
							<StackPanel Margin="24,20,24,20" MaxWidth="640" HorizontalAlignment="Left">
								<TextBlock Style="{StaticResource SectionHeading}" Text="Logging"/>
								<TextBlock Style="{StaticResource SectionSubtitle}" Text="Control diagnostic output and log file location."/>

								<CheckBox Style="{StaticResource SettingsCheck}" Name="ChkLoggingEnabled" Content="Enable logging"/>
								<CheckBox Style="{StaticResource SettingsCheck}" Name="ChkDebugLogging" Content="Debug Mode (verbose logging + perf trace)"/>
								<TextBlock Style="{StaticResource HelperText}" Text="$debugExportHint"/>
								<Button Name="BtnSettingsExportSupportBundle" Margin="0,6,0,0" HorizontalAlignment="Left" Padding="0" Background="Transparent" BorderBrush="Transparent" BorderThickness="0" Cursor="Hand">
									<TextBlock FontSize="11" Foreground="$accentBlue" Text="$openExportBundleButtonLabel" TextDecorations="Underline"/>
								</Button>

								<Border Background="$($theme.BorderColor)" Height="1" Margin="0,8,0,20" Opacity="0.35"/>

								<TextBlock Style="{StaticResource FieldLabel}" Name="LblLogLevel" Text="Log level"/>
								<ComboBox Style="{StaticResource SettingsCombo}" Name="CmbLogLevel"/>
								<TextBlock Style="{StaticResource FieldLabel}" Name="LblLogFolderPath" Text="Current log folder"/>
								<Grid Width="600" HorizontalAlignment="Left" Margin="0,0,0,10">
									<Grid.ColumnDefinitions>
										<ColumnDefinition Width="*"/>
										<ColumnDefinition Width="Auto"/>
									</Grid.ColumnDefinitions>
									<Border Grid.Column="0"
											Background="$surfaceControl"
											BorderBrush="$controlBorder"
											BorderThickness="1"
											CornerRadius="4"
											MinHeight="30"
											Padding="8,6">
										<TextBlock Name="TxtLogFolderPath"
												   Foreground="$textPrimary"
												   TextTrimming="CharacterEllipsis"
												   VerticalAlignment="Center"/>
									</Border>
									<Button Grid.Column="1" Name="BtnLogFolderBrowse" Content="..." Width="36" Height="30" Margin="8,0,0,0" Visibility="Collapsed"/>
								</Grid>
								<StackPanel Orientation="Horizontal" Margin="0,0,0,8">
									<Button Name="BtnOpenLogFolder" Content="Open Log Folder" Padding="12,6" Margin="0,0,8,0"/>
									<Button Name="BtnCopyLogFolderPath" Content="Copy Log Folder Path" Padding="12,6" Margin="0,0,8,0"/>
									<Button Name="BtnClearOldLogs" Content="Clear Old Logs" Padding="12,6"/>
								</StackPanel>
								<TextBlock Style="{StaticResource HelperText}" Name="TxtLogFolderHelper" Text="Logs stay in the default per-user folder. Expert mode allows choosing another folder."/>
							</StackPanel>
						</ScrollViewer>
					</Border>
				</TabItem>

				<TabItem Header="$advancedHeading">
					<Border Background="$cardBg" BorderBrush="$cardBorder" BorderThickness="1" CornerRadius="6" Margin="0,8,0,0">
						<ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0">
							<StackPanel Margin="24,20,24,20" MaxWidth="640" HorizontalAlignment="Left">
								<TextBlock Style="{StaticResource SectionHeading}" Text="Advanced"/>
								<TextBlock Style="{StaticResource SectionSubtitle}" Text="Features intended for power users."/>

								<CheckBox Style="{StaticResource SettingsCheck}" Name="ChkAdvancedMode" Content="Enable Expert mode"/>
								<CheckBox Style="{StaticResource SettingsCheck}" Name="ChkExperimentalFeatures" Content="Enable experimental features"/>
								<TextBlock Style="{StaticResource HelperText}" Text="Experimental options may change behavior without notice."/>
								<Border Background="$($theme.BorderColor)" Height="1" Margin="0,8,0,18" Opacity="0.35"/>
								<CheckBox Style="{StaticResource SettingsCheck}" Name="ChkDesignMode" Content="Design Mode"/>
								<TextBlock Style="{StaticResource HelperText}" Text="Build a config using default values instead of reading live system state."/>
							</StackPanel>
						</ScrollViewer>
					</Border>
				</TabItem>
			</TabControl>

			<Border Grid.Row="3" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0"
					Padding="24,14,24,14">
				<StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
					<Button Name="BtnCancel" Content="" Padding="22,8" FontSize="13" Margin="0,0,12,0"/>
					<Button Name="BtnSave" Content="" Padding="32,10" FontSize="14" FontWeight="SemiBold"/>
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
		if ($rootBorder)
		{
			$rootBorder.Background = ConvertTo-GuiBrush -Color $theme.WindowBg -Context 'DialogHelpers.ShowGuiSettingsDialog.WindowBg' -FallbackColor '#10131C'
			$rootBorder.BorderBrush = ConvertTo-GuiBrush -Color $theme.BorderColor -Context 'DialogHelpers.ShowGuiSettingsDialog.Border' -FallbackColor '#293044'
			$rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
		}

		[void](GUICommon\Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))

		$dlgTitleBar = $dlg.FindName('DlgTitleBar')
		$btnDlgClose = $dlg.FindName('BtnDlgClose')
		$btnCancel = $dlg.FindName('BtnCancel')
		$btnSave = $dlg.FindName('BtnSave')
		$btnSettingsLanguage = $dlg.FindName('BtnSettingsLanguage')
		$txtSettingsLanguageDisplay = $dlg.FindName('TxtSettingsLanguageDisplay')
		$settingsLanguagePopup = $dlg.FindName('SettingsLanguagePopup')
		$txtSettingsLanguageSearch = $dlg.FindName('TxtSettingsLanguageSearch')
		$settingsLanguageListPanel = $dlg.FindName('SettingsLanguageListPanel')
		$cmbDefaultStartupMode = $dlg.FindName('CmbDefaultStartupMode')
		$chkRestoreLastSession = $dlg.FindName('ChkRestoreLastSession')
		$chkAutoScanOnLaunch = $dlg.FindName('ChkAutoScanOnLaunch')
		$chkHideUnavailableItems = $dlg.FindName('ChkHideUnavailableItems')
		$cmbTheme = $dlg.FindName('CmbTheme')
		$cmbUIDensity = $dlg.FindName('CmbUIDensity')
		$chkSafeModeDefault = $dlg.FindName('ChkSafeModeDefault')
		$chkRequireRunConfirmation = $dlg.FindName('ChkRequireRunConfirmation')
		$chkPreviewBeforeRunDefault = $dlg.FindName('ChkPreviewBeforeRunDefault')
		$cmbAuditRetention = $dlg.FindName('CmbAuditRetention')
		$cmbPackageSource = $dlg.FindName('CmbPackageSource')
		$chkAppsSilentInstall = $dlg.FindName('ChkAppsSilentInstall')
		$chkAppsAutoUpdate = $dlg.FindName('ChkAppsAutoUpdate')
		$chkLoggingEnabled = $dlg.FindName('ChkLoggingEnabled')
		$chkDebugLogging = $dlg.FindName('ChkDebugLogging')
		$cmbLogLevel = $dlg.FindName('CmbLogLevel')
		$txtLogFolderPath = $dlg.FindName('TxtLogFolderPath')
		$txtLogFolderHelper = $dlg.FindName('TxtLogFolderHelper')
		$btnLogFolderBrowse = $dlg.FindName('BtnLogFolderBrowse')
		$btnOpenLogFolder = $dlg.FindName('BtnOpenLogFolder')
		$btnCopyLogFolderPath = $dlg.FindName('BtnCopyLogFolderPath')
		$btnClearOldLogs = $dlg.FindName('BtnClearOldLogs')
		$btnSettingsExportSupportBundle = $dlg.FindName('BtnSettingsExportSupportBundle')
		$chkAdvancedMode = $dlg.FindName('ChkAdvancedMode')
		$chkExperimentalFeatures = $dlg.FindName('ChkExperimentalFeatures')
		$chkDesignMode = $dlg.FindName('ChkDesignMode')
		$resultRef = @{ Value = $null }

		$settingsInputBgBrush = ConvertTo-GuiBrush -Color $surfaceControl -Context 'DialogHelpers.ShowGuiSettingsDialog.InputBg' -FallbackColor '#262D40'
		$settingsInputBorderBrush = ConvertTo-GuiBrush -Color $controlBorder -Context 'DialogHelpers.ShowGuiSettingsDialog.InputBorder' -FallbackColor '#293044'
		$settingsTextPrimaryBrush = ConvertTo-GuiBrush -Color $textPrimary -Context 'DialogHelpers.ShowGuiSettingsDialog.TextPrimary' -FallbackColor '#F4F7FF'
		$settingsTextSecondaryBrush = ConvertTo-GuiBrush -Color $textSecondary -Context 'DialogHelpers.ShowGuiSettingsDialog.TextSecondary' -FallbackColor '#B8C1D9'
		$settingsTextMutedBrush = ConvertTo-GuiBrush -Color $textMuted -Context 'DialogHelpers.ShowGuiSettingsDialog.TextMuted' -FallbackColor '#828AA2'
		$settingsAccentBrush = ConvertTo-GuiBrush -Color $accentBlue -Context 'DialogHelpers.ShowGuiSettingsDialog.Accent' -FallbackColor '#7CB7FF'
		$settingsSelectionBrush = ConvertTo-GuiBrush -Color $selectionSurface -Context 'DialogHelpers.ShowGuiSettingsDialog.Selection' -FallbackColor '#202638'

		$applySettingsSystemBrushes = {
			param ($control)
			if (-not $control) { return }
			$control.Resources[[System.Windows.SystemColors]::WindowBrushKey] = $settingsInputBgBrush
			$control.Resources[[System.Windows.SystemColors]::WindowTextBrushKey] = $settingsTextPrimaryBrush
			$control.Resources[[System.Windows.SystemColors]::ControlBrushKey] = $settingsInputBgBrush
			$control.Resources[[System.Windows.SystemColors]::ControlTextBrushKey] = $settingsTextPrimaryBrush
			$control.Resources[[System.Windows.SystemColors]::HighlightBrushKey] = $settingsSelectionBrush
			$control.Resources[[System.Windows.SystemColors]::HighlightTextBrushKey] = $settingsTextPrimaryBrush
			$control.Resources[[System.Windows.SystemColors]::MenuBrushKey] = $settingsInputBgBrush
			$control.Resources[[System.Windows.SystemColors]::MenuTextBrushKey] = $settingsTextPrimaryBrush
		}.GetNewClosure()

		$applySettingsComboItemTheme = {
			param ($item)
			if (-not $item -or -not ($item -is [System.Windows.Controls.ComboBoxItem])) { return }
			$item.Background = $settingsInputBgBrush
			$item.Foreground = $settingsTextPrimaryBrush
			$item.BorderBrush = $settingsInputBorderBrush
			$item.BorderThickness = [System.Windows.Thickness]::new(0)
			$item.Padding = [System.Windows.Thickness]::new(10, 4, 10, 4)
			$item.Opacity = 1
			& $applySettingsSystemBrushes $item
		}.GetNewClosure()

		$applySettingsInputTheme = {
			param ($control)
			if (-not $control) { return }
			try
			{
				& $applySettingsSystemBrushes $control
				$control.Background = $settingsInputBgBrush
				$control.Foreground = $settingsTextPrimaryBrush
				$control.BorderBrush = $settingsInputBorderBrush
				$control.Opacity = 1

				if ($control -is [System.Windows.Controls.TextBox])
				{
					$control.CaretBrush = $settingsTextPrimaryBrush
					$control.SelectionBrush = $settingsSelectionBrush
				}
				elseif ($control -is [System.Windows.Controls.ComboBox])
				{
					$control.OverridesDefaultStyle = $true
					$control.Opacity = 1
					$control.SetValue([System.Windows.Documents.TextElement]::ForegroundProperty, $settingsTextPrimaryBrush)
					foreach ($item in @($control.Items)) { & $applySettingsComboItemTheme $item }
				}
			}
			catch
			{
				Write-DebugSwallowedException -ErrorRecord $_ -Source 'DialogHelpers.ShowGuiSettingsDialog.ApplyInputTheme'
			}
		}.GetNewClosure()

		if ($btnSettingsLanguage)
		{
			& $applySettingsSystemBrushes $btnSettingsLanguage
			$btnSettingsLanguage.Background = $settingsInputBgBrush
			$btnSettingsLanguage.Foreground = $settingsTextPrimaryBrush
			$btnSettingsLanguage.BorderBrush = $settingsInputBorderBrush
			$btnSettingsLanguage.Opacity = 1
		}
		if ($txtSettingsLanguageDisplay) { $txtSettingsLanguageDisplay.Foreground = $settingsTextPrimaryBrush }
		& $applySettingsInputTheme $txtSettingsLanguageSearch
		foreach ($logFolderButton in @($btnLogFolderBrowse, $btnOpenLogFolder, $btnCopyLogFolderPath))
		{
			if ($logFolderButton) { Set-ButtonChrome -Button $logFolderButton -Variant 'Subtle' -Compact -Muted }
		}
		if ($btnClearOldLogs) { Set-ButtonChrome -Button $btnClearOldLogs -Variant 'DangerSubtle' -Compact }
		if ($btnSettingsExportSupportBundle)
		{
			if ($btnSettingsExportSupportBundle.Content -is [System.Windows.Controls.TextBlock])
			{
				$btnSettingsExportSupportBundle.Content.Text = $openExportBundleButtonLabel
			}
			else
			{
				$btnSettingsExportSupportBundle.Content = $openExportBundleButtonLabel
			}
			$btnSettingsExportSupportBundle.Cursor = [System.Windows.Input.Cursors]::Hand
			$btnSettingsExportSupportBundle.Foreground = $settingsAccentBrush
			$btnSettingsExportSupportBundle.Background = [System.Windows.Media.Brushes]::Transparent
			$btnSettingsExportSupportBundle.BorderBrush = [System.Windows.Media.Brushes]::Transparent
			$btnSettingsExportSupportBundle.BorderThickness = [System.Windows.Thickness]::new(0)
			$btnSettingsExportSupportBundle.Padding = [System.Windows.Thickness]::new(0)
			$exportBundleMenuItem = $Script:MenuToolsExportSupportBundle
			$btnSettingsExportSupportBundle.IsEnabled = [bool]($exportBundleMenuItem -and $exportBundleMenuItem.IsEnabled)
			$btnSettingsExportSupportBundle.Add_Click({
				if (-not $exportBundleMenuItem) { return }
				try
				{
					$eventArgs = [System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent)
					$exportBundleMenuItem.RaiseEvent($eventArgs)
				}
				catch
				{
					Write-DebugSwallowedException -ErrorRecord $_ -Source 'DialogHelpers.ShowGuiSettingsDialog.ExportSupportBundleShortcut'
				}
			}.GetNewClosure())
		}

		$addComboItem = {
			param ($combo, $label, $tag)
			if (-not $combo) { return }
			$ci = New-Object System.Windows.Controls.ComboBoxItem
			$ci.Content = $label
			$ci.Tag = $tag
			& $applySettingsComboItemTheme $ci
			[void]$combo.Items.Add($ci)
		}

		$selectComboByTag = {
			param ($combo, $tag)
			if (-not $combo) { return }
			for ($i = 0; $i -lt $combo.Items.Count; $i++)
			{
				if ([string]$combo.Items[$i].Tag -eq [string]$tag)
				{
					$combo.SelectedIndex = $i
					return
				}
			}
			if ($combo.Items.Count -gt 0) { $combo.SelectedIndex = 0 }
		}

		$formatLanguageDisplay = {
			param ($entry)
			$nativeName = [string]$entry.NativeName
			$englishName = [string]$entry.EnglishName
			if ([string]::IsNullOrWhiteSpace($nativeName) -or $nativeName -eq $englishName)
			{
				return $englishName
			}
			return ('{0} ({1})' -f $englishName, $nativeName)
		}

		$languageEntries = @(Get-GuiLanguageEntries -LocalizationDirectory $Script:GuiLocalizationDirectoryPath)
		$settingsLanguageState = @{
			Code = if ($Current.ContainsKey('Language') -and -not [string]::IsNullOrWhiteSpace([string]$Current.Language))
			{
				[string]$Current.Language
			}
			elseif ($Script:SelectedLanguage)
			{
				[string]$Script:SelectedLanguage
			}
			else
			{
				'en'
			}
		}
		if ([string]::IsNullOrWhiteSpace($settingsLanguageState.Code) -or [string]$settingsLanguageState.Code -eq 'en') { $settingsLanguageState.Code = 'en-US' }

		$textPrimaryBrush = $settingsTextPrimaryBrush
		$textMutedBrush = $settingsTextMutedBrush
		$activeBrush = $settingsSelectionBrush
		$accentBrush = $settingsAccentBrush
		$hoverColor = $surfaceHover

		$languageUiState = @{ Render = $null }

		$updateLanguageButtonText = {
			if (-not $txtSettingsLanguageDisplay) { return }
			$currentCode = [string]$settingsLanguageState.Code
			if ($currentCode -eq 'en') { $currentCode = 'en-US' }
			$matched = $languageEntries | Where-Object { [string]$_.Code -eq $currentCode } | Select-Object -First 1
			if ($matched)
			{
				$txtSettingsLanguageDisplay.Text = (& $formatLanguageDisplay $matched)
			}
			else
			{
				$txtSettingsLanguageDisplay.Text = $currentCode
			}
		}.GetNewClosure()

		$languageClickHandler = {
			param ($btnSender, $btnArgs)
			$null = $btnArgs
			$selectedCode = [string]$btnSender.Tag
			if ([string]::IsNullOrWhiteSpace($selectedCode)) { return }
			$settingsLanguageState.Code = $selectedCode
			& $updateLanguageButtonText
			if ($settingsLanguagePopup) { $settingsLanguagePopup.IsOpen = $false }
			if ($btnSettingsLanguage) { $btnSettingsLanguage.IsChecked = $false }
			if ($txtSettingsLanguageSearch) { $txtSettingsLanguageSearch.Text = '' }
			if ($languageUiState.Render) { & $languageUiState.Render '' }
		}.GetNewClosure()

		$renderLanguageList = {
			param ([string]$FilterText = '')
			if (-not $settingsLanguageListPanel) { return }
			$settingsLanguageListPanel.Children.Clear()

			$normalizedFilter = if ([string]::IsNullOrWhiteSpace([string]$FilterText)) { '' } else { ([string]$FilterText).Trim().ToLowerInvariant() }
			$filtered = if ([string]::IsNullOrWhiteSpace($normalizedFilter))
			{
				@($languageEntries)
			}
			else
			{
				@($languageEntries | Where-Object { [string]$_.SearchIndex -like "*$normalizedFilter*" })
			}

			if ($filtered.Count -eq 0)
			{
				$emptyState = [System.Windows.Controls.TextBlock]::new()
				$emptyState.Text = (Get-UxLocalizedString -Key 'GuiLanguageSearchNoResults' -Fallback 'No languages found.')
				$emptyState.Margin = [System.Windows.Thickness]::new(10, 8, 10, 6)
				$emptyState.FontSize = 12
				$emptyState.Foreground = $textMutedBrush
				[void]$settingsLanguageListPanel.Children.Add($emptyState)
				return
			}

			$templateXaml = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="{x:Type Button}">
	<Border x:Name="Bd" CornerRadius="4" Padding="{TemplateBinding Padding}" Background="{TemplateBinding Background}">
		<ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
	</Border>
	<ControlTemplate.Triggers>
		<Trigger Property="IsMouseOver" Value="True">
			<Setter TargetName="Bd" Property="Background" Value="$hoverColor"/>
		</Trigger>
	</ControlTemplate.Triggers>
</ControlTemplate>
"@
			$langTemplate = [Windows.Markup.XamlReader]::Parse($templateXaml)

			$currentCode = [string]$settingsLanguageState.Code
			foreach ($entry in $filtered)
			{
				$isActive = [string]$entry.Code -eq $currentCode
				$langBtn = [System.Windows.Controls.Button]::new()
				$langBtn.Tag = [string]$entry.Code
				$langBtn.Cursor = [System.Windows.Input.Cursors]::Hand
				$langBtn.HorizontalContentAlignment = 'Left'
				$langBtn.Padding = [System.Windows.Thickness]::new(12, 5, 12, 5)
				$langBtn.Margin = [System.Windows.Thickness]::new(0, 1, 0, 1)
				$langBtn.BorderThickness = [System.Windows.Thickness]::new(0)
				$langBtn.Background = if ($isActive) { $activeBrush } else { [System.Windows.Media.Brushes]::Transparent }
				$langBtn.Foreground = $textPrimaryBrush
				$langBtn.FocusVisualStyle = $null
				$langBtn.ClickMode = [System.Windows.Controls.ClickMode]::Press
				$langBtn.Template = $langTemplate

				$langStack = [System.Windows.Controls.StackPanel]::new()
				$langStack.Orientation = 'Vertical'

				$nativeBlock = [System.Windows.Controls.TextBlock]::new()
				$nativeBlock.Text = [string]$entry.NativeName
				$nativeBlock.FontSize = 12
				$nativeBlock.Foreground = if ($isActive) { $accentBrush } else { $textPrimaryBrush }
				$nativeBlock.FontWeight = if ($isActive) { [System.Windows.FontWeights]::Bold } else { [System.Windows.FontWeights]::Normal }
				[void]$langStack.Children.Add($nativeBlock)

				if ([string]$entry.NativeName -ne [string]$entry.EnglishName)
				{
					$engBlock = [System.Windows.Controls.TextBlock]::new()
					$engBlock.Text = [string]$entry.EnglishName
					$engBlock.FontSize = 10
					$engBlock.Foreground = $textMutedBrush
					[void]$langStack.Children.Add($engBlock)
				}

				$langBtn.Content = $langStack
				$langBtn.Add_Click($languageClickHandler)
				[void]$settingsLanguageListPanel.Children.Add($langBtn)
			}
		}.GetNewClosure()

		$languageUiState.Render = $renderLanguageList

		& $updateLanguageButtonText
		& $renderLanguageList ''

		if ($txtSettingsLanguageSearch)
		{
			$txtSettingsLanguageSearch.Add_TextChanged({
				param ($textSender, $textArgs)
				$null = $textArgs
				if ($languageUiState.Render)
				{
					& $languageUiState.Render ([string]$textSender.Text)
				}
			}.GetNewClosure())
		}

		if ($settingsLanguagePopup)
		{
			$settingsLanguagePopup.Add_Opened({
				param ($popupSender, $popupArgs)
				$null = $popupSender
				$null = $popupArgs
				if ($txtSettingsLanguageSearch)
				{
					$txtSettingsLanguageSearch.Text = ''
					[void]$txtSettingsLanguageSearch.Focus()
				}
				if ($languageUiState.Render) { & $languageUiState.Render '' }
			}.GetNewClosure())
		}

		if ($cmbDefaultStartupMode)
		{
			& $addComboItem $cmbDefaultStartupMode 'Safe' 'Safe'
			& $addComboItem $cmbDefaultStartupMode 'Expert' 'Expert'
			& $selectComboByTag $cmbDefaultStartupMode ($(if ($Current.ContainsKey('DefaultStartupMode') -and -not [string]::IsNullOrWhiteSpace([string]$Current.DefaultStartupMode)) { [string]$Current.DefaultStartupMode } else { 'Safe' }))
		}

		if ($cmbTheme)
		{
			& $addComboItem $cmbTheme 'System Default' 'System'
			& $addComboItem $cmbTheme 'Dark' 'Dark'
			& $addComboItem $cmbTheme 'Light' 'Light'
			& $selectComboByTag $cmbTheme ($(if ($Current.ContainsKey('Theme') -and -not [string]::IsNullOrWhiteSpace([string]$Current.Theme)) { [string]$Current.Theme } elseif ($Script:CurrentThemeName) { [string]$Script:CurrentThemeName } else { 'Dark' }))
		}

		if ($cmbUIDensity)
		{
			& $addComboItem $cmbUIDensity 'Comfortable' 'Comfortable'
			& $addComboItem $cmbUIDensity 'Compact' 'Compact'
			& $selectComboByTag $cmbUIDensity ($(if ($Current.ContainsKey('UIDensity') -and -not [string]::IsNullOrWhiteSpace([string]$Current.UIDensity)) { [string]$Current.UIDensity } else { 'Comfortable' }))
		}

		if ($cmbAuditRetention)
		{
			& $addComboItem $cmbAuditRetention '30 days' 30
			& $addComboItem $cmbAuditRetention '90 days' 90
			& $addComboItem $cmbAuditRetention '180 days' 180
			& $addComboItem $cmbAuditRetention '365 days' 365
			$selectedRetention = if ($Current.ContainsKey('AuditRetentionDays') -and $Current.AuditRetentionDays) { [int]$Current.AuditRetentionDays } else { 90 }
			& $selectComboByTag $cmbAuditRetention $selectedRetention
		}

		if ($cmbPackageSource)
		{
			& $addComboItem $cmbPackageSource 'Auto (prefer available)' 'auto'
			& $addComboItem $cmbPackageSource 'WinGet' 'winget'
			& $addComboItem $cmbPackageSource 'Chocolatey' 'choco'
			& $selectComboByTag $cmbPackageSource ($(if ($Current.ContainsKey('AppsPackageSourcePreference') -and -not [string]::IsNullOrWhiteSpace([string]$Current.AppsPackageSourcePreference)) { [string]$Current.AppsPackageSourcePreference } else { 'auto' }))
		}

		if ($cmbLogLevel)
		{
			& $addComboItem $cmbLogLevel 'Error' 'Error'
			& $addComboItem $cmbLogLevel 'Warn' 'Warn'
			& $addComboItem $cmbLogLevel 'Info' 'Info'
			& $addComboItem $cmbLogLevel 'Debug' 'Debug'
			& $addComboItem $cmbLogLevel 'Trace' 'Trace'
			& $selectComboByTag $cmbLogLevel ($(if ($Current.ContainsKey('LogLevel') -and -not [string]::IsNullOrWhiteSpace([string]$Current.LogLevel)) { [string]$Current.LogLevel } else { 'Info' }))
		}

		foreach ($settingsCombo in @($cmbDefaultStartupMode, $cmbTheme, $cmbUIDensity, $cmbAuditRetention, $cmbPackageSource, $cmbLogLevel))
		{
			& $applySettingsInputTheme $settingsCombo
		}

		if ($chkRestoreLastSession) { $chkRestoreLastSession.IsChecked = if ($Current.ContainsKey('RestoreLastSession')) { [bool]$Current.RestoreLastSession } else { $true } }
		if ($chkAutoScanOnLaunch) { $chkAutoScanOnLaunch.IsChecked = if ($Current.ContainsKey('AutoScanOnLaunch')) { [bool]$Current.AutoScanOnLaunch } else { $false } }
		if ($chkHideUnavailableItems) { $chkHideUnavailableItems.IsChecked = if ($Current.ContainsKey('HideUnavailableItems')) { [bool]$Current.HideUnavailableItems } else { $true } }
		if ($chkSafeModeDefault) { $chkSafeModeDefault.IsChecked = if ($Current.ContainsKey('SafeMode')) { [bool]$Current.SafeMode } else { $false } }
		if ($chkRequireRunConfirmation) { $chkRequireRunConfirmation.IsChecked = if ($Current.ContainsKey('RequireRunConfirmation')) { [bool]$Current.RequireRunConfirmation } else { $true } }
		if ($chkPreviewBeforeRunDefault) { $chkPreviewBeforeRunDefault.IsChecked = if ($Current.ContainsKey('PreviewBeforeRunDefault')) { [bool]$Current.PreviewBeforeRunDefault } else { $false } }
		if ($chkAppsSilentInstall) { $chkAppsSilentInstall.IsChecked = if ($Current.ContainsKey('AppsSilentInstall')) { [bool]$Current.AppsSilentInstall } else { $true } }
		if ($chkAppsAutoUpdate) { $chkAppsAutoUpdate.IsChecked = if ($Current.ContainsKey('AppsAutoUpdate')) { [bool]$Current.AppsAutoUpdate } else { $false } }
		if ($chkLoggingEnabled) { $chkLoggingEnabled.IsChecked = if ($Current.ContainsKey('LoggingEnabled')) { [bool]$Current.LoggingEnabled } else { $true } }
		if ($chkDebugLogging) { $chkDebugLogging.IsChecked = if ($Current.ContainsKey('DebugLoggingEnabled')) { [bool]$Current.DebugLoggingEnabled } else { $false } }
		if ($chkAdvancedMode) { $chkAdvancedMode.IsChecked = if ($Current.ContainsKey('AdvancedMode')) { [bool]$Current.AdvancedMode } else { $false } }
		if ($chkExperimentalFeatures) { $chkExperimentalFeatures.IsChecked = if ($Current.ContainsKey('ExperimentalFeatures')) { [bool]$Current.ExperimentalFeatures } else { $false } }
		if ($chkDesignMode) { $chkDesignMode.IsChecked = if ($Current.ContainsKey('DesignMode')) { [bool]$Current.DesignMode } else { [bool]$Script:DesignMode } }

		$defaultLogDirectory = if ($Current.ContainsKey('DefaultLogFileDirectory') -and -not [string]::IsNullOrWhiteSpace([string]$Current.DefaultLogFileDirectory))
		{
			[string]$Current.DefaultLogFileDirectory
		}
		elseif (Get-Command -Name 'Get-BaselineLogDirectory' -CommandType Function -ErrorAction SilentlyContinue)
		{
			[string](Get-BaselineLogDirectory)
		}
		else
		{
			[System.IO.Path]::Combine([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData), 'Baseline', 'UserState', 'Logs')
		}
		$settingsLogState = @{
			DefaultDirectory = $defaultLogDirectory
			CustomDirectory  = if ($Current.ContainsKey('LogFileDirectory') -and -not [string]::IsNullOrWhiteSpace([string]$Current.LogFileDirectory)) { [string]$Current.LogFileDirectory } else { '' }
		}
		$getEffectiveLogDirectory = {
			$expertEnabled = $chkAdvancedMode -and [bool]$chkAdvancedMode.IsChecked
			if ($expertEnabled -and -not [string]::IsNullOrWhiteSpace([string]$settingsLogState.CustomDirectory))
			{
				return [string]$settingsLogState.CustomDirectory
			}
			return [string]$settingsLogState.DefaultDirectory
		}.GetNewClosure()
		$refreshLogFolderDisplay = {
			$expertEnabled = $chkAdvancedMode -and [bool]$chkAdvancedMode.IsChecked
			$effectiveDirectory = & $getEffectiveLogDirectory
			if ($txtLogFolderPath) { $txtLogFolderPath.Text = $effectiveDirectory }
			if ($btnLogFolderBrowse)
			{
				$btnLogFolderBrowse.Visibility = if ($expertEnabled) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
			}
			if ($txtLogFolderHelper)
			{
				$txtLogFolderHelper.Text = if ($expertEnabled)
				{
					'Expert mode can choose another log folder. Leave it unchanged to use the default per-user location.'
				}
				else
				{
					'Logs stay in the default per-user folder. Enable Expert mode to choose another folder.'
				}
			}
		}.GetNewClosure()
		& $refreshLogFolderDisplay

		if ($chkAdvancedMode)
		{
			$chkAdvancedMode.Add_Checked({ & $refreshLogFolderDisplay }.GetNewClosure())
			$chkAdvancedMode.Add_Unchecked({ & $refreshLogFolderDisplay }.GetNewClosure())
		}

		if ($btnLogFolderBrowse)
		{
			$btnLogFolderBrowse.Add_Click({
				try
				{
					Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
					$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
					$folderDialog.Description = 'Select Baseline log folder'
					$folderDialog.ShowNewFolderButton = $true
					$selectedPath = & $getEffectiveLogDirectory
					if (-not [string]::IsNullOrWhiteSpace($selectedPath) -and [System.IO.Directory]::Exists($selectedPath))
					{
						$folderDialog.SelectedPath = $selectedPath
					}
					if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK)
					{
						$settingsLogState.CustomDirectory = [string]$folderDialog.SelectedPath
						& $refreshLogFolderDisplay
					}
				}
				catch
				{
					Write-DebugSwallowedException -ErrorRecord $_ -Source 'DialogHelpers.ShowGuiSettingsDialog.LogFolderBrowse'
					[void](Show-ThemedDialog -Title 'Logging' -Message ("Failed to choose a log folder.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
				}
			}.GetNewClosure())
		}

		if ($btnOpenLogFolder)
		{
			$btnOpenLogFolder.Add_Click({
				try
				{
					$folderPath = & $getEffectiveLogDirectory
					if ([string]::IsNullOrWhiteSpace($folderPath)) { return }
					if (-not [System.IO.Directory]::Exists($folderPath)) { [void][System.IO.Directory]::CreateDirectory($folderPath) }
					Start-Process -FilePath 'explorer.exe' -ArgumentList @($folderPath) | Out-Null
				}
				catch
				{
					Write-DebugSwallowedException -ErrorRecord $_ -Source 'DialogHelpers.ShowGuiSettingsDialog.OpenLogFolder'
					[void](Show-ThemedDialog -Title 'Logging' -Message ("Failed to open the log folder.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
				}
			}.GetNewClosure())
		}

		if ($btnCopyLogFolderPath)
		{
			$btnCopyLogFolderPath.Add_Click({
				try
				{
					$folderPath = & $getEffectiveLogDirectory
					if (-not [string]::IsNullOrWhiteSpace($folderPath))
					{
						[System.Windows.Clipboard]::SetText($folderPath)
					}
				}
				catch
				{
					Write-DebugSwallowedException -ErrorRecord $_ -Source 'DialogHelpers.ShowGuiSettingsDialog.CopyLogFolderPath'
					[void](Show-ThemedDialog -Title 'Logging' -Message ("Failed to copy the log folder path.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
				}
			}.GetNewClosure())
		}

		if ($btnClearOldLogs)
		{
			$btnClearOldLogs.Add_Click({
				try
				{
					$folderPath = & $getEffectiveLogDirectory
					if ([string]::IsNullOrWhiteSpace($folderPath) -or -not [System.IO.Directory]::Exists($folderPath)) { return }
					$confirm = Show-ThemedDialog -Title 'Clear Old Logs' -Message ("Delete old Baseline .log files from:`n{0}`n`nThe current session log is kept." -f $folderPath) -Buttons @('Clear', 'Cancel') -DestructiveButton 'Clear'
					if ($confirm -ne 'Clear') { return }

					$currentLogPath = if ($global:LogFilePath) { [System.IO.Path]::GetFullPath([string]$global:LogFilePath) } else { '' }
					$removedCount = 0
					foreach ($logFile in @(Get-ChildItem -LiteralPath $folderPath -Recurse -File -Filter '*.log' -ErrorAction SilentlyContinue))
					{
						$logPath = [System.IO.Path]::GetFullPath([string]$logFile.FullName)
						if (-not [string]::IsNullOrWhiteSpace($currentLogPath) -and [string]::Equals($logPath, $currentLogPath, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
						Remove-Item -LiteralPath $logFile.FullName -Force -ErrorAction Stop
						$removedCount++
					}
					[void](Show-ThemedDialog -Title 'Clear Old Logs' -Message ("Removed {0} old log file(s)." -f $removedCount) -Buttons @('OK') -AccentButton 'OK')
				}
				catch
				{
					Write-DebugSwallowedException -ErrorRecord $_ -Source 'DialogHelpers.ShowGuiSettingsDialog.ClearOldLogs'
					[void](Show-ThemedDialog -Title 'Clear Old Logs' -Message ("Failed to clear old logs.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
				}
			}.GetNewClosure())
		}

		$syncStartupMode = {
			param ([switch]$InitialLoad)
			if (-not $cmbDefaultStartupMode -or -not $cmbDefaultStartupMode.SelectedItem) { return }
			$selectedMode = [string]$cmbDefaultStartupMode.SelectedItem.Tag
			if ($selectedMode -eq 'Expert')
			{
				if ($chkSafeModeDefault)
				{
					$chkSafeModeDefault.IsEnabled = $false
					if (-not $InitialLoad) { $chkSafeModeDefault.IsChecked = $false }
				}
				if ($chkAdvancedMode -and -not $InitialLoad) { $chkAdvancedMode.IsChecked = $true }
			}
			else
			{
				if ($chkSafeModeDefault) { $chkSafeModeDefault.IsEnabled = $true }
				if (-not $InitialLoad)
				{
					if ($chkSafeModeDefault) { $chkSafeModeDefault.IsChecked = $true }
					if ($chkAdvancedMode) { $chkAdvancedMode.IsChecked = $false }
				}
			}
		}.GetNewClosure()

		if ($cmbDefaultStartupMode)
		{
			& $syncStartupMode -InitialLoad
			$cmbDefaultStartupMode.Add_SelectionChanged({
				& $syncStartupMode
			}.GetNewClosure())
		}

		if ($dlgTitleBar)
		{
			$dlgTitleBar.Add_MouseLeftButtonDown({ $dlg.DragMove() }.GetNewClosure())
		}
		if ($btnDlgClose) { $btnDlgClose.Add_Click({ $dlg.Close() }.GetNewClosure()) }
		if ($btnCancel)
		{
			$btnCancel.Content = $cancelLabel
			Set-ButtonChrome -Button $btnCancel -Variant 'Secondary' -Compact
			$btnCancel.IsCancel = $true
			$btnCancel.Add_Click({ $dlg.Close() }.GetNewClosure())
		}
		if ($btnSave)
		{
			$btnSave.Content = $saveLabel
			Set-ButtonChrome -Button $btnSave -Variant 'Primary'
			$btnSave.IsDefault = $true
			$btnSave.Add_Click({
				$getTag = {
					param ($combo, $default)
					if ($combo -and $combo.SelectedItem -and $null -ne $combo.SelectedItem.Tag)
					{
						return $combo.SelectedItem.Tag
					}
					return $default
				}

				$selectedLanguage = if ($settingsLanguageState -and $settingsLanguageState.Code) { [string]$settingsLanguageState.Code } else { 'en' }
				$resultRef.Value = @{
					Language = $selectedLanguage
					DefaultStartupMode = [string](& $getTag $cmbDefaultStartupMode 'Safe')
					RestoreLastSession = [bool]$chkRestoreLastSession.IsChecked
					AutoScanOnLaunch = [bool]$chkAutoScanOnLaunch.IsChecked
					HideUnavailableItems = if ($chkHideUnavailableItems) { [bool]$chkHideUnavailableItems.IsChecked } else { $true }
					Theme = [string](& $getTag $cmbTheme 'Dark')
					UIDensity = [string](& $getTag $cmbUIDensity 'Comfortable')
					SafeMode = [bool]$chkSafeModeDefault.IsChecked
					RequireRunConfirmation = [bool]$chkRequireRunConfirmation.IsChecked
					PreviewBeforeRunDefault = [bool]$chkPreviewBeforeRunDefault.IsChecked
					AuditRetentionDays = [int](& $getTag $cmbAuditRetention 90)
					AppsPackageSourcePreference = [string](& $getTag $cmbPackageSource 'auto')
					AppsSilentInstall = [bool]$chkAppsSilentInstall.IsChecked
					AppsAutoUpdate = [bool]$chkAppsAutoUpdate.IsChecked
					LoggingEnabled = [bool]$chkLoggingEnabled.IsChecked
					DebugLoggingEnabled = [bool]$chkDebugLogging.IsChecked
					LogLevel = [string](& $getTag $cmbLogLevel 'Info')
					LogFileDirectory = if ($chkAdvancedMode -and [bool]$chkAdvancedMode.IsChecked -and -not [string]::IsNullOrWhiteSpace([string]$settingsLogState.CustomDirectory)) { [string]$settingsLogState.CustomDirectory } else { '' }
					AdvancedMode = [bool]$chkAdvancedMode.IsChecked
					ExperimentalFeatures = [bool]$chkExperimentalFeatures.IsChecked
					DesignMode = [bool]$chkDesignMode.IsChecked
				}
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

		Stop-GuiPerfScope -Scope $__perf
		[void](GUICommon\Show-GuiActivatedDialog -Window $dlg)
		return $resultRef.Value
	}

