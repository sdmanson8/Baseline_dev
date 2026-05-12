# P5 rollback checkpoint: extracted from Show-GuiSettingsDialog in Module\GUI\DialogHelpers\SettingsDialogs.ps1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
$refreshLogFolderDisplay = {
			$expertEnabled = $chkAdvancedMode -and [bool]$chkAdvancedMode.IsChecked
			$effectiveDirectory = & $getEffectiveLogDirectory
			if ($txtLogFolderPath) { $txtLogFolderPath.Text = $effectiveDirectory }
			if ($btnLogFolderBrowse)
			{
				$btnLogFolderBrowse.Visibility = if ($expertEnabled) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
			}
			if ($txtLogFolderHelper)
			{
				$txtLogFolderHelper.Text = if ($expertEnabled)
				{
					$settingsLogFolderExpertHelper
				}
				else
				{
					$settingsLogFolderEnableExpertHelper
				}
			}
		}.GetNewClosure()
