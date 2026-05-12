# P5 rollback checkpoint: extracted from Show-GuiSettingsDialog in Module\GUI\DialogHelpers\SettingsDialogs.ps1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
$applySettingsInputTheme = {
			param ($control)
			if (-not $control) { return }
			try
			{
				& $applySettingsSystemBrushes $control
				$control.Background = $settingsInputBgBrush
				$control.Foreground = $settingsTextPrimaryBrush
				$control.BorderBrush = $settingsInputBorderBrush
				$control.Opacity = 1

				if ($control -is [System.Windows.Controls.TextBox])
				{
					$control.CaretBrush = $settingsTextPrimaryBrush
					$control.SelectionBrush = $settingsSelectionBrush
				}
				elseif ($control -is [System.Windows.Controls.ComboBox])
				{
					$control.OverridesDefaultStyle = $true
					$control.Opacity = 1
					$control.SetValue([System.Windows.Documents.TextElement]::ForegroundProperty, $settingsTextPrimaryBrush)
					foreach ($item in @($control.Items)) { & $applySettingsComboItemTheme $item }
				}
			}
			catch
			{
				Write-SwallowedException -ErrorRecord $_ -Source 'DialogHelpers.ShowGuiSettingsDialog.ApplyInputTheme'
			}
		}.GetNewClosure()
