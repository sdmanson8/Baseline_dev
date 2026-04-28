# Support bundle helpers for Baseline.
# Builds a portable, operator-facing archive with environment, audit,
# compliance, and execution context for troubleshooting and enterprise review.

<#
    .SYNOPSIS
    Internal function Export-BaselineSupportBundle.
#>

function Get-BaselineSupportBundleDeepLinks
{
	[CmdletBinding()]
	param (
		[string[]]$RunId,
		[string[]]$ComputerName,
		[string[]]$Operation
	)

	$runFilter = @($RunId | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim().ToLowerInvariant() })
	$computerFilter = @($ComputerName | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim().ToLowerInvariant() })
	$operationFilter = @($Operation | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim().ToLowerInvariant() })

	$records = @()
	if (Get-Command -Name 'Get-BaselineRemoteOrchestrationHistory' -ErrorAction SilentlyContinue)
	{
		try
		{
			$records = @(Get-BaselineRemoteOrchestrationHistory -MaxRecords 500)
		}
		catch
		{
			$records = @()
		}
	}
	if ($records.Count -eq 0)
	{
		try
		{
			$historyPath = $null
			if (Get-Command -Name 'Get-BaselineRemoteOrchestrationHistoryPath' -ErrorAction SilentlyContinue)
			{
				try { $historyPath = Get-BaselineRemoteOrchestrationHistoryPath } catch { $historyPath = $null }
			}
			if ([string]::IsNullOrWhiteSpace($historyPath))
			{
				$historyPath = Join-Path (Join-Path $env:LOCALAPPDATA 'Baseline') 'remote-orchestration.jsonl'
			}
			if (-not [string]::IsNullOrWhiteSpace($historyPath) -and (Test-Path -LiteralPath $historyPath))
			{
				$lines = [System.IO.File]::ReadAllLines($historyPath, [System.Text.UTF8Encoding]::new($false))
				foreach ($line in $lines)
				{
					if ([string]::IsNullOrWhiteSpace($line)) { continue }
					try
					{
						$record = $line | ConvertFrom-BaselineJson -Depth 16 -ErrorAction Stop
						if ($record) { $records += $record }
					}
					catch
					{
						continue
					}
				}
			}
		}
		catch
		{
			$records = @()
		}
	}

	$links = [System.Collections.Generic.List[pscustomobject]]::new()
	foreach ($record in $records)
	{
		if (-not $record) { continue }
		$recordKind = if ($record.PSObject.Properties['RecordKind']) { [string]$record.RecordKind } else { 'Target' }
		if ($recordKind -notin @('Target', 'RunSummary')) { continue }

		$recordRunId = if ($record.PSObject.Properties['RunId']) { [string]$record.RunId } else { $null }
		$recordComputer = if ($record.PSObject.Properties['ComputerName']) { [string]$record.ComputerName } else { $null }
		$recordOperation = if ($record.PSObject.Properties['Operation']) { [string]$record.Operation } else { 'Remote' }

		if ($runFilter.Count -gt 0 -and ([string]::IsNullOrWhiteSpace($recordRunId) -or $runFilter -notcontains $recordRunId.Trim().ToLowerInvariant())) { continue }
		if ($computerFilter.Count -gt 0 -and ([string]::IsNullOrWhiteSpace($recordComputer) -or $computerFilter -notcontains $recordComputer.Trim().ToLowerInvariant())) { continue }
		if ($operationFilter.Count -gt 0 -and $operationFilter -notcontains $recordOperation.Trim().ToLowerInvariant()) { continue }

		$targetState = if ($record.PSObject.Properties['TargetState']) { [string]$record.TargetState } else { 'Unknown' }
		$terminalState = if ($record.PSObject.Properties['TerminalState']) { [string]$record.TerminalState } else { 'Unknown' }
		$failedCount = if ($record.PSObject.Properties['FailedCount']) { [int]$record.FailedCount } else { 0 }
		$historyPath = if ($record.PSObject.Properties['HistoryPath']) { [string]$record.HistoryPath } else { $null }

		$artifactNames = [System.Collections.Generic.List[string]]::new()
		[void]$artifactNames.Add('bundle-index.json')
		[void]$artifactNames.Add('metadata.json')
		[void]$artifactNames.Add('remote-orchestration.jsonl')
		[void]$artifactNames.Add('remote-orchestration-summary.txt')
		[void]$artifactNames.Add('remote-orchestration-runs.json')
		[void]$artifactNames.Add('remote-orchestration-reconciliation.json')
		[void]$artifactNames.Add('remote-orchestration-details.json')
		if ($failedCount -gt 0)
		{
			[void]$artifactNames.Add('remote-orchestration-deeplinks.json')
		}

		$links.Add([pscustomobject]@{
			Kind         = $recordKind
			RunId        = $recordRunId
			ComputerName  = $recordComputer
			Operation     = $recordOperation
			TargetState   = $targetState
			TerminalState = $terminalState
			FailedCount   = $failedCount
			HistoryPath   = $historyPath
			Artifacts     = @($artifactNames | Select-Object -Unique)
		})
	}

	return @($links)
}

function Export-BaselineSupportBundle
{
	<#
		.SYNOPSIS
		Builds a Baseline support bundle archive at the requested output path.

		.DESCRIPTION
		Stages a portable folder containing:
		- bundle metadata
		- audit log snapshot
		- optional system state snapshot
		- optional compliance report
		- optional configuration profile
		- optional test report
		Then compresses the staging folder into a ZIP archive.

		When -Immutable is specified, generates a signoff bundle with:
		- SHA256 checksums for all included files
		- Bundle integrity manifest
		- Provenance tracking (user, machine, timestamp)
		- Read-only file attributes on extracted contents
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$OutputPath,

		[switch]$Immutable,

		[string]$SignoffReason,

		[string]$ProfilePath,

		[object]$ComplianceReport,

		[object]$WindowsUpdateStatus,

		[object]$SystemSnapshot,

		[object]$PreSnapshot,

		[object]$PostSnapshot,

		[object]$ConfigStatePre,

		[object]$ConfigStatePost,

		[Parameter()]
		[AllowEmptyCollection()]
		[object[]]$RemoteTargets = @(),

		[object]$ReproductionContext,

		[array]$Manifest,

		[string[]]$DeepLinkRunId,

		[string[]]$DeepLinkComputerName,

		[string[]]$DeepLinkOperation,

		[switch]$IncludeAuditLog = $true,

		[int]$AuditRetentionDays = $(try { Get-BaselineAuditRetentionDays } catch { 90 }),

		[switch]$IncludeTestReport = $true,

		[Parameter()]
		[AllowEmptyCollection()]
		[object[]]$ConnectivityResults = @()
	)

	if ([string]::IsNullOrWhiteSpace($OutputPath))
	{
		throw 'OutputPath is required.'
	}

	if (-not $OutputPath.EndsWith('.zip', [System.StringComparison]::OrdinalIgnoreCase))
	{
		$OutputPath = '{0}.zip' -f $OutputPath
	}

	$parentDir = Split-Path -Path $OutputPath -Parent
	if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path -LiteralPath $parentDir))
	{
		$null = New-Item -Path $parentDir -ItemType Directory -Force -ErrorAction Stop
	}

	$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('BaselineSupportBundle_{0}' -f [guid]::NewGuid().ToString('N'))
	$stagingDir = Join-Path $tempRoot 'Bundle'
	$bundleEntries = [System.Collections.Generic.List[pscustomobject]]::new()
	$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
	$deepLinkFilters = [ordered]@{
		RunId = @($DeepLinkRunId | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim() })
		ComputerName = @($DeepLinkComputerName | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim() })
		Operation = @($DeepLinkOperation | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim() })
	}

	try
	{
		$null = New-Item -Path $stagingDir -ItemType Directory -Force

		$baselineVersion = $null
		if (Get-Command -Name 'Get-BaselineDisplayVersion' -ErrorAction SilentlyContinue)
		{
			try { $baselineVersion = Get-BaselineDisplayVersion } catch { $baselineVersion = $null }
		}

		$maturityManifest = @($Manifest)
		if ($maturityManifest.Count -eq 0 -and (Get-Command -Name 'Import-TweakManifestFromData' -ErrorAction SilentlyContinue))
		{
			try { $maturityManifest = @(Import-TweakManifestFromData) } catch { $maturityManifest = @() }
		}

		$featureMaturityReport = $null
		if (Get-Command -Name 'Get-BaselineFeatureMaturityReport' -ErrorAction SilentlyContinue)
		{
			try { $featureMaturityReport = Get-BaselineFeatureMaturityReport -Manifest $maturityManifest } catch { $featureMaturityReport = $null }
		}

		$validationEvidenceReport = $null
		if (Get-Command -Name 'Get-BaselineValidationEvidenceReport' -ErrorAction SilentlyContinue)
		{
			try { $validationEvidenceReport = Get-BaselineValidationEvidenceReport } catch { $validationEvidenceReport = $null }
		}

		$windowsUpdateStatusForBundle = $WindowsUpdateStatus
		if ($null -eq $windowsUpdateStatusForBundle)
		{
			$getWindowsUpdateStatusCommand = Get-Command -Name 'Get-WindowsUpdateStatus' -CommandType Function -ErrorAction SilentlyContinue
			if ($getWindowsUpdateStatusCommand)
			{
				try
				{
					$windowsUpdateStatusForBundle = & $getWindowsUpdateStatusCommand
				}
				catch
				{
					$windowsUpdateStatusForBundle = [pscustomobject]@{
						Schema      = 'Baseline.WindowsUpdateStatus'
						GeneratedAt = [System.DateTime]::UtcNow.ToString('o')
						Succeeded   = $false
						Error       = $_.Exception.Message
					}
				}
			}
		}

		$windowsUpdateStatusSucceeded = $null
		$windowsUpdateSummary = $null
		if ($null -ne $windowsUpdateStatusForBundle)
		{
			if ($windowsUpdateStatusForBundle.PSObject.Properties['Succeeded'])
			{
				$windowsUpdateStatusSucceeded = [bool]$windowsUpdateStatusForBundle.Succeeded
			}
			if ($windowsUpdateStatusForBundle.PSObject.Properties['Summary'])
			{
				$windowsUpdateSummary = $windowsUpdateStatusForBundle.Summary
			}
		}

		$activeRunId = $null
		if (Get-Command -Name 'Get-BaselineRunId' -ErrorAction SilentlyContinue)
		{
			try { $activeRunId = [string](Get-BaselineRunId) } catch { $activeRunId = $null }
		}
		if ([string]::IsNullOrWhiteSpace($activeRunId) -and $global:BaselineRunId)
		{
			$activeRunId = [string]$global:BaselineRunId
		}

		$metadata = [ordered]@{
			Schema          = 'Baseline.SupportBundle'
			SchemaVersion   = 2
			GeneratedAt     = [System.DateTime]::UtcNow.ToString('o')
			RunId           = $activeRunId
			MachineName     = $env:COMPUTERNAME
			UserName        = $env:USERNAME
			BaselineVersion = $baselineVersion
			PowerShell      = [ordered]@{
				Edition = $PSVersionTable.PSEdition
				Version = $PSVersionTable.PSVersion.ToString()
			}
			OS              = [System.Environment]::OSVersion.VersionString
			OutputFile      = [System.IO.Path]::GetFileName($OutputPath)
			ProfilePath     = $ProfilePath
			AuditRetention  = [ordered]@{
				Days   = [int]$AuditRetentionDays
				Cutoff = (Get-Date).AddDays(-1 * [int]$AuditRetentionDays).ToString('o')
			}
			FeatureMaturitySummary = if ($featureMaturityReport) { $featureMaturityReport.Summary } else { $null }
			ValidationEvidenceSummary = if ($validationEvidenceReport) { $validationEvidenceReport.Summary } else { $null }
			ValidationEvidenceChannels = if ($validationEvidenceReport) { @($validationEvidenceReport.ValidationChannels) } else { @() }
			WindowsUpdateStatusSucceeded = $windowsUpdateStatusSucceeded
			WindowsUpdateSummary = $windowsUpdateSummary
			Immutable       = [bool]$Immutable
			SignoffBundle   = [bool]$Immutable
		}

		# --- Reproduction context: action sequence + CLI args ---
		# Caller hands us a hashtable / pscustomobject with optional
		# ActionSequence (string[]) and CommandLineArgs (string[]). Both are
		# emitted under metadata.ReproductionContext so a maintainer can
		# replay the user's path. ActionSequence comes from the in-process
		# action trail in Logging.psm1; CommandLineArgs is captured at
		# bootstrap. Either may be empty/null without breaking the bundle.
		$reproContext = $null
		if ($null -ne $ReproductionContext)
		{
			$actionTrail = @()
			$cliArgs = @()
			$reproProps = $ReproductionContext.PSObject.Properties
			if ($reproProps['ActionSequence']) { $actionTrail = @($ReproductionContext.ActionSequence | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) }
			if ($reproProps['CommandLineArgs']) { $cliArgs = @($ReproductionContext.CommandLineArgs | Where-Object { $null -ne $_ }) }
			$reproContext = [ordered]@{
				ActionSequence  = $actionTrail
				CommandLineArgs = $cliArgs
			}
		}
		else
		{
			# Auto-pull from Logging if available so callers that don't pass
			# explicit context still get the action trail.
			$autoTrail = @()
			if (Get-Command -Name 'Get-BaselineActionTrail' -ErrorAction SilentlyContinue)
			{
				try { $autoTrail = @(Get-BaselineActionTrail) } catch { $autoTrail = @() }
			}
			$autoCli = @()
			if ($global:BaselineCommandLineArgs) { $autoCli = @($global:BaselineCommandLineArgs) }
			if ($autoTrail.Count -gt 0 -or $autoCli.Count -gt 0)
			{
				$reproContext = [ordered]@{
					ActionSequence  = $autoTrail
					CommandLineArgs = $autoCli
				}
			}
		}
		if ($null -ne $reproContext)
		{
			$metadata['ReproductionContext'] = $reproContext
		}

		if ($Immutable)
		{
			$metadata['SignoffProvenance'] = [ordered]@{
				Reason       = if (-not [string]::IsNullOrWhiteSpace($SignoffReason)) { $SignoffReason } else { 'Enterprise signoff bundle' }
				SignedBy     = $env:USERNAME
				SignedOn     = $env:COMPUTERNAME
				SignedAt     = [System.DateTime]::UtcNow.ToString('o')
				Domain       = $env:USERDOMAIN
			}
		}

		$metadataPath = Join-Path $stagingDir 'metadata.json'
		[System.IO.File]::WriteAllText($metadataPath, ($metadata | ConvertTo-Json -Depth 8), $utf8NoBom)
		$bundleEntries.Add([pscustomobject]@{ Name = 'metadata.json'; Source = $metadataPath })

		$bundleIndex = [ordered]@{
			Schema        = 'Baseline.SupportBundleIndex'
			SchemaVersion = 1
			GeneratedAt   = [System.DateTime]::UtcNow.ToString('o')
			Files         = [ordered]@{
				Metadata = 'metadata.json'
			}
		}

		if ($featureMaturityReport)
		{
			$featureMaturityPath = Join-Path $stagingDir 'feature-maturity.json'
			[System.IO.File]::WriteAllText($featureMaturityPath, ($featureMaturityReport | ConvertTo-Json -Depth 10), $utf8NoBom)
			$bundleEntries.Add([pscustomobject]@{ Name = 'feature-maturity.json'; Source = $featureMaturityPath })
			$bundleIndex.Files['FeatureMaturity'] = 'feature-maturity.json'
		}

		if ($validationEvidenceReport)
		{
			$validationEvidencePath = Join-Path $stagingDir 'validation-evidence.json'
			[System.IO.File]::WriteAllText($validationEvidencePath, ($validationEvidenceReport | ConvertTo-Json -Depth 10), $utf8NoBom)
			$bundleEntries.Add([pscustomobject]@{ Name = 'validation-evidence.json'; Source = $validationEvidencePath })
			$bundleIndex.Files['ValidationEvidence'] = 'validation-evidence.json'
		}

		if ($null -ne $windowsUpdateStatusForBundle)
		{
			$windowsUpdateStatusPath = Join-Path $stagingDir 'windows-update-status.json'
			[System.IO.File]::WriteAllText($windowsUpdateStatusPath, ($windowsUpdateStatusForBundle | ConvertTo-Json -Depth 10), $utf8NoBom)
			$bundleEntries.Add([pscustomobject]@{ Name = 'windows-update-status.json'; Source = $windowsUpdateStatusPath })
			$bundleIndex.Files['WindowsUpdateStatus'] = 'windows-update-status.json'
		}

		$deepLinkItems = [System.Collections.Generic.List[pscustomobject]]::new()
		if ((($deepLinkFilters.RunId.Count -gt 0) -or ($deepLinkFilters.ComputerName.Count -gt 0) -or ($deepLinkFilters.Operation.Count -gt 0)) -and (Get-Command -Name 'Get-BaselineSupportBundleDeepLinks' -ErrorAction SilentlyContinue))
		{
			try
			{
				$deepLinkItems = [System.Collections.Generic.List[pscustomobject]]::new()
				$links = Get-BaselineSupportBundleDeepLinks -RunId $deepLinkFilters.RunId -ComputerName $deepLinkFilters.ComputerName -Operation $deepLinkFilters.Operation
				foreach ($link in @($links))
				{
					if ($null -ne $link) { [void]$deepLinkItems.Add($link) }
				}
			}
			catch
			{
				$deepLinkItems = [System.Collections.Generic.List[pscustomobject]]::new()
			}
		}

		if ($IncludeAuditLog)
		{
			$auditLogPath = Get-AuditLogPath
			if (Test-Path -LiteralPath $auditLogPath)
			{
				$destAuditLogPath = Join-Path $stagingDir 'audit.jsonl'
				$auditRecords = @()
				try
				{
					$auditRecords = @(Get-AuditLog -Since (Get-Date).AddDays(-1 * [int]$AuditRetentionDays) -MaxRecords 10000)
				}
				catch
				{
					$auditRecords = @()
				}

				if ($auditRecords.Count -gt 0)
				{
					$lines = foreach ($record in $auditRecords) { $record | ConvertTo-Json -Compress -Depth 6 }
					[System.IO.File]::WriteAllLines($destAuditLogPath, $lines, $utf8NoBom)
				}
				else
				{
					Copy-Item -LiteralPath $auditLogPath -Destination $destAuditLogPath -Force
				}
				$bundleEntries.Add([pscustomobject]@{ Name = 'audit.jsonl'; Source = $destAuditLogPath })
				$bundleIndex.Files['Audit'] = 'audit.jsonl'
			}
		}

		$remoteHistoryPath = $null
		$getRemoteHistoryPathCommand = Get-Command -Name 'Get-BaselineRemoteOrchestrationHistoryPath' -ErrorAction SilentlyContinue
		if ($getRemoteHistoryPathCommand)
		{
			try { $remoteHistoryPath = & $getRemoteHistoryPathCommand } catch { $remoteHistoryPath = $null }
		}
		if ([string]::IsNullOrWhiteSpace($remoteHistoryPath))
		{
			$remoteHistoryPath = Join-Path (Join-Path $env:LOCALAPPDATA 'Baseline') 'remote-orchestration.jsonl'
		}

		if (-not [string]::IsNullOrWhiteSpace($remoteHistoryPath) -and (Test-Path -LiteralPath $remoteHistoryPath))
		{
			$destRemoteHistoryPath = Join-Path $stagingDir 'remote-orchestration.jsonl'
			Copy-Item -LiteralPath $remoteHistoryPath -Destination $destRemoteHistoryPath -Force
			$bundleEntries.Add([pscustomobject]@{ Name = 'remote-orchestration.jsonl'; Source = $destRemoteHistoryPath })
			$bundleIndex.Files['RemoteHistory'] = 'remote-orchestration.jsonl'

			$getRemoteHistorySummaryCommand = Get-Command -Name 'Get-BaselineRemoteOrchestrationSummary' -ErrorAction SilentlyContinue
			if ($getRemoteHistorySummaryCommand)
			{
				try
				{
					$remoteHistorySummary = @(& $getRemoteHistorySummaryCommand -MaxRecords 25)
				}
				catch
				{
					$remoteHistorySummary = @()
				}
			}
			else
			{
				$remoteHistorySummary = [System.Collections.Generic.List[string]]::new()
				try
				{
					$historyLines = [System.IO.File]::ReadAllLines($remoteHistoryPath, [System.Text.UTF8Encoding]::new($false))
					foreach ($line in $historyLines)
					{
						if ([string]::IsNullOrWhiteSpace($line)) { continue }
						try
						{
							$record = $line | ConvertFrom-BaselineJson -Depth 16 -ErrorAction Stop
						}
						catch
						{
							continue
						}

						$stamp = $null
						try { $stamp = ([datetime]::Parse([string]$record.Timestamp)).ToString('yyyy-MM-dd HH:mm:ss') } catch { $stamp = [string]$record.Timestamp }
						$status = if ($record.Status) { [string]$record.Status } else { 'Unknown' }
						$target = if ($record.ComputerName) { [string]$record.ComputerName } else { 'unknown target' }
						$operation = if ($record.Operation) { [string]$record.Operation } else { 'Remote' }
						$retry = if ($record.Retryable -eq $true -and -not [string]::IsNullOrWhiteSpace([string]$record.RetryReason)) { ' | Retryable: {0}' -f [string]$record.RetryReason } else { '' }
						[void]$remoteHistorySummary.Add(('{0} | {1} | {2} | {3}{4}' -f $stamp, $operation, $target, $status, $retry))
					}
				}
				catch
				{
					$remoteHistorySummary = @()
				}
			}

			if ($remoteHistorySummary.Count -gt 0)
			{
				$remoteSummaryPath = Join-Path $stagingDir 'remote-orchestration-summary.txt'
				[System.IO.File]::WriteAllLines($remoteSummaryPath, $remoteHistorySummary, $utf8NoBom)
				$bundleEntries.Add([pscustomobject]@{ Name = 'remote-orchestration-summary.txt'; Source = $remoteSummaryPath })
				$bundleIndex.Files['RemoteSummary'] = 'remote-orchestration-summary.txt'
			}

			$remoteRunSummaries = @()
			$getRemoteRunSummariesCommand = Get-Command -Name 'Get-BaselineRemoteRunSummaries' -ErrorAction SilentlyContinue
			if ($getRemoteRunSummariesCommand)
			{
				try
				{
					$remoteRunSummaries = @(& $getRemoteRunSummariesCommand -MaxRecords 100)
				}
				catch
				{
					$remoteRunSummaries = @()
				}
			}

			if ($remoteRunSummaries.Count -gt 0)
			{
				$remoteRunSummariesPath = Join-Path $stagingDir 'remote-orchestration-runs.json'
				[System.IO.File]::WriteAllText($remoteRunSummariesPath, ($remoteRunSummaries | ConvertTo-Json -Depth 8), $utf8NoBom)
				$bundleEntries.Add([pscustomobject]@{ Name = 'remote-orchestration-runs.json'; Source = $remoteRunSummariesPath })
				$bundleIndex.Files['RemoteRuns'] = 'remote-orchestration-runs.json'
			}

			$remoteReconciliation = $null
			try
			{
				$recentRemoteRuns = @(Get-BaselineRemoteOrchestrationHistory -MaxRecords 100)
				if ($recentRemoteRuns.Count -gt 0)
				{
					$remoteReconciliation = Get-BaselineRemoteOrchestrationReconciliation -Records $recentRemoteRuns
				}
			}
			catch
			{
				$remoteReconciliation = $null
			}

			if ($null -ne $remoteReconciliation)
			{
				$remoteReconciliationPath = Join-Path $stagingDir 'remote-orchestration-reconciliation.json'
				[System.IO.File]::WriteAllText($remoteReconciliationPath, ($remoteReconciliation | ConvertTo-Json -Depth 8), $utf8NoBom)
				$bundleEntries.Add([pscustomobject]@{ Name = 'remote-orchestration-reconciliation.json'; Source = $remoteReconciliationPath })
				$bundleIndex.Files['RemoteReconciliation'] = 'remote-orchestration-reconciliation.json'
			}

			$remoteDetails = @()
			$getRemoteHistoryDetailsCommand = Get-Command -Name 'Get-BaselineRemoteOrchestrationDetails' -ErrorAction SilentlyContinue
			if ($getRemoteHistoryDetailsCommand)
			{
				try
				{
					$remoteDetails = @(& $getRemoteHistoryDetailsCommand -MaxRecords 100)
				}
				catch
				{
					$remoteDetails = @()
				}
			}
			else
			{
				try
				{
					$historyLines = [System.IO.File]::ReadAllLines($remoteHistoryPath, [System.Text.UTF8Encoding]::new($false))
					foreach ($line in $historyLines)
					{
						if ([string]::IsNullOrWhiteSpace($line)) { continue }
						try
						{
							$record = $line | ConvertFrom-BaselineJson -Depth 16 -ErrorAction Stop
						}
						catch
						{
							continue
						}

						$errors = @()
						if ($record.PSObject.Properties['Errors'] -and $record.Errors)
						{
							$errors = @($record.Errors | ForEach-Object { [string]$_ })
						}

						$remoteDetails += [pscustomobject]@{
							Timestamp       = [string]$record.Timestamp
							ComputerName    = if ($record.ComputerName) { [string]$record.ComputerName } else { 'unknown target' }
							Operation       = if ($record.Operation) { [string]$record.Operation } else { 'Remote' }
							Status          = if ($record.Status) { [string]$record.Status } else { 'Unknown' }
							LifecycleState  = if ($record.LifecycleState) { [string]$record.LifecycleState } else { 'Unknown' }
							RunId           = if ($record.RunId) { [string]$record.RunId } else { $null }
							AttemptCount    = if ($record.PSObject.Properties['AttemptCount']) { [int]$record.AttemptCount } else { 1 }
							RetryCount      = if ($record.PSObject.Properties['RetryCount']) { [int]$record.RetryCount } else { 0 }
							SessionState    = if ($record.PSObject.Properties['SessionState']) { [string]$record.SessionState } else { 'Unknown' }
							SessionReused   = if ($record.PSObject.Properties['SessionReused']) { [bool]$record.SessionReused } else { $false }
							Retryable       = if ($record.PSObject.Properties['Retryable']) { [bool]$record.Retryable } else { $false }
							RetryReason     = if ($record.PSObject.Properties['RetryReason']) { [string]$record.RetryReason } else { $null }
							FailureCategory = if ($record.PSObject.Properties['FailureCategory']) { [string]$record.FailureCategory } else { 'Unknown' }
							Errors          = @($errors)
						}
					}
				}
				catch
				{
					$remoteDetails = @()
				}
			}

			if ($remoteDetails.Count -gt 0)
			{
				$remoteDetailsPath = Join-Path $stagingDir 'remote-orchestration-details.json'
				[System.IO.File]::WriteAllText($remoteDetailsPath, ($remoteDetails | ConvertTo-Json -Depth 8), $utf8NoBom)
				$bundleEntries.Add([pscustomobject]@{ Name = 'remote-orchestration-details.json'; Source = $remoteDetailsPath })
				$bundleIndex.Files['RemoteDetails'] = 'remote-orchestration-details.json'
			}
		}

		# --- Connect-to-Computer dialog pre-flight results ---
		# Snapshot of the most recent Test-BaselineRemoteConnectivity output
		# captured by the GUI dialog (Set-GuiRemoteConnectivityResults stores
		# this on $Script:Ctx.Remote.LastConnectivityResults). Distinct from
		# remote-orchestration.jsonl, which only logs actual operations.
		if ($null -ne $ConnectivityResults -and $ConnectivityResults.Count -gt 0)
		{
			$connectivityPayload = [ordered]@{
				Schema        = 'Baseline.RemoteConnectivity'
				SchemaVersion = 1
				CapturedAt    = [System.DateTime]::UtcNow.ToString('o')
				Results       = @($ConnectivityResults)
			}
			$connectivityPath = Join-Path $stagingDir 'remote-connectivity.json'
			[System.IO.File]::WriteAllText($connectivityPath, ($connectivityPayload | ConvertTo-Json -Depth 8), $utf8NoBom)
			$bundleEntries.Add([pscustomobject]@{ Name = 'remote-connectivity.json'; Source = $connectivityPath })
			$bundleIndex.Files['RemoteConnectivity'] = 'remote-connectivity.json'
		}

		if ($deepLinkItems.Count -gt 0)
		{
			$deepLinksPath = Join-Path $stagingDir 'remote-orchestration-deeplinks.json'
			[System.IO.File]::WriteAllText($deepLinksPath, ($deepLinkItems | ConvertTo-Json -Depth 8), $utf8NoBom)
			$bundleEntries.Add([pscustomobject]@{ Name = 'remote-orchestration-deeplinks.json'; Source = $deepLinksPath })
			$bundleIndex.Files['RemoteDeepLinks'] = 'remote-orchestration-deeplinks.json'
			$bundleIndex.DeepLinks = @($deepLinkItems)
		}

		# --- Logs/ directory: daily baseline.log + perf.log ---
		# Both are best-effort. Bundle export must continue if either is locked
		# or missing. perf.log only exists when BASELINE_PERF_LOG=1 (or
		# Debug Mode is on, which force-enables it).
		$logsDir = Join-Path $stagingDir 'Logs'
		$null = New-Item -Path $logsDir -ItemType Directory -Force -ErrorAction SilentlyContinue
		try
		{
			$dailyLogPath = if ($global:LogFilePath) { [string]$global:LogFilePath } else { $null }
			if (-not [string]::IsNullOrWhiteSpace($dailyLogPath) -and (Test-Path -LiteralPath $dailyLogPath))
			{
				$destDailyLogPath = Join-Path $logsDir 'baseline.log'
				try
				{
					Copy-Item -LiteralPath $dailyLogPath -Destination $destDailyLogPath -Force -ErrorAction Stop
				}
				catch
				{
					# File-locked fallback: stream-copy with FileShare.ReadWrite
					$fs = [System.IO.File]::Open($dailyLogPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
					try
					{
						$reader = [System.IO.StreamReader]::new($fs, [System.Text.UTF8Encoding]::new($false))
						try { [System.IO.File]::WriteAllText($destDailyLogPath, $reader.ReadToEnd(), $utf8NoBom) }
						finally { $reader.Dispose() }
					}
					finally { $fs.Dispose() }
				}
				$bundleEntries.Add([pscustomobject]@{ Name = 'Logs/baseline.log'; Source = $destDailyLogPath })
				$bundleIndex.Files['DailyLog'] = 'Logs/baseline.log'
			}
		}
		catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SupportBundle.Assembly.DailyLog' }

		try
		{
			$perfLogPath = Join-Path (Join-Path $env:LOCALAPPDATA 'Baseline') 'perf.log'
			if (Test-Path -LiteralPath $perfLogPath)
			{
				$destPerfLogPath = Join-Path $logsDir 'perf.log'
				Copy-Item -LiteralPath $perfLogPath -Destination $destPerfLogPath -Force -ErrorAction SilentlyContinue
				if (Test-Path -LiteralPath $destPerfLogPath)
				{
					$bundleEntries.Add([pscustomobject]@{ Name = 'Logs/perf.log'; Source = $destPerfLogPath })
					$bundleIndex.Files['PerfLog'] = 'Logs/perf.log'
				}
			}
		}
		catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SupportBundle.Assembly.PerfLog' }

		# --- system-info.json: richer environment context than metadata.json ---
		try
		{
			$systemInfo = New-BaselineSupportBundleSystemInfo
			$systemInfoPath = Join-Path $stagingDir 'system-info.json'
			[System.IO.File]::WriteAllText($systemInfoPath, ($systemInfo | ConvertTo-Json -Depth 8), $utf8NoBom)
			$bundleEntries.Add([pscustomobject]@{ Name = 'system-info.json'; Source = $systemInfoPath })
			$bundleIndex.Files['SystemInfo'] = 'system-info.json'
		}
		catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SupportBundle.Assembly.SystemInfo' }

		# --- execution-summary.json: per-run statistics from the live session ---
		try
		{
			if (Get-Command -Name 'Get-SessionStatistics' -ErrorAction SilentlyContinue)
			{
				$stats = Get-SessionStatistics
				if ($stats)
				{
					$execSummary = [ordered]@{
						Schema        = 'Baseline.ExecutionSummary'
						SchemaVersion = 1
						GeneratedAt   = [System.DateTime]::UtcNow.ToString('o')
						DebugMode     = if (Get-Command -Name 'Get-BaselineDebugLogging' -ErrorAction SilentlyContinue) { [bool](Get-BaselineDebugLogging) } else { $false }
						Statistics    = $stats
					}
					$execSummaryPath = Join-Path $stagingDir 'execution-summary.json'
					[System.IO.File]::WriteAllText($execSummaryPath, ($execSummary | ConvertTo-Json -Depth 8), $utf8NoBom)
					$bundleEntries.Add([pscustomobject]@{ Name = 'execution-summary.json'; Source = $execSummaryPath })
					$bundleIndex.Files['ExecutionSummary'] = 'execution-summary.json'
				}
			}
		}
		catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SupportBundle.Assembly.ExecutionSummary' }

		# --- ConfigState.json: GUI / preset / mode state, before/after a run ---
		# Pre-run state is captured by ExecutionOrchestration.ps1 into
		# $Script:PreRunConfigState; post-run state is the live snapshot at
		# bundle time. If no run has happened this session, only Post is
		# populated and the diff is null. Field selection follows todo.md #14
		# (preset, overrides, Safe Mode, Onboarding, Game Mode, Preview Run).
		try
		{
			if ($null -ne $ConfigStatePre -or $null -ne $ConfigStatePost)
			{
				$configStatePayload = New-BaselineSupportBundleConfigState -PreState $ConfigStatePre -PostState $ConfigStatePost
				if ($configStatePayload)
				{
					$configStatePath = Join-Path $stagingDir 'ConfigState.json'
					[System.IO.File]::WriteAllText($configStatePath, ($configStatePayload | ConvertTo-Json -Depth 10), $utf8NoBom)
					$bundleEntries.Add([pscustomobject]@{ Name = 'ConfigState.json'; Source = $configStatePath })
					$bundleIndex.Files['ConfigState'] = 'ConfigState.json'
				}
			}
		}
		catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SupportBundle.Assembly.ConfigState' }

		# --- RemoteTargets.json: per-target redacted detail ---
		# Sanitized projection of the live remote-target context: hostname only
		# (no FQDN, no domain leak), connection method, state, credential type
		# only (never the secret). Distinct from remote-connectivity.json (which
		# is the dialog's pre-flight test results) and remote-orchestration.jsonl
		# (which is the per-operation history).
		try
		{
			if ($null -ne $RemoteTargets -and $RemoteTargets.Count -gt 0)
			{
				$remoteTargetsPayload = New-BaselineSupportBundleRemoteTargets -Targets $RemoteTargets
				if ($remoteTargetsPayload)
				{
					$remoteTargetsPath = Join-Path $stagingDir 'RemoteTargets.json'
					[System.IO.File]::WriteAllText($remoteTargetsPath, ($remoteTargetsPayload | ConvertTo-Json -Depth 6), $utf8NoBom)
					$bundleEntries.Add([pscustomobject]@{ Name = 'RemoteTargets.json'; Source = $remoteTargetsPath })
					$bundleIndex.Files['RemoteTargets'] = 'RemoteTargets.json'
				}
			}
		}
		catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SupportBundle.Assembly.RemoteTargets' }

		# --- errors.json: classified errors scraped from the daily log ---
		try
		{
			$dailyLogPath = if ($global:LogFilePath) { [string]$global:LogFilePath } else { $null }
			if (-not [string]::IsNullOrWhiteSpace($dailyLogPath) -and (Test-Path -LiteralPath $dailyLogPath))
			{
				$classified = Get-BaselineSupportBundleClassifiedErrors -LogPath $dailyLogPath -MaxErrors 200
				if ($classified -and $classified.Errors.Count -gt 0)
				{
					$errorsPath = Join-Path $stagingDir 'errors.json'
					[System.IO.File]::WriteAllText($errorsPath, ($classified | ConvertTo-Json -Depth 6), $utf8NoBom)
					$bundleEntries.Add([pscustomobject]@{ Name = 'errors.json'; Source = $errorsPath })
					$bundleIndex.Files['Errors'] = 'errors.json'
				}
			}
		}
		catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SupportBundle.Assembly.Errors' }

		$bundleIndexPath = Join-Path $stagingDir 'bundle-index.json'
		[System.IO.File]::WriteAllText($bundleIndexPath, ($bundleIndex | ConvertTo-Json -Depth 8), $utf8NoBom)
		$bundleEntries.Add([pscustomobject]@{ Name = 'bundle-index.json'; Source = $bundleIndexPath })

		if (-not [string]::IsNullOrWhiteSpace($ProfilePath) -and (Test-Path -LiteralPath $ProfilePath))
		{
			$destProfilePath = Join-Path $stagingDir (Split-Path -Path $ProfilePath -Leaf)
			Copy-Item -LiteralPath $ProfilePath -Destination $destProfilePath -Force
			$bundleEntries.Add([pscustomobject]@{ Name = (Split-Path -Path $ProfilePath -Leaf); Source = $destProfilePath })
		}

		if ($null -eq $SystemSnapshot -and $Manifest)
		{
			try
			{
				$SystemSnapshot = New-SystemStateSnapshot -Manifest $Manifest
			}
			catch
			{
				$SystemSnapshot = $null
			}
		}

		if ($null -ne $SystemSnapshot)
		{
			$snapshotPath = Join-Path $stagingDir 'system-state-snapshot.json'
			Export-SystemStateSnapshot -Snapshot $SystemSnapshot -Path $snapshotPath
			$bundleEntries.Add([pscustomobject]@{ Name = 'system-state-snapshot.json'; Source = $snapshotPath })
		}

		# --- SnapshotDiff.json: pre/post field-level diff ---
		# Catches unintended side-effects from a run and verifies rollback
		# completeness. Emits the snapshot pair plus the diff. If only one
		# side is supplied, that side is still embedded so a maintainer can
		# eyeball the captured state without the diff.
		if ($null -ne $PreSnapshot -or $null -ne $PostSnapshot)
		{
			try
			{
				$diff = $null
				if ($null -ne $PreSnapshot -and $null -ne $PostSnapshot -and (Get-Command -Name 'Compare-SystemStateSnapshots' -ErrorAction SilentlyContinue))
				{
					try { $diff = Compare-SystemStateSnapshots -Before $PreSnapshot -After $PostSnapshot } catch { $diff = $null }
				}

				$snapshotDiffPayload = [ordered]@{
					Schema        = 'Baseline.SnapshotDiff'
					SchemaVersion = 1
					GeneratedAt   = [System.DateTime]::UtcNow.ToString('o')
					HasPre        = ($null -ne $PreSnapshot)
					HasPost       = ($null -ne $PostSnapshot)
					Pre           = $PreSnapshot
					Post          = $PostSnapshot
					Diff          = if ($diff) {
						[ordered]@{
							AddedCount     = @($diff.Added).Count
							RemovedCount   = @($diff.Removed).Count
							ChangedCount   = @($diff.Changed).Count
							UnchangedCount = @($diff.Unchanged).Count
							Added          = @($diff.Added)
							Removed        = @($diff.Removed)
							Changed        = @($diff.Changed)
						}
					} else { $null }
				}

				$snapshotDiffPath = Join-Path $stagingDir 'SnapshotDiff.json'
				[System.IO.File]::WriteAllText($snapshotDiffPath, ($snapshotDiffPayload | ConvertTo-Json -Depth 10), $utf8NoBom)
				$bundleEntries.Add([pscustomobject]@{ Name = 'SnapshotDiff.json'; Source = $snapshotDiffPath })
				# bundle-index.json is already written by this point; SnapshotDiff
				# lands in contents.json (which is rewritten after every entry)
				# alongside the other optional artifacts (system-state-snapshot,
				# compliance-report, preflight-report).
			}
			catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SupportBundle.Assembly.SnapshotDiff' }
		}

		if ($null -ne $ComplianceReport)
		{
			$compliancePath = Join-Path $stagingDir 'compliance-report.json'
			Export-ComplianceReport -Report $ComplianceReport -FilePath $compliancePath -Format Json
			$bundleEntries.Add([pscustomobject]@{ Name = 'compliance-report.json'; Source = $compliancePath })
		}

		$preflightCommand = Get-Command -Name 'Invoke-PreflightChecks' -ErrorAction SilentlyContinue
		if ($preflightCommand)
		{
			try
			{
				$preflightReport = & $preflightCommand
				if ($null -ne $preflightReport)
				{
					$preflightPath = Join-Path $stagingDir 'preflight-report.json'
					[System.IO.File]::WriteAllText($preflightPath, ($preflightReport | ConvertTo-Json -Depth 8), $utf8NoBom)
					$bundleEntries.Add([pscustomobject]@{ Name = 'preflight-report.json'; Source = $preflightPath })
				}
			}
			catch
			{
				# Preflight capture is best-effort and should not block bundle creation.
			}
		}

		if ($IncludeTestReport)
		{
			$testReportPath = Join-Path $Script:SharedHelpersRepoRoot 'Tests\TestReport.json'
			if (Test-Path -LiteralPath $testReportPath)
			{
				$destTestReportPath = Join-Path $stagingDir 'test-report.json'
				Copy-Item -LiteralPath $testReportPath -Destination $destTestReportPath -Force
				$bundleEntries.Add([pscustomobject]@{ Name = 'test-report.json'; Source = $destTestReportPath })
			}
		}

		$contentsPath = Join-Path $stagingDir 'contents.json'
		$contents = [ordered]@{
			Files = @($bundleEntries)
		}
		[System.IO.File]::WriteAllText($contentsPath, ($contents | ConvertTo-Json -Depth 6), $utf8NoBom)

		# Generate integrity manifest for immutable/signoff bundles
		$integrityManifest = $null
		if ($Immutable)
		{
			$fileChecksums = [System.Collections.Generic.List[pscustomobject]]::new()
			foreach ($entry in $bundleEntries)
			{
				if (Test-Path -LiteralPath $entry.Source)
				{
					try
					{
						$hash = Get-FileHash -LiteralPath $entry.Source -Algorithm SHA256
						$fileChecksums.Add([pscustomobject]@{
							FileName  = $entry.Name
							SHA256    = $hash.Hash
							Size      = (Get-Item -LiteralPath $entry.Source).Length
						})
					}
					catch
					{
						$fileChecksums.Add([pscustomobject]@{
							FileName  = $entry.Name
							SHA256    = 'CHECKSUM_ERROR'
							Size      = 0
							Error     = $_.Exception.Message
						})
					}
				}
			}

			# Add contents.json to the checksum list
			try
			{
				$contentsHash = Get-FileHash -LiteralPath $contentsPath -Algorithm SHA256
				$fileChecksums.Add([pscustomobject]@{
					FileName  = 'contents.json'
					SHA256    = $contentsHash.Hash
					Size      = (Get-Item -LiteralPath $contentsPath).Length
				})
			}
			catch
			{
				$fileChecksums.Add([pscustomobject]@{
					FileName  = 'contents.json'
					SHA256    = 'CHECKSUM_ERROR'
					Size      = 0
					Error     = $_.Exception.Message
				})
			}

			$integrityManifest = [ordered]@{
				Schema         = 'Baseline.IntegrityManifest'
				SchemaVersion  = 1
				GeneratedAt    = [System.DateTime]::UtcNow.ToString('o')
				BundleType     = 'SignoffBundle'
				Immutable      = $true
				Provenance     = [ordered]@{
					Reason     = if (-not [string]::IsNullOrWhiteSpace($SignoffReason)) { $SignoffReason } else { 'Enterprise signoff bundle' }
					SignedBy   = $env:USERNAME
					SignedOn   = $env:COMPUTERNAME
					SignedAt   = [System.DateTime]::UtcNow.ToString('o')
					Domain     = $env:USERDOMAIN
				}
				FileCount      = $fileChecksums.Count
				Files          = @($fileChecksums)
				Verification   = [ordered]@{
					Algorithm  = 'SHA256'
					Instruction = 'To verify integrity: extract bundle, recompute SHA256 for each file, compare against this manifest.'
				}
			}

			$integrityManifestPath = Join-Path $stagingDir 'integrity-manifest.json'
			[System.IO.File]::WriteAllText($integrityManifestPath, ($integrityManifest | ConvertTo-Json -Depth 8), $utf8NoBom)
			$bundleEntries.Add([pscustomobject]@{ Name = 'integrity-manifest.json'; Source = $integrityManifestPath })
			$bundleIndex.Files['IntegrityManifest'] = 'integrity-manifest.json'

			# Set read-only attributes on all staged files for immutable bundles
			Get-ChildItem -LiteralPath $stagingDir -File | ForEach-Object {
				$_.Attributes = $_.Attributes -bor [System.IO.FileAttributes]::ReadOnly
			}
		}

		if (Test-Path -LiteralPath $OutputPath)
		{
			Remove-Item -LiteralPath $OutputPath -Force -ErrorAction SilentlyContinue
		}

		Compress-Archive -Path (Join-Path $stagingDir '*') -DestinationPath $OutputPath -Force

		# Set read-only on the ZIP file itself for immutable bundles
		if ($Immutable -and (Test-Path -LiteralPath $OutputPath))
		{
			$zipItem = Get-Item -LiteralPath $OutputPath
			$zipItem.Attributes = $zipItem.Attributes -bor [System.IO.FileAttributes]::ReadOnly
		}

		return [pscustomobject]@{
			OutputPath        = $OutputPath
			FileCount         = $bundleEntries.Count + 2
			BundleFiles       = @($bundleEntries)
			Immutable         = [bool]$Immutable
			IntegrityManifest = $integrityManifest
		}
	}
	finally
	{
		if (Test-Path -LiteralPath $tempRoot)
		{
			Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
		}
	}
}

<#
    .SYNOPSIS
    Internal function Test-BaselineSupportBundleIntegrity.

    .DESCRIPTION
    Verifies the integrity of an immutable/signoff support bundle by checking
    SHA256 checksums against the embedded integrity manifest.
#>

function Test-BaselineSupportBundleIntegrity
{
	<#
		.SYNOPSIS
		Verifies the integrity of an immutable Baseline support bundle.

		.DESCRIPTION
		Extracts the bundle temporarily, reads the integrity manifest, and
		verifies SHA256 checksums for all tracked files.

		.OUTPUTS
		PSCustomObject with:
		- Valid: $true if all checksums match
		- Immutable: $true if the bundle contains an integrity manifest
		- FilesChecked: Number of files verified
		- FilesPassed: Number of files with matching checksums
		- FilesFailed: Number of files with mismatched checksums
		- Failures: Array of files that failed verification
		- Provenance: Signoff provenance information from the manifest
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$BundlePath
	)

	if (-not (Test-Path -LiteralPath $BundlePath))
	{
		throw "Bundle not found: $BundlePath"
	}

	$result = [ordered]@{
		BundlePath    = $BundlePath
		Valid         = $false
		Immutable     = $false
		FilesChecked  = 0
		FilesPassed   = 0
		FilesFailed   = 0
		Failures      = @()
		Provenance    = $null
		VerifiedAt    = (Get-Date).ToString('o')
	}

	$tempExtract = Join-Path ([System.IO.Path]::GetTempPath()) ('BundleVerify_{0}' -f [guid]::NewGuid().ToString('N'))

	try
	{
		$null = New-Item -Path $tempExtract -ItemType Directory -Force
		Expand-Archive -LiteralPath $BundlePath -DestinationPath $tempExtract -Force

		$manifestPath = Join-Path $tempExtract 'integrity-manifest.json'
		if (-not (Test-Path -LiteralPath $manifestPath))
		{
			$result.Immutable = $false
			$result.Valid = $null  # Cannot verify non-immutable bundles
			return [pscustomobject]$result
		}

		$result.Immutable = $true

		$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-BaselineJson -Depth 16

		if ($manifest.Provenance)
		{
			$result.Provenance = $manifest.Provenance
		}

		$failures = [System.Collections.Generic.List[pscustomobject]]::new()

		foreach ($fileEntry in $manifest.Files)
		{
			$filePath = Join-Path $tempExtract $fileEntry.FileName
			$result.FilesChecked++

			if (-not (Test-Path -LiteralPath $filePath))
			{
				$failures.Add([pscustomobject]@{
					FileName   = $fileEntry.FileName
					Expected   = $fileEntry.SHA256
					Actual     = 'FILE_MISSING'
					Status     = 'Missing'
				})
				continue
			}

			try
			{
				$actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash

				if ($actualHash -eq $fileEntry.SHA256)
				{
					$result.FilesPassed++
				}
				else
				{
					$failures.Add([pscustomobject]@{
						FileName   = $fileEntry.FileName
						Expected   = $fileEntry.SHA256
						Actual     = $actualHash
						Status     = 'Mismatch'
					})
				}
			}
			catch
			{
				$failures.Add([pscustomobject]@{
					FileName   = $fileEntry.FileName
					Expected   = $fileEntry.SHA256
					Actual     = 'HASH_ERROR'
					Status     = 'Error'
					Error      = $_.Exception.Message
				})
			}
		}

		$result.FilesFailed = $failures.Count
		$result.Failures = @($failures)
		$result.Valid = ($failures.Count -eq 0)

		return [pscustomobject]$result
	}
	finally
	{
		if (Test-Path -LiteralPath $tempExtract)
		{
			# Remove read-only attributes before cleanup
			Get-ChildItem -LiteralPath $tempExtract -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
				$_.Attributes = $_.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
			}
			Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
		}
	}
}

<#
	.SYNOPSIS
	Build the ConfigState.json payload for a support bundle.

	.DESCRIPTION
	Projects the GUI session snapshot (whatever Get-GuiSettingsSnapshot
	returns) down to the field set called for in todo.md #14: preset,
	user overrides, Safe Mode, Onboarding mode, Game Mode profile, and
	the most recent Preview Run output. Both Pre and Post are accepted;
	either may be null. When both are present a shallow per-key Diff is
	emitted so a maintainer can see exactly what flipped between the
	two states without re-deriving it.
#>
function New-BaselineSupportBundleConfigState
{
	[CmdletBinding()]
	param (
		[object]$PreState,
		[object]$PostState
	)

	$projection = {
		param($state)
		if ($null -eq $state) { return $null }
		$props = $state.PSObject.Properties
		$pick = {
			param($name)
			if ($props[$name]) { return $state.$name }
			return $null
		}
		[ordered]@{
			Preset                    = & $pick 'SelectedPreset'
			Theme                     = & $pick 'Theme'
			Language                  = & $pick 'Language'
			SafeMode                  = & $pick 'SafeMode'
			AdvancedMode              = & $pick 'AdvancedMode'
			GameMode                  = & $pick 'GameMode'
			GameModeProfile           = & $pick 'GameModeProfile'
			GameModeDecisionOverrides = & $pick 'GameModeDecisionOverrides'
			OnboardingMode            = & $pick 'DefaultStartupMode'
			RestoreLastSession        = & $pick 'RestoreLastSession'
			RequireRunConfirmation    = & $pick 'RequireRunConfirmation'
			PreviewBeforeRunDefault   = & $pick 'PreviewBeforeRunDefault'
			LastPreviewRunOutput      = & $pick 'LastPreviewRunOutput'
			AppsQueuedActions         = & $pick 'AppsQueuedActions'
			LoggingEnabled            = & $pick 'LoggingEnabled'
			LogLevel                  = & $pick 'LogLevel'
			DebugLoggingEnabled       = & $pick 'DebugLoggingEnabled'
			RiskFilter                = & $pick 'RiskFilter'
			CategoryFilter            = & $pick 'CategoryFilter'
		}
	}

	$pre  = & $projection $PreState
	$post = & $projection $PostState

	$diff = $null
	if ($null -ne $pre -and $null -ne $post)
	{
		$changed = [System.Collections.Generic.List[pscustomobject]]::new()
		foreach ($key in $post.Keys)
		{
			$preVal  = if ($pre.Contains($key))  { $pre[$key]  } else { $null }
			$postVal = $post[$key]
			$preJson  = try { ConvertTo-Json -InputObject $preVal  -Depth 4 -Compress } catch { [string]$preVal }
			$postJson = try { ConvertTo-Json -InputObject $postVal -Depth 4 -Compress } catch { [string]$postVal }
			if ($preJson -ne $postJson)
			{
				[void]$changed.Add([pscustomobject]@{
					Key  = [string]$key
					Pre  = $preVal
					Post = $postVal
				})
			}
		}
		$diff = [ordered]@{
			ChangedCount = $changed.Count
			Changed      = @($changed)
		}
	}

	return [pscustomobject][ordered]@{
		Schema        = 'Baseline.ConfigState'
		SchemaVersion = 1
		GeneratedAt   = [System.DateTime]::UtcNow.ToString('o')
		HasPre        = ($null -ne $pre)
		HasPost       = ($null -ne $post)
		Pre           = $pre
		Post          = $post
		Diff          = $diff
	}
}

<#
	.SYNOPSIS
	Build the RemoteTargets.json payload for a support bundle.

	.DESCRIPTION
	Sanitized projection of the live remote target context. Each target is
	emitted as { TargetName, ConnectionMethod, State, CredentialType }.
	Hostname leakage is bounded — anything past the first dot is dropped so
	we keep "PC01" rather than shipping "PC01.corp.contoso.com". Credential
	values are never serialized: only the *type* (NTLM / Kerberos / Cert /
	None) lands in the bundle.
#>
function New-BaselineSupportBundleRemoteTargets
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[AllowEmptyCollection()]
		[object[]]$Targets
	)

	$out = [System.Collections.Generic.List[pscustomobject]]::new()
	foreach ($t in $Targets)
	{
		if ($null -eq $t) { continue }
		$props = $t.PSObject.Properties

		$rawName = if ($props['ComputerName']) { [string]$t.ComputerName } elseif ($props['TargetName']) { [string]$t.TargetName } else { $null }
		$shortName = $null
		if (-not [string]::IsNullOrWhiteSpace($rawName))
		{
			# Strip FQDN tail to avoid leaking the org's domain into the bundle.
			$shortName = ($rawName -split '\.', 2)[0]
		}

		$method = if ($props['ConnectionMethod']) { [string]$t.ConnectionMethod } elseif ($props['Method']) { [string]$t.Method } else { 'WinRM' }

		$state = $null
		if ($props['State']) { $state = [string]$t.State }
		elseif ($props['Status']) { $state = [string]$t.Status }
		elseif ($props['Reachable']) { $state = if ([bool]$t.Reachable) { 'Connected' } else { 'Failed' } }

		$credType = $null
		if ($props['CredentialType']) { $credType = [string]$t.CredentialType }
		elseif ($props['Credential'])
		{
			# Best-effort inference — UPN looks like Kerberos territory,
			# DOMAIN\user looks like NTLM. Never serialize the credential.
			$cred = $t.Credential
			if ($cred -and $cred.UserName)
			{
				$user = [string]$cred.UserName
				if ($user -match '@')      { $credType = 'Kerberos' }
				elseif ($user -match '\\') { $credType = 'NTLM' }
				else                       { $credType = 'Default' }
			}
			else { $credType = 'None' }
		}
		else { $credType = 'CurrentUser' }

		[void]$out.Add([pscustomobject][ordered]@{
			TargetName       = $shortName
			ConnectionMethod = $method
			State            = $state
			CredentialType   = $credType
		})
	}

	return [pscustomobject][ordered]@{
		Schema        = 'Baseline.RemoteTargets'
		SchemaVersion = 1
		GeneratedAt   = [System.DateTime]::UtcNow.ToString('o')
		Targets       = @($out)
	}
}

<#
	.SYNOPSIS
	Build a richer system info snapshot for support bundles.

	.DESCRIPTION
	Captures OS / SKU / arch / domain join / elevation / WinRM / Defender state /
	GPO summary / package counts. All probes are best-effort — a single failure
	never aborts the snapshot. Sensitive values (domain name, full GPO output,
	signature lists) are deliberately omitted.
#>
function New-BaselineSupportBundleSystemInfo
{
	$info = [ordered]@{
		Schema        = 'Baseline.SystemInfo'
		SchemaVersion = 1
		GeneratedAt   = [System.DateTime]::UtcNow.ToString('o')
	}

	try
	{
		$os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
		$info['OS'] = [ordered]@{
			Caption       = [string]$os.Caption
			Version       = [string]$os.Version
			BuildNumber   = [string]$os.BuildNumber
			Architecture  = [string]$os.OSArchitecture
			InstallDate   = if ($os.InstallDate) { [datetime]$os.InstallDate | ForEach-Object { $_.ToUniversalTime().ToString('o') } } else { $null }
			LastBootUpTime = if ($os.LastBootUpTime) { [datetime]$os.LastBootUpTime | ForEach-Object { $_.ToUniversalTime().ToString('o') } } else { $null }
		}
	}
	catch
	{
		$info['OS'] = [ordered]@{
			Caption      = [string][System.Environment]::OSVersion.VersionString
			Version      = [string][System.Environment]::OSVersion.Version
			Architecture = if ([System.Environment]::Is64BitOperatingSystem) { '64-bit' } else { '32-bit' }
		}
	}

	try
	{
		$sku = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name EditionID -ErrorAction Stop).EditionID
		$info['SKU'] = [string]$sku
	}
	catch { $info['SKU'] = $null }

	try
	{
		$cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
		$info['DomainJoined'] = [bool]$cs.PartOfDomain
		$info['SystemType']   = [string]$cs.SystemType
	}
	catch
	{
		$info['DomainJoined'] = $null
		$info['SystemType']   = $null
	}

	try
	{
		$current = [System.Security.Principal.WindowsIdentity]::GetCurrent()
		$principal = [System.Security.Principal.WindowsPrincipal]::new($current)
		$info['Elevated'] = [bool]$principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
	}
	catch { $info['Elevated'] = $null }

	$info['PowerShell'] = [ordered]@{
		Edition = [string]$PSVersionTable.PSEdition
		Version = [string]$PSVersionTable.PSVersion
	}

	try
	{
		$winrm = Get-Service -Name WinRM -ErrorAction Stop
		$info['WinRM'] = [ordered]@{
			Status    = [string]$winrm.Status
			StartType = [string]$winrm.StartType
		}
	}
	catch { $info['WinRM'] = $null }

	try
	{
		if (Get-Command -Name 'Get-MpPreference' -ErrorAction SilentlyContinue)
		{
			$mp = Get-MpPreference -ErrorAction Stop
			$info['Defender'] = [ordered]@{
				DisableRealtimeMonitoring = [bool]$mp.DisableRealtimeMonitoring
				DisableBehaviorMonitoring = [bool]$mp.DisableBehaviorMonitoring
				DisableScriptScanning     = [bool]$mp.DisableScriptScanning
				PUAProtection             = [string]$mp.PUAProtection
				MAPSReporting             = [string]$mp.MAPSReporting
			}
		}
		else { $info['Defender'] = $null }
	}
	catch { $info['Defender'] = $null }

	try
	{
		# gpresult /r outputs a long human-readable report; capture only that
		# the user has GPO scope at all, not the full content.
		$gpResult = & gpresult /r /scope:computer 2>$null | Select-Object -First 60
		$info['GPO'] = [ordered]@{
			Available = ($LASTEXITCODE -eq 0)
			LineCount = if ($gpResult) { ([string[]]$gpResult).Count } else { 0 }
		}
	}
	catch { $info['GPO'] = [ordered]@{ Available = $false; LineCount = 0 } }

	$pkgCounts = [ordered]@{}
	try
	{
		if (Get-Command -Name 'winget' -ErrorAction SilentlyContinue)
		{
			$wingetLines = & winget list --accept-source-agreements 2>$null
			# winget list emits a header + separator + entries; subtract them.
			$pkgCounts['Winget'] = [Math]::Max(0, ([string[]]$wingetLines).Count - 2)
		}
	}
	catch { $pkgCounts['Winget'] = $null }
	try
	{
		if (Get-Command -Name 'choco' -ErrorAction SilentlyContinue)
		{
			$chocoLines = & choco list --local-only --limit-output 2>$null
			$pkgCounts['Chocolatey'] = ([string[]]$chocoLines).Count
		}
	}
	catch { $pkgCounts['Chocolatey'] = $null }
	$info['PackageCounts'] = $pkgCounts

	# VM detection — best-effort via CIM Manufacturer/Model.
	try
	{
		$cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
		$model = ([string]$cs.Model).ToLowerInvariant()
		$mfg = ([string]$cs.Manufacturer).ToLowerInvariant()
		$hypervisor = $null
		if ($mfg -match 'microsoft' -and $model -match 'virtual') { $hypervisor = 'Hyper-V' }
		elseif ($mfg -match 'vmware') { $hypervisor = 'VMware' }
		elseif ($mfg -match 'parallels') { $hypervisor = 'Parallels' }
		elseif ($model -match 'virtualbox') { $hypervisor = 'VirtualBox' }
		elseif ($model -match 'kvm|qemu') { $hypervisor = 'KVM/QEMU' }
		$info['Virtualization'] = [ordered]@{
			IsVM       = ($null -ne $hypervisor)
			Hypervisor = $hypervisor
		}
	}
	catch { $info['Virtualization'] = $null }

	return [pscustomobject]$info
}

<#
	.SYNOPSIS
	Scrape recent ERROR / WARNING entries from the daily log and classify them.

	.DESCRIPTION
	Lightweight pattern classifier — categories match the Errors.json contract
	in todo.md (#14): AUTH / NETWORK / POLICY / DEPENDENCY / UNKNOWN. Pure-text
	matching against the Exception.Message tail of the log line — no parsing,
	no PowerShell ErrorRecord reconstruction.
#>
function Get-BaselineSupportBundleClassifiedErrors
{
	param (
		[Parameter(Mandatory = $true)][string]$LogPath,
		[int]$MaxErrors = 200
	)

	if (-not (Test-Path -LiteralPath $LogPath)) { return $null }

	$lines = $null
	try
	{
		# Use FileShare.ReadWrite so a live writer doesn't block us.
		$fs = [System.IO.File]::Open($LogPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
		try
		{
			$reader = [System.IO.StreamReader]::new($fs, [System.Text.UTF8Encoding]::new($false))
			try { $lines = $reader.ReadToEnd() -split "`r?`n" }
			finally { $reader.Dispose() }
		}
		finally { $fs.Dispose() }
	}
	catch { return $null }

	$classified = [System.Collections.Generic.List[pscustomobject]]::new()
	$counts = [ordered]@{ AUTH = 0; NETWORK = 0; POLICY = 0; DEPENDENCY = 0; UNKNOWN = 0 }

	foreach ($line in $lines)
	{
		if ([string]::IsNullOrWhiteSpace($line)) { continue }
		# Match the LogMessage format: "dd-MM-yyyy HH:mm LEVEL: ..."
		if ($line -notmatch '\b(ERROR|WARNING)\b') { continue }
		if ($classified.Count -ge $MaxErrors) { break }

		$msg = $line.ToLowerInvariant()
		$category = 'UNKNOWN'
		if ($msg -match 'access\s+denied|unauthor|requires?\s+administrator|elevation|elevated|hresult: 0x80070005|0x80004003') { $category = 'AUTH' }
		elseif ($msg -match 'network|wininet|dns|proxy|connection\s+(refused|reset|timed)|host\s+(unreachable|not\s+found)|wsaeconnaborted|0x800705b4|timed?\s*out') { $category = 'NETWORK' }
		elseif ($msg -match 'group\s+policy|gpo\b|policy\s+(restricted|prevents)|disabled\s+by\s+(your\s+)?administrator|managed\s+by\s+your\s+organization') { $category = 'POLICY' }
		elseif ($msg -match 'not\s+found|missing|cannot\s+find|no\s+such\s+file|service\s+(not\s+installed|missing)|cmdletnot|commandnot|cannot\s+load|module\s+not\s+found') { $category = 'DEPENDENCY' }

		$counts[$category]++
		[void]$classified.Add([pscustomobject]@{
			Category = $category
			Line     = $line
		})
	}

	return [pscustomobject][ordered]@{
		Schema        = 'Baseline.ClassifiedErrors'
		SchemaVersion = 1
		GeneratedAt   = [System.DateTime]::UtcNow.ToString('o')
		Source        = $LogPath
		Counts        = $counts
		Errors        = @($classified)
	}
}
