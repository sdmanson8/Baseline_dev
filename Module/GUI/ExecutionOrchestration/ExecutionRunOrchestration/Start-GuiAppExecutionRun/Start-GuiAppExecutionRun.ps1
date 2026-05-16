function Get-GuiAppProgressOutcomeRank
{
	param(
		[string]$Status
	)

	if ([string]::IsNullOrWhiteSpace($Status)) { return -1 }

	switch -Regex ([string]$Status)
	{
		'^(Failed|Error|Timed Out / Unknown Final State)$' { return 40 }
		'^(Partial|Warning|Timed Out)$' { return 30 }
		'^(Skipped|Already Removed|Already Installed)$' { return 10 }
		'^(Success|Updated)$' { return 0 }
		default { return 20 }
	}
}

function Set-GuiAppProgressOutcome
{
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$RunState,

		[string]$Status
	)

	if ([string]::IsNullOrWhiteSpace($Status)) { return }

	$currentStatus = if ($RunState.ContainsKey('AppOutcome')) { [string]$RunState['AppOutcome'] } else { $null }
	if ([string]::IsNullOrWhiteSpace($currentStatus))
	{
		$RunState['AppOutcome'] = [string]$Status
		return
	}

	if ((Get-GuiAppProgressOutcomeRank -Status $Status) -ge (Get-GuiAppProgressOutcomeRank -Status $currentStatus))
	{
		$RunState['AppOutcome'] = [string]$Status
	}
}

try
		{
			if ($wasAppsModeActive)
			{
				Set-GuiAppsMode -Enable:$false
			}

			if ($Script:GuiState)
			{
				& $Script:GuiState.Set 'RunInProgress' $true
			}
			else
			{
				$Script:RunInProgress = $true
			}

			Enter-ExecutionView -Title $executionTitle -ShowAbortButton:$true
			$Script:ExecutionMode = 'Apps'
			if ($Script:ExecutionProgressBar -or $Script:ExecutionProgressText)
			{
				if ([bool]$Script:RunState['AppProgressIndeterminate'])
				{
					Set-SharedProgressBarState -ProgressBar $Script:ExecutionProgressBar -ProgressText $Script:ExecutionProgressText -Indeterminate -CurrentAction $initialActionText
				}
				else
				{
					Set-SharedProgressBarState -ProgressBar $Script:ExecutionProgressBar -ProgressText $Script:ExecutionProgressText -Completed 0 -Total ([int]$Script:RunState['AppProgressTotal']) -CurrentAction $initialActionText
				}
			}
			if (-not [string]::IsNullOrWhiteSpace([string]$initialActionText))
			{
				LogInfo $initialActionText
			}

			$bgLocDir      = $LocalizationDirectory
			$bgUICulture   = $UICulture
			$bgLogFilePath = $LogFilePath

			$Script:ExecutionWorker = GUIExecution\Start-GuiAppExecutionWorker `
				-Action $Action `
				-LoaderPath $LoaderPath `
				-LocalizationDirectory $bgLocDir `
				-UICulture $bgUICulture `
				-LogFilePath $bgLogFilePath `
				-LogMode $LogMode `
				-RunState $Script:RunState `
				-WinGetId $resolvedWinGetId `
				-ChocoId $resolvedChocoId `
				-DisplayName $resolvedDisplayName `
				-Application $Application `
				-SelectedApps @($selectedApps) `
				-PreferredSource $PreferredSource `
				-PackageManagerAvailabilityState $PackageManagerAvailabilityState
			$Script:BgPS = $Script:ExecutionWorker.PowerShell
			$Script:BgAsync = $Script:ExecutionWorker.AsyncResult
			$Script:ExecutionRunspace = $Script:ExecutionWorker.Runspace
			$Script:ExecutionRunPowerShell = $Script:ExecutionWorker.PowerShell

			$Script:AppDrainQueue = {
				param([switch]$Final)

				$qEntry = $null
				while ($Script:RunState['LogQueue'].TryDequeue([ref]$qEntry))
				{
					try
					{
						Update-ExecutionActivityHeartbeat -RunState $Script:RunState
						switch ($qEntry.Kind)
						{
							'_AppStarted'
							{
								$Script:RunState['AppUseStructuredProgress'] = $true
								$appName = if ((Test-GuiObjectField -Object $qEntry -FieldName 'Name')) { [string]$qEntry.Name } else { [string]$Script:RunState['CurrentAction'] }
								$Script:RunState['CurrentAction'] = $appName
								$Script:ExecutionLastConsoleAction = $null
								$stepIndex = if ((Test-GuiObjectField -Object $qEntry -FieldName 'StepIndex')) { [int]$qEntry.StepIndex } else { ([int]$Script:RunState['AppCompletedCount'] + 1) }
								$stepTotal = if ((Test-GuiObjectField -Object $qEntry -FieldName 'StepTotal')) { [int]$qEntry.StepTotal } else { [int]$Script:RunState['AppProgressTotal'] }
								if ($Script:ExecutionProgressBar -or $Script:ExecutionProgressText)
								{
									Set-SharedProgressBarState -ProgressBar $Script:ExecutionProgressBar -ProgressText $Script:ExecutionProgressText -Completed ([Math]::Max($stepIndex - 1, 0)) -Total ([Math]::Max($stepTotal, 1)) -CurrentAction $appName
								}
							}
							'_AppCompleted'
							{
								$Script:RunState['AppUseStructuredProgress'] = $true
								$appStatus = if ((Test-GuiObjectField -Object $qEntry -FieldName 'Status')) { [string]$qEntry.Status } else { 'Success' }
								$appMessage = if ((Test-GuiObjectField -Object $qEntry -FieldName 'Message') -and -not [string]::IsNullOrWhiteSpace([string]$qEntry.Message)) { [string]$qEntry.Message } else { [string]$qEntry.Name }
								$appLevel = switch -Regex ($appStatus)
								{
									'^(Success|Updated|Already Removed|Already Installed)$' { 'SUCCESS'; break }
									'^(Timed Out|Timed Out / Unknown Final State)$' { 'WARNING'; break }
									'^(Skipped)$' { 'SKIP'; break }
									default { 'ERROR' }
								}
								Add-ExecutionLogLine -Text $appMessage -Level $appLevel

								$completedCount = if ((Test-GuiObjectField -Object $qEntry -FieldName 'StepIndex')) { [int]$qEntry.StepIndex } else { ([int]$Script:RunState['AppCompletedCount'] + 1) }
								$Script:RunState['AppCompletedCount'] = [Math]::Min($completedCount, [int]$Script:RunState['AppProgressTotal'])
								if (-not [string]::IsNullOrWhiteSpace($appStatus))
								{
									Set-GuiAppProgressOutcome -RunState $Script:RunState -Status $appStatus
								}
								if ($Script:ExecutionProgressBar -or $Script:ExecutionProgressText)
								{
									$displayName = if ((Test-GuiObjectField -Object $qEntry -FieldName 'Name') -and -not [string]::IsNullOrWhiteSpace([string]$qEntry.Name)) { [string]$qEntry.Name } else { [string]$Script:RunState['CurrentAction'] }
									Set-SharedProgressBarState -ProgressBar $Script:ExecutionProgressBar -ProgressText $Script:ExecutionProgressText -Completed ([int]$Script:RunState['AppCompletedCount']) -Total ([int]$Script:RunState['AppProgressTotal']) -CurrentAction $displayName
								}
								$Script:ExecutionLastConsoleAction = $null
							}
							'Log'
							{
								$message = if ((Test-GuiObjectField -Object $qEntry -FieldName 'Message')) { [string]$qEntry.Message } else { $null }
								if (-not [string]::IsNullOrWhiteSpace($message))
								{
									$level = if ((Test-GuiObjectField -Object $qEntry -FieldName 'Level') -and -not [string]::IsNullOrWhiteSpace([string]$qEntry.Level)) { [string]$qEntry.Level } else { 'INFO' }
									Add-ExecutionLogLine -Text $message -Level $level
								}
							}
							'ConsoleAction'
							{
								$currentAction = if ((Test-GuiObjectField -Object $qEntry -FieldName 'Action')) { [string]$qEntry.Action } else { $null }
								if (-not [string]::IsNullOrWhiteSpace($currentAction))
								{
									$Script:ExecutionLastConsoleAction = $currentAction
									if ($Script:ExecutionProgressBar -or $Script:ExecutionProgressText)
									{
										if ([bool]$Script:RunState['AppUseStructuredProgress'])
										{
											Set-SharedProgressBarState -ProgressBar $Script:ExecutionProgressBar -ProgressText $Script:ExecutionProgressText -Completed ([int]$Script:RunState['AppCompletedCount']) -Total ([int]$Script:RunState['AppProgressTotal']) -CurrentAction $currentAction
										}
										elseif ([bool]$Script:RunState['AppProgressIndeterminate'] -and [int]$Script:RunState['AppCompletedCount'] -eq 0)
										{
											Set-SharedProgressBarState -ProgressBar $Script:ExecutionProgressBar -ProgressText $Script:ExecutionProgressText -Indeterminate -CurrentAction $currentAction
										}
										else
										{
											Set-SharedProgressBarState -ProgressBar $Script:ExecutionProgressBar -ProgressText $Script:ExecutionProgressText -Completed ([int]$Script:RunState['AppCompletedCount']) -Total ([int]$Script:RunState['AppProgressTotal']) -CurrentAction $currentAction
										}
									}
								}
							}
							'ConsoleStatus'
							{
								$status = if ((Test-GuiObjectField -Object $qEntry -FieldName 'Status')) { [string]$qEntry.Status } else { $null }
								if (-not [string]::IsNullOrWhiteSpace($status))
								{
									Set-GuiAppProgressOutcome -RunState $Script:RunState -Status $status
								}
								if (-not [bool]$Script:RunState['AppUseStructuredProgress'])
								{
									$Script:RunState['AppCompletedCount'] = [Math]::Min(([int]$Script:RunState['AppCompletedCount'] + 1), [int]$Script:RunState['AppProgressTotal'])
								}
								if ($Script:ExecutionProgressBar -or $Script:ExecutionProgressText)
								{
									$currentAction = if (-not [string]::IsNullOrWhiteSpace([string]$Script:ExecutionLastConsoleAction)) { [string]$Script:ExecutionLastConsoleAction } else { [string]$Script:RunState['CurrentAction'] }
									Set-SharedProgressBarState -ProgressBar $Script:ExecutionProgressBar -ProgressText $Script:ExecutionProgressText -Completed ([int]$Script:RunState['AppCompletedCount']) -Total ([int]$Script:RunState['AppProgressTotal']) -CurrentAction $currentAction
								}
								$Script:ExecutionLastConsoleAction = $null
							}
							'ConsoleComplete'
							{
								$status = if ((Test-GuiObjectField -Object $qEntry -FieldName 'Status')) { [string]$qEntry.Status } else { $null }
								if (-not [string]::IsNullOrWhiteSpace($status))
								{
									Set-GuiAppProgressOutcome -RunState $Script:RunState -Status $status
								}
								if (-not [bool]$Script:RunState['AppUseStructuredProgress'])
								{
									$Script:RunState['AppCompletedCount'] = [Math]::Min(([int]$Script:RunState['AppCompletedCount'] + 1), [int]$Script:RunState['AppProgressTotal'])
								}
								if ($Script:ExecutionProgressBar -or $Script:ExecutionProgressText)
								{
									$currentAction = if ((Test-GuiObjectField -Object $qEntry -FieldName 'Action') -and -not [string]::IsNullOrWhiteSpace([string]$qEntry.Action)) { [string]$qEntry.Action } else { [string]$Script:RunState['CurrentAction'] }
									Set-SharedProgressBarState -ProgressBar $Script:ExecutionProgressBar -ProgressText $Script:ExecutionProgressText -Completed ([int]$Script:RunState['AppCompletedCount']) -Total ([int]$Script:RunState['AppProgressTotal']) -CurrentAction $currentAction
								}
								$Script:ExecutionLastConsoleAction = $null
							}
							'_RunError'
							{
								$fatalMessage = if ([string]::IsNullOrWhiteSpace([string]$qEntry.Error)) { 'Unexpected fatal app run error.' } else { [string]$qEntry.Error }
								$Script:RunState['AppOutcome'] = 'Failed'
								Add-ExecutionLogLine -Text ("Fatal app error: {0}" -f $fatalMessage) -Level 'ERROR'
								try
								{
									LogError ("Fatal app error: {0}" -f $fatalMessage)
								}
								catch
								{
									if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
									{
										Write-SwallowedException -ErrorRecord $_ -Source 'ExecutionOrchestration.RunLoop.FatalAppError.LogError'
									}
								}
								$diagnosticText = if ((Test-GuiObjectField -Object $qEntry -FieldName 'Diagnostic')) { [string]$qEntry.Diagnostic } else { $null }
								if (-not [string]::IsNullOrWhiteSpace($diagnosticText))
								{
									foreach ($diagnosticLine in @($diagnosticText -split "(`r`n|`n|`r)"))
									{
										if (-not [string]::IsNullOrWhiteSpace([string]$diagnosticLine))
										{
											Add-ExecutionLogLine -Text $diagnosticLine -Level 'ERROR'
											try
											{
												LogError $diagnosticLine
											}
											catch
											{
												if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
												{
													Write-SwallowedException -ErrorRecord $_ -Source 'ExecutionOrchestration.RunLoop.FatalAppDiagnostic.LogError'
												}
											}
										}
									}
								}
							}
							'_RunNotice'
							{
								$noticeMessage = if ((Test-GuiObjectField -Object $qEntry -FieldName 'Message')) { [string]$qEntry.Message } else { $null }
								if (-not [string]::IsNullOrWhiteSpace($noticeMessage))
								{
									$level = if ((Test-GuiObjectField -Object $qEntry -FieldName 'Level') -and -not [string]::IsNullOrWhiteSpace([string]$qEntry.Level)) { [string]$qEntry.Level } else { 'WARNING' }
									Add-ExecutionLogLine -Text $noticeMessage -Level $level
								}
							}
						}
					}
					catch
					{
						LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionAppTimerQueueEntryFailed' -Fallback '[AppTimer] Queue entry failed [{0}]' -FormatArgs @($(if ($qEntry -and (Test-GuiObjectField -Object $qEntry -FieldName 'Kind')) { [string]$qEntry.Kind } else { '<unknown>' }))))
					}
					finally
					{
						$qEntry = $null
					}
				}
			}

			$Script:ExecutionPumpTickFn = {
				try
				{
					if (-not $Script:RunInProgress -or -not $Script:RunState) { return }

					if ($Script:AbortRequested -and -not $Script:RunState['AbortRequested'])
					{
						$Script:RunState['AbortRequested'] = $true
						$Script:RunState['AbortRequestedAt'] = Get-Date
					}

					if (
						$Script:RunState['AbortRequested'] -and
						-not $Script:RunState['Done'] -and
						-not $Script:RunState['ForceStopIssued'] -and
						$Script:RunState['AbortRequestedAt'] -ne [datetime]::MinValue -and
						((Get-Date) - $Script:RunState['AbortRequestedAt']).TotalSeconds -ge 2
					)
					{
						$Script:RunState['ForceStopIssued'] = $true
						$Script:RunState['AbortedRun'] = $true
						$Script:RunState['LogQueue'].Enqueue([PSCustomObject]@{
							Kind = '_RunNotice'
							Level = 'WARNING'
							Message = 'Abort requested - stopping the current app operation now.'
						})
						$bgPsToStop = $Script:BgPS
						if ($bgPsToStop)
						{
							GUIExecution\Request-GuiExecutionWorkerStop -PowerShellInstance $bgPsToStop
						}
					}

					& $Script:AppDrainQueue
					Invoke-ExecutionIdleWatchdogPrompt -RunState $Script:RunState

					if ($Script:BgAsync -and -not $Script:BgAsync.IsCompleted -and -not $Script:RunState['Done']) { return }

					if ($Script:ExecutionRunTimer)
					{
						try { $Script:ExecutionRunTimer.Stop() } catch { $null = $_ }
						try { $Script:ExecutionRunTimer.Dispose() } catch { $null = $_ }
					}

					& $Script:AppDrainQueue

					GUIExecution\Complete-GuiExecutionWorker -Worker $Script:ExecutionWorker
					if ($Script:RunState['AppResult'] -and (Test-GuiObjectField -Object $Script:RunState['AppResult'] -FieldName 'Outcome') -and -not [string]::IsNullOrWhiteSpace([string]$Script:RunState['AppResult'].Outcome))
					{
						$Script:RunState['AppOutcome'] = [string]$Script:RunState['AppResult'].Outcome
					}
					$Script:ExecutionWorker = $null
					$Script:ExecutionRunspace = $null
					$Script:ExecutionRunPowerShell = $null
					$Script:ExecutionRunTimer = $null
					$Script:ExecutionPumpTickFn = $null
					$Script:BgPS = $null
					$Script:BgAsync = $null

					$appOutcome = if (-not [string]::IsNullOrWhiteSpace([string]$Script:RunState['AppOutcome'])) { [string]$Script:RunState['AppOutcome'] } else { 'Success' }
					$finalLabel = if ([bool]$Script:RunState['AbortedRun'])
					{
						Get-UxLocalizedString -Key 'GuiProgressAborted' -Fallback 'Aborted'
					}
					else
					{
						switch ($appOutcome.ToLowerInvariant())
						{
							'partial' { Get-UxLocalizedString -Key 'GuiProgressPartiallyComplete' -Fallback 'Partially Complete' }
							'warning' { Get-UxLocalizedString -Key 'GuiProgressPartiallyComplete' -Fallback 'Partially Complete' }
							'failed'  { Get-UxLocalizedString -Key 'GuiProgressFailed' -Fallback 'Failed' }
							default   { Get-UxLocalizedString -Key 'GuiProgressDone' -Fallback 'Done' }
						}
					}
					if ($Script:ExecutionProgressBar -or $Script:ExecutionProgressText)
					{
						Set-SharedProgressBarState -ProgressBar $Script:ExecutionProgressBar -ProgressText $Script:ExecutionProgressText -Completed 1 -Total 1 -CurrentAction $finalLabel
					}

					Clear-UILogHandler
					Remove-Variable -Name 'GUIRunState' -Scope Global -ErrorAction SilentlyContinue

					if ($Script:GuiState)
					{
						& $Script:GuiState.Set 'RunInProgress' $false
					}
					else
					{
						$Script:RunInProgress = $false
					}

					$Script:AppsOperationInProgress = $false
					$Script:ExecutionMode = $null
					Exit-ExecutionView

					$runAction = [string]$Script:RunState['Action']
					$runApplication = $Script:RunState['Application']
					$runSelectedApps = @($Script:RunState['SelectedApps'])
					$runPreferredSource = [string]$Script:RunState['PreferredSource']
					$runWasAppsModeActive = [bool]$Script:RunState['WasAppsModeActive']
					$runAppResult = $Script:RunState['AppResult']

					if ((Get-Command -Name 'Sync-AppActionStatesFromExecutionResult' -CommandType Function -ErrorAction SilentlyContinue) -and $runAction -in @('Install', 'Uninstall', 'Update'))
					{
						try
						{
							Sync-AppActionStatesFromExecutionResult -Action $runAction -Application $runApplication -SelectedApps @($runSelectedApps) -Result $runAppResult -PreferredSource $runPreferredSource
						}
						catch
						{
							LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionAppStateSyncFailed' -Fallback 'Failed to sync app action state after execution'))
						}
					}

					if ($runWasAppsModeActive)
					{
						if ($runAction -in @('Install', 'Uninstall', 'Update', 'UpdateAll'))
						{
							Start-AppsCacheRefresh
						}
						else
						{
							$Script:AppsViewDirty = $true
						}

						Set-GuiAppsMode -Enable:$true
					}

					$Script:RunState = $null
				}
				catch
				{
					LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionAppTimerUpdateFailed' -Fallback '[AppTimer] Execution UI update failed'))
					try { Clear-UILogHandler } catch { $null = $_ }
					try { Remove-Variable -Name 'GUIRunState' -Scope Global -ErrorAction SilentlyContinue } catch { $null = $_ }
					try { Exit-ExecutionView } catch { $null = $_ }
					try
					{
						$runCatchAction = if ($Script:RunState) { [string]$Script:RunState['Action'] } else { $null }
						$runCatchWasAppsModeActive = if ($Script:RunState) { [bool]$Script:RunState['WasAppsModeActive'] } else { $false }
						if ($runCatchWasAppsModeActive)
						{
							if ($runCatchAction -in @('Install', 'Uninstall', 'Update', 'UpdateAll'))
							{
								Start-AppsCacheRefresh
							}
							else
							{
								$Script:AppsViewDirty = $true
							}

							Set-GuiAppsMode -Enable:$true
						}
					}
					catch
					{
						$null = $_
					}
					$Script:AppsOperationInProgress = $false
					if ($Script:GuiState)
					{
						& $Script:GuiState.Set 'RunInProgress' $false
					}
					else
					{
						$Script:RunInProgress = $false
					}
					$Script:ExecutionWorker = $null
					$Script:ExecutionRunspace = $null
					$Script:ExecutionRunPowerShell = $null
					$Script:ExecutionRunTimer = $null
					$Script:ExecutionPumpTickFn = $null
					$Script:BgPS = $null
					$Script:BgAsync = $null
					$Script:ExecutionMode = $null
					$Script:RunState = $null
				}
			}

			$executionPumpTickFn = $Script:ExecutionPumpTickFn
			$runTimer = New-Object System.Windows.Threading.DispatcherTimer
			$runTimer.Interval = [TimeSpan]::FromMilliseconds(100)
			$runTimer.Add_Tick({
				& $executionPumpTickFn
			}.GetNewClosure())
			$Script:ExecutionRunTimer = $runTimer
			$runTimer.Start()
			& $executionPumpTickFn
		}
		catch
		{
			try { Clear-UILogHandler } catch { $null = $_ }
			try { Remove-Variable -Name 'GUIRunState' -Scope Global -ErrorAction SilentlyContinue } catch { $null = $_ }
			try { Exit-ExecutionView } catch { $null = $_ }
			try
			{
				if ($wasAppsModeActive)
				{
					Set-GuiAppsMode -Enable:$true
				}
			}
			catch
			{
				$null = $_
			}
			$Script:AppsOperationInProgress = $false
			if ($Script:GuiState)
			{
				& $Script:GuiState.Set 'RunInProgress' $false
			}
			else
			{
				$Script:RunInProgress = $false
			}
			$Script:ExecutionWorker = $null
			$Script:ExecutionRunspace = $null
			$Script:ExecutionRunPowerShell = $null
			$Script:ExecutionRunTimer = $null
			$Script:ExecutionPumpTickFn = $null
			$Script:BgPS = $null
			$Script:BgAsync = $null
			$Script:ExecutionMode = $null
			$Script:RunState = $null
			$null = & $Script:ShowGuiRuntimeFailureScript -Context 'Start-GuiAppExecutionRun' -Exception $_.Exception -ShowDialog
		}
