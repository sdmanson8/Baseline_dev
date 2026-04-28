	# Capture functions into $Script: variables so WPF event handler delegates can resolve them.
	$Script:SetSearchInputStyleScript = ${function:Set-SearchInputStyle}
	$Script:SetSafeModeStateScript = ${function:Set-SafeModeState}
	$Script:SetAdvancedModeStateScript = ${function:Set-AdvancedModeState}
	$Script:SetGameModeStateScript = ${function:Set-GameModeState}
	$Script:SetDesignModeStateScript = ${function:Set-DesignModeState}
	$Script:SaveCurrentTabScrollOffsetScript = ${function:Save-CurrentTabScrollOffset}
	$Script:UpdateMainContentPanelWidthScript = ${function:Update-MainContentPanelWidth}
	$testGuiRunInProgressCapture = $Script:TestGuiRunInProgressScript

	$searchRefreshTimer = New-Object System.Windows.Threading.DispatcherTimer
	$searchRefreshTimer.Interval = [TimeSpan]::FromMilliseconds($Script:SearchRefreshDelayMs)
	$refreshSearchContentForTimer = $refreshSearchContent
	$null = Register-GuiEventHandler -Source $searchRefreshTimer -EventName 'Tick' -Handler ({
		$searchRefreshTimer.Stop()
		& $refreshSearchContentForTimer
	})
	$Script:SearchRefreshTimer = $searchRefreshTimer

	Set-SearchInputStyle
	Set-FilterControlStyle
	# Cache the icon content command once to avoid Get-Command on every filter click.
	$Script:HasLabeledIconContent = [bool](Get-Command -Name 'New-GuiLabeledIconContent' -CommandType Function -ErrorAction SilentlyContinue)
	# Filter toggle button - shows/hides the collapsible filter options panel
	$null = Register-GuiEventHandler -Source $BtnFilterToggle -EventName 'Click' -Handler ({
		if ($FilterOptionsPanel.Visibility -eq [System.Windows.Visibility]::Collapsed)
		{
			$FilterOptionsPanel.Visibility = [System.Windows.Visibility]::Visible
			$BtnFilterToggle.Content = $(
				$fc = if ($Script:HasLabeledIconContent) { New-GuiLabeledIconContent -IconName 'Filter' -Text "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" -IconSize 14 -Gap 6 -TextFontSize 11 -AllowTextOnlyFallback } else { $null }
				if ($fc) { $fc } else { "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" }
			)
		}
		else
		{
			$FilterOptionsPanel.Visibility = [System.Windows.Visibility]::Collapsed
			$BtnFilterToggle.Content = $(
				$fc = if ($Script:HasLabeledIconContent) { New-GuiLabeledIconContent -IconName 'Filter' -Text "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25B8)" -IconSize 14 -Gap 6 -TextFontSize 11 -AllowTextOnlyFallback } else { $null }
				if ($fc) { $fc } else { "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25B8)" }
			)
		}
	})
	$TxtSearch.Text = if ($Script:AppsModeActive) { [string]$Script:AppsSearchText } else { [string]$Script:SearchText }
	$null = Register-GuiEventHandler -Source $TxtSearch -EventName 'GotKeyboardFocus' -Handler ({
		Invoke-CapturedFunction -Name 'Set-SearchInputStyle'
	})
	$null = Register-GuiEventHandler -Source $TxtSearch -EventName 'LostKeyboardFocus' -Handler ({
		Invoke-CapturedFunction -Name 'Set-SearchInputStyle'
	})
	$null = Register-GuiEventHandler -Source $TxtSearch -EventName 'TextChanged' -Handler ({
		if ((& $testGuiRunInProgressCapture) -or $Script:SearchUiUpdating) { return }
		if ($Script:AppsModeActive)
		{
			$Script:AppsSearchText = [string]$TxtSearch.Text
		}
		else
		{
			$Script:SearchText = [string]$TxtSearch.Text
		}
		& $Script:SetSearchInputStyleScript
		if ($Script:SearchRefreshTimer)
		{
			$Script:SearchRefreshTimer.Stop()
			$Script:SearchRefreshTimer.Start()
		}
		else
		{
			& $refreshSearchContent
		}
	})
	$null = Register-GuiEventHandler -Source $CmbRiskFilter -EventName 'SelectionChanged' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		$selectedRisk = if ($CmbRiskFilter.SelectedIndex -ge 0 -and $Script:RiskFilterInternalValues -and $CmbRiskFilter.SelectedIndex -lt $Script:RiskFilterInternalValues.Count) { $Script:RiskFilterInternalValues[$CmbRiskFilter.SelectedIndex] } else { 'All' }
		& $Script:GuiState.Set 'RiskFilter' $selectedRisk
		if ($selectedRisk -ne 'All' -and $FilterOptionsPanel.Visibility -eq [System.Windows.Visibility]::Collapsed)
		{
			$FilterOptionsPanel.Visibility = [System.Windows.Visibility]::Visible
			$BtnFilterToggle.Content = $(
				$fc = if ($Script:HasLabeledIconContent) { New-GuiLabeledIconContent -IconName 'Filter' -Text "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" -IconSize 14 -Gap 6 -TextFontSize 11 -AllowTextOnlyFallback } else { $null }
				if ($fc) { $fc } else { "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" }
			)
		}
	})
	$null = Register-GuiEventHandler -Source $CmbCategoryFilter -EventName 'SelectionChanged' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		$selectedCat = if ($CmbCategoryFilter.SelectedIndex -ge 0 -and $Script:CategoryFilterInternalValues -and $CmbCategoryFilter.SelectedIndex -lt $Script:CategoryFilterInternalValues.Count) { $Script:CategoryFilterInternalValues[$CmbCategoryFilter.SelectedIndex] } else { 'All' }
		& $Script:GuiState.Set 'CategoryFilter' $selectedCat
		if ($selectedCat -ne 'All' -and $FilterOptionsPanel.Visibility -eq [System.Windows.Visibility]::Collapsed)
		{
			$FilterOptionsPanel.Visibility = [System.Windows.Visibility]::Visible
			$BtnFilterToggle.Content = $(
				$fc = if ($Script:HasLabeledIconContent) { New-GuiLabeledIconContent -IconName 'Filter' -Text "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" -IconSize 14 -Gap 6 -TextFontSize 11 -AllowTextOnlyFallback } else { $null }
				if ($fc) { $fc } else { "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" }
			)
		}
	})
	$null = Register-GuiEventHandler -Source $CmbPlatformFilter -EventName 'SelectionChanged' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		$selectedPlatform = if ($CmbPlatformFilter.SelectedIndex -ge 0 -and $Script:PlatformFilterInternalValues -and $CmbPlatformFilter.SelectedIndex -lt $Script:PlatformFilterInternalValues.Count) { $Script:PlatformFilterInternalValues[$CmbPlatformFilter.SelectedIndex] } else { 'ThisDevice' }
		Set-PlatformFilterState -PlatformFilter $selectedPlatform
		if ($Script:UpdateCurrentTabContentScript)
		{
			& $Script:UpdateCurrentTabContentScript -SkipIdlePrebuild
		}
		elseif (Get-Command -Name 'Update-CurrentTabContent' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-CurrentTabContent -SkipIdlePrebuild
		}
		if ($selectedPlatform -ne 'ThisDevice' -and $FilterOptionsPanel.Visibility -eq [System.Windows.Visibility]::Collapsed)
		{
			$FilterOptionsPanel.Visibility = [System.Windows.Visibility]::Visible
			$BtnFilterToggle.Content = $(
				$fc = if ($Script:HasLabeledIconContent) { New-GuiLabeledIconContent -IconName 'Filter' -Text "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" -IconSize 14 -Gap 6 -TextFontSize 11 -AllowTextOnlyFallback } else { $null }
				if ($fc) { $fc } else { "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" }
			)
		}
	})
	if ($Script:AppsCategoryTabs)
	{
		$null = Register-GuiEventHandler -Source $Script:AppsCategoryTabs -EventName 'SelectionChanged' -Handler ({
			param($appsTabSender, $appsTabEventArgs)
			if (-not $appsTabEventArgs) { return }
			if ($appsTabEventArgs.Source -ne $Script:AppsCategoryTabs) { return }
			if ($Script:AppsFilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
			$selectedAppTab = $Script:AppsCategoryTabs.SelectedItem
			$selectedAppCategory = if ($selectedAppTab -and $selectedAppTab.Tag) { [string]$selectedAppTab.Tag } else { 'All' }
			Set-AppCategoryFilterState -Category $selectedAppCategory
		})
	}
	if ($Script:BtnAppsFilterToggle -and $Script:AppsFilterOptionsPanel)
	{
		$null = Register-GuiEventHandler -Source $Script:BtnAppsFilterToggle -EventName 'Click' -Handler ({
			if ($Script:AppsFilterOptionsPanel.Visibility -eq [System.Windows.Visibility]::Collapsed)
			{
				$Script:AppsFilterOptionsPanel.Visibility = [System.Windows.Visibility]::Visible
				$Script:BtnAppsFilterToggle.Content = $(
					$fc = if ($Script:HasLabeledIconContent) { New-GuiLabeledIconContent -IconName 'Filter' -Text "$(Get-UxLocalizedString -Key 'GuiBtnAppsFilterToggle' -Fallback 'Filter') $([char]0x25BE)" -IconSize 14 -Gap 6 -TextFontSize 11 -AllowTextOnlyFallback } else { $null }
					if ($fc) { $fc } else { "$(Get-UxLocalizedString -Key 'GuiBtnAppsFilterToggle' -Fallback 'Filter') $([char]0x25BE)" }
				)
			}
			else
			{
				$Script:AppsFilterOptionsPanel.Visibility = [System.Windows.Visibility]::Collapsed
				$Script:BtnAppsFilterToggle.Content = $(
					$fc = if ($Script:HasLabeledIconContent) { New-GuiLabeledIconContent -IconName 'Filter' -Text "$(Get-UxLocalizedString -Key 'GuiBtnAppsFilterToggle' -Fallback 'Filter') $([char]0x25B8)" -IconSize 14 -Gap 6 -TextFontSize 11 -AllowTextOnlyFallback } else { $null }
					if ($fc) { $fc } else { "$(Get-UxLocalizedString -Key 'GuiBtnAppsFilterToggle' -Fallback 'Filter') $([char]0x25B8)" }
				)
			}
		})
	}
	$null = Register-GuiEventHandler -Source $CmbAppsStatusFilter -EventName 'SelectionChanged' -Handler ({
		if ($Script:AppsFilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		$selectedAppStatus = if ($CmbAppsStatusFilter.SelectedIndex -ge 0 -and $Script:AppsStatusFilterInternalValues -and $CmbAppsStatusFilter.SelectedIndex -lt $Script:AppsStatusFilterInternalValues.Count) { $Script:AppsStatusFilterInternalValues[$CmbAppsStatusFilter.SelectedIndex] } else { 'All' }
		Set-AppStatusFilterState -Status $selectedAppStatus
		if ($selectedAppStatus -ne 'All' -and $Script:AppsFilterOptionsPanel -and $Script:AppsFilterOptionsPanel.Visibility -eq [System.Windows.Visibility]::Collapsed)
		{
			$Script:AppsFilterOptionsPanel.Visibility = [System.Windows.Visibility]::Visible
			if ($Script:BtnAppsFilterToggle)
			{
				$Script:BtnAppsFilterToggle.Content = $(
					$fc = if ($Script:HasLabeledIconContent) { New-GuiLabeledIconContent -IconName 'Filter' -Text "$(Get-UxLocalizedString -Key 'GuiBtnAppsFilterToggle' -Fallback 'Filter') $([char]0x25BE)" -IconSize 14 -Gap 6 -TextFontSize 11 -AllowTextOnlyFallback } else { $null }
					if ($fc) { $fc } else { "$(Get-UxLocalizedString -Key 'GuiBtnAppsFilterToggle' -Fallback 'Filter') $([char]0x25BE)" }
				)
			}
		}
	})
	$null = Register-GuiEventHandler -Source $ChkSelectedOnly -EventName 'Checked' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		& $Script:GuiState.Set 'SelectedOnlyFilter' $true
		if ($FilterOptionsPanel.Visibility -eq [System.Windows.Visibility]::Collapsed)
		{
			$FilterOptionsPanel.Visibility = [System.Windows.Visibility]::Visible
			$BtnFilterToggle.Content = $(
				$fc = if ($Script:HasLabeledIconContent) { New-GuiLabeledIconContent -IconName 'Filter' -Text "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" -IconSize 14 -Gap 6 -TextFontSize 11 -AllowTextOnlyFallback } else { $null }
				if ($fc) { $fc } else { "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" }
			)
		}
	})
	$null = Register-GuiEventHandler -Source $ChkSelectedOnly -EventName 'Unchecked' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		& $Script:GuiState.Set 'SelectedOnlyFilter' $false
	})
	$null = Register-GuiEventHandler -Source $ChkHideUnavailableItems -EventName 'Checked' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		Set-HideUnavailableItemsState -HideUnavailableItems $true
		if ($Script:UpdateCurrentTabContentScript)
		{
			& $Script:UpdateCurrentTabContentScript -SkipIdlePrebuild
		}
		elseif (Get-Command -Name 'Update-CurrentTabContent' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-CurrentTabContent -SkipIdlePrebuild
		}
	})
	$null = Register-GuiEventHandler -Source $ChkHideUnavailableItems -EventName 'Unchecked' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		Set-HideUnavailableItemsState -HideUnavailableItems $false
		if ($Script:UpdateCurrentTabContentScript)
		{
			& $Script:UpdateCurrentTabContentScript -SkipIdlePrebuild
		}
		elseif (Get-Command -Name 'Update-CurrentTabContent' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-CurrentTabContent -SkipIdlePrebuild
		}
	})
	$null = Register-GuiEventHandler -Source $ChkHighRiskOnly -EventName 'Checked' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		& $Script:GuiState.Set 'HighRiskOnlyFilter' $true
		if ($FilterOptionsPanel.Visibility -eq [System.Windows.Visibility]::Collapsed)
		{
			$FilterOptionsPanel.Visibility = [System.Windows.Visibility]::Visible
			$BtnFilterToggle.Content = $(
				$fc = if ($Script:HasLabeledIconContent) { New-GuiLabeledIconContent -IconName 'Filter' -Text "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" -IconSize 14 -Gap 6 -TextFontSize 11 -AllowTextOnlyFallback } else { $null }
				if ($fc) { $fc } else { "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" }
			)
		}
	})
	$null = Register-GuiEventHandler -Source $ChkHighRiskOnly -EventName 'Unchecked' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		& $Script:GuiState.Set 'HighRiskOnlyFilter' $false
	})
	$null = Register-GuiEventHandler -Source $ChkRestorableOnly -EventName 'Checked' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		& $Script:GuiState.Set 'RestorableOnlyFilter' $true
		if ($FilterOptionsPanel.Visibility -eq [System.Windows.Visibility]::Collapsed)
		{
			$FilterOptionsPanel.Visibility = [System.Windows.Visibility]::Visible
			$BtnFilterToggle.Content = $(
				$fc = if ($Script:HasLabeledIconContent) { New-GuiLabeledIconContent -IconName 'Filter' -Text "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" -IconSize 14 -Gap 6 -TextFontSize 11 -AllowTextOnlyFallback } else { $null }
				if ($fc) { $fc } else { "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" }
			)
		}
	})
	$null = Register-GuiEventHandler -Source $ChkRestorableOnly -EventName 'Unchecked' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		& $Script:GuiState.Set 'RestorableOnlyFilter' $false
	})
	$null = Register-GuiEventHandler -Source $ChkGamingOnly -EventName 'Checked' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		& $Script:GuiState.Set 'GamingOnlyFilter' $true
		if ($FilterOptionsPanel.Visibility -eq [System.Windows.Visibility]::Collapsed)
		{
			$FilterOptionsPanel.Visibility = [System.Windows.Visibility]::Visible
			$BtnFilterToggle.Content = $(
				$fc = if ($Script:HasLabeledIconContent) { New-GuiLabeledIconContent -IconName 'Filter' -Text "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" -IconSize 14 -Gap 6 -TextFontSize 11 -AllowTextOnlyFallback } else { $null }
				if ($fc) { $fc } else { "$(Get-UxLocalizedString -Key 'GuiBtnFilterToggle' -Fallback 'Filters') $([char]0x25BE)" }
			)
		}
	})
	$null = Register-GuiEventHandler -Source $ChkGamingOnly -EventName 'Unchecked' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		& $Script:GuiState.Set 'GamingOnlyFilter' $false
	})
	$null = Register-GuiEventHandler -Source $ChkSafeMode -EventName 'Checked' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		& $Script:SetSafeModeStateScript -Enabled $true
	})
	$null = Register-GuiEventHandler -Source $ChkSafeMode -EventName 'Unchecked' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		& $Script:SetAdvancedModeStateScript -Enabled $true
	})
	$null = Register-GuiEventHandler -Source $ChkGameMode -EventName 'Checked' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		& $Script:SetGameModeStateScript -Enabled $true
	})
	$null = Register-GuiEventHandler -Source $ChkGameMode -EventName 'Unchecked' -Handler ({
		if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
		& $Script:SetGameModeStateScript -Enabled $false
	})
	if ($ChkDesignMode)
	{
		$null = Register-GuiEventHandler -Source $ChkDesignMode -EventName 'Checked' -Handler ({
			if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
			& $Script:SetDesignModeStateScript -Enabled $true
		})
		$null = Register-GuiEventHandler -Source $ChkDesignMode -EventName 'Unchecked' -Handler ({
			if ($Script:FilterUiUpdating -or (& $testGuiRunInProgressCapture)) { return }
			& $Script:SetDesignModeStateScript -Enabled $false
		})
	}
	$null = Register-GuiEventHandler -Source $BtnClearSearch -EventName 'Click' -Handler ({
		$TxtSearch.Text = ''
		[void]($TxtSearch.Focus())
	})
	# Enable pixel-based smooth scrolling
	[System.Windows.Controls.ScrollViewer]::SetCanContentScroll($ContentScroll, $false)
	[System.Windows.Controls.ScrollViewer]::SetIsDeferredScrollingEnabled($ContentScroll, $false)
	$scrollSaveTimer = New-Object System.Windows.Threading.DispatcherTimer
	$scrollSaveTimer.Interval = [TimeSpan]::FromMilliseconds(100)
	$null = Register-GuiEventHandler -Source $scrollSaveTimer -EventName 'Tick' -Handler ({
		$scrollSaveTimer.Stop()
		Invoke-CapturedFunction -Name 'Save-CurrentTabScrollOffset'
	})
	$null = Register-GuiEventHandler -Source $ContentScroll -EventName 'ScrollChanged' -Handler ({
		if (& $testGuiRunInProgressCapture) { return }
		$scrollSaveTimer.Stop()
		$scrollSaveTimer.Start()
	})
	$null = Register-GuiEventHandler -Source $ContentScroll -EventName 'SizeChanged' -Handler ({
		if ($ContentScroll.Content -is [System.Windows.FrameworkElement])
		{
			& $Script:UpdateMainContentPanelWidthScript -Panel $ContentScroll.Content
		}
	})
