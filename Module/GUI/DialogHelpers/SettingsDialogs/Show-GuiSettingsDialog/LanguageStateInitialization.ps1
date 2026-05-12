# P5 rollback checkpoint: extracted from Show-GuiSettingsDialog in Module\GUI\DialogHelpers\SettingsDialogs.ps1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
$settingsLanguageState = @{
			Code = if ($Current.ContainsKey('Language') -and -not [string]::IsNullOrWhiteSpace([string]$Current.Language))
			{
				[string]$Current.Language
			}
			elseif ($Script:SelectedLanguage)
			{
				[string]$Script:SelectedLanguage
			}
			else
			{
				'en'
			}
		}
