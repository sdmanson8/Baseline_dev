# P5 rollback checkpoint: extracted from Show-GuiSettingsDialog in Module\GUI\DialogHelpers\SettingsDialogs.ps1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
if ($cmbUIDensity)
		{
			& $addComboItem $cmbUIDensity $settingsOptionDensityComfort 'Comfort'
			& $addComboItem $cmbUIDensity $settingsOptionDensityCompact 'Compact'
			& $addComboItem $cmbUIDensity $settingsOptionDensityHigh 'High Density'
			$selectedDensity = if ($Current.ContainsKey('UIDensity') -and -not [string]::IsNullOrWhiteSpace([string]$Current.UIDensity)) { [string]$Current.UIDensity } else { 'Comfort' }
			if (Get-Command -Name 'Normalize-BaselineUiDensity' -CommandType Function -ErrorAction SilentlyContinue)
			{
				$selectedDensity = Normalize-BaselineUiDensity -Density $selectedDensity
			}
			& $selectComboByTag $cmbUIDensity $selectedDensity
		}
