# Preset application logic: resolve context, apply selections, and complete preset state updates

	<#
	    .SYNOPSIS
	    Internal function Get-GuiPresetDebugLogger.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Get-GuiPresetDebugLogger
	{
		$writeGuiPresetDebugScript = ${function:Write-GuiPresetDebug}
		if ($Script:GuiPresetDebugScript)
		{
			$writeGuiPresetDebugScript = $Script:GuiPresetDebugScript
		}

		return $writeGuiPresetDebugScript
	}

	<#
	    .SYNOPSIS
	    Internal function .

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>
	function Resolve-TabPresetContext
	{
		param (
			[string]$PrimaryTab,
			[string]$PresetTier,
			[object]$SelectionDefinition = $null,
			[scriptblock]$WriteGuiPresetDebugScript
		)

		$convertToGuiPresetNameScript = ${function:ConvertTo-GuiPresetName}
		$getGuiPresetDefinitionScript = ${function:Get-GuiPresetDefinition}

		$normalizedPresetTier = & $convertToGuiPresetNameScript -PresetName $PresetTier
		$presetDefinition = if ($SelectionDefinition)
		{
			$SelectionDefinition
		}
		else
		{
			& $getGuiPresetDefinitionScript -PresetName $normalizedPresetTier
		}

		$usesExplicitPreset = ([string]$presetDefinition.SelectionMode -eq 'Explicit')
		$presetEntries = @{}
		if ($usesExplicitPreset -and $presetDefinition.Entries)
		{
			$presetEntries = $presetDefinition.Entries
		}

		$unmatchedPresetEntries = [object[]]@()
		if ($usesExplicitPreset -and (Test-GuiObjectField -Object $presetDefinition -FieldName 'UnmatchedEntries') -and $null -ne $presetDefinition.UnmatchedEntries)
		{
			$unmatchedPresetEntries = [object[]]$presetDefinition.UnmatchedEntries
		}

		if ($WriteGuiPresetDebugScript)
		{
			& $WriteGuiPresetDebugScript -Context 'Set-TabPreset' -Message ("Resolved preset apply: tab='{0}', normalizedPreset='{1}', mode={2}, source='{3}', entries={4}, unmatched={5}." -f $PrimaryTab, $presetDefinition.Name, $presetDefinition.SelectionMode, $(if ($presetDefinition.SourcePath) { $presetDefinition.SourcePath } else { '<none>' }), $presetEntries.Count, $unmatchedPresetEntries.Count)
		}

		$policyIssues = @()
		if ((Test-GuiObjectField -Object $presetDefinition -FieldName 'PolicyIssues') -and $null -ne $presetDefinition.PolicyIssues)
		{
			$policyIssues = [object[]]$presetDefinition.PolicyIssues
		}

		if ($policyIssues.Count -gt 0)
		{
			$policyReasonText = @($policyIssues | ForEach-Object { [string]$_.Reason } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
			$policyMessage = "Preset '{0}' has {1} policy issue$(if ($policyIssues.Count -eq 1) { '' } else { 's' }): {2}" -f $presetDefinition.Name, $policyIssues.Count, ($policyReasonText -join '; ')
			if ($WriteGuiPresetDebugScript)
			{
				& $WriteGuiPresetDebugScript -Context 'Set-TabPreset' -Message $policyMessage
			}
			else
			{
				Write-Warning $policyMessage
			}
		}

		if ($unmatchedPresetEntries.Count -gt 0)
		{
			$unmatchedFunctionNames = @($unmatchedPresetEntries | ForEach-Object { [string]$_.Function } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
			$unmatchedMessage = "Preset '{0}' references {1} unknown function$(if ($unmatchedPresetEntries.Count -eq 1) { '' } else { 's' }) (typo or removed tweak): {2}. These entries will be ignored." -f $presetDefinition.Name, $unmatchedPresetEntries.Count, ($unmatchedFunctionNames -join ', ')
			Write-Warning $unmatchedMessage
			if ($WriteGuiPresetDebugScript)
			{
				& $WriteGuiPresetDebugScript -Context 'Set-TabPreset' -Message $unmatchedMessage
			}
		}

		return [pscustomobject]@{
			NormalizedPresetTier   = $normalizedPresetTier
			PresetDefinition       = $presetDefinition
			UsesExplicitPreset     = $usesExplicitPreset
			PresetEntries          = $presetEntries
			UnmatchedPresetEntries = $unmatchedPresetEntries
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Initialize-TabPresetApplicationState.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Initialize-TabPresetApplicationState
	{
		param (
			[Parameter(Mandatory = $true)]
			[object]$PresetContext,
			[scriptblock]$SaveGuiUndoSnapshotScript,
			[scriptblock]$WriteGuiPresetDebugScript
		)

		& $SaveGuiUndoSnapshotScript
		if ($WriteGuiPresetDebugScript)
		{
			& $WriteGuiPresetDebugScript -Context 'Set-TabPreset' -Message ("Saved undo snapshot for preset '{0}'." -f $PresetContext.PresetDefinition.Name)
		}

		# Defensive state initialization for callback paths where script-scope stores may not exist yet.
		Initialize-GuiSelectionStateStores
		if (-not $Script:PendingLinkedChecks)
		{
			$Script:PendingLinkedChecks = [System.Collections.Generic.HashSet[string]]::new()
		}
		if (-not $Script:PendingLinkedUnchecks)
		{
			$Script:PendingLinkedUnchecks = [System.Collections.Generic.HashSet[string]]::new()
		}

		$Script:ExplicitPresetSelections.Clear()
		$Script:ExplicitPresetSelectionDefinitions.Clear()
		$Script:PendingLinkedChecks.Clear()
		$Script:PendingLinkedUnchecks.Clear()

		if ($PresetContext.UsesExplicitPreset)
		{
			foreach ($presetFunction in @($PresetContext.PresetEntries.Keys))
			{
				if (-not [string]::IsNullOrWhiteSpace([string]$presetFunction))
				{
					Set-GuiExplicitSelectionDefinition -FunctionName ([string]$presetFunction) -Definition (
						Copy-GuiExplicitSelectionDefinition -Definition $PresetContext.PresetEntries[$presetFunction] -FunctionName ([string]$presetFunction) -Source 'Preset'
					)
				}
			}
		}

		$Script:ScanEnabled = $false
		if ($ChkScan -and $ChkScan.IsChecked)
		{
			$ChkScan.IsChecked = $false
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-TabPresetSharedUiState.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Set-TabPresetSharedUiState
	{
		param (
			[string]$PrimaryTab,
			[Parameter(Mandatory = $true)]
			[object]$PresetContext,
			[scriptblock]$SetSafeModeStateScript,
			[scriptblock]$SetAdvancedModeStateScript,
			[scriptblock]$UpdateCategoryFilterListScript,
			[scriptblock]$SetFilterSelectionsScript,
			[scriptblock]$WriteGuiPresetDebugScript
		)

		$presetDefinition = $PresetContext.PresetDefinition
		$safeModeWasEnabled = Test-GuiModeActive -Mode 'Safe'
		$advancedModeWasEnabled = Test-GuiModeActive -Mode 'Expert'
		if ($presetDefinition.Name -eq 'Basic' -and (-not $safeModeWasEnabled -or (Test-GuiModeActive -Mode 'Expert')))
		{
			& $SetSafeModeStateScript -Enabled $true
		}
		if ($presetDefinition.Name -eq 'Advanced' -and (-not $advancedModeWasEnabled -or (Test-GuiModeActive -Mode 'Safe')))
		{
			& $SetAdvancedModeStateScript -Enabled $true
		}

		& $UpdateCategoryFilterListScript -PrimaryTab $PrimaryTab
		& $SetFilterSelectionsScript -Risk 'All' -Category 'All' -SelectedOnly:$false -HighRiskOnly:$false -RestorableOnly:$false -GamingOnly:$false

		if ($WriteGuiPresetDebugScript)
		{
			& $WriteGuiPresetDebugScript -Context 'Set-TabPreset' -Message ("Reset shared UI state for preset '{0}'." -f $presetDefinition.Name)
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Clear-GuiSelectableControlState.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Clear-GuiSelectableControlState
	{
		param ([object]$Control)

		if (-not $Control) { return }

		if ((Test-GuiObjectField -Object $Control -FieldName 'IsChecked'))
		{
			$Control.IsChecked = $false
		}
		elseif ((Test-GuiObjectField -Object $Control -FieldName 'SelectedIndex'))
		{
			[int]$clearIndex = -1
			$Control.SelectedIndex = $clearIndex
		}
		elseif ((Test-GuiObjectField -Object $Control -FieldName 'ACSlider') -or (Test-GuiObjectField -Object $Control -FieldName 'DCSlider'))
		{
			if ((Test-GuiObjectField -Object $Control -FieldName 'IsChecked'))
			{
				$Control.IsChecked = $false
			}
			if ((Test-GuiObjectField -Object $Control -FieldName 'ACValue'))
			{
				$Control.ACValue = $null
			}
			if ((Test-GuiObjectField -Object $Control -FieldName 'DCValue'))
			{
				$Control.DCValue = $null
			}
			if ((Test-GuiObjectField -Object $Control -FieldName 'Value'))
			{
				$Control.Value = $null
			}
			if ((Test-GuiObjectField -Object $Control -FieldName 'NumericValue'))
			{
				$Control.NumericValue = $null
			}
			if ((Test-GuiObjectField -Object $Control -FieldName 'IsEnabled'))
			{
				$Control.IsEnabled = $false
			}
			if ((Test-GuiObjectField -Object $Control -FieldName 'CheckBox') -and $Control.CheckBox)
			{
				$Control.CheckBox.IsChecked = $false
				$Control.CheckBox.IsEnabled = $false
			}
			if ((Test-GuiObjectField -Object $Control -FieldName 'ACSlider') -and $Control.ACSlider)
			{
				$Control.ACSlider.IsEnabled = $false
			}
			if ((Test-GuiObjectField -Object $Control -FieldName 'DCSlider') -and $Control.DCSlider)
			{
				$Control.DCSlider.IsEnabled = $false
			}
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Get-GuiChoiceOptions.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Get-GuiChoiceOptions
	{
		param ([object]$Options)

		if ($null -eq $Options)
		{
			return [object[]]@()
		}

		if ($Options -is [System.Array])
		{
			return [object[]]$Options
		}

		if ($Options -is [System.Collections.IEnumerable] -and -not ($Options -is [string]))
		{
			$optionList = [System.Collections.Generic.List[object]]::new()
			foreach ($option in $Options)
			{
				[void]$optionList.Add($option)
			}

			return [object[]]$optionList.ToArray()
		}

		return [object[]]@([string]$Options)
	}

	<#
	    .SYNOPSIS
	    Internal function Apply-TabPresetSelections.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Apply-TabPresetSelections
	{
		param (
			[Parameter(Mandatory = $true)]
			[object]$PresetContext,
			[scriptblock]$TestTweakMatchesPresetTierScript,
			[scriptblock]$SyncLinkedStateCapture
		)

			$stats = [ordered]@{
				SelectedCount       = 0
				ProcessedCount      = 0
				VisibleCount        = 0
				HiddenCount         = 0
				ControlMissingCount = 0
				ToggleCount         = 0
				ChoiceCount         = 0
				NumericRangeCount   = 0
				ActionCount         = 0
				StateChangeCount    = 0
			}

		$totalCount = $Script:TweakManifest.Count
		$progressBar = $Script:PresetProgressBar
		$progressHost = $Script:PresetProgressHost
		if ($progressHost)
		{
			$progressHost.Visibility = [System.Windows.Visibility]::Visible
		}
		if ($progressBar)
		{
			Set-SharedProgressBarState -ProgressBar $progressBar -Completed 0 -Total $totalCount
		}

		for ($index = 0; $index -lt $totalCount; $index++)
		{
			$stats.ProcessedCount++
			if ($progressBar -and ($index % 50 -eq 0))
			{
				Set-SharedProgressBarState -ProgressBar $progressBar -Completed $index -Total $totalCount
				[System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
			}
			$tweak = $Script:TweakManifest[$index]
			$control = $Script:Controls[$index]
			if (-not $control)
			{
				$stats.ControlMissingCount++
				continue
			}

			$isVisible = $true
			if ($tweak.VisibleIf)
			{
				try
				{
					$isVisible = [bool](& $tweak.VisibleIf)
				}
				catch
				{
					$isVisible = $false
				}
			}

			if ($isVisible)
			{
				$stats.VisibleCount++
			}
			else
			{
				$stats.HiddenCount++
			}

			if ((Test-GuiObjectField -Object $control -FieldName 'IsEnabled'))
			{
				$control.IsEnabled = $isVisible
			}

			if (-not $isVisible)
			{
				Clear-GuiSelectableControlState -Control $control
				continue
			}

			switch ($tweak.Type)
			{
				'Toggle'
				{
					$stats.ToggleCount++
					$presetEntry = if ($PresetContext.UsesExplicitPreset -and $null -ne $PresetContext.PresetEntries[$tweak.Function]) { $PresetContext.PresetEntries[$tweak.Function] } else { $null }
					if ($PresetContext.UsesExplicitPreset)
					{
						$includeInPreset = ($null -ne $presetEntry)
						$targetChecked = ($includeInPreset -and [string]$presetEntry.State -eq 'On')
					}
					else
					{
						$includeInPreset = (& $TestTweakMatchesPresetTierScript -Tweak $tweak -Tier $PresetContext.PresetDefinition.Tier)
						$targetChecked = ($includeInPreset -and [bool]$tweak.Default)
					}

					$currentChecked = $false
					if ((Test-GuiObjectField -Object $control -FieldName 'IsChecked'))
					{
						$currentChecked = [bool]$control.IsChecked
					}
					if ($currentChecked -ne [bool]$targetChecked)
					{
						$stats.StateChangeCount++
					}
					if ((Test-GuiObjectField -Object $control -FieldName 'IsChecked'))
					{
						$control.IsChecked = $targetChecked
					}

					if ($includeInPreset)
					{
						if ($PresetContext.UsesExplicitPreset)
						{
							[void]$Script:ExplicitPresetSelections.Add([string]$tweak.Function)
							$hasRunParam = if ($targetChecked) { -not [string]::IsNullOrWhiteSpace([string]$tweak.OnParam) } else { -not [string]::IsNullOrWhiteSpace([string]$tweak.OffParam) }
							if ($hasRunParam)
							{
								$stats.SelectedCount++
							}
						}
						elseif ($targetChecked)
						{
							$stats.SelectedCount++
						}
					}

					if ($tweak.LinkedWith -and $SyncLinkedStateCapture)
					{
						& $SyncLinkedStateCapture $tweak.LinkedWith $targetChecked
					}
				}
				'Action'
				{
					$stats.ActionCount++
					$presetEntry = if ($PresetContext.UsesExplicitPreset -and $null -ne $PresetContext.PresetEntries[$tweak.Function]) { $PresetContext.PresetEntries[$tweak.Function] } else { $null }
					if ($PresetContext.UsesExplicitPreset)
					{
						$includeInPreset = ($null -ne $presetEntry -and [bool]$presetEntry.Run)
						$targetChecked = $includeInPreset
					}
					else
					{
						$includeInPreset = (& $TestTweakMatchesPresetTierScript -Tweak $tweak -Tier $PresetContext.PresetDefinition.Tier)
						$targetChecked = ($includeInPreset -and [bool]$tweak.Default)
					}

					$currentChecked = $false
					if ((Test-GuiObjectField -Object $control -FieldName 'IsChecked'))
					{
						$currentChecked = [bool]$control.IsChecked
					}
					if ($currentChecked -ne [bool]$targetChecked)
					{
						$stats.StateChangeCount++
					}
					if ((Test-GuiObjectField -Object $control -FieldName 'IsChecked'))
					{
						$control.IsChecked = $targetChecked
					}
					if ($targetChecked)
					{
						$stats.SelectedCount++
					}

					if ($tweak.LinkedWith -and $SyncLinkedStateCapture)
					{
						& $SyncLinkedStateCapture $tweak.LinkedWith $targetChecked
					}
				}
					'Choice'
					{
						$stats.ChoiceCount++
						$targetSelectedIndex = -1
						$choiceOptions = Get-GuiChoiceOptions -Options $tweak.Options
					$presetEntry = if ($PresetContext.UsesExplicitPreset -and $null -ne $PresetContext.PresetEntries[$tweak.Function]) { $PresetContext.PresetEntries[$tweak.Function] } else { $null }
					if ($PresetContext.UsesExplicitPreset)
					{
						$includeInPreset = ($null -ne $presetEntry)
						if ($includeInPreset)
						{
							$targetSelectedIndex = [array]::IndexOf($choiceOptions, [string]$presetEntry.Value)
						}
					}
					else
					{
						$includeInPreset = (& $TestTweakMatchesPresetTierScript -Tweak $tweak -Tier $PresetContext.PresetDefinition.Tier)
						if ($includeInPreset)
						{
							$targetSelectedIndex = [array]::IndexOf($choiceOptions, $tweak.Default)
						}
					}

					if ($targetSelectedIndex -ge $choiceOptions.Count)
					{
						$targetSelectedIndex = -1
					}

					$currentSelectedIndex = -1
					if ((Test-GuiObjectField -Object $control -FieldName 'SelectedIndex'))
					{
						$currentSelectedIndex = [int]$control.SelectedIndex
					}
					if ($currentSelectedIndex -ne [int]$targetSelectedIndex)
					{
						$stats.StateChangeCount++
					}
					if ((Test-GuiObjectField -Object $control -FieldName 'SelectedIndex'))
					{
						[int]$selectedIndex = $targetSelectedIndex
						$control.SelectedIndex = $selectedIndex
					}
						if ($targetSelectedIndex -ge 0)
						{
							$stats.SelectedCount++
						}
					}
					'NumericRange'
					{
						$stats.NumericRangeCount++
						$presetEntry = if ($PresetContext.UsesExplicitPreset -and $null -ne $PresetContext.PresetEntries[$tweak.Function]) { $PresetContext.PresetEntries[$tweak.Function] } else { $null }
						if ($PresetContext.UsesExplicitPreset)
						{
							$includeInPreset = ($null -ne $presetEntry)
							$targetChecked = $includeInPreset
						}
						else
						{
							$includeInPreset = (& $TestTweakMatchesPresetTierScript -Tweak $tweak -Tier $PresetContext.PresetDefinition.Tier)
							$targetChecked = [bool]$includeInPreset
						}

						$targetValueSource = if ($PresetContext.UsesExplicitPreset -and $null -ne $presetEntry)
						{
							$presetEntry
						}
						elseif (Test-GuiObjectField -Object $tweak -FieldName 'Default')
						{
							$tweak.Default
						}
						elseif (Test-GuiObjectField -Object $tweak -FieldName 'WinDefault')
						{
							$tweak.WinDefault
						}
						else
						{
							$null
						}

						$currentChecked = if ((Test-GuiObjectField -Object $control -FieldName 'IsChecked')) { [bool]$control.IsChecked } else { $false }

						$currentACValue = if ((Test-GuiObjectField -Object $control -FieldName 'ACValue')) { $control.ACValue } else { $null }
						$currentDCValue = if ((Test-GuiObjectField -Object $control -FieldName 'DCValue')) { $control.DCValue } else { $null }
						if ($null -ne $targetValueSource)
						{
							$targetACValue = Get-GuiNumericRangeChannelValue -Value $targetValueSource -Channel 'AC' -NumericRange $tweak.NumericRange
							$targetDCValue = Get-GuiNumericRangeChannelValue -Value $targetValueSource -Channel 'DC' -NumericRange $tweak.NumericRange
						}
						else
						{
							$targetACValue = $null
							$targetDCValue = $null
						}

						$currentValueText = if ($null -ne $currentACValue -or $null -ne $currentDCValue)
						{
							Format-GuiPowerSchemeValueText -Value ([pscustomobject]@{ ACValue = $currentACValue; DCValue = $currentDCValue }) -NumericRange $tweak.NumericRange
						}
						else
						{
							$null
						}
						$targetValueText = if ($null -ne $targetACValue -or $null -ne $targetDCValue)
						{
							Format-GuiPowerSchemeValueText -Value ([pscustomobject]@{
								ACValue = $targetACValue
								DCValue = $targetDCValue
							}) -NumericRange $tweak.NumericRange
						}
						else
						{
							$null
						}

						if ((Test-GuiObjectField -Object $control -FieldName 'IsRestoring'))
						{
							$control.IsRestoring = $true
						}
						try
						{
							if ((Test-GuiObjectField -Object $control -FieldName 'CheckBox') -and $control.CheckBox)
							{
								$control.CheckBox.IsChecked = [bool]$targetChecked
							}
							elseif ((Test-GuiObjectField -Object $control -FieldName 'IsChecked'))
							{
								$control.IsChecked = [bool]$targetChecked
							}

							if ((Test-GuiObjectField -Object $control -FieldName 'ACSlider') -and $control.ACSlider)
							{
								$control.ACSlider.IsEnabled = [bool]$targetChecked
								if ($null -ne $targetACValue)
								{
									$control.ACSlider.Value = [double]$targetACValue
								}
							}
							if ((Test-GuiObjectField -Object $control -FieldName 'DCSlider') -and $control.DCSlider)
							{
								$control.DCSlider.IsEnabled = [bool]$targetChecked
								if ($null -ne $targetDCValue)
								{
									$control.DCSlider.Value = [double]$targetDCValue
								}
							}

							if ((Test-GuiObjectField -Object $control -FieldName 'ACValueText') -and $control.ACValueText)
							{
								$control.ACValueText.Text = if ($null -ne $targetACValue) { (Format-GuiNumericRangeValueText -Value $targetACValue -NumericRange $tweak.NumericRange) } else { '' }
							}
							if ((Test-GuiObjectField -Object $control -FieldName 'DCValueText') -and $control.DCValueText)
							{
								$control.DCValueText.Text = if ($null -ne $targetDCValue) { (Format-GuiNumericRangeValueText -Value $targetDCValue -NumericRange $tweak.NumericRange) } else { '' }
							}
							if ((Test-GuiObjectField -Object $control -FieldName 'SummaryText') -and $control.SummaryText)
							{
								$summaryValue = if ($null -ne $targetValueText) { $targetValueText } elseif ($null -ne $currentValueText) { $currentValueText } else { 'No numeric value selected' }
								$control.SummaryText.Text = (Get-UxLocalizedString -Key 'GuiNumericRangeSelectedValue' -Fallback 'Selected values: {0}' -FormatArgs @($summaryValue))
							}

							if ((Test-GuiObjectField -Object $control -FieldName 'ACValue'))
							{
								$control.ACValue = $targetACValue
							}
							if ((Test-GuiObjectField -Object $control -FieldName 'DCValue'))
							{
								$control.DCValue = $targetDCValue
							}
							if ((Test-GuiObjectField -Object $control -FieldName 'Value'))
							{
								if ($null -ne $targetACValue -or $null -ne $targetDCValue)
								{
									$control.Value = [pscustomobject]@{
										ACValue = $targetACValue
										DCValue = $targetDCValue
									}
								}
								else
								{
									$control.Value = $null
								}
							}
							if ((Test-GuiObjectField -Object $control -FieldName 'NumericValue'))
							{
								$control.NumericValue = if ($null -ne $targetACValue -and $null -eq $targetDCValue) { $targetACValue } elseif ($null -ne $targetDCValue -and $null -eq $targetACValue) { $targetDCValue } elseif ($null -ne $targetACValue -and $null -ne $targetDCValue -and [string]$targetACValue -eq [string]$targetDCValue) { $targetACValue } else { $null }
							}
						}
						finally
						{
							if ((Test-GuiObjectField -Object $control -FieldName 'IsRestoring'))
							{
								$control.IsRestoring = $false
							}
						}

						if ($currentChecked -ne [bool]$targetChecked -or [string]$currentValueText -ne [string]$targetValueText)
						{
							$stats.StateChangeCount++
						}

						if ([bool]$targetChecked)
						{
							$stats.SelectedCount++
						}
					}
				}
			}

		if ($progressBar)
		{
			Set-SharedProgressBarState -ProgressBar $progressBar -Completed $totalCount -Total $totalCount
			[System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
		}
		if ($progressHost)
		{
			$progressHost.Visibility = [System.Windows.Visibility]::Collapsed
		}

		return [pscustomobject]$stats
	}

	<#
	    .SYNOPSIS
	    Internal function Write-TabPresetUnmatchedEntryWarnings.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Write-TabPresetUnmatchedEntryWarnings
	{
		param (
			[Parameter(Mandatory = $true)]
			[object]$PresetContext
		)

		if (-not $PresetContext.UsesExplicitPreset -or $PresetContext.UnmatchedPresetEntries.Count -eq 0)
		{
			return
		}

		foreach ($unmatchedEntry in $PresetContext.UnmatchedPresetEntries)
		{
			$warningText = "Preset '{0}' skipped line {1}: {2} [{3}]" -f `
				$PresetContext.PresetDefinition.Name, `
				$unmatchedEntry.LineNumber, `
				$unmatchedEntry.Command, `
				$unmatchedEntry.Reason
			if (Get-Command -Name 'LogWarning' -CommandType Function -ErrorAction SilentlyContinue)
			{
				LogWarning $warningText
			}
			else
			{
				Write-Warning $warningText
			}
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Ensure-SafePresetRestorePointSelection.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Ensure-SafePresetRestorePointSelection
	{
		param (
			[Parameter(Mandatory = $true)]
			[object]$PresetContext,
			[Parameter(Mandatory = $true)]
			[object]$PresetStats
		)

		$presetName = if ($PresetContext -and (Test-GuiObjectField -Object $PresetContext -FieldName 'PresetDefinition') -and $PresetContext.PresetDefinition -and $PresetContext.PresetDefinition.PSObject.Properties['Name'])
		{
			[string]$PresetContext.PresetDefinition.Name
		}
		else
		{
			$null
		}

		if ($presetName -ne 'Minimal' -and $presetName -ne 'Basic')
		{
			return $PresetStats
		}

		for ($index = 0; $index -lt $Script:TweakManifest.Count; $index++)
		{
			$tweak = $Script:TweakManifest[$index]
			if (-not $tweak -or [string]$tweak.Function -ne 'CreateRestorePoint' -or [string]$tweak.Type -ne 'Action')
			{
				continue
			}

			$control = $Script:Controls[$index]
			if (-not $control -or -not (Test-GuiObjectField -Object $control -FieldName 'IsChecked'))
			{
				break
			}

			if ((Test-GuiObjectField -Object $control -FieldName 'IsEnabled') -and -not [bool]$control.IsEnabled)
			{
				break
			}

			if (-not [bool]$control.IsChecked)
			{
				$control.IsChecked = $true
				$PresetStats.StateChangeCount = [int]$PresetStats.StateChangeCount + 1
				$PresetStats.SelectedCount = [int]$PresetStats.SelectedCount + 1
			}

			Set-GuiExplicitSelectionDefinition -FunctionName 'CreateRestorePoint' -Definition ([pscustomobject]@{
				Function = 'CreateRestorePoint'
				Type = 'Action'
				Run = $true
				Source = 'Preset'
			})

			break
		}

		return $PresetStats
	}

	<#
	    .SYNOPSIS
	    Internal function Complete-TabPresetApplication.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Complete-TabPresetApplication
	{
		param (
			[string]$PrimaryTab,
			[Parameter(Mandatory = $true)]
			[object]$PresetContext,
			[Parameter(Mandatory = $true)]
			[object]$PresetStats,
			[scriptblock]$WriteGuiPresetDebugScript
		)

		$skippedEntrySuffix = if ($PresetContext.UsesExplicitPreset -and $PresetContext.UnmatchedPresetEntries.Count -gt 0)
		{
			" - $($PresetContext.UnmatchedPresetEntries.Count) preset entr$(if ($PresetContext.UnmatchedPresetEntries.Count -eq 1) { 'y' } else { 'ies' }) skipped; see log."
		}
		else
		{
			''
		}

		$restoreGuidance = if ($PresetContext.PresetDefinition.PSObject.Properties['RestoreGuidance'] -and -not [string]::IsNullOrWhiteSpace([string]$PresetContext.PresetDefinition.RestoreGuidance))
		{
			[string]$PresetContext.PresetDefinition.RestoreGuidance
		}
		else
		{
			switch ($PresetContext.PresetDefinition.Name)
			{
				'Balanced' { 'Restore point recommended before continuing.'; break }
				'Advanced' { 'Restore point recommended before continuing. Advanced is the expert preset.'; break }
				default    { $null }
			}
		}

		$statusMessagePrefix = if ($PresetContext.PresetDefinition.PSObject.Properties['StatusMessagePrefix'] -and -not [string]::IsNullOrWhiteSpace([string]$PresetContext.PresetDefinition.StatusMessagePrefix))
		{
			[string]$PresetContext.PresetDefinition.StatusMessagePrefix
		}
		else
		{
			'Preset applied'
		}

		$Script:PresetStatusMessage = "{0}: {1} ({2} tweaks selected){3}" -f $statusMessagePrefix, $PresetContext.PresetDefinition.Name, $PresetStats.SelectedCount, $skippedEntrySuffix
		if (-not [string]::IsNullOrWhiteSpace([string]$restoreGuidance))
		{
			$Script:PresetStatusMessage += " $restoreGuidance"
		}
		if ($Script:PresetStatusBadge -and $Script:PresetStatusBadge.Child -is [System.Windows.Controls.TextBlock])
		{
			$Script:PresetStatusBadge.Child.Text = $Script:PresetStatusMessage
		}

		$statusHasCaution = (($PresetContext.UsesExplicitPreset -and $PresetContext.UnmatchedPresetEntries.Count -gt 0) -or (-not [string]::IsNullOrWhiteSpace([string]$restoreGuidance)))
		# Always update the bottom status bar so switching presets clears the
		# previous preset's message (e.g. Advanced caution) instead of leaving
		# stale text visible.
		Set-GuiStatusText -Text $Script:PresetStatusMessage -Tone $(if ($statusHasCaution) { 'caution' } else { 'accent' })

		if ($WriteGuiPresetDebugScript)
		{
			& $WriteGuiPresetDebugScript -Context 'Set-TabPreset' -Message ("Status updated for preset '{0}': selected={1}, processed={2}, visible={3}, hidden={4}, missingControls={5}, toggles={6}, choices={7}, actions={8}, stateChanges={9}." -f $PresetContext.PresetDefinition.Name, $PresetStats.SelectedCount, $PresetStats.ProcessedCount, $PresetStats.VisibleCount, $PresetStats.HiddenCount, $PresetStats.ControlMissingCount, $PresetStats.ToggleCount, $PresetStats.ChoiceCount, $PresetStats.ActionCount, $PresetStats.StateChangeCount)
			& $WriteGuiPresetDebugScript -Context 'Set-TabPreset' -Message ("Updating primary tab visuals after preset '{0}'." -f $PresetContext.PresetDefinition.Name)
		}

		# Store the active selection so New-TabPresetButtonsPanel / New-ScenarioProfileButtonsPanel
		# can apply the highlight when buttons are (re)created during tab rebuilds.
		# Scenarios accumulate (multiple can be active); presets are mutually exclusive.
		if ([string]$PresetContext.PresetDefinition.ModeKind -eq 'Scenario')
		{
			if (-not ($Script:ActiveScenarioNames -is [hashtable])) { $Script:ActiveScenarioNames = @{} }
			$Script:ActiveScenarioNames[[string]$PresetContext.PresetDefinition.Name] = $true
			$Script:ActivePresetName = $null
		}
		else
		{
			$Script:ActivePresetName = [string]$PresetContext.PresetDefinition.Name
			$Script:ActiveScenarioNames = @{}
		}

		# Track the active preset in session statistics
		Update-SessionStatistics -Values @{ PresetName = [string]$PresetContext.PresetDefinition.Name }

		Update-PrimaryTabVisuals
		Update-CurrentTabContent
		if (Get-Command -Name 'Sync-ActivePresetButtonChrome' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Sync-ActivePresetButtonChrome
		}
		Update-RunPathContextLabel

		if ($WriteGuiPresetDebugScript)
		{
			& $WriteGuiPresetDebugScript -Context 'Set-TabPreset' -Message ("Completed preset apply for '{0}' on tab '{1}'." -f $PresetContext.PresetDefinition.Name, $PrimaryTab)
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-TabPreset.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Set-TabPreset
	{
		param (
			[string]$PrimaryTab,
			[string]$PresetTier,
			[object]$SelectionDefinition = $null
		)

		$writeGuiPresetDebugScript = Get-GuiPresetDebugLogger
		if ($writeGuiPresetDebugScript)
		{
			& $writeGuiPresetDebugScript -Context 'Set-TabPreset' -Message ("Begin preset apply: tab='{0}', requestedPreset='{1}'." -f $(if ($PrimaryTab) { $PrimaryTab } else { '<none>' }), $(if ($PresetTier) { $PresetTier } else { '<none>' }))
		}

		if ([string]::IsNullOrWhiteSpace($PrimaryTab) -or $PrimaryTab -eq $Script:SearchResultsTabTag)
		{
			if ($writeGuiPresetDebugScript)
			{
				& $writeGuiPresetDebugScript -Context 'Set-TabPreset' -Message ("Ignoring preset '{0}' because the primary tab is empty or search results are selected." -f $PresetTier)
			}
			return
		}

		$saveGuiUndoSnapshotScript = ${function:Save-GuiUndoSnapshot}
		$setSafeModeStateScript = ${function:Set-SafeModeState}
		$setAdvancedModeStateScript = ${function:Set-AdvancedModeState}
		$updateCategoryFilterListScript = ${function:Update-CategoryFilterList}
		$setFilterSelectionsScript = ${function:Set-FilterSelections}
		$testTweakMatchesPresetTierScript = ${function:Test-TweakMatchesPresetTier}
		$syncLinkedStateCapture = $syncLinkedState

		$presetContext = Resolve-TabPresetContext -PrimaryTab $PrimaryTab -PresetTier $PresetTier -SelectionDefinition $SelectionDefinition -WriteGuiPresetDebugScript $writeGuiPresetDebugScript
		Initialize-TabPresetApplicationState -PresetContext $presetContext -SaveGuiUndoSnapshotScript $saveGuiUndoSnapshotScript -WriteGuiPresetDebugScript $writeGuiPresetDebugScript

		$previousApplyingGuiPreset = $Script:ApplyingGuiPreset
		$Script:ApplyingGuiPreset = $presetContext.UsesExplicitPreset
		try
		{
			Set-TabPresetSharedUiState -PrimaryTab $PrimaryTab -PresetContext $presetContext -SetSafeModeStateScript $setSafeModeStateScript -SetAdvancedModeStateScript $setAdvancedModeStateScript -UpdateCategoryFilterListScript $updateCategoryFilterListScript -SetFilterSelectionsScript $setFilterSelectionsScript -WriteGuiPresetDebugScript $writeGuiPresetDebugScript
			$presetStats = Apply-TabPresetSelections -PresetContext $presetContext -TestTweakMatchesPresetTierScript $testTweakMatchesPresetTierScript -SyncLinkedStateCapture $syncLinkedStateCapture
			$presetStats = Ensure-SafePresetRestorePointSelection -PresetContext $presetContext -PresetStats $presetStats
			Write-TabPresetUnmatchedEntryWarnings -PresetContext $presetContext
			Complete-TabPresetApplication -PrimaryTab $PrimaryTab -PresetContext $presetContext -PresetStats $presetStats -WriteGuiPresetDebugScript $writeGuiPresetDebugScript
		}
		finally
		{
			if ($Script:PresetProgressBar)
			{
				Set-SharedProgressBarState -ProgressBar $Script:PresetProgressBar -Completed 0 -Total 1
			}
			if ($Script:PresetProgressHost)
			{
				$Script:PresetProgressHost.Visibility = [System.Windows.Visibility]::Collapsed
			}
			$Script:ApplyingGuiPreset = $previousApplyingGuiPreset
		}
	}
