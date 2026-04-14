# Support bundle helper slice for Baseline.
# Builds a portable, operator-facing archive with environment, audit,
# compliance, and execution context for troubleshooting and enterprise review.

<#
    .SYNOPSIS
    Internal function Export-BaselineSupportBundle.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

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
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$OutputPath,

		[string]$ProfilePath,

		[object]$ComplianceReport,

		[object]$SystemSnapshot,

		[array]$Manifest,

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

	try
	{
		$null = New-Item -Path $stagingDir -ItemType Directory -Force

		$baselineVersion = $null
		if (Get-Command -Name 'Get-BaselineDisplayVersion' -ErrorAction SilentlyContinue)
		{
			try { $baselineVersion = Get-BaselineDisplayVersion } catch { $baselineVersion = $null }
		}

		$metadata = [ordered]@{
			Schema          = 'Baseline.SupportBundle'
			SchemaVersion   = 1
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
							$record = $line | ConvertFrom-Json -ErrorAction Stop
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
							$record = $line | ConvertFrom-Json -ErrorAction Stop
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

		if (Test-Path -LiteralPath $OutputPath)
		{
			Remove-Item -LiteralPath $OutputPath -Force -ErrorAction SilentlyContinue
		}

		Compress-Archive -Path (Join-Path $stagingDir '*') -DestinationPath $OutputPath -Force

		return [pscustomobject]@{
			OutputPath  = $OutputPath
			FileCount   = $bundleEntries.Count + 2
			BundleFiles = @($bundleEntries)
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
