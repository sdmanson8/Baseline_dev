	#region Theme toggle handler
	Register-GuiEventHandler -Source $ChkTheme -EventName 'Checked' -Handler ({
		Invoke-CapturedFunction -Name 'Set-GUITheme' -Parameters @{ Theme = $Script:LightTheme }
	}) | Out-Null
	Register-GuiEventHandler -Source $ChkTheme -EventName 'Unchecked' -Handler ({
		Invoke-CapturedFunction -Name 'Set-GUITheme' -Parameters @{ Theme = $Script:DarkTheme }
	}) | Out-Null
	if ($NavModeTweaks)
	{
		Register-GuiEventHandler -Source $NavModeTweaks -EventName 'Checked' -Handler ({
			Set-GuiAppsMode -Enable:$false
		}) | Out-Null
	}
	if ($NavModeApps)
	{
		Register-GuiEventHandler -Source $NavModeApps -EventName 'Checked' -Handler ({
			Set-GuiAppsMode -Enable:$true
		}) | Out-Null
	}
	#endregion

	#region Button handlers
		$getActiveTweakRunListCommand = Get-GuiRuntimeCommand -Name 'Get-ActiveTweakRunList' -CommandType 'Function'
		$showSelectedTweakPreviewCommand = Get-GuiRuntimeCommand -Name 'Show-SelectedTweakPreview' -CommandType 'Function'
		$setGuiStatusTextCommand = Get-GuiRuntimeCommand -Name 'Set-GuiStatusText' -CommandType 'Function'
		$confirmHighRiskTweakRunCommand = Get-GuiRuntimeCommand -Name 'Confirm-HighRiskTweakRun' -CommandType 'Function'
		$testIsGameModeRunCommand = Get-GuiRuntimeCommand -Name 'Test-IsGameModeRun' -CommandType 'Function'
		$getTweakSelectionSummaryCommand = Get-GuiRuntimeCommand -Name 'Get-TweakSelectionSummary' -CommandType 'Function'
		$getGameModeProfileCommand = Get-GuiRuntimeCommand -Name 'Get-GameModeProfile' -CommandType 'Function'
		$getGameModeDecisionOverridesTextCommand = Get-GuiRuntimeCommand -Name 'Get-GameModeDecisionOverridesText' -CommandType 'Function'
		$getGameModeDecisionOverridesCommand = Get-GuiRuntimeCommand -Name 'Get-GameModeDecisionOverrides' -CommandType 'Function'
		$createRestorePointCommand = Get-GuiRuntimeCommand -Name 'CreateRestorePoint' -CommandType 'Function'
		$startGuiExecutionRunCommand = Get-GuiRuntimeCommand -Name 'Start-GuiExecutionRun' -CommandType 'Function'
		$getWindowsDefaultRunListCommand = Get-GuiRuntimeCommand -Name 'Get-WindowsDefaultRunList' -CommandType 'Function'
		$showHelpDialogCommand = Get-GuiRuntimeCommand -Name 'Show-HelpDialog' -CommandType 'Function'
		$showThemedDialogCommand = Get-GuiRuntimeCommand -Name 'Show-ThemedDialog' -CommandType 'Function'
		$showReadmeDialogCommand = Get-GuiRuntimeCommand -Name 'Show-ReadmeDialog' -CommandType 'Function'
		$showGuiFaqDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiFaqDialog' -CommandType 'Function'
		$showUpdateCheckDialogCommand = Get-GuiRuntimeCommand -Name 'Show-BaselineUpdateCheckDialog' -CommandType 'Function'
		$showLogDialogCommand = Get-GuiRuntimeCommand -Name 'Show-LogDialog' -CommandType 'Function'
		$showChangelogDialogCommand = Get-GuiRuntimeCommand -Name 'Show-ChangelogDialog' -CommandType 'Function'
		$showGuiAuditSettingsDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiAuditSettingsDialog' -CommandType 'Function'
		$showGuiRemoteConsoleDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiRemoteConsoleDialog' -CommandType 'Function'
		$showGuiOperatorConsoleDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiOperatorConsoleDialog' -CommandType 'Function'
		$showGuiReleaseStatusDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiReleaseStatusDialog' -CommandType 'Function'
		$showGuiTroubleshootingGuideDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiTroubleshootingGuideDialog' -CommandType 'Function'
		$exportSupportBundleCommand = Get-GuiRuntimeCommand -Name 'Export-BaselineSupportBundle' -CommandType 'Function'
		$getGuiSettingsSnapshotCommand = Get-GuiRuntimeCommand -Name 'Get-GuiSettingsSnapshot' -CommandType 'Function'
		$getRemoteSessionSummaryCommand = Get-GuiRuntimeCommand -Name 'Get-BaselineRemoteSessionSummary' -CommandType 'Function'
		$promptRemoteTargetConnectionCommand = Get-GuiRuntimeCommand -Name 'Prompt-GuiRemoteTargetConnection' -CommandType 'Function'
		$getRemoteTargetContextCommand = Get-GuiRuntimeCommand -Name 'Get-GuiRemoteTargetContext' -CommandType 'Function'
		$setRemoteTargetContextCommand = Get-GuiRuntimeCommand -Name 'Set-GuiRemoteTargetContext' -CommandType 'Function'
		$setRemoteTargetApprovalCommand = Get-GuiRuntimeCommand -Name 'Set-GuiRemoteTargetApprovalList' -CommandType 'Function'
		$testRemoteTargetApprovalCommand = Get-GuiRuntimeCommand -Name 'Test-GuiRemoteTargetApproval' -CommandType 'Function'
		$exportRemoteTargetApprovalPolicyCommand = Get-GuiRuntimeCommand -Name 'Export-GuiRemoteTargetApprovalPolicy' -CommandType 'Function'
		$importRemoteTargetApprovalPolicyCommand = Get-GuiRuntimeCommand -Name 'Import-GuiRemoteTargetApprovalPolicy' -CommandType 'Function'
		$clearRemoteTargetContextCommand = Get-GuiRuntimeCommand -Name 'Clear-GuiRemoteTargetContext' -CommandType 'Function'
		$clearRemoteSessionCacheCommand = Get-GuiRuntimeCommand -Name 'Clear-BaselineRemoteSessionCache' -CommandType 'Function'
		$testRemoteTargetConnectedCommand = Get-GuiRuntimeCommand -Name 'Test-GuiRemoteTargetConnected' -CommandType 'Function'
		$getUxRunActionLabelCommand = Get-GuiRuntimeCommand -Name 'Get-UxRunActionLabel' -CommandType 'Function'
		$getUxPreviewButtonLabelCommand = Get-GuiRuntimeCommand -Name 'Get-UxPreviewButtonLabel' -CommandType 'Function'
		$getUxRestoreDefaultsConfirmationCommand = Get-GuiRuntimeCommand -Name 'Get-UxRestoreDefaultsConfirmation' -CommandType 'Function'
		$getUxLocalizedStringCapture = Get-GuiFunctionCapture -Name 'Get-UxLocalizedString'
		$getUxBilingualLocalizedStringCapture = Get-GuiFunctionCapture -Name 'Get-UxBilingualLocalizedString'
		if ($getUxBilingualLocalizedStringCapture)
		{
			Set-Item -Path function:Get-UxBilingualLocalizedString -Value $getUxBilingualLocalizedStringCapture
		}
		$testGuiRunInProgressCapture = $Script:TestGuiRunInProgressScript
		$startAppsCacheRefreshCommand = Get-GuiRuntimeCommand -Name 'Start-AppsCacheRefresh' -CommandType 'Function'
		$setAppPackageSourcePreferenceStateCommand = Get-GuiRuntimeCommand -Name 'Set-AppPackageSourcePreferenceState' -CommandType 'Function'
		$setAppSourceFilterStateCommand = Get-GuiRuntimeCommand -Name 'Set-AppSourceFilterState' -CommandType 'Function'
		$startAppsModuleActionAsyncCommand = Get-GuiRuntimeCommand -Name 'Start-AppsModuleActionAsync' -CommandType 'Function'
		$startAppsModuleBatchActionAsyncCommand = Get-GuiRuntimeCommand -Name 'Start-AppsModuleBatchActionAsync' -CommandType 'Function'
		$clearAppSelectionStateCommand = Get-GuiRuntimeCommand -Name 'Clear-AppSelectionState' -CommandType 'Function'
		$startAppsModuleQueuedActionAsyncCommand = Get-GuiRuntimeCommand -Name 'Start-AppsModuleQueuedActionAsync' -CommandType 'Function'
		$clearAppsQueuedActionsCommand = Get-GuiRuntimeCommand -Name 'Clear-AppsQueuedActions' -CommandType 'Function'
		$setAppQueuedActionCommand = Get-GuiRuntimeCommand -Name 'Set-AppQueuedAction' -CommandType 'Function'
		$getQueuedAppsProfileActionsCommand = Get-GuiRuntimeCommand -Name 'Get-QueuedAppsProfileActions' -CommandType 'Function'
		if (-not $startAppsCacheRefreshCommand) { throw 'Start-AppsCacheRefresh not found.' }
		if (-not $setAppPackageSourcePreferenceStateCommand) { throw 'Set-AppPackageSourcePreferenceState not found.' }
		if (-not $startAppsModuleActionAsyncCommand) { throw 'Start-AppsModuleActionAsync not found.' }
		if (-not $startAppsModuleBatchActionAsyncCommand) { throw 'Start-AppsModuleBatchActionAsync not found.' }
		if (-not $clearAppSelectionStateCommand) { throw 'Clear-AppSelectionState not found.' }
		if (-not $showGuiAuditSettingsDialogCommand) { throw 'Show-GuiAuditSettingsDialog not found.' }
		if (-not $showGuiRemoteConsoleDialogCommand) { throw 'Show-GuiRemoteConsoleDialog not found.' }
		if (-not $showGuiReleaseStatusDialogCommand) { throw 'Show-GuiReleaseStatusDialog not found.' }
		if (-not $showGuiTroubleshootingGuideDialogCommand) { throw 'Show-GuiTroubleshootingGuideDialog not found.' }
		if (-not $showGuiFaqDialogCommand) { throw 'Show-GuiFaqDialog not found.' }
		if (-not $exportRemoteTargetApprovalPolicyCommand)
		{
			LogWarning 'Export-GuiRemoteTargetApprovalPolicy not found; remote approval policy save actions will be disabled.'
			if ($MenuToolsSaveRemoteApprovalPolicy) { $MenuToolsSaveRemoteApprovalPolicy.IsEnabled = $false }
		}
		if (-not $importRemoteTargetApprovalPolicyCommand)
		{
			LogWarning 'Import-GuiRemoteTargetApprovalPolicy not found; remote approval policy load actions will be disabled.'
			if ($MenuToolsLoadRemoteApprovalPolicy) { $MenuToolsLoadRemoteApprovalPolicy.IsEnabled = $false }
		}
		Register-GuiEventHandler -Source $BtnPreviewRun -EventName 'Click' -Handler ({
			if ($Script:AppsModeActive) { return }
			if (& $testGuiRunInProgressCapture) { return }

		$tweakList = & $getActiveTweakRunListCommand
		if (-not $tweakList -or $tweakList.Count -eq 0) { return }

		$warningChoice = & $confirmHighRiskTweakRunCommand -SelectedTweaks $tweakList
		if (-not $warningChoice -or $warningChoice -eq 'Cancel') { return }

		$previewActionLabel = if ($getUxPreviewButtonLabelCommand) { & $getUxPreviewButtonLabelCommand } else { 'Preview Run' }
		$previewResult = $null
		switch ($warningChoice)
		{
			'PreviewRequired'
			{
				$previewResult = & $showSelectedTweakPreviewCommand -SelectedTweaks $tweakList -AllowApply
			}
			$previewActionLabel
			{
				$previewResult = & $showSelectedTweakPreviewCommand -SelectedTweaks $tweakList -AllowApply
			}
			'Preview Run'
			{
				$previewResult = & $showSelectedTweakPreviewCommand -SelectedTweaks $tweakList -AllowApply
			}
			'Continue Anyway'
			{
				$previewResult = & $showSelectedTweakPreviewCommand -SelectedTweaks $tweakList -AllowApply
			}
			'Create Restore Point'
			{
				$previewResult = & $showSelectedTweakPreviewCommand -SelectedTweaks $tweakList -AllowApply
			}
		}

		if ($previewResult -and $previewResult -eq (& $getUxRunActionLabelCommand))
		{
			try
			{
				& $startGuiExecutionRunCommand -TweakList $tweakList -Mode 'Run' -ExecutionTitle $(if (& $testIsGameModeRunCommand -TweakList $tweakList) { & $getUxLocalizedStringCapture -Key 'GuiExecTitleRunningGameMode' -Fallback 'Running Game Mode Workflow' } else { & $getUxLocalizedStringCapture -Key 'GuiExecTitleRunning' -Fallback 'Running Selected Tweaks' })
			}
			catch
			{
				$null = & $Script:ShowGuiRuntimeFailureScript -Context 'BtnPreviewRun' -Exception $_.Exception -ShowDialog
			}
			return
		}
	}) | Out-Null

		Register-GuiEventHandler -Source $BtnRun -EventName 'Click' -Handler ({
				if ($Script:AppsModeActive) { return }
			if ((& $testGuiRunInProgressCapture) -and $Script:RunState)
			{
				if ($Script:RunState['Paused'])
				{
					$Script:RunState['Paused'] = $false
					$BtnRun.Content = (& $getUxLocalizedStringCapture -Key 'GuiPauseButton' -Fallback 'Pause')
					& $setGuiStatusTextCommand -Text $(if ($Script:ExecutionMode -eq 'Defaults') { & $getUxLocalizedStringCapture -Key 'GuiStatusRestoringDefaults' -Fallback 'Restoring Windows defaults...' } else { & $getUxLocalizedStringCapture -Key 'GuiStatusRunningTweaks' -Fallback 'Running selected tweaks...' }) -Tone 'accent'
				}
				else
				{
					$Script:RunState['Paused'] = $true
					$BtnRun.Content = (& $getUxLocalizedStringCapture -Key 'GuiResumeButton' -Fallback 'Resume')
					& $setGuiStatusTextCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiRunPaused' -Fallback 'Run paused...') -Tone 'caution'
				}
				return
			}

			$tweakList = & $getActiveTweakRunListCommand
			if (-not $tweakList) { return }
			if ($tweakList.Count -eq 0)
			{
				$emptyRunMessage = if (Test-GuiModeActive -Mode 'Game') {
					(& $getUxLocalizedStringCapture -Key 'GuiActionEmptyRunGameMode' -Fallback 'Choose a Game Mode profile before starting a gaming run.')
				}
				else {
					(& $getUxLocalizedStringCapture -Key 'GuiActionEmptyRunNormal' -Fallback 'Select at least one tweak before starting a run.')
				}
				Show-ThemedDialog -Title $(if (Test-GuiModeActive -Mode 'Game') { & $getUxLocalizedStringCapture -Key 'GuiGameModeHeader' -Fallback 'Game Mode' } else { & $getUxRunActionLabelCommand }) `
					-Message $emptyRunMessage `
					-Buttons @('OK') `
					-AccentButton 'OK'
				return
			}

			$isGameModeRun = & $testIsGameModeRunCommand -TweakList $tweakList
			if ($isGameModeRun)
			{
				$runSummary = & $getTweakSelectionSummaryCommand -SelectedTweaks $tweakList
				LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogGameModeRunRequested' -Fallback 'Game Mode run requested: Profile={0}, Actions={1}, RestorePointRecommended={2}, Decisions={3}' -FormatArgs @((& $getGameModeProfileCommand), $tweakList.Count, $runSummary.ShouldRecommendRestorePoint, (& $getGameModeDecisionOverridesTextCommand -Overrides (& $getGameModeDecisionOverridesCommand))))
			}

			# Plan Summary: show pre-run overview with pre-flight checks (including restore point)
			$planPreflightResults = $null
			try { $planPreflightResults = Invoke-PreflightChecks } catch { $planPreflightResults = $null }
			$planChoice = Show-PlanSummaryDialog -SelectedTweaks $tweakList -PreflightResults $planPreflightResults
			if ($planChoice -ne 'Run Tweaks')
			{
				if ($isGameModeRun)
				{
					LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogGameModeRunCancelled' -Fallback 'Game Mode run cancelled from plan summary.')
				}
				return
			}

			# Restore point creation is now handled by the pre-flight checks system.
			# See Test-PreflightRestorePointCreation in PreflightChecks.ps1.

			try
			{
				& $startGuiExecutionRunCommand -TweakList $tweakList -Mode 'Run' -ExecutionTitle $(if (& $testIsGameModeRunCommand -TweakList $tweakList) { & $getUxLocalizedStringCapture -Key 'GuiExecTitleRunningGameMode' -Fallback 'Running Game Mode Workflow' } else { & $getUxLocalizedStringCapture -Key 'GuiExecTitleRunning' -Fallback 'Running Selected Tweaks' })
			}
			catch
			{
				$null = & $Script:ShowGuiRuntimeFailureScript -Context 'BtnRun' -Exception $_.Exception -ShowDialog
			}
		}) | Out-Null

		if ($BtnUpdateAllApps)
		{
			Register-GuiEventHandler -Source $BtnUpdateAllApps -EventName 'Click' -Handler ({
				if ($Script:AppsModeActive)
				{
					$confirmation = Show-ThemedDialog -Title (Get-UxLocalizedString -Key 'GuiUpdateAllAppsConfirmTitle' -Fallback 'Update All Installed Apps') `
						-Message (Get-UxLocalizedString -Key 'GuiUpdateAllAppsConfirmMessage' -Fallback 'Are you sure you want to update all installed apps?') `
						-Buttons @('Cancel', 'Update All') `
						-AccentButton 'Update All'
					if ($confirmation -ne 'Update All') { return }
					try
					{
						& $startAppsModuleActionAsyncCommand -Action 'UpdateAll'
					}
					catch
					{
						$null = & $Script:ShowGuiRuntimeFailureScript -Context 'BtnUpdateAllApps' -Exception $_.Exception -ShowDialog
					}
				}
			}) | Out-Null
		}

		# Source filter pills are RadioButtons in one group, so we still route
		# clicks through Set-AppSourceFilterState to keep the source filter state
		# normalized and to refresh the app list consistently.
		if ($BtnAppsSourceFilterAll)
		{
			Register-GuiEventHandler -Source $BtnAppsSourceFilterAll -EventName 'Click' -Handler ({
				if (-not $Script:AppsModeActive -or $Script:AppsSourceFilterUiUpdating) { return }
				if ([string]$Script:AppsSourceFilter -eq 'All')
				{
					$Script:AppsSourceFilterUiUpdating = $true
					try { $Script:BtnAppsSourceFilterAll.IsChecked = $true } finally { $Script:AppsSourceFilterUiUpdating = $false }
					return
				}
				& $setAppSourceFilterStateCommand -Source 'All'
			}) | Out-Null
		}

		if ($BtnAppsSourceFilterWinGet)
		{
			Register-GuiEventHandler -Source $BtnAppsSourceFilterWinGet -EventName 'Click' -Handler ({
				if (-not $Script:AppsModeActive -or $Script:AppsSourceFilterUiUpdating) { return }
				if ([string]$Script:AppsSourceFilter -eq 'winget')
				{
					$Script:AppsSourceFilterUiUpdating = $true
					try { $Script:BtnAppsSourceFilterWinGet.IsChecked = $true } finally { $Script:AppsSourceFilterUiUpdating = $false }
					return
				}
				& $setAppSourceFilterStateCommand -Source 'winget'
			}) | Out-Null
		}

		if ($BtnAppsSourceFilterChocolatey)
		{
			Register-GuiEventHandler -Source $BtnAppsSourceFilterChocolatey -EventName 'Click' -Handler ({
				if (-not $Script:AppsModeActive -or $Script:AppsSourceFilterUiUpdating) { return }
				if ([string]$Script:AppsSourceFilter -eq 'choco')
				{
					$Script:AppsSourceFilterUiUpdating = $true
					try { $Script:BtnAppsSourceFilterChocolatey.IsChecked = $true } finally { $Script:AppsSourceFilterUiUpdating = $false }
					return
				}
				& $setAppSourceFilterStateCommand -Source 'choco'
			}) | Out-Null
		}

		if ($BtnAppsViewCards)
		{
			Register-GuiEventHandler -Source $BtnAppsViewCards -EventName 'Click' -Handler ({
				if ($Script:AppsViewModeUiUpdating) { return }
				if ([string]$Script:AppsViewMode -eq 'Cards')
				{
					$Script:AppsViewModeUiUpdating = $true
					try { $Script:BtnAppsViewCards.IsChecked = $true } finally { $Script:AppsViewModeUiUpdating = $false }
					return
				}
				$Script:AppsViewMode = 'Cards'
				$Script:AppsViewBuildSignature = $null
				if (Get-Command -Name 'Update-AppsViewModeControls' -CommandType Function -ErrorAction SilentlyContinue)
				{
					Update-AppsViewModeControls
				}
				if ($Script:AppsModeActive -and (Get-Command -Name 'Build-AppsViewCards' -CommandType Function -ErrorAction SilentlyContinue))
				{
					Build-AppsViewCards
				}
			}) | Out-Null
		}

		if ($BtnAppsViewList)
		{
			Register-GuiEventHandler -Source $BtnAppsViewList -EventName 'Click' -Handler ({
				if ($Script:AppsViewModeUiUpdating) { return }
				if ([string]$Script:AppsViewMode -eq 'List')
				{
					$Script:AppsViewModeUiUpdating = $true
					try { $Script:BtnAppsViewList.IsChecked = $true } finally { $Script:AppsViewModeUiUpdating = $false }
					return
				}
				$Script:AppsViewMode = 'List'
				$Script:AppsViewBuildSignature = $null
				if (Get-Command -Name 'Update-AppsViewModeControls' -CommandType Function -ErrorAction SilentlyContinue)
				{
					Update-AppsViewModeControls
				}
				if ($Script:AppsModeActive -and (Get-Command -Name 'Build-AppsViewCards' -CommandType Function -ErrorAction SilentlyContinue))
				{
					Build-AppsViewCards
				}
			}) | Out-Null
		}

		if ($BtnInstallSelectedApps)
		{
			Register-GuiEventHandler -Source $BtnInstallSelectedApps -EventName 'Click' -Handler ({
				if (-not $Script:AppsModeActive) { return }
				if (-not $Script:SelectedAppIds) { return }
				foreach ($id in @($Script:SelectedAppIds))
				{
					if ([string]::IsNullOrWhiteSpace([string]$id)) { continue }
					try { Set-AppQueuedAction -AppId $id -Action 'Install' } catch { $null = $_ }
				}
			}) | Out-Null
		}

		if ($BtnUninstallSelectedApps)
		{
			Register-GuiEventHandler -Source $BtnUninstallSelectedApps -EventName 'Click' -Handler ({
				if (-not $Script:AppsModeActive) { return }
				if (-not $Script:SelectedAppIds) { return }
				foreach ($id in @($Script:SelectedAppIds))
				{
					if ([string]::IsNullOrWhiteSpace([string]$id)) { continue }
					try { Set-AppQueuedAction -AppId $id -Action 'Uninstall' } catch { $null = $_ }
				}
			}) | Out-Null
		}

		if ($BtnUpdateSelectedApps)
		{
			Register-GuiEventHandler -Source $BtnUpdateSelectedApps -EventName 'Click' -Handler ({
				if (-not $Script:AppsModeActive) { return }
				if (-not $Script:SelectedAppIds) { return }
				foreach ($id in @($Script:SelectedAppIds))
				{
					if ([string]::IsNullOrWhiteSpace([string]$id)) { continue }
					try { Set-AppQueuedAction -AppId $id -Action 'Update' } catch { $null = $_ }
				}
			}) | Out-Null
		}

		if ($BtnScanInstalledApps)
		{
			Register-GuiEventHandler -Source $BtnScanInstalledApps -EventName 'Click' -Handler ({
				if (-not $Script:AppsModeActive) { return }
				try
				{
					& $startAppsCacheRefreshCommand
				}
				catch
				{
					$null = & $Script:ShowGuiRuntimeFailureScript -Context 'BtnScanInstalledApps' -Exception $_.Exception -ShowDialog
				}
			}) | Out-Null
		}

		# Per-app queued-action apply button: executes the Install/Uninstall queue that
		# individual app rows can populate via Set-AppQueuedAction.
		if ($BtnApplyQueuedActions)
		{
			Register-GuiEventHandler -Source $BtnApplyQueuedActions -EventName 'Click' -Handler ({
				if (-not $Script:AppsModeActive) { return }
				if ($startAppsModuleQueuedActionAsyncCommand)
				{
					& $startAppsModuleQueuedActionAsyncCommand
				}
			}) | Out-Null
		}

		# Reset: clear queued actions and uncheck all selected apps in one go.
		if ($BtnClearQueuedActions)
		{
			Register-GuiEventHandler -Source $BtnClearQueuedActions -EventName 'Click' -Handler ({
				if (-not $Script:AppsModeActive) { return }
				if ($clearAppsQueuedActionsCommand) { & $clearAppsQueuedActionsCommand }
				if ($clearAppSelectionStateCommand) { & $clearAppSelectionStateCommand }
			}) | Out-Null
		}

	Register-GuiEventHandler -Source $BtnDefaults -EventName 'Click' -Handler ({
			# Confirmation dialog for destructive action - wording adapts to current UX mode
			$restoreUx = & $getUxRestoreDefaultsConfirmationCommand
		$result = Show-ThemedDialog -Title $restoreUx.Title `
			-Message $restoreUx.Message `
			-Buttons $restoreUx.Buttons `
			-DestructiveButton $restoreUx.DestructiveButton
		if ($result -ne 'Restore Defaults') { return }

			$defaultsTweakList = & $getWindowsDefaultRunListCommand
			if ($defaultsTweakList.Count -eq 0)
			{
				Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiBtnDefaults' -Fallback 'Restore to Windows Defaults') `
					-Message (& $getUxLocalizedStringCapture -Key 'GuiActionRestoreDefaultsNoTweaks' -Fallback 'No restorable tweaks with Windows default actions are currently available.') `
					-Buttons @('OK') `
					-AccentButton 'OK'
				return
			}

			try
			{
				& $startGuiExecutionRunCommand -TweakList $defaultsTweakList -Mode 'Defaults' -ExecutionTitle (& $getUxLocalizedStringCapture -Key 'GuiExecTitleRestoringDefaults' -Fallback 'Restoring Windows Defaults')
			}
			catch
			{
				$null = & $Script:ShowGuiRuntimeFailureScript -Context 'BtnDefaults' -Exception $_.Exception -ShowDialog
			}
		}) | Out-Null

	# Per-page "Reset to defaults" buttons.
	# Each button must be named BtnPageReset_<CategoryName> in the XAML, or the
	# page view can call Invoke-PageResetToDefaults with the category string.
	# Here we register a generic handler factory so any button following the
	# BtnPageReset_* naming convention is wired automatically.
	$getCategoryDefaultRunListCommand = Get-GuiRuntimeCommand -Name 'Get-CategoryDefaultRunList' -CommandType 'Function'
	if ($getCategoryDefaultRunListCommand)
	{
		foreach ($pageResetButton in @($Script:Controls | Where-Object { $_ -and $_.Name -match '^BtnPageReset_' }))
		{
			$pageCategory = $pageResetButton.Name -replace '^BtnPageReset_', '' -replace '_', ' '
			$capturedButton = $pageResetButton
			$capturedCategory = $pageCategory
			Register-GuiEventHandler -Source $capturedButton -EventName 'Click' -Handler ([scriptblock]::Create("
				param ()
				\$categoryTweakList = & \$getCategoryDefaultRunListCommand -Category '$($capturedCategory -replace "'", "''")'
				if (-not \$categoryTweakList -or \$categoryTweakList.Count -eq 0)
				{
					Show-ThemedDialog -Title 'Reset to Defaults' -Message 'No restorable tweaks with Windows default values found for this page.' -Buttons @('OK') -AccentButton 'OK'
					return
				}
				\$result = Show-ThemedDialog -Title 'Reset page to defaults' -Message ('Reset ' + '$capturedCategory' + ' (' + \$categoryTweakList.Count + ' tweaks) to Windows defaults?') -Buttons @('Cancel','Reset to Defaults') -DestructiveButton 'Reset to Defaults'
				if (\$result -ne 'Reset to Defaults') { return }
				& \$startGuiExecutionRunCommand -TweakList \$categoryTweakList -Mode 'Defaults' -ExecutionTitle ('Resetting ' + '$capturedCategory' + ' to defaults')
			")) | Out-Null
		}
	}

	# Public helper: call this from any page/tab to trigger a category-scoped
	# defaults restore without needing a named button.
	<#
	    .SYNOPSIS
	    Internal function Invoke-PageResetToDefaults.
	#>

	function Invoke-PageResetToDefaults
	{
		[CmdletBinding()]
		param (
			[Parameter(Mandatory)]
			[string]$Category
		)

		$tweakList = if ($getCategoryDefaultRunListCommand) { & $getCategoryDefaultRunListCommand -Category $Category } else { @() }
		if (-not $tweakList -or $tweakList.Count -eq 0)
		{
			Show-ThemedDialog -Title 'Reset to Defaults' -Message "No restorable tweaks with Windows default values found for '$Category'." -Buttons @('OK') -AccentButton 'OK'
			return
		}
		$result = Show-ThemedDialog -Title 'Reset page to defaults' `
			-Message "Reset $Category ($($tweakList.Count) tweaks) to Windows defaults?" `
			-Buttons @('Cancel', 'Reset to Defaults') `
			-DestructiveButton 'Reset to Defaults'
		if ($result -ne 'Reset to Defaults') { return }
		& $startGuiExecutionRunCommand -TweakList $tweakList -Mode 'Defaults' -ExecutionTitle "Resetting $Category to defaults"
	}

	Register-GuiEventHandler -Source $BtnHelp -EventName 'Click' -Handler ({
		& $showHelpDialogCommand
		& $setGuiStatusTextCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiHelpOpened' -Fallback 'Help opened.') -Tone 'accent'
	}) | Out-Null

	if ($BtnStartHere)
	{
		$startHereShowThemedDialogCommand = Get-GuiRuntimeCommand -Name 'Show-ThemedDialog' -CommandType 'Function'
		$startHereShowHelpDialogCommand = Get-GuiRuntimeCommand -Name 'Show-HelpDialog' -CommandType 'Function'
		$startHereSetGuiPresetSelectionCommand = Get-GuiRuntimeCommand -Name 'Set-GuiPresetSelection' -CommandType 'Function'
		$startHereGetRecommendedPresetCommand = Get-GuiRuntimeCommand -Name 'Get-UxRecommendedPresetName' -CommandType 'Function'
		$startHereGetPresetLoadedStatusTextCommand = Get-GuiRuntimeCommand -Name 'Get-UxPresetLoadedStatusText' -CommandType 'Function'
		$startHereGetPrimaryActionLabelCommand = Get-GuiRuntimeCommand -Name 'Get-UxFirstRunPrimaryActionLabel' -CommandType 'Function'
		$startHereGetDialogTitleCommand = Get-GuiRuntimeCommand -Name 'Get-UxFirstRunDialogTitle' -CommandType 'Function'
		$startHereGetOpenHelpActionLabelCommand = Get-GuiRuntimeCommand -Name 'Get-UxOpenHelpActionLabel' -CommandType 'Function'
		$startHereGetWelcomeMessageCommand = Get-GuiRuntimeCommand -Name 'Get-UxFirstRunWelcomeMessage' -CommandType 'Function'
		$startHereGuidedSetupWizardCommand = Get-GuiRuntimeCommand -Name 'Show-GuidedSetupWizard' -CommandType 'Function'
		if (-not $startHereShowThemedDialogCommand) { throw "Show-ThemedDialog not found." }
		if (-not $startHereShowHelpDialogCommand) { throw "Show-HelpDialog not found." }
		if (-not $startHereSetGuiPresetSelectionCommand) { throw "Set-GuiPresetSelection not found." }
		if (-not $startHereGetRecommendedPresetCommand) { throw "Get-UxRecommendedPresetName not found." }
		if (-not $startHereGetPresetLoadedStatusTextCommand) { throw "Get-UxPresetLoadedStatusText not found." }
		if (-not $startHereGetPrimaryActionLabelCommand) { throw "Get-UxFirstRunPrimaryActionLabel not found." }
		if (-not $startHereGetWelcomeMessageCommand) { throw "Get-UxFirstRunWelcomeMessage not found." }
		Register-GuiEventHandler -Source $BtnStartHere -EventName 'Click' -Handler ({
			$recommendedPreset   = & $startHereGetRecommendedPresetCommand
			$chooseButton        = & $startHereGetPrimaryActionLabelCommand
			$dialogTitle         = if ($startHereGetDialogTitleCommand) { & $startHereGetDialogTitleCommand } else { (& $getUxLocalizedStringCapture -Key 'GuiFirstRunDialogTitle' -Fallback 'Welcome to Baseline') }
			$openHelpActionLabel = if ($startHereGetOpenHelpActionLabelCommand) { & $startHereGetOpenHelpActionLabelCommand } else { (& $getUxLocalizedStringCapture -Key 'GuiOpenHelpActionLabel' -Fallback 'Open Help') }
			$welcomeMessage      = & $startHereGetWelcomeMessageCommand
			$closeLabel          = & $getUxLocalizedStringCapture -Key 'GuiCloseButton' -Fallback 'Close'
			$guidedSetupLabel    = & $getUxLocalizedStringCapture -Key 'GuiGuidedSetupButton' -Fallback 'Guided Setup'

			$choice = & $startHereShowThemedDialogCommand -Title $dialogTitle `
				-Message $welcomeMessage `
				-Buttons @($closeLabel, $openHelpActionLabel, $chooseButton, $guidedSetupLabel) `
				-AccentButton $guidedSetupLabel

			if ([string]::IsNullOrWhiteSpace([string]$choice) -or [string]$choice -eq $closeLabel)
			{
				& $setGuiStatusTextCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiActionStartGuideClosed' -Fallback 'Start guide closed.') -Tone 'muted'
				return
			}

			if ([string]$choice -eq [string]$openHelpActionLabel)
			{
				& $startHereShowHelpDialogCommand
				return
			}

			if ([string]$choice -eq [string]$guidedSetupLabel -and $startHereGuidedSetupWizardCommand)
			{
				& $startHereGuidedSetupWizardCommand `
					-ShowThemedDialogCapture $startHereShowThemedDialogCommand `
					-SetGuiPresetSelectionAction { param($PresetName) & $startHereSetGuiPresetSelectionCommand -PresetName $PresetName } `
					-SetGuiStatusTextAction { param($Text, $Tone) & $setGuiStatusTextCommand -Text $Text -Tone $Tone } `
					-Theme $Script:CurrentTheme `
					-ApplyButtonChrome ${function:Set-ButtonChrome} `
					-OwnerWindow $Script:MainForm `
					-UseDarkMode ($Script:CurrentThemeName -eq 'Dark')
				return
			}

			if ([string]$choice -eq [string]$chooseButton)
			{
				if ([bool]$Script:GameMode)
				{
					$gamingTab = Get-PrimaryTabItem -Tag 'Gaming'
					if ($gamingTab -and $PrimaryTabs)
					{
						$PrimaryTabs.SelectedItem = $gamingTab
					}
					& $setGuiStatusTextCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiActionGameModeActive' -Fallback 'Game Mode active. Review the gaming plan, then use Preview Run before Run Tweaks.') -Tone 'accent'
				}
				else
				{
					& $startHereSetGuiPresetSelectionCommand -PresetName $recommendedPreset
					$presetLoadedStatusText = & $startHereGetPresetLoadedStatusTextCommand -PresetName $recommendedPreset
					& $setGuiStatusTextCommand -Text $presetLoadedStatusText -Tone 'accent'
				}
			}
		}.GetNewClosure()) | Out-Null
	}

	Register-GuiEventHandler -Source $BtnLog -EventName 'Click' -Handler ({
		$logPath = $Global:LogFilePath
		if ($logPath -and (Test-Path -LiteralPath $logPath -ErrorAction SilentlyContinue))
		{
			& $showLogDialogCommand -LogPath $logPath
		}
		else
		{
			Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiBtnLog' -Fallback 'Open Log') `
				-Message ((& $getUxLocalizedStringCapture -Key 'GuiActionLogNotFound' -Fallback "Log file not found.`n{0}") -f $logPath) `
				-Buttons @('OK') `
				-AccentButton 'OK'
		}
	}) | Out-Null
	#endregion Button handlers

	#region System scan state
	$buildTabContentCommand = Get-GuiRuntimeCommand -Name 'Build-TabContent' -CommandType 'Function'
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
	    Internal function Sync-UxActionButtonText.
	#>

	function Sync-UxActionButtonText
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		if ($Script:AppsModeActive)
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
			$btnRunContent = [string]$Script:BtnRun.Content
			if ($btnRunContent -notin @('Pause', 'Resume', 'Stopping...', 'Exiting...'))
			{
				Set-GuiButtonIconContent -Button $Script:BtnRun -IconName 'RunTweaks' -Text (Get-UxRunActionLabel) -ToolTip (Get-UxRunActionToolTip)
			}
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
	    Internal function Update-RunPathContextLabel.
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
				try { $Script:RunPathContextLabel.Foreground = $Script:SharedBrushConverter.ConvertFromString([string]$toneColor) } catch { }
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
			LogError (Get-UxBilingualLocalizedString -Key 'GuiLogRestoreSnapshotFailed' -Fallback 'Failed to restore GUI snapshot: {0}' -FormatArgs @($_.Exception.Message))
			[void](Show-ThemedDialog -Title (& $getUxUndoSelectionActionLabelCommand) -Message $(if (& $testIsSafeModeUxCommand) { (& $getUxLocalizedStringCapture -Key 'GuiActionUndoFailedSafe' -Fallback "Failed to undo the previous selection change.`n`n{0}") -f $_.Exception.Message } else { (& $getUxLocalizedStringCapture -Key 'GuiActionUndoFailed' -Fallback "Failed to restore the previous snapshot.`n`n{0}") -f $_.Exception.Message }) -Buttons @('OK') -AccentButton 'OK')
			return
		}

		& $setGuiStatusTextCommand -Text $(if (& $testIsSafeModeUxCommand) { & $getUxLocalizedStringCapture -Key 'GuiActionUndoSuccessSafe' -Fallback 'Last selection change undone.' } else { & $getUxLocalizedStringCapture -Key 'GuiActionUndoSuccess' -Fallback 'Previous GUI snapshot restored.' }) -Tone 'accent'
		LogInfo $(if (& $testIsSafeModeUxCommand) { (Get-UxBilingualLocalizedString -Key 'GuiLogUndoSnapshotSafe' -Fallback 'Undid previous GUI selection change via snapshot restore.') } else { (Get-UxBilingualLocalizedString -Key 'GuiLogUndoSnapshot' -Fallback 'Restored previous GUI snapshot') })
	}) | Out-Null

	# Capture file-dialog function for use inside .GetNewClosure() handlers
	# (.GetNewClosure() captures variables but not functions from the parent scope).
		$showGuiFileSaveDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiFileSaveDialog' -CommandType 'Function'

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
			LogError (Get-UxBilingualLocalizedString -Key 'GuiLogExportSystemStateFailed' -Fallback 'Failed to export system state: {0}' -FormatArgs @($_.Exception.Message))
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
			try { $baselineVersion = Get-BaselineDisplayVersion } catch { }
			if ([string]::IsNullOrWhiteSpace($baselineVersion)) { $baselineVersion = 'unknown' }

			$profile = New-ConfigurationProfile `
				-Name ('Baseline-Profile-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss')) `
				-Selections @($tweakList) `
				-AppActions @($queuedAppActions) `
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
			LogError (Get-UxBilingualLocalizedString -Key 'GuiLogExportConfigProfileFailed' -Fallback 'Failed to export configuration profile: {0}' -FormatArgs @($_.Exception.Message))
			[void](Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiActionExportProfileTitle' -Fallback 'Export Configuration Profile') -Message ((& $getUxLocalizedStringCapture -Key 'GuiActionExportProfileFailed' -Fallback "Failed to export configuration profile.`n`n{0}") -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
	}
	}.GetNewClosure()) | Out-Null

	# Export Support Bundle action
	if ($MenuToolsExportSupportBundle)
	{
		Register-GuiEventHandler -Source $MenuToolsExportSupportBundle -EventName 'Click' -Handler ({
			if (& $testGuiRunInProgressCapture) { return }
			try
			{
				$defaultFileName = 'Baseline-SupportBundle-{0}.zip' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
				$savePath = & $showGuiFileSaveDialogCommand -Title 'Export Support Bundle' `
					-Filter 'ZIP Files (*.zip)|*.zip|All Files (*.*)|*.*' `
					-DefaultExtension 'zip' `
					-FileName $defaultFileName
				if ([string]::IsNullOrWhiteSpace($savePath))
				{
					return
				}

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

					$result = & $exportSupportBundleCommand -OutputPath $savePath -ProfilePath $sessionStatePath -SystemSnapshot $systemSnapshot -Manifest $Script:TweakManifest -IncludeAuditLog -IncludeTestReport
					& $setGuiStatusTextCommand -Text ("Support bundle exported: {0}" -f $result.OutputPath) -Tone 'success'
					LogInfo ("Exported support bundle to {0}" -f $result.OutputPath)
				}
				finally
				{
					if (Test-Path -LiteralPath $sessionStatePath)
					{
						try { Remove-Item -LiteralPath $sessionStatePath -Force -ErrorAction SilentlyContinue } catch { }
					}
				}
			}
			catch
			{
				LogError (Get-UxBilingualLocalizedString -Key 'GuiLogExportSupportBundleFailed' -Fallback 'Failed to export support bundle: {0}' -FormatArgs @($_.Exception.Message))
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
				LogError (Get-UxBilingualLocalizedString -Key 'GuiLogRemoteTargetApprovalFailed' -Fallback 'Failed to approve remote target list: {0}' -FormatArgs @($_.Exception.Message))
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
				LogError (Get-UxBilingualLocalizedString -Key 'GuiLogRemoteTargetApprovalPolicySaveFailed' -Fallback 'Failed to save remote approval policy: {0}' -FormatArgs @($_.Exception.Message))
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
				LogError (Get-UxBilingualLocalizedString -Key 'GuiLogRemoteTargetApprovalPolicyLoadFailed' -Fallback 'Failed to load remote approval policy: {0}' -FormatArgs @($_.Exception.Message))
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
				LogError (Get-UxBilingualLocalizedString -Key 'GuiLogRemoteConsoleFailed' -Fallback 'Failed to open remote console: {0}' -FormatArgs @($_.Exception.Message))
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
				LogError (Get-UxBilingualLocalizedString -Key 'GuiLogOperatorConsoleFailed' -Fallback 'Failed to open operator console: {0}' -FormatArgs @($_.Exception.Message))
				[void](Show-ThemedDialog -Title 'Operator Console' -Message ("Failed to open operator console.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
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
				LogError (Get-UxBilingualLocalizedString -Key 'GuiLogRemoteSessionStatusFailed' -Fallback 'Failed to view remote session status: {0}' -FormatArgs @($_.Exception.Message))
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
		if (-not $lastRunProfile -or -not (Test-GuiObjectField -Object $lastRunProfile -FieldName 'RollbackCommands'))
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

		$timestampText = if ((Test-GuiObjectField -Object $lastRunProfile -FieldName 'Timestamp') -and -not [string]::IsNullOrWhiteSpace([string]$lastRunProfile.Timestamp))
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
				RecoveryLevel   = if ((Test-GuiObjectField -Object $manifestEntry -FieldName 'RecoveryLevel')) { [string]$manifestEntry.RecoveryLevel } else { 'Direct' }
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
		if (-not $interruptedRunProfile -or -not (Test-GuiObjectField -Object $interruptedRunProfile -FieldName 'ResumeCandidates'))
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

		$timestampText = if ((Test-GuiObjectField -Object $interruptedRunProfile -FieldName 'Timestamp') -and -not [string]::IsNullOrWhiteSpace([string]$interruptedRunProfile.Timestamp))
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

	#region Top Menu Bar handlers
	# Menu items route to existing buttons by raising their Click event, reusing all existing logic.
	$raiseButtonClick = {
		param($Button)
		if ($null -eq $Button) { return }
		try
		{
			if (-not $Button.IsEnabled) { return }
			$evt = [System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)
			$Button.RaiseEvent($evt)
		}
		catch
		{
			try { LogWarning ("Menu click routing failed: {0}" -f $_.Exception.Message) } catch { }
		}
	}

	# File menu
	if ($MenuFileImportSettings)
	{
		Register-GuiEventHandler -Source $MenuFileImportSettings -EventName 'Click' -Handler ({
			& $raiseButtonClick $Script:BtnImportSettings
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuFileExportSettings)
	{
		Register-GuiEventHandler -Source $MenuFileExportSettings -EventName 'Click' -Handler ({
			& $raiseButtonClick $Script:BtnExportSettings
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuFileAuditSettings)
	{
		Register-GuiEventHandler -Source $MenuFileAuditSettings -EventName 'Click' -Handler ({
			if (& $testGuiRunInProgressCapture) { return }
			try
			{
				$initialRetentionDays = if ($Script:AuditRetentionDays) { [int]$Script:AuditRetentionDays } else { 90 }
				$selectedRetentionDays = & $showGuiAuditSettingsDialogCommand -InitialRetentionDays $initialRetentionDays
				if ($null -eq $selectedRetentionDays) { return }

				$Script:AuditRetentionDays = [int]$selectedRetentionDays
				if ($Script:Ctx -and $Script:Ctx.UI)
				{
					$Script:Ctx.UI.AuditRetentionDays = [int]$selectedRetentionDays
				}
				& $setGuiStatusTextCommand -Text ("Audit settings saved. Retention window: {0} day(s)." -f [int]$selectedRetentionDays) -Tone 'success'
				LogInfo ("Updated audit retention window via GUI: {0} day(s)" -f [int]$selectedRetentionDays)
			}
			catch
			{
				LogError (Get-UxBilingualLocalizedString -Key 'GuiLogAuditSettingsFailed' -Fallback 'Failed to update audit settings: {0}' -FormatArgs @($_.Exception.Message))
				[void](Show-ThemedDialog -Title 'Audit Settings' -Message ("Failed to update audit settings.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
			}
		}) | Out-Null
	}
	if ($MenuFileExportConfigProfile)
	{
		Register-GuiEventHandler -Source $MenuFileExportConfigProfile -EventName 'Click' -Handler ({
			& $raiseButtonClick $Script:BtnExportConfigProfile
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuFileExportSystemState)
	{
		Register-GuiEventHandler -Source $MenuFileExportSystemState -EventName 'Click' -Handler ({
			& $raiseButtonClick $Script:BtnExportSystemState
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuFileExit)
	{
		Register-GuiEventHandler -Source $MenuFileExit -EventName 'Click' -Handler ({
			try { $Script:MainForm.Close() } catch { }
		}) | Out-Null
	}

	# Actions menu
	if ($MenuActionsConnectToComputer)
	{
		Register-GuiEventHandler -Source $MenuActionsConnectToComputer -EventName 'Click' -Handler ({
			if (& $testGuiRunInProgressCapture) { return }
			try
			{
				$connectionRequest = & $promptRemoteTargetConnectionCommand
				if (-not $connectionRequest) { return }
				$context = & $setRemoteTargetContextCommand -ComputerName $connectionRequest.ComputerName -Credential $connectionRequest.Credential -StatusMessage 'Remote target connected.'
				$targetLabel = if ($context.TargetComputers.Count -gt 0) { $context.TargetComputers -join ', ' } else { 'unknown target' }
				& $setGuiStatusTextCommand -Text ("Remote: {0}" -f $targetLabel) -Tone 'accent'
				LogInfo ("Connected remote target context: {0}" -f $targetLabel)
			}
			catch
			{
				LogError (Get-UxBilingualLocalizedString -Key 'GuiLogRemoteConnectFailed' -Fallback 'Failed to connect to remote target: {0}' -FormatArgs @($_.Exception.Message))
				[void](Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiRemoteConnectTitle' -Fallback 'Connect to Computer') -Message ((& $getUxLocalizedStringCapture -Key 'GuiRemoteConnectFailed' -Fallback "Failed to connect to remote target.`n`n{0}") -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
			}
		}) | Out-Null
	}
	if ($MenuActionsDisconnect)
	{
		Register-GuiEventHandler -Source $MenuActionsDisconnect -EventName 'Click' -Handler ({
			if (& $testGuiRunInProgressCapture) { return }
			try
			{
				if (-not (& $testRemoteTargetConnectedCommand))
				{
					[void](Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiRemoteDisconnectTitle' -Fallback 'Disconnect') -Message (& $getUxLocalizedStringCapture -Key 'GuiRemoteDisconnectNone' -Fallback 'No remote target is currently connected.') -Buttons @('OK') -AccentButton 'OK')
					return
				}

				$context = & $getRemoteTargetContextCommand
				if ($clearRemoteSessionCacheCommand)
				{
					& $clearRemoteSessionCacheCommand -ComputerName @($context.TargetComputers)
				}
				& $clearRemoteTargetContextCommand
				$targetLabel = if ($context.TargetComputers.Count -gt 0) { $context.TargetComputers -join ', ' } else { 'remote target' }
				LogInfo ("Disconnected remote target context: {0}" -f $targetLabel)
				& $setGuiStatusTextCommand -Text (Get-UxLocalizedString -Key 'GuiRemoteDisconnected' -Fallback 'Remote target disconnected.') -Tone 'muted'
			}
			catch
			{
				LogError (Get-UxBilingualLocalizedString -Key 'GuiLogRemoteDisconnectFailed' -Fallback 'Failed to disconnect remote target: {0}' -FormatArgs @($_.Exception.Message))
				[void](Show-ThemedDialog -Title (& $getUxLocalizedStringCapture -Key 'GuiRemoteDisconnectTitle' -Fallback 'Disconnect') -Message ((& $getUxLocalizedStringCapture -Key 'GuiRemoteDisconnectFailed' -Fallback "Failed to disconnect remote target.`n`n{0}") -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
			}
		}) | Out-Null
	}
	if ($MenuActionsPreviewRun)
	{
		Register-GuiEventHandler -Source $MenuActionsPreviewRun -EventName 'Click' -Handler ({
			& $raiseButtonClick $BtnPreviewRun
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuActionsRunTweaks)
	{
		Register-GuiEventHandler -Source $MenuActionsRunTweaks -EventName 'Click' -Handler ({
			& $raiseButtonClick $BtnRun
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuActionsUndoLastRun)
	{
		Register-GuiEventHandler -Source $MenuActionsUndoLastRun -EventName 'Click' -Handler ({
			& $raiseButtonClick $Script:BtnUndoLastRun
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuActionsRestoreDefaults)
	{
		Register-GuiEventHandler -Source $MenuActionsRestoreDefaults -EventName 'Click' -Handler ({
			& $raiseButtonClick $BtnDefaults
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuActionsCheckCompliance)
	{
		Register-GuiEventHandler -Source $MenuActionsCheckCompliance -EventName 'Click' -Handler ({
			& $raiseButtonClick $Script:BtnCheckCompliance
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuActionsAuditLog)
	{
		Register-GuiEventHandler -Source $MenuActionsAuditLog -EventName 'Click' -Handler ({
			& $raiseButtonClick $Script:BtnAuditLog
		}.GetNewClosure()) | Out-Null
	}
	# Scan System - mirrors ChkScan checkbox
	if ($MenuActionsScanSystem -and $ChkScan)
	{
		try { $MenuActionsScanSystem.IsChecked = [bool]$ChkScan.IsChecked } catch { }
		Register-GuiEventHandler -Source $MenuActionsScanSystem -EventName 'Click' -Handler ({
			try { $ChkScan.IsChecked = [bool]$MenuActionsScanSystem.IsChecked } catch { }
		}.GetNewClosure()) | Out-Null
		Register-GuiEventHandler -Source $ChkScan -EventName 'Checked' -Handler ({
			try { $MenuActionsScanSystem.IsChecked = $true } catch { }
		}.GetNewClosure()) | Out-Null
		Register-GuiEventHandler -Source $ChkScan -EventName 'Unchecked' -Handler ({
			try { $MenuActionsScanSystem.IsChecked = $false } catch { }
		}.GetNewClosure()) | Out-Null
	}

	# View menu - these are IsCheckable, sync with underlying controls
	if ($MenuViewSafeMode -and $ChkSafeMode)
	{
		try { $MenuViewSafeMode.IsChecked = [bool]$ChkSafeMode.IsChecked } catch { }
		Register-GuiEventHandler -Source $MenuViewSafeMode -EventName 'Click' -Handler ({
			try { $ChkSafeMode.IsChecked = [bool]$MenuViewSafeMode.IsChecked } catch { }
		}.GetNewClosure()) | Out-Null
		Register-GuiEventHandler -Source $ChkSafeMode -EventName 'Checked' -Handler ({
			try { $MenuViewSafeMode.IsChecked = $true } catch { }
		}.GetNewClosure()) | Out-Null
		Register-GuiEventHandler -Source $ChkSafeMode -EventName 'Unchecked' -Handler ({
			try { $MenuViewSafeMode.IsChecked = $false } catch { }
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuViewFilters -and $BtnFilterToggle)
	{
		Register-GuiEventHandler -Source $MenuViewFilters -EventName 'Click' -Handler ({
			& $raiseButtonClick $BtnFilterToggle
			try { $MenuViewFilters.IsChecked = ($FilterOptionsPanel.Visibility -eq [System.Windows.Visibility]::Visible) } catch { }
		}.GetNewClosure()) | Out-Null
	}
	# Open Logs - opens the log dialog (BtnLog handler)
	if ($MenuViewLogsPanel)
	{
		Register-GuiEventHandler -Source $MenuViewLogsPanel -EventName 'Click' -Handler ({
			& $raiseButtonClick $BtnLog
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuViewTheme -and $ChkTheme)
	{
		try { $MenuViewTheme.IsChecked = [bool]$ChkTheme.IsChecked } catch { }
		Register-GuiEventHandler -Source $MenuViewTheme -EventName 'Click' -Handler ({
			try { $ChkTheme.IsChecked = [bool]$MenuViewTheme.IsChecked } catch { }
		}.GetNewClosure()) | Out-Null
		Register-GuiEventHandler -Source $ChkTheme -EventName 'Checked' -Handler ({
			try { $MenuViewTheme.IsChecked = $true } catch { }
		}.GetNewClosure()) | Out-Null
		Register-GuiEventHandler -Source $ChkTheme -EventName 'Unchecked' -Handler ({
			try { $MenuViewTheme.IsChecked = $false } catch { }
		}.GetNewClosure()) | Out-Null
	}

	# Tools menu
	if ($MenuToolsAppsManager -and $NavModeApps)
	{
		Register-GuiEventHandler -Source $MenuToolsAppsManager -EventName 'Click' -Handler ({
			try { $NavModeApps.IsChecked = $true } catch { }
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuToolsUpdateAllApps -and $BtnUpdateAllApps)
	{
		Register-GuiEventHandler -Source $MenuToolsUpdateAllApps -EventName 'Click' -Handler ({
			try { $NavModeApps.IsChecked = $true } catch { }
			& $raiseButtonClick $BtnUpdateAllApps
		}.GetNewClosure()) | Out-Null
	}

	# Help menu
	if ($MenuHelpStartGuide)
	{
		$gettingStartedShowThemedDialogCommand = Get-GuiRuntimeCommand -Name 'Show-ThemedDialog' -CommandType 'Function'
		$gettingStartedQuickStartStepsCommand  = Get-GuiRuntimeCommand -Name 'Get-UxQuickStartSteps' -CommandType 'Function'
		$gettingStartedHelpLinesCommand        = Get-GuiRuntimeCommand -Name 'Get-UxHelpGettingStartedLines' -CommandType 'Function'
		$gettingStartedOnboardingModeCommand   = Get-GuiRuntimeCommand -Name 'Get-UxOnboardingMode' -CommandType 'Function'
		Register-GuiEventHandler -Source $MenuHelpStartGuide -EventName 'Click' -Handler ({
			try
			{
				$title = & $getUxLocalizedStringCapture -Key 'GuiMenuHelpStartGuide' -Fallback 'Getting Started'
				$closeLabel = & $getUxLocalizedStringCapture -Key 'GuiCloseButton' -Fallback 'Close'
				$steps = @()
				if ($gettingStartedQuickStartStepsCommand)
				{
					try { $steps = @(& $gettingStartedQuickStartStepsCommand) } catch { }
				}
				$gettingStartedLines = @()
				if ($gettingStartedHelpLinesCommand)
				{
					$modeValue = 'Standard'
					if ($gettingStartedOnboardingModeCommand)
					{
						try { $modeValue = [string](& $gettingStartedOnboardingModeCommand) } catch { }
					}
					if ([string]::IsNullOrWhiteSpace($modeValue)) { $modeValue = 'Standard' }
					try { $gettingStartedLines = @(& $gettingStartedHelpLinesCommand -Mode $modeValue) } catch { }
				}
				$bodyLines = New-Object System.Collections.Generic.List[string]
				$stepIndex = 1
				foreach ($line in $steps)
				{
					if ([string]::IsNullOrWhiteSpace([string]$line)) { continue }
					[void]$bodyLines.Add(("{0}. {1}" -f $stepIndex, $line))
					$stepIndex++
				}
				foreach ($line in $gettingStartedLines)
				{
					if ([string]::IsNullOrWhiteSpace([string]$line)) { continue }
					[void]$bodyLines.Add(("- {0}" -f $line))
				}
				if ($bodyLines.Count -eq 0)
				{
					[void]$bodyLines.Add((& $getUxLocalizedStringCapture -Key 'GuiMenuHelpStartGuideEmpty' -Fallback 'No getting-started steps are available yet.'))
				}
				$message = [string]::Join([Environment]::NewLine, $bodyLines.ToArray())
				if ($gettingStartedShowThemedDialogCommand)
				{
					[void](& $gettingStartedShowThemedDialogCommand -Title $title -Message $message -Buttons @($closeLabel) -AccentButton $closeLabel)
				}
				& $setGuiStatusTextCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiMenuHelpStartGuideOpened' -Fallback 'Getting Started opened.') -Tone 'accent'
			}
			catch { try { LogWarning ("Getting Started menu open failed: {0}" -f $_.Exception.Message) } catch { } }
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuHelpReadme)
	{
		Register-GuiEventHandler -Source $MenuHelpReadme -EventName 'Click' -Handler ({
			try
			{
				if ($showReadmeDialogCommand)
				{
					& $showReadmeDialogCommand
				}
				else
				{
					throw 'Show-ReadmeDialog not found.'
				}
				& $setGuiStatusTextCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiMenuHelpReadmeOpened' -Fallback 'Readme opened in the themed popup.') -Tone 'accent'
			}
			catch
			{
				try { LogWarning ("Readme open failed: {0}" -f $_.Exception.Message) } catch { }
				if ($showThemedDialogCommand)
				{
					try
					{
						$errTitle = & $getUxLocalizedStringCapture -Key 'GuiMenuHelpReadme' -Fallback 'Readme'
						$errMsg = & $getUxLocalizedStringCapture -Key 'GuiMenuHelpReadmeFailed' -Fallback 'Unable to open the README popup. Check the installed directory for README.md.'
						[void](& $showThemedDialogCommand -Title $errTitle -Message $errMsg -Buttons @('OK') -AccentButton 'OK')
					}
					catch { }
				}
			}
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuHelpFAQ)
	{
		Register-GuiEventHandler -Source $MenuHelpFAQ -EventName 'Click' -Handler ({
			try
			{
				if ($showGuiFaqDialogCommand)
				{
					& $showGuiFaqDialogCommand
				}
				else
				{
					throw 'Show-GuiFaqDialog not found.'
				}
				& $setGuiStatusTextCommand -Text (& $getUxLocalizedStringCapture -Key 'GuiMenuHelpFAQOpened' -Fallback 'FAQ opened in the themed popup.') -Tone 'accent'
			}
			catch
			{
				try { LogWarning ("FAQ open failed: {0}" -f $_.Exception.Message) } catch { }
			}
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuHelpChangelog)
	{
		Register-GuiEventHandler -Source $MenuHelpChangelog -EventName 'Click' -Handler ({
			try
			{
				if ($showChangelogDialogCommand)
				{
					& $showChangelogDialogCommand
				}
				else
				{
					[void](Show-ThemedDialog -Title (Get-UxLocalizedString -Key 'GuiMenuHelpChangelog' -Fallback 'Changelog') -Message (Get-UxLocalizedString -Key 'GuiMenuHelpChangelogMissing' -Fallback 'Changelog file not found.') -Buttons @('OK') -AccentButton 'OK')
				}
			}
			catch { try { LogWarning ("Changelog open failed: {0}" -f $_.Exception.Message) } catch { } }
		}) | Out-Null
	}
	if ($MenuHelpCheckForUpdate)
	{
		Register-GuiEventHandler -Source $MenuHelpCheckForUpdate -EventName 'Click' -Handler ({
			try
			{
				if ($showUpdateCheckDialogCommand)
				{
					& $showUpdateCheckDialogCommand
				}
			}
			catch { try { LogWarning ("Update check open failed: {0}" -f $_.Exception.Message) } catch { } }
		}) | Out-Null
	}
	if ($MenuHelpReleaseStatus)
	{
		Register-GuiEventHandler -Source $MenuHelpReleaseStatus -EventName 'Click' -Handler ({
			try
			{
				if ($showGuiReleaseStatusDialogCommand)
				{
					& $showGuiReleaseStatusDialogCommand
				}
			}
			catch { try { LogWarning ("Release status open failed: {0}" -f $_.Exception.Message) } catch { } }
		}) | Out-Null
	}
	if ($MenuHelpTroubleshooting)
	{
		Register-GuiEventHandler -Source $MenuHelpTroubleshooting -EventName 'Click' -Handler ({
			try
			{
				if ($showGuiTroubleshootingGuideDialogCommand)
				{
					& $showGuiTroubleshootingGuideDialogCommand
				}
			}
			catch { try { LogWarning ("Troubleshooting guide open failed: {0}" -f $_.Exception.Message) } catch { } }
		}) | Out-Null
	}
	if ($MenuHelpAbout)
	{
		Register-GuiEventHandler -Source $MenuHelpAbout -EventName 'Click' -Handler ({
			try
			{
				$aboutTitle = Get-UxLocalizedString -Key 'GuiMenuHelpAbout' -Fallback 'About Baseline'
				$version = 'unknown'
				try { $version = Get-BaselineDisplayVersion } catch { }
				$msg = "Baseline`nVersion: $version`n`nA Windows utility for system configuration and optimization."
				[void](Show-ThemedDialog -Title $aboutTitle -Message $msg -Buttons @('OK') -AccentButton 'OK')
			}
			catch { }
		}) | Out-Null
	}

	# Apply localization to menu headers
	if ($MenuFile)                     { $MenuFile.Header                     = (Get-UxLocalizedString -Key 'GuiMenuFile' -Fallback '_File') }
	if ($MenuActions)                  { $MenuActions.Header                  = (Get-UxLocalizedString -Key 'GuiMenuActions' -Fallback '_Actions') }
	if ($MenuView)                     { $MenuView.Header                     = (Get-UxLocalizedString -Key 'GuiMenuView' -Fallback '_View') }
	if ($MenuTools)                    { $MenuTools.Header                    = (Get-UxLocalizedString -Key 'GuiMenuTools' -Fallback '_Tools') }
	if ($MenuHelp)                     { $MenuHelp.Header                     = (Get-UxLocalizedString -Key 'GuiMenuHelp' -Fallback '_Help') }
	if ($MenuFileImportSettings)       { $MenuFileImportSettings.Header       = (Get-UxLocalizedString -Key 'GuiMenuFileImportSettings' -Fallback 'Import Settings...') }
	if ($MenuFileExportSettings)       { $MenuFileExportSettings.Header       = (Get-UxLocalizedString -Key 'GuiMenuFileExportSettings' -Fallback 'Export Settings...') }
	if ($MenuFileAuditSettings)        { $MenuFileAuditSettings.Header        = (Get-UxLocalizedString -Key 'GuiMenuFileAuditSettings' -Fallback 'Audit Settings...') }
	if ($MenuFileExportConfigProfile)  { $MenuFileExportConfigProfile.Header  = (Get-UxLocalizedString -Key 'GuiMenuFileExportConfigProfile' -Fallback 'Export Config Profile...') }
	if ($MenuFileExportSystemState)    { $MenuFileExportSystemState.Header    = (Get-UxLocalizedString -Key 'GuiMenuFileExportSystemState' -Fallback 'Export System State...') }
	if ($MenuFileExit)                 { $MenuFileExit.Header                 = (Get-UxLocalizedString -Key 'GuiMenuFileExit' -Fallback 'E_xit') }
	if ($MenuActionsPreviewRun)        { $MenuActionsPreviewRun.Header        = (Get-UxLocalizedString -Key 'GuiMenuActionsPreviewRun' -Fallback 'Preview Run') }
	if ($MenuActionsRunTweaks)         { $MenuActionsRunTweaks.Header         = (Get-UxLocalizedString -Key 'GuiMenuActionsRunTweaks' -Fallback 'Run Tweaks') }
	if ($MenuActionsUndoLastRun)       { $MenuActionsUndoLastRun.Header       = (Get-UxLocalizedString -Key 'GuiMenuActionsUndoLastRun' -Fallback 'Undo Last Run') }
	if ($MenuActionsRestoreDefaults)   { $MenuActionsRestoreDefaults.Header   = (Get-UxLocalizedString -Key 'GuiMenuActionsRestoreDefaults' -Fallback 'Restore Defaults') }
	if ($MenuActionsCheckCompliance)   { $MenuActionsCheckCompliance.Header   = (Get-UxLocalizedString -Key 'GuiMenuActionsCheckCompliance' -Fallback 'Check Compliance...') }
	if ($MenuActionsScanSystem)        { $MenuActionsScanSystem.Header        = (Get-UxLocalizedString -Key 'GuiMenuActionsScanSystem' -Fallback 'Scan System') }
	if ($MenuActionsAuditLog)          { $MenuActionsAuditLog.Header          = (Get-UxLocalizedString -Key 'GuiMenuActionsAuditLog' -Fallback 'Audit Log...') }
	if ($MenuViewSafeMode)             { $MenuViewSafeMode.Header             = (Get-UxLocalizedString -Key 'GuiChkSafeMode' -Fallback 'Safe Mode') }
	if ($MenuViewFilters)              { $MenuViewFilters.Header              = (Get-UxLocalizedString -Key 'GuiMenuViewFilters' -Fallback 'Show Filters Panel') }
	if ($MenuViewLogsPanel)            { $MenuViewLogsPanel.Header            = (Get-UxLocalizedString -Key 'GuiMenuViewOpenLogs' -Fallback 'Open Logs') }
	if ($MenuViewTheme)
	{
		$MenuViewTheme.Header = if ($ChkTheme -and $ChkTheme.IsChecked -eq $true)
		{
			(Get-UxLocalizedString -Key 'GuiMenuViewSwitchToDarkMode' -Fallback 'Switch to Dark Mode')
		}
		else
		{
			(Get-UxLocalizedString -Key 'GuiMenuViewSwitchToLightMode' -Fallback 'Switch to Light Mode')
		}
	}
	if ($MenuToolsAppsManager)         { $MenuToolsAppsManager.Header         = (Get-UxLocalizedString -Key 'GuiMenuToolsAppsManager' -Fallback 'Apps Manager') }
	if ($MenuToolsUpdateAllApps)       { $MenuToolsUpdateAllApps.Header       = (Get-UxLocalizedString -Key 'GuiMenuToolsUpdateAllApps' -Fallback 'Update All Applications') }
	if ($MenuToolsExportSupportBundle) { $MenuToolsExportSupportBundle.Header = (Get-UxLocalizedString -Key 'GuiMenuToolsExportSupportBundle' -Fallback 'Export Support Bundle...') }
	if ($MenuToolsApproveRemoteTargets){ $MenuToolsApproveRemoteTargets.Header = (Get-UxLocalizedString -Key 'GuiMenuToolsApproveRemoteTargets' -Fallback 'Approve Target List...') }
	if ($MenuToolsSaveRemoteApprovalPolicy){ $MenuToolsSaveRemoteApprovalPolicy.Header = (Get-UxLocalizedString -Key 'GuiMenuToolsSaveRemoteApprovalPolicy' -Fallback 'Save Remote Approval Policy...') }
	if ($MenuToolsLoadRemoteApprovalPolicy){ $MenuToolsLoadRemoteApprovalPolicy.Header = (Get-UxLocalizedString -Key 'GuiMenuToolsLoadRemoteApprovalPolicy' -Fallback 'Load Remote Approval Policy...') }
	if ($MenuToolsRemoteConsole)       { $MenuToolsRemoteConsole.Header       = (Get-UxLocalizedString -Key 'GuiMenuToolsRemoteConsole' -Fallback 'Remote Console...') }
	if ($MenuToolsOperatorConsole)     { $MenuToolsOperatorConsole.Header     = (Get-UxLocalizedString -Key 'GuiMenuToolsOperatorConsole' -Fallback 'Operator Console...') }
	if ($MenuToolsRemoteSessionStatus) { $MenuToolsRemoteSessionStatus.Header = (Get-UxLocalizedString -Key 'GuiMenuToolsRemoteSessionStatus' -Fallback 'Remote Session Status...') }
	if ($MenuHelpStartGuide)           { $MenuHelpStartGuide.Header           = (Get-UxLocalizedString -Key 'GuiMenuHelpStartGuide' -Fallback 'Getting Started') }
	if ($MenuHelpReadme)               { $MenuHelpReadme.Header               = (Get-UxLocalizedString -Key 'GuiMenuHelpReadme' -Fallback 'Readme') }
	if ($MenuHelpFAQ)                  { $MenuHelpFAQ.Header                  = (Get-UxLocalizedString -Key 'GuiMenuHelpFAQ' -Fallback 'FAQ') }
	if ($MenuHelpChangelog)            { $MenuHelpChangelog.Header            = (Get-UxLocalizedString -Key 'GuiMenuHelpChangelog' -Fallback 'Changelog') }
	if ($MenuHelpCheckForUpdate)       { $MenuHelpCheckForUpdate.Header       = (Get-UxLocalizedString -Key 'GuiMenuHelpCheckForUpdate' -Fallback 'Check for Updates...') }
	if ($MenuHelpReleaseStatus)       { $MenuHelpReleaseStatus.Header       = (Get-UxLocalizedString -Key 'GuiMenuHelpReleaseStatus' -Fallback 'Release Status...') }
	if ($MenuHelpTroubleshooting)     { $MenuHelpTroubleshooting.Header     = (Get-UxLocalizedString -Key 'GuiMenuHelpTroubleshooting' -Fallback 'Troubleshooting Guide...') }
	if ($MenuHelpAbout)                { $MenuHelpAbout.Header                = (Get-UxLocalizedString -Key 'GuiMenuHelpAbout' -Fallback 'About Baseline') }

	# Hide duplicated toolbar/header buttons now that menus expose them (Phase 2 cleanup).
	# Kept in tree (not removed) so all existing wiring / theming / snapshots continue to work.
	Update-GuiDuplicateActionVisibility
	#endregion Top Menu Bar handlers
