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

	$generalHeading = Get-UxLocalizedString -Key 'GuiSettingsGroupGeneral' -Fallback 'General'
	$appearanceHeading = Get-UxLocalizedString -Key 'GuiSettingsGroupAppearance' -Fallback 'Appearance'
	$safetyHeading = Get-UxLocalizedString -Key 'GuiSettingsGroupSafety' -Fallback 'Safety / Execution'
	$appsHeading = Get-UxLocalizedString -Key 'GuiSettingsGroupApplications' -Fallback 'Applications'
	$loggingHeading = Get-UxLocalizedString -Key 'GuiSettingsGroupLogging' -Fallback 'Logging'
	$advancedHeading = Get-UxLocalizedString -Key 'GuiSettingsGroupAdvanced' -Fallback 'Advanced'

	$cardBg = if ($theme.CardBg) { [string]$theme.CardBg } else { [string]$theme.PanelBg }
	$cardBorder = if ($theme.CardBorder) { [string]$theme.CardBorder } else { [string]$theme.BorderColor }
	$tabHoverBg = if ($theme.InputHoverBg) { [string]$theme.InputHoverBg } else { [string]$theme.CardBg }
	$textPrimary = if ($theme.TextPrimary) { [string]$theme.TextPrimary } else { '#CDD6F4' }
	$textMuted = if ($theme.TextMuted) { [string]$theme.TextMuted } else { '#828AA2' }
	$accentBlue = if ($theme.AccentBlue) { [string]$theme.AccentBlue } else { '#89B4FA' }
	$activeBorder = if ($theme.ActiveTabBorder) { [string]$theme.ActiveTabBorder } else { $accentBlue }

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
		</Style>
		<Style TargetType="ComboBox" x:Key="SettingsCombo">
			<Setter Property="Width" Value="320"/>
			<Setter Property="HorizontalAlignment" Value="Left"/>
			<Setter Property="Margin" Value="0,0,0,18"/>
			<Setter Property="Padding" Value="10,4"/>
			<Setter Property="MinHeight" Value="30"/>
		</Style>
		<Style TargetType="TextBox" x:Key="SettingsTextBox">
			<Setter Property="HorizontalAlignment" Value="Left"/>
			<Setter Property="Margin" Value="0,0,0,18"/>
			<Setter Property="Padding" Value="8,6"/>
			<Setter Property="MinHeight" Value="30"/>
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
											Background="#FFFFFF" Foreground="#1A1C2E"
											BorderBrush="#A7B0C0" BorderThickness="1">
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
														<Setter TargetName="LangBtnBorder" Property="BorderBrush" Value="#6E7A94"/>
													</Trigger>
													<Trigger Property="IsChecked" Value="True">
														<Setter TargetName="LangBtnBorder" Property="BorderBrush" Value="#1550AA"/>
													</Trigger>
												</ControlTemplate.Triggers>
											</ControlTemplate>
										</ToggleButton.Template>
										<Grid>
											<Grid.ColumnDefinitions>
												<ColumnDefinition Width="*"/>
												<ColumnDefinition Width="Auto"/>
											</Grid.ColumnDefinitions>
											<TextBlock Name="TxtSettingsLanguageDisplay" Grid.Column="0" VerticalAlignment="Center" HorizontalAlignment="Left" TextTrimming="CharacterEllipsis" Foreground="#1A1C2E" Text=""/>
											<Path Grid.Column="1" Margin="8,0,2,0" VerticalAlignment="Center" Data="M 0 0 L 4 4 L 8 0" Stroke="#1A1C2E" StrokeThickness="1.6" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Stretch="Fill" Width="8" Height="4" IsHitTestVisible="False"/>
										</Grid>
									</ToggleButton>
									<Popup Name="SettingsLanguagePopup" StaysOpen="False" Placement="Bottom" PlacementTarget="{Binding ElementName=BtnSettingsLanguage}" AllowsTransparency="True" IsOpen="{Binding IsChecked, ElementName=BtnSettingsLanguage, Mode=TwoWay}">
										<Border Background="#FFFFFF" BorderBrush="#A7B0C0" BorderThickness="1" CornerRadius="6" Padding="6">
											<StackPanel Width="360">
												<TextBox Name="TxtSettingsLanguageSearch" Height="28" Padding="10,4" Margin="0,0,0,6" VerticalContentAlignment="Center"
														Background="#FFFFFF" Foreground="#1A1C2E"
														BorderBrush="#A7B0C0" BorderThickness="1" CaretBrush="#1A1C2E"/>
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
								<TextBlock Style="{StaticResource HelperText}" Text="When on, DEBUG-level entries are written to the daily log and the perf tracer is force-enabled. Use before exporting a Support Bundle to maximize what maintainers can replay."/>

								<Border Background="$($theme.BorderColor)" Height="1" Margin="0,8,0,20" Opacity="0.35"/>

								<TextBlock Style="{StaticResource FieldLabel}" Name="LblLogLevel" Text="Log level"/>
								<ComboBox Style="{StaticResource SettingsCombo}" Name="CmbLogLevel"/>
								<TextBlock Style="{StaticResource FieldLabel}" Name="LblLogFilePath" Text="Log file path"/>
								<TextBox Style="{StaticResource SettingsTextBox}" Name="TxtLogFilePath" Width="560"/>
								<TextBlock Style="{StaticResource HelperText}" Text="Leave blank to use the default location."/>
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
			$rootBorder.Background = $bc.ConvertFromString($theme.WindowBg)
			$rootBorder.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
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
		$txtLogFilePath = $dlg.FindName('TxtLogFilePath')
		$chkAdvancedMode = $dlg.FindName('ChkAdvancedMode')
		$chkExperimentalFeatures = $dlg.FindName('ChkExperimentalFeatures')
		$chkDesignMode = $dlg.FindName('ChkDesignMode')
		$resultRef = @{ Value = $null }

		$addComboItem = {
			param ($combo, $label, $tag)
			if (-not $combo) { return }
			$ci = New-Object System.Windows.Controls.ComboBoxItem
			$ci.Content = $label
			$ci.Tag = $tag
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

		$languageBrushConverter = New-Object System.Windows.Media.BrushConverter
		$textPrimaryBrush = $languageBrushConverter.ConvertFromString('#1A1C2E')
		$textMutedBrush = $languageBrushConverter.ConvertFromString('#646C7F')
		$activeBrush = $languageBrushConverter.ConvertFromString('#CCE4F7')
		$accentBrush = $languageBrushConverter.ConvertFromString('#1550AA')
		$hoverColor = '#EDF2FA'

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
		if ($txtLogFilePath) { $txtLogFilePath.Text = if ($Current.ContainsKey('LogFilePath') -and $null -ne $Current.LogFilePath) { [string]$Current.LogFilePath } else { '' } }
		if ($chkAdvancedMode) { $chkAdvancedMode.IsChecked = if ($Current.ContainsKey('AdvancedMode')) { [bool]$Current.AdvancedMode } else { $false } }
		if ($chkExperimentalFeatures) { $chkExperimentalFeatures.IsChecked = if ($Current.ContainsKey('ExperimentalFeatures')) { [bool]$Current.ExperimentalFeatures } else { $false } }
		if ($chkDesignMode) { $chkDesignMode.IsChecked = if ($Current.ContainsKey('DesignMode')) { [bool]$Current.DesignMode } else { [bool]$Script:DesignMode } }

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
					LogFilePath = [string]$txtLogFilePath.Text
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

