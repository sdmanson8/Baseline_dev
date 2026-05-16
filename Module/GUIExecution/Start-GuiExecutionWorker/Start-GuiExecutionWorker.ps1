$worker = [powershell]::Create().AddScript({
		try
		{
			$Global:GUIMode = $true
			if ([string]::IsNullOrWhiteSpace([string]$bgOperationMode))
			{
				$bgOperationMode = 'ReadWrite'
			}
			$Global:BaselineOperationMode = [string]$bgOperationMode
			[System.Environment]::SetEnvironmentVariable('BASELINE_OPERATION_MODE', [string]$bgOperationMode, [System.EnvironmentVariableTarget]::Process)
			$Script:RunState = $runState

			# Load JSON and localization helpers in the background runspace before importing the execution module.
			$bgModuleRoot = Split-Path $bgLoaderPath -Parent
			$bgJsonHelperPath = Join-Path $bgModuleRoot 'SharedHelpers\Json.Helpers.ps1'
			$bgHelperPath = Join-Path $bgModuleRoot 'SharedHelpers\Localization.Helpers.ps1'
			. $bgJsonHelperPath
			. $bgHelperPath
			$Global:Localization = Import-BaselineLocalization -BaseDirectory $bgLocDir -UICulture $bgUICulture
			[void](Set-BaselineThreadCulture -UICulture $bgUICulture)

			# Module import must be side-effect-free (no Write-Host, no state mutation)
			# because this runs in a fresh background runspace.
			try
			{
				$Global:LogFilePath = $bgLogFilePath
				Import-Module $bgLoaderPath -Force -Global -ErrorAction Stop
				if (Get-Command -Name Set-BaselineOperationMode -ErrorAction SilentlyContinue)
				{
					Set-BaselineOperationMode -Mode ([string]$bgOperationMode)
				}
			}
			catch
			{
				$importError = $_.Exception.Message
				$Script:RunState['LogQueue'].Enqueue([PSCustomObject]@{
					Kind = 'LogWarning'
					Message = "Background module import failed: $importError"
				})
				throw
			}

			$global:LogFilePath = $bgLogFilePath
			Set-LogFile -Path $bgLogFilePath
			Set-LogMode -Mode $bgLogMode
			Set-UILogHandler { param($entry) $Script:RunState['LogQueue'].Enqueue($entry) }

			$missingFunctions = @(
				$tweakList |
					ForEach-Object { $_.Function } |
					Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
					Select-Object -Unique |
					Where-Object { -not (Get-Command -Name $_ -ErrorAction SilentlyContinue) }
			)
			if ($missingFunctions.Count -gt 0)
			{
				$loadedModules = @(Get-Module | Select-Object -ExpandProperty Name) -join ', '
				throw ("Required tweak functions were not loaded: {0}`nLoaded modules: {1}" -f ($missingFunctions -join ', '), $loadedModules)
			}

			$actionHost = New-GuiExecutionActionHost `
				-LoaderPath $bgLoaderPath `
				-LocalizationDirectory $bgLocDir `
				-UICulture $bgUICulture `
				-LogFilePath $bgLogFilePath `
				-LogMode $bgLogMode `
				-OperationMode $bgOperationMode `
				-LogQueue $Script:RunState['LogQueue']

			$stepIndex = 0
			$stepTotal = $tweakList.Count
			foreach ($tweak in $tweakList)
			{
				while ($Script:RunState['Paused'] -and -not $Script:RunState['AbortRequested'])
				{
					Start-Sleep -Milliseconds 250
				}

				if ($Script:RunState['AbortRequested'])
				{
					$Script:RunState['AbortedRun'] = $true
					break
				}

				$stepIndex++
				$Global:CurrentTweakName = $tweak.Name
				$Script:RunState['CurrentTweak'] = $tweak.Name
				$Script:RunState['LogQueue'].Enqueue([PSCustomObject]@{
					Kind = '_TweakStarted'
					Key = $tweak.Key
					Name = $tweak.Name
					StepIndex = $stepIndex
					StepTotal = $stepTotal
				})

				$tweakErrorBaseline = if ($Global:Error) { $Global:Error.Count } else { 0 }
				$tweakErrorMessage = $null
				$tweakFailed = $false

				$availabilityGate = Resolve-GuiExecutionAvailabilityGate -Entry $tweak -ForceUnsupported:$bgForceUnsupported
				if ($availabilityGate.Decision -eq 'Block')
				{
					$skipDetail = if ([string]::IsNullOrWhiteSpace($availabilityGate.Reason)) { 'Not available on this system.' } else { $availabilityGate.Reason }
					LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionSkippedNotApplicable' -Fallback 'Skipped - not available on this system: {0} - {1}' -FormatArgs @([string]$tweak.Function, $skipDetail))
					$Script:RunState['SkippedTweaks'][[string]$tweak.Key] = $skipDetail
					$completedCount = Update-GuiRunStateCounter -RunState $Script:RunState -Key 'CompletedCount'
					$Script:RunState['LogQueue'].Enqueue([PSCustomObject]@{
						Kind = '_TweakCompleted'
						Key = $tweak.Key
						Name = $tweak.Name
						Status = 'skipped'
						Message = $skipDetail
						Count = $completedCount
						StepIndex = $stepIndex
						StepTotal = $stepTotal
					})
					continue
				}
				if ($availabilityGate.Decision -eq 'Force')
				{
					LogWarning (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionForceUnsupportedAvailability' -Fallback 'Forcing execution of unavailable entry: {0} - {1}' -FormatArgs @([string]$tweak.Function, $availabilityGate.Reason))
				}

				$supportsExecutionGate = Resolve-GuiExecutionSupportsExecutionGate -Entry $tweak -ForceUnsupported:$bgForceUnsupported
				if ($supportsExecutionGate.Decision -eq 'Block')
				{
					$skipDetail = if ([string]::IsNullOrWhiteSpace($supportsExecutionGate.Reason)) { 'Execution not supported on this system.' } else { $supportsExecutionGate.Reason }
					LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionSkippedNotExecutable' -Fallback 'Skipped - execution not supported on this system: {0}' -FormatArgs @([string]$tweak.Function))
					$Script:RunState['SkippedTweaks'][[string]$tweak.Key] = $skipDetail
					$null = Update-GuiRunStateCounter -RunState $Script:RunState -Key 'NotExecutableCount'
					$completedCount = Update-GuiRunStateCounter -RunState $Script:RunState -Key 'CompletedCount'
					$Script:RunState['LogQueue'].Enqueue([PSCustomObject]@{
						Kind = '_TweakCompleted'
						Key = $tweak.Key
						Name = $tweak.Name
						Status = 'skipped'
						Message = $skipDetail
						Count = $completedCount
						StepIndex = $stepIndex
						StepTotal = $stepTotal
					})
					continue
				}
				if ($supportsExecutionGate.Decision -eq 'Force')
				{
					LogWarning (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionForceUnsupportedExecution' -Fallback 'Forcing execution of non-executable entry: {0} - {1}' -FormatArgs @([string]$tweak.Function, $supportsExecutionGate.Reason))
				}

				try
				{
					$commandArguments = @{}

					switch ($tweak.Type)
					{
						'Toggle'
						{
							$toggleParam = if (-not [string]::IsNullOrWhiteSpace([string]$tweak.ToggleParam)) { [string]$tweak.ToggleParam } else { [string]$tweak.OnParam }
							if ([string]::IsNullOrWhiteSpace($toggleParam))
							{
								throw "The toggle selection for '$($tweak.Function)' did not include a parameter to execute."
							}
							$commandArguments = @{ $toggleParam = $true }
						}
						'Date'
						{
							$enableParam = if (-not [string]::IsNullOrWhiteSpace([string]$tweak.OnParam)) { [string]$tweak.OnParam } else { 'Enable' }
							$disableParam = if (-not [string]::IsNullOrWhiteSpace([string]$tweak.OffParam)) { [string]$tweak.OffParam } else { 'Disable' }
							if ($tweak.Run)
							{
								$dateParamName = if (-not [string]::IsNullOrWhiteSpace([string]$tweak.DateParam)) { [string]$tweak.DateParam } else { 'StartDate' }
								$dateValue = if ((Test-GuiObjectField -Object $tweak -FieldName 'DateValue') -and -not [string]::IsNullOrWhiteSpace([string]$tweak.DateValue))
								{
									[string]$tweak.DateValue
								}
								elseif ((Test-GuiObjectField -Object $tweak -FieldName 'Value') -and -not [string]::IsNullOrWhiteSpace([string]$tweak.Value))
								{
									[string]$tweak.Value
								}
								else
								{
									$null
								}

								if ([string]::IsNullOrWhiteSpace($dateValue))
								{
									throw "The date selection for '$($tweak.Function)' did not include a date to execute."
								}

								$commandArguments = @{}
								$commandArguments[$enableParam] = $true
								$commandArguments[$dateParamName] = $dateValue
								if ($tweak.ExtraArgs)
								{
									$tweak.ExtraArgs.GetEnumerator() | ForEach-Object { $commandArguments[[string]$_.Key] = $_.Value }
								}
							}
							else
							{
								$commandArguments = @{}
								$commandArguments[$disableParam] = $true
								if ($tweak.ExtraArgs)
								{
									$tweak.ExtraArgs.GetEnumerator() | ForEach-Object { $commandArguments[[string]$_.Key] = $_.Value }
								}
							}
						}
						'Choice'
						{
							$choiceParam = [string]$tweak.Value
							if ([string]::IsNullOrWhiteSpace($choiceParam))
							{
								throw "The choice selection for '$($tweak.Function)' did not include a parameter to execute."
							}
							$choiceOptions = @()
							if (Test-GuiObjectField -Object $tweak -FieldName 'Options')
							{
								$choiceOptions = @($tweak.Options | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
							}
							if ($choiceOptions.Count -gt 0 -and $choiceParam -notin $choiceOptions)
							{
								throw "The choice selection for '$($tweak.Function)' is invalid: '$choiceParam'. Expected one of: $($choiceOptions -join ', ')."
							}
							$commandArguments = @{ $choiceParam = $true }
							if ($tweak.ExtraArgs)
							{
								$tweak.ExtraArgs.GetEnumerator() | ForEach-Object { $commandArguments[[string]$_.Key] = $_.Value }
							}
						}
						'Action'
						{
							if ($tweak.ExtraArgs)
							{
								$commandArguments = @{}
								$tweak.ExtraArgs.GetEnumerator() | ForEach-Object { $commandArguments[[string]$_.Key] = $_.Value }
							}
						}
						default
						{
							$commandArguments = @{}
						}
					}

					$timeoutSeconds = Get-GuiExecutionActionTimeoutSeconds -Entry $tweak -ExecutionClass 'Tweak'
					$timedInvocation = Invoke-GuiExecutionActionHostCommand `
						-ActionHost $actionHost `
						-CommandName ([string]$tweak.Function) `
						-CommandArguments $commandArguments `
						-TimeoutSeconds $timeoutSeconds `
						-RunState $Script:RunState

					if ($timedInvocation.HostRequiresReset)
					{
						Close-GuiExecutionActionHost -ActionHost $actionHost
						$actionHost = New-GuiExecutionActionHost `
							-LoaderPath $bgLoaderPath `
							-LocalizationDirectory $bgLocDir `
							-UICulture $bgUICulture `
							-LogFilePath $bgLogFilePath `
							-LogMode $bgLogMode `
							-OperationMode $bgOperationMode `
							-LogQueue $Script:RunState['LogQueue']
					}

					if ($timedInvocation.Aborted)
					{
						$Script:RunState['AbortedRun'] = $true
						break
					}

					if ($timedInvocation.TimedOut)
					{
						$isCriticalAction = Test-GuiExecutionCriticalAction -Entry $tweak
						$tweakFailed = $true
						$tweakErrorMessage = if ($isCriticalAction)
						{
							"Timed out after $timeoutSeconds second(s). This action is marked critical, so the run will abort."
						}
						else
						{
							"Timed out after $timeoutSeconds second(s), continuing to the next item."
						}

						Write-GuiExecutionTimeoutRecord `
							-ActionId ([string]$tweak.Key) `
							-ActionName ([string]$tweak.Name) `
							-ActionType 'Tweak' `
							-TimeoutSeconds $timeoutSeconds `
							-StartedAt $timedInvocation.StartedAt `
							-EndedAt $timedInvocation.EndedAt `
							-CommandName ([string]$tweak.Function) `
							-Continued:(-not $isCriticalAction) `
							-Aborted:$isCriticalAction `
							-Result 'Timed Out' `
							-Message $tweakErrorMessage

						if ($isCriticalAction)
						{
							$Script:RunState['AbortedRun'] = $true
						}
					}
					elseif (-not $timedInvocation.Succeeded)
					{
						$tweakFailed = $true
						$tweakErrorMessage = $timedInvocation.ErrorMessage
					}
				}
				catch
				{
					$tweakFailed = $true
					$tweakErrorMessage = $_.Exception.Message
				}

				if ($Script:RunState['AbortedRun'] -and $tweakFailed -and $tweakErrorMessage -match 'Timed out after')
				{
					$Script:RunState['LogQueue'].Enqueue([PSCustomObject]@{
						Kind = '_RunNotice'
						Level = 'WARNING'
						Message = $tweakErrorMessage
					})
				}

				if (-not $tweakFailed)
				{
					$newErrors = @(Get-NewUnhandledErrorRecords -BaselineCount $tweakErrorBaseline)
					if ($newErrors.Count -gt 0)
					{
						$tweakFailed = $true
						$tweakErrorMessage = $newErrors[0].Exception.Message
					}
				}

				$Global:CurrentTweakName = $null

				if (-not $tweakFailed)
				{
					$Script:RunState['AppliedFunctions'].Add($tweak.Function)
					$completedCount = Update-GuiRunStateCounter -RunState $Script:RunState -Key 'CompletedCount'
					$Script:RunState['LogQueue'].Enqueue([PSCustomObject]@{
						Kind = '_TweakCompleted'
						Key = $tweak.Key
						Name = $tweak.Name
						Status = 'success'
						Count = $completedCount
						StepIndex = $stepIndex
						StepTotal = $stepTotal
					})
				}
				else
				{
					$Script:RunState['LogQueue'].Enqueue([PSCustomObject]@{
						Kind = '_TweakFailed'
						Key = $tweak.Key
						Name = $tweak.Name
						Error = $tweakErrorMessage
						StepIndex = $stepIndex
						StepTotal = $stepTotal
					})
					$null = Update-GuiRunStateCounter -RunState $Script:RunState -Key 'ErrorCount'
					$completedCount = Update-GuiRunStateCounter -RunState $Script:RunState -Key 'CompletedCount'
					$Script:RunState['LogQueue'].Enqueue([PSCustomObject]@{
						Kind = '_TweakCompleted'
						Key = $tweak.Key
						Name = $tweak.Name
						Status = $(if ($tweakErrorMessage -match '^Timed out after ') { 'Timed Out' } else { 'failed' })
						Message = $tweakErrorMessage
						Count = $completedCount
						StepIndex = $stepIndex
						StepTotal = $stepTotal
					})

					if ($Script:RunState['AbortedRun'] -and $tweakErrorMessage -match '^Timed out after ')
					{
						break
					}
				}
			}

			if (-not $Script:RunState['AbortedRun'])
			{
				PostActions
				Errors
			}
			else
			{
				LogWarning (Get-BaselineBilingualString -Key 'GuiLogExecutionAbortedByUser' -Fallback '{0} execution aborted by user before all selected tweaks finished.' -FormatArgs @($executionMode))
			}

			Stop-Foreground
		}
		catch
		{
			$fatalMessage = if ([string]::IsNullOrWhiteSpace([string]$_.Exception.Message)) { 'Unexpected fatal run error.' } else { [string]$_.Exception.Message }
			$diagnosticLines = [System.Collections.Generic.List[string]]::new()
			if ($Script:RunState -and -not [string]::IsNullOrWhiteSpace([string]$Script:RunState['CurrentTweak']))
			{
				[void]$diagnosticLines.Add(("Current tweak: {0}" -f [string]$Script:RunState['CurrentTweak']))
			}
			if ($_.Exception)
			{
				[void]$diagnosticLines.Add(("Exception type: {0}" -f $_.Exception.GetType().FullName))
			}
			if ($_.InvocationInfo -and -not [string]::IsNullOrWhiteSpace([string]$_.InvocationInfo.PositionMessage))
			{
				[void]$diagnosticLines.Add('Invocation:')
				[void]$diagnosticLines.Add([string]$_.InvocationInfo.PositionMessage.Trim())
			}
			if (-not [string]::IsNullOrWhiteSpace([string]$_.ScriptStackTrace))
			{
				[void]$diagnosticLines.Add('Script stack trace:')
				[void]$diagnosticLines.Add([string]$_.ScriptStackTrace.Trim())
			}

			$Script:RunState['LogQueue'].Enqueue([PSCustomObject]@{
				Kind = '_RunError'
				Error = $fatalMessage
				Diagnostic = ($diagnosticLines -join "`n")
			})
		}
		finally
		{
			if ($actionHost)
			{
				Close-GuiExecutionActionHost -ActionHost $actionHost
			}
			Clear-LogMode
			$Script:RunState['Done'] = $true
		}
	})
