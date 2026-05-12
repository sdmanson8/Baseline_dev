# P5 rollback checkpoint: extracted from Show-GuiSettingsDialog in Module\GUI\DialogHelpers\SettingsDialogs.ps1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
$getUpdateStatusDisplay = {
			param ([string]$Status)
			switch ([string]$Status)
			{
				'Up to date' { return $settingsUpdateStatusUpToDate }
				'Update available' { return $settingsUpdateStatusAvailable }
				'Failed' { return $settingsUpdateStatusFailed }
				'Skipped (offline)' { return $settingsUpdateStatusOffline }
				'Disabled' { return $settingsUpdateStatusDisabled }
				default { return $settingsUpdateStatusNotChecked }
			}
		}.GetNewClosure()
