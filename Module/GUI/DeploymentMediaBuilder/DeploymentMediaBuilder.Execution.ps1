# DeploymentMediaBuilder.Execution.ps1
# Bounded execution, cancellation, telemetry, and cleanup helpers.

function Write-GuiDeploymentMediaBuildStatus
{
	[CmdletBinding()]
	param (
		[scriptblock]$ProgressCallback,
		[Parameter(Mandatory = $true)]
		[string]$Message
	)

	if ($ProgressCallback)
	{
		& $ProgressCallback $Message
	}
	if (Get-Command -Name 'LogInfo' -CommandType Function, Alias -ErrorAction SilentlyContinue)
	{
		LogInfo $Message
	}
}

function New-GuiDeploymentMediaCancellationState
{
	[CmdletBinding()]
	[OutputType([hashtable])]
	param ()

	return [hashtable]::Synchronized(@{
		CancelRequested = $false
		CancelReason = ''
		RequestedUtc = $null
		CurrentStage = ''
		StageStartedUtc = $null
	})
}

function Request-GuiDeploymentMediaCancellation
{
	[CmdletBinding()]
	param (
		[AllowNull()]
		[hashtable]$CancellationState,
		[string]$Reason = 'Deployment media operation cancelled by operator.'
	)

	if (-not $CancellationState) { return }

	$CancellationState.CancelRequested = $true
	$CancellationState.CancelReason = $Reason
	$CancellationState.RequestedUtc = [DateTime]::UtcNow
}

function Test-GuiDeploymentMediaCancellationRequested
{
	[CmdletBinding()]
	[OutputType([bool])]
	param (
		[AllowNull()]
		[hashtable]$CancellationState
	)

	return ($CancellationState -and $CancellationState.ContainsKey('CancelRequested') -and [bool]$CancellationState.CancelRequested)
}

function Assert-GuiDeploymentMediaNotCancelled
{
	[CmdletBinding()]
	param (
		[AllowNull()]
		[hashtable]$CancellationState,
		[string]$Stage = 'Deployment media operation'
	)

	if (Test-GuiDeploymentMediaCancellationRequested -CancellationState $CancellationState)
	{
		$reason = if ($CancellationState.ContainsKey('CancelReason') -and -not [string]::IsNullOrWhiteSpace([string]$CancellationState.CancelReason)) { [string]$CancellationState.CancelReason } else { 'Deployment media operation cancelled by operator.' }
		throw ([System.OperationCanceledException]::new(('{0} cancelled. {1}' -f $Stage, $reason)))
	}
}

function Set-GuiDeploymentMediaCurrentStage
{
	[CmdletBinding()]
	param (
		[AllowNull()]
		[hashtable]$CancellationState,
		[string]$Stage
	)

	if (-not $CancellationState) { return }

	$CancellationState.CurrentStage = [string]$Stage
	$CancellationState.StageStartedUtc = [DateTime]::UtcNow
}

function New-GuiDeploymentMediaBuildTelemetry
{
	[CmdletBinding()]
	[OutputType([hashtable])]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Plan,
		[Parameter(Mandatory = $true)]
		[string]$BuildRoot,
		[Parameter(Mandatory = $true)]
		[string]$MediaRoot,
		[Parameter(Mandatory = $true)]
		[string]$MountRoot,
		[int]$GlobalTimeoutSeconds
	)

	$architecture = ''
	if ($Plan.IsoImageInfo -and $Plan.IsoImageInfo.PSObject.Properties['Editions'])
	{
		foreach ($edition in @($Plan.IsoImageInfo.Editions))
		{
			if ([int]$edition.Index -eq [int]$Plan.EditionIndex -and $edition.PSObject.Properties['Architecture'])
			{
				$architecture = [string]$edition.Architecture
				break
			}
		}
	}

	return @{
		SourceIsoName = [System.IO.Path]::GetFileName([string]$Plan.SourceIso)
		SourceIsoPath = [string]$Plan.SourceIso
		EditionIndex = [int]$Plan.EditionIndex
		EditionName = [string]$Plan.EditionName
		Architecture = $architecture
		ImageKind = $(if ($Plan.IsoImageInfo -and $Plan.IsoImageInfo.PSObject.Properties['ImageKind']) { [string]$Plan.IsoImageInfo.ImageKind } else { '' })
		OutputMode = [string]$Plan.OutputMode
		GlobalTimeoutSeconds = [int]$GlobalTimeoutSeconds
		TempPaths = [pscustomobject]@{
			BuildRoot = $BuildRoot
			MediaRoot = $MediaRoot
			MountRoot = $MountRoot
		}
		StageRecords = [System.Collections.Generic.List[object]]::new()
		CleanupRecords = [System.Collections.Generic.List[object]]::new()
	}
}

function Write-GuiDeploymentMediaTelemetryLog
{
	[CmdletBinding()]
	param (
		[AllowNull()]
		[hashtable]$Telemetry,
		[Parameter(Mandatory = $true)]
		[ValidateSet('Stage', 'Cleanup')]
		[string]$Kind,
		[Parameter(Mandatory = $true)]
		[object]$Record
	)

	if (-not $Telemetry -or -not $Record) { return }

	try
	{
		$tempPaths = $Telemetry.TempPaths
		$payload = [ordered]@{
			Event = 'DeploymentMediaBuilderTelemetry'
			Kind = $Kind
			Name = [string]$Record.Name
			Outcome = [string]$Record.Outcome
			StartedUtc = $Record.StartedUtc
			CompletedUtc = $Record.CompletedUtc
			ElapsedSeconds = $Record.ElapsedSeconds
			Detail = [string]$Record.Detail
			SourceIsoName = [string]$Telemetry.SourceIsoName
			EditionIndex = [int]$Telemetry.EditionIndex
			EditionName = [string]$Telemetry.EditionName
			Architecture = [string]$Telemetry.Architecture
			ImageKind = [string]$Telemetry.ImageKind
			OutputMode = [string]$Telemetry.OutputMode
			GlobalTimeoutSeconds = [int]$Telemetry.GlobalTimeoutSeconds
			TempPaths = [ordered]@{
				BuildRoot = $(if ($tempPaths) { [string]$tempPaths.BuildRoot } else { '' })
				MediaRoot = $(if ($tempPaths) { [string]$tempPaths.MediaRoot } else { '' })
				MountRoot = $(if ($tempPaths) { [string]$tempPaths.MountRoot } else { '' })
			}
		}
		$message = 'DeploymentMediaTelemetry ' + (ConvertTo-Json -InputObject $payload -Depth 8 -Compress)
		if ([string]$Record.Outcome -eq 'Failed')
		{
			if ($Kind -eq 'Cleanup' -and (Get-Command -Name 'LogWarning' -CommandType Function, Alias -ErrorAction SilentlyContinue))
			{
				LogWarning $message
			}
			elseif (Get-Command -Name 'LogError' -CommandType Function, Alias -ErrorAction SilentlyContinue)
			{
				LogError $message
			}
			return
		}
		if (Get-Command -Name 'LogInfo' -CommandType Function, Alias -ErrorAction SilentlyContinue)
		{
			LogInfo $message
		}
	}
	catch
	{
		if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Write-SwallowedException -ErrorRecord $_ -Source 'DeploymentMediaBuilder.TelemetryLog' -Severity Warning
		}
	}
}

function Add-GuiDeploymentMediaTelemetryRecord
{
	[CmdletBinding()]
	param (
		[AllowNull()]
		[hashtable]$Telemetry,
		[Parameter(Mandatory = $true)]
		[ValidateSet('Stage', 'Cleanup')]
		[string]$Kind,
		[Parameter(Mandatory = $true)]
		[string]$Name,
		[Parameter(Mandatory = $true)]
		[DateTime]$StartedUtc,
		[Parameter(Mandatory = $true)]
		[DateTime]$CompletedUtc,
		[Parameter(Mandatory = $true)]
		[string]$Outcome,
		[string]$Detail = ''
	)

	if (-not $Telemetry) { return }

	$record = [pscustomobject]@{
		Name = $Name
		StartedUtc = $StartedUtc
		CompletedUtc = $CompletedUtc
		ElapsedSeconds = [Math]::Round(($CompletedUtc - $StartedUtc).TotalSeconds, 3)
		Outcome = $Outcome
		Detail = $Detail
	}

	if ($Kind -eq 'Cleanup')
	{
		[void]$Telemetry.CleanupRecords.Add($record)
	}
	else
	{
		[void]$Telemetry.StageRecords.Add($record)
	}

	Write-GuiDeploymentMediaTelemetryLog -Telemetry $Telemetry -Kind $Kind -Record $record
}

function Get-GuiDeploymentMediaStageTimeoutSeconds
{
	[CmdletBinding()]
	[OutputType([int])]
	param (
		[DateTime]$OperationStartedUtc,
		[int]$GlobalTimeoutSeconds,
		[int]$StageTimeoutSeconds
	)

	if ($StageTimeoutSeconds -lt 1) { $StageTimeoutSeconds = 1 }
	if ($GlobalTimeoutSeconds -lt 1) { return $StageTimeoutSeconds }

	$deadlineUtc = $OperationStartedUtc.AddSeconds($GlobalTimeoutSeconds)
	$remainingSeconds = [int][Math]::Floor(($deadlineUtc - [DateTime]::UtcNow).TotalSeconds)
	if ($remainingSeconds -lt 1)
	{
		throw ([System.TimeoutException]::new(('Deployment media build exceeded its global timeout of {0} second(s).' -f $GlobalTimeoutSeconds)))
	}

	return [Math]::Max(1, [Math]::Min($StageTimeoutSeconds, $remainingSeconds))
}

function Invoke-GuiDeploymentMediaCleanupWithRetry
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Name,
		[Parameter(Mandatory = $true)]
		[scriptblock]$Action,
		[AllowNull()]
		[hashtable]$Telemetry,
		[string]$Detail = '',
		[ValidateRange(1, 10)]
		[int]$MaxAttempts = 3,
		[ValidateRange(0, 60000)]
		[int]$DelayMilliseconds = 750
	)

	$startedUtc = [DateTime]::UtcNow
	$attemptCount = [Math]::Max(1, $MaxAttempts)
	$lastError = $null
	for ($attempt = 1; $attempt -le $attemptCount; $attempt++)
	{
		try
		{
			& $Action
			$successDetail = ('{0}; Attempts={1}' -f $Detail, $attempt).Trim(@(';', ' '))
			Add-GuiDeploymentMediaTelemetryRecord -Telemetry $Telemetry -Kind Cleanup -Name $Name -StartedUtc $startedUtc -CompletedUtc ([DateTime]::UtcNow) -Outcome 'Succeeded' -Detail $successDetail
			return
		}
		catch
		{
			$lastError = $_
			if ($attempt -lt $attemptCount)
			{
				if (Get-Command -Name 'LogWarning' -CommandType Function, Alias -ErrorAction SilentlyContinue)
				{
					LogWarning ('Deployment media cleanup retry {0}/{1} for {2}: {3}' -f ($attempt + 1), $attemptCount, $Name, $_.Exception.Message)
				}
				if ($DelayMilliseconds -gt 0)
				{
					Start-Sleep -Milliseconds $DelayMilliseconds
				}
			}
		}
	}

	$failureDetail = ('{0}; Attempts={1}; Error={2}' -f $Detail, $attemptCount, $lastError.Exception.Message).Trim(@(';', ' '))
	Add-GuiDeploymentMediaTelemetryRecord -Telemetry $Telemetry -Kind Cleanup -Name $Name -StartedUtc $startedUtc -CompletedUtc ([DateTime]::UtcNow) -Outcome 'Failed' -Detail $failureDetail
	if ($lastError) { throw $lastError }
}

function Request-GuiDeploymentMediaPowerShellStop
{
	[CmdletBinding()]
	[OutputType([bool])]
	param (
		[AllowNull()]
		[System.Management.Automation.PowerShell]$PowerShell,
		[string]$Source = 'DeploymentMedia.PowerShellStop',
		[int]$StopWaitMilliseconds = 1000
	)

	if (-not $PowerShell) { return $true }

	try
	{
		$stopResult = $PowerShell.BeginStop($null, $null)
		if ($stopResult -and $stopResult.AsyncWaitHandle)
		{
			if ($stopResult.AsyncWaitHandle.WaitOne([Math]::Max(0, $StopWaitMilliseconds)))
			{
				try { $PowerShell.EndStop($stopResult) }
				catch
				{
					if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
					{
						Write-SwallowedException -ErrorRecord $_ -Source ($Source + '.EndStop') -Severity Debug
					}
				}
				return $true
			}
			return $false
		}
	}
	catch
	{
		if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Write-SwallowedException -ErrorRecord $_ -Source $Source -Severity Warning
		}
		return $false
	}

	return $true
}

function Invoke-GuiDeploymentMediaPowerShellStage
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Name,
		[Parameter(Mandatory = $true)]
		[scriptblock]$ScriptBlock,
		[object[]]$ArgumentList = @(),
		[ValidateRange(1, 86400)]
		[int]$TimeoutSeconds = 900,
		[AllowNull()]
		[hashtable]$CancellationState,
		[AllowNull()]
		[hashtable]$Telemetry
	)

	Assert-GuiDeploymentMediaNotCancelled -CancellationState $CancellationState -Stage $Name
	Set-GuiDeploymentMediaCurrentStage -CancellationState $CancellationState -Stage $Name

	$startedUtc = [DateTime]::UtcNow
	$runspace = $null
	$ps = $null
	$asyncResult = $null
	$completed = $false
	try
	{
		$runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
		$runspace.ApartmentState = 'STA'
		$runspace.ThreadOptions = 'ReuseThread'
		$runspace.Open()

		$ps = [System.Management.Automation.PowerShell]::Create()
		$ps.Runspace = $runspace
		[void]$ps.AddScript($ScriptBlock.ToString())
		foreach ($argument in @($ArgumentList))
		{
			[void]$ps.AddArgument($argument)
		}

		$asyncResult = $ps.BeginInvoke()
		$deadlineUtc = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
		while (-not $asyncResult.AsyncWaitHandle.WaitOne(250))
		{
			if (Test-GuiDeploymentMediaCancellationRequested -CancellationState $CancellationState)
			{
				[void](Request-GuiDeploymentMediaPowerShellStop -PowerShell $ps -Source ('DeploymentMedia.{0}.CancelStop' -f $Name))
				throw ([System.OperationCanceledException]::new(('Deployment media stage cancelled: {0}' -f $Name)))
			}
			if ([DateTime]::UtcNow -ge $deadlineUtc)
			{
				[void](Request-GuiDeploymentMediaPowerShellStop -PowerShell $ps -Source ('DeploymentMedia.{0}.TimeoutStop' -f $Name))
				throw ([System.TimeoutException]::new(('{0} timed out after {1} second(s).' -f $Name, $TimeoutSeconds)))
			}
		}

		$completed = $true
		$result = @($ps.EndInvoke($asyncResult))
		Add-GuiDeploymentMediaTelemetryRecord -Telemetry $Telemetry -Kind Stage -Name $Name -StartedUtc $startedUtc -CompletedUtc ([DateTime]::UtcNow) -Outcome 'Succeeded'
		if ($result.Count -eq 0) { return $null }
		if ($result.Count -eq 1) { return $result[0] }
		return $result
	}
	catch
	{
		Add-GuiDeploymentMediaTelemetryRecord -Telemetry $Telemetry -Kind Stage -Name $Name -StartedUtc $startedUtc -CompletedUtc ([DateTime]::UtcNow) -Outcome 'Failed' -Detail $_.Exception.Message
		throw
	}
	finally
	{
		if (-not $completed -and $ps)
		{
			[void](Request-GuiDeploymentMediaPowerShellStop -PowerShell $ps -Source ('DeploymentMedia.{0}.FinalStop' -f $Name))
		}
		try { if ($ps) { $ps.Dispose() } }
		catch
		{
			if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Write-SwallowedException -ErrorRecord $_ -Source ('DeploymentMedia.{0}.DisposePowerShell' -f $Name) -Severity Warning
			}
		}
		try
		{
			if ($runspace)
			{
				if ($completed) { $runspace.Close() } else { $runspace.CloseAsync() }
				$runspace.Dispose()
			}
		}
		catch
		{
			if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Write-SwallowedException -ErrorRecord $_ -Source ('DeploymentMedia.{0}.DisposeRunspace' -f $Name) -Severity Warning
			}
		}
	}
}

function Resolve-GuiDeploymentMediaOscdimgPath
{
	[CmdletBinding()]
	[OutputType([string])]
	param ()

	$command = Get-Command -Name 'oscdimg.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($command -and -not [string]::IsNullOrWhiteSpace([string]$command.Source))
	{
		return [string]$command.Source
	}

	$candidates = [System.Collections.Generic.List[string]]::new()
	foreach ($root in @(${env:ProgramFiles(x86)}, $env:ProgramFiles))
	{
		if ([string]::IsNullOrWhiteSpace([string]$root)) { continue }
		foreach ($architecture in @('amd64', 'x86', 'arm64'))
		{
			[void]$candidates.Add((Join-Path $root ('Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\{0}\Oscdimg\oscdimg.exe' -f $architecture)))
		}
	}

	foreach ($candidate in $candidates)
	{
		if (Test-Path -LiteralPath $candidate -PathType Leaf)
		{
			return $candidate
		}
	}

	throw 'oscdimg.exe is required to create an ISO. Install the Windows ADK Deployment Tools or put oscdimg.exe on PATH.'
}

function Resolve-GuiDeploymentMediaDismPath
{
	[CmdletBinding()]
	[OutputType([string])]
	param ()

	$dismPath = Join-Path $env:SystemRoot 'System32\dism.exe'
	if (Test-Path -LiteralPath $dismPath -PathType Leaf)
	{
		return $dismPath
	}

	$command = Get-Command -Name 'dism.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($command -and -not [string]::IsNullOrWhiteSpace([string]$command.Source))
	{
		return [string]$command.Source
	}

	throw 'dism.exe is required for deployment media image servicing.'
}

function Invoke-GuiDeploymentMediaProcess
{
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true)]
		[string]$FilePath,
		[object[]]$ArgumentList = @(),
		[int]$TimeoutSeconds = 7200,
		[int[]]$AllowedExitCodes = @(0),
		[AllowNull()]
		[hashtable]$CancellationState,
		[string]$StageName = '',
		[string]$WorkingDirectory = '',
		[AllowNull()]
		[hashtable]$Telemetry
	)

	if (-not (Get-Command -Name 'ConvertTo-BaselineProcessArgumentString' -CommandType Function -ErrorAction SilentlyContinue))
	{
		throw 'ConvertTo-BaselineProcessArgumentString is required for deployment media external tool execution.'
	}
	if (-not (Get-Command -Name 'Stop-BaselineProcessTree' -CommandType Function -ErrorAction SilentlyContinue))
	{
		throw 'Stop-BaselineProcessTree is required for deployment media timeout and cancellation cleanup.'
	}

	$effectiveStageName = if ([string]::IsNullOrWhiteSpace($StageName)) { [System.IO.Path]::GetFileName($FilePath) } else { $StageName }
	Assert-GuiDeploymentMediaNotCancelled -CancellationState $CancellationState -Stage $effectiveStageName
	Set-GuiDeploymentMediaCurrentStage -CancellationState $CancellationState -Stage $effectiveStageName

	$startedUtc = [DateTime]::UtcNow
	$argumentDisplay = ConvertTo-BaselineProcessArgumentString -ArgumentList $ArgumentList
	$psi = [System.Diagnostics.ProcessStartInfo]::new()
	$psi.FileName = $FilePath
	$argumentListProperty = $psi.GetType().GetProperty('ArgumentList')
	if ($argumentListProperty)
	{
		foreach ($argument in @($ArgumentList))
		{
			[void]$psi.ArgumentList.Add([string]$argument)
		}
	}
	else
	{
		$psi.Arguments = $argumentDisplay
	}
	$psi.UseShellExecute = $false
	$psi.CreateNoWindow = $true
	$psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
	if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory))
	{
		if (-not (Test-Path -LiteralPath $WorkingDirectory -PathType Container))
		{
			throw ('Working directory does not exist for {0}: {1}' -f $effectiveStageName, $WorkingDirectory)
		}
		$psi.WorkingDirectory = [System.IO.Path]::GetFullPath($WorkingDirectory)
	}

	$process = [System.Diagnostics.Process]::new()
	$process.StartInfo = $psi
	try
	{
		[void]$process.Start()
		$deadlineUtc = [DateTime]::UtcNow.AddSeconds([Math]::Max(1, $TimeoutSeconds))
		while (-not $process.WaitForExit(250))
		{
			if (Test-GuiDeploymentMediaCancellationRequested -CancellationState $CancellationState)
			{
				Stop-BaselineProcessTree -Process $process -Source ('DeploymentMedia.{0}.Cancel' -f $effectiveStageName)
				throw ([System.OperationCanceledException]::new(('Deployment media process cancelled during {0}.' -f $effectiveStageName)))
			}
			if ([DateTime]::UtcNow -ge $deadlineUtc)
			{
				Stop-BaselineProcessTree -Process $process -Source ('DeploymentMedia.{0}.Timeout' -f $effectiveStageName)
				throw ([System.TimeoutException]::new(('{0} timed out after {1} second(s). Process: {2}' -f $effectiveStageName, $TimeoutSeconds, $FilePath)))
			}
		}

		$effectiveAllowedExitCodes = @($AllowedExitCodes)
		if ($effectiveAllowedExitCodes.Count -eq 0) { $effectiveAllowedExitCodes = @(0) }
		if ($process.ExitCode -notin $effectiveAllowedExitCodes)
		{
			throw ("Process '{0}' failed with exit code {1}. Arguments: {2}" -f $FilePath, $process.ExitCode, $argumentDisplay)
		}

		Add-GuiDeploymentMediaTelemetryRecord -Telemetry $Telemetry -Kind Stage -Name $effectiveStageName -StartedUtc $startedUtc -CompletedUtc ([DateTime]::UtcNow) -Outcome 'Succeeded' -Detail ('ProcessId={0}; ExitCode={1}' -f $process.Id, $process.ExitCode)
		return [pscustomobject]@{
			ExitCode = [int]$process.ExitCode
			TimedOut = $false
			ProcessId = [int]$process.Id
			FilePath = $FilePath
			Arguments = $argumentDisplay
		}
	}
	catch
	{
		Add-GuiDeploymentMediaTelemetryRecord -Telemetry $Telemetry -Kind Stage -Name $effectiveStageName -StartedUtc $startedUtc -CompletedUtc ([DateTime]::UtcNow) -Outcome 'Failed' -Detail $_.Exception.Message
		throw
	}
	finally
	{
		try { $process.Dispose() }
		catch
		{
			if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Write-SwallowedException -ErrorRecord $_ -Source ('DeploymentMedia.{0}.DisposeProcess' -f $effectiveStageName) -Severity Debug
			}
		}
	}
}

function Invoke-GuiDeploymentMediaDism
{
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true)]
		[object[]]$ArgumentList,
		[Parameter(Mandatory = $true)]
		[string]$StageName,
		[int]$TimeoutSeconds = 3600,
		[AllowNull()]
		[hashtable]$CancellationState,
		[AllowNull()]
		[hashtable]$Telemetry
	)

	$dismPath = Resolve-GuiDeploymentMediaDismPath
	return Invoke-GuiDeploymentMediaProcess -FilePath $dismPath -ArgumentList $ArgumentList -TimeoutSeconds $TimeoutSeconds -AllowedExitCodes @(0) -CancellationState $CancellationState -StageName $StageName -Telemetry $Telemetry
}

function Invoke-GuiDeploymentMediaIsoDismountCleanup
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$ImagePath,
		[AllowNull()]
		[hashtable]$CancellationState,
		[AllowNull()]
		[hashtable]$Telemetry
	)

	$cleanupAction = {
		$diskImage = Get-DiskImage -ImagePath $ImagePath -ErrorAction SilentlyContinue
		if ($diskImage -and $diskImage.Attached)
		{
			Dismount-DiskImage -ImagePath $ImagePath -ErrorAction Stop
		}
	}.GetNewClosure()
	Invoke-GuiDeploymentMediaCleanupWithRetry -Name 'Dismount source ISO' -Action $cleanupAction -Telemetry $Telemetry -Detail $ImagePath -MaxAttempts 3 -DelayMilliseconds 750
}

function Invoke-GuiDeploymentMediaDismountImage
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$MountPath,
		[Parameter(Mandatory = $true)]
		[ValidateSet('Save', 'Discard')]
		[string]$Mode,
		[int]$TimeoutSeconds = 1800,
		[AllowNull()]
		[hashtable]$CancellationState,
		[AllowNull()]
		[hashtable]$Telemetry,
		[switch]$Cleanup
	)

	$modeArgument = if ($Mode -eq 'Save') { '/Commit' } else { '/Discard' }
	$stageName = ('Dismount image ({0})' -f $Mode)
	$startedUtc = [DateTime]::UtcNow
	if ($Cleanup)
	{
		$cleanupAction = {
			$null = Invoke-GuiDeploymentMediaDism -ArgumentList @('/Unmount-Image', ('/MountDir:{0}' -f $MountPath), $modeArgument) -StageName $stageName -TimeoutSeconds $TimeoutSeconds -CancellationState $CancellationState -Telemetry $null
		}.GetNewClosure()
		Invoke-GuiDeploymentMediaCleanupWithRetry -Name $stageName -Action $cleanupAction -Telemetry $Telemetry -Detail $MountPath -MaxAttempts 3 -DelayMilliseconds 1000
		return
	}

	try
	{
		$null = Invoke-GuiDeploymentMediaDism -ArgumentList @('/Unmount-Image', ('/MountDir:{0}' -f $MountPath), $modeArgument) -StageName $stageName -TimeoutSeconds $TimeoutSeconds -CancellationState $CancellationState -Telemetry $Telemetry
	}
	catch
	{
		throw
	}
}

function Invoke-GuiDeploymentMediaEmergencyDismCleanup
{
	[CmdletBinding()]
	param (
		[AllowNull()]
		[hashtable]$CancellationState,
		[AllowNull()]
		[hashtable]$Telemetry
	)

	$cleanupAction = {
		$null = Invoke-GuiDeploymentMediaDism -ArgumentList @('/Cleanup-Wim') -StageName 'Emergency DISM cleanup' -TimeoutSeconds 900 -CancellationState $CancellationState -Telemetry $null
	}.GetNewClosure()
	Invoke-GuiDeploymentMediaCleanupWithRetry -Name 'Emergency DISM cleanup' -Action $cleanupAction -Telemetry $Telemetry -MaxAttempts 3 -DelayMilliseconds 1000
}

function Invoke-GuiDeploymentMediaRobocopy
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Source,
		[Parameter(Mandatory = $true)]
		[string]$Destination,
		[AllowNull()]
		[hashtable]$CancellationState,
		[AllowNull()]
		[hashtable]$Telemetry
	)

	$robocopyPath = Join-Path $env:SystemRoot 'System32\robocopy.exe'
	if (-not (Test-Path -LiteralPath $robocopyPath -PathType Leaf))
	{
		throw ('robocopy.exe was not found at {0}.' -f $robocopyPath)
	}

	[void][System.IO.Directory]::CreateDirectory($Destination)
	$arguments = @($Source, $Destination, '/E', '/COPY:DAT', '/DCOPY:DAT', '/R:2', '/W:2', '/NFL', '/NDL')
	$null = Invoke-GuiDeploymentMediaProcess -FilePath $robocopyPath -ArgumentList $arguments -TimeoutSeconds 7200 -AllowedExitCodes @(0, 1, 2, 3, 4, 5, 6, 7) -CancellationState $CancellationState -StageName ('Robocopy {0}' -f [System.IO.Path]::GetFileName($Destination.TrimEnd('\'))) -Telemetry $Telemetry
}

function Get-GuiDeploymentMediaPreparedInstallImagePath
{
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[Parameter(Mandatory = $true)]
		[string]$MediaRoot
	)

	$wimPath = Join-Path $MediaRoot 'sources\install.wim'
	if (Test-Path -LiteralPath $wimPath -PathType Leaf) { return $wimPath }

	$esdPath = Join-Path $MediaRoot 'sources\install.esd'
	if (Test-Path -LiteralPath $esdPath -PathType Leaf) { return $esdPath }

	throw ('Prepared media does not contain sources\install.wim or sources\install.esd under {0}.' -f $MediaRoot)
}

function Invoke-GuiDeploymentMediaDriverInjection
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Plan,
		[Parameter(Mandatory = $true)]
		[string]$MediaRoot,
		[Parameter(Mandatory = $true)]
		[string]$MountRoot,
		[scriptblock]$ProgressCallback,
		[AllowNull()]
		[hashtable]$CancellationState,
		[AllowNull()]
		[hashtable]$Telemetry
	)

	if ([string]::IsNullOrWhiteSpace([string]$Plan.DriverSource) -and -not [bool]$Plan.InjectBootDrivers)
	{
		return
	}

	$null = Resolve-GuiDeploymentMediaDismPath
	[void][System.IO.Directory]::CreateDirectory($MountRoot)

	if (-not [string]::IsNullOrWhiteSpace([string]$Plan.DriverSource))
	{
		Assert-GuiDeploymentMediaNotCancelled -CancellationState $CancellationState -Stage 'Install image driver injection'
		$installImagePath = Get-GuiDeploymentMediaPreparedInstallImagePath -MediaRoot $MediaRoot
		if ([System.IO.Path]::GetExtension($installImagePath).Equals('.esd', [System.StringComparison]::OrdinalIgnoreCase))
		{
			throw 'Driver injection requires sources\install.wim; convert install.esd to WIM before enabling driver injection.'
		}

		$installMountPath = Join-Path $MountRoot 'Install'
		[void][System.IO.Directory]::CreateDirectory($installMountPath)
		Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message ('Mounting install image index {0} for driver injection.' -f $Plan.EditionIndex)
		try
		{
			$null = Invoke-GuiDeploymentMediaDism -ArgumentList @('/Mount-Image', ('/ImageFile:{0}' -f $installImagePath), ('/Index:{0}' -f ([int]$Plan.EditionIndex)), ('/MountDir:{0}' -f $installMountPath)) -StageName 'Mount install image' -TimeoutSeconds 1800 -CancellationState $CancellationState -Telemetry $Telemetry
			$null = Invoke-GuiDeploymentMediaDism -ArgumentList @('/Image:{0}' -f $installMountPath, '/Add-Driver', ('/Driver:{0}' -f ([string]$Plan.DriverSource)), '/Recurse') -StageName 'Inject install drivers' -TimeoutSeconds 7200 -CancellationState $CancellationState -Telemetry $Telemetry
			Invoke-GuiDeploymentMediaDismountImage -MountPath $installMountPath -Mode Save -TimeoutSeconds 1800 -CancellationState $CancellationState -Telemetry $Telemetry
		}
		catch
		{
			$originalError = $_.Exception.Message
			try { Invoke-GuiDeploymentMediaDismountImage -MountPath $installMountPath -Mode Discard -TimeoutSeconds 1800 -CancellationState $null -Telemetry $Telemetry -Cleanup }
			catch
			{
				$cleanupError = $_.Exception.Message
				try { Invoke-GuiDeploymentMediaEmergencyDismCleanup -CancellationState $null -Telemetry $Telemetry }
				catch { throw ('Install image driver injection failed: {0} Cleanup failed: {1}; emergency cleanup failed: {2}' -f $originalError, $cleanupError, $_.Exception.Message) }
				throw ('Install image driver injection failed: {0} Cleanup failed: {1}' -f $originalError, $cleanupError)
			}
			throw ('Install image driver injection failed: {0}' -f $originalError)
		}
	}

	if ([bool]$Plan.InjectBootDrivers)
	{
		Assert-GuiDeploymentMediaNotCancelled -CancellationState $CancellationState -Stage 'Boot image driver injection'
		if ([string]::IsNullOrWhiteSpace([string]$Plan.DriverSource))
		{
			throw 'Boot driver injection requires a driver source directory.'
		}

		$bootImagePath = Join-Path $MediaRoot 'sources\boot.wim'
		if (-not (Test-Path -LiteralPath $bootImagePath -PathType Leaf))
		{
			throw ('Prepared media does not contain sources\boot.wim under {0}.' -f $MediaRoot)
		}

		$bootImages = @(Invoke-GuiDeploymentMediaPowerShellStage -Name 'Inspect boot images' -ScriptBlock {
			param ([string]$ImagePath)
			foreach ($image in @(Get-WindowsImage -ImagePath $ImagePath -ErrorAction Stop))
			{
				[pscustomobject]@{
					ImageIndex = [int]$image.ImageIndex
				}
			}
		} -ArgumentList @($bootImagePath) -TimeoutSeconds 900 -CancellationState $CancellationState -Telemetry $Telemetry)
		foreach ($bootImage in $bootImages)
		{
			Assert-GuiDeploymentMediaNotCancelled -CancellationState $CancellationState -Stage ('Boot image {0} driver injection' -f $bootImage.ImageIndex)
			$bootMountPath = Join-Path $MountRoot ('Boot-{0}' -f $bootImage.ImageIndex)
			[void][System.IO.Directory]::CreateDirectory($bootMountPath)
			Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message ('Mounting boot image index {0} for driver injection.' -f $bootImage.ImageIndex)
			try
			{
				$null = Invoke-GuiDeploymentMediaDism -ArgumentList @('/Mount-Image', ('/ImageFile:{0}' -f $bootImagePath), ('/Index:{0}' -f ([int]$bootImage.ImageIndex)), ('/MountDir:{0}' -f $bootMountPath)) -StageName ('Mount boot image {0}' -f $bootImage.ImageIndex) -TimeoutSeconds 1800 -CancellationState $CancellationState -Telemetry $Telemetry
				$null = Invoke-GuiDeploymentMediaDism -ArgumentList @('/Image:{0}' -f $bootMountPath, '/Add-Driver', ('/Driver:{0}' -f ([string]$Plan.DriverSource)), '/Recurse') -StageName ('Inject boot image {0} drivers' -f $bootImage.ImageIndex) -TimeoutSeconds 7200 -CancellationState $CancellationState -Telemetry $Telemetry
				Invoke-GuiDeploymentMediaDismountImage -MountPath $bootMountPath -Mode Save -TimeoutSeconds 1800 -CancellationState $CancellationState -Telemetry $Telemetry
			}
			catch
			{
				$originalError = $_.Exception.Message
				try { Invoke-GuiDeploymentMediaDismountImage -MountPath $bootMountPath -Mode Discard -TimeoutSeconds 1800 -CancellationState $null -Telemetry $Telemetry -Cleanup }
				catch
				{
					$cleanupError = $_.Exception.Message
					try { Invoke-GuiDeploymentMediaEmergencyDismCleanup -CancellationState $null -Telemetry $Telemetry }
					catch { throw ('Boot image driver injection failed: {0} Cleanup failed: {1}; emergency cleanup failed: {2}' -f $originalError, $cleanupError, $_.Exception.Message) }
					throw ('Boot image driver injection failed: {0} Cleanup failed: {1}' -f $originalError, $cleanupError)
				}
				throw ('Boot image driver injection failed: {0}' -f $originalError)
			}
		}
	}
}

function Get-GuiDeploymentMediaSelectedTweaksForSetup
{
	[CmdletBinding()]
	[OutputType([object[]])]
	param ()

	if (-not (Get-Command -Name 'Get-SelectedTweakRunList' -CommandType Function -ErrorAction SilentlyContinue))
	{
		throw 'Get-SelectedTweakRunList is required to stage selected Baseline setup customizations.'
	}

	$selectedTweaks = @(Get-SelectedTweakRunList -TweakManifest $Script:TweakManifest -Controls $Script:Controls)
	if ($selectedTweaks.Count -lt 1)
	{
		throw 'Baseline setup customizations were requested, but no GUI tweaks are selected.'
	}

	return $selectedTweaks
}

function Invoke-GuiDeploymentMediaBuild
{
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Plan,
		[scriptblock]$ProgressCallback,
		[AllowNull()]
		[object[]]$SelectedTweaks = $null,
		[AllowNull()]
		[hashtable]$CancellationState,
		[ValidateRange(1, 86400)]
		[int]$GlobalTimeoutSeconds = 28800
	)

	if (-not $CancellationState)
	{
		$CancellationState = New-GuiDeploymentMediaCancellationState
	}
	Assert-GuiDeploymentMediaNotCancelled -CancellationState $CancellationState -Stage 'Deployment media build'

	if (-not [bool]$Plan.IsValid)
	{
		throw 'Deployment media build plan has blocking validation errors.'
	}

	$validatedPlan = New-GuiDeploymentMediaBuildPlan -SourceIso ([string]$Plan.SourceIso) -WorkingDirectory ([string]$Plan.WorkingDirectory) -EditionIndex ([int]$Plan.EditionIndex) -EditionName ([string]$Plan.EditionName) -AutounattendPath ([string]$Plan.AutounattendPath) -DriverSource ([string]$Plan.DriverSource) -UsbTargetRoot ([string]$Plan.UsbTargetRoot) -IsoImageInfo $Plan.IsoImageInfo -OutputMode ([string]$Plan.OutputMode) -InjectBootDrivers:([bool]$Plan.InjectBootDrivers) -IncludeBaselineTweaks:([bool]$Plan.IncludeBaselineTweaks)
	if (-not [bool]$validatedPlan.IsValid)
	{
		throw ('Deployment media build plan failed final validation: {0}' -f (@($validatedPlan.Errors) -join '; '))
	}
	$Plan = $validatedPlan

	$startedUtc = [DateTime]::UtcNow
	$buildRoot = Join-Path ([string]$Plan.WorkingDirectory) ('Build-{0}' -f $startedUtc.ToString('yyyyMMdd-HHmmss'))
	$mediaRoot = Join-Path $buildRoot 'Media'
	$mountRoot = Join-Path $buildRoot 'Mount'
	[void][System.IO.Directory]::CreateDirectory($mediaRoot)
	[void][System.IO.Directory]::CreateDirectory($mountRoot)
	$telemetry = New-GuiDeploymentMediaBuildTelemetry -Plan $Plan -BuildRoot $buildRoot -MediaRoot $mediaRoot -MountRoot $mountRoot -GlobalTimeoutSeconds $GlobalTimeoutSeconds

	$diskImage = $null
	$primaryError = $null
	$cleanupError = $null
	$outputPath = $null

	try
	{
		Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message 'Mounting source ISO read-only.'
		$mountTimeoutSeconds = Get-GuiDeploymentMediaStageTimeoutSeconds -OperationStartedUtc $startedUtc -GlobalTimeoutSeconds $GlobalTimeoutSeconds -StageTimeoutSeconds 300
		$diskImage = $true
		$mountInfo = Invoke-GuiDeploymentMediaPowerShellStage -Name 'Mount source ISO' -ScriptBlock {
			param ([string]$SourceIso)
			$mountedImage = Mount-DiskImage -ImagePath $SourceIso -StorageType ISO -Access ReadOnly -PassThru -ErrorAction Stop
			$volume = $mountedImage | Get-Volume -ErrorAction Stop | Select-Object -First 1
			if (-not $volume -or [string]::IsNullOrWhiteSpace([string]$volume.DriveLetter))
			{
				throw 'Mounted ISO did not expose a drive letter.'
			}
			[pscustomobject]@{
				DriveLetter = [string]$volume.DriveLetter
			}
		} -ArgumentList @([string]$Plan.SourceIso) -TimeoutSeconds $mountTimeoutSeconds -CancellationState $CancellationState -Telemetry $telemetry
		$isoRoot = ('{0}:\' -f $mountInfo.DriveLetter)
		Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message ('Copying ISO contents from {0} to {1}.' -f $isoRoot, $mediaRoot)
		Assert-GuiDeploymentMediaNotCancelled -CancellationState $CancellationState -Stage 'Copy source ISO contents'
		Invoke-GuiDeploymentMediaRobocopy -Source $isoRoot -Destination $mediaRoot -CancellationState $CancellationState -Telemetry $telemetry
	}
	catch
	{
		if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue) { Write-SwallowedException -ErrorRecord $_ -Source 'DeploymentMediaBuilder.Execution.Invoke-GuiDeploymentMediaBuild:catch869' -Severity Debug }

		$primaryError = $_
	}
	finally
	{
		if ($diskImage)
		{
			try { Invoke-GuiDeploymentMediaIsoDismountCleanup -ImagePath ([string]$Plan.SourceIso) -CancellationState $CancellationState -Telemetry $telemetry }
			catch {
				if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue) { Write-SwallowedException -ErrorRecord $_ -Source 'DeploymentMediaBuilder.Execution.Invoke-GuiDeploymentMediaBuild:catch878' -Severity Debug }
			 $cleanupError = $_ }
		}
	}

	if ($cleanupError -and $primaryError)
	{
		throw ('Deployment media source ISO cleanup failed after source copy error. Source error: {0} Cleanup error: {1}' -f $primaryError.Exception.Message, $cleanupError.Exception.Message)
	}
	if ($cleanupError)
	{
		throw ('Failed to cleanup mounted ISO: {0}' -f $cleanupError.Exception.Message)
	}
	if ($primaryError)
	{
		throw $primaryError
	}

	Assert-GuiDeploymentMediaNotCancelled -CancellationState $CancellationState -Stage 'Prepare deployment media'
	$installImagePath = Get-GuiDeploymentMediaPreparedInstallImagePath -MediaRoot $mediaRoot
	Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message ('Prepared install image: {0}.' -f $installImagePath)

	if (-not [string]::IsNullOrWhiteSpace([string]$Plan.AutounattendPath))
	{
		Assert-GuiDeploymentMediaNotCancelled -CancellationState $CancellationState -Stage 'Stage autounattend.xml'
		$answerDestination = Join-Path $mediaRoot 'autounattend.xml'
		Copy-Item -LiteralPath ([string]$Plan.AutounattendPath) -Destination $answerDestination -Force -ErrorAction Stop
		Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message ('Staged autounattend.xml at {0}.' -f $answerDestination)
	}

	if ([bool]$Plan.IncludeBaselineTweaks)
	{
		Assert-GuiDeploymentMediaNotCancelled -CancellationState $CancellationState -Stage 'Stage Baseline setup customizations'
		$selectedTweaks = if ($null -ne $SelectedTweaks) { @($SelectedTweaks) } else { @(Get-GuiDeploymentMediaSelectedTweaksForSetup) }
		if ($selectedTweaks.Count -lt 1)
		{
			throw 'Baseline setup customizations were requested, but no GUI tweaks are selected.'
		}

		$setupScriptsDirectory = Join-Path $mediaRoot 'sources\$OEM$\$$\Setup\Scripts'
		[void][System.IO.Directory]::CreateDirectory($setupScriptsDirectory)
		$setupPlanPath = Join-Path $setupScriptsDirectory 'Baseline-DeploymentPlan.json'
		$setupPlan = [pscustomobject]@{
			CreatedUtc = [DateTime]::UtcNow
			Source = 'Baseline Deployment Media Builder'
			SelectedTweaks = @($selectedTweaks)
		}
		[System.IO.File]::WriteAllText($setupPlanPath, ($setupPlan | ConvertTo-Json -Depth 12), [System.Text.Encoding]::UTF8)
		Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message ('Staged selected Baseline setup customization plan at {0}.' -f $setupPlanPath)
	}

	Invoke-GuiDeploymentMediaDriverInjection -Plan $Plan -MediaRoot $mediaRoot -MountRoot $mountRoot -ProgressCallback $ProgressCallback -CancellationState $CancellationState -Telemetry $telemetry

	switch ([string]$Plan.OutputMode)
	{
		'Export Working Folder Only'
		{
			Assert-GuiDeploymentMediaNotCancelled -CancellationState $CancellationState -Stage 'Export working folder'
			$outputPath = $mediaRoot
		}
		'Create ISO'
		{
			Assert-GuiDeploymentMediaNotCancelled -CancellationState $CancellationState -Stage 'Create ISO output'
			$oscdimgPath = Resolve-GuiDeploymentMediaOscdimgPath
			$etfsbootPath = Join-Path $mediaRoot 'boot\etfsboot.com'
			$efisysPath = Join-Path $mediaRoot 'efi\microsoft\boot\efisys.bin'
			if (-not (Test-Path -LiteralPath $etfsbootPath -PathType Leaf))
			{
				throw ('BIOS boot sector file is missing: {0}' -f $etfsbootPath)
			}
			if (-not (Test-Path -LiteralPath $efisysPath -PathType Leaf))
			{
				throw ('UEFI boot sector file is missing: {0}' -f $efisysPath)
			}
			$outputPath = Join-Path ([string]$Plan.WorkingDirectory) ('Baseline-DeploymentMedia-{0}.iso' -f ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')))
			$bootData = '-bootdata:2#p0,e,b{0}#pEF,e,b{1}' -f $etfsbootPath, $efisysPath
			$arguments = @('-m', '-o', '-u2', '-udfver102', $bootData, $mediaRoot, $outputPath)
			Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message ('Creating ISO at {0}.' -f $outputPath)
			$oscdimgTimeoutSeconds = Get-GuiDeploymentMediaStageTimeoutSeconds -OperationStartedUtc $startedUtc -GlobalTimeoutSeconds $GlobalTimeoutSeconds -StageTimeoutSeconds 7200
			$null = Invoke-GuiDeploymentMediaProcess -FilePath $oscdimgPath -ArgumentList $arguments -TimeoutSeconds $oscdimgTimeoutSeconds -AllowedExitCodes @(0) -CancellationState $CancellationState -StageName 'Create ISO image' -Telemetry $telemetry
			if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf))
			{
				throw ('oscdimg.exe completed but ISO output was not created: {0}' -f $outputPath)
			}
		}
		'Create USB'
		{
			Assert-GuiDeploymentMediaNotCancelled -CancellationState $CancellationState -Stage 'Create USB output'
			$targetRoot = [System.IO.Path]::GetFullPath([string]$Plan.UsbTargetRoot)
			$bootsectPath = Join-Path $mediaRoot 'boot\bootsect.exe'
			if (-not (Test-Path -LiteralPath $bootsectPath -PathType Leaf))
			{
				throw ('USB boot sector tool is missing from prepared media: {0}' -f $bootsectPath)
			}
			Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message ('Copying prepared media to USB target {0}.' -f $targetRoot)
			Invoke-GuiDeploymentMediaRobocopy -Source $mediaRoot -Destination $targetRoot -CancellationState $CancellationState -Telemetry $telemetry
			$driveArgument = [System.IO.Path]::GetPathRoot($targetRoot).TrimEnd('\')
			$null = Invoke-GuiDeploymentMediaProcess -FilePath $bootsectPath -ArgumentList @('/nt60', $driveArgument, '/force') -TimeoutSeconds 300 -AllowedExitCodes @(0) -CancellationState $CancellationState -StageName 'Write USB boot sector' -Telemetry $telemetry
			$outputPath = $targetRoot
			$targetInstallImage = Join-Path $targetRoot ('sources\{0}' -f [System.IO.Path]::GetFileName($installImagePath))
			if (-not (Test-Path -LiteralPath $targetInstallImage -PathType Leaf))
			{
				throw ('USB copy completed but install image was not present at {0}.' -f $targetInstallImage)
			}
		}
		default
		{
			throw ('Unsupported deployment media output mode: {0}' -f $Plan.OutputMode)
		}
	}

	$result = [pscustomobject]@{
		StartedUtc = $startedUtc
		CompletedUtc = [DateTime]::UtcNow
		OutputMode = [string]$Plan.OutputMode
		BuildRoot = $buildRoot
		MediaRoot = $mediaRoot
		OutputPath = $outputPath
		ReportPath = $null
		Telemetry = $telemetry
	}
	$result.ReportPath = Save-GuiDeploymentMediaBuildReport -Plan $Plan -BuildResult $result
	Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message ('Deployment media build completed. Report: {0}.' -f $result.ReportPath)
	return $result
}

function Save-GuiDeploymentMediaBuildReport
{
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Plan,
		[object]$BuildResult = $null
	)

	if (-not [bool]$Plan.IsValid)
	{
		throw 'Deployment media build plan has blocking validation errors.'
	}

	$reportDirectory = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Baseline\DeploymentMediaBuilder\Reports'
	[void][System.IO.Directory]::CreateDirectory($reportDirectory)
	$reportPath = Join-Path $reportDirectory ('BuildPlan-{0}.json' -f ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')))
	$report = [pscustomobject]@{
		ReportType = 'DeploymentMediaBuildReport'
		GeneratedUtc = [DateTime]::UtcNow
		Plan = $Plan
		BuildResult = $BuildResult
	}
	$json = $report | ConvertTo-Json -Depth 12
	[System.IO.File]::WriteAllText($reportPath, $json, [System.Text.Encoding]::UTF8)
	return $reportPath
}

