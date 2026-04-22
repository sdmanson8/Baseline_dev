using module .\Logging.psm1
using module .\SharedHelpers.psm1

<#
    .SYNOPSIS
    Internal GUI execution helper module for Baseline.

    .DESCRIPTION
    Provides cleanup and run-state helpers used by the GUI execution flow.
    This is internal runtime plumbing, not user-facing documentation.
#>

function Write-GuiExecutionCleanupWarning
{
	param ([string]$Message)

		if ([string]::IsNullOrWhiteSpace($Message))
		{
			return
		}

	LogWarning $Message
}

<#
    .SYNOPSIS
    Internal function .
#>
function Update-GuiRunStateCounter
{
	param (
		[hashtable]$RunState,
		[string]$Key,
		[int]$Delta = 1
	)

	[System.Threading.Monitor]::Enter($RunState.SyncRoot)
	try
	{
		$RunState[$Key] = [int]$RunState[$Key] + $Delta
		return [int]$RunState[$Key]
	}
	finally
	{
		[System.Threading.Monitor]::Exit($RunState.SyncRoot)
	}
}

<#
    .SYNOPSIS
    Internal function Get-GuiExecutionOutcome.
#>

function Get-GuiExecutionOutcome
{
	param (
		[string]$Status,
		[string]$Detail,
		[bool]$RequiresRestart = $false
	)

	$statusText = if ([string]::IsNullOrWhiteSpace($Status)) { 'Pending' } else { $Status.Trim() }

	switch -Regex ($statusText)
	{
		'^(Failed)$' { return 'Failed' }
		'^(Not Run)$' { return 'Not Run' }
		'^(Not applicable)$' { return 'Not applicable' }
		'^(Restart pending)$' { return 'Restart pending' }
		'^(Skipped)$'
		{
			if (-not [string]::IsNullOrWhiteSpace($Detail) -and $Detail -match '(?i)\b(not applicable|not supported|unsupported|unsupported build|windows server)\b')
			{
				return 'Not applicable'
			}
			return 'Skipped'
		}
		'^(Success)$'
		{
			if ($RequiresRestart)
			{
				return 'Restart pending'
			}
			return 'Success'
		}
		default
		{
			return $statusText
		}
	}
}

<#
    .SYNOPSIS
    Internal function Test-GuiExecutionAppliedOutcome.
#>

function Test-GuiExecutionAppliedOutcome
{
	param (
		[string]$Outcome
	)

	return ($Outcome -in @('Success', 'Restart pending'))
}

<#
    .SYNOPSIS
    Internal function .
#>
function New-GuiExecutionAppliedTweakMetadata
{
	param (
		[object]$Result,
		[string]$Outcome
	)

	if (-not $Result)
	{
		return $null
	}

	$resolvedOutcome = if ([string]::IsNullOrWhiteSpace($Outcome))
	{
		Get-GuiExecutionOutcome -Status ([string]$Result.Status) -Detail ([string]$Result.Detail) -RequiresRestart $(if ((Test-GuiObjectField -Object $Result -FieldName 'RequiresRestart')) { [bool]$Result.RequiresRestart } else { $false })
	}
	else
	{
		[string]$Outcome
	}

	return [pscustomobject]@{
		Key                 = [string]$Result.Key
		Order               = if ((Test-GuiObjectField -Object $Result -FieldName 'Order')) { [int]$Result.Order } else { 0 }
		Name                = [string]$Result.Name
		Function            = [string]$Result.Function
		Category            = [string]$Result.Category
		Type                = if ((Test-GuiObjectField -Object $Result -FieldName 'Type')) { [string]$Result.Type } else { $null }
		TypeLabel           = if ((Test-GuiObjectField -Object $Result -FieldName 'TypeLabel')) { [string]$Result.TypeLabel } else { $null }
		Selection           = if ((Test-GuiObjectField -Object $Result -FieldName 'Selection')) { [string]$Result.Selection } else { $null }
		ToggleParam         = if ((Test-GuiObjectField -Object $Result -FieldName 'ToggleParam')) { [string]$Result.ToggleParam } else { $null }
		RequiresRestart     = if ((Test-GuiObjectField -Object $Result -FieldName 'RequiresRestart')) { [bool]$Result.RequiresRestart } else { $false }
		Restorable          = if ((Test-GuiObjectField -Object $Result -FieldName 'Restorable')) { $Result.Restorable } else { $null }
		RecoveryLevel       = if ((Test-GuiObjectField -Object $Result -FieldName 'RecoveryLevel')) { [string]$Result.RecoveryLevel } else { $null }
		TroubleshootingOnly = if ((Test-GuiObjectField -Object $Result -FieldName 'TroubleshootingOnly')) { [bool]$Result.TroubleshootingOnly } else { $false }
		FromGameMode        = if ((Test-GuiObjectField -Object $Result -FieldName 'FromGameMode')) { [bool]$Result.FromGameMode } else { $false }
		GameModeProfile     = if ((Test-GuiObjectField -Object $Result -FieldName 'GameModeProfile')) { [string]$Result.GameModeProfile } else { $null }
		GameModeOperation   = if ((Test-GuiObjectField -Object $Result -FieldName 'GameModeOperation')) { [string]$Result.GameModeOperation } else { $null }
		Outcome             = $resolvedOutcome
		Detail              = if ((Test-GuiObjectField -Object $Result -FieldName 'Detail')) { [string]$Result.Detail } else { $null }
	}
}

<#
    .SYNOPSIS
    Internal function Get-GuiExecutionSummaryPayload.
#>

function Get-GuiExecutionSummaryPayload
{
	param (
		[object[]]$Results
	)

	$results = @($Results | Where-Object { $_ })
	$decorated = @(
		foreach ($result in $results)
		{
			$outcome = Get-GuiExecutionOutcome -Status ([string]$result.Status) -Detail ([string]$result.Detail) -RequiresRestart $(if ((Test-GuiObjectField -Object $result -FieldName 'RequiresRestart')) { [bool]$result.RequiresRestart } else { $false })
			[pscustomobject]@{
				Result = $result
				Outcome = $outcome
			}
		}
	)

	$successResults = @($decorated | Where-Object Outcome -eq 'Success' | ForEach-Object { $_.Result })
	$restartPendingResults = @($decorated | Where-Object Outcome -eq 'Restart pending' | ForEach-Object { $_.Result })
	$failedResults = @($decorated | Where-Object Outcome -eq 'Failed' | ForEach-Object { $_.Result })
	$skippedResults = @($decorated | Where-Object Outcome -eq 'Skipped' | ForEach-Object { $_.Result })
	$notApplicableResults = @($decorated | Where-Object Outcome -eq 'Not applicable' | ForEach-Object { $_.Result })
	$notRunResults = @($decorated | Where-Object Outcome -eq 'Not Run' | ForEach-Object { $_.Result })
	$appliedResults = @($decorated | Where-Object { Test-GuiExecutionAppliedOutcome -Outcome $_.Outcome } | ForEach-Object { $_.Result })

	return [pscustomobject]@{
		TotalCount = $results.Count
		SuccessCount = $successResults.Count
		RestartPendingCount = $restartPendingResults.Count
		AppliedCount = $appliedResults.Count
		FailedCount = $failedResults.Count
		SkippedCount = $skippedResults.Count
		NotApplicableCount = $notApplicableResults.Count
		NotRunCount = $notRunResults.Count
		DirectUndoEligibleCount = @(
			$appliedResults |
				Where-Object {
					(Test-GuiObjectField -Object $_ -FieldName 'Restorable') -and
					$null -ne $_.Restorable -and
					[bool]$_.Restorable -and
					(Test-GuiObjectField -Object $_ -FieldName 'RecoveryLevel') -and
					[string]$_.RecoveryLevel -eq 'Direct'
				}
		).Count
		Results = $results
		AppliedResults = $appliedResults
		RestartPendingResults = $restartPendingResults
		RestartPendingNames = @($restartPendingResults | ForEach-Object { [string]$_.Name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
		OutcomeCounts = [ordered]@{
			Success = $successResults.Count
			RestartPending = $restartPendingResults.Count
			Failed = $failedResults.Count
			Skipped = $skippedResults.Count
			NotApplicable = $notApplicableResults.Count
			NotRun = $notRunResults.Count
		}
	}
}

<#
    .SYNOPSIS
    Internal function Start-GuiExecutionWorker.
#>

function Start-GuiExecutionWorker
{
	param (
		[Parameter(Mandatory = $true)]
		[hashtable]$RunState,

		[Parameter(Mandatory = $true)]
		[object[]]$TweakList,

		[Parameter(Mandatory = $true)]
		[ValidateSet('Run', 'Defaults')]
		[string]$Mode,

		[Parameter(Mandatory = $true)]
		[string]$LoaderPath,

		[Parameter(Mandatory = $true)]
		[string]$LocalizationDirectory,

		[Parameter(Mandatory = $true)]
		[string]$UICulture,

		[Parameter(Mandatory = $true)]
		[string]$LogFilePath,
		[string]$LogMode
	)

	$bgRunspace = [runspacefactory]::CreateRunspace()
	$bgRunspace.ApartmentState = 'STA'
	$bgRunspace.ThreadOptions = 'ReuseThread'
	$bgRunspace.Open()
	$bgRunspace.SessionStateProxy.SetVariable('runState', $RunState)
	$bgRunspace.SessionStateProxy.SetVariable('tweakList', @($TweakList))
	$bgRunspace.SessionStateProxy.SetVariable('executionMode', $Mode)
	$bgRunspace.SessionStateProxy.SetVariable('bgLoaderPath', $LoaderPath)
	$bgRunspace.SessionStateProxy.SetVariable('bgLocDir', $LocalizationDirectory)
	$bgRunspace.SessionStateProxy.SetVariable('bgUICulture', $UICulture)
	$bgRunspace.SessionStateProxy.SetVariable('bgLogFilePath', $LogFilePath)
	$bgRunspace.SessionStateProxy.SetVariable('bgLogMode', $LogMode)
	$bgRunspace.SessionStateProxy.SetVariable('GUIRunState', $RunState['LogQueue'])

	$worker = [powershell]::Create().AddScript({
		try
		{
			$Global:GUIMode = $true
			$Script:RunState = $runState

			# Load JSON localization helper and localized strings in the background runspace.
			$bgHelperPath = Join-Path (Split-Path $bgLoaderPath -Parent) 'SharedHelpers\Localization.Helpers.ps1'
			. $bgHelperPath
			$Global:Localization = Import-BaselineLocalization -BaseDirectory $bgLocDir -UICulture $bgUICulture
			[void](Set-BaselineThreadCulture -UICulture $bgUICulture)

			# Module import must be side-effect-free (no Write-Host, no state mutation)
			# because this runs in a fresh background runspace.
			try
			{
				Import-Module $bgLoaderPath -Force -Global -ErrorAction Stop
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

				try
				{
					$tweakCommand = Get-Command -Name $tweak.Function -ErrorAction SilentlyContinue
					if (-not $tweakCommand)
					{
						throw "The tweak function '$($tweak.Function)' is not available in the current session."
					}

					switch ($tweak.Type)
					{
						'Toggle'
						{
							$toggleParam = if (-not [string]::IsNullOrWhiteSpace([string]$tweak.ToggleParam)) { [string]$tweak.ToggleParam } else { [string]$tweak.OnParam }
							if ([string]::IsNullOrWhiteSpace($toggleParam))
							{
								throw "The toggle selection for '$($tweak.Function)' did not include a parameter to execute."
							}
							$splat = @{ $toggleParam = $true }
							& $tweakCommand @splat
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

								$splat = @{}
								$splat[$enableParam] = $true
								$splat[$dateParamName] = $dateValue
								if ($tweak.ExtraArgs)
								{
									$tweak.ExtraArgs.GetEnumerator() | ForEach-Object { $splat[[string]$_.Key] = $_.Value }
								}
								& $tweakCommand @splat
							}
							else
							{
								$splat = @{}
								$splat[$disableParam] = $true
								if ($tweak.ExtraArgs)
								{
									$tweak.ExtraArgs.GetEnumerator() | ForEach-Object { $splat[[string]$_.Key] = $_.Value }
								}
								& $tweakCommand @splat
							}
						}
						'Choice'
						{
							$choiceParam = [string]$tweak.Value
							if ([string]::IsNullOrWhiteSpace($choiceParam))
							{
								throw "The choice selection for '$($tweak.Function)' did not include a parameter to execute."
							}
							$splat = @{ $choiceParam = $true }
							if ($tweak.ExtraArgs)
							{
								$tweak.ExtraArgs.GetEnumerator() | ForEach-Object { $splat[[string]$_.Key] = $_.Value }
							}
							& $tweakCommand @splat
						}
						'Action'
						{
							if ($tweak.ExtraArgs)
							{
								$argSplat = $tweak.ExtraArgs
								& $tweakCommand @argSplat
							}
							else
							{
								& $tweakCommand
							}
						}
					}
				}
				catch
				{
					$tweakFailed = $true
					$tweakErrorMessage = $_.Exception.Message
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
						Status = 'failed'
						Count = $completedCount
						StepIndex = $stepIndex
						StepTotal = $stepTotal
					})
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
			Clear-LogMode
			$Script:RunState['Done'] = $true
		}
	})

	$worker.Runspace = $bgRunspace
	$asyncResult = $worker.BeginInvoke()

	return [pscustomobject]@{
		PowerShell = $worker
		AsyncResult = $asyncResult
		Runspace = $bgRunspace
	}
}

<#
    .SYNOPSIS
    Internal function Start-GuiAppExecutionWorker.
#>

function Start-GuiAppExecutionWorker
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateSet('Install', 'Uninstall', 'Update', 'UpdateAll')]
		[string]$Action,

		[Parameter(Mandatory = $true)]
		[string]$LoaderPath,

		[Parameter(Mandatory = $true)]
		[string]$LocalizationDirectory,

		[Parameter(Mandatory = $true)]
		[string]$UICulture,

		[Parameter(Mandatory = $true)]
		[string]$LogFilePath,

		[string]$LogMode,

		[hashtable]$RunState,

		[string]$WinGetId,

		[string]$ChocoId,

		[string]$DisplayName,

		[object]$Application,

		[object[]]$SelectedApps = @(),

		[string]$PreferredSource = $null,

		[object]$PackageManagerAvailabilityState = $null
	)

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

	$bgRunspace = [runspacefactory]::CreateRunspace()
	$bgRunspace.ApartmentState = 'STA'
	$bgRunspace.ThreadOptions = 'ReuseThread'
	$bgRunspace.Open()
	if ($RunState)
	{
		$bgRunspace.SessionStateProxy.SetVariable('runState', $RunState)
		if ($RunState.ContainsKey('LogQueue'))
		{
			$bgRunspace.SessionStateProxy.SetVariable('GUIRunState', $RunState['LogQueue'])
		}
	}
	$bgRunspace.SessionStateProxy.SetVariable('bgLoaderPath', $LoaderPath)
	$bgRunspace.SessionStateProxy.SetVariable('bgLocDir', $LocalizationDirectory)
	$bgRunspace.SessionStateProxy.SetVariable('bgUICulture', $UICulture)
	$bgRunspace.SessionStateProxy.SetVariable('bgLogFilePath', $LogFilePath)
	$bgRunspace.SessionStateProxy.SetVariable('bgLogMode', $LogMode)
	$bgRunspace.SessionStateProxy.SetVariable('runAction', $Action)
	$bgRunspace.SessionStateProxy.SetVariable('packageId', $resolvedWinGetId)
	$bgRunspace.SessionStateProxy.SetVariable('chocolateyId', $resolvedChocoId)
	$bgRunspace.SessionStateProxy.SetVariable('displayName', $resolvedDisplayName)
	$bgRunspace.SessionStateProxy.SetVariable('application', $Application)
	$bgRunspace.SessionStateProxy.SetVariable('selectedApps', @($SelectedApps))
	$bgRunspace.SessionStateProxy.SetVariable('preferredSource', $PreferredSource)
	$bgRunspace.SessionStateProxy.SetVariable('packageManagerAvailabilityState', $PackageManagerAvailabilityState)

	$worker = [powershell]::Create().AddScript({
		try
		{
			$Global:GUIMode = $true
			$Script:RunState = $runState

			$bgHelperPath = Join-Path (Split-Path $bgLoaderPath -Parent) 'SharedHelpers\Localization.Helpers.ps1'
			. $bgHelperPath
			$Global:Localization = Import-BaselineLocalization -BaseDirectory $bgLocDir -UICulture $bgUICulture
			[void](Set-BaselineThreadCulture -UICulture $bgUICulture)

			# Module import must be side-effect-free (no Write-Host, no state mutation)
			# because this runs in a fresh background runspace.
			try
			{
				Import-Module $bgLoaderPath -Force -Global -ErrorAction Stop
			}
			catch
			{
				$importError = $_.Exception.Message
				if ($Script:RunState -and $Script:RunState['LogQueue'])
				{
					$Script:RunState['LogQueue'].Enqueue([PSCustomObject]@{
						Kind = 'LogWarning'
						Message = "Background app module import failed: $importError"
					})
				}
				throw
			}

			$global:LogFilePath = $bgLogFilePath
			Set-LogFile -Path $bgLogFilePath
			Set-LogMode -Mode $bgLogMode
			if ($Script:RunState -and $Script:RunState['LogQueue'])
			{
				Set-UILogHandler { param($entry) $Script:RunState['LogQueue'].Enqueue($entry) }
			}
			else
			{
				Clear-UILogHandler
			}

			if ($selectedApps -and @($selectedApps).Count -gt 0 -and $runAction -in @('Install', 'Uninstall', 'Update'))
			{
				$appBatchResult = Invoke-AppBatchAction -Action $runAction -Applications $selectedApps -PreferredSource $preferredSource -PackageManagerAvailabilityState $packageManagerAvailabilityState
				if ($Script:RunState)
				{
					$Script:RunState['AppResult'] = $appBatchResult
					if ($appBatchResult -and (Test-GuiObjectField -Object $appBatchResult -FieldName 'Outcome'))
					{
						$Script:RunState['AppOutcome'] = [string]$appBatchResult.Outcome
					}
					if ($appBatchResult -and (Test-GuiObjectField -Object $appBatchResult -FieldName 'Message'))
					{
						$Script:RunState['AppMessage'] = [string]$appBatchResult.Message
					}
				}
			}
			elseif ($application -and $runAction -in @('Install', 'Uninstall', 'Update'))
			{
				Invoke-ApplicationAction -Action $runAction -Application $application -PreferredSource $preferredSource -PackageManagerAvailabilityState $packageManagerAvailabilityState
			}
			else
			{
				switch ($runAction)
				{
					'Install'   { AppInstall -Install -WinGetId $packageId -ChocoId $chocolateyId -DisplayName $displayName -PreferredSource $preferredSource -PackageManagerAvailabilityState $packageManagerAvailabilityState }
					'Uninstall' { AppInstall -Uninstall -WinGetId $packageId -ChocoId $chocolateyId -DisplayName $displayName -PreferredSource $preferredSource -PackageManagerAvailabilityState $packageManagerAvailabilityState }
					'Update'    { AppUpdate -WinGetId $packageId -ChocoId $chocolateyId -DisplayName $displayName -PreferredSource $preferredSource -PackageManagerAvailabilityState $packageManagerAvailabilityState }
						'UpdateAll' { AppUpdate -All -PackageManagerAvailabilityState $packageManagerAvailabilityState }
					default
					{
						throw "Unsupported app action '$runAction'."
					}
				}
			}

			if ($Script:RunState -and [string]::IsNullOrWhiteSpace([string]$Script:RunState['AppOutcome']))
			{
				$Script:RunState['AppOutcome'] = 'Success'
			}
		}
		catch
		{
			if ($Script:RunState -and [string]::IsNullOrWhiteSpace([string]$Script:RunState['AppOutcome']))
			{
				$Script:RunState['AppOutcome'] = 'Failed'
			}
			$fatalMessage = if ([string]::IsNullOrWhiteSpace([string]$_.Exception.Message)) { 'Unexpected fatal app run error.' } else { [string]$_.Exception.Message }
			$diagnosticLines = [System.Collections.Generic.List[string]]::new()
			if ($Script:RunState -and -not [string]::IsNullOrWhiteSpace([string]$runAction))
			{
				[void]$diagnosticLines.Add(("Action: {0}" -f [string]$runAction))
			}
			if ($Script:RunState -and -not [string]::IsNullOrWhiteSpace([string]$packageId))
			{
				[void]$diagnosticLines.Add(("WinGet ID: {0}" -f [string]$packageId))
			}
			if ($Script:RunState -and -not [string]::IsNullOrWhiteSpace([string]$chocolateyId))
			{
				[void]$diagnosticLines.Add(("Chocolatey ID: {0}" -f [string]$chocolateyId))
			}
			if ($Script:RunState -and -not [string]::IsNullOrWhiteSpace([string]$displayName))
			{
				[void]$diagnosticLines.Add(("Display name: {0}" -f [string]$displayName))
			}
			if ($Script:RunState -and $application)
			{
				if ($application.PSObject.Properties['EntityType'] -and -not [string]::IsNullOrWhiteSpace([string]$application.EntityType))
				{
					[void]$diagnosticLines.Add(("Entity type: {0}" -f [string]$application.EntityType))
				}
				if ($application.PSObject.Properties['Name'] -and -not [string]::IsNullOrWhiteSpace([string]$application.Name))
				{
					[void]$diagnosticLines.Add(("Application: {0}" -f [string]$application.Name))
				}
			}
			if ($Script:RunState -and $selectedApps)
			{
				[void]$diagnosticLines.Add(("Selected apps: {0}" -f @($selectedApps).Count))
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
			if ($Script:RunState -and $Script:RunState['LogQueue'])
			{
				$Script:RunState['LogQueue'].Enqueue([PSCustomObject]@{
					Kind = '_RunError'
					Error = $fatalMessage
					Diagnostic = ($diagnosticLines -join "`n")
				})
			}
			throw
		}
		finally
		{
			Clear-LogMode
			if ($Script:RunState)
			{
				$Script:RunState['Done'] = $true
			}
		}
	}.GetNewClosure())

	$worker.Runspace = $bgRunspace
	$asyncResult = $worker.BeginInvoke()

	return [pscustomobject]@{
		PowerShell = $worker
		AsyncResult = $asyncResult
		Runspace = $bgRunspace
	}
}

<#
    .SYNOPSIS
    Internal function Request-GuiExecutionWorkerStop.
#>

function Request-GuiExecutionWorkerStop
{
	param (
		[Parameter(Mandatory = $true)]
		$PowerShellInstance
	)

	if (-not $PowerShellInstance)
	{
		return
	}

	[System.Threading.ThreadPool]::QueueUserWorkItem(
		[System.Threading.WaitCallback]{
			param($state)
			try
			{
				if ($state)
				{
					$state.Stop()
				}
			}
			catch
			{
				Write-GuiExecutionCleanupWarning "Failed to request GUI execution worker stop: $($_.Exception.Message)"
			}
		},
		$PowerShellInstance
	) | Out-Null
}

<#
    .SYNOPSIS
    Internal function Stop-GuiExecutionWorkerAsync.
#>

function Stop-GuiExecutionWorkerAsync
{
	# Fire-and-forget cleanup via ThreadPool. Each step (Stop, EndInvoke, Dispose,
	# Runspace.Close/Dispose) is wrapped in its own try/catch because a failure in
	# one step must not prevent cleanup of subsequent resources. Callers should null
	# out their $Worker reference after calling this function - the ThreadPool work
	# item provides no completion signal.
	param (
		[Parameter(Mandatory = $true)]
		$Worker
	)

	if (-not $Worker)
	{
		return
	}

	[System.Threading.ThreadPool]::QueueUserWorkItem(
		[System.Threading.WaitCallback]{
			param($state)

			if (-not $state)
			{
				return
			}

			try
			{
				if ($state.PowerShell)
				{
					$state.PowerShell.Stop()
				}
			}
			catch
			{
				Write-GuiExecutionCleanupWarning "Failed to stop GUI execution worker asynchronously: $($_.Exception.Message)"
			}

			try
			{
				if ($state.PowerShell -and $state.AsyncResult)
				{
					$state.PowerShell.EndInvoke($state.AsyncResult)
				}
			}
			catch
			{
				Write-GuiExecutionCleanupWarning "Failed to finalize GUI execution worker asynchronously: $($_.Exception.Message)"
			}

			try
			{
				if ($state.PowerShell)
				{
					$state.PowerShell.Dispose()
				}
			}
			catch
			{
				Write-GuiExecutionCleanupWarning "Failed to dispose GUI PowerShell worker asynchronously: $($_.Exception.Message)"
			}

			try
			{
				if ($state.Runspace)
				{
					$state.Runspace.Close()
					$state.Runspace.Dispose()
				}
			}
			catch
			{
				Write-GuiExecutionCleanupWarning "Failed to dispose GUI runspace asynchronously: $($_.Exception.Message)"
			}
		},
		$Worker
	) | Out-Null
}

<#
    .SYNOPSIS
    Internal function Stop-GuiExecutionWorker.
#>

function Stop-GuiExecutionWorker
{
	param (
		[Parameter(Mandatory = $true)]
		$Worker
	)

	if (-not $Worker)
	{
		return
	}

	try
	{
		if ($Worker.PowerShell)
		{
			$Worker.PowerShell.Stop()
		}
	}
	catch
	{
		Write-GuiExecutionCleanupWarning "Failed to stop GUI execution worker: $($_.Exception.Message)"
	}

	try
	{
		if ($Worker.PowerShell -and $Worker.AsyncResult)
		{
			$Worker.PowerShell.EndInvoke($Worker.AsyncResult)
		}
	}
	catch
	{
		Write-GuiExecutionCleanupWarning "Failed to finalize GUI execution worker: $($_.Exception.Message)"
	}

	try
	{
		if ($Worker.PowerShell)
		{
			$Worker.PowerShell.Dispose()
		}
	}
	catch
	{
		Write-GuiExecutionCleanupWarning "Failed to dispose GUI PowerShell worker: $($_.Exception.Message)"
	}

	try
	{
		if ($Worker.Runspace)
		{
			$Worker.Runspace.Close()
			$Worker.Runspace.Dispose()
		}
	}
	catch
	{
		Write-GuiExecutionCleanupWarning "Failed to dispose GUI runspace: $($_.Exception.Message)"
	}
}

<#
    .SYNOPSIS
    Internal function Complete-GuiExecutionWorker.
#>

function Complete-GuiExecutionWorker
{
	param (
		[Parameter(Mandatory = $true)]
		$Worker
	)

	if (-not $Worker)
	{
		return
	}

	try
	{
		if ($Worker.PowerShell -and $Worker.AsyncResult)
		{
			$Worker.PowerShell.EndInvoke($Worker.AsyncResult)
		}
	}
	catch
	{
		Write-GuiExecutionCleanupWarning "Failed to finalize completed GUI execution worker: $($_.Exception.Message)"
	}

	try
	{
		if ($Worker.PowerShell)
		{
			$Worker.PowerShell.Dispose()
		}
	}
	catch
	{
		Write-GuiExecutionCleanupWarning "Failed to dispose completed GUI PowerShell worker: $($_.Exception.Message)"
	}

	try
	{
		if ($Worker.Runspace)
		{
			$Worker.Runspace.Close()
			$Worker.Runspace.Dispose()
		}
	}
	catch
	{
		Write-GuiExecutionCleanupWarning "Failed to dispose completed GUI runspace: $($_.Exception.Message)"
	}
}

Export-ModuleMember -Function @(
	'Update-GuiRunStateCounter'
	'Get-GuiExecutionOutcome'
	'Test-GuiExecutionAppliedOutcome'
	'New-GuiExecutionAppliedTweakMetadata'
	'Get-GuiExecutionSummaryPayload'
	'Start-GuiExecutionWorker'
	'Start-GuiAppExecutionWorker'
	'Request-GuiExecutionWorkerStop'
	'Stop-GuiExecutionWorkerAsync'
	'Stop-GuiExecutionWorker'
	'Complete-GuiExecutionWorker'
)
<#
    .SYNOPSIS

    .DESCRIPTION
    Provides cleanup and run-state helpers used by the GUI execution flow.
    This is internal runtime plumbing, not user-facing documentation.
#>
