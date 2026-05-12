# P5 rollback checkpoint: extracted from Show-GuiSettingsDialog in Module\GUI\DialogHelpers\SettingsDialogs.ps1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
$applySettingsSystemBrushes = {
			param ($control)
			if (-not $control) { return }
			$control.Resources[[System.Windows.SystemColors]::WindowBrushKey] = $settingsInputBgBrush
			$control.Resources[[System.Windows.SystemColors]::WindowTextBrushKey] = $settingsTextPrimaryBrush
			$control.Resources[[System.Windows.SystemColors]::ControlBrushKey] = $settingsInputBgBrush
			$control.Resources[[System.Windows.SystemColors]::ControlTextBrushKey] = $settingsTextPrimaryBrush
			$control.Resources[[System.Windows.SystemColors]::HighlightBrushKey] = $settingsSelectionBrush
			$control.Resources[[System.Windows.SystemColors]::HighlightTextBrushKey] = $settingsTextPrimaryBrush
			$control.Resources[[System.Windows.SystemColors]::MenuBrushKey] = $settingsInputBgBrush
			$control.Resources[[System.Windows.SystemColors]::MenuTextBrushKey] = $settingsTextPrimaryBrush
		}.GetNewClosure()
