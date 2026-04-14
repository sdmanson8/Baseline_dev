# Lifecycle helper slice for Baseline.
# Provides release lifecycle playbooks, rollback execution, and incident
# reproduction pack generation from existing Baseline artifacts.

<#
    .SYNOPSIS
    Internal function Get-BaselineLifecycleComparableVersion.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-BaselineLifecycleComparableVersion
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$VersionText
	)

	$text = ([string]$VersionText).Trim()
	if ([string]::IsNullOrWhiteSpace($text))
	{
		return $null
	}

	if (Get-Command -Name 'ConvertTo-NormalizedVersion' -ErrorAction SilentlyContinue)
	{
		try
		{
			return ConvertTo-NormalizedVersion -Version $text
		}
		catch
		{
			# Fall through to the local parser below.
		}
	}

	$normalizedText = $text.TrimStart('v')
	$normalizedText = $normalizedText.Split('(')[0].Trim()
	$normalizedText = $normalizedText.Split('-')[0].Trim()

	$parsedVersion = $null
	if ([version]::TryParse($normalizedText, [ref]$parsedVersion))
	{
		return $parsedVersion
	}

	return $normalizedText
}

<#
    .SYNOPSIS
    Internal function Import-BaselineRollbackProfile.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Import-BaselineRollbackProfile
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$Path
	)

	if (-not (Test-Path -LiteralPath $Path -PathType Leaf))
	{
		throw "Rollback profile not found: $Path"
	}

	$document = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
	$entries = @()
	if ($document.PSObject.Properties['Entries'])
	{
		$entries = @($document.Entries)
	}
	elseif ($document.PSObject.Properties['Commands'])
	{
		$entries = @($document.Commands)
	}

	$commands = @(
		$entries |
			ForEach-Object { [string]$_ } |
			Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
	)

	[pscustomobject]@{
		Path         = (Resolve-Path -LiteralPath $Path).Path
		Schema       = if ($document.PSObject.Properties['Schema']) { [string]$document.Schema } else { 'Baseline.RollbackProfile' }
		SchemaVersion = if ($document.PSObject.Properties['SchemaVersion']) { [int]$document.SchemaVersion } else { 1 }
		Name         = if ($document.PSObject.Properties['Name']) { [string]$document.Name } else { [System.IO.Path]::GetFileNameWithoutExtension($Path) }
		SourceMode   = if ($document.PSObject.Properties['SourceMode']) { [string]$document.SourceMode } else { $null }
		Commands     = $commands
		CommandCount = $commands.Count
		ExportedAt   = if ($document.PSObject.Properties['ExportedAt']) { [string]$document.ExportedAt } else { $null }
	}
}

<#
    .SYNOPSIS
    Internal function New-BaselineLifecyclePlaybook.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function New-BaselineLifecyclePlaybook
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[ValidateSet('Upgrade', 'Downgrade', 'Rollback')]
		[string]$Operation,

		[string]$CurrentVersion,
		[string]$TargetVersion,
		[string]$InstallerPath,
		[string]$RollbackProfilePath,
		[string]$BaselineExecutablePath
	)

	if ([string]::IsNullOrWhiteSpace($CurrentVersion))
	{
		try { $CurrentVersion = Get-BaselineDisplayVersion } catch { $CurrentVersion = $null }
	}

	$targetVersionText = $TargetVersion
	if ([string]::IsNullOrWhiteSpace($targetVersionText) -and -not [string]::IsNullOrWhiteSpace($InstallerPath))
	{
		$leaf = [System.IO.Path]::GetFileNameWithoutExtension($InstallerPath)
		$match = [regex]::Match($leaf, '^Baseline-(?:setup-|portable-)?(?<Version>.+)$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
		if ($match.Success)
		{
			$targetVersionText = [string]$match.Groups['Version'].Value
		}
	}

	$commands = @()
	$rollbackProfile = $null
	if ($Operation -eq 'Rollback')
	{
		if ([string]::IsNullOrWhiteSpace($RollbackProfilePath))
		{
			throw 'RollbackProfilePath is required when Operation is Rollback.'
		}

		$rollbackProfile = Import-BaselineRollbackProfile -Path $RollbackProfilePath
		$commands = @($rollbackProfile.Commands)
		if ($commands.Count -eq 0)
		{
			throw "Rollback profile '$RollbackProfilePath' does not contain any rollback commands."
		}
	}

	$currentComparable = if ([string]::IsNullOrWhiteSpace($CurrentVersion)) { $null } else { Get-BaselineLifecycleComparableVersion -VersionText $CurrentVersion }
	$targetComparable = if ([string]::IsNullOrWhiteSpace($targetVersionText)) { $null } else { Get-BaselineLifecycleComparableVersion -VersionText $targetVersionText }

	$direction = switch ($Operation)
	{
		'Upgrade' {
			if ($currentComparable -and $targetComparable -and $targetComparable -lt $currentComparable) { 'Downgrade' } else { 'Upgrade' }
			break
		}
		'Downgrade' {
			if ($currentComparable -and $targetComparable -and $targetComparable -gt $currentComparable) { 'Upgrade' } else { 'Downgrade' }
			break
		}
		default { 'Rollback' }
	}

	$steps = [System.Collections.Generic.List[string]]::new()
	switch ($Operation)
	{
		'Upgrade' {
			[void]$steps.Add('Verify the installer signature and release provenance.')
			[void]$steps.Add('Export a support bundle and keep the current configuration profile.')
			[void]$steps.Add('Run the installer silently and wait for completion.')
			[void]$steps.Add('Reopen Baseline and confirm the installed version.')
		}
		'Downgrade' {
			[void]$steps.Add('Verify the older installer signature and release provenance.')
			[void]$steps.Add('Export a support bundle and keep the current configuration profile.')
			[void]$steps.Add('Run the older installer silently and wait for completion.')
			[void]$steps.Add('Reopen Baseline and confirm the installed version rolled back.')
		}
		'Rollback' {
			[void]$steps.Add('Review the rollback profile and confirm the target commands.')
			[void]$steps.Add('Export a support bundle before applying the rollback profile.')
			[void]$steps.Add('Execute the rollback commands through the Baseline launcher.')
			[void]$steps.Add('Validate the resulting state and keep the support bundle with the incident record.')
		}
	}

	[pscustomobject]@{
		Operation         = $Operation
		Direction         = $direction
		CurrentVersion    = $CurrentVersion
		TargetVersion     = $targetVersionText
		InstallerPath     = if ($InstallerPath) { (Resolve-Path -LiteralPath $InstallerPath).Path } else { $null }
		RollbackProfile   = $rollbackProfile
		RollbackCommands  = $commands
		BaselineExecutable = if ($BaselineExecutablePath) { (Resolve-Path -LiteralPath $BaselineExecutablePath).Path } else { $null }
		Steps             = @($steps)
		GeneratedAt       = [System.DateTime]::UtcNow.ToString('o')
	}
}

<#
    .SYNOPSIS
    Internal function Invoke-BaselineLifecyclePlaybook.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Invoke-BaselineLifecyclePlaybook
{
	[CmdletBinding(SupportsShouldProcess = $true)]
	param(
		[Parameter(Mandatory)]
		[pscustomobject]$Playbook,

		[switch]$Execute
	)

	if ($null -eq $Playbook)
	{
		throw 'Playbook is required.'
	}

	$result = [ordered]@{
		Operation = [string]$Playbook.Operation
		Direction = [string]$Playbook.Direction
		Executed  = [bool]$Execute
		Success   = $false
		ExitCode  = $null
		Commands  = @()
	}

	if (-not $Execute)
	{
		$result.Success = $true
		return [pscustomobject]$result
	}

	switch ([string]$Playbook.Operation)
	{
		'Upgrade' { }
		'Downgrade' { }
		'Rollback' { }
		default { throw "Unsupported lifecycle operation '$($Playbook.Operation)'." }
	}

	if ($Playbook.Operation -in @('Upgrade', 'Downgrade'))
	{
		if ([string]::IsNullOrWhiteSpace([string]$Playbook.InstallerPath))
		{
			throw 'InstallerPath is required for upgrade or downgrade execution.'
		}

		if (Get-Command -Name 'Assert-AuthenticodeSignature' -ErrorAction SilentlyContinue)
		{
			$null = Assert-AuthenticodeSignature -Path $Playbook.InstallerPath
		}

		$arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS')
		if ($PSCmdlet.ShouldProcess($Playbook.InstallerPath, "$($Playbook.Operation) Baseline"))
		{
			$process = Start-Process -FilePath $Playbook.InstallerPath -ArgumentList $arguments -Wait -PassThru -ErrorAction Stop
			$result.ExitCode = $process.ExitCode
			$result.Success = ($process.ExitCode -eq 0)
		}

		return [pscustomobject]$result
	}

	$commands = @($Playbook.RollbackCommands)
	if ($commands.Count -eq 0)
	{
		throw 'Rollback playbook does not contain any commands.'
	}

	$bootstrapPath = Join-Path $Script:SharedHelpersRepoRoot 'Baseline.exe'
	$useExe = Test-Path -LiteralPath $bootstrapPath -PathType Leaf
	if (-not $useExe)
	{
		$bootstrapPath = Join-Path $Script:SharedHelpersRepoRoot 'Bootstrap\Baseline.ps1'
		if (-not (Test-Path -LiteralPath $bootstrapPath -PathType Leaf))
		{
			throw 'Could not locate Baseline.exe or Bootstrap\Baseline.ps1 to execute rollback commands.'
		}
	}

	$argumentList = @()
	if ($useExe)
	{
		$argumentList += '-Functions'
		$argumentList += $commands
	}
	else
	{
		$argumentList += @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $bootstrapPath, '-Functions')
		$argumentList += $commands
		$bootstrapPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
	}

	if ($PSCmdlet.ShouldProcess(($commands -join ', '), 'Execute rollback playbook'))
	{
		$process = Start-Process -FilePath $bootstrapPath -ArgumentList $argumentList -Wait -PassThru -ErrorAction Stop
		$result.ExitCode = $process.ExitCode
		$result.Success = ($process.ExitCode -eq 0)
		$result.Commands = @($commands)
	}

	return [pscustomobject]$result
}

<#
    .SYNOPSIS
    Internal function New-BaselineIncidentReproductionPack.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function New-BaselineIncidentReproductionPack
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$SupportBundlePath,

		[string]$OutputDirectory,

		[string]$IncidentId
	)

	if (-not (Test-Path -LiteralPath $SupportBundlePath))
	{
		throw "Support bundle not found: $SupportBundlePath"
	}

	$resolvedBundlePath = (Resolve-Path -LiteralPath $SupportBundlePath).Path
	$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("BaselineIncident_{0}" -f [guid]::NewGuid().ToString('N'))
	$bundleRoot = $workRoot
	$createdTemp = $false

	try
	{
		if ((Get-Item -LiteralPath $resolvedBundlePath).PSIsContainer)
		{
			$bundleRoot = $resolvedBundlePath
		}
		else
		{
			$bundleRoot = Join-Path $workRoot 'bundle'
			New-Item -Path $bundleRoot -ItemType Directory -Force | Out-Null
			Expand-Archive -LiteralPath $resolvedBundlePath -DestinationPath $bundleRoot -Force
			$createdTemp = $true
		}

		if ([string]::IsNullOrWhiteSpace($OutputDirectory))
		{
			$bundleName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedBundlePath)
			$OutputDirectory = Join-Path (Split-Path -Path $resolvedBundlePath -Parent) ("{0}.repro" -f $bundleName)
		}

		$resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path (Split-Path -Path $resolvedBundlePath -Parent) $OutputDirectory }
		New-Item -Path $resolvedOutput -ItemType Directory -Force | Out-Null

		$metadataPath = Join-Path $bundleRoot 'metadata.json'
		$preflightPath = Join-Path $bundleRoot 'preflight-report.json'
		$auditPath = Join-Path $bundleRoot 'audit.jsonl'
		$compliancePath = Join-Path $bundleRoot 'compliance-report.json'

		$metadata = if (Test-Path -LiteralPath $metadataPath) { Get-Content -LiteralPath $metadataPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction SilentlyContinue } else { $null }
		$preflight = if (Test-Path -LiteralPath $preflightPath) { Get-Content -LiteralPath $preflightPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction SilentlyContinue } else { $null }
		$compliance = if (Test-Path -LiteralPath $compliancePath) { Get-Content -LiteralPath $compliancePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction SilentlyContinue } else { $null }

		$auditLines = @()
		if (Test-Path -LiteralPath $auditPath)
		{
			$auditLines = @(Get-Content -LiteralPath $auditPath -ErrorAction SilentlyContinue | Select-Object -First 20)
		}

		$recentAudit = @(
			foreach ($line in $auditLines)
			{
				if ([string]::IsNullOrWhiteSpace([string]$line)) { continue }
				try { $line | ConvertFrom-Json -ErrorAction Stop } catch { continue }
			}
		)

		$warningDetails = @()
		if ($preflight -and $preflight.PSObject.Properties['AllResults'])
		{
			$warningDetails = @(
				@($preflight.AllResults | Where-Object { $_.Status -in @('Warning', 'Failed') } | ForEach-Object { '{0}: {1}' -f $_.Name, $_.Message })
			)
		}

		$reproSteps = [System.Collections.Generic.List[string]]::new()
		[void]$reproSteps.Add('Use the exact Baseline version recorded in the support bundle metadata.')
		[void]$reproSteps.Add('Reapply the same profile, approval policy, or rollback profile that was attached to the bundle.')
		[void]$reproSteps.Add('Match the same target scope, connectivity state, and preflight warnings before retrying.')
		[void]$reproSteps.Add('Capture a fresh support bundle immediately after the failure or deviation.')

		$incident = [ordered]@{
			Schema            = 'Baseline.IncidentRepro'
			SchemaVersion     = 1
			IncidentId        = if ([string]::IsNullOrWhiteSpace($IncidentId)) { [guid]::NewGuid().ToString('N') } else { $IncidentId }
			GeneratedAt       = [System.DateTime]::UtcNow.ToString('o')
			SupportBundlePath = $resolvedBundlePath
			BaselineVersion   = if ($metadata -and $metadata.PSObject.Properties['BaselineVersion']) { [string]$metadata.BaselineVersion } else { $null }
			MachineName       = if ($metadata -and $metadata.PSObject.Properties['MachineName']) { [string]$metadata.MachineName } else { $null }
			UserName          = if ($metadata -and $metadata.PSObject.Properties['UserName']) { [string]$metadata.UserName } else { $null }
			OS                = if ($metadata -and $metadata.PSObject.Properties['OS']) { [string]$metadata.OS } else { $null }
			ProfilePath       = if ($metadata -and $metadata.PSObject.Properties['ProfilePath']) { [string]$metadata.ProfilePath } else { $null }
			AuditRetention    = if ($metadata -and $metadata.PSObject.Properties['AuditRetention']) { $metadata.AuditRetention } else { $null }
			PreflightWarnings = @($warningDetails)
			RecentAudit        = @($recentAudit | Select-Object -First 10)
			RecommendedSteps   = @($reproSteps)
			Attachments        = @(
				'metadata.json'
				'preflight-report.json'
				'compliance-report.json'
				'audit.jsonl'
			) | Where-Object { Test-Path -LiteralPath (Join-Path $bundleRoot $_) }
		}

		$jsonPath = Join-Path $resolvedOutput 'incident-reproduction.json'
		$mdPath = Join-Path $resolvedOutput 'incident-reproduction.md'
		[System.IO.File]::WriteAllText($jsonPath, ($incident | ConvertTo-Json -Depth 12), [System.Text.UTF8Encoding]::new($false))

		$md = [System.Collections.Generic.List[string]]::new()
		[void]$md.Add('# Baseline Incident Reproduction Pack')
		[void]$md.Add('')
		[void]$md.Add(('Incident ID: {0}' -f $incident.IncidentId))
		[void]$md.Add(('Support bundle: {0}' -f $incident.SupportBundlePath))
		[void]$md.Add(('Baseline version: {0}' -f $(if ($incident.BaselineVersion) { $incident.BaselineVersion } else { 'unknown' })))
		[void]$md.Add(('Machine: {0}' -f $(if ($incident.MachineName) { $incident.MachineName } else { 'unknown' })))
		[void]$md.Add('')
		[void]$md.Add('## Reproduction Steps')
		foreach ($step in @($incident.RecommendedSteps))
		{
			[void]$md.Add(('- {0}' -f $step))
		}
		if ($incident.PreflightWarnings.Count -gt 0)
		{
			[void]$md.Add('')
			[void]$md.Add('## Preflight Warnings')
			foreach ($warning in @($incident.PreflightWarnings))
			{
				[void]$md.Add(('- {0}' -f $warning))
			}
		}
		if ($incident.RecentAudit.Count -gt 0)
		{
			[void]$md.Add('')
			[void]$md.Add('## Recent Audit Events')
			foreach ($record in @($incident.RecentAudit))
			{
				$action = if ($record.PSObject.Properties['Action']) { [string]$record.Action } else { 'Unknown' }
				$mode = if ($record.PSObject.Properties['Mode']) { [string]$record.Mode } else { 'Unknown' }
				[void]$md.Add(('- {0} ({1})' -f $action, $mode))
			}
		}
		[System.IO.File]::WriteAllText($mdPath, ($md -join [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))

		return [pscustomobject]@{
			OutputDirectory = $resolvedOutput
			JsonPath        = $jsonPath
			MarkdownPath    = $mdPath
			IncidentId      = $incident.IncidentId
			BaselineVersion = $incident.BaselineVersion
			WarningCount    = @($incident.PreflightWarnings).Count
			AuditEventCount = @($incident.RecentAudit).Count
		}
	}
	finally
	{
		if ($createdTemp -and (Test-Path -LiteralPath $workRoot))
		{
			Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
		}
	}
}
