# ExecutionOrchestration split file loaded by Module\GUI\ExecutionOrchestration.ps1.

	<#
	    .SYNOPSIS
	    Internal function Get-ExecutionResumeCandidateList.
	#>

	function Get-ExecutionResumeCandidateList
	{
		[CmdletBinding()]
		param (
			[object[]]$Results
		)

		$resumeCandidates = @($Results | Where-Object {
			[string]$_.Status -in @('Not Run', 'Cancelled')
		} | Sort-Object -Property Order)

		return @($resumeCandidates)
	}

	<#
	    .SYNOPSIS
	    Internal function Confirm-RemoteMultiTargetApply.
	#>

	function Confirm-RemoteMultiTargetApply
	{
		[CmdletBinding()]
		param (
			[Parameter(Mandatory)]
			[string[]]$TargetComputers
		)

		$targets = @($TargetComputers | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim() })
		if ($targets.Count -le 1)
		{
			return $true
		}

		$targetList = ($targets -join ', ')
		$message = "You are about to apply remote changes to $($targets.Count) targets.`n`nTargets: $targetList`n`nThis is a broad operation. Continue only if you intend to change every listed machine."
		$confirm = Show-ThemedDialog -Title 'Confirm Remote Apply' -Message $message -Buttons @('Cancel', 'Apply to Targets') -AccentButton 'Apply to Targets'
		return ($confirm -eq 'Apply to Targets')
	}

	<#
	    .SYNOPSIS
	    Internal function Confirm-RemoteTargetApproval.
	#>

	function Confirm-RemoteTargetApproval
	{
		[CmdletBinding()]
		param (
			[Parameter(Mandatory)]
			[string[]]$TargetComputers
		)

		$targets = @($TargetComputers | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim() })
		if ($targets.Count -eq 0)
		{
			return $false
		}

		if (Test-GuiRemoteTargetApproval -ComputerName $targets)
		{
			return $true
		}

		$targetList = ($targets -join ', ')
		$message = "Approve this exact target list for the current GUI session before applying changes.`n`nTargets: $targetList`n`nThe approval is cleared when you disconnect."
		$confirm = Show-ThemedDialog -Title 'Approve Target List' -Message $message -Buttons @('Cancel', 'Approve and Continue') -AccentButton 'Approve and Continue'
		if ($confirm -ne 'Approve and Continue')
		{
			return $false
		}

		Set-GuiRemoteTargetApprovalList -ComputerName $targets -ApprovalMessage 'Remote target list approved for this session.'
		return $true
	}

	<#
	    .SYNOPSIS
	    Internal function Start-GuiAppExecutionRun.
	#>

	function Start-GuiAppExecutionRun
	{
		[CmdletBinding()]
		param (
			[Parameter(Mandatory = $true)]
			[ValidateSet('Install', 'Uninstall', 'Update', 'UpdateAll')]
			[string]$Action,

			[string]$Title,

			[Parameter(Mandatory = $true)]
			[string]$LoaderPath,

			[Parameter(Mandatory = $true)]
			[string]$LocalizationDirectory,

			[Parameter(Mandatory = $true)]
			[string]$UICulture,

			[Parameter(Mandatory = $true)]
			[string]$LogFilePath,

			[string]$LogMode,

			[string]$WinGetId,

			[string]$ChocoId,

			[string]$DisplayName,

			[object]$Application,

			[object[]]$SelectedApps = @(),

			[string]$PreferredSource = $null,

			[object]$PackageManagerAvailabilityState = $null
		)

		if ($Script:AppsOperationInProgress)
		{
			return
		}

		if ((Get-Command -Name 'Test-BaselineReadOnlyMode' -ErrorAction SilentlyContinue) -and (Test-BaselineReadOnlyMode))
		{
			$readOnlyMessage = ("App {0} blocked: Baseline is running in -ReadOnly mode. State mutation is not permitted; restart without -ReadOnly to install/uninstall apps." -f $Action)
			LogWarning $readOnlyMessage
			Write-Warning $readOnlyMessage
			return
		}

		$resolvedDisplayName = $DisplayName
		$resolvedWinGetId = $WinGetId
		$resolvedChocoId = $ChocoId
		if ($Application)
		{
			if ([string]::IsNullOrWhiteSpace([string]$resolvedDisplayName) -and $Application.PSObject.Properties['Name'])
			{
				$resolvedDisplayName = [string]$Application.Name
			}
			if ([string]::IsNullOrWhiteSpace([string]$resolvedWinGetId) -and $Application.PSObject.Properties['WinGetId'])
			{
				$resolvedWinGetId = [string]$Application.WinGetId
			}
			if ([string]::IsNullOrWhiteSpace([string]$resolvedChocoId) -and $Application.PSObject.Properties['ChocoId'])
			{
				$resolvedChocoId = [string]$Application.ChocoId
			}
		}

		$selectedApps = @($SelectedApps | Where-Object { $_ })
		$selectedCount = $selectedApps.Count
		if ((Get-Command -Name 'Set-AppActionStatesQueued' -CommandType Function -ErrorAction SilentlyContinue) -and $Action -in @('Install', 'Uninstall', 'Update'))
		{
			try
			{
				Set-AppActionStatesQueued -Action $Action -Application $Application -SelectedApps @($selectedApps) -PreferredSource $PreferredSource
			}
			catch
			{
				LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionAppQueueStateFailed' -Fallback 'Failed to queue app state for execution'))
			}
		}
		$targetName = if (-not [string]::IsNullOrWhiteSpace([string]$resolvedDisplayName))
		{
			[string]$resolvedDisplayName
		}
		elseif (-not [string]::IsNullOrWhiteSpace([string]$resolvedWinGetId))
		{
			[string]$resolvedWinGetId
		}
		elseif (-not [string]::IsNullOrWhiteSpace([string]$resolvedChocoId))
		{
			[string]$resolvedChocoId
		}
		else
		{
			$null
		}

		$initialActionText = switch ($Action)
		{
			'Install'
			{
				if ($selectedCount -gt 0)
				{
					Get-UxLocalizedString -Key 'Progress_WinGet_StartingInstallationSelected' -Fallback 'Installing {0} selected app(s)...' -FormatArgs @($selectedCount)
				}
				elseif (-not [string]::IsNullOrWhiteSpace($targetName))
				{
					Get-UxLocalizedString -Key 'Progress_WinGet_StartingInstallation' -Fallback 'Starting installation of {0}...' -FormatArgs @($targetName)
				}
				else
				{
					Get-UxLocalizedString -Key 'Progress_WinGet_StartingInstallation' -Fallback 'Starting installation...'
				}
			}
			'Uninstall'
			{
				if ($selectedCount -gt 0)
				{
					Get-UxLocalizedString -Key 'Progress_WinGet_StartingUninstallationSelected' -Fallback 'Uninstalling {0} selected app(s)...' -FormatArgs @($selectedCount)
				}
				elseif (-not [string]::IsNullOrWhiteSpace($targetName))
				{
					Get-UxLocalizedString -Key 'Progress_WinGet_StartingUninstallation' -Fallback 'Starting uninstallation of {0}...' -FormatArgs @($targetName)
				}
				else
				{
					Get-UxLocalizedString -Key 'Progress_WinGet_StartingUninstallation' -Fallback 'Starting uninstallation...'
				}
			}
			'Update'
			{
				if ($selectedCount -gt 0)
				{
					Get-UxLocalizedString -Key 'Progress_WinGet_CheckingUpdatesSelected' -Fallback 'Checking updates for {0} selected app(s)...' -FormatArgs @($selectedCount)
				}
				elseif (-not [string]::IsNullOrWhiteSpace($targetName))
				{
					Get-UxLocalizedString -Key 'Progress_Processing' -Fallback 'Processing {0}...' -FormatArgs @($targetName)
				}
				else
				{
					Get-UxLocalizedString -Key 'Progress_WinGet_CheckingUpdates' -Fallback 'Checking for WinGet updates...'
				}
			}
			'UpdateAll'
			{
				Get-UxLocalizedString -Key 'Progress_WinGet_CheckingUpdates' -Fallback 'Checking for WinGet updates...'
			}
		}

		$executionTitle = if ([string]::IsNullOrWhiteSpace([string]$Title))
		{
			$initialActionText
		}
		else
		{
			[string]$Title
		}

		$wasAppsModeActive = [bool]$Script:AppsModeActive
		$Script:AppsOperationInProgress = $true
		Set-AppsActionControlsEnabled -Enabled $false
		$Script:ExecutionMode = 'Apps'
		$Script:RunState = [hashtable]::Synchronized(@{
			StartedAt        = (Get-Date)
			Paused           = $false
			AbortRequested   = $false
			AbortRequestedAt = [datetime]::MinValue
			Done             = $false
			AbortedRun       = $false
			ForceStopIssued  = $false
			CurrentAction    = $initialActionText
			PreferredSource  = $PreferredSource
			AppOutcome       = $null
			AppResult        = $null
			LogQueue         = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
			Action           = $Action
			Application      = $Application
			SelectedApps     = @($selectedApps)
			AppCompletedCount = 0
			AppProgressTotal = $(if ($selectedCount -gt 0) { $selectedCount } else { 1 })
			AppProgressIndeterminate = ($selectedCount -le 1)
			WasAppsModeActive = $wasAppsModeActive
		})

		Set-Variable -Name 'GUIRunState' -Scope Global -Value $Script:RunState['LogQueue']
		Set-UILogHandler { param($entry) $Script:RunState['LogQueue'].Enqueue($entry) }

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

			Enter-ExecutionView -Title $executionTitle -ShowAbortButton:$false
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
						switch ($qEntry.Kind)
						{
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
										if ([bool]$Script:RunState['AppProgressIndeterminate'] -and [int]$Script:RunState['AppCompletedCount'] -eq 0)
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
									$Script:RunState['AppOutcome'] = $status
								}
								$Script:RunState['AppCompletedCount'] = [Math]::Min(([int]$Script:RunState['AppCompletedCount'] + 1), [int]$Script:RunState['AppProgressTotal'])
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
									$Script:RunState['AppOutcome'] = $status
								}
								$Script:RunState['AppCompletedCount'] = [Math]::Min(([int]$Script:RunState['AppCompletedCount'] + 1), [int]$Script:RunState['AppProgressTotal'])
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
									if (Get-Command -Name 'Write-DebugSwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
									{
										Write-DebugSwallowedException -ErrorRecord $_ -Source 'ExecutionOrchestration.RunLoop.FatalAppError.LogError'
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
												if (Get-Command -Name 'Write-DebugSwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
												{
													Write-DebugSwallowedException -ErrorRecord $_ -Source 'ExecutionOrchestration.RunLoop.FatalAppDiagnostic.LogError'
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

					& $Script:AppDrainQueue

					if ($Script:BgAsync -and -not $Script:BgAsync.IsCompleted -and -not $Script:RunState['Done']) { return }

					if ($Script:ExecutionRunTimer)
					{
						try { $Script:ExecutionRunTimer.Stop() } catch { $null = $_ }
						try { $Script:ExecutionRunTimer.Dispose() } catch { $null = $_ }
					}

					& $Script:AppDrainQueue

					GUIExecution\Complete-GuiExecutionWorker -Worker $Script:ExecutionWorker
					$Script:ExecutionWorker = $null
					$Script:ExecutionRunspace = $null
					$Script:ExecutionRunPowerShell = $null
					$Script:ExecutionRunTimer = $null
					$Script:ExecutionPumpTickFn = $null
					$Script:BgPS = $null
					$Script:BgAsync = $null

					$appOutcome = if (-not [string]::IsNullOrWhiteSpace([string]$Script:RunState['AppOutcome'])) { [string]$Script:RunState['AppOutcome'] } else { 'Success' }
					$finalLabel = switch ($appOutcome.ToLowerInvariant())
					{
						'partial' { Get-UxLocalizedString -Key 'GuiProgressPartiallyComplete' -Fallback 'Partially Complete' }
						'warning' { Get-UxLocalizedString -Key 'GuiProgressPartiallyComplete' -Fallback 'Partially Complete' }
						'failed'  { Get-UxLocalizedString -Key 'GuiProgressFailed' -Fallback 'Failed' }
						default   { Get-UxLocalizedString -Key 'GuiProgressDone' -Fallback 'Done' }
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
	}

	<#
	    .SYNOPSIS
	    Internal function Copy-ExecutionTweakExtraArgs.
	#>

	function Copy-ExecutionTweakExtraArgs
	{
		param (
			$ExtraArgs
		)

		$copy = @{}
		if ($null -eq $ExtraArgs)
		{
			return $copy
		}

		if ($ExtraArgs -is [System.Collections.IDictionary])
		{
			foreach ($entry in $ExtraArgs.GetEnumerator())
			{
				$copy[[string]$entry.Key] = $entry.Value
			}
			return $copy
		}

		foreach ($property in $ExtraArgs.PSObject.Properties)
		{
			$copy[[string]$property.Name] = $property.Value
		}

		return $copy
	}

	<#
	    .SYNOPSIS
	    Internal function Resolve-InteractiveRunSelections.
	#>

	function Resolve-InteractiveRunSelections
	{
		param (
			[object[]]$TweakList
		)

		$tweaks = @($TweakList | Where-Object { $_ })
		if ($tweaks.Count -eq 0)
		{
			return @()
		}

		$resolvedTweaks = [System.Collections.Generic.List[object]]::new()

		<#
		    .SYNOPSIS
		    Internal function New-ResolvedExecutionTweak.
		#>

		function New-ResolvedExecutionTweak
		{
			param (
				[Parameter(Mandatory = $true)]
				$SourceTweak,

				[Parameter(Mandatory = $true)]
				[hashtable]$ResolvedExtraArgs,

				[Parameter(Mandatory = $true)]
				[string]$SelectionLabel
			)

			if ($SourceTweak -is [System.Collections.IDictionary])
			{
				$resolvedTweak = @{}
				foreach ($entry in $SourceTweak.GetEnumerator())
				{
					$resolvedTweak[[string]$entry.Key] = $entry.Value
				}
				$resolvedTweak['ExtraArgs'] = $ResolvedExtraArgs
				$resolvedTweak['Selection'] = $SelectionLabel
				return $resolvedTweak
			}

			$resolvedTweak = [ordered]@{}
			foreach ($property in $SourceTweak.PSObject.Properties)
			{
				$resolvedTweak[[string]$property.Name] = $property.Value
			}
			$resolvedTweak['ExtraArgs'] = $ResolvedExtraArgs
			$resolvedTweak['Selection'] = $SelectionLabel
			return [pscustomobject]$resolvedTweak
		}

		foreach ($tweak in $tweaks)
		{
			[void]$resolvedTweaks.Add($tweak)
		}

		return @($resolvedTweaks)
	}

	<#
	    .SYNOPSIS
	    Internal function Get-ExecutionRollbackCommandList.
	#>

	function Get-ExecutionRollbackCommandList
	{
		param ([object[]]$Results)

		$commands = [System.Collections.Generic.List[string]]::new()
		$seenCommands = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
		foreach ($result in @($Results | Where-Object { $_.Status -in @('Success', 'Restart pending') }))
		{
			$manifestEntry = Get-ManifestEntryByFunction -Manifest $Script:TweakManifest -Function ([string]$result.Function)
			if (-not $manifestEntry) { continue }

			$commandLine = Get-DirectUndoCommandLineForEntry -Entry $result -ManifestEntry $manifestEntry -Manifest $Script:TweakManifest
			if ([string]::IsNullOrWhiteSpace([string]$commandLine)) { continue }
			if ($seenCommands.Add($commandLine))
			{
				[void]$commands.Add($commandLine)
			}
		}

		return @($commands)
	}

	<#
	    .SYNOPSIS
	    Internal function Export-ExecutionRollbackProfile.
	#>

	function Export-ExecutionRollbackProfile
	{
		param (
			[Parameter(Mandatory = $true)][string]$FilePath,
			[object[]]$Results,
			[string]$Mode = 'Run',
			[string]$ProfileName = 'Rollback'
		)

		$rollbackCommands = @(Get-ExecutionRollbackCommandList -Results $Results)
		if ($rollbackCommands.Count -eq 0)
		{
			throw 'No directly undoable changes were available to export.'
		}

		$payload = [ordered]@{
			Schema = 'Baseline.RollbackProfile'
			SchemaVersion = 1
			Name = $ProfileName
			ExportedAt = (Get-Date).ToString('o')
			SourceMode = $Mode
			Entries = @($rollbackCommands)
		}

		[System.IO.File]::WriteAllText($FilePath, ($payload | ConvertTo-Json -Depth 16), [System.Text.UTF8Encoding]::new($false))
		LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionRollbackProfileExported' -Fallback 'Exported rollback profile with {0} command(s): {1}' -FormatArgs @($rollbackCommands.Count, $FilePath))
		return $rollbackCommands.Count
	}

	<#
	    .SYNOPSIS
	    Internal function Complete-GuiExecutionRun.
	#>

	function Complete-GuiExecutionRun
	{
		param (
			[ValidateSet('Run', 'Defaults')]
			[string]$Mode,
			[int]$CompletedCount,
			[bool]$AbortedRun = $false,
			[string]$FatalError = $null,
			[object[]]$ExecutionSummary,
			[string]$LogPath,
			[switch]$RemoteExecution,
			[string]$RemoteTargetLabel = $null
		)

		$executionSummary = @($ExecutionSummary)
		$gameModeContext = Get-ExecutionGameModeContext
		$summaryPayload = GUIExecution\Get-GuiExecutionSummaryPayload -Results $executionSummary
		if ($AbortedRun)
		{
			$resumeCandidates = @(Get-ExecutionResumeCandidateList -Results $executionSummary)
			if ($resumeCandidates.Count -gt 0)
			{
				$null = Save-GuiInterruptedRunProfile -ResumeCandidates $resumeCandidates -Mode $Mode -Reason 'Interrupted run'
			}
			else
			{
				$null = Clear-GuiInterruptedRunProfile
			}
		}
		else
		{
			$null = Clear-GuiInterruptedRunProfile
		}
		if ($Script:RunState)
		{
			$Script:RunState['SummaryPayload'] = $summaryPayload
		}
		$restartPendingCount = $summaryPayload.RestartPendingCount
		$appliedCount = $summaryPayload.AppliedCount
		$failedCount = $summaryPayload.FailedCount
		$skippedCount = $summaryPayload.SkippedCount
		$notApplicableCount = $summaryPayload.NotApplicableCount
		$notRunCount = $summaryPayload.NotRunCount
		# Use summary-derived processed count instead of RunState counter to avoid
		# mismatches when drain queue entries fail to update CompletedCount.
		$CompletedCount = $summaryPayload.TotalCount - $notRunCount
		$recoverableFailedResults = @($executionSummary | Where-Object {
			[string]$_.Status -eq 'Failed' -and (Test-GuiObjectField -Object $_ -FieldName 'IsRecoverable') -and [bool]$_.IsRecoverable
		})
		$executionInsights = Get-ExecutionSummaryInsights -Results $executionSummary -FatalError $FatalError
		$summaryCountsText = Get-ExecutionSummaryCountsText -Mode $Mode -SummaryPayload $summaryPayload -Insights $executionInsights
		$summaryNextStepsText = Get-ExecutionSummaryNextStepsText -Mode $Mode -SummaryPayload $summaryPayload -Insights $executionInsights
		$summaryCards = Get-ExecutionSummaryDialogCards -Mode $Mode -SummaryPayload $summaryPayload -Insights $executionInsights
		$shouldOfferLogReview = [bool]$executionInsights.NeedsLogReview
		$displayLogPath = if ($shouldOfferLogReview) { $LogPath } else { $null }
		$healthCheckFailed = $false
		$summaryNeedsRefresh = $false
		$settingsAppsFeaturesHealthAssessment = $null
		$screenSnippingHealthAssessment = $null
		if (
			$Mode -eq 'Run' -and
			-not $RemoteExecution -and
			-not $AbortedRun -and
			-not $FatalError -and
			$failedCount -eq 0 -and
			$notRunCount -eq 0 -and
			$restartPendingCount -eq 0 -and
			$appliedCount -gt 0 -and
			(Get-Command -Name 'Resolve-BaselineSettingsAppsFeaturesHealthAssessment' -CommandType Function -ErrorAction SilentlyContinue)
		)
		{
			try
			{
				$settingsAppsFeaturesHealthAssessment = Resolve-BaselineSettingsAppsFeaturesHealthAssessment
			}
			catch
			{
				Write-DebugSwallowedException -ErrorRecord $_ -Source 'ExecutionOrchestration.RunCompletion.SettingsAppsFeaturesHealthAssessment'
			}

			if ($settingsAppsFeaturesHealthAssessment -and -not [bool]$settingsAppsFeaturesHealthAssessment.Healthy)
			{
				$healthCheckFailed = $true
			}
		}
		if (
			$Mode -eq 'Run' -and
			-not $RemoteExecution -and
			-not $AbortedRun -and
			-not $FatalError -and
			$failedCount -eq 0 -and
			$notRunCount -eq 0 -and
			$restartPendingCount -eq 0 -and
			$appliedCount -gt 0 -and
			(Get-Command -Name 'Resolve-BaselineScreenSnippingHealthAssessment' -CommandType Function -ErrorAction SilentlyContinue)
		)
		{
			try
			{
				$screenSnippingHealthAssessment = Resolve-BaselineScreenSnippingHealthAssessment
			}
			catch
			{
				Write-DebugSwallowedException -ErrorRecord $_ -Source 'ExecutionOrchestration.RunCompletion.ScreenSnippingHealthAssessment'
			}

			if ($screenSnippingHealthAssessment -and -not [bool]$screenSnippingHealthAssessment.Healthy)
			{
				$healthCheckFailed = $true
				if ($Script:ExecutionSummaryLookup.ContainsKey('PrtScnSnippingTool'))
				{
					Set-ExecutionSummaryStatus -Key 'PrtScnSnippingTool' -Status 'Failed' -Detail ([string]$screenSnippingHealthAssessment.Message)
					$summaryNeedsRefresh = $true
				}
			}
		}

		if ($summaryNeedsRefresh)
		{
			$summaryPayload = GUIExecution\Get-GuiExecutionSummaryPayload -Results $executionSummary
			if ($Script:RunState)
			{
				$Script:RunState['SummaryPayload'] = $summaryPayload
			}
			$restartPendingCount = $summaryPayload.RestartPendingCount
			$appliedCount = $summaryPayload.AppliedCount
			$failedCount = $summaryPayload.FailedCount
			$skippedCount = $summaryPayload.SkippedCount
			$notApplicableCount = $summaryPayload.NotApplicableCount
			$notRunCount = $summaryPayload.NotRunCount
			$CompletedCount = $summaryPayload.TotalCount - $notRunCount
			$recoverableFailedResults = @($executionSummary | Where-Object {
				[string]$_.Status -eq 'Failed' -and (Test-GuiObjectField -Object $_ -FieldName 'IsRecoverable') -and [bool]$_.IsRecoverable
			})
			$executionInsights = Get-ExecutionSummaryInsights -Results $executionSummary -FatalError $FatalError
			$summaryCountsText = Get-ExecutionSummaryCountsText -Mode $Mode -SummaryPayload $summaryPayload -Insights $executionInsights
			$summaryNextStepsText = Get-ExecutionSummaryNextStepsText -Mode $Mode -SummaryPayload $summaryPayload -Insights $executionInsights
			$summaryCards = Get-ExecutionSummaryDialogCards -Mode $Mode -SummaryPayload $summaryPayload -Insights $executionInsights
			$shouldOfferLogReview = [bool]$executionInsights.NeedsLogReview
			$displayLogPath = if ($shouldOfferLogReview) { $LogPath } else { $null }
		}

		if ($settingsAppsFeaturesHealthAssessment -and -not [bool]$settingsAppsFeaturesHealthAssessment.Healthy)
		{
			$summaryNextStepsText = if ([string]::IsNullOrWhiteSpace([string]$summaryNextStepsText))
			{
				[string]$settingsAppsFeaturesHealthAssessment.Message
			}
			else
			{
				'{0}`n{1}' -f [string]$summaryNextStepsText, [string]$settingsAppsFeaturesHealthAssessment.Message
			}
		}

		if ($screenSnippingHealthAssessment -and -not [bool]$screenSnippingHealthAssessment.Healthy)
		{
			$summaryNextStepsText = if ([string]::IsNullOrWhiteSpace([string]$summaryNextStepsText))
			{
				[string]$screenSnippingHealthAssessment.Message
			}
			else
			{
				'{0}`n{1}' -f [string]$summaryNextStepsText, [string]$screenSnippingHealthAssessment.Message
			}
		}

		if ($RemoteExecution)
		{
			$remoteLabel = if (-not [string]::IsNullOrWhiteSpace([string]$RemoteTargetLabel)) { [string]$RemoteTargetLabel } else { 'remote target' }
			$remoteTargetCount = @($executionSummary).Count
			$finalLabel = if ($AbortedRun) { Get-UxLocalizedString -Key 'GuiProgressAborted' -Fallback 'Aborted' } elseif ($FatalError) { Get-UxLocalizedString -Key 'GuiProgressFailed' -Fallback 'Failed' } elseif ($failedCount -gt 0 -or $notRunCount -gt 0) { Get-UxLocalizedString -Key 'GuiProgressPartiallyComplete' -Fallback 'Partially Complete' } else { Get-UxLocalizedString -Key 'GuiProgressDone' -Fallback 'Done' }
			& $Script:UpdateProgressFn -Completed $CompletedCount -Total $(if ($remoteTargetCount -gt 0) { $remoteTargetCount } else { 1 }) -CurrentAction $finalLabel

			$statusMsg = if ($AbortedRun)
			{
				Get-UxBilingualLocalizedString -Key 'GuiStatusRunAborted' -Fallback 'Remote run aborted. Completed {0} of {1}. {2}' -FormatArgs @($CompletedCount, $(if ($remoteTargetCount -gt 0) { $remoteTargetCount } else { 1 }), $summaryCountsText)
			}
			elseif ($FatalError)
			{
				Get-UxBilingualLocalizedString -Key 'GuiStatusRunFailed' -Fallback 'Remote run failed. Completed {0} of {1}. {2} Open the summary for next steps.' -FormatArgs @($CompletedCount, $(if ($remoteTargetCount -gt 0) { $remoteTargetCount } else { 1 }), $summaryCountsText)
			}
			elseif ($failedCount -gt 0 -or $notRunCount -gt 0)
			{
				Get-UxBilingualLocalizedString -Key 'GuiStatusRunPartial' -Fallback 'Remote run partially completed. Completed {0} of {1}. {2} Open the summary for next steps.' -FormatArgs @($CompletedCount, $(if ($remoteTargetCount -gt 0) { $remoteTargetCount } else { 1 }), $summaryCountsText)
			}
			else
			{
				Get-UxBilingualLocalizedString -Key 'GuiStatusRunComplete' -Fallback 'Remote run complete. Completed {0} of {1}. {2}' -FormatArgs @($CompletedCount, $(if ($remoteTargetCount -gt 0) { $remoteTargetCount } else { 1 }), $summaryCountsText)
			}
			Set-GuiStatusText -Text (Get-UxLocalizedString -Key 'GuiStatusRunSummary' -Fallback '{0}' -FormatArgs @($statusMsg)) -Tone $(if ($AbortedRun -or $FatalError -or $failedCount -gt 0 -or $notRunCount -gt 0 -or $healthCheckFailed) { 'caution' } elseif ($restartPendingCount -gt 0) { 'danger' } else { 'success' })

			$dlgTitle = if ($FatalError) { "Remote Run Failed - $remoteLabel" } elseif ($failedCount -gt 0 -or $notRunCount -gt 0) { "Remote Run Partially Completed - $remoteLabel" } elseif ($restartPendingCount -gt 0) { "Remote Run Complete (Restart Pending) - $remoteLabel" } else { "Remote Run Complete - $remoteLabel" }
			$whatChangedText = "What happened: $successCount remote target$(if ($successCount -eq 1) { '' } else { 's' }) completed successfully."
			if ($restartPendingCount -gt 0)
			{
				$whatChangedText += " $restartPendingCount remote target$(if ($restartPendingCount -eq 1) { '' } else { 's' }) still need a restart to finish."
			}
			if ($failedCount -gt 0)
			{
				$whatChangedText += " $failedCount remote target$(if ($failedCount -eq 1) { '' } else { 's' }) failed."
			}
			if ($skippedCount -gt 0)
			{
				$whatChangedText += " $skippedCount remote target$(if ($skippedCount -eq 1) { '' } else { 's' }) were skipped."
			}
			if ($notApplicableCount -gt 0)
			{
				$whatChangedText += " $notApplicableCount remote target$(if ($notApplicableCount -eq 1) { '' } else { 's' }) were not applicable."
			}
			if ($notRunCount -gt 0)
			{
				$whatChangedText += " $notRunCount remote target$(if ($notRunCount -eq 1) { '' } else { 's' }) did not run."
			}

			$dlgMessage = if ($FatalError)
			{
				"$whatChangedText`n`nThe remote run stopped because of an unexpected error.`n`nCompleted $CompletedCount of $(if ($remoteTargetCount -gt 0) { $remoteTargetCount } else { 1 }).`n$summaryCountsText`n`nFatal error:`n$FatalError"
			}
			elseif ($failedCount -gt 0 -or $notRunCount -gt 0)
			{
				"$whatChangedText`n`nRemote execution partially completed.`n`nCompleted $CompletedCount of $(if ($remoteTargetCount -gt 0) { $remoteTargetCount } else { 1 }).`n$summaryCountsText"
			}
			else
			{
				"$whatChangedText`n`nRemote execution completed successfully.`n`nCompleted $CompletedCount of $(if ($remoteTargetCount -gt 0) { $remoteTargetCount } else { 1 }).`n$summaryCountsText"
			}
			if (-not [string]::IsNullOrWhiteSpace([string]$summaryNextStepsText))
			{
				$dlgMessage += "`n`nNext steps: $summaryNextStepsText"
			}
			$summaryButtons = @()
			if ($shouldOfferLogReview) { $summaryButtons += 'Open Detailed Log' }
			$summaryButtons += 'Close'
			$nextStep = Show-ExecutionSummaryDialog -Title $dlgTitle `
				-SummaryText $dlgMessage `
				-Results $executionSummary `
				-LogPath $displayLogPath `
				-SummaryCards $summaryCards `
				-Buttons $summaryButtons

			if ($nextStep -eq 'Open Detailed Log')
			{
				Exit-ExecutionView
				Show-LogDialog -LogPath $LogPath
				Invoke-GuiExecutionCompletionToast -Mode $Mode -Title $dlgTitle -Body $summaryCountsText
				Set-ExecutionGameModeContext -Context $null
				return
			}

			Exit-ExecutionView
			Invoke-GuiExecutionCompletionToast -Mode $Mode -Title $dlgTitle -Body $summaryCountsText
			Set-ExecutionGameModeContext -Context $null
			return
		}

		if ($Mode -eq 'Defaults')
		{
			Sync-DefaultsControlsFromExecutionSummary -Results $executionSummary
			if ($Script:CurrentPrimaryTab)
			{
				Build-TabContent -PrimaryTab $Script:CurrentPrimaryTab
			}

			$finalLabel = if ($AbortedRun) { Get-UxLocalizedString -Key 'GuiProgressAborted' -Fallback 'Aborted' } elseif ($FatalError) { Get-UxLocalizedString -Key 'GuiProgressFailed' -Fallback 'Failed' } elseif ($failedCount -gt 0 -or $notRunCount -gt 0) { Get-UxLocalizedString -Key 'GuiProgressPartiallyComplete' -Fallback 'Partially Complete' } else { Get-UxLocalizedString -Key 'GuiProgressDone' -Fallback 'Done' }
			& $Script:UpdateProgressFn -Completed $CompletedCount -Total $Script:TotalRunnableTweaks -CurrentAction $finalLabel

			if ($AbortedRun)
			{
				$rawRunAbortDisposition = if ($null -eq $Script:RunAbortDisposition) { '<null>' } else { [string]$Script:RunAbortDisposition }
				$runAbortDisposition = Get-RunAbortDisposition
				LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionCompleteDefaultsAborted' -Fallback '[Complete-Defaults] AbortedRun=true, RunAbortDisposition={0}, EffectiveDisposition={1}' -FormatArgs @($rawRunAbortDisposition, $runAbortDisposition))
				Set-GuiStatusText -Text (Get-UxLocalizedString -Key 'GuiStatusDefaultsAborted' -Fallback '' -FormatArgs @($CompletedCount, $Script:TotalRunnableTweaks, $summaryCountsText)) -Tone 'caution'

				if ($runAbortDisposition -eq 'Exit')
				{
					Close-GuiMainWindow -Reason 'Defaults restore abort disposition requested exit.'
				}
				else
				{
					Set-RunAbortDisposition -Disposition 'Return'
					Exit-ExecutionView
				}
				return
			}

			if ($FatalError)
			{
				Set-GuiStatusText -Text (Get-UxLocalizedString -Key 'GuiStatusDefaultsFailed' -Fallback '' -FormatArgs @($CompletedCount, $Script:TotalRunnableTweaks, $summaryCountsText)) -Tone 'caution'
			}
			elseif ($failedCount -gt 0 -or $notRunCount -gt 0)
			{
				Set-GuiStatusText -Text (Get-UxLocalizedString -Key 'GuiStatusDefaultsPartial' -Fallback '' -FormatArgs @($CompletedCount, $Script:TotalRunnableTweaks, $summaryCountsText)) -Tone 'caution'
			}
			elseif ($restartPendingCount -gt 0)
			{
				Set-GuiStatusText -Text (Get-UxLocalizedString -Key 'GuiStatusDefaultsCompleteRestart' -Fallback '' -FormatArgs @($CompletedCount, $Script:TotalRunnableTweaks, $summaryCountsText)) -Tone 'danger'
			}
			else
			{
				Set-GuiStatusText -Text (Get-UxLocalizedString -Key 'GuiStatusDefaultsComplete' -Fallback '' -FormatArgs @($CompletedCount, $Script:TotalRunnableTweaks, $summaryCountsText)) -Tone 'success'
			}

			$dlgTitle = if ($FatalError) { Get-UxLocalizedString -Key 'GuiDlgDefaultsRestoreFailed' -Fallback 'Defaults Restore Failed' } elseif ($restartPendingCount -gt 0 -and $failedCount -eq 0 -and $notRunCount -eq 0) { Get-UxLocalizedString -Key 'GuiDlgDefaultsRestoreRestartPending' -Fallback 'Defaults Restore Restart Pending' } elseif ($failedCount -gt 0 -or $notRunCount -gt 0) { Get-UxLocalizedString -Key 'GuiDlgDefaultsRestorePartiallyCompleted' -Fallback 'Defaults Restore Partially Completed' } else { Get-UxLocalizedString -Key 'GuiDlgDefaultsRestoreComplete' -Fallback 'Defaults Restore Complete' }
			$whatChangedText = Build-WhatChangedSummaryText `
				-OpeningLine "What happened: $appliedCount item$(if ($appliedCount -eq 1) { '' } else { 's' }) restored to Windows defaults." `
				-Noun 'item' `
				-Insights $executionInsights `
				-RestartPendingCount $restartPendingCount `
				-NotRunCount $notRunCount `
				-AlreadyDesiredPhrase 'already matched the Windows default' `
				-RestartPendingPhrase 'still need a restart to finish restoring' `
				-NotApplicableSingularPhrase ' does not apply on this PC or this version of Windows' `
				-NotApplicablePluralPhrase 's do not apply on this PC or this version of Windows' `
				-PolicySkippedSingularPhrase ' is not supported by in-app restore' `
				-PolicySkippedPluralPhrase 's are not supported by in-app restore' `
				-RecoverableSingularPhrase ' qualifies for a safe restore retry' `
				-RecoverablePluralPhrase 's qualify for a safe restore retry' `
				-ManualSingularPhrase ' still needs manual follow-up' `
				-ManualPluralPhrase 's still need manual follow-up'
			$dlgMessage = if ($FatalError) {
				"$whatChangedText`n`nThe defaults restore stopped because of an unexpected error.`n`nCompleted $CompletedCount of $Script:TotalRunnableTweaks.`n$summaryCountsText`n`nFatal error:`n$FatalError"
			}
			elseif ($failedCount -gt 0 -or $notRunCount -gt 0) {
				"$whatChangedText`n`nWindows defaults restore partially completed.`n`nCompleted $CompletedCount of $Script:TotalRunnableTweaks.`n$summaryCountsText"
			}
			else {
				"$whatChangedText`n`nWindows defaults restored successfully.`n`nCompleted $CompletedCount of $Script:TotalRunnableTweaks.`n$summaryCountsText"
			}
			if (-not [string]::IsNullOrWhiteSpace([string]$summaryNextStepsText))
			{
				$dlgMessage += "`n`nNext steps: $summaryNextStepsText"
			}
			$summaryButtons = @()
			if ($recoverableFailedResults.Count -gt 0) { $summaryButtons += 'Retry Safe Restore Failures' }
			$resumeInterruptedResults = @(Get-ExecutionResumeCandidateList -Results $executionSummary)
			if ($abortedRun -and $resumeInterruptedResults.Count -gt 0) { $summaryButtons += 'Resume Interrupted Run' }
			if ($shouldOfferLogReview) { $summaryButtons += 'Open Detailed Log' }
			$summaryButtons += 'Close'
			$nextStep = Show-ExecutionSummaryDialog -Title $dlgTitle `
				-SummaryText $dlgMessage `
				-Results $executionSummary `
				-LogPath $displayLogPath `
				-SummaryCards $summaryCards `
				-Buttons $summaryButtons

			if ($nextStep -eq 'Retry Safe Restore Failures')
			{
				LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionRetryingSafeDefaultsFailures' -Fallback 'Retrying safe defaults failures: Count={0}' -FormatArgs @($recoverableFailedResults.Count))
				Start-GuiExecutionRun -TweakList $recoverableFailedResults -Mode 'Defaults' -ExecutionTitle (Get-UxLocalizedString -Key 'GuiExecTitleRetryingSafeRestore' -Fallback 'Retrying Safe Restore Failures') -ForceUnsupported:$ForceUnsupported
				return
			}
			if ($nextStep -eq 'Resume Interrupted Run')
			{
				LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionResumingInterruptedDefaultsRun' -Fallback 'Resuming interrupted defaults run: Count={0}' -FormatArgs @($resumeInterruptedResults.Count))
				Start-GuiExecutionRun -TweakList $resumeInterruptedResults -Mode 'Defaults' -ExecutionTitle (Get-UxLocalizedString -Key 'GuiExecTitleResumingInterruptedRun' -Fallback 'Resuming Interrupted Run') -ForceUnsupported:$ForceUnsupported
				return
			}
			if ($nextStep -eq 'Open Detailed Log')
			{
				Exit-ExecutionView
				Show-LogDialog -LogPath $LogPath
				Set-ExecutionGameModeContext -Context $null
				return
			}

			Exit-ExecutionView
			Set-ExecutionGameModeContext -Context $null
			return
		}

		$finalLabel = if ($AbortedRun) { Get-UxLocalizedString -Key 'GuiProgressAborted' -Fallback 'Aborted' } elseif ($FatalError) { Get-UxLocalizedString -Key 'GuiProgressFailed' -Fallback 'Failed' } elseif ($failedCount -gt 0 -or $notRunCount -gt 0) { Get-UxLocalizedString -Key 'GuiProgressPartiallyComplete' -Fallback 'Partially Complete' } else { Get-UxLocalizedString -Key 'GuiProgressDone' -Fallback 'Done' }
		& $Script:UpdateProgressFn -Completed $CompletedCount -Total $Script:TotalRunnableTweaks -CurrentAction $finalLabel

		$statusMsg = if ($AbortedRun) {
			Get-UxBilingualLocalizedString -Key 'GuiStatusRunAborted' -Fallback 'Run aborted. Completed {0} of {1}. {2}' -FormatArgs @($CompletedCount, $Script:TotalRunnableTweaks, $summaryCountsText)
		} elseif ($FatalError) {
			Get-UxBilingualLocalizedString -Key 'GuiStatusRunFailed' -Fallback 'Run failed. Completed {0} of {1}. {2} Open the summary for next steps.' -FormatArgs @($CompletedCount, $Script:TotalRunnableTweaks, $summaryCountsText)
		} elseif ($failedCount -gt 0 -or $notRunCount -gt 0) {
			Get-UxBilingualLocalizedString -Key 'GuiStatusRunPartial' -Fallback 'Run partially completed. Completed {0} of {1}. {2} Open the summary for next steps.' -FormatArgs @($CompletedCount, $Script:TotalRunnableTweaks, $summaryCountsText)
		} elseif ($restartPendingCount -gt 0) {
			Get-UxBilingualLocalizedString -Key 'GuiStatusRunCompleteRestart' -Fallback 'Run complete. Completed {0} of {1}. {2} Restart required to finish applying some items.' -FormatArgs @($CompletedCount, $Script:TotalRunnableTweaks, $summaryCountsText)
		} else {
			Get-UxBilingualLocalizedString -Key 'GuiStatusRunComplete' -Fallback 'Run complete. Completed {0} of {1}. {2}' -FormatArgs @($CompletedCount, $Script:TotalRunnableTweaks, $summaryCountsText)
		}
			Set-GuiStatusText -Text (Get-UxLocalizedString -Key 'GuiStatusRunSummary' -Fallback '{0}' -FormatArgs @($statusMsg)) -Tone $(if ($AbortedRun -or $FatalError -or $failedCount -gt 0 -or $notRunCount -gt 0) { 'caution' } elseif ($restartPendingCount -gt 0) { 'danger' } else { 'success' })

			if ($AbortedRun)
			{
				$rawRunAbortDisposition = if ($null -eq $Script:RunAbortDisposition) { '<null>' } else { [string]$Script:RunAbortDisposition }
				$runAbortDisposition = Get-RunAbortDisposition
				LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionCompleteRunAborted' -Fallback '[Complete-Run] AbortedRun=true, RunAbortDisposition={0}, EffectiveDisposition={1}' -FormatArgs @($rawRunAbortDisposition, $runAbortDisposition))
				if ($runAbortDisposition -eq 'Exit')
				{
					Close-GuiMainWindow -Reason 'Run abort disposition requested exit.'
				}
				else
				{
					Set-RunAbortDisposition -Disposition 'Return'
					Exit-ExecutionView
				}
				Set-ExecutionGameModeContext -Context $null
				return
			}

		$gameModeOperation = 'Apply'
		$gameModeUndoList = @()
		$dlgTitle = Get-UxLocalizedString -Key 'GuiDlgRunComplete' -Fallback 'Run Complete'
		$dlgMsg = "Completed $CompletedCount of $Script:TotalRunnableTweaks. $summaryCountsText"
		$rollbackCommandList = @()

		try
		{
			$gameModeOperation = if ($gameModeContext -and (Test-GuiObjectField -Object $gameModeContext -FieldName 'Operation') -and -not [string]::IsNullOrWhiteSpace([string]$gameModeContext.Operation)) { [string]$gameModeContext.Operation } else { 'Apply' }
			if ($gameModeContext -and $gameModeOperation -ne 'Undo')
			{
				$gameModeUndoList = @(Get-GameModeUndoRunList -Results $executionSummary -ProfileName $gameModeContext.Profile)
			}

			$dlgTitle = if ($gameModeContext -and $gameModeOperation -eq 'Undo') {
				if ($FatalError) {
					Get-UxLocalizedString -Key 'GuiDlgGameModeUndoFailed' -Fallback 'Game Mode Undo Failed'
				} elseif ($failedCount -gt 0 -or $notRunCount -gt 0) {
					Get-UxLocalizedString -Key 'GuiDlgGameModeUndoPartiallyCompleted' -Fallback 'Game Mode Undo Partially Completed'
				} elseif ($restartPendingCount -gt 0) {
					Get-UxLocalizedString -Key 'GuiDlgGameModeUndoRestartPending' -Fallback 'Game Mode Undo Restart Pending'
				} else {
					Get-UxLocalizedString -Key 'GuiDlgGameModeUndoComplete' -Fallback 'Game Mode Undo Complete'
				}
			} elseif ($FatalError) {
				Get-UxLocalizedString -Key 'GuiDlgRunFailed' -Fallback 'Run Failed'
			} elseif ($failedCount -gt 0 -or $notRunCount -gt 0) {
				Get-UxLocalizedString -Key 'GuiDlgRunPartiallyCompleted' -Fallback 'Run Partially Completed'
			} elseif ($restartPendingCount -gt 0) {
				Get-UxLocalizedString -Key 'GuiDlgRunCompleteRestartPending' -Fallback 'Run Complete (Restart Pending)'
			} else {
				Get-UxLocalizedString -Key 'GuiDlgRunComplete' -Fallback 'Run Complete'
			}
			$whatChangedOpeningLine = if ($gameModeContext -and $gameModeOperation -eq 'Undo') {
				"What happened: $appliedCount gaming change$(if ($appliedCount -eq 1) { '' } else { 's' }) rolled back successfully."
			} else {
				"What happened: $appliedCount tweak$(if ($appliedCount -eq 1) { '' } else { 's' }) applied successfully."
			}
			# Safe Mode: show human-readable list of what changed instead of technical summary
			$humanReadableSummary = $null
			if ((Test-IsSafeModeUX) -and -not ($gameModeContext -and $gameModeOperation -eq 'Undo'))
			{
				$humanReadableSummary = Get-UxHumanReadableSummary -Results $executionSummary
			}
			$whatChangedText = if ($humanReadableSummary)
			{
				"$whatChangedOpeningLine`n`n$humanReadableSummary"
			}
			else
			{
				Build-WhatChangedSummaryText `
					-OpeningLine $whatChangedOpeningLine `
					-Noun 'tweak' `
					-Insights $executionInsights `
					-RestartPendingCount $restartPendingCount `
					-NotRunCount $notRunCount `
					-AlreadyDesiredPhrase 'already matched the requested state' `
					-RestartPendingPhrase 'still need a restart to finish applying' `
					-NotApplicableSingularPhrase ' did not apply on this system' `
					-NotApplicablePluralPhrase 's did not apply on this system' `
					-PolicySkippedSingularPhrase ' was intentionally skipped by the current selection' `
					-PolicySkippedPluralPhrase 's were intentionally skipped by the current selection'
			}
			$gamingSummaryText = $null
			if ($gameModeContext)
			{
				$restartGuidance = if ($restartPendingCount -gt 0) {
					'Restart guidance: a reboot is recommended after this Game Mode run so graphics and overlay changes can fully settle.'
				}
				else {
					'Restart guidance: no restart-specific gaming actions were queued in this run.'
				}
				if ($gameModeOperation -eq 'Undo')
				{
					$gamingSummaryText = "Game Mode undo summary: profile $($gameModeContext.Profile) rollback finished.`n`n$restartGuidance`n`nYou can rerun Game Mode with a different profile whenever you want to rebuild the focused gaming workflow."
				}
				else
				{
					$decisionText = if ((Test-GuiObjectField -Object $gameModeContext -FieldName 'DecisionOverrides')) { Get-GameModeDecisionOverridesText -Overrides $gameModeContext.DecisionOverrides } else { 'none' }
					$undoOptionsLabel = if (Test-IsSafeModeUX) { 'Undo options' } else { 'Rollback options' }
					$rollbackText = if ($gameModeUndoList.Count -gt 0)
					{
						"{0}: {1} gaming change{2} can be undone directly from the post-run summary." -f $undoOptionsLabel, $gameModeUndoList.Count, $(if ($gameModeUndoList.Count -eq 1) { '' } else { 's' })
					}
					else
					{
						"$undoOptionsLabel`: no directly undoable gaming changes were applied in this run."
					}
					$gamingSummaryText = "Game Mode summary: profile $($gameModeContext.Profile) completed under the focused gaming workflow.`n`nDecision overrides: $decisionText.`n`n$restartGuidance`n`n$rollbackText"
					LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionGameModePostRunSummary' -Fallback 'Game Mode post-run summary: Profile={0}, Applied={1}, RestartPending={2}, DirectUndoEligible={3}, Decisions={4}' -FormatArgs @($gameModeContext.Profile, $appliedCount, $restartPendingCount, $gameModeUndoList.Count, $decisionText))
				}
			}

			$dlgMsg = if ($FatalError) {
				"$whatChangedText`n`nThe run stopped because of an unexpected error.`n`nCompleted $CompletedCount of $Script:TotalRunnableTweaks.`n$summaryCountsText`n`nFatal error:`n$FatalError"
			} elseif ($failedCount -gt 0 -or $notRunCount -gt 0) {
				"$whatChangedText`n`nSelected tweaks partially completed.`n`nCompleted $CompletedCount of $Script:TotalRunnableTweaks.`n$summaryCountsText"
			} elseif ($restartPendingCount -gt 0) {
				"$whatChangedText`n`nSelected tweaks have finished running, but a restart is still recommended to finish applying some changes.`n`nCompleted $CompletedCount of $Script:TotalRunnableTweaks.`n$summaryCountsText"
			} elseif ($skippedCount -gt 0 -or $notApplicableCount -gt 0) {
				"$whatChangedText`n`nSelected tweaks have finished running.`n`nCompleted $CompletedCount of $Script:TotalRunnableTweaks.`n$summaryCountsText"
			} elseif ($healthCheckFailed) {
				"$whatChangedText`n`nSelected tweaks have finished running, but the Settings appsfeatures health check needs attention.`n`nCompleted $CompletedCount of $Script:TotalRunnableTweaks.`n$summaryCountsText"
			} else {
				"$whatChangedText`n`nSelected tweaks have finished running successfully.`n`nCompleted $CompletedCount of $Script:TotalRunnableTweaks.`n$summaryCountsText"
			}
			if (-not [string]::IsNullOrWhiteSpace([string]$gamingSummaryText))
			{
				$dlgMsg += "`n`n$gamingSummaryText"
			}
			if (-not [string]::IsNullOrWhiteSpace([string]$summaryNextStepsText))
			{
				$dlgMsg += "`n`nNext steps: $summaryNextStepsText"
			}
			if (-not ($gameModeContext -and $gameModeOperation -eq 'Undo'))
			{
				$rollbackCommandList = @(Get-ExecutionRollbackCommandList -Results $executionSummary)
			}

			# Post-run snapshot comparison
			if ($Script:PreRunSnapshot)
			{
				try
				{
					$postRunSnapshot = New-SystemStateSnapshot -Manifest $Script:TweakManifest
					$snapshotComparison = Compare-SystemStateSnapshots -Before $Script:PreRunSnapshot -After $postRunSnapshot
					$summaryPayload | Add-Member -NotePropertyName 'SnapshotChangedCount' -NotePropertyValue $snapshotComparison.Changed.Count -Force
					$summaryPayload | Add-Member -NotePropertyName 'SnapshotComparison' -NotePropertyValue $snapshotComparison -Force
					if ($Script:RunState)
					{
						$Script:RunState['PostRunSnapshot'] = $postRunSnapshot
						$Script:RunState['SnapshotComparison'] = $snapshotComparison
					}
					LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionPostRunSnapshotComparison' -Fallback 'Post-run snapshot comparison: {0} changed, {1} unchanged, {2} added, {3} removed' -FormatArgs @($snapshotComparison.Changed.Count, $snapshotComparison.Unchanged.Count, $snapshotComparison.Added.Count, $snapshotComparison.Removed.Count))
				}
				catch
				{
					LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionPostRunSnapshotFailed' -Fallback 'Failed to capture post-run snapshot'))
				}
			}

			# Auto-save last run for Undo Last Run feature and support-bundle
			# snapshot export. Snapshot payloads are retained even when the
			# undo command list is empty so the latest run's diff can still be
			# exported later.
			if (($Mode -eq 'Run' -or $Mode -eq 'Defaults') -and ($rollbackCommandList.Count -gt 0 -or $Script:PreRunSnapshot))
			{
				try
				{
					$lastRunPath = GUICommon\Get-GuiLastRunFilePath
					$lastRunPayload = @{
						Schema = 'Baseline.LastRun'
						Timestamp = (Get-Date -Format 'o')
						AppliedCount = $appliedCount
						RollbackCommands = $rollbackCommandList
						State = (Get-GuiSettingsSnapshot)
						PreRunSnapshot = $Script:PreRunSnapshot
						PostRunSnapshot = if ($Script:RunState -and $Script:RunState.ContainsKey('PostRunSnapshot')) { $Script:RunState['PostRunSnapshot'] } else { $null }
					}
					[System.IO.File]::WriteAllText($lastRunPath, ($lastRunPayload | ConvertTo-Json -Depth 16), [System.Text.UTF8Encoding]::new($false))
					$Script:LastRunProfile = [pscustomobject]$lastRunPayload
					if ((Test-GuiObjectField -Object $Script:BtnUndoLastRun -FieldName 'IsEnabled')) { $Script:BtnUndoLastRun.IsEnabled = ($rollbackCommandList.Count -gt 0) }
					LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionAutoSavedLastRunProfile' -Fallback 'Auto-saved last run profile with {0} rollback command(s).' -FormatArgs @($rollbackCommandList.Count))
				}
				catch
				{
					LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionAutoSaveLastRunProfileFailed' -Fallback 'Failed to auto-save last run profile'))
				}
			}
		}
		catch
		{
			LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionSummaryFailed' -Fallback 'Failed to build execution summary details'))
			# Fall through to show the summary dialog with whatever we have
		}

		while ($true)
		{
			$undoProfileActionLabel = Get-UxUndoProfileActionLabel
			$summaryButtons = @()
			if ($recoverableFailedResults.Count -gt 0)
			{
				$summaryButtons += 'Retry Safe Failures'
			}
			$resumeInterruptedResults = @(Get-ExecutionResumeCandidateList -Results $executionSummary)
			if ($abortedRun -and $resumeInterruptedResults.Count -gt 0)
			{
				$summaryButtons += 'Resume Interrupted Run'
			}
			if ($gameModeContext -and $gameModeOperation -ne 'Undo' -and $gameModeUndoList.Count -gt 0)
			{
				$summaryButtons += 'Undo Game Mode Changes'
			}
			if ($rollbackCommandList.Count -gt 0)
			{
				$summaryButtons += $undoProfileActionLabel
			}
			if ($shouldOfferLogReview)
			{
				$summaryButtons += 'Open Detailed Log'
			}
			$summaryButtons += @('Close', 'Exit')

			$nextStep = Show-ExecutionSummaryDialog -Title $dlgTitle `
				-SummaryText $dlgMsg `
				-Results $executionSummary `
				-LogPath $displayLogPath `
				-SummaryCards $summaryCards `
				-Buttons $summaryButtons

			if ($nextStep -eq 'Retry Safe Failures')
			{
				LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionRetryingSafeFailures' -Fallback 'Retrying safe failures: Count={0}' -FormatArgs @($recoverableFailedResults.Count))
				Start-GuiExecutionRun -TweakList $recoverableFailedResults -Mode 'Run' -ExecutionTitle (Get-UxLocalizedString -Key 'GuiExecTitleRetryingSafeFailures' -Fallback 'Retrying Safe Failures') -ForceUnsupported:$ForceUnsupported
				return
			}
			if ($nextStep -eq 'Resume Interrupted Run')
			{
				LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionResumingInterruptedRun' -Fallback 'Resuming interrupted run: Count={0}' -FormatArgs @($resumeInterruptedResults.Count))
				Start-GuiExecutionRun -TweakList $resumeInterruptedResults -Mode 'Run' -ExecutionTitle (Get-UxLocalizedString -Key 'GuiExecTitleResumingInterruptedRun' -Fallback 'Resuming Interrupted Run') -ForceUnsupported:$ForceUnsupported
				return
			}
			if ($nextStep -eq 'Undo Game Mode Changes')
			{
				LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionGameModeDirectUndoRequested' -Fallback 'Game Mode direct undo requested: Profile={0}, Actions={1}' -FormatArgs @($gameModeContext.Profile, $gameModeUndoList.Count))
				Start-GuiExecutionRun -TweakList $gameModeUndoList -Mode 'Run' -ExecutionTitle (Get-UxLocalizedString -Key 'GuiExecTitleUndoingGameMode' -Fallback 'Undoing Game Mode Changes') -ForceUnsupported:$ForceUnsupported
				return
			}
			if ($nextStep -eq $undoProfileActionLabel)
			{
				$profileLabel = if ($gameModeContext -and -not [string]::IsNullOrWhiteSpace([string]$gameModeContext.Profile))
				{
					'GameMode-{0}-Rollback' -f [string]$gameModeContext.Profile
				}
				else
				{
					'Baseline-Rollback'
				}
				$defaultRollbackFileName = '{0}-{1}.json' -f $profileLabel, (Get-Date -Format 'yyyyMMdd-HHmmss')
				$savePath = Show-GuiFileSaveDialog -Title $undoProfileActionLabel `
					-Filter 'JSON Files (*.json)|*.json|All Files (*.*)|*.*' `
					-DefaultExtension 'json' `
					-FileName $defaultRollbackFileName
				if ([string]::IsNullOrWhiteSpace([string]$savePath))
				{
					continue
				}

				try
				{
					$exportMode = if ($gameModeContext) { 'GameMode' } else { $Mode }
					$exportProfileName = if ($gameModeContext -and -not [string]::IsNullOrWhiteSpace([string]$gameModeContext.Profile))
					{
						'Rollback-{0}' -f [string]$gameModeContext.Profile
					}
					else
					{
						'Rollback'
					}
					$exportedCount = Export-ExecutionRollbackProfile -FilePath $savePath -Results $executionSummary -Mode $exportMode -ProfileName $exportProfileName
					Set-GuiStatusText -Text (Get-UxLocalizedString -Key 'GuiLogExecutionRollbackProfileExported' -Fallback '' -FormatArgs @($exportedCount, $savePath)) -Tone 'accent'
					[void](Show-ThemedDialog -Title $(if (Test-IsSafeModeUX) { (Get-UxLocalizedString -Key 'GuiExportUndoProfile' -Fallback '') } else { (Get-UxLocalizedString -Key 'GuiExportRollbackProfile' -Fallback '') }) -Message (Get-UxLocalizedString -Key 'GuiLogExecutionRollbackProfileExported' -Fallback '' -FormatArgs @($exportedCount, $savePath)) -Buttons @('OK') -AccentButton 'OK')
				}
				catch
				{
					LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionRollbackProfileExportFailed' -Fallback 'Failed to export rollback profile'))
					[void](Show-ThemedDialog -Title $undoProfileActionLabel -Message (Get-UxLocalizedString -Key 'GuiLogExecutionRollbackProfileExportFailed' -Fallback '' -FormatArgs @($_.Exception.Message)) -Buttons @('OK') -AccentButton 'OK')
				}

				continue
			}
			if ($nextStep -eq 'Open Detailed Log')
			{
				Exit-ExecutionView
				Show-LogDialog -LogPath $LogPath
				Set-ExecutionGameModeContext -Context $null
				return
			}

					if ($nextStep -eq 'Close')
					{
						Exit-ExecutionView
						Invoke-GuiSystemScan
					}
					else
					{
						Close-GuiMainWindow -Reason 'Execution summary exit requested.'
					}

			break
		}
		Set-ExecutionGameModeContext -Context $null
	}

	<#
	    .SYNOPSIS
	    Internal function Start-GuiExecutionRun.
	#>

	function Start-GuiExecutionRun
	{
		param (
			[object[]]$TweakList,
			[ValidateSet('Run', 'Defaults')]
			[string]$Mode,
			[string]$ExecutionTitle,
			[switch]$ForceUnsupported
		)

		$tweakList = @($TweakList)
		if ($tweakList.Count -eq 0) { return }

		if ($Mode -in @('Run', 'Defaults') -and (Get-Command -Name 'Test-BaselineReadOnlyMode' -ErrorAction SilentlyContinue) -and (Test-BaselineReadOnlyMode))
		{
			$readOnlyMessage = ("Tweak run blocked: Baseline is running in -ReadOnly mode. State mutation is not permitted; restart without -ReadOnly to apply changes.")
			LogWarning $readOnlyMessage
			Write-Warning $readOnlyMessage
			return
		}

		if ($Mode -in @('Run', 'Defaults') -and $Global:BaselineHostTaint -and [string]$Global:BaselineHostTaint.Level -eq 'Blocked')
		{
			$detectedTweakers = if ($Global:BaselineHostTaint.PSObject.Properties['Detected']) { @($Global:BaselineHostTaint.Detected | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ }) } else { @() }
			$detectedText = if ($detectedTweakers.Count -gt 0) { $detectedTweakers -join ', ' } else { 'unknown third-party tweaker' }
			$hostTaintMessage = ((Get-UxLocalizedString -Key 'GuiHostTaintRunBlocked' -Fallback 'Baseline will not apply system changes because this host is flagged as potentially compromised: {0}. Reinstall Windows from genuine media before running Baseline again.') -f $detectedText)
			LogError $hostTaintMessage
			try { Set-GuiStatusText -Text $hostTaintMessage -Tone 'caution' } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ExecutionOrchestration.HostTaintBlock.StatusText' }

			if (Get-Command -Name 'Show-ThemedDialog' -CommandType Function -ErrorAction SilentlyContinue)
			{
				[void](Show-ThemedDialog -Title (Get-UxLocalizedString -Key 'GuiHostTaintRunBlockedTitle' -Fallback 'Run Blocked') -Message $hostTaintMessage -Buttons @('OK') -AccentButton 'OK')
			}
			else
			{
				Write-Warning $hostTaintMessage
			}
			return
		}

		if ($Mode -in @('Run', 'Defaults'))
		{
			$resolvedTweakList = Resolve-InteractiveRunSelections -TweakList $tweakList
			if ($null -eq $resolvedTweakList)
			{
				return
			}

			$tweakList = @($resolvedTweakList | Where-Object { $_ })
			if ($tweakList.Count -eq 0)
			{
				return
			}
		}

		$remoteContext = $null
		if ($Mode -eq 'Run')
		{
			try { $remoteContext = Get-GuiRemoteTargetContext } catch { $remoteContext = $null }
		}
		if ($Mode -eq 'Run' -and $remoteContext -and $remoteContext.Connected -and $remoteContext.TargetComputers.Count -gt 0)
		{
			$targetLabel = ($remoteContext.TargetComputers -join ', ')
			if (-not (Confirm-RemoteMultiTargetApply -TargetComputers @($remoteContext.TargetComputers)))
			{
				LogInfo ("Remote run cancelled before apply for {0}" -f $targetLabel)
				return
			}
			if (-not (Confirm-RemoteTargetApproval -TargetComputers @($remoteContext.TargetComputers)))
			{
				LogInfo ("Remote run cancelled before target approval for {0}" -f $targetLabel)
				return
			}
			$tempProfileDir = $null
			$tempProfilePath = $null
			$remoteExecutionResults = @()

			try
			{
				$baselineVersion = 'unknown'
				try
				{
					$baselineVersion = Get-BaselineDisplayVersion
				}
				catch
				{
					Write-DebugSwallowedException -ErrorRecord $_ -Source 'ExecutionOrchestration.RemoteRunProfile.BaselineVersion'
				}

				$tempProfileDir = Join-Path ([System.IO.Path]::GetTempPath()) ('BaselineGuiRemote_{0}' -f [guid]::NewGuid().ToString('N'))
				$null = New-Item -Path $tempProfileDir -ItemType Directory -Force
				$tempProfilePath = Join-Path $tempProfileDir 'RemoteRunProfile.json'

				$remoteProfile = New-ConfigurationProfile `
					-Name ('GUI Remote Run {0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss')) `
					-Selections @($tweakList) `
					-AppActions @() `
					-BaselineVersion $baselineVersion `
					-Description ("Remote run requested from the GUI for {0}." -f $targetLabel) `
					-AppsPackageSourcePreference $(if ($Script:AppsPackageSourcePreference) { [string]$Script:AppsPackageSourcePreference } else { $null })
				Export-ConfigurationProfile -Profile $remoteProfile -FilePath $tempProfilePath

				Set-GuiStatusText -Text ("Remote run starting for {0}..." -f $targetLabel) -Tone 'accent'

				$remoteExecutionResults = @(Invoke-BaselineRemoteApply -ComputerName @($remoteContext.TargetComputers) -ProfilePath $tempProfilePath -Credential $remoteContext.Credential)
				$executionSummary = @(
					foreach ($remoteResult in @($remoteExecutionResults))
					{
						if (-not $remoteResult) { continue }

						$remoteErrors = @()
						if ((Test-GuiObjectField -Object $remoteResult -FieldName 'Errors') -and $remoteResult.Errors)
						{
							$remoteErrors = @($remoteResult.Errors | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
						}
						$terminalState = if ((Test-GuiObjectField -Object $remoteResult -FieldName 'TerminalState') -and -not [string]::IsNullOrWhiteSpace([string]$remoteResult.TerminalState)) { [string]$remoteResult.TerminalState } else { $null }

						$status = if ($terminalState -eq 'Succeeded') { 'Success' }
							elseif ($terminalState -eq 'Skipped') { 'Skipped' }
							elseif ($terminalState -eq 'Cancelled') { 'Not Run' }
							elseif ($terminalState -eq 'Retrying') { 'Failed' }
							elseif (($remoteResult.Applied -eq $true) -and ($remoteErrors.Count -eq 0)) { 'Success' }
							elseif (([int]$remoteResult.FailedCount -gt 0) -or ($remoteErrors.Count -gt 0)) { 'Failed' }
							else { 'Skipped' }

						$detail = if ($status -eq 'Success')
						{
							'Applied {0} change(s).' -f ([int]$remoteResult.AppliedCount)
						}
						elseif ($terminalState -eq 'Retrying')
						{
							if ($remoteErrors.Count -gt 0) { 'Retryable failure: {0}' -f ($remoteErrors -join '; ') } else { 'Retryable failure.' }
						}
						elseif ($terminalState -eq 'Cancelled')
						{
							'Cancelled before completion.'
						}
						elseif ($remoteErrors.Count -gt 0)
						{
							$remoteErrors -join '; '
						}
						elseif ([int]$remoteResult.FailedCount -gt 0)
						{
							'Failed to apply {0} change(s).' -f ([int]$remoteResult.FailedCount)
						}
						else
						{
							'No changes were applied.'
						}

						[pscustomobject]@{
							Kind          = 'RemoteTarget'
							Name          = [string]$remoteResult.ComputerName
							Category      = 'Remote Target'
							Status        = $status
							TerminalState = $terminalState
							Detail        = $detail
							Selection     = $targetLabel
							Type          = 'Remote'
							CurrentState  = $(if ($status -eq 'Success') { 'Connected' } elseif ($status -eq 'Skipped') { 'Connected (skipped)' } else { 'Connected with issues' })
							OutcomeState  = $(if ($terminalState -eq 'Succeeded') { 'Applied' } elseif ($terminalState -eq 'Retrying') { 'Retrying' } elseif ($terminalState -eq 'Cancelled') { 'Cancelled' } elseif ($status -eq 'Success') { 'Applied' } elseif ($status -eq 'Failed') { 'Failed' } else { 'Skipped' })
							OutcomeReason = if ($remoteErrors.Count -gt 0) { $remoteErrors -join '; ' } else { $null }
							IsRecoverable = $false
						}
					}
				)

				LogInfo ("Remote run completed for {0}: {1}" -f $targetLabel, ($executionSummary.Count))
				Complete-GuiExecutionRun -Mode 'Run' -CompletedCount $executionSummary.Count -ExecutionSummary $executionSummary -LogPath $Global:LogFilePath -RemoteExecution -RemoteTargetLabel $targetLabel
				return
			}
			catch
			{
				LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionCompleteFailed' -Fallback 'Remote GUI run failed'))
				[void](Show-ThemedDialog -Title (Get-UxLocalizedString -Key 'GuiRemoteConnectTitle' -Fallback 'Connect to Computer') -Message ((Get-UxLocalizedString -Key 'GuiRemoteConnectFailed' -Fallback "Remote execution failed.`n`n{0}") -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
				return
			}
			finally
			{
				if ($tempProfilePath -and (Test-Path -LiteralPath $tempProfilePath))
				{
					try { Remove-Item -LiteralPath $tempProfilePath -Force -ErrorAction SilentlyContinue } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ExecutionOrchestration.RemoteRunCleanup.RemoveTempProfilePath' }
				}
				if ($tempProfileDir -and (Test-Path -LiteralPath $tempProfileDir))
				{
					try { Remove-Item -LiteralPath $tempProfileDir -Recurse -Force -ErrorAction SilentlyContinue } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ExecutionOrchestration.RemoteRunCleanup.RemoveTempProfileDir' }
				}
			}
		}

		Initialize-ExecutionSummary -SelectedTweaks $tweakList

		# Partition by PlatformSupport availability: entries flagged unavailable
		# get marked "Not applicable" in the summary and filtered out of the run,
		# so the report shows them as cleanly skipped instead of disappearing.
		$availableTweaks = New-Object System.Collections.ArrayList
		foreach ($tweak in $tweakList)
		{
			$availabilityGate = GUIExecution\Resolve-GuiExecutionAvailabilityGate -Entry $tweak -ForceUnsupported:$ForceUnsupported
			if ($availabilityGate.Decision -in @('Allow', 'Force'))
			{
				[void]$availableTweaks.Add($tweak)
			}
			else
			{
				$detailText = if ([string]::IsNullOrWhiteSpace($availabilityGate.Reason)) { 'Not available on this system.' } else { $availabilityGate.Reason }
				Set-ExecutionSummaryStatus -Key ([string]$tweak.Key) -Status 'Not applicable' -Detail $detailText
				LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionNotApplicable' -Fallback 'Skipping {0}: {1}' -FormatArgs @([string]$tweak.Function, $detailText))
			}
		}

		$tweakList = @($availableTweaks.ToArray())

		# Pre-flight checks (including restore point creation) already ran
		# and were confirmed via the Plan Summary dialog. Do not re-run.

		Set-ExecutionGameModeContext -Context $(if (Test-HasGameModeTweaks -TweakList $tweakList) {
			[pscustomobject]@{
				Profile = if ($tweakList[0].PSObject.Properties['GameModeProfile']) { [string]$tweakList[0].GameModeProfile } else { [string](Get-GameModeProfile) }
				Operation = if ($tweakList[0].PSObject.Properties['GameModeOperation']) { [string]$tweakList[0].GameModeOperation } else { 'Apply' }
				DecisionOverrides = (Get-GameModeDecisionOverrides)
			}
		}
		else {
			$null
		})
		if (Get-ExecutionGameModeContext)
		{
					LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionGameModeContext' -Fallback 'Game Mode execution context: Operation={0}, Profile={1}, Decisions={2}' -FormatArgs @((Get-ExecutionGameModeContext).Operation, (Get-ExecutionGameModeContext).Profile, (Get-GameModeDecisionOverridesText -Overrides (Get-ExecutionGameModeContext).DecisionOverrides)))
		}
		$Script:PreExecutionErrorCount = $Global:Error.Count
		$Script:ExecutionMode = $Mode

		# Auto-capture pre-run snapshot
		try
		{
			$Script:PreRunSnapshot = $null
			$Script:PostRunSnapshot = $null
			if ($Script:RunState)
			{
				$Script:RunState['PreRunSnapshot'] = $null
				$Script:RunState['PostRunSnapshot'] = $null
			}
			$preRunSnapshot = New-SystemStateSnapshot -Manifest $Script:TweakManifest
			$Script:PreRunSnapshot = $preRunSnapshot
			if ($Script:RunState)
			{
				$Script:RunState['PreRunSnapshot'] = $preRunSnapshot
			}
			$snapshotDir = Join-Path (Get-BaselineDataDirectory) 'Snapshots'
			if (-not (Test-Path $snapshotDir)) { New-Item -Path $snapshotDir -ItemType Directory -Force | Out-Null }
			Limit-SnapshotDirectory -Directory $snapshotDir -Keep 10
			$snapshotPath = Join-Path $snapshotDir ('PreRun-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
			Export-SystemStateSnapshot -Snapshot $preRunSnapshot -Path $snapshotPath
			LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionPreRunSnapshotSaved' -Fallback 'Pre-run snapshot saved: {0} entries captured to {1}' -FormatArgs @($preRunSnapshot.Entries.Count, $snapshotPath))
		}
		catch
		{
			LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionPreRunSnapshotFailed' -Fallback 'Failed to capture pre-run snapshot'))
		}

		# Track this apply run in session statistics
		Add-SessionStatistic -Name 'ApplyRunCount'
		Update-SessionStatistics -Values @{ TweaksSelected = $tweakList.Count }

		Set-GuiStatusText -Text $(if ($Mode -eq 'Defaults') { (Get-UxLocalizedString -Key 'GuiStatusRestoringDefaults' -Fallback '') } else { (Get-UxLocalizedString -Key 'GuiStatusRunningTweaks' -Fallback '') }) -Tone 'accent'
		$null = Invoke-GuiDispatcherAction -Dispatcher $Form.Dispatcher -PriorityUsage 'RenderRefresh' -Synchronous -Action {}

		Stop-Foreground
		if ($Mode -eq 'Defaults')
		{
			Save-GuiUndoSnapshot
		}

			if ($Script:GuiState) { & $Script:GuiState.Set 'RunInProgress' $true } else { $Script:RunInProgress = $true }
		if ((Test-GuiObjectField -Object $PrimaryTabs -FieldName 'IsEnabled')) { $PrimaryTabs.IsEnabled = $false }
		if ((Test-GuiObjectField -Object $BtnRun -FieldName 'Content')) { $BtnRun.Content = Get-UxLocalizedString -Key 'GuiPauseButton' -Fallback 'Pause' }
		if ((Test-GuiObjectField -Object $BtnRun -FieldName 'IsEnabled')) { $BtnRun.IsEnabled = $true }
		if ((Test-GuiObjectField -Object $BtnPreviewRun -FieldName 'IsEnabled')) { $BtnPreviewRun.IsEnabled = $false }
		if ((Test-GuiObjectField -Object $BtnDefaults -FieldName 'IsEnabled')) { $BtnDefaults.IsEnabled = $false }
		Set-GuiActionButtonsEnabled -Enabled $false
		if ((Test-GuiObjectField -Object $ChkScan -FieldName 'IsEnabled')) { $ChkScan.IsEnabled = $false }
		if ((Test-GuiObjectField -Object $ChkTheme -FieldName 'IsEnabled')) { $ChkTheme.IsEnabled = $false }
		Set-SearchControlsEnabled -Enabled $false
			Enter-ExecutionView -Title $ExecutionTitle
			Reset-RunAbortState

			$Script:TotalRunnableTweaks = $tweakList.Count
		$Script:CurrentTweakDisplayName = $null

		$Script:RunState = [hashtable]::Synchronized(@{
			StartedAt        = (Get-Date)
			Paused           = $false
			AbortRequested   = $false
			AbortRequestedAt = [datetime]::MinValue
			Done             = $false
				AbortedRun       = $false
				AbortDisposition = $null
				CompletedCount   = 0
			ErrorCount       = 0
			FatalError       = $null
			ForceStopIssued  = $false
			CurrentTweak     = ''
			FailureDetails   = [System.Collections.ArrayList]::new()
			LogQueue         = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
			SkippedTweaks    = [hashtable]::Synchronized(@{})
			NotExecutableCount = 0
			AppliedFunctions = [System.Collections.Concurrent.ConcurrentBag[string]]::new()
			AppliedTweakMetadata = [System.Collections.ArrayList]::new()
			SummaryPayload   = $null
		})
		& $Script:UpdateProgressFn -Completed 0 -Total $Script:TotalRunnableTweaks -CurrentAction (Get-UxLocalizedString -Key 'GuiProgressStarting' -Fallback 'Starting...')

		$Script:AppendLogFn = {
			param($Text, $Level = 'INFO')
			if (-not $Script:ExecutionLogBox -or -not $Script:ExecutionLogBox.Document) { return }
			$cleanText = ($Text -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', '').Trim()
			if ([string]::IsNullOrWhiteSpace($cleanText)) { return }

			$bc = [System.Windows.Media.BrushConverter]::new()

			$para = New-Object System.Windows.Documents.Paragraph
			$para.Margin = [System.Windows.Thickness]::new(0, 0, 0, 2)
			$para.FontFamily = New-Object System.Windows.Media.FontFamily('Consolas')
			$para.FontSize = $Script:GuiLayout.FontSizeSubheading

			$contentRun = New-Object System.Windows.Documents.Run
			$contentRun.Text = $cleanText
			$contentColor = switch ($Level.ToUpperInvariant())
			{
				'SUCCESS' { $Script:CurrentTheme.ToggleOn }
				'SKIP'    { $Script:CurrentTheme.TextMuted }
				'ERROR'   { $Script:CurrentTheme.CautionText }
				'WARNING' { $Script:CurrentTheme.RiskMediumBadge }
				default   { $Script:CurrentTheme.TextPrimary }
			}
			$contentRun.Foreground = $bc.ConvertFromString($contentColor)
			[void]($para.Inlines.Add($contentRun))
			[void]($Script:ExecutionLogBox.Document.Blocks.Add($para))
			$vO = $Script:ExecutionLogBox.VerticalOffset
			$vH = $Script:ExecutionLogBox.ViewportHeight
			$eH = $Script:ExecutionLogBox.ExtentHeight
			if (($vO + $vH) -ge ($eH - 30)) { $Script:ExecutionLogBox.ScrollToEnd() }
		}

			$Script:DrainEntry = {
				param($entry)
				switch ($entry.Kind)
				{
				'Log'
				{
					if (Test-ExecutionSkipMessage -Message $entry.Message)
					{
						$skipKey = if (-not [string]::IsNullOrWhiteSpace($Script:ExecutionCurrentSummaryKey)) { $Script:ExecutionCurrentSummaryKey } else { $null }
						if (-not [string]::IsNullOrWhiteSpace($skipKey))
						{
							$skipDetail = if ((Test-GuiObjectField -Object $entry -FieldName 'Message')) { [string]$entry.Message } else { 'Skipped because the system already matched the requested state.' }
							$Script:RunState['SkippedTweaks'][$skipKey] = $skipDetail
							Set-ExecutionSummaryStatus -Key $skipKey -Status 'Skipped' -Detail $skipDetail
						}
					}
				}
				'_TweakStarted'
				{
					$Script:RunState['CurrentTweak'] = $entry.Name
					$Script:ExecutionCurrentSummaryKey = if ((Test-GuiObjectField -Object $entry -FieldName 'Key')) { [string]$entry.Key } else { $null }
					if (-not [string]::IsNullOrWhiteSpace($Script:ExecutionCurrentSummaryKey))
					{
						if ($Script:RunState['SkippedTweaks'].ContainsKey($Script:ExecutionCurrentSummaryKey))
						{
							$null = $Script:RunState['SkippedTweaks'].Remove($Script:ExecutionCurrentSummaryKey)
						}
						Set-ExecutionSummaryStatus -Key $Script:ExecutionCurrentSummaryKey -Status 'Running'
					}
					$Script:ExecutionLastConsoleAction = $null
					$Script:ExecutionCurrentStepIndex = if ((Test-GuiObjectField -Object $entry -FieldName 'StepIndex')) { [int]$entry.StepIndex } else { $null }
					$Script:ExecutionCurrentStepTotal = if ((Test-GuiObjectField -Object $entry -FieldName 'StepTotal')) { [int]$entry.StepTotal } else { $null }
					$progressLabel = $entry.Name
					$startProgress = if ($null -ne $Script:ExecutionCurrentStepIndex) { [int]$Script:ExecutionCurrentStepIndex - 1 } else { [int]$Script:RunState['CompletedCount'] }
					& $Script:UpdateProgressFn -Completed $startProgress -Total $Script:TotalRunnableTweaks -CurrentAction $progressLabel
				}
				'_TweakCompleted'
				{
					$completedStatus = if ([string]::IsNullOrWhiteSpace($entry.Status)) { 'success' } else { $entry.Status.ToLowerInvariant() }
					$completedName = ($entry.Name -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', '').Trim()
					$completedKey = if ((Test-GuiObjectField -Object $entry -FieldName 'Key')) { [string]$entry.Key } else { $null }
					$wasSkipped = $false
					$skipDetail = $null
					if ((Test-GuiObjectField -Object $entry -FieldName 'Count'))
					{
						$Script:RunState['CompletedCount'] = [int]$entry.Count
					}
					if (-not [string]::IsNullOrWhiteSpace($completedKey) -and $Script:RunState['SkippedTweaks'].ContainsKey($completedKey))
					{
						$wasSkipped = $true
						$skipDetail = [string]$Script:RunState['SkippedTweaks'][$completedKey]
						$null = $Script:RunState['SkippedTweaks'].Remove($completedKey)
					}
					if (-not [string]::IsNullOrWhiteSpace($completedName))
					{
						$resolvedOutcome = $null
						if ($wasSkipped)
						{
							$completedRecord = if (-not [string]::IsNullOrWhiteSpace($completedKey)) { $Script:ExecutionSummaryLookup[$completedKey] } else { $null }
							$resolvedOutcome = GUIExecution\Get-GuiExecutionOutcome -Status 'Skipped' -Detail $skipDetail -RequiresRestart $(if ($completedRecord -and (Test-GuiObjectField -Object $completedRecord -FieldName 'RequiresRestart')) { [bool]$completedRecord.RequiresRestart } else { $false })
							Set-ExecutionSummaryStatus -Key $completedKey -Status $resolvedOutcome -Detail $skipDetail
						}
						else
						{
							$completedRecord = if (-not [string]::IsNullOrWhiteSpace($completedKey)) { $Script:ExecutionSummaryLookup[$completedKey] } else { $null }
							$baseStatus = if ($completedStatus -eq 'success') { 'Success' } else { 'Failed' }
							$resolvedOutcome = GUIExecution\Get-GuiExecutionOutcome -Status $baseStatus -Detail $null -RequiresRestart $(if ($completedRecord -and (Test-GuiObjectField -Object $completedRecord -FieldName 'RequiresRestart')) { [bool]$completedRecord.RequiresRestart } else { $false })
							Set-ExecutionSummaryStatus -Key $completedKey -Status $resolvedOutcome
						}

						$completedRecord = if (-not [string]::IsNullOrWhiteSpace($completedKey)) { $Script:ExecutionSummaryLookup[$completedKey] } else { $null }
						if (-not $completedRecord)
						{
							$completedRecord = [pscustomobject]@{
								Name = $completedName
								Status = $resolvedOutcome
								Detail = if ($wasSkipped) { $skipDetail } else { $null }
								OutcomeState = $resolvedOutcome
								OutcomeReason = if ($wasSkipped) { $skipDetail } else { $null }
							}
						}

						$liveLogEntry = Get-ExecutionResultLiveLogEntry -Record $completedRecord
						if ($liveLogEntry -and -not [string]::IsNullOrWhiteSpace([string]$liveLogEntry.Message))
						{
							$completedStepIndex = if ((Test-GuiObjectField -Object $entry -FieldName 'StepIndex')) { [int]$entry.StepIndex } else { $null }
							$completedStepTotal = if ((Test-GuiObjectField -Object $entry -FieldName 'StepTotal')) { [int]$entry.StepTotal } else { $null }
							$logMessage = if ($null -ne $completedStepIndex -and $null -ne $completedStepTotal) {
								"[{0}/{1}] {2}" -f $completedStepIndex, $completedStepTotal, ([string]$liveLogEntry.Message)
							} else { [string]$liveLogEntry.Message }
							& $Script:AppendLogFn $logMessage $(if ((Test-GuiObjectField -Object $liveLogEntry -FieldName 'Level')) { [string]$liveLogEntry.Level } else { 'INFO' })
						}
					}
					if (-not [string]::IsNullOrWhiteSpace($completedKey))
					{
						$completedRecord = $Script:ExecutionSummaryLookup[$completedKey]
						if ($completedRecord -and $Script:RunState['AppliedTweakMetadata'])
						{
							$appliedMetadata = GUIExecution\New-GuiExecutionAppliedTweakMetadata -Result $completedRecord -Outcome ([string]$completedRecord.Status)
							if ($appliedMetadata)
							{
								[void]$Script:RunState['AppliedTweakMetadata'].Add($appliedMetadata)
							}
						}
					}
					$Script:ExecutionCurrentSummaryKey = $null
					$Script:ExecutionCurrentStepIndex = $null
					$Script:ExecutionCurrentStepTotal = $null
					$Script:ExecutionLastConsoleAction = $null
					$completedProgress = if ($null -ne $completedStepIndex) { [int]$completedStepIndex } else { [int]$Script:RunState['CompletedCount'] }
					& $Script:UpdateProgressFn -Completed $completedProgress -Total $Script:TotalRunnableTweaks -CurrentAction $completedName
				}
				'_TweakFailed'
				{
					$failedKey = if ((Test-GuiObjectField -Object $entry -FieldName 'Key')) { [string]$entry.Key } else { $null }
					if (-not [string]::IsNullOrWhiteSpace($failedKey) -and $Script:RunState['SkippedTweaks'].ContainsKey($failedKey))
					{
						$null = $Script:RunState['SkippedTweaks'].Remove($failedKey)
					}
					if (-not [string]::IsNullOrWhiteSpace($entry.Name))
					{
						[void]$Script:RunState['FailureDetails'].Add([PSCustomObject]@{
							Name  = $entry.Name
							Error = if ((Test-GuiObjectField -Object $entry -FieldName 'Error')) { $entry.Error } else { $null }
						})
					}
					if (-not [string]::IsNullOrWhiteSpace($failedKey))
					{
						Set-ExecutionSummaryStatus -Key $failedKey -Status 'Failed' -Detail $(if ((Test-GuiObjectField -Object $entry -FieldName 'Error')) { [string]$entry.Error } else { $null })
					}
					& $Script:UpdateProgressFn -Completed $Script:RunState['CompletedCount'] -Total $Script:TotalRunnableTweaks -CurrentAction $Script:RunState['CurrentTweak']
				}
				'_RunError'
				{
					$Script:RunState['FatalError'] = if ([string]::IsNullOrWhiteSpace($entry.Error)) { 'Unexpected fatal run error.' } else { [string]$entry.Error }
					& $Script:AppendLogFn ("Fatal run error: {0}" -f $Script:RunState['FatalError']) 'ERROR'
					$diagnosticText = if ((Test-GuiObjectField -Object $entry -FieldName 'Diagnostic')) { [string]$entry.Diagnostic } else { $null }
					if (-not [string]::IsNullOrWhiteSpace($diagnosticText))
					{
						foreach ($diagnosticLine in @($diagnosticText -split "(`r`n|`n|`r)"))
						{
							if (-not [string]::IsNullOrWhiteSpace([string]$diagnosticLine))
							{
								& $Script:AppendLogFn $diagnosticLine 'ERROR'
							}
						}
					}
					LogError (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionFatalRunError' -Fallback 'Fatal run error: {0}' -FormatArgs @($Script:RunState['FatalError']))
				}
				'_RunNotice'
				{
				}
				'ConsoleAction'
				{
					$cleanAct = ($entry.Action -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', '').Trim()
					$Script:ExecutionLastConsoleAction = $cleanAct
					& $Script:UpdateProgressFn -Completed $Script:RunState['CompletedCount'] -Total $Script:TotalRunnableTweaks -CurrentAction $cleanAct
				}
				'ConsoleStatus'
				{
					$Script:ExecutionLastConsoleAction = $null
				}
				'ConsoleComplete'
				{
					$Script:ExecutionLastConsoleAction = $null
				}
				'_InteractiveSelectionRequest'
				{
					$responseState = if ((Test-GuiObjectField -Object $entry -FieldName 'ResponseState')) { $entry.ResponseState } else { $null }
					try
					{
						switch ([string]$entry.RequestType)
						{
							'ScheduledTasks'
							{
								$selectionArgs = @{
									CollectSelectionOnly = $true
								}
								$requestedMode = if ((Test-GuiObjectField -Object $entry -FieldName 'Mode')) { [string]$entry.Mode } else { $null }
								if ($requestedMode -in @('Enable', 'Disable'))
								{
									$selectionArgs[$requestedMode] = $true
								}
								else
								{
									throw "Unsupported ScheduledTasks selection mode '$requestedMode'."
								}
								if ((Test-GuiObjectField -Object $entry -FieldName 'SelectedNames') -and $null -ne $entry.SelectedNames)
								{
									$selectionArgs['SelectedTaskNames'] = @($entry.SelectedNames)
								}

								$selectionResult = ScheduledTasks @selectionArgs
								if ($responseState)
								{
									$responseState['Result'] = $selectionResult
								}
							}
							'UWPApps' # NOTE: string must match the function name in UWPApps.psm1
							{
								$selectionArgs = @{
									CollectSelectionOnly = $true
								}
								$requestedMode = if ((Test-GuiObjectField -Object $entry -FieldName 'Mode')) { [string]$entry.Mode } else { $null }
								if ($requestedMode -in @('Install', 'Uninstall'))
								{
									$selectionArgs[$requestedMode] = $true
								}
								else
								{
									throw "Unsupported UWPApps selection mode '$requestedMode'."
								}
								if ((Test-GuiObjectField -Object $entry -FieldName 'ForAllUsers') -and [bool]$entry.ForAllUsers)
								{
									$selectionArgs['ForAllUsers'] = $true
								}
								if ((Test-GuiObjectField -Object $entry -FieldName 'SelectedPackages') -and $null -ne $entry.SelectedPackages)
								{
									$selectionArgs['SelectedPackages'] = @($entry.SelectedPackages)
								}

								$selectionResult = UWPApps @selectionArgs
								if ($responseState)
								{
									$responseState['Result'] = $selectionResult
								}
							}
							'WindowsCapabilities'
							{
								$selectionArgs = @{
									CollectSelectionOnly = $true
								}
								$requestedMode = if ((Test-GuiObjectField -Object $entry -FieldName 'Mode')) { [string]$entry.Mode } else { $null }
								if ($requestedMode -in @('Install', 'Uninstall'))
								{
									$selectionArgs[$requestedMode] = $true
								}
								else
								{
									throw "Unsupported WindowsCapabilities selection mode '$requestedMode'."
								}
								if ((Test-GuiObjectField -Object $entry -FieldName 'SelectedNames') -and $null -ne $entry.SelectedNames)
								{
									$selectionArgs['SelectedCapabilityNames'] = @($entry.SelectedNames)
								}

								$selectionResult = WindowsCapabilities @selectionArgs
								if ($responseState)
								{
									$responseState['Result'] = $selectionResult
								}
							}
							'WindowsFeatures'
							{
								$selectionArgs = @{
									CollectSelectionOnly = $true
								}
								$requestedMode = if ((Test-GuiObjectField -Object $entry -FieldName 'Mode')) { [string]$entry.Mode } else { $null }
								if ($requestedMode -in @('Enable', 'Disable'))
								{
									$selectionArgs[$requestedMode] = $true
								}
								else
								{
									throw "Unsupported WindowsFeatures selection mode '$requestedMode'."
								}
								if ((Test-GuiObjectField -Object $entry -FieldName 'SelectedNames') -and $null -ne $entry.SelectedNames)
								{
									$selectionArgs['SelectedFeatureNames'] = @($entry.SelectedNames)
								}

								$selectionResult = WindowsFeatures @selectionArgs
								if ($responseState)
								{
									$responseState['Result'] = $selectionResult
								}
							}
							default
							{
								throw "Unsupported interactive selection request type '$([string]$entry.RequestType)'."
							}
						}
					}
					catch
					{
						$errorText = if (Get-Command -Name 'Format-BaselineErrorForLog' -CommandType Function -ErrorAction SilentlyContinue)
						{
							Format-BaselineErrorForLog -ErrorObject $_ -Prefix ("Interactive selection request failed: {0}" -f [string]$entry.RequestType)
						}
						else
						{
							$_.Exception.ToString()
						}
						try { LogError $errorText } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ExecutionOrchestration.InteractiveSelectionRequest.LogError' }
						if ($responseState)
						{
							$responseState['Error'] = $errorText
						}
					}
					finally
					{
						if ($responseState)
						{
							$responseState['Done'] = $true
						}
					}
				}
				'_SubProgress'
				{
					$subAct = if ((Test-GuiObjectField -Object $entry -FieldName 'Action')) { $entry.Action } else { $null }
					$subPct = if ((Test-GuiObjectField -Object $entry -FieldName 'Percent')) { [int]$entry.Percent } else { -1 }
					$subComp = if ((Test-GuiObjectField -Object $entry -FieldName 'Completed')) { [int]$entry.Completed } else { 0 }
					$subTot = if ((Test-GuiObjectField -Object $entry -FieldName 'Total')) { [int]$entry.Total } else { 0 }
					if ($subPct -lt 0 -and $subTot -gt 0) { $subPct = [Math]::Round(($subComp / $subTot) * 100) }
					$detail = if ($subAct -and $subPct -ge 0) { "{0} ({1}%)" -f $subAct, $subPct }
						elseif ($subAct) { $subAct }
						elseif ($subPct -ge 0) { "{0}%" -f $subPct }
						else { $null }
					if ($detail)
					{
						& $Script:UpdateProgressFn -Completed $Script:RunState['CompletedCount'] -Total $Script:TotalRunnableTweaks -CurrentAction $detail
					}
					}
				}
			}

			$Script:DrainExecutionQueueSafely = {
				$qEntry = $null
				while ($Script:RunState['LogQueue'].TryDequeue([ref]$qEntry))
				{
					try
					{
						& $Script:DrainEntry $qEntry
					}
					catch
					{
						$entryKind = if ($qEntry -and (Test-GuiObjectField -Object $qEntry -FieldName 'Kind')) { [string]$qEntry.Kind } else { '<unknown>' }
						$entryName = if ($qEntry -and (Test-GuiObjectField -Object $qEntry -FieldName 'Name')) { [string]$qEntry.Name } else { $null }
						$entryAction = if ($qEntry -and (Test-GuiObjectField -Object $qEntry -FieldName 'Action')) { [string]$qEntry.Action } else { $null }
						$entryLabel = if (-not [string]::IsNullOrWhiteSpace($entryName)) { '{0}/{1}' -f $entryKind, $entryName }
							elseif (-not [string]::IsNullOrWhiteSpace($entryAction)) { '{0}/{1}' -f $entryKind, $entryAction }
							else { $entryKind }

						switch ($entryKind)
						{
							'_TweakStarted'
							{
								if (-not [string]::IsNullOrWhiteSpace($entryName))
								{
									$Script:RunState['CurrentTweak'] = $entryName
								}
								$Script:ExecutionCurrentSummaryKey = if ($qEntry -and (Test-GuiObjectField -Object $qEntry -FieldName 'Key')) { [string]$qEntry.Key } else { $null }
							}
							'_TweakCompleted'
							{
								if ($qEntry -and (Test-GuiObjectField -Object $qEntry -FieldName 'Count'))
								{
									$Script:RunState['CompletedCount'] = [int]$qEntry.Count
								}
								if (-not [string]::IsNullOrWhiteSpace($entryName))
								{
									$Script:RunState['CurrentTweak'] = $entryName
								}
								$Script:ExecutionCurrentSummaryKey = $null
							}
							'_TweakFailed'
							{
								$Script:ExecutionCurrentSummaryKey = $null
							}
							'ConsoleAction'
							{
								if (-not [string]::IsNullOrWhiteSpace($entryAction))
								{
									$Script:ExecutionLastConsoleAction = $entryAction
								}
							}
							'ConsoleStatus'
							{
								$Script:ExecutionLastConsoleAction = $null
							}
							'ConsoleComplete'
							{
								$Script:ExecutionLastConsoleAction = $null
							}
						}

						LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionQueueEntryFailed' -Fallback '[Timer] Queue entry failed [{0}]' -FormatArgs @($entryLabel)))
					}
					finally
					{
						$qEntry = $null
					}
				}
			}

			Set-Variable -Name 'GUIRunState' -Scope Global -Value $Script:RunState['LogQueue']
			Set-UILogHandler { param($entry) $Script:RunState['LogQueue'].Enqueue($entry) }

		LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionStarting' -Fallback 'Starting tweak execution (mode: {0}, scenario: {1})' -FormatArgs @($Mode, $(if (Get-ExecutionGameModeContext) { 'Game' } else { 'Standard' })))

		$bgModuleDir   = Split-Path $Script:ExecutionOrchestrationRoot -Parent
		$bgLoaderPath  = Join-Path $bgModuleDir 'Baseline.psm1'
		$bgRootDir     = Split-Path $bgModuleDir -Parent
		$bgLocDir      = Join-Path $bgRootDir 'Localizations'
		$bgUICulture   = $PSUICulture
		$bgLogFilePath = $Global:LogFilePath

		$Script:ExecutionWorker = GUIExecution\Start-GuiExecutionWorker `
			-RunState $Script:RunState `
			-TweakList $tweakList `
			-Mode $Mode `
			-LoaderPath $bgLoaderPath `
			-LocalizationDirectory $bgLocDir `
			-UICulture $bgUICulture `
			-LogFilePath $bgLogFilePath `
			-LogMode $(if (Get-ExecutionGameModeContext) { 'Game' } else { $null }) `
			-ForceUnsupported:$ForceUnsupported
		$Script:BgPS = $Script:ExecutionWorker.PowerShell
		$Script:BgAsync = $Script:ExecutionWorker.AsyncResult
		$Script:ExecutionRunspace = $Script:ExecutionWorker.Runspace
		$Script:ExecutionRunPowerShell = $Script:ExecutionWorker.PowerShell

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
						Message = 'Abort requested - stopping the current operation now.'
					})
					$bgPsToStop = $Script:BgPS
					if ($bgPsToStop)
					{
						GUIExecution\Request-GuiExecutionWorkerStop -PowerShellInstance $bgPsToStop
					}
				}

					& $Script:DrainExecutionQueueSafely

					$completed = [int]$Script:RunState['CompletedCount']
					if (-not $Script:RunState['Paused'])
					{
						$currentAction = if (-not [string]::IsNullOrWhiteSpace($Script:RunState['CurrentTweak'])) { $Script:RunState['CurrentTweak'] } else { Get-UxExecutionPlaceholderText -Kind 'Working' }
						& $Script:UpdateProgressFn -Completed $completed -Total $Script:TotalRunnableTweaks -CurrentAction $currentAction
					}

				if ($Script:BgAsync -and -not $Script:BgAsync.IsCompleted -and -not $Script:RunState['Done']) { return }

				# Do not complete the run while the abort dialog is showing to prevent stacked dialogs
				if ($Script:AbortDialogShowing) { return }

				if ($Script:ExecutionRunTimer)
				{
					try { $Script:ExecutionRunTimer.Stop() } catch { $null = $_ }
					try { $Script:ExecutionRunTimer.Dispose() } catch { $null = $_ }
				}

					& $Script:DrainExecutionQueueSafely

					GUIExecution\Complete-GuiExecutionWorker -Worker $Script:ExecutionWorker
				$Script:ExecutionWorker = $null
				$Script:ExecutionRunspace = $null
				$Script:ExecutionRunPowerShell = $null
				$Script:ExecutionRunTimer = $null
				$Script:BgPS = $null
				$Script:BgAsync = $null

				foreach ($fn in $Script:RunState['AppliedFunctions']) { [void]$Script:AppliedTweaks.Add($fn) }

				Clear-UILogHandler
				Remove-Variable -Name 'GUIRunState' -Scope Global -ErrorAction SilentlyContinue
				if ($Script:GuiState) { & $Script:GuiState.Set 'RunInProgress' $false } else { $Script:RunInProgress = $false }
				$Script:CurrentTweakDisplayName = $null
                if ((Test-GuiObjectField -Object $PrimaryTabs -FieldName 'IsEnabled')) { $PrimaryTabs.IsEnabled = $true }
                if ((Test-GuiObjectField -Object $BtnRun -FieldName 'IsEnabled')) { $BtnRun.IsEnabled = $true }
                if ($BtnPreviewRun) { $BtnPreviewRun.IsEnabled = $true }
                if ((Test-GuiObjectField -Object $BtnDefaults -FieldName 'IsEnabled')) { $BtnDefaults.IsEnabled = $true }
                Set-GuiActionButtonsEnabled -Enabled $true
                if ((Test-GuiObjectField -Object $ChkScan -FieldName 'IsEnabled')) { $ChkScan.IsEnabled = $true }
                if ((Test-GuiObjectField -Object $ChkTheme -FieldName 'IsEnabled')) { $ChkTheme.IsEnabled = $true }
                Set-SearchControlsEnabled -Enabled $true
				if (Get-Command -Name 'Sync-UxActionButtonText' -CommandType Function -ErrorAction SilentlyContinue)
				{
					Sync-UxActionButtonText
				}
				else
				{
					$BtnRun.Content = Get-UxRunActionLabel
				}

				$completedCount = [int]$Script:RunState['CompletedCount']
				$abortedRun = $Script:RunState['AbortedRun']
				$fatalError = if ([string]::IsNullOrWhiteSpace($Script:RunState['FatalError'])) { $null } else { [string]$Script:RunState['FatalError'] }
				$logPath = $Global:LogFilePath
				LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionRunDone' -Fallback '[Timer] Run done. mode={0}, aborted={1}, disposition={2}, completed={3}' -FormatArgs @($Script:ExecutionMode, $abortedRun, $Script:RunAbortDisposition, $completedCount))
				Complete-ExecutionSummary -AbortedRun:$abortedRun -FatalError $fatalError
				$executionSummary = @(Get-ExecutionSummaryResults)
				try
				{
					Set-LogMode -Mode $(if (Get-ExecutionGameModeContext) { 'Game' } else { $null })
					Write-ExecutionSummaryToLog -Results $executionSummary -AbortedRun:$abortedRun -FatalError $fatalError

					# Update session statistics from execution results
					$guiSummaryPayload = GUIExecution\Get-GuiExecutionSummaryPayload -Results $executionSummary
					Add-SessionStatistic -Name 'SucceededCount' -Increment $guiSummaryPayload.SuccessCount
					Add-SessionStatistic -Name 'SucceededCount' -Increment $guiSummaryPayload.RestartPendingCount
					Add-SessionStatistic -Name 'FailedCount' -Increment $guiSummaryPayload.FailedCount
					Add-SessionStatistic -Name 'SkippedCount' -Increment ($guiSummaryPayload.SkippedCount + $guiSummaryPayload.NotApplicableCount + $guiSummaryPayload.NotRunCount)

					# Write audit trail record for this execution run
					try
					{
						$auditAction = if ($Script:ExecutionMode -eq 'Defaults') { 'DefaultsRestored' } else { 'RunCompleted' }
						$auditDuration = if ($Script:RunState['StartedAt']) { (Get-Date) - [datetime]$Script:RunState['StartedAt'] } else { $null }
						$auditParams = @{
							Action  = $auditAction
							Mode    = $Script:ExecutionMode
							Results = $guiSummaryPayload
						}
						if ($null -ne $auditDuration) { $auditParams['Duration'] = $auditDuration }
						Write-AuditRecord @auditParams
					}
					catch
					{
						LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionWriteAuditRecordFailed' -Fallback '[Timer] Write-AuditRecord failed'))
					}

					# Match the headless contract: pin
					# $Global:LASTEXITCODE through the documented exit
					# surface (0=clean, 1=partial/all-failed). An aborted run with
					# any successes is treated as partial, never silently 0. The
					# whole pin is wrapped because a missing helper or counter
					# must NEVER break the GUI completion path.
					try
					{
						$exitCodeFn = Get-Command -Name 'Get-BaselineHeadlessExitCode' -CommandType Function -ErrorAction SilentlyContinue
						if ($exitCodeFn)
						{
							$guiSucceeded = [int]$guiSummaryPayload.SuccessCount + [int]$guiSummaryPayload.RestartPendingCount
							$guiFailed = [int]$guiSummaryPayload.FailedCount
							$guiTotal = [int]$completedCount
							if ($abortedRun -and $guiFailed -eq 0 -and $guiSucceeded -lt $guiTotal)
							{
								# Treat the unstarted remainder as "failed to apply" so
								# the exit code surfaces a partial / all-failed Reason
								# rather than masquerading as clean.
								$guiFailed = $guiTotal - $guiSucceeded
							}
							$guiExit = & $exitCodeFn -Total $guiTotal -Succeeded $guiSucceeded -Failed $guiFailed
							$Global:LASTEXITCODE = [int]$guiExit.ExitCode
							if (Get-Command -Name 'Write-LaunchTrace' -CommandType Function -ErrorAction SilentlyContinue)
							{
								Write-LaunchTrace ('GUI run finished: exitCode={0} reason={1} total={2} succeeded={3} failed={4} aborted={5}' -f [int]$guiExit.ExitCode, [string]$guiExit.Reason, $guiTotal, $guiSucceeded, $guiFailed, [bool]$abortedRun)
							}
						}
					}
					catch
					{
						Write-DebugSwallowedException -ErrorRecord $_ -Source 'ExecutionOrchestration.RunCompletion.ExitCode'
					}

					Complete-GuiExecutionRun -Mode $Script:ExecutionMode `
						-CompletedCount $completedCount `
						-AbortedRun:$abortedRun `
						-FatalError $fatalError `
						-ExecutionSummary $executionSummary `
						-LogPath $logPath
				}
				catch
				{
					LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionCompleteFailed' -Fallback '[Timer] Complete-GuiExecutionRun FAILED'))
					LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionCompleteFailedDetail' -Fallback 'Complete-GuiExecutionRun failed'))
					# Ensure the GUI is restored even if the completion handler fails
					try { Exit-ExecutionView } catch { $null = $_ }
				}
				finally
				{
					Clear-LogMode
				}
			}
			catch
			{
				if (-not $Script:ExecutionTimerErrorShown)
				{
					$Script:ExecutionTimerErrorShown = $true
					LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionOuterCatch' -Fallback '[Timer] OUTER CATCH'))
					LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionUpdateFailedDetail' -Fallback 'Execution UI update failed'))
				}
				if ($Script:ExecutionRunTimer)
				{
					try { $Script:ExecutionRunTimer.Stop() } catch { $null = $_ }
					try { $Script:ExecutionRunTimer.Dispose() } catch { $null = $_ }
					$Script:ExecutionRunTimer = $null
				}
				try { Exit-ExecutionView } catch { $null = $_ }
				# winutil #4376 / PR #4404: every early exit out of the apply
				# pipeline must clear the busy flag and re-enable the controls
				# so a thrown pump-tick body doesn't leave the GUI permanently
				# spinning ("Applying tweaks" with hourglass cursor). The
				# success path above already does this; this catch did not.
				try { if ($Script:GuiState) { & $Script:GuiState.Set 'RunInProgress' $false } else { $Script:RunInProgress = $false } } catch { $null = $_ }
				try { if ((Test-GuiObjectField -Object $PrimaryTabs -FieldName 'IsEnabled')) { $PrimaryTabs.IsEnabled = $true } } catch { $null = $_ }
				try { if ((Test-GuiObjectField -Object $BtnRun -FieldName 'IsEnabled')) { $BtnRun.IsEnabled = $true } } catch { $null = $_ }
				try { if ($BtnPreviewRun) { $BtnPreviewRun.IsEnabled = $true } } catch { $null = $_ }
				try { if ((Test-GuiObjectField -Object $BtnDefaults -FieldName 'IsEnabled')) { $BtnDefaults.IsEnabled = $true } } catch { $null = $_ }
				try { Set-GuiActionButtonsEnabled -Enabled $true } catch { $null = $_ }
				try { if ((Test-GuiObjectField -Object $ChkScan -FieldName 'IsEnabled')) { $ChkScan.IsEnabled = $true } } catch { $null = $_ }
				try { if ((Test-GuiObjectField -Object $ChkTheme -FieldName 'IsEnabled')) { $ChkTheme.IsEnabled = $true } } catch { $null = $_ }
				try { Set-SearchControlsEnabled -Enabled $true } catch { $null = $_ }
				$null = & $Script:ShowGuiRuntimeFailureScript -Context 'ExecutionTimer' -Exception $_.Exception -ShowDialog
			}
		}
		$executionPumpTickFn = $Script:ExecutionPumpTickFn

		# winutil #4376 / PR #4404: a synchronous throw between RunInProgress=$true
		# (above) and the first pump-tick would also leave the GUI stuck. Wrap the
		# timer setup + initial tick so the cleanup contract above runs even if
		# DispatcherTimer construction or the first invocation fails before the
		# pump-tick body's own catch can fire.
		try
		{
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
			LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionTimerStartFailed' -Fallback '[Timer] Failed to start execution pump'))
			if ($Script:ExecutionRunTimer)
			{
				try { $Script:ExecutionRunTimer.Stop() } catch { $null = $_ }
				try { $Script:ExecutionRunTimer.Dispose() } catch { $null = $_ }
				$Script:ExecutionRunTimer = $null
			}
			try { Exit-ExecutionView } catch { $null = $_ }
			try { if ($Script:GuiState) { & $Script:GuiState.Set 'RunInProgress' $false } else { $Script:RunInProgress = $false } } catch { $null = $_ }
			try { if ((Test-GuiObjectField -Object $PrimaryTabs -FieldName 'IsEnabled')) { $PrimaryTabs.IsEnabled = $true } } catch { $null = $_ }
			try { if ((Test-GuiObjectField -Object $BtnRun -FieldName 'IsEnabled')) { $BtnRun.IsEnabled = $true } } catch { $null = $_ }
			try { if ($BtnPreviewRun) { $BtnPreviewRun.IsEnabled = $true } } catch { $null = $_ }
			try { if ((Test-GuiObjectField -Object $BtnDefaults -FieldName 'IsEnabled')) { $BtnDefaults.IsEnabled = $true } } catch { $null = $_ }
			try { Set-GuiActionButtonsEnabled -Enabled $true } catch { $null = $_ }
			try { if ((Test-GuiObjectField -Object $ChkScan -FieldName 'IsEnabled')) { $ChkScan.IsEnabled = $true } } catch { $null = $_ }
			try { if ((Test-GuiObjectField -Object $ChkTheme -FieldName 'IsEnabled')) { $ChkTheme.IsEnabled = $true } } catch { $null = $_ }
			try { Set-SearchControlsEnabled -Enabled $true } catch { $null = $_ }
			throw
		}
	}

