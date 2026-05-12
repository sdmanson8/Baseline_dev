# ActionHandlers split file loaded by Module\GUI\ActionHandlers.ps1.

	#region System scan state
	$buildTabContentCommand = Get-GuiRuntimeCommand -Name 'Build-TabContent' -CommandType 'Function'
	$hasField = {
		param (
			[object]$Object,
			[string]$FieldName
		)

		if ($null -eq $Object)
		{
			return $false
		}

		if ($Object -is [System.Collections.IDictionary])
		{
			return $Object.Contains($FieldName)
		}

		return ($null -ne $Object.PSObject.Properties[$FieldName])
	}.GetNewClosure()
	Register-GuiEventHandler -Source $ChkScan -EventName 'Unchecked' -Handler ({
		if ($Script:FilterUiUpdating -or $Script:RunInProgress) { return }
		$Script:ScanEnabled = $false
		foreach ($si in $Script:Controls.Keys)
		{
			$sctl = $Script:Controls[$si]
			if ($sctl) { $sctl.IsEnabled = $true }
		}
		& $setGuiStatusTextCommand -Text '' -Tone 'muted'
		if ($Script:CurrentPrimaryTab) { & $buildTabContentCommand -PrimaryTab $Script:CurrentPrimaryTab }
	}) | Out-Null
	#endregion

	# Style buttons directly
	$bc = [System.Windows.Media.BrushConverter]::new()

	<#
	    .SYNOPSIS
	#>

	function Sync-UxActionButtonText
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		if ($Script:AppsModeActive -or $Script:UpdatesModeActive -or $Script:DeploymentMediaModeActive)
		{
			if ($Script:BtnRun) { $Script:BtnRun.Visibility = [System.Windows.Visibility]::Collapsed }
			if ($Script:BtnPreviewRun) { $Script:BtnPreviewRun.Visibility = [System.Windows.Visibility]::Collapsed }
			if ($Script:BtnDefaults) { $Script:BtnDefaults.Visibility = [System.Windows.Visibility]::Collapsed }
			return
		}

		if ($Script:BtnRun)
		{
			$Script:BtnRun.Visibility = [System.Windows.Visibility]::Visible
		}
		if ($Script:BtnRun -and -not (& $Script:TestGuiRunInProgressScript))
		{
			Set-GuiButtonIconContent -Button $Script:BtnRun -IconName 'RunTweaks' -Text (Get-UxRunActionLabel) -ToolTip (Get-UxRunActionToolTip)
		}

		if ($Script:BtnRestoreSnapshot)
		{
			$Script:BtnRestoreSnapshot.Content = Get-UxUndoSelectionActionLabel
			$Script:BtnRestoreSnapshot.ToolTip = if (Test-IsSafeModeUX) {
				Get-UxLocalizedString -Key 'GuiActionUndoSelectionTooltipSafe' -Fallback 'Undo the last preset or imported selection change by restoring the previous GUI snapshot.'
			}
			else {
				Get-UxLocalizedString -Key 'GuiActionUndoSelectionTooltip' -Fallback 'Restore the last captured UI snapshot before an import or preset change.'
			}
		}

		if ($Script:BtnPreviewRun)
		{
			$Script:BtnPreviewRun.Visibility = [System.Windows.Visibility]::Visible
			Set-GuiButtonIconContent -Button $Script:BtnPreviewRun -IconName 'PreviewRun' -Text (Get-UxPreviewButtonLabel) -ToolTip (Get-UxPreviewButtonToolTip)
		}

		if ($Script:BtnStartHere)
		{
			Set-GuiButtonIconContent -Button $Script:BtnStartHere -IconName 'QuickStart' -Text (Get-UxStartGuideButtonLabel) -ToolTip (Get-UxLocalizedString -Key 'GuiActionStartGuideTooltip' -Fallback 'Open the getting started guide.')
		}

		if ($Script:BtnHelp)
		{
			Set-GuiButtonIconContent -Button $Script:BtnHelp -IconName 'Help' -Text (Get-UxHelpButtonLabel) -ToolTip (Get-UxLocalizedString -Key 'GuiActionOpenHelpTooltip' -Fallback 'Open help and usage guidance.')
		}

		if ($Script:BtnDefaults)
		{
			$Script:BtnDefaults.Visibility = [System.Windows.Visibility]::Visible
		}

		Update-RunPathContextLabel
	}

	<#
	    .SYNOPSIS
	#>

	function Update-RunPathContextLabel
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		if (-not $Script:RunPathContextLabel) { return }

		$pathContext = Get-UxRunPathContext
		$labelText = switch ($pathContext.Path)
		{
			'Preset'          { "Preset: $($pathContext.Label)" }
			'Troubleshooting' { 'Troubleshooting' }
			'GameMode'        { $pathContext.Label }
			default           { $pathContext.Label }
		}

		$Script:RunPathContextLabel.Text = $labelText
		$Script:RunPathContextLabel.Visibility = [System.Windows.Visibility]::Visible

		if ($Script:SharedBrushConverter)
		{
			$toneColor = Get-GuiStatusToneColor -Tone $pathContext.Tone
			if ($toneColor)
			{
				try
				{
					$Script:RunPathContextLabel.Foreground = $Script:SharedBrushConverter.ConvertFromString([string]$toneColor)
				}
				catch
				{
					if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
					{
						Write-SwallowedException -ErrorRecord $_ -Source 'ActionHandlers.UpdateRunPathContextLabel.Foreground'
					}
				}
			}
		}
	}

	# Settings profile buttons live alongside the defaults action so users can
	# export, import, and roll back the current GUI state.
	$secondaryActionGroup = New-Object System.Windows.Controls.Border
	$secondaryActionGroup.Margin = [System.Windows.Thickness]::new(4, 8, 4, 0)
	$secondaryActionGroup.Padding = [System.Windows.Thickness]::new(6, 4, 6, 4)
	$secondaryActionGroup.CornerRadius = [System.Windows.CornerRadius]::new(8)
	$secondaryActionGroup.BorderThickness = [System.Windows.Thickness]::new(1)
	$secondaryActionGroup.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
	$secondaryActionGroup.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
	$secondaryActionBar = New-Object System.Windows.Controls.WrapPanel
	$secondaryActionBar.Orientation = 'Horizontal'
	$secondaryActionGroup.Child = $secondaryActionBar
	$Script:SecondaryActionGroupBorder = $secondaryActionGroup
	$setSecondaryActionGroupMaxWidth = {
		if (-not $ActionButtonBar -or -not $secondaryActionGroup) { return }
		$availableWidth = [double]$ActionButtonBar.ActualWidth
		if ($availableWidth -gt 0)
		{
			$secondaryActionGroup.MaxWidth = [Math]::Max(0, $availableWidth - 12)
		}
	}.GetNewClosure()
	& $setSecondaryActionGroupMaxWidth
	Register-GuiEventHandler -Source $ActionButtonBar -EventName 'SizeChanged' -Handler ({
		& $setSecondaryActionGroupMaxWidth
	}.GetNewClosure()) | Out-Null
	[void]($ActionButtonBar.Children.Add($secondaryActionGroup))
	$BtnExportSettings = New-PresetButton -Label (Get-UxLocalizedString -Key 'GuiFooterExportSettings' -Fallback 'Export Settings') -Variant 'Subtle' -Compact -Muted
	$BtnExportSettings.FontSize = $Script:GuiLayout.FontSizeSmall
	$BtnExportSettings.ToolTip = (Get-UxLocalizedString -Key 'GuiActionExportSettingsTooltip' -Fallback 'Export the current GUI selections to a JSON profile.')
	[void]($secondaryActionBar.Children.Add($BtnExportSettings))
	$Script:BtnExportSettings = $BtnExportSettings
	$BtnImportSettings = New-PresetButton -Label (Get-UxLocalizedString -Key 'GuiFooterImportSettings' -Fallback 'Import Settings') -Variant 'Subtle' -Compact -Muted
	$BtnImportSettings.FontSize = $Script:GuiLayout.FontSizeSmall
	$BtnImportSettings.ToolTip = (Get-UxLocalizedString -Key 'GuiActionImportSettingsTooltip' -Fallback 'Import a saved JSON profile and restore the selected GUI state.')
	[void]($secondaryActionBar.Children.Add($BtnImportSettings))
	$Script:BtnImportSettings = $BtnImportSettings
	$BtnRestoreSnapshot = New-PresetButton -Label (Get-UxUndoSelectionActionLabel) -Variant 'Secondary' -Compact
	$BtnRestoreSnapshot.FontSize = $Script:GuiLayout.FontSizeSmall
	$BtnRestoreSnapshot.ToolTip = (Get-UxLocalizedString -Key 'GuiActionUndoSelectionTooltip' -Fallback 'Restore the last captured UI snapshot before an import or preset change.')
	[void]($secondaryActionBar.Children.Add($BtnRestoreSnapshot))
	$Script:BtnRestoreSnapshot = $BtnRestoreSnapshot
	$exportGuiSettingsProfileCommand = Get-GuiRuntimeCommand -Name 'Export-GuiSettingsProfile' -CommandType 'Function'
	$importGuiSettingsProfileCommand = Get-GuiRuntimeCommand -Name 'Import-GuiSettingsProfile' -CommandType 'Function'
	$restoreGuiSnapshotCommand = Get-GuiRuntimeCommand -Name 'Restore-GuiSnapshot' -CommandType 'Function'
	$setGuiStatusTextCommand = Get-GuiRuntimeCommand -Name 'Set-GuiStatusText' -CommandType 'Function'
	$testIsSafeModeUxCommand = Get-GuiRuntimeCommand -Name 'Test-IsSafeModeUX' -CommandType 'Function'
	$getUxUndoSelectionActionLabelCommand = Get-GuiRuntimeCommand -Name 'Get-UxUndoSelectionActionLabel' -CommandType 'Function'
	Register-GuiEventHandler -Source $BtnExportSettings -EventName 'Click' -Handler ({
		$null = & $exportGuiSettingsProfileCommand
	}) | Out-Null

	Register-GuiEventHandler -Source $BtnImportSettings -EventName 'Click' -Handler ({
		$null = & $importGuiSettingsProfileCommand
	}) | Out-Null

	Register-GuiEventHandler -Source $BtnRestoreSnapshot -EventName 'Click' -Handler ({
		try
		{
			if (-not (& $restoreGuiSnapshotCommand))
			{
				[void](Show-ThemedDialog -Title (& $getUxUndoSelectionActionLabelCommand) -Message $(if (& $testIsSafeModeUxCommand) { & $getUxLocalizedStringCapture -Key 'GuiActionUndoNoSnapshotSafe' -Fallback 'No preset or imported selection change is available to undo yet.' } else { & $getUxLocalizedStringCapture -Key 'GuiActionUndoNoSnapshot' -Fallback 'No previous GUI snapshot has been captured yet.' }) -Buttons @('OK') -AccentButton 'OK')
				return
			}
		}
		catch
		{
			LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to restore GUI snapshot')
			[void](Show-ThemedDialog -Title (& $getUxUndoSelectionActionLabelCommand) -Message $(if (& $testIsSafeModeUxCommand) { (& $getUxLocalizedStringCapture -Key 'GuiActionUndoFailedSafe' -Fallback "Failed to undo the previous selection change.`n`n{0}") -f $_.Exception.Message } else { (& $getUxLocalizedStringCapture -Key 'GuiActionUndoFailed' -Fallback "Failed to restore the previous snapshot.`n`n{0}") -f $_.Exception.Message }) -Buttons @('OK') -AccentButton 'OK')
			return
		}

		& $setGuiStatusTextCommand -Text $(if (& $testIsSafeModeUxCommand) { & $getUxLocalizedStringCapture -Key 'GuiActionUndoSuccessSafe' -Fallback 'Last selection change undone.' } else { & $getUxLocalizedStringCapture -Key 'GuiActionUndoSuccess' -Fallback 'Previous GUI snapshot restored.' }) -Tone 'accent'
		LogInfo $(if (& $testIsSafeModeUxCommand) { (Get-UxBilingualLocalizedString -Key 'GuiLogUndoSnapshotSafe' -Fallback 'Undid previous GUI selection change via snapshot restore.') } else { (Get-UxBilingualLocalizedString -Key 'GuiLogUndoSnapshot' -Fallback 'Restored previous GUI snapshot') })
	}) | Out-Null

	# Capture file-dialog function for use inside .GetNewClosure() handlers
	# (.GetNewClosure() captures variables but not functions from the parent scope).
		$showGuiFileSaveDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiFileSaveDialog' -CommandType 'Function'
		$showGuiFolderPickerDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiFolderPickerDialog' -CommandType 'Function'

	# Export System State button
	$BtnExportSystemState = New-PresetButton -Label (Get-UxLocalizedString -Key 'GuiFooterExportSystemState' -Fallback 'Export System State') -Variant 'Subtle' -Compact -Muted
	$BtnExportSystemState.FontSize = $Script:GuiLayout.FontSizeSmall
	$BtnExportSystemState.ToolTip = (Get-UxLocalizedString -Key 'GuiActionExportStateTooltip' -Fallback 'Capture a snapshot of current system settings and save to a JSON file.')
	[void]($secondaryActionBar.Children.Add($BtnExportSystemState))
	$Script:BtnExportSystemState = $BtnExportSystemState
	$exportSystemStateSetStatusCommand = Get-GuiRuntimeCommand -Name 'Set-GuiStatusText' -CommandType 'Function'
	Register-GuiEventHandler -Source $BtnExportSystemState -EventName 'Click' -Handler ({
		try
		{
			& $exportSystemStateSetStatusCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiActionExportStateCapturing' -Fallback 'Capturing system state snapshot...') -Tone 'accent'
			$snapshot = New-SystemStateSnapshot -Manifest $Script:TweakManifest
			$defaultFileName = 'Baseline-SystemState-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
			$savePath = & $showGuiFileSaveDialogCommand -Title (& $getUxLocalizedStringCapture -Key 'GuiActionExportStateDialogTitle' -Fallback 'Export System State Snapshot') `
				-Filter 'JSON Files (*.json)|*.json|All Files (*.*)|*.*' `
				-DefaultExtension 'json' `
				-FileName $defaultFileName
			if ([string]::IsNullOrWhiteSpace($savePath))
			{
				& $exportSystemStateSetStatusCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiActionExportStateCancelled' -Fallback 'System state export cancelled.') -Tone 'accent'
				return
			}
			Export-SystemStateSnapshot -Snapshot $snapshot -Path $savePath
			& $exportSystemStateSetStatusCommand -Text ((& $getUxLocalizedStringCapture -Key 'GuiActionExportStateSuccess' -Fallback 'System state exported: {0} entries saved to {1}') -f $snapshot.Entries.Count, $savePath) -Tone 'success'
			LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExportSystemStateSuccess' -Fallback 'Exported system state snapshot: {0} entries to {1}' -FormatArgs @($snapshot.Entries.Count, $savePath))
		}
		catch
		{
			LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to export system state')
			[void](Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiActionExportStateTitle' -Fallback 'Export System State') -Message ((& $getUxLocalizedStringCapture -Key 'GuiActionExportStateFailed' -Fallback "Failed to export system state.`n`n{0}") -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
		}
	}) | Out-Null

	# Export Configuration Profile button
	$BtnExportConfigProfile = New-PresetButton -Label (Get-UxLocalizedString -Key 'GuiFooterExportConfigProfile' -Fallback 'Export Config Profile') -Variant 'Subtle' -Compact -Muted
	$BtnExportConfigProfile.FontSize = $Script:GuiLayout.FontSizeSmall
	$BtnExportConfigProfile.ToolTip = (Get-UxLocalizedString -Key 'GuiActionExportProfileTooltip' -Fallback 'Export current tweak selections and queued app changes as a portable configuration profile.')
	[void]($secondaryActionBar.Children.Add($BtnExportConfigProfile))
	$Script:BtnExportConfigProfile = $BtnExportConfigProfile
	$exportConfigProfileGetRunListCommand = Get-GuiRuntimeCommand -Name 'Get-ActiveTweakRunList' -CommandType 'Function'
	$exportConfigProfileSetStatusCommand = Get-GuiRuntimeCommand -Name 'Set-GuiStatusText' -CommandType 'Function'
	Register-GuiEventHandler -Source $BtnExportConfigProfile -EventName 'Click' -Handler ({
		if (& $testGuiRunInProgressCapture) { return }
		try
		{
			$tweakList = & $exportConfigProfileGetRunListCommand
			$queuedAppActions = if ($getQueuedAppsProfileActionsCommand) { @(& $getQueuedAppsProfileActionsCommand) } else { @() }
			$tweakCount = @($tweakList).Count
			$appActionCount = @($queuedAppActions).Count
			if ($tweakCount -eq 0 -and $appActionCount -eq 0)
			{
				Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiActionExportProfileTitle' -Fallback 'Export Configuration Profile') `
					-Message (& $getUxLocalizedStringCapture -Key 'GuiActionExportProfileNoTweaks' -Fallback 'Select at least one tweak or queue at least one app action before exporting a configuration profile.') `
					-Buttons @('OK') `
					-AccentButton 'OK'
				return
			}

			$baselineVersion = $null
			try { $baselineVersion = Get-BaselineDisplayVersion } catch { Write-SwallowedException -ErrorRecord $_ -Source 'ActionHandlers.ExportConfigProfile.GetDisplayVersion' }
			if ([string]::IsNullOrWhiteSpace($baselineVersion)) { $baselineVersion = 'unknown' }

			# Snapshot user-added external software entries so the profile is
			# portable: importing on another machine can restore the catalog
			# definitions, not just selection state.
			$userAppSnapshot = @()
			if (Get-Command -Name 'Get-BaselineUserAppEntries' -CommandType Function -ErrorAction SilentlyContinue)
			{
				try
				{
					$userAppResult = Get-BaselineUserAppEntries
					if ($userAppResult -and $userAppResult.PSObject.Properties['Entries'])
					{
						$userAppSnapshot = @($userAppResult.Entries)
					}
				}
				catch
				{
					if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
					{
						Write-SwallowedException -ErrorRecord $_ -Source 'ActionHandlers.ExportConfigProfile.UserApps'
					}
					$userAppSnapshot = @()
				}
			}
			$userAppCount = @($userAppSnapshot).Count

			$includePaths = @()
			$includePathCmd = Get-Command -Name 'Get-HeadlessPresetIncludedTweakLibraryPathSet' -CommandType Function -ErrorAction SilentlyContinue
			if ($includePathCmd)
			{
				$includePaths = @(& $includePathCmd)
			}

			$profile = New-ConfigurationProfile `
				-Name ('Baseline-Profile-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss')) `
				-Selections @($tweakList) `
				-AppActions @($queuedAppActions) `
				-UserApps @($userAppSnapshot) `
				-IncludePaths $includePaths `
				-BaselineVersion $baselineVersion `
				-AppsPackageSourcePreference $Script:AppsPackageSourcePreference

			$defaultFileName = 'Baseline-ConfigProfile-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
			$savePath = & $showGuiFileSaveDialogCommand -Title (& $getUxLocalizedStringCapture -Key 'GuiActionExportProfileTitle' -Fallback 'Export Configuration Profile') `
				-Filter 'JSON Files (*.json)|*.json|All Files (*.*)|*.*' `
				-DefaultExtension 'json' `
				-FileName $defaultFileName

			if ([string]::IsNullOrWhiteSpace($savePath))
			{
				& $exportConfigProfileSetStatusCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiActionExportProfileCancelled' -Fallback 'Configuration profile export cancelled.') -Tone 'accent'
				return
			}

			Export-ConfigurationProfile -Profile $profile -FilePath $savePath
			if ($tweakCount -gt 0 -and $appActionCount -gt 0)
			{
				& $exportConfigProfileSetStatusCommand -Text ("Configuration profile exported: {0} tweak(s) and {1} app action(s) saved to {2}" -f $tweakCount, $appActionCount, $savePath) -Tone 'success'
				LogInfo ("Exported configuration profile: {0} tweak(s) and {1} app action(s) to {2}" -f $tweakCount, $appActionCount, $savePath)
			}
			elseif ($tweakCount -gt 0)
			{
				& $exportConfigProfileSetStatusCommand -Text ("Configuration profile exported: {0} tweak(s) saved to {1}" -f $tweakCount, $savePath) -Tone 'success'
				LogInfo ("Exported configuration profile: {0} tweak(s) to {1}" -f $tweakCount, $savePath)
			}
			else
			{
				& $exportConfigProfileSetStatusCommand -Text ("Configuration profile exported: {0} app action(s) saved to {1}" -f $appActionCount, $savePath) -Tone 'success'
				LogInfo ("Exported configuration profile: {0} app action(s) to {1}" -f $appActionCount, $savePath)
			}
		}
		catch
		{
			LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to export configuration profile')
			[void](Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiActionExportProfileTitle' -Fallback 'Export Configuration Profile') -Message ((& $getUxLocalizedStringCapture -Key 'GuiActionExportProfileFailed' -Fallback "Failed to export configuration profile.`n`n{0}") -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
		}
	}.GetNewClosure()) | Out-Null

	# Export First-Logon Command button
	$BtnExportFirstLogonCommand = New-PresetButton -Label (Get-UxLocalizedString -Key 'GuiFooterExportFirstLogonCommand' -Fallback 'Export First-Logon Command') -Variant 'Subtle' -Compact -Muted
	$BtnExportFirstLogonCommand.FontSize = $Script:GuiLayout.FontSizeSmall
	$BtnExportFirstLogonCommand.ToolTip = (Get-UxLocalizedString -Key 'GuiActionExportFirstLogonTooltip' -Fallback 'Export an autounattend FirstLogonCommands XML snippet that runs Baseline with a saved configuration profile.')
	[void]($secondaryActionBar.Children.Add($BtnExportFirstLogonCommand))
	$Script:BtnExportFirstLogonCommand = $BtnExportFirstLogonCommand
	$exportFirstLogonCommandShowOpenDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiFileOpenDialog' -CommandType 'Function'
	$exportFirstLogonCommandShowSaveDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiFileSaveDialog' -CommandType 'Function'
	$exportFirstLogonCommandExportCommand = Get-GuiRuntimeCommand -Name 'Export-BaselineFirstLogonCommandSnippet' -CommandType 'Function'
	$exportFirstLogonCommandSetStatusCommand = Get-GuiRuntimeCommand -Name 'Set-GuiStatusText' -CommandType 'Function'
	Register-GuiEventHandler -Source $BtnExportFirstLogonCommand -EventName 'Click' -Handler ({
		if (& $testGuiRunInProgressCapture) { return }
		try
		{
			$configPath = & $exportFirstLogonCommandShowOpenDialogCommand -Title 'Select Configuration Profile' -Filter 'JSON Files (*.json)|*.json|All Files (*.*)|*.*' -InitialDirectory (Get-GuiSettingsProfileDirectory -AppName 'Baseline')
			if ([string]::IsNullOrWhiteSpace([string]$configPath))
			{
				& $exportFirstLogonCommandSetStatusCommand -Text 'First-logon command export cancelled.' -Tone 'accent'
				return
			}

			$configPath = [System.IO.Path]::GetFullPath([string]$configPath)
			if (-not (Test-Path -LiteralPath $configPath -PathType Leaf))
			{
				throw "Configuration profile not found: $configPath"
			}

			$configStem = [System.IO.Path]::GetFileNameWithoutExtension($configPath)
			if ([string]::IsNullOrWhiteSpace([string]$configStem))
			{
				$configStem = 'Baseline-ConfigProfile'
			}

			$savePath = & $exportFirstLogonCommandShowSaveDialogCommand -Title 'Export First-Logon Command' -Filter 'XML Files (*.xml)|*.xml|All Files (*.*)|*.*' -DefaultExtension 'xml' -FileName ('Baseline-FirstLogonCommand-{0}.xml' -f $configStem) -InitialDirectory (Split-Path -Path $configPath -Parent)
			if ([string]::IsNullOrWhiteSpace([string]$savePath))
			{
				& $exportFirstLogonCommandSetStatusCommand -Text 'First-logon command export cancelled.' -Tone 'accent'
				return
			}

			$exportResult = & $exportFirstLogonCommandExportCommand -ConfigPath $configPath -FilePath $savePath
			& $exportFirstLogonCommandSetStatusCommand -Text ("First-logon command exported to {0}" -f $exportResult.FilePath) -Tone 'success'
			LogInfo ("Exported first-logon command snippet for {0} to {1}" -f $exportResult.ConfigPath, $exportResult.FilePath)
		}
		catch
		{
			LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to export first-logon command')
			[void](Show-ThemedDialog -Title 'Export First-Logon Command' -Message ("Failed to export first-logon command.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
		}
	}.GetNewClosure()) | Out-Null

	# Import Configuration Profile button - file -> review-mode dialog -> apply.
	$BtnImportConfigProfile = New-PresetButton -Label (Get-UxLocalizedString -Key 'GuiFooterImportConfigProfile' -Fallback 'Import Config Profile') -Variant 'Subtle' -Compact -Muted
	$BtnImportConfigProfile.FontSize = $Script:GuiLayout.FontSizeSmall
	$BtnImportConfigProfile.ToolTip = (Get-UxLocalizedString -Key 'GuiActionImportProfileTooltip' -Fallback 'Load a portable configuration profile, review the per-row diff, and apply the accepted changes.')
	[void]($secondaryActionBar.Children.Add($BtnImportConfigProfile))
	$Script:BtnImportConfigProfile = $BtnImportConfigProfile
	$importConfigProfileGetRunListCommand = Get-GuiRuntimeCommand -Name 'Get-ActiveTweakRunList' -CommandType 'Function'
	$importConfigProfileSetStatusCommand = Get-GuiRuntimeCommand -Name 'Set-GuiStatusText' -CommandType 'Function'
	$importConfigProfileShowOpenDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiFileOpenDialog' -CommandType 'Function'
	$importConfigProfileImportCommand = Get-GuiRuntimeCommand -Name 'Import-ConfigurationProfile' -CommandType 'Function'
	$importConfigProfileNewCommand = Get-GuiRuntimeCommand -Name 'New-ConfigurationProfile' -CommandType 'Function'
	$importConfigProfileToRunListCommand = Get-GuiRuntimeCommand -Name 'ConvertFrom-BaselineConfigProfileToRunList' -CommandType 'Function'
	$importConfigProfileTestCompatCommand = Get-GuiRuntimeCommand -Name 'Test-ConfigurationProfileCompatibility' -CommandType 'Function'
	$importConfigProfilePromptForRunCommand = Get-GuiRuntimeCommand -Name 'Invoke-GuiReviewModePromptForRun' -CommandType 'Function'
	Register-GuiEventHandler -Source $BtnImportConfigProfile -EventName 'Click' -Handler ({
		if (& $testGuiRunInProgressCapture) { return }
		$importTitle = (& $getUxLocalizedStringCapture -Key 'GuiActionImportProfileTitle' -Fallback 'Import Configuration Profile')
		try
		{
			if (-not $importConfigProfileImportCommand -or -not $importConfigProfileToRunListCommand -or -not $importConfigProfilePromptForRunCommand)
			{
				throw 'Import-ConfigurationProfile / ConvertFrom-BaselineConfigProfileToRunList / Invoke-GuiReviewModePromptForRun not available.'
			}

			$openPath = & $importConfigProfileShowOpenDialogCommand -Title $importTitle -Filter 'Baseline Config Profile (*.json)|*.json|All Files (*.*)|*.*'
			if ([string]::IsNullOrWhiteSpace($openPath))
			{
				& $importConfigProfileSetStatusCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiActionImportProfileCancelled' -Fallback 'Configuration profile import cancelled.') -Tone 'accent'
				return
			}

			$importedProfile = & $importConfigProfileImportCommand -FilePath $openPath

			if ($importConfigProfileTestCompatCommand)
			{
				$compat = & $importConfigProfileTestCompatCommand -Profile $importedProfile
				if ($compat -and -not [bool]$compat.Compatible)
				{
					$warningText = ($compat.Warnings -join "`n")
					$choice = Show-ThemedDialog -Title $importTitle -Message ((& $getUxLocalizedStringCapture -Key 'GuiActionImportProfileIncompatible' -Fallback "This profile is not fully compatible with the current system:`n`n{0}`n`nProceed anyway?") -f $warningText) -Buttons @('OK','Cancel') -AccentButton 'OK'
					if ($choice -ne 'OK')
					{
						& $importConfigProfileSetStatusCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiActionImportProfileCancelled' -Fallback 'Configuration profile import cancelled.') -Tone 'accent'
						return
					}
				}
				elseif ($compat -and @($compat.Warnings).Count -gt 0)
				{
					LogWarning ("Import-ConfigProfile compatibility warnings: {0}" -f (@($compat.Warnings) -join '; '))
				}
			}

			$baselineVersion = $null
			try { $baselineVersion = Get-BaselineDisplayVersion } catch { Write-SwallowedException -ErrorRecord $_ -Source 'ActionHandlers.ImportConfigProfile.GetDisplayVersion' }
			if ([string]::IsNullOrWhiteSpace($baselineVersion)) { $baselineVersion = 'unknown' }

			# If the profile carries inlined custom user-app definitions, offer
			# to restore them to the local user-apps directory before walking
			# the tweak run-list. Skip silently when the profile predates
			# SchemaVersion 3 or carries an empty UserApps array.
			$profileUserApps = @()
			if ($importedProfile -and $importedProfile.PSObject.Properties['UserApps'] -and $null -ne $importedProfile.UserApps)
			{
				$profileUserApps = @($importedProfile.UserApps)
			}
			$userAppRestoreSummary = $null
			if (@($profileUserApps).Count -gt 0 -and (Get-Command -Name 'Save-BaselineUserAppEntriesFromProfile' -CommandType Function -ErrorAction SilentlyContinue))
			{
				$userAppNames = @($profileUserApps | ForEach-Object {
					if ($_ -and $_.PSObject.Properties['Name']) { [string]$_.Name } else { '<unnamed>' }
				})
				$userAppPromptMessage = (& $getUxLocalizedStringCapture -Key 'GuiActionImportProfileUserAppsPrompt' -Fallback "This profile carries {0} custom external software definition(s):`n`n{1}`n`nRestore them to your user apps directory? Existing entries with the same Name / WinGetId / ChocoId will be skipped.") -f @($profileUserApps).Count, ((@($userAppNames) | Select-Object -First 20) -join ', ')
				$userAppChoice = Show-ThemedDialog -Title $importTitle -Message $userAppPromptMessage -Buttons @('Yes','No','Cancel') -AccentButton 'Yes'
				if ($userAppChoice -eq 'Cancel')
				{
					& $importConfigProfileSetStatusCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiActionImportProfileCancelled' -Fallback 'Configuration profile import cancelled.') -Tone 'accent'
					return
				}
				if ($userAppChoice -eq 'Yes')
				{
					try
					{
						$userAppRestoreSummary = Save-BaselineUserAppEntriesFromProfile -Profile $importedProfile
						$importedCount = @($userAppRestoreSummary.Imported).Count
						$skippedCount = @($userAppRestoreSummary.Skipped).Count
						$failedCount = @($userAppRestoreSummary.Failed).Count
						LogInfo ('Import config profile user-app restore: {0} imported, {1} skipped, {2} failed.' -f $importedCount, $skippedCount, $failedCount)
						if ($importedCount -gt 0 -and (Get-Command -Name 'Get-BaselineApplicationsCatalog' -CommandType Function -ErrorAction SilentlyContinue))
						{
							try { $null = Get-BaselineApplicationsCatalog -Force } catch { Write-SwallowedException -ErrorRecord $_ -Source 'ActionHandlers.ImportConfigProfile.RefreshUserAppsCatalog' }
							$Script:AppsViewBuildSignature = $null
							if ($Script:AppsModeActive -and (Get-Command -Name 'Build-AppsViewCards' -CommandType Function -ErrorAction SilentlyContinue))
							{
								Build-AppsViewCards
							}
						}
					}
					catch
					{
						LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to restore user apps from imported profile')
					}
				}
			}

			$currentTweakList = @(& $importConfigProfileGetRunListCommand)
			$currentQueuedAppActions = if ($getQueuedAppsProfileActionsCommand) { @(& $getQueuedAppsProfileActionsCommand) } else { @() }
			$currentProfile = & $importConfigProfileNewCommand `
				-Name ('Baseline-Current-{0}' -f (Get-Date -Format 'yyyyMMddHHmmss')) `
				-Selections $currentTweakList `
				-AppActions $currentQueuedAppActions `
				-BaselineVersion $baselineVersion `
				-AppsPackageSourcePreference $Script:AppsPackageSourcePreference

			$importedRunList = @(& $importConfigProfileToRunListCommand -Profile $importedProfile -Manifest $Script:TweakManifest)
			if (@($importedRunList).Count -eq 0)
			{
				# UserApps-only profile is a legitimate use case - show a
				# success message reflecting what was restored rather than
				# the generic "no matching tweaks" warning.
				if ($userAppRestoreSummary -and @($userAppRestoreSummary.Imported).Count -gt 0)
				{
					$importedCount = @($userAppRestoreSummary.Imported).Count
					& $importConfigProfileSetStatusCommand -Text (("Imported {0} custom app definition(s) from profile." -f $importedCount)) -Tone 'success'
					return
				}
				[void](Show-ThemedDialog -Title $importTitle -Message (& $getUxLocalizedStringCapture -Key 'GuiActionImportProfileEmpty' -Fallback 'The imported profile contains no entries that match this Baseline build.') -Buttons @('OK') -AccentButton 'OK')
				& $importConfigProfileSetStatusCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiActionImportProfileEmptyStatus' -Fallback 'No matching tweaks in imported profile.') -Tone 'accent'
				return
			}

			$promptArgs = @{
				CurrentProfile  = $currentProfile
				ImportedProfile = $importedProfile
				TweakList       = $importedRunList
				Title           = $importTitle
				Subtitle        = (& $getUxLocalizedStringCapture -Key 'GuiActionImportProfileSubtitle' -Fallback 'Review the imported profile against current state. Accept the rows you want to apply, then click Apply.')
			}
			$filteredTweaks = @(& $importConfigProfilePromptForRunCommand @promptArgs)
			if ($null -eq $filteredTweaks -or @($filteredTweaks).Count -eq 0)
			{
				& $importConfigProfileSetStatusCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiActionImportProfileCancelled' -Fallback 'Configuration profile import cancelled.') -Tone 'accent'
				LogInfo ('Import config profile cancelled or accepted nothing for {0}' -f $openPath)
				return
			}

			$warningChoice = & $confirmHighRiskTweakRunCommand -SelectedTweaks $filteredTweaks
			if (-not $warningChoice -or $warningChoice -eq 'Cancel')
			{
				& $importConfigProfileSetStatusCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiActionImportProfileCancelled' -Fallback 'Configuration profile import cancelled.') -Tone 'accent'
				return
			}

			$runTitle = ((& $getUxLocalizedStringCapture -Key 'GuiActionImportProfileRunTitle' -Fallback 'Apply imported configuration profile ({0})') -f ([System.IO.Path]::GetFileName($openPath)))
			LogInfo ('Applying imported config profile {0}: {1} accepted tweak(s).' -f $openPath, @($filteredTweaks).Count)
			& $startGuiExecutionRunCommand -TweakList $filteredTweaks -Mode 'Run' -ExecutionTitle $runTitle
		}
		catch
		{
			LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to import configuration profile')
			[void](Show-ThemedDialog -Title $importTitle -Message ((& $getUxLocalizedStringCapture -Key 'GuiActionImportProfileFailed' -Fallback "Failed to import configuration profile.`n`n{0}") -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
		}
	}.GetNewClosure()) | Out-Null

	# Export Support Bundle action
	if ($MenuToolsExportSupportBundle)
	{
		Register-GuiEventHandler -Source $MenuToolsExportSupportBundle -EventName 'Click' -Handler ({
			if (& $testGuiRunInProgressCapture) { return }
			try
			{
				$selectedFolder = & $showGuiFolderPickerDialogCommand -Description 'Select a folder to save the support bundle.'
				if ([string]::IsNullOrWhiteSpace($selectedFolder))
				{
					return
				}

				$defaultFileName = 'Baseline_SupportBundle_{0}_{1}.zip' -f (Get-Date -Format 'yyyy-MM-dd_HHmmss'), (Get-BaselineRunId)
				$savePath = Join-Path -Path $selectedFolder -ChildPath $defaultFileName

				$sessionSnapshot = & $getGuiSettingsSnapshotCommand
				$sessionStatePath = Join-Path ([System.IO.Path]::GetTempPath()) ('BaselineSupportBundleSession_{0}.json' -f [guid]::NewGuid().ToString('N'))
				try
				{
					$sessionPayload = [ordered]@{
						Schema = 'Baseline.GuiSession'
						SchemaVersion = 1
						SavedAt = (Get-Date).ToString('o')
						State = $sessionSnapshot
					}
					($sessionPayload | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $sessionStatePath -Encoding UTF8 -Force

					$systemSnapshot = $null
					try { $systemSnapshot = New-SystemStateSnapshot -Manifest $Script:TweakManifest } catch { $systemSnapshot = $null }

					$preRunSnapshot = $null
					$postRunSnapshot = $null
					try
					{
						if ($Script:RunState)
						{
							if ($Script:RunState.ContainsKey('PreRunSnapshot') -and $Script:RunState['PreRunSnapshot']) { $preRunSnapshot = $Script:RunState['PreRunSnapshot'] }
							if ($Script:RunState.ContainsKey('PostRunSnapshot') -and $Script:RunState['PostRunSnapshot']) { $postRunSnapshot = $Script:RunState['PostRunSnapshot'] }
						}

						if (($null -eq $preRunSnapshot -or $null -eq $postRunSnapshot) -and $Script:LastRunProfile)
						{
							if ($null -eq $preRunSnapshot -and (& $hasField -Object $Script:LastRunProfile -FieldName 'PreRunSnapshot')) { $preRunSnapshot = $Script:LastRunProfile.PreRunSnapshot }
							if ($null -eq $postRunSnapshot -and (& $hasField -Object $Script:LastRunProfile -FieldName 'PostRunSnapshot')) { $postRunSnapshot = $Script:LastRunProfile.PostRunSnapshot }
						}
					}
					catch
					{
						$preRunSnapshot = $null
						$postRunSnapshot = $null
					}

					$connectivityResults = @()
					try
					{
						$ctx = & $getRemoteTargetContextCommand
						if ($ctx -and (& $hasField -Object $ctx -FieldName 'LastConnectivityResults'))
						{
							$connectivityResults = @($ctx.LastConnectivityResults)
						}
					}
					catch { $connectivityResults = @() }

					$result = & $exportSupportBundleCommand -OutputPath $savePath -ProfilePath $sessionStatePath -SystemSnapshot $systemSnapshot -PreSnapshot $preRunSnapshot -PostSnapshot $postRunSnapshot -Manifest $Script:TweakManifest -IncludeAuditLog -IncludeTestReport -ConnectivityResults $connectivityResults
					& $setGuiStatusTextCommand -Text ("Support bundle exported: {0}" -f $result.OutputPath) -Tone 'success'
					LogInfo ("Exported support bundle to {0}" -f $result.OutputPath)
				}
				finally
				{
					if (Test-Path -LiteralPath $sessionStatePath)
					{
						try
						{
							Remove-Item -LiteralPath $sessionStatePath -Force -ErrorAction SilentlyContinue
						}
						catch
						{
							if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
							{
								Write-SwallowedException -ErrorRecord $_ -Source 'ActionHandlers.ExportSupportBundle.RemoveSessionStatePath'
							}
						}
					}
				}
			}
			catch
			{
				LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to export support bundle')
				[void](Show-ThemedDialog -Title 'Export Support Bundle' -Message ("Failed to export support bundle.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
			}
		}.GetNewClosure()) | Out-Null
	}

	# Remote target approval action
	if ($MenuToolsApproveRemoteTargets)
	{
		Register-GuiEventHandler -Source $MenuToolsApproveRemoteTargets -EventName 'Click' -Handler ({
			if (& $testGuiRunInProgressCapture) { return }
			try
			{
				$context = $null
				try { $context = & $getRemoteTargetContextCommand } catch { $context = $null }
				if (-not $context -or -not $context.Connected -or $context.TargetComputers.Count -eq 0)
				{
					[void](Show-ThemedDialog -Title 'Approve Target List' -Message 'Connect to at least one remote computer before approving a target list.' -Buttons @('OK') -AccentButton 'OK')
					return
				}

				$targetLabel = ($context.TargetComputers -join ', ')
				if ($testRemoteTargetApprovalCommand -and (& $testRemoteTargetApprovalCommand -ComputerName @($context.TargetComputers)))
				{
					[void](Show-ThemedDialog -Title 'Approve Target List' -Message ("The current target list is already approved for this session.`n`nTargets: {0}" -f $targetLabel) -Buttons @('OK') -AccentButton 'OK')
					return
				}

				$confirm = Show-ThemedDialog -Title 'Approve Target List' -Message ("Approve this exact target list for the current session?`n`nTargets: {0}`n`nFuture remote applies must match this list exactly until disconnect." -f $targetLabel) -Buttons @('Cancel', 'Approve') -AccentButton 'Approve'
				if ($confirm -ne 'Approve') { return }

				if ($setRemoteTargetApprovalCommand)
				{
					& $setRemoteTargetApprovalCommand -ComputerName @($context.TargetComputers) -ApprovalMessage 'Remote target list approved for this session.'
				}
				& $setGuiStatusTextCommand -Text ("Approved remote targets: {0}" -f $targetLabel) -Tone 'success'
				LogInfo ("Approved remote target list: {0}" -f $targetLabel)
			}
			catch
			{
				LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to approve remote target list')
				[void](Show-ThemedDialog -Title 'Approve Target List' -Message ((& $getUxLocalizedStringCapture -Key 'GuiRemoteTargetApprovalFailed' -Fallback "Failed to approve remote target list.`n`n{0}") -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
			}
		}.GetNewClosure()) | Out-Null
	}

	# Remote approval policy actions
	if ($MenuToolsSaveRemoteApprovalPolicy)
	{
		Register-GuiEventHandler -Source $MenuToolsSaveRemoteApprovalPolicy -EventName 'Click' -Handler ({
			if (& $testGuiRunInProgressCapture) { return }
			if (-not $exportRemoteTargetApprovalPolicyCommand)
			{
				[void](Show-ThemedDialog -Title 'Save Remote Approval Policy' -Message 'Remote approval policy export is unavailable in this runtime.' -Buttons @('OK') -AccentButton 'OK')
				return
			}
			try
			{
				$null = & $exportRemoteTargetApprovalPolicyCommand
				& $setGuiStatusTextCommand -Text 'Remote approval policy saved.' -Tone 'success'
			}
			catch
			{
				LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to save remote approval policy')
				[void](Show-ThemedDialog -Title 'Save Remote Approval Policy' -Message ("Failed to save remote approval policy.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
			}
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuToolsLoadRemoteApprovalPolicy)
	{
		Register-GuiEventHandler -Source $MenuToolsLoadRemoteApprovalPolicy -EventName 'Click' -Handler ({
			if (& $testGuiRunInProgressCapture) { return }
			if (-not $importRemoteTargetApprovalPolicyCommand)
			{
				[void](Show-ThemedDialog -Title 'Load Remote Approval Policy' -Message 'Remote approval policy import is unavailable in this runtime.' -Buttons @('OK') -AccentButton 'OK')
				return
			}
			try
			{
				$null = & $importRemoteTargetApprovalPolicyCommand
				& $setGuiStatusTextCommand -Text 'Remote approval policy loaded.' -Tone 'success'
			}
			catch
			{
				LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to load remote approval policy')
				[void](Show-ThemedDialog -Title 'Load Remote Approval Policy' -Message ("Failed to load remote approval policy.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
			}
		}.GetNewClosure()) | Out-Null
	}

	if ($MenuToolsRemoteConsole)
	{
		Register-GuiEventHandler -Source $MenuToolsRemoteConsole -EventName 'Click' -Handler ({
			if (& $testGuiRunInProgressCapture) { return }
			try
			{
				$null = & $showGuiRemoteConsoleDialogCommand
			}
			catch
			{
				LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to open remote console')
				[void](Show-ThemedDialog -Title 'Remote Console' -Message ("Failed to open remote console.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
			}
		}.GetNewClosure()) | Out-Null
	}

	if ($MenuToolsOperatorConsole)
	{
		Register-GuiEventHandler -Source $MenuToolsOperatorConsole -EventName 'Click' -Handler ({
			if (& $testGuiRunInProgressCapture) { return }
			try
			{
				$null = & $showGuiOperatorConsoleDialogCommand
			}
			catch
			{
				LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to open operator console')
				[void](Show-ThemedDialog -Title 'Operator Console' -Message ("Failed to open operator console.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
			}
		}.GetNewClosure()) | Out-Null
	}

	if ($MenuToolsRemovalPersistence)
	{
		Register-GuiEventHandler -Source $MenuToolsRemovalPersistence -EventName 'Click' -Handler ({
			if (& $testGuiRunInProgressCapture) { return }
			try
			{
				$removalPersistenceDialogCommand = $showGuiRemovalPersistenceDialogCommand
				if (-not $removalPersistenceDialogCommand)
				{
					$removalPersistenceDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiRemovalPersistenceDialog' -CommandType 'Function'
				}
				if (-not $removalPersistenceDialogCommand)
				{
					throw 'Removal Persistence dialog command is not available.'
				}
				$null = & $removalPersistenceDialogCommand
			}
			catch
			{
				LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to open removal persistence')
				[void](Show-ThemedDialog -Title 'Removal Persistence' -Message ("Failed to open removal persistence.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
			}
		}.GetNewClosure()) | Out-Null
	}

	if ($MenuToolsDeploymentMediaBuilder)
	{
		Register-GuiEventHandler -Source $MenuToolsDeploymentMediaBuilder -EventName 'Click' -Handler ({
			if (& $testGuiRunInProgressCapture) { return }
			try
			{
				$deploymentMediaBuilderDialogCommand = $showGuiDeploymentMediaBuilderDialogCommand
				if (-not $deploymentMediaBuilderDialogCommand)
				{
					$deploymentMediaBuilderDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiDeploymentMediaBuilderDialog' -CommandType 'Function'
				}
				if (-not $deploymentMediaBuilderDialogCommand)
				{
					throw 'Deployment Media Builder dialog command is not available.'
				}
				$null = & $deploymentMediaBuilderDialogCommand
			}
			catch
			{
				LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to open deployment media builder')
				[void](Show-ThemedDialog -Title 'Deployment Media Builder' -Message ("Failed to open deployment media builder.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
			}
		}.GetNewClosure()) | Out-Null
	}

	# Remote session status action
	if ($MenuToolsRemoteSessionStatus)
	{
		Register-GuiEventHandler -Source $MenuToolsRemoteSessionStatus -EventName 'Click' -Handler ({
			if (& $testGuiRunInProgressCapture) { return }
			try
			{
				$context = $null
				try { $context = & $getRemoteTargetContextCommand } catch { $context = $null }
				$sessions = @()
				if ($getRemoteSessionSummaryCommand)
				{
					try { $sessions = @(& $getRemoteSessionSummaryCommand) } catch { $sessions = @() }
				}

				$lines = [System.Collections.Generic.List[string]]::new()
				[void]$lines.Add((Get-UxLocalizedString -Key 'GuiRemoteSessionStatusTitle' -Fallback 'Remote Session Status'))
				[void]$lines.Add(' ')
				if ($context -and $context.Connected -and $context.TargetComputers.Count -gt 0)
				{
					[void]$lines.Add(('Connected target(s): {0}' -f ($context.TargetComputers -join ', ')))
					if ($context.ConnectedAt) { [void]$lines.Add(('Connected at (UTC): {0}' -f $context.ConnectedAt)) }
					if ($context.StatusMessage) { [void]$lines.Add(('Status: {0}' -f $context.StatusMessage)) }
					if ($context.ApprovedTargetComputers -and $context.ApprovedTargetComputers.Count -gt 0)
					{
						[void]$lines.Add(('Approved target list: {0}' -f ($context.ApprovedTargetComputers -join ', ')))
						if ($context.ApprovedAt) { [void]$lines.Add(('Approved at (UTC): {0}' -f $context.ApprovedAt)) }
					}
				}
				else
				{
					[void]$lines.Add((Get-UxLocalizedString -Key 'GuiRemoteSessionStatusNone' -Fallback 'No remote target is currently connected.'))
				}

				[void]$lines.Add(' ')
				if ($sessions.Count -gt 0)
				{
					[void]$lines.Add((Get-UxLocalizedString -Key 'GuiRemoteSessionStatusCacheHeader' -Fallback 'Cached sessions:'))
					foreach ($session in @($sessions))
					{
						if (-not $session) { continue }
						$transportSuffix = ''
						if ($session.PSObject.Properties['TransportKey'] -and -not [string]::IsNullOrWhiteSpace([string]$session.TransportKey) -and [string]$session.TransportKey -ne '<default>')
						{
							$transportSuffix = ' (transport: {0})' -f ([string]$session.TransportKey).Substring(0, [Math]::Min(8, ([string]$session.TransportKey).Length))
						}
						[void]$lines.Add((' - {0} [{1}]{2}' -f $session.ComputerName, $session.State, $transportSuffix))
					}
				}
				else
				{
					[void]$lines.Add((Get-UxLocalizedString -Key 'GuiRemoteSessionStatusCacheEmpty' -Fallback 'Cached sessions: none'))
				}

				[void](Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiRemoteSessionStatusTitle' -Fallback 'Remote Session Status') -Message ($lines -join [Environment]::NewLine) -Buttons @('OK') -AccentButton 'OK')
				LogInfo 'Viewed remote session status.'
			}
			catch
			{
				LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to view remote session status')
				[void](Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiRemoteSessionStatusTitle' -Fallback 'Remote Session Status') -Message ((& $getUxLocalizedStringCapture -Key 'GuiRemoteSessionStatusFailed' -Fallback "Failed to view remote session status.`n`n{0}") -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
			}
		}.GetNewClosure()) | Out-Null
	}

	# Undo Last Run button
	$Script:LastRunProfile = Import-GuiLastRunProfile
	$Script:InterruptedRunProfile = Import-GuiInterruptedRunProfile
	$BtnUndoLastRun = New-PresetButton -Label (Get-UxLocalizedString -Key 'GuiFooterUndoLastRun' -Fallback 'Undo Last Run') -Variant 'Secondary' -Compact
	$BtnUndoLastRun.FontSize = $Script:GuiLayout.FontSizeSmall
	$BtnUndoLastRun.ToolTip = (Get-UxLocalizedString -Key 'GuiActionUndoLastRunTooltip' -Fallback 'Reverse the changes from your most recent run')
	$BtnUndoLastRun.IsEnabled = ($null -ne $Script:LastRunProfile -and $Script:LastRunProfile.PSObject.Properties['RollbackCommands'] -and @($Script:LastRunProfile.RollbackCommands).Count -gt 0)
	[void]($secondaryActionBar.Children.Add($BtnUndoLastRun))
	$Script:BtnUndoLastRun = $BtnUndoLastRun
	$undoLastRunStartCommand = Get-GuiRuntimeCommand -Name 'Start-GuiExecutionRun' -CommandType 'Function'
	$undoLastRunClearCommand = Get-GuiRuntimeCommand -Name 'Clear-GuiLastRunProfile' -CommandType 'Function'
	Register-GuiEventHandler -Source $BtnUndoLastRun -EventName 'Click' -Handler ({
		if (& $testGuiRunInProgressCapture) { return }
		$lastRunProfile = $Script:LastRunProfile
		if (-not $lastRunProfile -or -not (& $hasField -Object $lastRunProfile -FieldName 'RollbackCommands'))
		{
			Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiFooterUndoLastRun' -Fallback 'Undo Last Run') -Message (& $getUxLocalizedStringCapture -Key 'GuiActionUndoNoRun' -Fallback 'No previous run is available to undo.') -Buttons @('OK') -AccentButton 'OK'
			return
		}

		$rollbackCommands = @($lastRunProfile.RollbackCommands)
		if ($rollbackCommands.Count -eq 0)
		{
			Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiFooterUndoLastRun' -Fallback 'Undo Last Run') -Message (& $getUxLocalizedStringCapture -Key 'GuiActionUndoNoChanges' -Fallback 'No undoable changes were found in the last run.') -Buttons @('OK') -AccentButton 'OK'
			return
		}

		$timestampText = if ((& $hasField -Object $lastRunProfile -FieldName 'Timestamp') -and -not [string]::IsNullOrWhiteSpace([string]$lastRunProfile.Timestamp))
		{
			try { " from $(([datetime]$lastRunProfile.Timestamp).ToString('g'))" } catch { '' }
		}
		else { '' }

		$undoChangesLabel = (& $getUxLocalizedStringCapture -Key 'GuiActionUndoButton' -Fallback 'Undo Changes')
		$undoConfirmMsg = if ($rollbackCommands.Count -eq 1) { (& $getUxLocalizedStringCapture -Key 'GuiActionUndoConfirmSingular' -Fallback "This will undo {0} change{1}.`n`nDo you want to continue?") -f $rollbackCommands.Count, $timestampText } else { (& $getUxLocalizedStringCapture -Key 'GuiActionUndoConfirmPlural' -Fallback "This will undo {0} changes{1}.`n`nDo you want to continue?") -f $rollbackCommands.Count, $timestampText }
		$confirmResult = Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiFooterUndoLastRun' -Fallback 'Undo Last Run') `
			-Message $undoConfirmMsg `
			-Buttons @('Cancel', $undoChangesLabel) `
			-DestructiveButton $undoChangesLabel
		if ($confirmResult -ne $undoChangesLabel) { return }

		# Build tweak list from rollback commands
		$undoTweakList = [System.Collections.Generic.List[hashtable]]::new()
		$order = 0
		foreach ($commandLine in $rollbackCommands)
		{
			if ([string]::IsNullOrWhiteSpace([string]$commandLine)) { continue }
			$parts = ([string]$commandLine).Trim() -split '\s+', 2
			$functionName = $parts[0]
			$paramName = if ($parts.Count -gt 1) { $parts[1].TrimStart('-') } else { $null }
			if ([string]::IsNullOrWhiteSpace($functionName)) { continue }

			$manifestEntry = Get-ManifestEntryByFunction -Manifest $Script:TweakManifest -Function $functionName
			if (-not $manifestEntry) { continue }

			$order++
			$undoTweakList.Add(@{
				Key             = [string]$order
				Index           = $order
				Name            = [string]$manifestEntry.Name
				Function        = $functionName
				Type            = 'Toggle'
				TypeKind        = 'Toggle'
				TypeLabel       = 'Undo'
				TypeTone        = 'Caution'
				TypeBadgeLabel  = 'Undo'
				Category        = [string]$manifestEntry.Category
				Risk            = [string]$manifestEntry.Risk
				Restorable      = $manifestEntry.Restorable
				RecoveryLevel   = if ((& $hasField -Object $manifestEntry -FieldName 'RecoveryLevel')) { [string]$manifestEntry.RecoveryLevel } else { 'Direct' }
				RequiresRestart = [bool]$manifestEntry.RequiresRestart
				Impact          = $manifestEntry.Impact
				PresetTier      = $manifestEntry.PresetTier
				Selection       = if ($paramName) { $paramName } else { 'Undo' }
				ToggleParam     = $paramName
				OnParam         = [string]$manifestEntry.OnParam
				OffParam        = [string]$manifestEntry.OffParam
				IsChecked       = $true
				CurrentState    = (& $getUxLocalizedStringCapture -Key 'GuiActionUndoState' -Fallback 'Undoing previous change')
				CurrentStateTone = 'Caution'
				StateDetail     = (& $getUxLocalizedStringCapture -Key 'GuiActionUndoDetail' -Fallback 'Reverting to the state before the last run.')
				MatchesDesired  = $false
				ScenarioTags    = @()
				ReasonIncluded  = (& $getUxLocalizedStringCapture -Key 'GuiActionUndoReason' -Fallback 'Included as part of Undo Last Run.')
				BlastRadius     = ''
				IsRemoval       = $false
				ExtraArgs       = $null
				GamingPreviewGroup = $null
				TroubleshootingOnly = $false
			})
		}

		if ($undoTweakList.Count -eq 0)
		{
			Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiFooterUndoLastRun' -Fallback 'Undo Last Run') -Message (& $getUxLocalizedStringCapture -Key 'GuiActionUndoNoResolvable' -Fallback 'Could not resolve any undoable changes from the last run.') -Buttons @('OK') -AccentButton 'OK'
			return
		}

		LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogUndoLastRunReversing' -Fallback 'Undo Last Run: reversing {0} change(s).' -FormatArgs @($undoTweakList.Count))
		& $undoLastRunStartCommand -TweakList @($undoTweakList) -Mode 'Defaults' -ExecutionTitle (& $getUxLocalizedStringCapture -Key 'GuiActionUndoTitle' -Fallback 'Undoing Last Run')

		# Clear the last run profile after undo
		& $undoLastRunClearCommand
		$BtnUndoLastRun.IsEnabled = $false
	}.GetNewClosure()) | Out-Null

	# Resume Interrupted Run button
	$BtnResumeInterruptedRun = New-PresetButton -Label (Get-UxLocalizedString -Key 'GuiFooterResumeInterruptedRun' -Fallback 'Resume Interrupted Run') -Variant 'Secondary' -Compact
	$BtnResumeInterruptedRun.FontSize = $Script:GuiLayout.FontSizeSmall
	$BtnResumeInterruptedRun.ToolTip = (Get-UxLocalizedString -Key 'GuiActionResumeInterruptedTooltip' -Fallback 'Resume the remaining items from the most recent interrupted run')
	$BtnResumeInterruptedRun.IsEnabled = ($null -ne $Script:InterruptedRunProfile -and $Script:InterruptedRunProfile.PSObject.Properties['ResumeCandidates'] -and @($Script:InterruptedRunProfile.ResumeCandidates).Count -gt 0)
	[void]($secondaryActionBar.Children.Add($BtnResumeInterruptedRun))
	$Script:BtnResumeInterruptedRun = $BtnResumeInterruptedRun
	$resumeInterruptedStartCommand = Get-GuiRuntimeCommand -Name 'Start-GuiExecutionRun' -CommandType 'Function'
	$resumeInterruptedClearCommand = Get-GuiRuntimeCommand -Name 'Clear-GuiInterruptedRunProfile' -CommandType 'Function'
	Register-GuiEventHandler -Source $BtnResumeInterruptedRun -EventName 'Click' -Handler ({
		if (& $testGuiRunInProgressCapture) { return }
		$interruptedRunProfile = $Script:InterruptedRunProfile
		if (-not $interruptedRunProfile -or -not (& $hasField -Object $interruptedRunProfile -FieldName 'ResumeCandidates'))
		{
			Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiFooterResumeInterruptedRun' -Fallback 'Resume Interrupted Run') -Message (& $getUxLocalizedStringCapture -Key 'GuiActionResumeInterruptedNoRun' -Fallback 'No interrupted run is available to resume.') -Buttons @('OK') -AccentButton 'OK'
			return
		}

		$resumeCandidates = @($interruptedRunProfile.ResumeCandidates)
		if ($resumeCandidates.Count -eq 0)
		{
			Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiFooterResumeInterruptedRun' -Fallback 'Resume Interrupted Run') -Message (& $getUxLocalizedStringCapture -Key 'GuiActionResumeInterruptedNoChanges' -Fallback 'No resumable items were found in the interrupted run.') -Buttons @('OK') -AccentButton 'OK'
			return
		}

		$timestampText = if ((& $hasField -Object $interruptedRunProfile -FieldName 'Timestamp') -and -not [string]::IsNullOrWhiteSpace([string]$interruptedRunProfile.Timestamp))
		{
			try { " from $(([datetime]$interruptedRunProfile.Timestamp).ToString('g'))" } catch { '' }
		}
		else { '' }

		$resumeLabel = (& $getUxLocalizedStringCapture -Key 'GuiFooterResumeInterruptedRun' -Fallback 'Resume Interrupted Run')
		$resumeConfirmMsg = if ($resumeCandidates.Count -eq 1) { (& $getUxLocalizedStringCapture -Key 'GuiActionResumeInterruptedConfirmSingular' -Fallback "This will resume {0} interrupted item{1}.`n`nDo you want to continue?") -f $resumeCandidates.Count, $timestampText } else { (& $getUxLocalizedStringCapture -Key 'GuiActionResumeInterruptedConfirmPlural' -Fallback "This will resume {0} interrupted items{1}.`n`nDo you want to continue?") -f $resumeCandidates.Count, $timestampText }
		$confirmResult = Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiFooterResumeInterruptedRun' -Fallback 'Resume Interrupted Run') `
			-Message $resumeConfirmMsg `
			-Buttons @('Cancel', $resumeLabel) `
			-AccentButton $resumeLabel
		if ($confirmResult -ne $resumeLabel) { return }

		LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogResumeInterruptedRun' -Fallback 'Resuming interrupted run: Count={0}.' -FormatArgs @($resumeCandidates.Count))
		& $resumeInterruptedStartCommand -TweakList @($resumeCandidates) -Mode 'Run' -ExecutionTitle (& $getUxLocalizedStringCapture -Key 'GuiExecTitleResumingInterruptedRun' -Fallback 'Resuming Interrupted Run')

		& $resumeInterruptedClearCommand
		$BtnResumeInterruptedRun.IsEnabled = $false
	}.GetNewClosure()) | Out-Null

	# Check Compliance button
	$BtnCheckCompliance = New-PresetButton -Label (Get-UxLocalizedString -Key 'GuiFooterCheckCompliance' -Fallback 'Check Compliance') -Variant 'Subtle' -Compact -Muted
	$BtnCheckCompliance.FontSize = $Script:GuiLayout.FontSizeSmall
	$BtnCheckCompliance.ToolTip = (Get-UxLocalizedString -Key 'GuiActionComplianceTooltip' -Fallback 'Check current system state against a saved profile or snapshot for compliance drift.')
	[void]($secondaryActionBar.Children.Add($BtnCheckCompliance))
	$Script:BtnCheckCompliance = $BtnCheckCompliance
	$showComplianceDialogCommand = Get-GuiRuntimeCommand -Name 'Show-ComplianceDialog' -CommandType 'Function'
	Register-GuiEventHandler -Source $BtnCheckCompliance -EventName 'Click' -Handler ({
		if (& $testGuiRunInProgressCapture) { return }
		& $showComplianceDialogCommand
	}) | Out-Null

	# Audit Log button
	$BtnAuditLog = New-PresetButton -Label (Get-UxLocalizedString -Key 'GuiFooterAuditLog' -Fallback 'Audit Log') -Variant 'Subtle' -Compact -Muted
	$BtnAuditLog.FontSize = $Script:GuiLayout.FontSizeSmall
	$BtnAuditLog.ToolTip = (Get-UxLocalizedString -Key 'GuiActionAuditTooltip' -Fallback 'View the audit trail of all Baseline execution runs and compliance checks.')
	[void]($secondaryActionBar.Children.Add($BtnAuditLog))
	$Script:BtnAuditLog = $BtnAuditLog
	$showAuditLogDialogCommand = Get-GuiRuntimeCommand -Name 'Show-AuditLogDialog' -CommandType 'Function'
	Register-GuiEventHandler -Source $BtnAuditLog -EventName 'Click' -Handler ({
		& $showAuditLogDialogCommand
	}) | Out-Null

