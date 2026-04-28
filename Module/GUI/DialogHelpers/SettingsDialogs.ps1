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

		[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$windowTitle"
	Width="900" Height="720"
	MinWidth="780" MinHeight="560"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="Segoe UI"
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

			<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="14,8,8,8">
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

			<ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
				<StackPanel Margin="24,18,24,18">
					<TextBlock Text="$generalHeading" FontSize="14" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)" Margin="0,0,0,4"/>
					<TextBlock Text="Startup behavior, language, and visibility." FontSize="11" Foreground="$($theme.TextMuted)" Margin="0,0,0,12" TextWrapping="Wrap"/>
					<TextBlock Text="Language" FontSize="12" FontWeight="Medium" Foreground="$($theme.TextPrimary)" Margin="0,0,0,6"/>
					<ComboBox Name="CmbLanguage" Width="380" HorizontalAlignment="Left" Margin="0,0,0,12" Padding="8,4"/>
					<TextBlock Text="Default startup mode" FontSize="12" FontWeight="Medium" Foreground="$($theme.TextPrimary)" Margin="0,0,0,6"/>
					<ComboBox Name="CmbDefaultStartupMode" Width="240" HorizontalAlignment="Left" Margin="0,0,0,12" Padding="8,4"/>
					<CheckBox Name="ChkRestoreLastSession" Content="Restore last session on launch" Margin="0,0,0,8" Foreground="$($theme.TextPrimary)"/>
					<CheckBox Name="ChkAutoScanOnLaunch" Content="Auto-scan system on launch" Margin="0,0,0,8" Foreground="$($theme.TextPrimary)"/>
					<CheckBox Name="ChkHideUnavailableItems" Content="Hide items not available on this system" Margin="0,0,0,12" Foreground="$($theme.TextPrimary)"/>

					<Border Background="$($theme.BorderColor)" Height="1" Margin="0,0,0,16" Opacity="0.35"/>

					<TextBlock Text="$appearanceHeading" FontSize="14" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)" Margin="0,0,0,4"/>
					<TextBlock Text="Theme and density." FontSize="11" Foreground="$($theme.TextMuted)" Margin="0,0,0,12" TextWrapping="Wrap"/>
					<TextBlock Text="Theme" FontSize="12" FontWeight="Medium" Foreground="$($theme.TextPrimary)" Margin="0,0,0,6"/>
					<ComboBox Name="CmbTheme" Width="240" HorizontalAlignment="Left" Margin="0,0,0,12" Padding="8,4"/>
					<TextBlock Text="UI density" FontSize="12" FontWeight="Medium" Foreground="$($theme.TextPrimary)" Margin="0,0,0,6"/>
					<ComboBox Name="CmbUIDensity" Width="240" HorizontalAlignment="Left" Margin="0,0,0,12" Padding="8,4"/>

					<Border Background="$($theme.BorderColor)" Height="1" Margin="0,0,0,16" Opacity="0.35"/>

					<TextBlock Text="$safetyHeading" FontSize="14" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)" Margin="0,0,0,4"/>
					<TextBlock Text="Defaults that affect runs and cleanup." FontSize="11" Foreground="$($theme.TextMuted)" Margin="0,0,0,12" TextWrapping="Wrap"/>
					<CheckBox Name="ChkSafeModeDefault" Content="Enable Safe Mode by default" Margin="0,0,0,8" Foreground="$($theme.TextPrimary)"/>
					<CheckBox Name="ChkRequireRunConfirmation" Content="Require confirmation before Run" Margin="0,0,0,8" Foreground="$($theme.TextPrimary)"/>
					<CheckBox Name="ChkPreviewBeforeRunDefault" Content="Show preview before Run by default" Margin="0,0,0,12" Foreground="$($theme.TextPrimary)"/>
					<TextBlock Text="Audit retention" FontSize="12" FontWeight="Medium" Foreground="$($theme.TextPrimary)" Margin="0,0,0,6"/>
					<ComboBox Name="CmbAuditRetention" Width="240" HorizontalAlignment="Left" Margin="0,0,0,12" Padding="8,4"/>

					<Border Background="$($theme.BorderColor)" Height="1" Margin="0,0,0,16" Opacity="0.35"/>

					<TextBlock Text="$appsHeading" FontSize="14" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)" Margin="0,0,0,4"/>
					<TextBlock Text="Installer preferences for managed apps." FontSize="11" Foreground="$($theme.TextMuted)" Margin="0,0,0,12" TextWrapping="Wrap"/>
					<TextBlock Text="Preferred package source" FontSize="12" FontWeight="Medium" Foreground="$($theme.TextPrimary)" Margin="0,0,0,6"/>
					<ComboBox Name="CmbPackageSource" Width="240" HorizontalAlignment="Left" Margin="0,0,0,12" Padding="8,4"/>
					<CheckBox Name="ChkAppsSilentInstall" Content="Silent install when supported" Margin="0,0,0,8" Foreground="$($theme.TextPrimary)"/>
					<CheckBox Name="ChkAppsAutoUpdate" Content="Automatically update managed apps" Margin="0,0,0,12" Foreground="$($theme.TextPrimary)"/>

					<Border Background="$($theme.BorderColor)" Height="1" Margin="0,0,0,16" Opacity="0.35"/>

					<TextBlock Text="$loggingHeading" FontSize="14" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)" Margin="0,0,0,4"/>
					<TextBlock Text="Diagnostic output and log file location." FontSize="11" Foreground="$($theme.TextMuted)" Margin="0,0,0,12" TextWrapping="Wrap"/>
					<CheckBox Name="ChkLoggingEnabled" Content="Enable logging" Margin="0,0,0,8" Foreground="$($theme.TextPrimary)"/>
					<CheckBox Name="ChkDebugLogging" Content="Debug Mode (verbose logging + perf trace)" Margin="0,0,0,12" Foreground="$($theme.TextPrimary)"/>
					<TextBlock Text="Log level" FontSize="12" FontWeight="Medium" Foreground="$($theme.TextPrimary)" Margin="0,0,0,6"/>
					<ComboBox Name="CmbLogLevel" Width="240" HorizontalAlignment="Left" Margin="0,0,0,12" Padding="8,4"/>
					<TextBlock Text="Log file path" FontSize="12" FontWeight="Medium" Foreground="$($theme.TextPrimary)" Margin="0,0,0,6"/>
					<TextBox Name="TxtLogFilePath" Width="560" HorizontalAlignment="Left" Margin="0,0,0,12" Padding="8,6"/>
					<TextBlock Text="Leave blank to use the default location." FontSize="11" Foreground="$($theme.TextMuted)" Margin="0,0,0,12" TextWrapping="Wrap"/>

					<Border Background="$($theme.BorderColor)" Height="1" Margin="0,0,0,16" Opacity="0.35"/>

					<TextBlock Text="$advancedHeading" FontSize="14" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)" Margin="0,0,0,4"/>
					<TextBlock Text="Features intended for power users." FontSize="11" Foreground="$($theme.TextMuted)" Margin="0,0,0,12" TextWrapping="Wrap"/>
					<CheckBox Name="ChkAdvancedMode" Content="Enable Expert mode" Margin="0,0,0,8" Foreground="$($theme.TextPrimary)"/>
					<CheckBox Name="ChkExperimentalFeatures" Content="Enable experimental features" Margin="0,0,0,0" Foreground="$($theme.TextPrimary)"/>
				</StackPanel>
			</ScrollViewer>

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
		$cmbLanguage = $dlg.FindName('CmbLanguage')
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
		foreach ($entry in $languageEntries)
		{
			& $addComboItem $cmbLanguage (& $formatLanguageDisplay $entry) ([string]$entry.Code)
		}

		$initialLanguage = if ($Current.ContainsKey('Language') -and -not [string]::IsNullOrWhiteSpace([string]$Current.Language))
		{
			[string]$Current.Language
		}
		else
		{
			'en-US'
		}
		& $selectComboByTag $cmbLanguage $initialLanguage

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

				$selectedLanguage = if ($cmbLanguage -and $cmbLanguage.SelectedItem -and $cmbLanguage.SelectedItem.Tag) { [string]$cmbLanguage.SelectedItem.Tag } else { 'en' }
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

