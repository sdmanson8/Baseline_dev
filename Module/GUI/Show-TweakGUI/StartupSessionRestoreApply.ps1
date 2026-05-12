# P5 rollback checkpoint: extracted from Show-TweakGUI in Module\Regions\GUI.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
if ($shouldRestoreLastSession -and $Script:StartupSessionSnapshot)
	{
		$restoreGuiSessionStateScript = Get-GuiFunctionCapture -Name 'Restore-GuiSessionState'
		$setGuiStatusTextScript = Get-GuiFunctionCapture -Name 'Set-GuiStatusText'
		$restoredSessionAction = {
			try
			{
				$restoredGuiSession = & $restoreGuiSessionStateScript -Snapshot $Script:StartupSessionSnapshot
				if ($restoredGuiSession)
				{
					if ($setGuiStatusTextScript) { & $setGuiStatusTextScript -Text $restoredSessionStatusText -Tone 'accent' }
				}
			}
			catch
			{
				Write-SwallowedException -ErrorRecord $_ -Source 'Regions.GUI.RestoreStartupSession'
			}
		}.GetNewClosure()
		& $restoredSessionAction
	}
