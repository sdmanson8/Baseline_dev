# Remote targeting helper slice for Baseline.
# Provides multi-machine compliance checking and profile application over
# PowerShell Remoting (WinRM / PSSession). Each function accepts an array of
# computer names and operates in parallel per-session.
#
# Dependencies (loaded earlier in SharedHelpers.psm1):
#   Import-ConfigurationProfile       (ConfigProfile.Helpers.ps1)
#   Test-SystemCompliance              (Compliance.Helpers.ps1)
#   Import-TweakManifestFromData       (Manifest.Helpers.ps1)
#   Get-HeadlessPresetCommandList      (Preset.Helpers.ps1)

if (-not $Script:CachedRemoteSessionCache)
{
	$Script:CachedRemoteSessionCache = @{}
}

if (-not $Script:CachedRemoteOrchestrationHistoryPath)
{
	$Script:CachedRemoteOrchestrationHistoryPath = $null
}

if (-not $Script:CachedRemoteOrchestrationDefaultRetryCount)
{
	$Script:CachedRemoteOrchestrationDefaultRetryCount = 2
}

if (-not $Script:CachedRemoteOrchestrationDefaultRetryDelayMilliseconds)
{
	$Script:CachedRemoteOrchestrationDefaultRetryDelayMilliseconds = 250
}

<#
    .SYNOPSIS
    Internal function Get-BaselineRemoteSessionKey.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-BaselineRemoteSessionKey
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$ComputerName,

		[System.Management.Automation.PSCredential]$Credential
	)

	$user = if ($Credential) { [string]$Credential.UserName } else { '<default>' }
	return ('{0}|{1}' -f ([string]$ComputerName).Trim().ToLowerInvariant(), $user.Trim().ToLowerInvariant())
}

<#
    .SYNOPSIS
    Internal function Clear-BaselineRemoteSessionCache.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Clear-BaselineRemoteSessionCache
{
	<#
		.SYNOPSIS Clears cached remote sessions.
	#>
	[CmdletBinding()]
	param (
		[string[]]$ComputerName
	)

	if (-not $Script:CachedRemoteSessionCache)
	{
		$Script:CachedRemoteSessionCache = @{}
		return
	}

	$keysToRemove = @()
	if ($ComputerName -and $ComputerName.Count -gt 0)
	{
		$targets = @($ComputerName | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim().ToLowerInvariant() })
		foreach ($key in @($Script:CachedRemoteSessionCache.Keys))
		{
			foreach ($target in $targets)
			{
				if ($key.StartsWith(($target + '|'), [System.StringComparison]::OrdinalIgnoreCase))
				{
					$keysToRemove += $key
					break
				}
			}
		}
	}
	else
	{
		$keysToRemove = @($Script:CachedRemoteSessionCache.Keys)
	}

	foreach ($key in @($keysToRemove | Select-Object -Unique))
	{
		$session = $Script:CachedRemoteSessionCache[$key]
		if ($session)
		{
			try { Remove-PSSession -Session $session -ErrorAction SilentlyContinue } catch { }
		}
		$null = $Script:CachedRemoteSessionCache.Remove($key)
	}
}

<#
    .SYNOPSIS
    Internal function Get-BaselineRemoteSession.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-BaselineRemoteSession
{
	<#
		.SYNOPSIS Gets or creates a cached remote session for a target.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$ComputerName,

		[System.Management.Automation.PSCredential]$Credential,

		[Parameter()]
		[int]$MaxRetryCount = $(if ($Script:CachedRemoteOrchestrationDefaultRetryCount) { [int]$Script:CachedRemoteOrchestrationDefaultRetryCount } else { 2 }),

		[Parameter()]
		[int]$RetryDelayMilliseconds = $(if ($Script:CachedRemoteOrchestrationDefaultRetryDelayMilliseconds) { [int]$Script:CachedRemoteOrchestrationDefaultRetryDelayMilliseconds } else { 250 })
	)

	$key = Get-BaselineRemoteSessionKey -ComputerName $ComputerName -Credential $Credential
	$session = $null
	if ($Script:CachedRemoteSessionCache.ContainsKey($key))
	{
		$session = $Script:CachedRemoteSessionCache[$key]
		$state = $null
		try { $state = [string]$session.State } catch { $state = $null }
		if ($state -notin @('Opened', 'Open'))
		{
			try { Remove-PSSession -Session $session -ErrorAction SilentlyContinue } catch { }
			$null = $Script:CachedRemoteSessionCache.Remove($key)
			$session = $null
		}
	}

	if (-not $session)
	{
		$sessionParams = @{ ComputerName = $ComputerName; ErrorAction = 'Stop' }
		if ($Credential) { $sessionParams.Credential = $Credential }

		$attempt = 0
		while ($true)
		{
			$attempt++
			try
			{
				$session = New-PSSession @sessionParams
				$Script:CachedRemoteSessionCache[$key] = $session
				break
			}
			catch
			{
				$failureProfile = Get-BaselineRemoteFailureProfile -ErrorMessages @($_.Exception.Message) -Status 'Unreachable'
				if (-not $failureProfile.Retryable -or $attempt -gt ([math]::Max(1, $MaxRetryCount + 1)))
				{
					throw
				}

				Invoke-BaselineRemoteRetryDelay -Attempt $attempt -BaseDelayMilliseconds $RetryDelayMilliseconds
			}
		}
	}

	return $session
}

<#
    .SYNOPSIS
    Internal function Get-BaselineRemoteSessionSummary.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-BaselineRemoteSessionSummary
{
	<#
		.SYNOPSIS Returns a light-weight summary of the cached remote sessions.
	#>
	[CmdletBinding()]
	param (
		[string[]]$ComputerName
	)

	$entries = [System.Collections.Generic.List[pscustomobject]]::new()
	if (-not $Script:CachedRemoteSessionCache -or $Script:CachedRemoteSessionCache.Count -eq 0)
	{
		return @()
	}

	$targets = @()
	if ($ComputerName -and $ComputerName.Count -gt 0)
	{
		$targets = @($ComputerName | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim().ToLowerInvariant() })
	}

	foreach ($key in @($Script:CachedRemoteSessionCache.Keys))
	{
		$session = $Script:CachedRemoteSessionCache[$key]
		if (-not $session) { continue }

		$computer = $null
		try { $computer = [string]$session.ComputerName } catch { $computer = $null }
		if ([string]::IsNullOrWhiteSpace($computer))
		{
			$computer = ($key -split '\|', 2)[0]
		}

		if ($targets.Count -gt 0 -and $targets -notcontains ([string]$computer).Trim().ToLowerInvariant())
		{
			continue
		}

		$userName = ($key -split '\|', 2)[1]
		$state = $null
		try { $state = [string]$session.State } catch { $state = 'Unknown' }

		$entries.Add([pscustomobject]@{
			ComputerName = $computer
			UserName     = $userName
			State        = if ([string]::IsNullOrWhiteSpace($state)) { 'Unknown' } else { $state }
		})
	}

	return @($entries)
}

<#
    .SYNOPSIS
    Internal function Get-BaselineRemoteOrchestrationHistoryPath.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-BaselineRemoteOrchestrationHistoryPath
{
	<# .SYNOPSIS Returns the path to the remote orchestration history file. #>
	[CmdletBinding()]
	param ()

	$historyDir = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'Baseline')
	if (-not [System.IO.Directory]::Exists($historyDir))
	{
		[void][System.IO.Directory]::CreateDirectory($historyDir)
	}

	$path = [System.IO.Path]::Combine($historyDir, 'remote-orchestration.jsonl')
	$Script:CachedRemoteOrchestrationHistoryPath = $path
	return $path
}

<#
    .SYNOPSIS
    Internal function Get-BaselineRemoteFailureProfile.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-BaselineRemoteFailureProfile
{
	<# .SYNOPSIS Classifies remote failures for retry and audit purposes. #>
	[CmdletBinding()]
	param (
		[string[]]$ErrorMessages,
		[string]$Status = 'Unknown'
	)

	$text = @($ErrorMessages | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ }) -join ' | '
	if ([string]::IsNullOrWhiteSpace($text) -and @('Reachable', 'Success', 'Compliant', 'Applied') -contains $Status)
	{
		return [pscustomobject]@{
			Category   = 'Success'
			Retryable  = $false
			RetryReason = 'Completed successfully.'
		}
	}

	if ([string]::IsNullOrWhiteSpace($text) -and @('Drifted', 'NonCompliant') -contains $Status)
	{
		return [pscustomobject]@{
			Category   = 'Compliance'
			Retryable  = $false
			RetryReason = 'The target completed, but drift was detected and manual remediation is required.'
		}
	}

	if ([string]::IsNullOrWhiteSpace($text) -and $Status -eq 'Partial')
	{
		return [pscustomobject]@{
			Category   = 'Partial'
			Retryable  = $false
			RetryReason = 'The target completed with partial success; review the failed items before retrying.'
		}
	}

	if ([string]::IsNullOrWhiteSpace($text))
	{
		return [pscustomobject]@{
			Category   = 'Unknown'
			Retryable  = $false
			RetryReason = 'No error details were captured.'
		}
	}

	switch -regex ($text)
	{
		'(?i)\b(timeout|timed out|unreachable|network|rpc|wsman|winrm|transport)\b'
		{
			return [pscustomobject]@{
				Category   = 'Connectivity'
				Retryable  = $true
				RetryReason = 'The failure looks transient or transport-related; retry after connectivity recovers.'
			}
		}
		'(?i)\b(access denied|authentication|logon failure|credential|unauthorized)\b'
		{
			return [pscustomobject]@{
				Category   = 'Authentication'
				Retryable  = $false
				RetryReason = 'The failure points to credentials or authorization; retry only after fixing access.'
			}
		}
		'(?i)\b(policy|gpo|group policy|blocked by policy|not permitted)\b'
		{
			return [pscustomobject]@{
				Category   = 'Policy'
				Retryable  = $false
				RetryReason = 'The failure is policy-driven; retry only after the policy conflict is resolved.'
			}
		}
		default
		{
			return [pscustomobject]@{
				Category   = 'Execution'
				Retryable  = $false
				RetryReason = 'The failure does not appear transient enough to justify an automatic retry.'
			}
		}
	}
}

<#
    .SYNOPSIS
    Internal function Get-BaselineRemoteOrchestrationHistory.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-BaselineRemoteOrchestrationHistory
{
	<# .SYNOPSIS Reads the remote orchestration JSONL history file. #>
	[CmdletBinding()]
	param (
		[datetime]$Since,
		[int]$MaxRecords = 100,
		[string]$Operation,
		[string]$ComputerName
	)

	$path = Get-BaselineRemoteOrchestrationHistoryPath
	if (-not [System.IO.File]::Exists($path))
	{
		return @()
	}

	$records = [System.Collections.Generic.List[object]]::new()
	$lines = [System.IO.File]::ReadAllLines($path, [System.Text.UTF8Encoding]::new($false))
	foreach ($line in $lines)
	{
		if ([string]::IsNullOrWhiteSpace($line)) { continue }

		try
		{
			$obj = $line | ConvertFrom-Json -ErrorAction Stop
		}
		catch
		{
			continue
		}

		if ($PSBoundParameters.ContainsKey('Since') -and $obj.Timestamp)
		{
			try
			{
				$ts = [datetime]::Parse([string]$obj.Timestamp)
				if ($ts -lt $Since) { continue }
			}
			catch { }
		}

		if (-not [string]::IsNullOrWhiteSpace($Operation) -and $obj.Operation -ne $Operation)
		{
			continue
		}

		if (-not [string]::IsNullOrWhiteSpace($ComputerName) -and $obj.ComputerName -ne $ComputerName)
		{
			continue
		}

		$records.Add($obj)
	}

	$ordered = @($records | Sort-Object -Property Timestamp -Descending)
	if ($MaxRecords -gt 0)
	{
		$ordered = @($ordered | Select-Object -First $MaxRecords)
	}

	return @($ordered)
}

<#
    .SYNOPSIS
    Internal function Get-BaselineRemoteOrchestrationSummary.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-BaselineRemoteOrchestrationSummary
{
	<# .SYNOPSIS Returns a human-readable summary of recent remote orchestration runs. #>
	[CmdletBinding()]
	param (
		[int]$MaxRecords = 5
	)

	$records = @(Get-BaselineRemoteOrchestrationHistory -MaxRecords $MaxRecords)
	if ($records.Count -eq 0)
	{
		return @()
	}

	$lines = [System.Collections.Generic.List[string]]::new()
	foreach ($record in $records)
	{
		$stamp = $null
		try { $stamp = ([datetime]::Parse([string]$record.Timestamp)).ToString('yyyy-MM-dd HH:mm:ss') } catch { $stamp = [string]$record.Timestamp }
		$status = if ($record.Status) { [string]$record.Status } else { 'Unknown' }
		$target = if ($record.ComputerName) { [string]$record.ComputerName } else { 'unknown target' }
		$operation = if ($record.Operation) { [string]$record.Operation } else { 'Remote' }
		$state = if ($record.LifecycleState) { [string]$record.LifecycleState } else { 'Unknown' }
		$attempts = if ($record.PSObject.Properties['AttemptCount']) { [int]$record.AttemptCount } else { 1 }
		$retries = if ($record.PSObject.Properties['RetryCount']) { [int]$record.RetryCount } else { 0 }
		$retry = if ($record.Retryable -eq $true -and -not [string]::IsNullOrWhiteSpace([string]$record.RetryReason)) { ' | Retryable: {0}' -f [string]$record.RetryReason } else { '' }
		[void]$lines.Add(('{0} | {1} | {2} | {3} | State: {4} | Attempts: {5} | Retries: {6}{7}' -f $stamp, $operation, $target, $status, $state, $attempts, $retries, $retry))
	}

	return @($lines)
}

<#
    .SYNOPSIS
    Internal function Get-BaselineRemoteOrchestrationDetails.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-BaselineRemoteOrchestrationDetails
{
	<# .SYNOPSIS Returns structured remote orchestration results with optional filters. #>
	[CmdletBinding()]
	param (
		[string[]]$ComputerName,
		[string[]]$Operation,
		[string[]]$Status,
		[string[]]$LifecycleState,
		[string]$RunId,
		[int]$MaxRecords = 25
	)

	$records = @(Get-BaselineRemoteOrchestrationHistory -MaxRecords $MaxRecords)
	if ($records.Count -eq 0)
	{
		return @()
	}

	$computerFilter = @($ComputerName | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim().ToLowerInvariant() })
	$operationFilter = @($Operation | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim().ToLowerInvariant() })
	$statusFilter = @($Status | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim().ToLowerInvariant() })
	$lifecycleFilter = @($LifecycleState | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim().ToLowerInvariant() })

	$entries = [System.Collections.Generic.List[pscustomobject]]::new()
	foreach ($record in $records)
	{
		if (-not [string]::IsNullOrWhiteSpace($RunId) -and ([string]$record.RunId) -ne [string]$RunId) { continue }

		$recordComputer = if ($record.ComputerName) { [string]$record.ComputerName } else { 'unknown target' }
		$recordOperation = if ($record.Operation) { [string]$record.Operation } else { 'Remote' }
		$recordStatus = if ($record.Status) { [string]$record.Status } else { 'Unknown' }
		$recordLifecycle = if ($record.LifecycleState) { [string]$record.LifecycleState } else { 'Unknown' }
		if ($computerFilter.Count -gt 0 -and $computerFilter -notcontains $recordComputer.Trim().ToLowerInvariant()) { continue }
		if ($operationFilter.Count -gt 0 -and $operationFilter -notcontains $recordOperation.Trim().ToLowerInvariant()) { continue }
		if ($statusFilter.Count -gt 0 -and $statusFilter -notcontains $recordStatus.Trim().ToLowerInvariant()) { continue }
		if ($lifecycleFilter.Count -gt 0 -and $lifecycleFilter -notcontains $recordLifecycle.Trim().ToLowerInvariant()) { continue }

		$stamp = $null
		try { $stamp = [datetime]::Parse([string]$record.Timestamp) } catch { $stamp = [datetime]::UtcNow }

		$errors = @()
		if ($record.PSObject.Properties['Errors'] -and $record.Errors)
		{
			$errors = @($record.Errors | ForEach-Object { [string]$_ })
		}
		$attemptCount = if ($record.PSObject.Properties['AttemptCount']) { [int]$record.AttemptCount } else { 1 }
		$retryCount = if ($record.PSObject.Properties['RetryCount']) { [int]$record.RetryCount } else { 0 }

		$entries.Add([pscustomobject]@{
			Timestamp       = $stamp
			ComputerName    = $recordComputer
			RemoteTarget    = if ($record.PSObject.Properties['RemoteTargetLabel']) { [string]$record.RemoteTargetLabel } else { $recordComputer }
			Operation       = $recordOperation
			Status          = $recordStatus
			LifecycleState  = $recordLifecycle
			RunId           = if ($record.PSObject.Properties['RunId']) { [string]$record.RunId } else { $null }
			AttemptCount    = if ($record.PSObject.Properties['AttemptCount']) { [int]$record.AttemptCount } else { 1 }
			RetryCount      = if ($record.PSObject.Properties['RetryCount']) { [int]$record.RetryCount } else { 0 }
			SessionState    = if ($record.PSObject.Properties['SessionState']) { [string]$record.SessionState } else { 'Unknown' }
			SessionReused   = if ($record.PSObject.Properties['SessionReused']) { [bool]$record.SessionReused } else { $false }
			BlockedByPolicy = if ($record.PSObject.Properties['BlockedByPolicy']) { [bool]$record.BlockedByPolicy } else { $false }
			FailureCategory = if ($record.PSObject.Properties['FailureCategory']) { [string]$record.FailureCategory } else { 'Unknown' }
			Retryable       = if ($record.PSObject.Properties['Retryable']) { [bool]$record.Retryable } else { $false }
			RetryReason     = if ($record.PSObject.Properties['RetryReason']) { [string]$record.RetryReason } else { $null }
			HistoryPath     = if ($record.PSObject.Properties['HistoryPath']) { [string]$record.HistoryPath } else { $null }
			DurationSeconds = if ($record.PSObject.Properties['DurationSeconds']) { [double]$record.DurationSeconds } else { 0 }
			Errors          = @($errors)
			Summary         = ('{0} | {1} | {2} | {3} | State: {4} | Attempts: {5} | Retries: {6}' -f $stamp.ToString('yyyy-MM-dd HH:mm:ss'), $recordOperation, $recordComputer, $recordStatus, $recordLifecycle, $attemptCount, $retryCount)
		})
	}

	return @($entries)
}

<#
    .SYNOPSIS
    Internal function Get-BaselineRemoteTargetLifecycleState.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-BaselineRemoteTargetLifecycleState
{
	<# .SYNOPSIS Maps remote orchestration status into a lifecycle state. #>
	[CmdletBinding()]
	param (
		[string]$Operation,
		[string]$Status,
		[bool]$Retryable = $false,
		[bool]$Blocked = $false
	)

	if ($Blocked) { return 'BlockedByPolicy' }
	if ([string]::IsNullOrWhiteSpace($Status)) { return 'Pending' }

	switch ([string]$Status)
	{
		'Reachable' { return 'Connected' }
		'Applied' { return 'Succeeded' }
		'Compliant' { return 'Succeeded' }
		'Drifted' { return 'PartiallySucceeded' }
		'Partial' { return 'PartiallySucceeded' }
		'Failed' { return if ($Retryable) { 'RetryableFailure' } else { 'Failed' } }
		'Unreachable' { return if ($Retryable) { 'RetryableFailure' } else { 'Failed' } }
		'Blocked' { return 'BlockedByPolicy' }
		'Cancelled' { return 'Cancelled' }
		default
		{
			if (-not [string]::IsNullOrWhiteSpace($Operation))
			{
				switch ([string]$Operation)
				{
					'ConnectivityTest' { return if ($Status -eq 'Reachable') { 'Connected' } else { 'RetryableFailure' } }
					'RemoteCompliance' { return if ($Status -eq 'Compliant') { 'Succeeded' } elseif ($Status -eq 'Drifted') { 'PartiallySucceeded' } else { 'Failed' } }
					'RemoteApply' { return if ($Status -eq 'Applied') { 'Succeeded' } elseif ($Status -eq 'Partial') { 'PartiallySucceeded' } else { 'Failed' } }
				}
			}
			return if ($Retryable) { 'RetryableFailure' } else { 'Failed' }
		}
	}
}

<#
    .SYNOPSIS
    Internal function Get-BaselineRemoteOrchestrationReconciliation.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-BaselineRemoteOrchestrationReconciliation
{
	<# .SYNOPSIS Summarizes remote orchestration results across runs or targets. #>
	[CmdletBinding()]
	param (
		[object[]]$Records = @()
	)

	$items = @($Records | Where-Object { $null -ne $_ })
	$summary = [ordered]@{
		Total = $items.Count
		Succeeded = 0
		PartiallySucceeded = 0
		Failed = 0
		RetryableFailures = 0
		Blocked = 0
		TotalAttempts = 0
		TotalRetries = 0
		Operations = @{}
	}

	foreach ($item in $items)
	{
		$status = if ($item.PSObject.Properties['Status']) { [string]$item.Status } else { 'Unknown' }
		$attempts = if ($item.PSObject.Properties['AttemptCount']) { [int]$item.AttemptCount } else { 1 }
		$retries = if ($item.PSObject.Properties['RetryCount']) { [int]$item.RetryCount } else { 0 }
		$summary.TotalAttempts += [math]::Max(1, $attempts)
		$summary.TotalRetries += [math]::Max(0, $retries)
		$lifecycle = if ($item.PSObject.Properties['LifecycleState']) { [string]$item.LifecycleState } else { Get-BaselineRemoteTargetLifecycleState -Operation ([string]$item.Operation) -Status $status -Retryable ([bool]$item.Retryable) -Blocked ([bool]$item.BlockedByPolicy) }
		switch ($lifecycle)
		{
			'Succeeded' { $summary.Succeeded++ }
			'PartiallySucceeded' { $summary.PartiallySucceeded++ }
			'RetryableFailure' { $summary.RetryableFailures++ }
			'BlockedByPolicy' { $summary.Blocked++ }
			default { $summary.Failed++ }
		}

		$op = if ($item.PSObject.Properties['Operation']) { [string]$item.Operation } else { 'Unknown' }
		if (-not $summary.Operations.ContainsKey($op))
		{
			$summary.Operations[$op] = [ordered]@{ Total = 0; Succeeded = 0; Failed = 0; RetryableFailures = 0; PartiallySucceeded = 0; Blocked = 0; Attempts = 0; Retries = 0 }
		}
		$summary.Operations[$op].Total++
		$summary.Operations[$op].Attempts += [math]::Max(1, $attempts)
		$summary.Operations[$op].Retries += [math]::Max(0, $retries)
		switch ($lifecycle)
		{
			'Succeeded' { $summary.Operations[$op].Succeeded++ }
			'PartiallySucceeded' { $summary.Operations[$op].PartiallySucceeded++ }
			'RetryableFailure' { $summary.Operations[$op].RetryableFailures++ }
			'BlockedByPolicy' { $summary.Operations[$op].Blocked++ }
			default { $summary.Operations[$op].Failed++ }
		}
	}

	return [pscustomobject]$summary
}

<#
    .SYNOPSIS
    Internal function Invoke-BaselineRemoteEntryWithRetry.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Invoke-BaselineRemoteEntryWithRetry
{
	<# .SYNOPSIS Executes a remote profile entry with bounded retry. #>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$EntryName,

		[Parameter(Mandatory)]
		[scriptblock]$Action,

		[int]$MaxRetryCount = $(if ($Script:CachedRemoteOrchestrationDefaultRetryCount) { [int]$Script:CachedRemoteOrchestrationDefaultRetryCount } else { 2 }),

		[int]$RetryDelayMilliseconds = $(if ($Script:CachedRemoteOrchestrationDefaultRetryDelayMilliseconds) { [int]$Script:CachedRemoteOrchestrationDefaultRetryDelayMilliseconds } else { 250 })
	)

	$attempt = 0
	$errors = [System.Collections.Generic.List[string]]::new()
	$lastProfile = $null
	$result = $null

	while ($true)
	{
		$attempt++
		try
		{
			$result = & $Action
			return [pscustomobject]@{
				Success         = $true
				Attempts        = $attempt
				RetryCount      = [math]::Max(0, $attempt - 1)
				Result          = $result
				Errors          = @()
				FailureCategory = 'Success'
				Retryable       = $false
				RetryReason     = 'Completed successfully.'
			}
		}
		catch
		{
			$message = [string]$_.Exception.Message
			if (-not [string]::IsNullOrWhiteSpace($message))
			{
				$errors.Add($message)
			}
			$lastProfile = Get-BaselineRemoteFailureProfile -ErrorMessages @($message) -Status 'Failed'
			if (-not $lastProfile.Retryable -or $attempt -ge ([math]::Max(1, $MaxRetryCount + 1)))
			{
				break
			}

			Invoke-BaselineRemoteRetryDelay -Attempt $attempt -BaseDelayMilliseconds $RetryDelayMilliseconds
		}
	}

	return [pscustomobject]@{
		Success         = $false
		Attempts        = $attempt
		RetryCount      = [math]::Max(0, $attempt - 1)
		Result          = $result
		Errors          = @($errors)
		FailureCategory = if ($lastProfile) { [string]$lastProfile.Category } else { 'Unknown' }
		Retryable       = if ($lastProfile) { [bool]$lastProfile.Retryable } else { $false }
		RetryReason     = if ($lastProfile) { [string]$lastProfile.RetryReason } else { 'No error details were captured.' }
	}
}

<#
    .SYNOPSIS
    Internal function Invoke-BaselineRemoteRetryDelay.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Invoke-BaselineRemoteRetryDelay
{
	[CmdletBinding()]
	param(
		[int]$Attempt = 1,
		[int]$BaseDelayMilliseconds = $(if ($Script:CachedRemoteOrchestrationDefaultRetryDelayMilliseconds) { [int]$Script:CachedRemoteOrchestrationDefaultRetryDelayMilliseconds } else { 250 })
	)

	$attemptIndex = [Math]::Max(1, [int]$Attempt)
	$delay = [Math]::Min(5000, $BaseDelayMilliseconds * [Math]::Pow(2, ($attemptIndex - 1)))
	$delay += (Get-Random -Minimum 0 -Maximum 100)
	Start-Sleep -Milliseconds ([int]$delay)
}

<#
    .SYNOPSIS
    Internal function Test-BaselineRemoteOrchestrationAllowed.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Test-BaselineRemoteOrchestrationAllowed
{
	[CmdletBinding()]
	param(
		[string]$KillSwitchPath = $(try { (New-BaselineOperatorPolicy).KillSwitchPath } catch { [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'BASELINE_KILL_SWITCH') })
	)

	$engaged = $false
	if (Get-Command -Name 'Test-BaselineKillSwitch' -ErrorAction SilentlyContinue)
	{
		try { $engaged = Test-BaselineKillSwitch -Path $KillSwitchPath } catch { $engaged = $false }
	}
	else
	{
		try { $engaged = [bool](Test-Path -LiteralPath $KillSwitchPath -PathType Leaf -ErrorAction SilentlyContinue) } catch { $engaged = $false }
	}

	if ($engaged)
	{
		return [pscustomobject]@{
			Allowed = $false
			Reason  = 'Kill switch is engaged.'
			Path    = $KillSwitchPath
		}
	}

	return [pscustomobject]@{
		Allowed = $true
		Reason  = $null
		Path    = $KillSwitchPath
	}
}

<#
    .SYNOPSIS
    Internal function Write-BaselineRemoteOrchestrationRecord.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Write-BaselineRemoteOrchestrationRecord
{
	<# .SYNOPSIS Appends a single remote orchestration history record. #>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[hashtable]$Record
	)

	$path = Get-BaselineRemoteOrchestrationHistoryPath
	$payload = [ordered]@{
		Timestamp      = (Get-Date).ToString('o')
		MachineName    = $env:COMPUTERNAME
		RunId          = if ($Record.ContainsKey('RunId')) { [string]$Record.RunId } else { [guid]::NewGuid().ToString('N') }
		Operation      = if ($Record.ContainsKey('Operation')) { [string]$Record.Operation } else { 'Unknown' }
		ComputerName   = if ($Record.ContainsKey('ComputerName')) { [string]$Record.ComputerName } else { $null }
		Status         = if ($Record.ContainsKey('Status')) { [string]$Record.Status } else { 'Unknown' }
		SessionReused  = if ($Record.ContainsKey('SessionReused')) { [bool]$Record.SessionReused } else { $false }
		SessionState   = if ($Record.ContainsKey('SessionState')) { [string]$Record.SessionState } else { 'Unknown' }
		LifecycleState = if ($Record.ContainsKey('LifecycleState')) { [string]$Record.LifecycleState } else { $null }
		AttemptCount   = if ($Record.ContainsKey('AttemptCount')) { [int]$Record.AttemptCount } else { 1 }
		RetryCount     = if ($Record.ContainsKey('RetryCount')) { [int]$Record.RetryCount } else { 0 }
		BlockedByPolicy = if ($Record.ContainsKey('BlockedByPolicy')) { [bool]$Record.BlockedByPolicy } else { $false }
		AppliedCount   = if ($Record.ContainsKey('AppliedCount')) { [int]$Record.AppliedCount } else { 0 }
		FailedCount    = if ($Record.ContainsKey('FailedCount')) { [int]$Record.FailedCount } else { 0 }
		DriftedCount   = if ($Record.ContainsKey('DriftedCount')) { [int]$Record.DriftedCount } else { 0 }
		TotalChecked   = if ($Record.ContainsKey('TotalChecked')) { [int]$Record.TotalChecked } else { 0 }
		FailureCategory = if ($Record.ContainsKey('FailureCategory')) { [string]$Record.FailureCategory } else { $null }
		Retryable      = if ($Record.ContainsKey('Retryable')) { [bool]$Record.Retryable } else { $false }
		RetryReason    = if ($Record.ContainsKey('RetryReason')) { [string]$Record.RetryReason } else { $null }
		Errors         = if ($Record.ContainsKey('Errors') -and $null -ne $Record.Errors) { @($Record.Errors) } else { @() }
		HistoryPath    = $path
	}

	if ($Record.ContainsKey('StartedAt') -and $Record.StartedAt)
	{
		$payload['StartedAt'] = ([datetime]$Record.StartedAt).ToString('o')
	}
	if ($Record.ContainsKey('CompletedAt') -and $Record.CompletedAt)
	{
		$payload['CompletedAt'] = ([datetime]$Record.CompletedAt).ToString('o')
	}
	if ($Record.ContainsKey('DurationSeconds') -and $null -ne $Record.DurationSeconds)
	{
		$payload['DurationSeconds'] = [math]::Round([double]$Record.DurationSeconds, 2)
	}
	if ($Record.ContainsKey('Details') -and $null -ne $Record.Details)
	{
		$payload['Details'] = $Record.Details
	}
	if ($Record.ContainsKey('RemoteTargetLabel') -and $Record.RemoteTargetLabel)
	{
		$payload['RemoteTargetLabel'] = [string]$Record.RemoteTargetLabel
	}

	$json = ConvertTo-Json -InputObject $payload -Compress -Depth 6
	[System.IO.File]::AppendAllText($path, "$json`n", [System.Text.UTF8Encoding]::new($false))
	return [pscustomobject]$payload
}

<#
    .SYNOPSIS
    Internal function Test-BaselineRemoteConnectivity.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Test-BaselineRemoteConnectivity
{
	<#
		.SYNOPSIS
		Tests WinRM connectivity for one or more remote computers.

		.DESCRIPTION
		Iterates over each computer name, calls Test-WSMan, and returns a
		per-machine result indicating whether the machine is reachable.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string[]]$ComputerName,

		[Parameter()]
		[System.Management.Automation.PSCredential]$Credential,

		[Parameter()]
		[int]$MaxRetryCount = $(if ($Script:CachedRemoteOrchestrationDefaultRetryCount) { [int]$Script:CachedRemoteOrchestrationDefaultRetryCount } else { 2 }),

		[Parameter()]
		[int]$RetryDelayMilliseconds = $(if ($Script:CachedRemoteOrchestrationDefaultRetryDelayMilliseconds) { [int]$Script:CachedRemoteOrchestrationDefaultRetryDelayMilliseconds } else { 250 })
	)

	$policyGate = Test-BaselineRemoteOrchestrationAllowed
	$results = [System.Collections.Generic.List[pscustomobject]]::new()

	foreach ($computer in @($ComputerName))
	{
		$attempt = 0
		$entry = $null
		do
		{
			$attempt++
			$runId = [guid]::NewGuid().ToString('N')
			$startedAt = [datetime]::UtcNow
			$status = if ($policyGate.Allowed) { 'Unreachable' } else { 'Blocked' }
			$entry = [pscustomobject]@{
				ComputerName    = $computer
				RunId           = $runId
				AttemptCount    = $attempt
				RetryCount      = 0
				Reachable       = $false
				Status          = $status
				LifecycleState  = Get-BaselineRemoteTargetLifecycleState -Operation 'ConnectivityTest' -Status $status -Blocked (-not $policyGate.Allowed)
				FailureCategory = $null
				Retryable       = $false
				RetryReason     = $null
				BlockedByPolicy = (-not $policyGate.Allowed)
				HistoryPath     = $null
				DurationSeconds = 0
				Error           = if ($policyGate.Allowed) { $null } else { $policyGate.Reason }
			}

			$shouldRetry = $false
			if ($policyGate.Allowed)
			{
				try
				{
					$wsmanParams = @{ ComputerName = $computer; ErrorAction = 'Stop' }
					if ($Credential) { $wsmanParams.Credential = $Credential }

					$null = Test-WSMan @wsmanParams
					$entry.Reachable = $true
					$status = 'Reachable'
				}
				catch
				{
					$entry.Error = $_.Exception.Message
				}
			}

			$completedAt = [datetime]::UtcNow
			$failureProfile = Get-BaselineRemoteFailureProfile -ErrorMessages @($entry.Error) -Status $status
			$entry.Status = $status
			$entry.FailureCategory = $failureProfile.Category
			$entry.Retryable = $failureProfile.Retryable
			$entry.RetryReason = $failureProfile.RetryReason
			$entry.LifecycleState = Get-BaselineRemoteTargetLifecycleState -Operation 'ConnectivityTest' -Status $status -Retryable $entry.Retryable -Blocked $entry.BlockedByPolicy
			$entry.DurationSeconds = [math]::Round(($completedAt - $startedAt).TotalSeconds, 2)
			$entry.RetryCount = [math]::Max(0, $attempt - 1)
			$record = Write-BaselineRemoteOrchestrationRecord -Record @{
				RunId             = $runId
				Operation         = 'ConnectivityTest'
				ComputerName      = $computer
				RemoteTargetLabel = $computer
				Status            = $status
				LifecycleState    = $entry.LifecycleState
				SessionReused     = $false
				SessionState      = 'NotConnected'
				TotalChecked      = 0
				AttemptCount      = $attempt
				RetryCount        = [math]::Max(0, $attempt - 1)
				Errors            = @($entry.Error)
				FailureCategory   = $failureProfile.Category
				Retryable         = $failureProfile.Retryable
				RetryReason       = $failureProfile.RetryReason
				StartedAt         = $startedAt
				CompletedAt       = $completedAt
				DurationSeconds   = $entry.DurationSeconds
				Details           = [ordered]@{ Reachable = [bool]$entry.Reachable; AttemptCount = $attempt }
			}
			$entry.HistoryPath = $record.HistoryPath

			if ($policyGate.Allowed -and $entry.Retryable -and $attempt -lt ([math]::Max(1, $MaxRetryCount + 1)))
			{
				$shouldRetry = $true
				Invoke-BaselineRemoteRetryDelay -Attempt $attempt -BaseDelayMilliseconds $RetryDelayMilliseconds
			}
		}
		while ($shouldRetry)

		$results.Add($entry)
	}

	return @($results)
}

<#
    .SYNOPSIS
    Internal function Invoke-BaselineRemoteCompliance.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Invoke-BaselineRemoteCompliance
{
	<#
		.SYNOPSIS
		Runs a Baseline compliance check against one or more remote machines.

		.DESCRIPTION
		For each computer, opens a PSSession, copies the profile and Baseline
		module files to a temporary directory, invokes the compliance check
		headlessly inside the session, collects results, and cleans up.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string[]]$ComputerName,

		[Parameter(Mandatory)]
		[string]$ProfilePath,

		[Parameter()]
		[System.Management.Automation.PSCredential]$Credential,

		[Parameter()]
		[int]$MaxRetryCount = $(if ($Script:CachedRemoteOrchestrationDefaultRetryCount) { [int]$Script:CachedRemoteOrchestrationDefaultRetryCount } else { 2 }),

		[Parameter()]
		[int]$RetryDelayMilliseconds = $(if ($Script:CachedRemoteOrchestrationDefaultRetryDelayMilliseconds) { [int]$Script:CachedRemoteOrchestrationDefaultRetryDelayMilliseconds } else { 250 })
	)

	if (-not (Test-Path -LiteralPath $ProfilePath))
	{
		throw "Profile file not found: $ProfilePath"
	}

	$moduleRoot = $Script:SharedHelpersModuleRoot
	$repoRoot   = $Script:SharedHelpersRepoRoot
	$policyGate = Test-BaselineRemoteOrchestrationAllowed

	$results = [System.Collections.Generic.List[pscustomobject]]::new()

	foreach ($computer in @($ComputerName))
	{
		$runId = [guid]::NewGuid().ToString('N')
		$startedAt = [datetime]::UtcNow
		$status = 'Unknown'
		$sessionReused = $false
		$sessionState = 'NotConnected'
		$entry = [pscustomobject]@{
			ComputerName    = $computer
			RunId           = $runId
			AttemptCount    = 1
			RetryCount      = 0
			Compliant       = $false
			DriftedCount    = 0
			TotalChecked    = 0
			Status          = $status
			LifecycleState  = if ($policyGate.Allowed) { 'Pending' } else { 'BlockedByPolicy' }
			FailureCategory = $null
			Retryable       = $false
			RetryReason     = $null
			BlockedByPolicy = (-not $policyGate.Allowed)
			SessionReused   = $sessionReused
			SessionState    = $sessionState
			HistoryPath     = $null
			DurationSeconds = 0
			Errors          = @()
		}

		$session = $null
		try
		{
			if ($policyGate.Allowed)
			{
				$payloadAttempt = 0
				$payloadRetry = $false
				do
				{
					$payloadAttempt++
					$payloadRetry = $false
					$remoteTempDir = $null
					$entry.Errors = @()
					$entry.Compliant = $false
					$entry.DriftedCount = 0
					$entry.TotalChecked = 0

					try
					{
						$sessionSummaryBefore = @()
						try { $sessionSummaryBefore = @(Get-BaselineRemoteSessionSummary -ComputerName $computer) } catch { $sessionSummaryBefore = @() }
						$sessionReused = $sessionSummaryBefore.Count -gt 0
						# Open or reuse a cached remote session.
						$session = Get-BaselineRemoteSession -ComputerName $computer -Credential $Credential -MaxRetryCount $MaxRetryCount -RetryDelayMilliseconds $RetryDelayMilliseconds
						if ($session) { $sessionState = [string]$session.State }

						# Create a temp staging directory on the remote machine.
						$remoteTempDir = Invoke-Command -Session $session -ScriptBlock {
							$dir = Join-Path ([System.IO.Path]::GetTempPath()) "Baseline_$([guid]::NewGuid().ToString('N'))"
							$null = New-Item -Path $dir -ItemType Directory -Force
							return $dir
						}

						# Copy profile file to the remote temp directory.
						$remoteProfilePath = Join-Path $remoteTempDir (Split-Path $ProfilePath -Leaf)
						Copy-Item -Path $ProfilePath -Destination $remoteProfilePath -ToSession $session -Force

						# Copy the Module directory to the remote temp directory.
						$remoteModuleDir = Join-Path $remoteTempDir 'Module'
						Copy-Item -Path $moduleRoot -Destination $remoteModuleDir -ToSession $session -Recurse -Force

						# Copy the Localizations directory (required by the module).
						$localizationsDir = Join-Path $repoRoot 'Localizations'
						if (Test-Path -LiteralPath $localizationsDir)
						{
							$remoteLocDir = Join-Path $remoteTempDir 'Localizations'
							Copy-Item -Path $localizationsDir -Destination $remoteLocDir -ToSession $session -Recurse -Force
						}

						# Run the compliance check on the remote machine.
						$remoteResult = Invoke-Command -Session $session -ArgumentList $remoteProfilePath, $remoteModuleDir -ScriptBlock {
							param ($profilePath, $moduleDir)

							$errors = [System.Collections.Generic.List[string]]::new()
							$report = $null

							try
							{
								# Import the SharedHelpers module from the staged directory.
								$sharedHelpersPath = Join-Path $moduleDir 'SharedHelpers.psm1'
								Import-Module -Name $sharedHelpersPath -Force -ErrorAction Stop

								# Load the profile.
								$profileContent = Get-Content -LiteralPath $profilePath -Raw -ErrorAction Stop
								$profile = $profileContent | ConvertFrom-Json -ErrorAction Stop

								# Load the manifest.
								$manifest = @(Import-TweakManifestFromData)
								if (-not $manifest -or $manifest.Count -eq 0)
								{
									$errors.Add('Failed to load tweak manifest on remote machine.')
								}
								else
								{
									$report = Test-SystemCompliance -Profile $profile -Manifest $manifest
								}
							}
							catch
							{
								$errors.Add($_.Exception.Message)
							}

							return @{
								Report = $report
								Errors = @($errors)
							}
						}

						# Process remote results.
						if ($remoteResult.Report)
						{
							$report = $remoteResult.Report
							$entry.TotalChecked = $report.TotalChecked
							$entry.DriftedCount = $report.Drifted
							$entry.Compliant    = ($report.Drifted -eq 0)
						}

						if ($remoteResult.Errors -and $remoteResult.Errors.Count -gt 0)
						{
							$entry.Errors = @($remoteResult.Errors)
						}
					}
					catch
					{
						$entry.Errors = @($entry.Errors + $_.Exception.Message)
					}
					finally
					{
						if ($remoteTempDir)
						{
							Invoke-Command -Session $session -ArgumentList $remoteTempDir -ScriptBlock {
								param ($dir)
								if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
							}
						}
					}

					if ($entry.Errors.Count -gt 0)
					{
						$payloadProfile = Get-BaselineRemoteFailureProfile -ErrorMessages @($entry.Errors) -Status 'Failed'
						if ($payloadProfile.Retryable -and $payloadAttempt -lt ([math]::Max(1, $MaxRetryCount + 1)))
						{
							$payloadRetry = $true
							Invoke-BaselineRemoteRetryDelay -Attempt $payloadAttempt -BaseDelayMilliseconds $RetryDelayMilliseconds
						}
					}
				}
				while ($payloadRetry)

				$entry.AttemptCount = $payloadAttempt
				$entry.RetryCount = [math]::Max(0, $payloadAttempt - 1)
			}
			else
			{
				$entry.Errors = @($policyGate.Reason)
			}
		}
		catch
		{
			$entry.Errors = @($entry.Errors + $_.Exception.Message)
		}
		finally
		{
			$completedAt = [datetime]::UtcNow
			$entry.SessionReused = $sessionReused
			$entry.SessionState = $sessionState
			if ($entry.Errors.Count -gt 0)
			{
				$status = 'Failed'
			}
			elseif ($entry.Compliant)
			{
				$status = 'Compliant'
			}
			elseif ($entry.TotalChecked -gt 0 -and $entry.DriftedCount -gt 0)
			{
				$status = 'Drifted'
			}
			else
			{
				$status = 'Unknown'
			}

			$entry.Status = $status
			$failureProfile = Get-BaselineRemoteFailureProfile -ErrorMessages @($entry.Errors) -Status $status
			$entry.LifecycleState = Get-BaselineRemoteTargetLifecycleState -Operation 'RemoteCompliance' -Status $status -Retryable $failureProfile.Retryable -Blocked $entry.BlockedByPolicy
			$record = Write-BaselineRemoteOrchestrationRecord -Record @{
				RunId             = $runId
				Operation         = 'RemoteCompliance'
				ComputerName      = $computer
				RemoteTargetLabel = $computer
				Status            = $status
				LifecycleState    = $entry.LifecycleState
				SessionReused     = $sessionReused
				SessionState      = $sessionState
				DriftedCount      = $entry.DriftedCount
				TotalChecked      = $entry.TotalChecked
				AttemptCount      = $entry.AttemptCount
				RetryCount        = $entry.RetryCount
				BlockedByPolicy   = $entry.BlockedByPolicy
				Errors            = @($entry.Errors)
				FailureCategory   = $failureProfile.Category
				Retryable         = $failureProfile.Retryable
				RetryReason       = $failureProfile.RetryReason
				StartedAt         = $startedAt
				CompletedAt       = $completedAt
				DurationSeconds   = ($completedAt - $startedAt).TotalSeconds
				Details           = [ordered]@{
					Compliant = [bool]$entry.Compliant
				}
			}

			$entry.FailureCategory = $record.FailureCategory
			$entry.Retryable = $record.Retryable
			$entry.RetryReason = $record.RetryReason
			$entry.HistoryPath = $record.HistoryPath
			$entry.DurationSeconds = $record.DurationSeconds
		}

		$results.Add($entry)
	}

	return @($results)
}

<#
    .SYNOPSIS
    Internal function Invoke-BaselineRemoteApply.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Invoke-BaselineRemoteApply
{
	<#
		.SYNOPSIS
		Applies a Baseline configuration profile to one or more remote machines.

		.DESCRIPTION
		For each computer, opens a PSSession, copies the profile and Baseline
		module files to a temporary directory, resolves the profile entries to
		headless commands, executes them inside the remote session, and collects
		per-machine results.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string[]]$ComputerName,

		[Parameter(Mandatory)]
		[string]$ProfilePath,

		[Parameter()]
		[System.Management.Automation.PSCredential]$Credential,

		[Parameter()]
		[int]$MaxRetryCount = $(if ($Script:CachedRemoteOrchestrationDefaultRetryCount) { [int]$Script:CachedRemoteOrchestrationDefaultRetryCount } else { 2 }),

		[Parameter()]
		[int]$RetryDelayMilliseconds = $(if ($Script:CachedRemoteOrchestrationDefaultRetryDelayMilliseconds) { [int]$Script:CachedRemoteOrchestrationDefaultRetryDelayMilliseconds } else { 250 })
	)

	if (-not (Test-Path -LiteralPath $ProfilePath))
	{
		throw "Profile file not found: $ProfilePath"
	}

	$moduleRoot = $Script:SharedHelpersModuleRoot
	$repoRoot   = $Script:SharedHelpersRepoRoot
	$policyGate = Test-BaselineRemoteOrchestrationAllowed

	$results = [System.Collections.Generic.List[pscustomobject]]::new()

	foreach ($computer in @($ComputerName))
	{
		$runId = [guid]::NewGuid().ToString('N')
		$startedAt = [datetime]::UtcNow
		$status = 'Unknown'
		$sessionReused = $false
		$sessionState = 'NotConnected'
		$entry = [pscustomobject]@{
			ComputerName    = $computer
			RunId           = $runId
			AttemptCount    = 1
			RetryCount      = 0
			Applied         = $false
			AppliedCount    = 0
			FailedCount     = 0
			Status          = $status
			LifecycleState  = if ($policyGate.Allowed) { 'Pending' } else { 'BlockedByPolicy' }
			FailureCategory = $null
			Retryable       = $false
			RetryReason     = $null
			BlockedByPolicy = (-not $policyGate.Allowed)
			SessionReused   = $sessionReused
			SessionState    = $sessionState
			HistoryPath     = $null
			DurationSeconds = 0
			Errors          = @()
		}

		$session = $null
		try
		{
			if ($policyGate.Allowed)
			{
				$sessionSummaryBefore = @()
				try { $sessionSummaryBefore = @(Get-BaselineRemoteSessionSummary -ComputerName $computer) } catch { $sessionSummaryBefore = @() }
				$sessionReused = $sessionSummaryBefore.Count -gt 0
				# Open or reuse a cached remote session.
				$session = Get-BaselineRemoteSession -ComputerName $computer -Credential $Credential -MaxRetryCount $MaxRetryCount -RetryDelayMilliseconds $RetryDelayMilliseconds
				if ($session) { $sessionState = [string]$session.State }

				# Create a temp staging directory on the remote machine.
				$remoteTempDir = Invoke-Command -Session $session -ScriptBlock {
					$dir = Join-Path ([System.IO.Path]::GetTempPath()) "Baseline_$([guid]::NewGuid().ToString('N'))"
					$null = New-Item -Path $dir -ItemType Directory -Force
					return $dir
				}

				# Copy profile file to the remote temp directory.
				$remoteProfilePath = Join-Path $remoteTempDir (Split-Path $ProfilePath -Leaf)
				Copy-Item -Path $ProfilePath -Destination $remoteProfilePath -ToSession $session -Force

				# Copy the Module directory to the remote temp directory.
				$remoteModuleDir = Join-Path $remoteTempDir 'Module'
				Copy-Item -Path $moduleRoot -Destination $remoteModuleDir -ToSession $session -Recurse -Force

				# Copy the Localizations directory (required by the module).
				$localizationsDir = Join-Path $repoRoot 'Localizations'
				if (Test-Path -LiteralPath $localizationsDir)
				{
					$remoteLocDir = Join-Path $remoteTempDir 'Localizations'
					Copy-Item -Path $localizationsDir -Destination $remoteLocDir -ToSession $session -Recurse -Force
				}

				# Copy the relocated entry script for headless execution.
				$baselineScript = Join-Path $repoRoot 'Bootstrap/Baseline.ps1'
				if (Test-Path -LiteralPath $baselineScript)
				{
					$remoteBootstrapDir = Join-Path $remoteTempDir 'Bootstrap'
					Invoke-Command -Session $session -ArgumentList $remoteBootstrapDir -ScriptBlock {
						param ($dir)
						$null = New-Item -Path $dir -ItemType Directory -Force
					}
					Copy-Item -Path $baselineScript -Destination $remoteBootstrapDir -ToSession $session -Force
				}

				# Run the profile application on the remote machine.
				$remoteResult = Invoke-Command -Session $session -ArgumentList $remoteProfilePath, $remoteModuleDir, $remoteTempDir -ScriptBlock {
				param ($profilePath, $moduleDir, $baseDir)

				$errors = [System.Collections.Generic.List[string]]::new()
				$appliedCount = 0
				$failedCount  = 0

				try
				{
					# Import the SharedHelpers module from the staged directory.
					$sharedHelpersPath = Join-Path $moduleDir 'SharedHelpers.psm1'
					Import-Module -Name $sharedHelpersPath -Force -ErrorAction Stop

					# Import the main Baseline module.
					$baselineModulePath = Join-Path $moduleDir 'Baseline.psd1'
					if (Test-Path -LiteralPath $baselineModulePath)
					{
						Import-Module -Name $baselineModulePath -Force -ErrorAction Stop
					}

					# Load the profile.
					$profileContent = Get-Content -LiteralPath $profilePath -Raw -ErrorAction Stop
					$profile = $profileContent | ConvertFrom-Json -ErrorAction Stop

					# Extract entries from the profile and build headless command list.
					$profileEntries = @()
					if ($profile.PSObject.Properties['Entries'] -and $profile.Entries)
					{
						$profileEntries = @($profile.Entries)
					}

					$entryResults = [System.Collections.Generic.List[pscustomobject]]::new()
					foreach ($profileEntry in @($profileEntries))
					{
						if (-not $profileEntry) { continue }

						$functionName = $null
						$paramValue   = $null
						$entryType    = 'Toggle'

						if ($profileEntry.PSObject.Properties['Function'])
						{
							$functionName = [string]$profileEntry.Function
						}
						if ($profileEntry.PSObject.Properties['Type'])
						{
							$entryType = [string]$profileEntry.Type
						}

						if ([string]::IsNullOrWhiteSpace($functionName)) { continue }

						# Resolve the parameter to pass.
						switch ($entryType)
						{
							'Choice'
							{
								if ($profileEntry.PSObject.Properties['Value'] -and
									-not [string]::IsNullOrWhiteSpace([string]$profileEntry.Value))
								{
									$paramValue = [string]$profileEntry.Value
								}
							}
							default
							{
								if ($profileEntry.PSObject.Properties['Param'] -and
									-not [string]::IsNullOrWhiteSpace([string]$profileEntry.Param))
								{
									$paramValue = [string]$profileEntry.Param
								}
							}
						}

						$entryAttempt = Invoke-BaselineRemoteEntryWithRetry -EntryName $functionName -MaxRetryCount $MaxRetryCount -RetryDelayMilliseconds $RetryDelayMilliseconds -Action {
							$cmd = Get-Command -Name $functionName -ErrorAction SilentlyContinue
							if (-not $cmd)
							{
								throw "Command not found: $functionName"
							}

							if ($paramValue)
							{
								& $functionName -$paramValue
							}
							else
							{
								& $functionName
							}
						}

						if ($entryAttempt.Success)
						{
							$appliedCount++
						}
						else
						{
							$failedCount++
							foreach ($message in @($entryAttempt.Errors))
							{
								if (-not [string]::IsNullOrWhiteSpace([string]$message))
								{
									$errors.Add("Failed to apply $functionName : $message")
								}
							}
						}

						$entryResults.Add([pscustomobject]@{
							Function    = $functionName
							Type        = $entryType
							Attempts    = $entryAttempt.Attempts
							RetryCount  = $entryAttempt.RetryCount
							Success     = [bool]$entryAttempt.Success
							Retryable   = [bool]$entryAttempt.Retryable
							RetryReason = [string]$entryAttempt.RetryReason
							Errors      = @($entryAttempt.Errors)
						})
					}
				}
				catch
				{
					$errors.Add($_.Exception.Message)
				}

					return @{
						AppliedCount = $appliedCount
						FailedCount  = $failedCount
						Errors       = @($errors)
						Entries      = @($entryResults)
					}
				}

				# Process remote results.
				$entry.AppliedCount = $remoteResult.AppliedCount
				$entry.FailedCount  = $remoteResult.FailedCount
				$entry.Applied      = ($remoteResult.FailedCount -eq 0 -and $remoteResult.AppliedCount -gt 0)
				if ($remoteResult.Entries -and $remoteResult.Entries.Count -gt 0)
				{
					$entry.AttemptCount = [int](($remoteResult.Entries | ForEach-Object { if ($_.Attempts) { [int]$_.Attempts } else { 1 } }) | Measure-Object -Sum).Sum
					$entry.RetryCount = [int](($remoteResult.Entries | ForEach-Object { if ($_.RetryCount) { [int]$_.RetryCount } else { 0 } }) | Measure-Object -Sum).Sum
				}
				else
				{
					$entry.AttemptCount = 1
					$entry.RetryCount = 0
				}

				if ($remoteResult.Errors -and $remoteResult.Errors.Count -gt 0)
				{
					$entry.Errors = @($remoteResult.Errors)
				}

				# Clean up temp files on the remote machine.
				Invoke-Command -Session $session -ArgumentList $remoteTempDir -ScriptBlock {
					param ($dir)
					if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
				}
			}
			else
			{
				$entry.Errors = @($policyGate.Reason)
			}
		}
		catch
		{
			$entry.Errors = @($entry.Errors + $_.Exception.Message)
		}
		finally
		{
			$completedAt = [datetime]::UtcNow
			$entry.SessionReused = $sessionReused
			$entry.SessionState = $sessionState
			if ($entry.Errors.Count -gt 0)
			{
				$status = 'Failed'
			}
			elseif ($entry.AppliedCount -gt 0 -and $entry.FailedCount -eq 0)
			{
				$status = 'Applied'
			}
			elseif ($entry.AppliedCount -gt 0 -and $entry.FailedCount -gt 0)
			{
				$status = 'Partial'
			}
			elseif ($entry.AppliedCount -eq 0 -and $entry.FailedCount -gt 0)
			{
				$status = 'Failed'
			}
			else
			{
				$status = 'Unknown'
			}

			$entry.Applied = ($status -eq 'Applied')
			$entry.Status = $status
			$failureProfile = Get-BaselineRemoteFailureProfile -ErrorMessages @($entry.Errors) -Status $status
			$entry.LifecycleState = Get-BaselineRemoteTargetLifecycleState -Operation 'RemoteApply' -Status $status -Retryable $failureProfile.Retryable -Blocked $entry.BlockedByPolicy
			$record = Write-BaselineRemoteOrchestrationRecord -Record @{
				RunId             = $runId
				Operation         = 'RemoteApply'
				ComputerName      = $computer
				RemoteTargetLabel = $computer
				Status            = $status
				LifecycleState    = $entry.LifecycleState
				SessionReused     = $sessionReused
				SessionState      = $sessionState
				AppliedCount      = $entry.AppliedCount
				FailedCount       = $entry.FailedCount
				AttemptCount      = $entry.AttemptCount
				RetryCount        = $entry.RetryCount
				BlockedByPolicy   = $entry.BlockedByPolicy
				Errors            = @($entry.Errors)
				FailureCategory   = $failureProfile.Category
				Retryable         = $failureProfile.Retryable
				RetryReason       = $failureProfile.RetryReason
				StartedAt         = $startedAt
				CompletedAt       = $completedAt
				DurationSeconds   = ($completedAt - $startedAt).TotalSeconds
				Details           = [ordered]@{
					Applied = [bool]$entry.Applied
					Entries = @($remoteResult.Entries)
				}
			}

			$entry.FailureCategory = $record.FailureCategory
			$entry.Retryable = $record.Retryable
			$entry.RetryReason = $record.RetryReason
			$entry.HistoryPath = $record.HistoryPath
			$entry.DurationSeconds = $record.DurationSeconds
		}

		$results.Add($entry)
	}

	return @($results)
}
