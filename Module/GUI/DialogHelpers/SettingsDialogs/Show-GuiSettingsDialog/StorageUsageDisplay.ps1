# P5 rollback checkpoint: extracted from Show-GuiSettingsDialog in Module\GUI\DialogHelpers\SettingsDialogs.ps1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
$refreshStorageDisplay = {
			$usage = & $getGuiBaselineStorageUsage
			if ($txtStorageUsage)
			{
				$usageText = if ($usage)
				{
					@(
						$settingsStorageUsageHeader
						''
						('- {0}' -f ($settingsStorageUsageAppData -f (& $formatGuiStorageSize -Bytes ([Int64]$usage.AppDataBytes))))
						('- {0}' -f ($settingsStorageUsageTemp -f (& $formatGuiStorageSize -Bytes ([Int64]$usage.TempBytes))))
						('- {0}' -f ($settingsStorageUsageTotal -f (& $formatGuiStorageSize -Bytes ([Int64]$usage.TotalBytes))))
					) -join [Environment]::NewLine
				}
				else
				{
					$settingsStorageUnavailable
				}
				$txtStorageUsage.Text = $usageText
			}
			if ($txtStorageLocation)
			{
				$locationText = if ($usage)
				{
					@(
						$settingsStorageLocationHeader
						(& $formatGuiBaselineStorageLocation -Path ([string]$usage.AppDataRoot))
						(& $formatGuiBaselineStorageLocation -Path ([string]$usage.TempRoot))
					) -join [Environment]::NewLine
				}
				else
				{
					$settingsStorageUnavailable
				}
				$txtStorageLocation.Text = $locationText
			}
		}.GetNewClosure()
