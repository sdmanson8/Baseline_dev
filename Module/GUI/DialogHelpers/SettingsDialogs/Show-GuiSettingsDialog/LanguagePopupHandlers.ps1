# P5 rollback checkpoint: extracted from Show-GuiSettingsDialog in Module\GUI\DialogHelpers\SettingsDialogs.ps1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
if ($settingsLanguagePopup)
		{
			$settingsLanguagePopup.Add_Opened({
				param ($popupSender, $popupArgs)
				$null = $popupSender
				$null = $popupArgs
				if ($txtSettingsLanguageSearch)
				{
					$txtSettingsLanguageSearch.Text = ''
					[void]$txtSettingsLanguageSearch.Focus()
				}
				if ($languageUiState.Render) { & $languageUiState.Render '' }
			}.GetNewClosure())
		}
