# ExecutionOrchestration split file loaded by Module\GUI\ExecutionOrchestration.ps1.

	<#
	    .SYNOPSIS
	#>

	function Set-RunAbortDisposition
	{
		param (
			[string]$Disposition = $null
		)

		$resolvedDisposition = if ([string]::IsNullOrWhiteSpace([string]$Disposition))
		{
			$null
		}
		else
		{
			[string]$Disposition.Trim()
		}

		$Script:RunAbortDisposition = $resolvedDisposition
		if ($Script:RunState)
		{
			$Script:RunState['AbortDisposition'] = $resolvedDisposition
		}
	}

	<#
	    .SYNOPSIS
	#>

	function Get-RunAbortDisposition
	{
		$stateDisposition = $null
		if ($Script:RunState -and $Script:RunState.ContainsKey('AbortDisposition'))
		{
			$stateDisposition = if ([string]::IsNullOrWhiteSpace([string]$Script:RunState['AbortDisposition']))
			{
				$null
			}
			else
			{
				[string]$Script:RunState['AbortDisposition']
			}
		}

		$scriptDisposition = if ([string]::IsNullOrWhiteSpace([string]$Script:RunAbortDisposition))
		{
			$null
		}
		else
		{
			[string]$Script:RunAbortDisposition
		}

		$resolvedDisposition = if (-not [string]::IsNullOrWhiteSpace([string]$stateDisposition))
		{
			$stateDisposition
		}
		else
		{
			$scriptDisposition
		}

		if ([string]::IsNullOrWhiteSpace([string]$resolvedDisposition))
		{
			return 'Return'
		}

		return [string]$resolvedDisposition
	}

	<#
	    .SYNOPSIS
	#>

	function Reset-RunAbortState
	{
		$Script:AbortRequested = $false
		Set-RunAbortDisposition -Disposition $null
	}

	function Build-WhatChangedSummaryText
	{
		<#
		.SYNOPSIS
			Builds the "What happened" summary string from execution insight counts.
		.DESCRIPTION
			Shared helper that eliminates duplicated whatChangedText construction
			between the Defaults-mode and standard/GameMode completion paths.
		#>
		param (
			[string]$OpeningLine,
			[string]$Noun,
			[object]$Insights,
			[int]$RestartPendingCount,
			[int]$NotRunCount,
			[string]$AlreadyDesiredPhrase,
			[string]$RestartPendingPhrase,
			[string]$NotApplicableSingularPhrase,
			[string]$NotApplicablePluralPhrase,
			[string]$PolicySkippedSingularPhrase,
			[string]$PolicySkippedPluralPhrase,
			[string]$RecoverableSingularPhrase = ' qualifies for a safe retry',
			[string]$RecoverablePluralPhrase = 's qualify for a safe retry',
			[string]$ManualSingularPhrase = ' still needs manual review',
			[string]$ManualPluralPhrase = 's still need manual review'
		)

		$text = $OpeningLine
		if ($Insights.AlreadyDesiredCount -gt 0)
		{
			$text += " $($Insights.AlreadyDesiredCount) $Noun$(if ($Insights.AlreadyDesiredCount -eq 1) { '' } else { 's' }) $AlreadyDesiredPhrase."
		}
		if ($RestartPendingCount -gt 0)
		{
			$text += " $RestartPendingCount $Noun$(if ($RestartPendingCount -eq 1) { '' } else { 's' }) $RestartPendingPhrase."
		}
		if ($Insights.NotApplicableCount -gt 0)
		{
			$text += " $($Insights.NotApplicableCount) $Noun$(if ($Insights.NotApplicableCount -eq 1) { $NotApplicableSingularPhrase } else { $NotApplicablePluralPhrase })."
		}
		if ($Insights.PolicySkippedCount -gt 0)
		{
			$text += " $($Insights.PolicySkippedCount) $Noun$(if ($Insights.PolicySkippedCount -eq 1) { $PolicySkippedSingularPhrase } else { $PolicySkippedPluralPhrase })."
		}
		if ($Insights.RecoverableFailedCount -gt 0)
		{
			$text += " $($Insights.RecoverableFailedCount) $Noun$(if ($Insights.RecoverableFailedCount -eq 1) { $RecoverableSingularPhrase } else { $RecoverablePluralPhrase })."
		}
		if ($Insights.ManualFailedCount -gt 0)
		{
			$text += " $($Insights.ManualFailedCount) $Noun$(if ($Insights.ManualFailedCount -eq 1) { $ManualSingularPhrase } else { $ManualPluralPhrase })."
		}
		if ($NotRunCount -gt 0)
		{
			$text += " $NotRunCount $Noun$(if ($NotRunCount -eq 1) { '' } else { 's' }) did not run."
		}
		return $text
	}

	<#
	    .SYNOPSIS
	#>

	function Invoke-GuiExecutionCompletionToast
	{
		[CmdletBinding()]
		param (
			[ValidateSet('Run', 'Defaults')]
			[string]$Mode,
			[Parameter(Mandatory)]
			[string]$Title,
			[Parameter(Mandatory)]
			[string]$Body
		)

		if ($Mode -ne 'Run')
		{
			return
		}

		if (-not (Get-Command -Name 'Show-BaselineToast' -CommandType Function -ErrorAction SilentlyContinue))
		{
			return
		}

		if (-not (Get-Command -Name 'Test-BaselineToastRuntimeAvailable' -CommandType Function -ErrorAction SilentlyContinue))
		{
			return
		}

		if (-not (Test-BaselineToastRuntimeAvailable))
		{
			return
		}

		try
		{
			$null = Show-BaselineToast -Title $Title -Body $Body -AppId 'Baseline' -Duration 'Short'
		}
		catch
		{
			Write-SwallowedException -ErrorRecord $_ -Source 'ExecutionOrchestration.RunCompletion.Toast'
		}
	}

	<#
	    .SYNOPSIS
	#>

	function Get-ActiveTweakRunList
	{
		$selectedTweaks = @(Get-SelectedTweakRunList)
		if (-not [bool]$Script:GameMode)
		{
			return $selectedTweaks
		}

		$allowlistLookup = @{}
		foreach ($allowlistFunction in @($Script:GameModeAllowlist))
		{
			$allowlistName = [string]$allowlistFunction
			if (-not [string]::IsNullOrWhiteSpace($allowlistName))
			{
				$allowlistLookup[$allowlistName] = $true
			}
		}

		$selectedGameModeScoped = @(
			$selectedTweaks | Where-Object {
				if (-not $_) { return $false }
				$selectedFunction = if ((Test-GuiObjectField -Object $_ -FieldName 'Function')) { [string]$_.Function } else { $null }
				if ([string]::IsNullOrWhiteSpace($selectedFunction)) { return $false }
				return $allowlistLookup.ContainsKey($selectedFunction)
			}
		)

		$gameModePlan = @(Get-GameModePlan)
		if ($gameModePlan.Count -eq 0)
		{
			return $selectedGameModeScoped
		}

		# Merge gaming-scoped manual selections with the active Game Mode plan.
		# If both contain the same function, Game Mode plan entry wins.
		$mergedRunList = [System.Collections.Generic.List[object]]::new()
		$indexByFunction = @{}

		foreach ($selectedEntry in $selectedGameModeScoped)
		{
			if (-not $selectedEntry)
			{
				continue
			}

			[void]$mergedRunList.Add($selectedEntry)

			$selectedFunction = if ((Test-GuiObjectField -Object $selectedEntry -FieldName 'Function')) { [string]$selectedEntry.Function } else { $null }
			if (-not [string]::IsNullOrWhiteSpace($selectedFunction))
			{
				$indexByFunction[$selectedFunction] = $mergedRunList.Count - 1
			}
		}

		foreach ($planEntry in $gameModePlan)
		{
			if (-not $planEntry)
			{
				continue
			}

			$planFunction = if ((Test-GuiObjectField -Object $planEntry -FieldName 'Function')) { [string]$planEntry.Function } else { $null }
			if (-not [string]::IsNullOrWhiteSpace($planFunction) -and $indexByFunction.ContainsKey($planFunction))
			{
				$mergedRunList[[int]$indexByFunction[$planFunction]] = $planEntry
				continue
			}

			[void]$mergedRunList.Add($planEntry)
			if (-not [string]::IsNullOrWhiteSpace($planFunction))
			{
				$indexByFunction[$planFunction] = $mergedRunList.Count - 1
			}
		}

		return @($mergedRunList)
	}

