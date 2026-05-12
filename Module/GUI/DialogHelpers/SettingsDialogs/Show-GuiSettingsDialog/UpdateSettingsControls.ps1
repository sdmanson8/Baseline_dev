# P5 rollback checkpoint: extracted from Show-GuiSettingsDialog in Module\GUI\DialogHelpers\SettingsDialogs.ps1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
if ($cmbUpdateFrequency)
		{
			& $addComboItem $cmbUpdateFrequency $settingsOptionUpdateStartup 'Startup'
			& $addComboItem $cmbUpdateFrequency $settingsOptionUpdateDaily 'Daily'
			& $addComboItem $cmbUpdateFrequency $settingsOptionUpdateWeekly 'Weekly'
			$selectedUpdateFrequency = if ($Current.ContainsKey('UpdateCheckFrequency') -and -not [string]::IsNullOrWhiteSpace([string]$Current.UpdateCheckFrequency)) { [string]$Current.UpdateCheckFrequency } else { 'Startup' }
			if (Get-Command -Name 'ConvertTo-BaselineUpdateCheckFrequency' -CommandType Function -ErrorAction SilentlyContinue)
			{
				$selectedUpdateFrequency = ConvertTo-BaselineUpdateCheckFrequency -Frequency $selectedUpdateFrequency
			}
			& $selectComboByTag $cmbUpdateFrequency $selectedUpdateFrequency
		}

		if ($cmbUpdateBranch)
		{
			& $addComboItem $cmbUpdateBranch $settingsOptionUpdateBranchStable 'Stable'
			& $addComboItem $cmbUpdateBranch $settingsOptionUpdateBranchBeta 'Beta'
			$defaultUpdateBranch = if (Get-Command -Name 'Get-BaselineDefaultUpdateBranch' -CommandType Function -ErrorAction SilentlyContinue) { Get-BaselineDefaultUpdateBranch } else { 'Stable' }
			$selectedUpdateBranch = $defaultUpdateBranch
			if (Get-Command -Name 'ConvertTo-BaselineUpdateBranch' -CommandType Function -ErrorAction SilentlyContinue)
			{
				$selectedUpdateBranch = ConvertTo-BaselineUpdateBranch -Branch $selectedUpdateBranch
			}
			& $selectComboByTag $cmbUpdateBranch $selectedUpdateBranch
		}
