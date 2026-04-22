		<#
		    .SYNOPSIS
		    Internal function Set-GUITheme.
		#>

		function Set-GUITheme
		{
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
			param ([hashtable]$Theme)
			$themeRepairName = 'Dark'
			if ($Theme -eq $Script:LightTheme)
			{
				$Script:CurrentThemeName = 'Light'
				$themeRepairName = 'Light'
			}
			elseif ($Theme -eq $Script:DarkTheme)
			{
				$Script:CurrentThemeName = 'Dark'
				$themeRepairName = 'Dark'
			}
			else
			{
				$Script:CurrentThemeName = 'Custom'
			}
			$Theme = Repair-GuiThemePalette -Theme $Theme -ThemeName $themeRepairName
			$Script:CurrentTheme = $Theme
			$Script:BrushCache = @{}
			$Script:SharedCardShadow = $null
			$Script:CardHoverResources = $null
			$bc = New-SafeBrushConverter -Context 'Set-GUITheme'

		$Form.Foreground  = $bc.ConvertFromString($Theme.TextPrimary)
		[void](GUICommon\Set-GuiWindowChromeTheme -Window $Form -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))
		[void](GUICommon\Update-GuiPopupWindowThemes -Theme $Theme -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))
		if ($WindowBorder) { $WindowBorder.Background = $bc.ConvertFromString($Theme.WindowBg); $WindowBorder.BorderBrush = $bc.ConvertFromString($Theme.BorderColor) }
		if ($TitleBar) { $TitleBar.Background = $bc.ConvertFromString($Theme.HeaderBg) }
		if ($TitleBarText) { $TitleBarText.Foreground = $bc.ConvertFromString($Theme.TextPrimary) }
		if ($BtnMinimize) { Set-WindowCaptionButtonStyle -Button $BtnMinimize }
		if ($BtnMaximize) { Set-WindowCaptionButtonStyle -Button $BtnMaximize }
		if ($BtnClose) { Set-WindowCaptionButtonStyle -Button $BtnClose -Variant 'Close' }
		if ($Script:NavModeTweaks) { Set-ButtonChrome -Button $Script:NavModeTweaks -Variant 'Subtle' -Compact -Muted }
		if ($Script:NavModeApps) { Set-ButtonChrome -Button $Script:NavModeApps -Variant 'Subtle' -Compact -Muted }
		if ($Script:BtnUpdateAllApps) { Set-ButtonChrome -Button $Script:BtnUpdateAllApps -Variant 'Primary' -Compact }
		if ($Script:BtnDownloadYes) { Set-ButtonChrome -Button $Script:BtnDownloadYes -Variant 'Primary' }
		if ($Script:BtnDownloadNo) { Set-ButtonChrome -Button $Script:BtnDownloadNo -Variant 'Secondary' }
		$HeaderBorder.Background = $bc.ConvertFromString($Theme.HeaderBg)
		if ($HeaderSeparator) { $HeaderSeparator.Background = $bc.ConvertFromString($Theme.BorderColor) }
		$ContentBorder.Background = $bc.ConvertFromString($Theme.PanelBg)
		if ($Script:ExpertModeBanner)
		{
			$Script:ExpertModeBanner.Background = $bc.ConvertFromString($Theme.CautionBg)
			$bannerText = $Script:ExpertModeBanner.Child
			if ($bannerText) { $bannerText.Foreground = $bc.ConvertFromString($Theme.CautionText) }
		}
		$BottomBorder.Background = $bc.ConvertFromString($Theme.PanelBg)
		$BottomBorder.BorderBrush = $bc.ConvertFromString($Theme.BorderColor)
		$TitleText.Foreground = $bc.ConvertFromString($Theme.TextPrimary)
		$ScanLabel.Foreground = $bc.ConvertFromString($Theme.TextSecondary)
		$currentStatusText = ''
		if ($Script:GuiState)
		{
			try { $currentStatusText = [string](& $Script:GuiState.Get 'StatusText') } catch { $currentStatusText = '' }
		}
		elseif ($StatusText)
		{
			$currentStatusText = [string]$StatusText.Text
		}
		Set-GuiStatusText -Text $currentStatusText -Tone $(if ($Script:CurrentStatusTone) { [string]$Script:CurrentStatusTone } else { 'muted' })
		Set-HeaderToggleControlsStyle
		if ($Script:UpdateDialogCard)
		{
			$Script:UpdateDialogCard.Background = $bc.ConvertFromString($Theme.CardBg)
			$Script:UpdateDialogCard.BorderBrush = $bc.ConvertFromString($Theme.BorderColor)
		}
		if ($Script:CustomPBarContainer) { $Script:CustomPBarContainer.Background = $bc.ConvertFromString($Theme.CardBorder) }
		if ($Script:AppsProgressContainer) { $Script:AppsProgressContainer.Background = $bc.ConvertFromString($Theme.CardBorder) }
		foreach ($progressBar in @($Script:CustomProgressBar, $Script:ExecutionProgressBar, $Script:AppsProgressBar, $Script:PresetProgressBar))
		{
			if ($progressBar)
			{
				Set-SheenProgressBarTheme -ProgressBar $progressBar -Theme $Theme
			}
		}
		if ($Script:TxtAppCacheStatus) { $Script:TxtAppCacheStatus.Foreground = $bc.ConvertFromString($Theme.TextSecondary) }
		if ($Script:AppsPackageManagerBanner)
		{
			$Script:AppsPackageManagerBanner.Background = $bc.ConvertFromString($Theme.CautionBg)
			$Script:AppsPackageManagerBanner.BorderBrush = $bc.ConvertFromString($Theme.CautionBorder)
		}
		if ($Script:TxtAppsPackageManagerBanner) { $Script:TxtAppsPackageManagerBanner.Foreground = $bc.ConvertFromString($Theme.CautionText) }
		if ($Script:TxtAppSelectionStatus) { $Script:TxtAppSelectionStatus.Foreground = $bc.ConvertFromString($Theme.TextSecondary) }
		if ($Script:TxtAppsProgressText) { $Script:TxtAppsProgressText.Foreground = $bc.ConvertFromString($Theme.TextSecondary) }
		if ($Script:TxtOverlayTitle) { $Script:TxtOverlayTitle.Foreground = $bc.ConvertFromString($Theme.TextPrimary) }
		if ($Script:TxtUpdateDescription) { $Script:TxtUpdateDescription.Foreground = $bc.ConvertFromString($Theme.TextSecondary) }
		if ($Script:TxtDownloadProgressLabel) { $Script:TxtDownloadProgressLabel.Foreground = $bc.ConvertFromString($Theme.TextSecondary) }
		if ($Script:TxtDownloadProgressPct) { $Script:TxtDownloadProgressPct.Foreground = $bc.ConvertFromString($Theme.TextSecondary) }
		Set-SearchInputStyle
		Set-FilterControlStyle
		Set-StaticButtonStyle
		Update-PrimaryTabVisuals
		if (Get-Command -Name 'Update-GuiMenuBarTheme' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-GuiMenuBarTheme
		}
		if (Get-Command -Name 'Update-GuiScrollBarTheme' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-GuiScrollBarTheme
		}

		# Rebuild content for current tab to pick up new theme colors.
		$Script:FilterGeneration++
		Clear-TabContentCache
		$Script:AppsViewBuildSignature = $null
		if ($Script:AppsModeActive)
		{
			if (Get-Command -Name 'Build-AppsViewCards' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Build-AppsViewCards
			}
		}
		elseif ($null -ne $Script:CurrentPrimaryTab)
		{
			Build-TabContent -PrimaryTab $Script:CurrentPrimaryTab -SkipIdlePrebuild
		}
		Update-HeaderModeStateText
		if (Get-Command -Name 'Update-RunPathContextLabel' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-RunPathContextLabel
		}
	}
