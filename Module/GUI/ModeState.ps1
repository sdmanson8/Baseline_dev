# Safe Mode / Expert Mode state toggle functions.
# Dot-sourced inside Show-TweakGUI.
#
# Single unified toggle: ChkSafeMode checked = Safe Mode, unchecked = Expert Mode.
# The toggle label updates dynamically to reflect the active mode.

	function Save-GuiDefaultStartupModePreference
	{
		[CmdletBinding()]
		param (
			[Parameter(Mandatory)]
			[ValidateSet('Safe', 'Expert')]
			[string]$Mode
		)

		if (Get-Command -Name 'Set-BaselineUserPreference' -CommandType Function -ErrorAction SilentlyContinue)
		{
			try { Set-BaselineUserPreference -Key 'DefaultStartupMode' -Value $Mode } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ModeState.SaveDefaultStartupModePreference' }
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-SafeModeState.
	#>

	function Set-SafeModeState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ([bool]$Enabled)

		# Toggling Safe Mode on via the header is also a vote for Safe being the
		# default mode at the next launch, so keep DefaultStartupMode in sync
		# (Settings dialog reads it back from $Script:DefaultStartupMode).
		if ($Enabled)
		{
			$Script:DefaultStartupMode = 'Safe'
			Save-GuiDefaultStartupModePreference -Mode 'Safe'
		}

		$previousState = Test-GuiModeActive -Mode 'Safe'
		$advancedWasEnabled = Test-GuiModeActive -Mode 'Expert'
		$Script:FilterUiUpdating = $true
		try
		{
			Set-GuiMode -ViewMode $(if ($Enabled) { 'Safe' } else { 'Standard' })
			if ($ChkSafeMode)
			{
				$ChkSafeMode.IsChecked = $Enabled
				$ChkSafeMode.Content = if ($Enabled)
				{
					Get-UxLocalizedString -Key 'GuiHelpSectionSafeMode' -Fallback 'Safe Mode'
				}
				else
				{
					Get-UxLocalizedString -Key 'GuiHelpSectionExpertMode' -Fallback 'Expert Mode'
				}
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
		if ($BtnLog)           { $BtnLog.Visibility           = 'Collapsed' }
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

		# Enabling Expert via the header makes Expert the new startup default;
		# disabling drops back to Safe (Standard isn't a startup option).
		$nextStartupMode = if ($Enabled) { 'Expert' } else { 'Safe' }
		$Script:DefaultStartupMode = $nextStartupMode
		Save-GuiDefaultStartupModePreference -Mode $nextStartupMode

		$previousState = Test-GuiModeActive -Mode 'Expert'
		$safeWasEnabled = Test-GuiModeActive -Mode 'Safe'
		$Script:FilterUiUpdating = $true
		try
		{
			Set-GuiMode -ViewMode $(if ($Enabled) { 'Expert' } else { 'Standard' })
			if ($ChkSafeMode)
			{
				$ChkSafeMode.IsChecked = $false
				$ChkSafeMode.Content = if ($Enabled)
				{
					Get-UxLocalizedString -Key 'GuiHelpSectionExpertMode' -Fallback 'Expert Mode'
				}
				else
				{
					Get-UxLocalizedString -Key 'GuiHelpSectionSafeMode' -Fallback 'Safe Mode'
				}
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
		if ($BtnLog)          { $BtnLog.Visibility          = 'Collapsed' }
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

	<#
	    .SYNOPSIS
	    Internal function Set-DesignModeState.
	#>

	function Set-DesignModeState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ([bool]$Enabled)

		$previousState = [bool]$Script:DesignMode
		$normalized = [bool]$Enabled
		$Script:FilterUiUpdating = $true
		try
		{
			$Script:DesignMode = $normalized
			if ($Script:Ctx)
			{
				if ($Script:Ctx.ContainsKey('UI')) { $Script:Ctx.UI.DesignMode = $normalized }
				if ($Script:Ctx.ContainsKey('Mode')) { $Script:Ctx.Mode.Design = $normalized }
			}
			if ($ChkDesignMode)
			{
				$ChkDesignMode.IsChecked = $normalized
				$ChkDesignMode.Content = 'Design Mode'
			}
			if (Get-Command -Name 'Set-BaselineUserPreference' -CommandType Function -ErrorAction SilentlyContinue)
			{
				try { Set-BaselineUserPreference -Key 'DesignMode' -Value $normalized } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ModeState.Set-DesignModeState.SavePreference' }
			}
		}
		finally
		{
			$Script:FilterUiUpdating = $false
		}

		if ($previousState -eq $normalized)
		{
			return
		}

		$message = if ($normalized)
		{
			'Design Mode enabled. Detection now uses manifest defaults and the action button becomes {0}.' -f (Get-UxRunActionLabel)
		}
		else
		{
			'Design Mode disabled. The action button returns to {0}.' -f (Get-UxRunActionLabel)
		}

		Invoke-GuiStateTransition `
			-Context 'DesignMode' `
			-StatusMessage $message `
			-StatusTone $(if ($normalized) { 'success' } else { 'muted' }) `
			-ClearCache `
			-RebuildTab `
			-SyncActionButton `
			-UpdateModeText

		if (Get-Command -Name 'Update-WindowMinWidthFromHeader' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-WindowMinWidthFromHeader
		}
	}
