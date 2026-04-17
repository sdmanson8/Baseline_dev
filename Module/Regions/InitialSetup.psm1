using module ..\Logging.psm1
using module ..\SharedHelpers.psm1

#region Initial Setup

<#
	.SYNOPSIS
	Create a restore point for the system drive before changes are applied.

	.DESCRIPTION
	Ensures System Restore is available on the system drive, temporarily allows
	immediate restore point creation, creates a restore point named for the
	current Windows version, and restores the prior System Restore state.

	.EXAMPLE
	CreateRestorePoint

	.NOTES
	Machine-wide
#>
function CreateRestorePoint
{
	LogInfo "Creating Restore Point"
	# Write-Host: intentional — user-visible progress indicator
	Write-Host "Creating System Restore Point - " -NoNewline
	$restoreSystemProtection = $false
	$createdSuccessfully = $false
	try
	{
		# Ensure the Volume Shadow Copy service is running — both Checkpoint-Computer
		# and the WMI fallback depend on it. On VMs or hardened systems it may be
		# set to Manual/Disabled and not started.
		try
		{
			$vssSvc = Get-Service -Name VSS -ErrorAction Stop
			if ($vssSvc.Status -ne 'Running')
			{
				LogInfo "Starting Volume Shadow Copy (VSS) service (was $($vssSvc.Status))."
				if ($vssSvc.StartType -eq 'Disabled')
				{
					Set-Service -Name VSS -StartupType Manual -ErrorAction Stop
				}
				Start-Service -Name VSS -ErrorAction Stop
			}
		}
		catch
		{
			LogWarning "Could not ensure VSS service is running: $($_.Exception.Message)"
		}

		$SystemDriveUniqueID = (Get-Volume | Where-Object -FilterScript {$_.DriveLetter -eq "$($env:SystemDrive[0])"}).UniqueID
		$SystemProtection = ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SPP\Clients" -ErrorAction Ignore)."{09F7EDC5-294E-4180-AF6A-FB0E6A0E9513}") | Where-Object -FilterScript {$_ -match [regex]::Escape($SystemDriveUniqueID)}

		if ($null -eq $SystemProtection)
		{
			# Verify whether System Protection is actually disabled before attempting to enable it,
			# because the SPP\Clients registry check can return null on newer Windows 11 builds
			# even when System Protection is already on.
			$srpEnabled = $false
			try
			{
				$srpStatus = Get-CimInstance -ClassName SystemRestoreConfig -Namespace 'root\default' -ErrorAction Stop
				if ($srpStatus -and $srpStatus.RPSessionInterval -eq 1) { $srpEnabled = $true }
			}
			catch { $srpEnabled = $false }

			if (-not $srpEnabled)
			{
				$restoreSystemProtection = $true
				Enable-ComputerRestore -Drive $env:SystemDrive -ErrorAction Stop
			}
		}

		# Never skip creating a restore point
		New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name SystemRestorePointCreationFrequency -PropertyType DWord -Value 0 -Force -ErrorAction Stop | Out-Null

		$osName = (Get-OSInfo).OSName
		$displayVersion = Get-BaselineDisplayVersion

		$restorePointDescription = "Baseline | Utility for $osName"
		if (-not [string]::IsNullOrWhiteSpace([string]$displayVersion))
		{
			$restorePointDescription = "$restorePointDescription $displayVersion"
		}

		# Try Checkpoint-Computer in a background job with a timeout to prevent hanging
		$checkpointSucceeded = $false
		$restorePointTimeoutSeconds = 120
		try
		{
			$job = Start-Job -ScriptBlock {
				param ($Desc)
				Checkpoint-Computer -Description $Desc -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
			} -ArgumentList $restorePointDescription
			$finished = $job | Wait-Job -Timeout $restorePointTimeoutSeconds
			if ($finished)
			{
				$job | Receive-Job -ErrorAction Stop | Out-Null
				$checkpointSucceeded = $true
			}
			else
			{
				$job | Stop-Job -ErrorAction SilentlyContinue
				LogWarning "Checkpoint-Computer timed out after $restorePointTimeoutSeconds seconds. Trying WMI fallback."
			}
			$job | Remove-Job -Force -ErrorAction SilentlyContinue
		}
		catch
		{
			LogWarning "Checkpoint-Computer failed: $($_.Exception.Message). Trying WMI fallback."
			if ($job) { $job | Remove-Job -Force -ErrorAction SilentlyContinue }
		}

		if (-not $checkpointSucceeded)
		{
			try
			{
				$sr = [wmiclass]'\\.\root\default:SystemRestore'
				$result = $sr.CreateRestorePoint($restorePointDescription, 12, 100)
				if ($result.ReturnValue -ne 0)
				{
					throw "WMI SystemRestore.CreateRestorePoint failed with return code $($result.ReturnValue)"
				}
				$checkpointSucceeded = $true
			}
			catch
			{
				throw "Restore point creation failed: $($_.Exception.Message)"
			}
		}

		# Revert the System Restore checkpoint creation frequency to 1440 minutes
		New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name SystemRestorePointCreationFrequency -PropertyType DWord -Value 1440 -Force -ErrorAction Stop | Out-Null

		# Turn off System Protection for the system drive if it was turned off before without deleting the existing restore points
		if ($restoreSystemProtection)
		{
			LogInfo "Disabling System Restore again"
			Disable-ComputerRestore -Drive $env:SystemDrive -ErrorAction Stop | Out-Null
		}
		Write-ConsoleStatus -Status success
		$createdSuccessfully = $true
	}
	catch
	{
		Write-ConsoleStatus -Status failed
		LogError "Failed to create a restore point: $($_.Exception.Message)"
	}

	return $createdSuccessfully
}
<#
	.SYNOPSIS
	Check whether WinGet is installed and install it if needed.

	.DESCRIPTION
	Validates that WinGet is present and functional. If it is missing or broken,
	the function downloads a bootstrap installer script, executes it, and
	validates the WinGet installation again before continuing.

	.EXAMPLE
	CheckWinGet

	.NOTES
	Machine-wide
#>
function CheckWinGet
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $false)]
		[object]
		$LoadingSplash = $Global:LoadingSplash
	)

	$startupSplashUpdateCommand = Get-Command -Name 'Set-BootstrapLoadingSplashState' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$resetWinGetAvailabilityCommand = Get-Command -Name 'Reset-WinGetAvailabilityState' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$updateStartupSplashState = {
		param(
			[string]$StatusText,
			[switch]$Indeterminate,
			[switch]$HideProgressBar
		)

		if (-not $LoadingSplash -or -not $startupSplashUpdateCommand)
		{
			return
		}

		try
		{
			& $startupSplashUpdateCommand -Splash $LoadingSplash -StatusText $StatusText -Indeterminate:$Indeterminate -HideProgressBar:$HideProgressBar | Out-Null
		}
		catch
		{
			$null = $_
		}
	}.GetNewClosure()

	$installerMetadata = Get-WinGetBootstrapInstallerMetadata
	$installerVersion = [string]$installerMetadata.Version
	$installerSha256 = [string]$installerMetadata.Sha256
	$installerArguments = @(Get-WinGetBootstrapInstallerArguments)
	$installerPath = $null
	$stdoutLog = $null
	$stderrLog = $null
	$stdoutLines = @()
	$stderrLines = @()

	try
	{
		$osInfo = Get-OSInfo
		$osVersion = $osInfo.DisplayVersion
		$currentBuild = $osInfo.CurrentBuild
		$osName = $osInfo.OSName

		LogInfo "Detected OS: $osName (Build $currentBuild, Release $osVersion)"

		$checkingStatusText = Get-BaselineLocalizedString -Key 'Progress_CheckingInstallStatus' -Fallback 'Checking installation status...'
		Write-ConsoleStatus -Action $checkingStatusText
		& $updateStartupSplashState -StatusText $checkingStatusText -Indeterminate

		$wingetVersion = Get-WinGetVersion
		if ($wingetVersion)
		{
			$resolvedWingetPath = Resolve-WinGetExecutable
			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingPackageManager' -Fallback 'Checking {0}' -FormatArgs @('WinGet'))
			if (-not [string]::IsNullOrWhiteSpace([string]$resolvedWingetPath))
			{
				LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_ResolvedPackageManagerExecutable' -Fallback 'Resolved {0} executable: {1}' -FormatArgs @('WinGet', $resolvedWingetPath))
			}
			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerAlreadyInstalled' -Fallback '{0} is already installed and working. Version: {1}' -FormatArgs @('WinGet', $wingetVersion))
			Write-ConsoleStatus -Status success
			& $updateStartupSplashState -StatusText (Get-BaselineLocalizedString -Key 'Progress_WinGet_Ready' -Fallback 'WinGet is ready') -HideProgressBar
			return
		}

		LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerNotFunctional' -Fallback '{0} not found or not functional' -FormatArgs @('WinGet'))
		$installStatusText = Get-BaselineLocalizedString -Key 'Progress_Installing' -Fallback 'Installing {0}...' -FormatArgs @('WinGet')
		Write-ConsoleStatus -Action $installStatusText
		& $updateStartupSplashState -StatusText $installStatusText -Indeterminate

		try
		{
			$installerUrl = [string]$installerMetadata.Uri
			$installerPath = Join-Path $env:TEMP ("winget-install-{0}.ps1" -f $installerVersion)
			$stdoutLog = Join-Path $env:TEMP "winget-install-stdout.log"
			$stderrLog = Join-Path $env:TEMP "winget-install-stderr.log"

			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_DownloadingPackageManagerInstaller' -Fallback 'Downloading {0} installer from {1}' -FormatArgs @('WinGet', $installerUrl))
			Invoke-DownloadFile -Uri $installerUrl -OutFile $installerPath

			if (-not (Test-Path $installerPath) -or (Get-Item $installerPath).Length -eq 0)
			{
				throw "winget installer download failed or produced an empty file at $installerPath"
			}

			& $updateStartupSplashState -StatusText (Get-BaselineLocalizedString -Key 'Progress_Processing' -Fallback 'Processing {0}...' -FormatArgs @('WinGet installer verification')) -Indeterminate
			$null = Assert-FileHash `
				-Path $installerPath `
				-ExpectedSha256 $installerSha256 `
				-Label ([string]$installerMetadata.Label)
			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerDownloadVerified' -Fallback 'Download and SHA-256 verification completed for {0} v{1}' -FormatArgs @('WinGet', $installerVersion))

			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_ExecutingInstallerScript' -Fallback 'Executing installer script...')
			$executingStatusText = Get-BaselineLocalizedString -Key 'Progress_Installing' -Fallback 'Installing {0}...' -FormatArgs @('WinGet')
			& $updateStartupSplashState -StatusText $executingStatusText -Indeterminate

			$process = Start-Process powershell.exe -ArgumentList (@(
				'-NoProfile',
				'-ExecutionPolicy', 'Bypass',
				'-File', "`"$installerPath`""
			) + $installerArguments) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -ErrorAction Stop

			if (Test-Path $stdoutLog)
			{
				$stdoutLines = @(Get-Content $stdoutLog | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
				foreach ($stdoutLine in $stdoutLines)
				{
					LogInfo "winget-installer: $stdoutLine"
				}
			}

			if (Test-Path $stderrLog)
			{
				$stderrLines = @(Get-Content $stderrLog | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
				foreach ($stderrLine in $stderrLines)
				{
					LogError "winget-installer: $stderrLine"
				}
			}

			$installerCompletedSuccessfully = ($process.ExitCode -eq 0 -or $null -eq $process.ExitCode)
			$installerReportedErrors = ($stderrLines.Count -gt 0)
			if ($installerCompletedSuccessfully -and -not $installerReportedErrors)
			{
				LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerInstallerScriptCompletedSuccessfully' -Fallback '{0} installer script completed successfully' -FormatArgs @('WinGet'))
			}
			elseif ($installerCompletedSuccessfully -and $installerReportedErrors)
			{
				LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerInstallerScriptReportedErrors' -Fallback '{0} installer script reported errors despite a zero exit code. Running validation before accepting the install.' -FormatArgs @('WinGet'))
			}
			else
			{
				LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerInstallerScriptReportedExitCode' -Fallback '{0} installer script reported exit code: {1}' -FormatArgs @('WinGet', $process.ExitCode))
			}

			Start-Sleep -Seconds 5
			$wingetVersion = Get-WinGetVersion
			if ($wingetVersion)
			{
				LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerValidationSucceeded' -Fallback '{0} validation succeeded. Version: {1}' -FormatArgs @('WinGet', $wingetVersion))
				Write-ConsoleStatus -Status success
				& $updateStartupSplashState -StatusText (Get-BaselineLocalizedString -Key 'Progress_WinGet_Ready' -Fallback 'WinGet is ready') -HideProgressBar
				return
			}

			if ($installerCompletedSuccessfully -and -not $installerReportedErrors)
			{
				LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerInstallationCompletedButUnavailable' -Fallback '{0} installation completed, but {1} is not available in the current session yet. A new session may be required.' -FormatArgs @('WinGet', 'winget.exe'))
				Write-ConsoleStatus -Status success
				& $updateStartupSplashState -StatusText (Get-BaselineLocalizedString -Key 'Progress_WinGet_Ready' -Fallback 'WinGet is ready') -HideProgressBar
				return
			}

			$validationFailureMessage = if ($installerReportedErrors)
			{
				"WinGet installer reported errors and winget.exe is still unavailable. First error: $([string]$stderrLines[0].Trim())"
			}
			else
			{
				Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerInstallationFailedValidation' -Fallback '{0} installation failed validation after the installer completed.' -FormatArgs @('WinGet')
			}
			throw $validationFailureMessage
		}
		catch
		{
			LogError (Get-BaselineBilingualString -Key 'Bootstrap_ErrorDuringPackageManagerInstallation' -Fallback 'Error during {0} installation: {1}' -FormatArgs @('WinGet', $_))
			$repairStatusText = Get-BaselineLocalizedString -Key 'Progress_WinGet_Updating' -Fallback 'Updating WinGet...'
			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_AttemptingPackageManagerRepair' -Fallback 'Attempting {0} repair via {1}...' -FormatArgs @('WinGet', 'Microsoft.WinGet.Client'))
			Write-ConsoleStatus -Action $repairStatusText
			& $updateStartupSplashState -StatusText $repairStatusText -Indeterminate

			try
			{
				Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
				Install-PackageProvider -Name NuGet -Force -ErrorAction Stop | Out-Null
				Install-Module Microsoft.WinGet.Client -Force -ErrorAction Stop | Out-Null
				Import-Module Microsoft.WinGet.Client -ErrorAction Stop
				Repair-WinGetPackageManager -ErrorAction Stop
				Start-Sleep -Seconds 3
				$wingetVersion = Get-WinGetVersion
				if ($wingetVersion)
				{
					LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerRepairSucceeded' -Fallback '{0} repair succeeded. Version: {1}' -FormatArgs @('WinGet', $wingetVersion))
					Write-ConsoleStatus -Status success
					& $updateStartupSplashState -StatusText (Get-BaselineLocalizedString -Key 'Progress_WinGet_Ready' -Fallback 'WinGet is ready') -HideProgressBar
					return
				}

				LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerRepairCompletedButUnavailable' -Fallback '{0} repair completed but {1} still not resolvable in this session.' -FormatArgs @('WinGet', 'winget.exe'))
				Write-ConsoleStatus -Status success
				& $updateStartupSplashState -StatusText (Get-BaselineLocalizedString -Key 'Progress_WinGet_Ready' -Fallback 'WinGet is ready') -HideProgressBar
			}
			catch
			{
				LogError (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerRepairFailed' -Fallback '{0} repair also failed: {1}' -FormatArgs @('WinGet', $_))
				Write-ConsoleStatus -Status failed
				& $updateStartupSplashState -HideProgressBar
			}
			return
		}
	}
	finally
	{
		if ($installerPath -and (Test-Path -LiteralPath $installerPath))
		{
			Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
		}
		if ($stdoutLog -and (Test-Path -LiteralPath $stdoutLog))
		{
			Remove-Item -LiteralPath $stdoutLog -Force -ErrorAction SilentlyContinue
		}
		if ($stderrLog -and (Test-Path -LiteralPath $stderrLog))
		{
			Remove-Item -LiteralPath $stderrLog -Force -ErrorAction SilentlyContinue
		}

		if ($resetWinGetAvailabilityCommand)
		{
			try
			{
				& $resetWinGetAvailabilityCommand | Out-Null
			}
			catch
			{
				$null = $_
			}
		}
	}
}

<#
	.SYNOPSIS
	Check WinGet and Chocolatey together during startup and bootstrap whichever package managers are missing.

	.NOTES
	Startup-only helper used by InitialActions.
#>
function Initialize-PackageManagersBootstrap
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $false)]
		[object]
		$LoadingSplash = $Global:LoadingSplash,

		[Parameter(Mandatory = $false)]
		[bool]
		$IncludeWinGet = $true
	)

	$startupSplashUpdateCommand = Get-Command -Name 'Set-BootstrapLoadingSplashState' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$resetWinGetAvailabilityCommand = Get-Command -Name 'Reset-WinGetAvailabilityState' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$resetChocolateyAvailabilityCommand = Get-Command -Name 'Reset-ChocolateyAvailabilityState' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$updateStartupSplashState = {
		param(
			[string]$StatusText,
			[switch]$Indeterminate,
			[switch]$HideProgressBar
		)

		if (-not $LoadingSplash -or -not $startupSplashUpdateCommand)
		{
			return
		}

		try
		{
			& $startupSplashUpdateCommand -Splash $LoadingSplash -StatusText $StatusText -Indeterminate:$Indeterminate -HideProgressBar:$HideProgressBar | Out-Null
		}
		catch
		{
			$null = $_
		}
	}.GetNewClosure()

	$moduleRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
	$loggingModulePath = Join-Path $moduleRoot 'Logging.psm1'
	$sharedHelpersModulePath = Join-Path $moduleRoot 'SharedHelpers.psm1'
	$logFilePath = if ($Global:LogFilePath) { [string]$Global:LogFilePath } else { $null }
	$results = [System.Collections.Generic.List[object]]::new()
	$jobs = @()

	$jobScriptBlock = {
		param(
			[string]$PackageManager,
			[string]$LoggingModulePath,
			[string]$SharedHelpersModulePath,
			[string]$LogFilePath
		)

		Import-Module -Name $LoggingModulePath -Force -ErrorAction Stop
		Import-Module -Name $SharedHelpersModulePath -Force -ErrorAction Stop
		if (-not [string]::IsNullOrWhiteSpace($LogFilePath))
		{
			Set-LogFile -Path $LogFilePath
		}

		switch ($PackageManager)
		{
			'WinGet' { Invoke-WinGetBootstrap }
			'Chocolatey' { Invoke-ChocolateyBootstrap }
			default { throw "Unsupported package manager '$PackageManager'." }
		}
	}

	try
	{
		$checkingStatusText = Get-BaselineLocalizedString -Key 'Progress_CheckingInstallStatus' -Fallback 'Checking installation status...'
		Write-ConsoleStatus -Action $checkingStatusText
		& $updateStartupSplashState -StatusText $checkingStatusText -Indeterminate

		if ($IncludeWinGet)
		{
			$wingetVersion = Get-WinGetVersion
			if ($wingetVersion)
			{
				LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerAlreadyInstalled' -Fallback '{0} is already installed and working. Version: {1}' -FormatArgs @('WinGet', $wingetVersion))
				[void]$results.Add([pscustomobject]@{
					PackageManager = 'WinGet'
					Available      = $true
					Installed      = $false
					Repaired       = $false
					Version        = [string]$wingetVersion
					Success        = $true
					Error          = $null
				})
			}
			else
			{
				try
				{
					$jobs += Start-Job -Name 'WinGetBootstrap' -ScriptBlock $jobScriptBlock -ArgumentList @('WinGet', $loggingModulePath, $sharedHelpersModulePath, $logFilePath)
				}
				catch
				{
					LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_FailedToStartPackageManagerBootstrapJob' -Fallback 'Failed to start {0} bootstrap job: {1}' -FormatArgs @('WinGet', $_.Exception.Message))
					[void]$results.Add([pscustomobject]@{
						PackageManager = 'WinGet'
						Available      = $false
						Installed      = $false
						Repaired       = $false
						Version        = $null
						Success        = $false
						Error          = $_.Exception.Message
					})
				}
			}
		}

		$chocolateyVersion = Get-ChocolateyVersion
		if ($chocolateyVersion)
		{
			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerAlreadyInstalled' -Fallback '{0} is already installed and working. Version: {1}' -FormatArgs @('Chocolatey', $chocolateyVersion))
			[void]$results.Add([pscustomobject]@{
				PackageManager = 'Chocolatey'
				Available      = $true
				Installed      = $false
				Repaired       = $false
				Version        = [string]$chocolateyVersion
				Success        = $true
				Error          = $null
			})
		}
		else
		{
			if (-not (Test-BaselineEnvironmentFlagEnabled -Name 'BASELINE_ALLOW_CHOCOLATEY_BOOTSTRAP'))
			{
				LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_SkippingChocolateyStartupBootstrapApprovalRequired' -Fallback 'Skipping automatic Chocolatey bootstrap during startup because explicit approval is required. Chocolatey will be installed on demand after approval.')
				[void]$results.Add([pscustomobject]@{
					PackageManager = 'Chocolatey'
					Available      = $false
					Installed      = $false
					Repaired       = $false
					Version        = $null
					Success        = $true
					Error          = $null
				})
			}
			else
			{
				try
				{
					$jobs += Start-Job -Name 'ChocolateyBootstrap' -ScriptBlock $jobScriptBlock -ArgumentList @('Chocolatey', $loggingModulePath, $sharedHelpersModulePath, $logFilePath)
				}
				catch
				{
					LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_FailedToStartPackageManagerBootstrapJob' -Fallback 'Failed to start {0} bootstrap job: {1}' -FormatArgs @('Chocolatey', $_.Exception.Message))
					[void]$results.Add([pscustomobject]@{
						PackageManager = 'Chocolatey'
						Available      = $false
						Installed      = $false
						Repaired       = $false
						Version        = $null
						Success        = $false
						Error          = $_.Exception.Message
					})
				}
			}
		}

		if ($jobs.Count -gt 0)
		{
			$installStatusText = if ($jobs.Count -gt 1)
			{
				Get-BaselineLocalizedString -Key 'Progress_InstallingPackageManagers' -Fallback 'Installing WinGet and Chocolatey...'
			}
			else
			{
				Get-BaselineLocalizedString -Key 'Progress_Installing' -Fallback 'Installing {0}...' -FormatArgs @([string]$jobs[0].Name.Replace('Bootstrap', ''))
			}

			Write-ConsoleStatus -Action $installStatusText
			& $updateStartupSplashState -StatusText $installStatusText -Indeterminate

			while ($jobs.Count -gt 0)
			{
				$null = Wait-Job -Job $jobs -Any -Timeout 1
				$completedJobs = @($jobs | Where-Object { $_.State -ne 'Running' })
				foreach ($completedJob in @($completedJobs))
				{
					try
					{
						$jobResult = Receive-Job -Job $completedJob -ErrorAction Stop | Select-Object -First 1
						if ($jobResult)
						{
							[void]$results.Add($jobResult)
						}
					}
					catch
					{
						LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerBootstrapJobDidNotReturnResult' -Fallback "Package manager bootstrap job '{0}' did not return a result: {1}" -FormatArgs @($completedJob.Name, $_.Exception.Message))
						[void]$results.Add([pscustomobject]@{
							PackageManager = [string]$completedJob.Name.Replace('Bootstrap', '')
							Available      = $false
							Installed      = $false
							Repaired       = $false
							Version        = $null
							Success        = $false
							Error          = $_.Exception.Message
						})
					}
					finally
					{
						Remove-Job -Job $completedJob -Force -ErrorAction SilentlyContinue
					}
				}

				$jobs = @($jobs | Where-Object { $_.State -eq 'Running' })
				if ($jobs.Count -gt 0)
				{
					$runningNames = @($jobs | ForEach-Object { [string]$_.Name })
					$runningStatusText = if ($runningNames.Count -gt 1)
					{
						Get-BaselineLocalizedString -Key 'Progress_InstallingPackageManagers' -Fallback 'Installing WinGet and Chocolatey...'
					}
					else
					{
						Get-BaselineLocalizedString -Key 'Progress_Installing' -Fallback 'Installing {0}...' -FormatArgs @([string]$runningNames[0].Replace('Bootstrap', ''))
					}
					& $updateStartupSplashState -StatusText $runningStatusText -Indeterminate
				}
			}
		}

		$failedResults = @($results | Where-Object { -not [bool]$_.Success })
		if ($failedResults.Count -gt 0)
		{
			Write-ConsoleStatus -Status failed
			foreach ($failedResult in @($failedResults))
			{
				$packageManagerName = [string]$failedResult.PackageManager
				$failureText = if (-not [string]::IsNullOrWhiteSpace([string]$failedResult.Error))
				{
					$failedResult.Error
				}
					else
					{
						(Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerBootstrapDidNotCompleteSuccessfully' -Fallback '{0} bootstrap did not complete successfully.' -FormatArgs @($packageManagerName))
					}
				LogWarning $failureText
			}
		}
		else
		{
			Write-ConsoleStatus -Status success
		}

		return @($results)
	}
	catch
	{
		LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerStartupBootstrapFailedUnexpectedly' -Fallback 'Package manager startup bootstrap failed unexpectedly: {0}' -FormatArgs @($_.Exception.Message))
		Write-ConsoleStatus -Status failed
		return @($results)
	}
	finally
	{
		if ($IncludeWinGet -and $resetWinGetAvailabilityCommand)
		{
			try
			{
				& $resetWinGetAvailabilityCommand | Out-Null
			}
			catch
			{
				$null = $_
			}
		}

		if ($resetChocolateyAvailabilityCommand)
		{
			try
			{
				& $resetChocolateyAvailabilityCommand | Out-Null
			}
			catch
			{
				$null = $_
			}
		}

		& $updateStartupSplashState -HideProgressBar
	}
}

<#
	.SYNOPSIS
	Hide the Spotlight "About this picture" desktop icon.

	.DESCRIPTION
	Removes the Spotlight namespace entry from the desktop and sets the matching
	HideDesktopIcons value so the icon stays hidden for the current user.

	.EXAMPLE
	DesktopRegistry

	.NOTES
	Current user
#>
function DesktopRegistry
{
	# Write-Host: intentional — user-visible progress indicator
	Write-Host 'Removing "About this Picture" from Desktop - ' -NoNewline
	LogInfo 'Removing "About this Picture" from Desktop'
    # Define registry paths and key/value
    $namespaceKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{2cc5ca98-6485-489a-920e-b3e88a6ccce3}"
    $hideIconsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
    $valueName = "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}"
    $valueData = 1

    # Remove the specified namespace registry key
    try
	{
        Remove-Item -Path $namespaceKeyPath -Force -ErrorAction SilentlyContinue | Out-Null
    }
	catch
	{
        LogError "Registry key not found or could not be removed: $namespaceKeyPath"
    }

    # Ensure the HideDesktopIcons path exists and set the DWORD value
    try
	{
        if (-not (Test-Path -Path $hideIconsPath))
		{
            New-Item -Path $hideIconsPath -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -LiteralPath $hideIconsPath -Name $valueName -Value $valueData -Type DWord -ErrorAction Stop | Out-Null
		Write-ConsoleStatus -Status success
    }
	catch
	{
        Write-ConsoleStatus -Status failed
        LogError "Failed to set registry value: $valueName"
    }
}

<#
	.SYNOPSIS
	Refresh the current process PATH from the machine and user environment blocks.
#>
function Update-ProcessPathFromRegistry
{
	$MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
	$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
	$env:Path = (@($MachinePath, $UserPath) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ";"
}

<#
	.SYNOPSIS
	Restart File Explorer so desktop and shell changes apply immediately.

	.DESCRIPTION
	Stops the Explorer foreground process so desktop, taskbar, and File Explorer
	changes can be reloaded by the shell.

	.EXAMPLE
	Stop-Foreground

	.NOTES
	Current user
#>
function Stop-Foreground
{
	LogInfo "Stopping explorer.exe to apply shell changes"
	Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue | Out-Null
}

#endregion Initial Setup

Export-ModuleMember -Function '*'
