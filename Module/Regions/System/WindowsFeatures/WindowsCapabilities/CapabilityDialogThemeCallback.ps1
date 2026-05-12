# P5 rollback checkpoint: extracted from WindowsCapabilities in Module\Regions\System\System.WindowsFeatures.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
$windowsCapabilitiesThemeCallback = {
		param($Window, $Theme, $UseDarkMode)

		if ($Button)
		{
			try { GUICommon\Set-GuiPopupActionButtonStyle -Button $Button -Theme $Theme -UseDarkMode $UseDarkMode } catch { Write-SwallowedException -ErrorRecord $_ -Source 'WindowsCapabilities.ThemeCallback.SetPopupActionButtonStyle' }
		}

		if ($TextBlockSelectAll -and $Window.Foreground)
		{
			$TextBlockSelectAll.Foreground = $Window.Foreground
		}
	}.GetNewClosure()
