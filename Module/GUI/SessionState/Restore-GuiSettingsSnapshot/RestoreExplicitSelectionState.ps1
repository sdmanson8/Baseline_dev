# P5 rollback checkpoint: extracted from Restore-GuiSettingsSnapshot in Module\GUI\SessionState.ps1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
if ((Test-GuiObjectField -Object $Snapshot -FieldName 'ExplicitSelectionDefinitions') -and $null -ne $Snapshot.ExplicitSelectionDefinitions)
		{
			foreach ($selectionDefinition in @($Snapshot.ExplicitSelectionDefinitions))
			{
				$functionName = if ($selectionDefinition -and (Test-GuiObjectField -Object $selectionDefinition -FieldName 'Function')) { [string]$selectionDefinition.Function } else { $null }
				if (-not [string]::IsNullOrWhiteSpace($functionName))
				{
					Set-GuiExplicitSelectionDefinition -FunctionName $functionName -Definition $selectionDefinition
				}
			}
		}
		elseif ((Test-GuiObjectField -Object $Snapshot -FieldName 'ExplicitSelections'))
		{
			foreach ($functionName in @($Snapshot.ExplicitSelections))
			{
				if (-not [string]::IsNullOrWhiteSpace([string]$functionName))
				{
					[void]$Script:ExplicitPresetSelections.Add([string]$functionName)
				}
			}
		}

		for ($i = 0; $i -lt $Script:TweakManifest.Count; $i++)
		{
			$manifest = $Script:TweakManifest[$i]
			$control = $Script:Controls[$i]
			if (-not $control) { continue }

			$state = $controlStates[$manifest.Function]
			if (-not $state) { continue }

			switch ($manifest.Type)
			{
				'Date'
				{
					$isChecked = if ((Test-GuiObjectField -Object $state -FieldName 'IsChecked')) { [bool]$state.IsChecked } else { $false }
					$selectedDate = $null
					if ((Test-GuiObjectField -Object $state -FieldName 'SelectedDate') -and -not [string]::IsNullOrWhiteSpace([string]$state.SelectedDate))
					{
						$parsedDate = [datetime]::MinValue
						if (-not [datetime]::TryParseExact([string]$state.SelectedDate, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate))
						{
							throw "Invalid GUI session date value for '$([string]$manifest.Function)': '$([string]$state.SelectedDate)'."
						}
						$selectedDate = $parsedDate
					}

					if ((Test-GuiObjectField -Object $control -FieldName 'IsRestoring'))
					{
						$control.IsRestoring = $true
					}
					if ((Test-GuiObjectField -Object $control -FieldName 'CheckBox') -and $control.CheckBox)
					{
						$control.CheckBox.IsChecked = [bool]$isChecked
					}
					elseif ((Test-GuiObjectField -Object $control -FieldName 'IsChecked'))
					{
						$control.IsChecked = [bool]$isChecked
					}
					if ((Test-GuiObjectField -Object $control -FieldName 'DatePicker') -and $control.DatePicker)
					{
						$control.DatePicker.SelectedDate = $selectedDate
					}
					if ((Test-GuiObjectField -Object $control -FieldName 'SelectedDate'))
					{
						$control.SelectedDate = $selectedDate
					}
					if ((Test-GuiObjectField -Object $control -FieldName 'IsRestoring'))
					{
						$control.IsRestoring = $false
					}
				}
				'Choice'
				{
					if ((Test-GuiObjectField -Object $control -FieldName 'SelectedIndex'))
					{
						$selectedIndex = -1
						if ($manifest.Options -and (Test-GuiObjectField -Object $state -FieldName 'SelectedValue') -and -not [string]::IsNullOrWhiteSpace([string]$state.SelectedValue))
						{
							$selectedIndex = [array]::IndexOf(@($manifest.Options), [string]$state.SelectedValue)
						}
						if ($selectedIndex -lt 0 -and (Test-GuiObjectField -Object $state -FieldName 'SelectedIndex'))
						{
							$selectedIndex = [int]$state.SelectedIndex
						}
						$optCount = if ($manifest.Options) { $manifest.Options.Count } else { 0 }
						if ($selectedIndex -ge $optCount) { $selectedIndex = -1 }
						[int]$idx = $selectedIndex
						$control.SelectedIndex = $idx
					}
				}
				default
				{
					if ((Test-GuiObjectField -Object $control -FieldName 'IsChecked'))
					{
						$control.IsChecked = [bool]$state.IsChecked
					}
				}
			}
		}
