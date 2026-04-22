# Safe Mode / Expert Mode state toggle functions.
# Dot-sourced inside Show-TweakGUI.
#
# Single unified toggle: ChkSafeMode checked = Safe Mode, unchecked = Expert Mode.
# The toggle label updates dynamically to reflect the active mode.

	<#
	    .SYNOPSIS
	    Internal function Set-SafeModeState.
	#>

	function Set-SafeModeState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ([bool]$Enabled)

		$previousState = Test-GuiModeActive -Mode 'Safe'
		$advancedWasEnabled = Test-GuiModeActive -Mode 'Expert'
		$Script:FilterUiUpdating = $true
		try
		{
			Set-GuiMode -ViewMode $(if ($Enabled) { 'Safe' } else { 'Standard' })
			if ($ChkSafeMode)
			{
				$ChkSafeMode.IsChecked = $Enabled
				$ChkSafeMode.Content = (Get-UxLocalizedString -Key 'GuiChkSafeMode' -Fallback '')
			}
		}
		finally
		{
			$Script:FilterUiUpdating = $false
		}

		if (($previousState -eq $Enabled) -and -not ($Enabled -and $advancedWasEnabled))
		{
			return
		}

		$clearedCount = 0
		if ($Enabled)
		{
			$clearedCount = & $Script:ClearInvisibleSelectionStateScript
		}

		$message = if ($Enabled)
		{
			Get-UxLocalizedString -Key 'GuiStatusSafeModeEnabled' -Fallback ''
		}
		elseif ($clearedCount -gt 0)
		{
			Get-UxLocalizedString -Key 'GuiStatusSafeModeDisabledCleared' -Fallback '' -FormatArgs @($clearedCount)
		}
		else
		{
			Get-UxLocalizedString -Key 'GuiStatusSafeModeDisabledRestored' -Fallback ''
		}

		Invoke-GuiStateTransition `
			-Context 'SafeMode' `
			-StatusMessage $message `
			-StatusTone $(if ($Enabled) { 'success' } else { 'muted' }) `
			-ClearCache `
			-RebuildTab `
			-SyncActionButton `
			-UpdatePresetBadge `
			-UpdateModeText

		if ($ExpertModeBanner)
		{
			$ExpertModeBanner.Visibility = 'Collapsed'
		}

		# Progressive disclosure: hide non-essential controls in Safe Mode
		$safeModeHidden = if ($Enabled) { 'Collapsed' } else { 'Visible' }
		if ($BtnLog)           { $BtnLog.Visibility           = $safeModeHidden }
		if ($BtnFilterToggle)  { $BtnFilterToggle.Visibility  = $safeModeHidden }
		if ($FilterOptionsPanel -and $FilterOptionsPanel.Visibility -ne 'Collapsed')
		{
			$FilterOptionsPanel.Visibility = 'Collapsed'
		}
		if ($ChkScan)          { $ChkScan.Visibility          = $safeModeHidden }

		# Menu bar: hide advanced menu items and Tools menu entirely in Safe Mode
		if ($Script:MenuTools)                  { $Script:MenuTools.Visibility                  = $safeModeHidden }
		if ($Script:MenuActionsCheckCompliance) { $Script:MenuActionsCheckCompliance.Visibility = $safeModeHidden }
		if ($Script:MenuActionsScanSystem)      { $Script:MenuActionsScanSystem.Visibility      = $safeModeHidden }
		if ($Script:MenuActionsAuditLog)        { $Script:MenuActionsAuditLog.Visibility        = $safeModeHidden }
		if ($Script:MenuViewFilters)            { $Script:MenuViewFilters.Visibility            = $safeModeHidden }
		if ($Script:MenuFileExportSystemState)  { $Script:MenuFileExportSystemState.Visibility  = $safeModeHidden }
		if ($Script:MenuFileExportConfigProfile){ $Script:MenuFileExportConfigProfile.Visibility= $safeModeHidden }

		if (Get-Command -Name 'Update-WindowMinWidthFromHeader' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-WindowMinWidthFromHeader
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-AdvancedModeState.
	#>

	function Set-AdvancedModeState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ([bool]$Enabled)

		$previousState = Test-GuiModeActive -Mode 'Expert'
		$safeWasEnabled = Test-GuiModeActive -Mode 'Safe'
		$Script:FilterUiUpdating = $true
		try
		{
			Set-GuiMode -ViewMode $(if ($Enabled) { 'Expert' } else { 'Standard' })
			if ($ChkSafeMode)
			{
				$ChkSafeMode.IsChecked = $false
				$ChkSafeMode.Content = (Get-UxLocalizedString -Key 'GuiChkSafeMode' -Fallback '')
			}
		}
		finally
		{
			$Script:FilterUiUpdating = $false
		}

		if (($previousState -eq $Enabled) -and -not ($Enabled -and $safeWasEnabled))
		{
			return
		}

		$clearedCount = 0
		if (-not $Enabled)
		{
			$clearedCount = & $Script:ClearInvisibleSelectionStateScript
		}

		$message = if ($Enabled)
		{
			Get-UxLocalizedString -Key 'GuiStatusExpertModeEnabled' -Fallback ''
		}
		elseif ($clearedCount -gt 0)
		{
			Get-UxLocalizedString -Key 'GuiStatusExpertModeDisabledCleared' -Fallback '' -FormatArgs @($clearedCount)
		}
		else
		{
			Get-UxLocalizedString -Key 'GuiStatusExpertModeDisabledRestored' -Fallback ''
		}

		Invoke-GuiStateTransition `
			-Context 'ExpertMode' `
			-StatusMessage $message `
			-StatusTone $(if ($Enabled) { 'success' } else { 'muted' }) `
			-ClearCache `
			-RebuildTab `
			-SyncActionButton `
			-UpdatePresetBadge `
			-UpdateModeText

		if ($ExpertModeBanner)
		{
			$ExpertModeBanner.Visibility = if ($Enabled) { 'Visible' } else { 'Collapsed' }
		}

		# Restore controls hidden by Safe Mode's progressive disclosure
		if ($BtnLog)          { $BtnLog.Visibility          = 'Visible' }
		if ($BtnFilterToggle) { $BtnFilterToggle.Visibility = 'Visible' }
		if ($ChkScan)         { $ChkScan.Visibility         = 'Visible' }

		# Restore menu bar items hidden by Safe Mode
		if ($Script:MenuTools)                  { $Script:MenuTools.Visibility                  = 'Visible' }
		if ($Script:MenuActionsCheckCompliance) { $Script:MenuActionsCheckCompliance.Visibility = 'Visible' }
		if ($Script:MenuActionsScanSystem)      { $Script:MenuActionsScanSystem.Visibility      = 'Visible' }
		if ($Script:MenuActionsAuditLog)        { $Script:MenuActionsAuditLog.Visibility        = 'Visible' }
		if ($Script:MenuViewFilters)            { $Script:MenuViewFilters.Visibility            = 'Visible' }
		if ($Script:MenuFileExportSystemState)  { $Script:MenuFileExportSystemState.Visibility  = 'Visible' }
		if ($Script:MenuFileExportConfigProfile){ $Script:MenuFileExportConfigProfile.Visibility= 'Visible' }

		if (Get-Command -Name 'Update-WindowMinWidthFromHeader' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-WindowMinWidthFromHeader
		}
	}
