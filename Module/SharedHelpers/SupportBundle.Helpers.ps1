# Support bundle helper slice for Baseline.
# Builds a portable, operator-facing archive with environment, audit,
# compliance, and execution context for troubleshooting and enterprise review.

<#
    .SYNOPSIS
    Internal function Export-BaselineSupportBundle.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
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

		[object]$SystemSnapshot,

		[array]$Manifest,

		[string[]]$DeepLinkRunId,

		[string[]]$DeepLinkComputerName,

		[string[]]$DeepLinkOperation,

		[switch]$IncludeAuditLog = $true,

		[int]$AuditRetentionDays = $(try { Get-BaselineAuditRetentionDays } catch { 90 }),

		[switch]$IncludeTestReport = $true
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

		$metadata = [ordered]@{
			Schema          = 'Baseline.SupportBundle'
			SchemaVersion   = 2
			GeneratedAt     = [System.DateTime]::UtcNow.ToString('o')
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
			Immutable       = [bool]$Immutable
			SignoffBundle   = [bool]$Immutable
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

		if ($deepLinkItems.Count -gt 0)
		{
			$deepLinksPath = Join-Path $stagingDir 'remote-orchestration-deeplinks.json'
			[System.IO.File]::WriteAllText($deepLinksPath, ($deepLinkItems | ConvertTo-Json -Depth 8), $utf8NoBom)
			$bundleEntries.Add([pscustomobject]@{ Name = 'remote-orchestration-deeplinks.json'; Source = $deepLinksPath })
			$bundleIndex.Files['RemoteDeepLinks'] = 'remote-orchestration-deeplinks.json'
			$bundleIndex.DeepLinks = @($deepLinkItems)
		}

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
