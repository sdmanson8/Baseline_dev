# ActionHandlers split file loaded by Module\GUI\ActionHandlers.ps1.

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
			try
			{
				LogWarning ("Menu click routing failed: {0}" -f $_.Exception.Message)
			}
			catch
			{
				if (Get-Command -Name 'Write-DebugSwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
				{
					Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.MenuClickRouting.LogWarning'
				}
			}
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
			try
			{
				$Script:MainForm.Close()
			}
			catch
			{
				if (Get-Command -Name 'Write-DebugSwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
				{
					Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.MenuFileExit.CloseMainForm'
				}
			}
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
				$requestMethod = if ((Test-GuiObjectField -Object $connectionRequest -FieldName 'ConnectionMethod') -and $connectionRequest.ConnectionMethod) { [string]$connectionRequest.ConnectionMethod } else { 'WinRM' }
				$context = & $setRemoteTargetContextCommand -ComputerName $connectionRequest.ComputerName -Credential $connectionRequest.Credential -StatusMessage 'Remote target connected.' -ConnectionMethod $requestMethod
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
	if ($Script:BtnRemoteModeBannerDisconnect)
	{
		Register-GuiEventHandler -Source $Script:BtnRemoteModeBannerDisconnect -EventName 'Click' -Handler ({
			# Banner button shares the menu's Disconnect handler — raise its Click
			# so any wiring (telemetry / future hooks) flows through one path.
			if ($Script:MenuActionsDisconnect)
			{
				try { $Script:MenuActionsDisconnect.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent)) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuActionsDisconnect.RaiseEvent' }
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
	# Scan System - matches ChkScan checkbox
	if ($MenuActionsScanSystem -and $ChkScan)
	{
		try { $MenuActionsScanSystem.IsChecked = [bool]$ChkScan.IsChecked } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuActionsScanSystem.SetChecked' }
		Register-GuiEventHandler -Source $MenuActionsScanSystem -EventName 'Click' -Handler ({
			try { $ChkScan.IsChecked = [bool]$MenuActionsScanSystem.IsChecked } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuActionsScanSystem.SyncClick' }
		}.GetNewClosure()) | Out-Null
		Register-GuiEventHandler -Source $ChkScan -EventName 'Checked' -Handler ({
			try { $MenuActionsScanSystem.IsChecked = $true } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuActionsScanSystem.Checked' }
		}.GetNewClosure()) | Out-Null
		Register-GuiEventHandler -Source $ChkScan -EventName 'Unchecked' -Handler ({
			try { $MenuActionsScanSystem.IsChecked = $false } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuActionsScanSystem.Unchecked' }
		}.GetNewClosure()) | Out-Null
	}

	# View menu - these are IsCheckable, sync with underlying controls
	if ($MenuViewSafeMode -and $ChkSafeMode)
	{
		try { $MenuViewSafeMode.IsChecked = [bool]$ChkSafeMode.IsChecked } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuViewSafeMode.SetChecked' }
		Register-GuiEventHandler -Source $MenuViewSafeMode -EventName 'Click' -Handler ({
			try { $ChkSafeMode.IsChecked = [bool]$MenuViewSafeMode.IsChecked } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuViewSafeMode.SyncClick' }
		}.GetNewClosure()) | Out-Null
		Register-GuiEventHandler -Source $ChkSafeMode -EventName 'Checked' -Handler ({
			try { $MenuViewSafeMode.IsChecked = $true } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuViewSafeMode.Checked' }
		}.GetNewClosure()) | Out-Null
		Register-GuiEventHandler -Source $ChkSafeMode -EventName 'Unchecked' -Handler ({
			try { $MenuViewSafeMode.IsChecked = $false } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuViewSafeMode.Unchecked' }
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuViewFilters -and $BtnFilterToggle)
	{
		Register-GuiEventHandler -Source $MenuViewFilters -EventName 'Click' -Handler ({
			& $raiseButtonClick $BtnFilterToggle
			try { $MenuViewFilters.IsChecked = ($FilterOptionsPanel.Visibility -eq [System.Windows.Visibility]::Visible) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuViewFilters.SetChecked' }
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
		try { $MenuViewTheme.IsChecked = [bool]$ChkTheme.IsChecked } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuViewTheme.SetChecked' }
		Register-GuiEventHandler -Source $MenuViewTheme -EventName 'Click' -Handler ({
			try { $ChkTheme.IsChecked = [bool]$MenuViewTheme.IsChecked } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuViewTheme.SyncClick' }
		}.GetNewClosure()) | Out-Null
		Register-GuiEventHandler -Source $ChkTheme -EventName 'Checked' -Handler ({
			try { $MenuViewTheme.IsChecked = $true } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuViewTheme.Checked' }
		}.GetNewClosure()) | Out-Null
		Register-GuiEventHandler -Source $ChkTheme -EventName 'Unchecked' -Handler ({
			try { $MenuViewTheme.IsChecked = $false } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuViewTheme.Unchecked' }
		}.GetNewClosure()) | Out-Null
	}

	# Tools menu
	if ($MenuToolsAppsManager -and $NavModeApps)
	{
		Register-GuiEventHandler -Source $MenuToolsAppsManager -EventName 'Click' -Handler ({
			try { $NavModeApps.IsChecked = $true } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuToolsAppsManager.Checked' }
		}.GetNewClosure()) | Out-Null
	}
	if ($MenuToolsUpdateAllApps -and $BtnUpdateAllApps)
	{
		Register-GuiEventHandler -Source $MenuToolsUpdateAllApps -EventName 'Click' -Handler ({
			try { $NavModeApps.IsChecked = $true } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.SyncMenuState.MenuToolsUpdateAllApps.Checked' }
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
					try { $steps = @(& $gettingStartedQuickStartStepsCommand) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.MenuHelpStartGuide.GetQuickStartSteps' }
				}
				$gettingStartedLines = @()
				if ($gettingStartedHelpLinesCommand)
				{
					$modeValue = 'Standard'
					if ($gettingStartedOnboardingModeCommand)
					{
						try { $modeValue = [string](& $gettingStartedOnboardingModeCommand) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.MenuHelpStartGuide.GetOnboardingMode' }
					}
					if ([string]::IsNullOrWhiteSpace($modeValue)) { $modeValue = 'Standard' }
					try { $gettingStartedLines = @(& $gettingStartedHelpLinesCommand -Mode $modeValue) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.MenuHelpStartGuide.GetHelpLines' }
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
			catch
			{
				try
				{
					LogWarning ("Getting Started menu open failed: {0}" -f $_.Exception.Message)
				}
				catch
				{
					if (Get-Command -Name 'Write-DebugSwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
					{
						Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.MenuHelpGettingStarted.LogWarning'
					}
				}
			}
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
				try
				{
					LogWarning ("Readme open failed: {0}" -f $_.Exception.Message)
				}
				catch
				{
					if (Get-Command -Name 'Write-DebugSwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
					{
						Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.MenuHelpReadme.LogWarning'
					}
				}
				if ($showThemedDialogCommand)
				{
					try
					{
						$errTitle = & $getUxLocalizedStringCapture -Key 'GuiMenuHelpReadme' -Fallback 'Readme'
						$errMsg = & $getUxLocalizedStringCapture -Key 'GuiMenuHelpReadmeFailed' -Fallback 'Unable to open the README popup. Check the installed directory for README.md.'
						[void](& $showThemedDialogCommand -Title $errTitle -Message $errMsg -Buttons @('OK') -AccentButton 'OK')
					}
					catch
					{
						if (Get-Command -Name 'Write-DebugSwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
						{
							Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.MenuHelpReadme.ShowThemedDialog'
						}
					}
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
				try
				{
					LogWarning ("FAQ open failed: {0}" -f $_.Exception.Message)
				}
				catch
				{
					if (Get-Command -Name 'Write-DebugSwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
					{
						Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.MenuHelpFAQ.LogWarning'
					}
				}
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
			catch
			{
				try
				{
					LogWarning ("Changelog open failed: {0}" -f $_.Exception.Message)
				}
				catch
				{
					if (Get-Command -Name 'Write-DebugSwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
					{
						Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.MenuHelpChangelog.LogWarning'
					}
				}
			}
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
			catch
			{
				try
				{
					LogWarning ("Update check open failed: {0}" -f $_.Exception.Message)
				}
				catch
				{
					if (Get-Command -Name 'Write-DebugSwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
					{
						Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.MenuHelpUpdateCheck.LogWarning'
					}
				}
			}
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
			catch
			{
				try
				{
					LogWarning ("Release status open failed: {0}" -f $_.Exception.Message)
				}
				catch
				{
					if (Get-Command -Name 'Write-DebugSwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
					{
						Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.MenuHelpReleaseStatus.LogWarning'
					}
				}
			}
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
			catch
			{
				try
				{
					LogWarning ("Troubleshooting guide open failed: {0}" -f $_.Exception.Message)
				}
				catch
				{
					if (Get-Command -Name 'Write-DebugSwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
					{
						Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.MenuHelpTroubleshooting.LogWarning'
					}
				}
			}
		}) | Out-Null
	}
	if ($MenuHelpAbout)
	{
		Register-GuiEventHandler -Source $MenuHelpAbout -EventName 'Click' -Handler ({
			try
			{
				$aboutTitle = Get-UxLocalizedString -Key 'GuiMenuHelpAbout' -Fallback 'About Baseline'
				$version = 'unknown'
				try { $version = Get-BaselineDisplayVersion } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.MenuHelpAbout.GetDisplayVersion' }
				$msg = "Baseline`nVersion: $version`n`nA Windows utility for system configuration and optimization."
				[void](Show-ThemedDialog -Title $aboutTitle -Message $msg -Buttons @('OK') -AccentButton 'OK')
			}
			catch
			{
				if (Get-Command -Name 'Write-DebugSwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
				{
					Write-DebugSwallowedException -ErrorRecord $_ -Source 'ActionHandlers.MenuHelpAbout.ShowThemedDialog'
				}
			}
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
	if ($MenuActionsRunTweaks)         { $MenuActionsRunTweaks.Header         = (Get-UxRunActionLabel) }
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
	if ($MenuToolsUserFolders)         { $MenuToolsUserFolders.Header         = (New-GuiLabeledIconContent -IconName 'Document' -Text (Get-UxLocalizedString -Key 'GuiMenuToolsUserFolders' -Fallback 'User Folders...') -IconSize 12 -Gap 6 -TextFontSize 12 -AllowTextOnlyFallback) }
	if ($MenuToolsInstallWsl)          { $MenuToolsInstallWsl.Header          = (New-GuiLabeledIconContent -IconName 'WindowConsole' -Text (Get-UxLocalizedString -Key 'GuiMenuToolsInstallWsl' -Fallback 'Install WSL...') -IconSize 12 -Gap 6 -TextFontSize 12 -AllowTextOnlyFallback) }
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
