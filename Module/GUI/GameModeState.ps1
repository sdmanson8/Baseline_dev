# Game Mode state initialization and reset

	<#
	    .SYNOPSIS
	    Internal function Initialize-GameModeState.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Initialize-GameModeState
	{
		param ([hashtable]$Context = $Script:Ctx)

		$Script:GameMode = $false
		$Script:GameModeProfile = $null
		$Script:GameModeCorePlan = @()
		$Script:GameModePlan = @()
		$Script:GameModeControlSyncInProgress = $false
		$Script:GameModeDecisionOverrides = @{}
		$Script:GameModeAdvancedSelections = @{}
		$Script:GameModePreviousPrimaryTab = $null
		$Script:GameModeAllowlist = @(Get-GameModeAllowlist)
		# Cross-tab entries: functions from other tabs that should also appear in the Gaming tab.
		# Uses a HashSet for O(1) lookup in the filter hot path.
		$Script:GamingCrossTabFunctions = [System.Collections.Generic.HashSet[string]]::new([string[]]@('PowerPlan'))
		$Script:ExecutionGameModeContext = $null

		if ($Context)
		{
			Sync-GameModeContextState -Context $Context
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Reset-GameModeState.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Reset-GameModeState
	{
		param ([hashtable]$Context = $Script:Ctx)

		$Script:GameModeProfile = $null
		$Script:GameModeCorePlan = @()
		$Script:GameModePlan = @()
		$Script:GameModeControlSyncInProgress = $false
		$Script:GameModeDecisionOverrides = @{}
		$Script:GameModeAdvancedSelections = @{}

		if ($Context)
		{
			Sync-GameModeContextState -Context $Context
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Sync-GameModeContextState.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Sync-GameModeContextState
	{
		param ([hashtable]$Context = $Script:Ctx)

		if (-not $Context)
		{
			return
		}

		$decisionOverrides = @{}
		foreach ($overrideKey in @($Script:GameModeDecisionOverrides.Keys))
		{
			if ([string]::IsNullOrWhiteSpace([string]$overrideKey)) { continue }
			$decisionOverrides[[string]$overrideKey] = [string]$Script:GameModeDecisionOverrides[$overrideKey]
		}

		$advancedSelections = @{}
		foreach ($selectionKey in @($Script:GameModeAdvancedSelections.Keys))
		{
			if ([string]::IsNullOrWhiteSpace([string]$selectionKey)) { continue }
			$advancedSelections[[string]$selectionKey] = [bool]$Script:GameModeAdvancedSelections[$selectionKey]
		}

		$Context.GameMode.Active = [bool]$Script:GameMode
		$Context.GameMode.Profile = if ([string]::IsNullOrWhiteSpace([string]$Script:GameModeProfile)) { $null } else { [string]$Script:GameModeProfile }
		$Context.GameMode.CorePlan = @($Script:GameModeCorePlan)
		$Context.GameMode.Plan = @($Script:GameModePlan)
		$Context.GameMode.ControlSyncInProgress = [bool]$Script:GameModeControlSyncInProgress
		$Context.GameMode.DecisionOverrides = $decisionOverrides
		$Context.GameMode.AdvancedSelections = $advancedSelections
		$Context.GameMode.PreviousPrimaryTab = if ([string]::IsNullOrWhiteSpace([string]$Script:GameModePreviousPrimaryTab)) { $null } else { [string]$Script:GameModePreviousPrimaryTab }
		$Context.GameMode.Allowlist = @($Script:GameModeAllowlist)
		$Context.GameMode.ExecutionContext = $Script:ExecutionGameModeContext
	}

	<#
	    .SYNOPSIS
	    Internal function Test-HasGameModeTweaks.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Test-HasGameModeTweaks
	{
		param ([object[]]$TweakList)

		return (@($TweakList | Where-Object { (Test-GuiObjectField -Object $_ -FieldName 'FromGameMode') -and [bool]$_.FromGameMode }).Count -gt 0)
	}

	<#
	    .SYNOPSIS
	    Internal function .

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>
	function Test-IsGameModeRun
	{
		param (
			[object[]]$TweakList,
			[hashtable]$Context = $Script:Ctx
		)

		$active = if ($Context) { [bool]$Context.GameMode.Active } else { [bool]$Script:GameMode }
		return ($active -and (Test-HasGameModeTweaks -TweakList $TweakList))
	}

	<#
	    .SYNOPSIS
	    Internal function Test-IsGameModeActive.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Test-IsGameModeActive
	{
		param ([hashtable]$Context = $Script:Ctx)
		if ($Context) { return [bool]$Context.GameMode.Active }
		return [bool]$Script:GameMode
	}

	<#
	    .SYNOPSIS
	    Internal function .

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>
	function Get-GameModeProfile
	{
		param ([hashtable]$Context = $Script:Ctx)
		if ($Context) { return $Context.GameMode.Profile }
		return $Script:GameModeProfile
	}

	<#
	    .SYNOPSIS
	    Internal function Get-GameModePlan.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Get-GameModePlan
	{
		param ([hashtable]$Context = $Script:Ctx)
		if ($Context) { return @($Context.GameMode.Plan) }
		return @($Script:GameModePlan)
	}

	<#
	    .SYNOPSIS
	    Internal function .

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>
	function Get-GameModeDecisionOverrides
	{
		param ([hashtable]$Context = $Script:Ctx)
		if ($Context) { return $Context.GameMode.DecisionOverrides }
		return $Script:GameModeDecisionOverrides
	}

	<#
	    .SYNOPSIS
	    Internal function Get-ExecutionGameModeContext.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Get-ExecutionGameModeContext
	{
		param ([hashtable]$Context = $Script:Ctx)
		if ($Context) { return $Context.GameMode.ExecutionContext }
		return $Script:ExecutionGameModeContext
	}

	<#
	    .SYNOPSIS
	    Internal function .

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>
	function Set-ExecutionGameModeContext
	{
		param (
			$GameModeContext,
			[hashtable]$Context = $Script:Ctx
		)

		$Script:ExecutionGameModeContext = $GameModeContext
		if ($Context) { $Context.GameMode.ExecutionContext = $GameModeContext }
	}

