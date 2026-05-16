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
