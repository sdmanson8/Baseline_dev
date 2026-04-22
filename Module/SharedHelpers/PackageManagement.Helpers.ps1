# Shared helper slice for Baseline.

<#
    .SYNOPSIS
    Internal function Update-ProcessPathFromRegistry.
#>

function Update-ProcessPathFromRegistry
{
	<# .SYNOPSIS Refreshes $env:Path from machine and user registry environment variables. #>
	$MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
	$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
	$env:Path = (@($MachinePath, $UserPath) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ";"
}

<#
    .SYNOPSIS
    Internal function .
#>
function Get-ApplicationPackageIdCandidates
{
	<# .SYNOPSIS Splits a package identifier into normalized candidate IDs. #>
	param(
		[string]$PackageId
	)

	if ([string]::IsNullOrWhiteSpace($PackageId))
	{
		return @()
	}

	return @(
		[string]$PackageId -split ';' |
			ForEach-Object { [string]$_.Trim() } |
			Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
			Select-Object -Unique
	)
}

<#
    .SYNOPSIS
    Internal function Resolve-ApplicationPackageId.
#>

function Resolve-ApplicationPackageId
{
	<# .SYNOPSIS Chooses the canonical package ID from a candidate list. #>
	param(
		[string]$PackageId
	)

	$candidates = @(Get-ApplicationPackageIdCandidates -PackageId $PackageId)
	if ($candidates.Count -eq 0)
	{
		return $null
	}

	return [string]$candidates[-1]
}

<#
    .SYNOPSIS
    Internal function Test-ApplicationPackageIdInCache.
#>

function Test-ApplicationPackageIdInCache
{
	<# .SYNOPSIS Tests whether any package ID candidate exists in a cache. #>
	param(
		[string]$PackageId,
		[hashtable]$Cache
	)

	if (-not $Cache)
	{
		return $false
	}

	foreach ($candidate in @(Get-ApplicationPackageIdCandidates -PackageId $PackageId))
	{
		if ($Cache.ContainsKey([string]$candidate))
		{
			return $true
		}
	}

	return $false
}

<#
    .SYNOPSIS
    Internal function Write-PackageHelperWarning.
#>

function Write-PackageHelperWarning
{
	<# .SYNOPSIS Writes a warning via LogWarning or Write-Warning fallback. #>
	param([string]$Message)

	if ([string]::IsNullOrWhiteSpace($Message))
	{
		return
	}

	if (Get-Command -Name 'LogWarning' -CommandType Function -ErrorAction SilentlyContinue)
	{
		LogWarning $Message
	}
	else
	{
		Write-Warning $Message
	}
}

<#
    .SYNOPSIS
    Internal function Resolve-WinGetExecutable.
#>

function Resolve-WinGetExecutable
{
	<# .SYNOPSIS Resolves the winget.exe path from command lookup or known install locations. #>
	Update-ProcessPathFromRegistry

	$WingetCommand = Get-Command -Name winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source -ErrorAction SilentlyContinue
	if (-not [string]::IsNullOrWhiteSpace($WingetCommand))
	{
		return $WingetCommand
	}

	$CandidatePaths = @(
		(Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe")
		(Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links\winget.exe")
	) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

	return ($CandidatePaths | Select-Object -First 1)
}

<#
    .SYNOPSIS
    Internal function Get-WinGetVersion.
#>

function Get-WinGetVersion
{
	<# .SYNOPSIS Returns the installed winget version string. #>
	$WingetPath = Resolve-WinGetExecutable
	if (-not $WingetPath)
	{
		return $null
	}

	try
	{
		$WingetVersion = & $WingetPath --version 2>$null
		if ($LASTEXITCODE -eq 0)
		{
			$ResolvedVersion = [string]($WingetVersion | Select-Object -First 1)
			if (-not [string]::IsNullOrWhiteSpace($ResolvedVersion))
			{
				return $ResolvedVersion.Trim()
			}
		}
	}
	catch
	{
		return $null
	}

	return $null
}

<#
    .SYNOPSIS
    Internal function Reset-WinGetAvailabilityState.
#>

function Reset-WinGetAvailabilityState
{
	<# .SYNOPSIS Clears the cached WinGet availability probe result. #>
	$Script:WinGetAvailabilityState = $null
}

<#
    .SYNOPSIS
    Internal function .
#>
function Test-WinGetAvailable
{
	<# .SYNOPSIS Returns whether WinGet can be executed successfully. #>
	[CmdletBinding()]
	param (
		[switch]$Refresh
	)

	if (-not $Refresh -and $Script:WinGetAvailabilityState -and $Script:WinGetAvailabilityState.PSObject.Properties['Available'])
	{
		return [bool]$Script:WinGetAvailabilityState.Available
	}

	$available = $false
	$version = $null
	try
	{
		$version = Get-WinGetVersion
		if (-not [string]::IsNullOrWhiteSpace([string]$version))
		{
			$available = $true
		}
	}
	catch
	{
		$available = $false
		$version = $null
	}

	$Script:WinGetAvailabilityState = [pscustomobject]@{
		Available = $available
		Version = if ($available) { [string]$version } else { $null }
	}

	return $available
}

<#
    .SYNOPSIS
    Internal function Resolve-ChocolateyExecutable.
#>

function Resolve-ChocolateyExecutable
{
	<# .SYNOPSIS Resolves the choco.exe path from command lookup or known install locations. #>
	Update-ProcessPathFromRegistry

	$ChocolateyCommand = Get-Command -Name choco, choco.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source -ErrorAction SilentlyContinue
	if (-not [string]::IsNullOrWhiteSpace($ChocolateyCommand))
	{
		return $ChocolateyCommand
	}

	$CandidatePaths = @()
	if (-not [string]::IsNullOrWhiteSpace([string]$env:ChocolateyInstall))
	{
		$CandidatePaths += (Join-Path $env:ChocolateyInstall 'bin\choco.exe')
	}
	if (-not [string]::IsNullOrWhiteSpace([string]$env:ProgramData))
	{
		$CandidatePaths += (Join-Path $env:ProgramData 'chocolatey\bin\choco.exe')
	}

	$CandidatePaths = @($CandidatePaths | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique)
	return ($CandidatePaths | Select-Object -First 1)
}

<#
    .SYNOPSIS
    Internal function Get-ChocolateyVersion.
#>

function Get-ChocolateyVersion
{
	<# .SYNOPSIS Returns the installed Chocolatey version string. #>
	$ChocolateyPath = Resolve-ChocolateyExecutable
	if (-not $ChocolateyPath)
	{
		return $null
	}

	try
	{
		$ChocolateyVersion = & $ChocolateyPath --version 2>$null
		if ($LASTEXITCODE -eq 0)
		{
			$ResolvedVersion = [string]($ChocolateyVersion | Select-Object -First 1)
			if (-not [string]::IsNullOrWhiteSpace($ResolvedVersion))
			{
				return $ResolvedVersion.Trim()
			}
		}
	}
	catch
	{
		return $null
	}

	return $null
}

<#
    .SYNOPSIS
    Internal function Reset-ChocolateyAvailabilityState.
#>

function Reset-ChocolateyAvailabilityState
{
	<# .SYNOPSIS Clears the cached Chocolatey availability probe result. #>
	$Script:ChocolateyAvailabilityState = $null
}

<#
    .SYNOPSIS
    Internal function .
#>
function Test-ChocolateyAvailable
{
	<# .SYNOPSIS Returns whether Chocolatey can be executed successfully. #>
	[CmdletBinding()]
	param (
		[switch]$Refresh
	)

	if (-not $Refresh -and $Script:ChocolateyAvailabilityState -and $Script:ChocolateyAvailabilityState.PSObject.Properties['Available'])
	{
		return [bool]$Script:ChocolateyAvailabilityState.Available
	}

	$available = $false
	$version = $null
	try
	{
		$version = Get-ChocolateyVersion
		if (-not [string]::IsNullOrWhiteSpace([string]$version))
		{
			$available = $true
		}
	}
	catch
	{
		$available = $false
		$version = $null
	}

	$Script:ChocolateyAvailabilityState = [pscustomobject]@{
		Available = $available
		Version = if ($available) { [string]$version } else { $null }
	}

	return $available
}

<#
    .SYNOPSIS
    Internal function Test-BaselineEnvironmentFlagEnabled.
#>

function Test-BaselineEnvironmentFlagEnabled
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)

	$rawValue = [System.Environment]::GetEnvironmentVariable($Name)
	if ([string]::IsNullOrWhiteSpace($rawValue))
	{
		return $false
	}

	switch ($rawValue.Trim().ToLowerInvariant())
	{
		'1' { return $true }
		'true' { return $true }
		'yes' { return $true }
		'on' { return $true }
		default { return $false }
	}
}

<#
    .SYNOPSIS
    Internal function Test-ChocolateyBootstrapInteractiveHost.
#>

function Test-ChocolateyBootstrapInteractiveHost
{
	[CmdletBinding()]
	param(
		[Parameter()]
		[object]$HostInstance = $Host,

		[Parameter()]
		[Nullable[bool]]$UserInteractive = $null
	)

	try
	{
		if ($null -eq $HostInstance -or $null -eq $HostInstance.UI)
		{
			return $false
		}

		# Known non-interactive hosts whose PromptForChoice implementation throws
		# NotSupportedException: BaselineHost (launcher), ServerRemoteHost (PSRemoting),
		# Default Host (various automation contexts). RawUI presence is not enough —
		# BaselineHost exposes RawUI but rejects PromptForChoice.
		$nonInteractiveHostNames = @('BaselineHost', 'ServerRemoteHost', 'Default Host')
		if ($HostInstance.Name -and ($nonInteractiveHostNames -contains [string]$HostInstance.Name))
		{
			return $false
		}

		$isUserInteractive = if ($null -ne $UserInteractive) { [bool]$UserInteractive } else { [Environment]::UserInteractive }
		if (-not $isUserInteractive)
		{
			return $false
		}

		$null = $HostInstance.UI.RawUI
		return $true
	}
	catch
	{
		return $false
	}
}

<#
    .SYNOPSIS
    Internal function Confirm-ChocolateyBootstrapExecution.
#>

function Confirm-ChocolateyBootstrapExecution
{
	[CmdletBinding()]
	param()

	$installerUrl = 'https://community.chocolatey.org/install.ps1'
	$approvalVariableName = 'BASELINE_ALLOW_CHOCOLATEY_BOOTSTRAP'
	if (Test-BaselineEnvironmentFlagEnabled -Name $approvalVariableName)
	{
		return
	}

	$approvalTitle = Get-BaselineBilingualString -Key 'Bootstrap_ChocolateyApprovalTitle' -Fallback 'Approve Chocolatey bootstrap'
	$approvalMessage = Get-BaselineBilingualString -Key 'Bootstrap_ChocolateyApprovalMessage' -Fallback ("Baseline can install Chocolatey by downloading and running Chocolatey's official bootstrap script.`n`nURL: {0}`n`nThis script is not bundled with Baseline or integrity-pinned by this repository. Review and approve it before continuing.`n`nFor reviewed headless automation, set {1}=1 for this process before launching Baseline." -f $installerUrl, $approvalVariableName)
	$approvalFailureMessage = Get-BaselineBilingualString -Key 'Bootstrap_ChocolateyApprovalRequired' -Fallback ("Chocolatey bootstrap requires explicit operator approval before Baseline runs {0}. Review the script and approve it in an interactive session, or set {1}=1 for this process after review." -f $installerUrl, $approvalVariableName)

	if (Test-ChocolateyBootstrapInteractiveHost)
	{
		$approveChoice = New-Object -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList '&Approve and Continue', 'Download and run the Chocolatey bootstrap script now.'
		$cancelChoice = New-Object -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList '&Cancel', 'Stop before downloading and executing the Chocolatey bootstrap script.'
		$selectedIndex = $Host.UI.PromptForChoice($approvalTitle, $approvalMessage, @($approveChoice, $cancelChoice), 1)
		if ($selectedIndex -eq 0)
		{
			return
		}
	}

	throw $approvalFailureMessage
}

<#
    .SYNOPSIS
    Internal function Get-PackageManagerBootstrapLogLines.
#>

function Get-PackageManagerBootstrapLogLines
{
	[CmdletBinding()]
	param(
		[AllowNull()]
		[string]$Path
	)

	if ([string]::IsNullOrWhiteSpace([string]$Path) -or -not (Test-Path -LiteralPath $Path))
	{
		return @()
	}

	return @(
		Get-Content -LiteralPath $Path |
			ForEach-Object { [string]$_ } |
			Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
	)
}

<#
    .SYNOPSIS
    Internal function Get-PackageManagerBootstrapFailureSummary.
#>

function Get-PackageManagerBootstrapFailureSummary
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$PackageManager,

		[Parameter(Mandatory = $true)]
		[string]$ExecutableName,

		[AllowNull()]
		[string[]]$ErrorLines = @()
	)

	$summary = '{0} installer reported errors and {1} is still unavailable.' -f $PackageManager, $ExecutableName
	if ($ErrorLines -and $ErrorLines.Count -gt 0)
	{
		$summary = '{0} First error: {1}' -f $summary, ([string]$ErrorLines[0].Trim())
	}

	return $summary
}

<#
    .SYNOPSIS
    Internal function Get-WinGetBootstrapInstallerMetadata.
#>

function Get-WinGetBootstrapInstallerMetadata
{
	<# .SYNOPSIS Returns the reviewed winget-install release metadata Baseline bootstraps from. #>
	[CmdletBinding()]
	param()

	$version = '5.3.6'

	return [pscustomobject]@{
		Version = $version
		Sha256  = '6016097051EBD3385F4E315FE33B17CEDA6912B9E71CD0C60C1D0DF1823D3262'
		Uri     = "https://github.com/asheroto/winget-install/releases/download/$version/winget-install.ps1"
		Label   = "winget-install.ps1 v$version"
	}
}

<#
    .SYNOPSIS
    Internal function Get-WinGetBootstrapInstallerArguments.
#>

function Get-WinGetBootstrapInstallerArguments
{
	<# .SYNOPSIS Returns the generic winget-install arguments Baseline passes to the upstream installer. #>
	[CmdletBinding()]
	param()

	# Keep the invocation generic so winget-install can choose the correct Server 2019/2022/2025 path itself.
	return @('-Force')
}

<#
    .SYNOPSIS
    Internal function Invoke-WinGetBootstrap.
#>

function Invoke-WinGetBootstrap
{
	<# .SYNOPSIS Installs or repairs WinGet without surfacing startup failures to the caller. #>
	[CmdletBinding()]
	param()

	$result = [pscustomobject]@{
		PackageManager = 'WinGet'
		Available      = $false
		Installed      = $false
		Repaired       = $false
		Version        = $null
		Success        = $false
		Error          = $null
	}

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
		$wingetVersion = Get-WinGetVersion
		if ($wingetVersion)
		{
			$result.Available = $true
			$result.Version = [string]$wingetVersion
			$result.Success = $true
			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerAlreadyInstalled' -Fallback '{0} is already installed and working. Version: {1}' -FormatArgs @('WinGet', $wingetVersion))
			return $result
		}

		LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerNotFunctional' -Fallback '{0} not found or not functional' -FormatArgs @('WinGet'))
		try
		{
			$installerUrl = [string]$installerMetadata.Uri
			$installerPath = Join-Path $env:TEMP ("winget-install-{0}.ps1" -f $installerVersion)
			$stdoutLog = Join-Path $env:TEMP "winget-install-stdout.log"
			$stderrLog = Join-Path $env:TEMP "winget-install-stderr.log"

			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_DownloadingPackageManagerInstaller' -Fallback 'Downloading {0} installer from {1}' -FormatArgs @('WinGet', $installerUrl))
			Invoke-DownloadFile -Uri $installerUrl -OutFile $installerPath

			if (-not (Test-Path -LiteralPath $installerPath) -or (Get-Item -LiteralPath $installerPath).Length -eq 0)
			{
				throw "winget installer download failed or produced an empty file at $installerPath"
			}

			$null = Assert-FileHash `
				-Path $installerPath `
				-ExpectedSha256 $installerSha256 `
				-Label ([string]$installerMetadata.Label)
			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerDownloadVerified' -Fallback 'Download and SHA-256 verification completed for {0} v{1}' -FormatArgs @('WinGet', $installerVersion))

			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_ExecutingInstallerScript' -Fallback 'Executing installer script...')
			$process = $null
			try
			{
				$process = Start-Process powershell.exe -ArgumentList (@(
					'-NoProfile',
					'-ExecutionPolicy', 'Bypass',
					'-WindowStyle', 'Hidden',
					'-File', "`"$installerPath`""
				) + $installerArguments) -Wait -PassThru -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -ErrorAction Stop
			}
			catch
			{
				LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_StartProcessFailedInstaller' -Fallback 'Start-Process failed for {0} installer: {1}. Trying direct execution.' -FormatArgs @('WinGet', $_.Exception.Message))
				& powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $installerPath @installerArguments
				$process = [pscustomobject]@{ ExitCode = $LASTEXITCODE }
			}

			$stdoutLines = @(Get-PackageManagerBootstrapLogLines -Path $stdoutLog)
			foreach ($stdoutLine in $stdoutLines)
			{
				LogInfo "winget-installer: $stdoutLine"
			}

			$stderrLines = @(Get-PackageManagerBootstrapLogLines -Path $stderrLog)
			foreach ($stderrLine in $stderrLines)
			{
				LogError "winget-installer: $stderrLine"
			}

			$installerExitedCleanly = ($process.ExitCode -eq 0 -or $null -eq $process.ExitCode)
			$installerReportedErrors = ($stderrLines.Count -gt 0)
			$result.Installed = $installerExitedCleanly
			if ($installerExitedCleanly -and -not $installerReportedErrors)
			{
				LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerInstallerScriptCompletedSuccessfully' -Fallback '{0} installer script completed successfully' -FormatArgs @('WinGet'))
			}
			elseif ($installerExitedCleanly -and $installerReportedErrors)
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
				$result.Available = $true
				$result.Version = [string]$wingetVersion
				$result.Installed = $true
				$result.Success = $true
				LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerValidationSucceeded' -Fallback '{0} validation succeeded. Version: {1}' -FormatArgs @('WinGet', $wingetVersion))
				return $result
			}

			if ($installerExitedCleanly -and -not $installerReportedErrors)
			{
				LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerInstallationCompletedButUnavailable' -Fallback '{0} installation completed, but {1} is not available in the current session yet. A new session may be required.' -FormatArgs @('WinGet', 'winget.exe'))
				$result.Success = $true
				return $result
			}

			$validationFailureMessage = if ($installerReportedErrors)
			{
				Get-PackageManagerBootstrapFailureSummary -PackageManager 'WinGet' -ExecutableName 'winget.exe' -ErrorLines $stderrLines
			}
			else
			{
				Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerInstallationFailedValidation' -Fallback '{0} installation failed validation after the installer completed.' -FormatArgs @('WinGet')
			}
			throw $validationFailureMessage
		}
		catch
		{
			LogError (Get-BaselineBilingualString -Key 'Bootstrap_ErrorDuringPackageManagerInstallation' -Fallback 'Error during {0} installation: {1}' -FormatArgs @('WinGet', $_.Exception.Message))
			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_AttemptingPackageManagerRepair' -Fallback 'Attempting {0} repair via {1}...' -FormatArgs @('WinGet', 'Microsoft.WinGet.Client'))

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
					$result.Available = $true
					$result.Repaired = $true
					$result.Version = [string]$wingetVersion
					$result.Success = $true
					LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerRepairSucceeded' -Fallback '{0} repair succeeded. Version: {1}' -FormatArgs @('WinGet', $wingetVersion))
					return $result
				}

				LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerRepairCompletedButUnavailable' -Fallback '{0} repair completed but {1} still not resolvable in this session.' -FormatArgs @('WinGet', 'winget.exe'))
				$result.Repaired = $true
				$result.Success = $true
				return $result
			}
			catch
			{
				LogError (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerRepairFailed' -Fallback '{0} repair also failed: {1}' -FormatArgs @('WinGet', $_))
				$result.Error = $_.Exception.Message
			}
		}
	}
	catch
	{
		$result.Error = $_.Exception.Message
		LogError (Get-BaselineBilingualString -Key 'Bootstrap_ErrorDuringPackageManagerBootstrap' -Fallback 'Error during {0} bootstrap: {1}' -FormatArgs @('WinGet', $_.Exception.Message))
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

		Reset-WinGetAvailabilityState
	}

	return $result
}

<#
    .SYNOPSIS
    Internal function Invoke-ChocolateyBootstrap.
#>

function Invoke-ChocolateyBootstrap
{
	<# .SYNOPSIS Installs Chocolatey without surfacing startup failures to the caller. #>
	[CmdletBinding()]
	param()

	$result = [pscustomobject]@{
		PackageManager = 'Chocolatey'
		Available      = $false
		Installed      = $false
		Repaired       = $false
		Version        = $null
		Success        = $false
		Error          = $null
	}

	$installerUrl = 'https://community.chocolatey.org/install.ps1'
	$installerPath = $null
	$stdoutLog = $null
	$stderrLog = $null
	$stdoutLines = @()
	$stderrLines = @()

	try
	{
		Confirm-ChocolateyBootstrapExecution

		$chocolateyVersion = Get-ChocolateyVersion
		if ($chocolateyVersion)
		{
			$result.Available = $true
			$result.Version = [string]$chocolateyVersion
			$result.Success = $true
			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerAlreadyInstalled' -Fallback '{0} is already installed and working. Version: {1}' -FormatArgs @('Chocolatey', $chocolateyVersion))
			return $result
		}

		LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerNotFunctional' -Fallback '{0} not found or not functional' -FormatArgs @('Chocolatey'))
		try
		{
			$installerPath = Join-Path $env:TEMP ("chocolatey-install-{0}.ps1" -f ([guid]::NewGuid().ToString('N')))
			$stdoutLog = [System.IO.Path]::ChangeExtension($installerPath, '.stdout.log')
			$stderrLog = [System.IO.Path]::ChangeExtension($installerPath, '.stderr.log')

			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_DownloadingPackageManagerInstaller' -Fallback 'Downloading {0} installer from {1}' -FormatArgs @('Chocolatey', $installerUrl))
			Invoke-DownloadFile -Uri $installerUrl -OutFile $installerPath

			if (-not (Test-Path -LiteralPath $installerPath) -or (Get-Item -LiteralPath $installerPath).Length -eq 0)
			{
				throw "Chocolatey installer download failed or produced an empty file at $installerPath"
			}

			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_ExecutingInstallerScript' -Fallback 'Executing installer script...')
			$process = $null
			try
			{
				$process = Start-Process powershell.exe -ArgumentList @(
					'-NoProfile',
					'-ExecutionPolicy', 'Bypass',
					'-WindowStyle', 'Hidden',
					'-File', "`"$installerPath`""
				) -Wait -PassThru -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -ErrorAction Stop
			}
			catch
			{
				LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_StartProcessFailedInstaller' -Fallback 'Start-Process failed for {0} installer: {1}. Trying direct execution.' -FormatArgs @('Chocolatey', $_.Exception.Message))
				& powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $installerPath
				$process = [pscustomobject]@{ ExitCode = $LASTEXITCODE }
			}

			$stdoutLines = @(Get-PackageManagerBootstrapLogLines -Path $stdoutLog)
			foreach ($stdoutLine in $stdoutLines)
			{
				LogInfo "chocolatey-installer: $stdoutLine"
			}

			$stderrLines = @(Get-PackageManagerBootstrapLogLines -Path $stderrLog)
			foreach ($stderrLine in $stderrLines)
			{
				LogError "chocolatey-installer: $stderrLine"
			}

			$installerExitedCleanly = ($process.ExitCode -eq 0 -or $null -eq $process.ExitCode)
			$installerReportedErrors = ($stderrLines.Count -gt 0)
			$result.Installed = $installerExitedCleanly
			if ($installerExitedCleanly -and -not $installerReportedErrors)
			{
				LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerInstallerScriptCompletedSuccessfully' -Fallback '{0} installer script completed successfully' -FormatArgs @('Chocolatey'))
			}
			elseif ($installerExitedCleanly -and $installerReportedErrors)
			{
				LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerInstallerScriptReportedErrors' -Fallback '{0} installer script reported errors despite a zero exit code. Running validation before accepting the install.' -FormatArgs @('Chocolatey'))
			}
			else
			{
				LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerInstallerScriptReportedExitCode' -Fallback '{0} installer script reported exit code: {1}' -FormatArgs @('Chocolatey', $process.ExitCode))
			}

			Start-Sleep -Seconds 2
			$chocolateyVersion = Get-ChocolateyVersion
			if ($chocolateyVersion)
			{
				$result.Available = $true
				$result.Version = [string]$chocolateyVersion
				$result.Installed = $true
				$result.Success = $true
				LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerValidationSucceeded' -Fallback '{0} validation succeeded. Version: {1}' -FormatArgs @('Chocolatey', $chocolateyVersion))
				return $result
			}

			if ($installerExitedCleanly -and -not $installerReportedErrors)
			{
				LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerInstallationCompletedButUnavailable' -Fallback '{0} installation completed, but {1} is not available in the current session yet. A new session may be required.' -FormatArgs @('Chocolatey', 'choco.exe'))
				$result.Success = $true
				return $result
			}

			$validationFailureMessage = if ($installerReportedErrors)
			{
				Get-PackageManagerBootstrapFailureSummary -PackageManager 'Chocolatey' -ExecutableName 'choco.exe' -ErrorLines $stderrLines
			}
			else
			{
				Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerInstallationFailedValidation' -Fallback '{0} installation failed validation after the installer completed.' -FormatArgs @('Chocolatey')
			}
			throw $validationFailureMessage
		}
		catch
		{
			$result.Error = $_.Exception.Message
			LogError (Get-BaselineBilingualString -Key 'Bootstrap_ErrorDuringPackageManagerInstallation' -Fallback 'Error during {0} installation: {1}' -FormatArgs @('Chocolatey', $_.Exception.Message))
		}
	}
	catch
	{
		$result.Error = $_.Exception.Message
		LogError (Get-BaselineBilingualString -Key 'Bootstrap_ErrorDuringPackageManagerBootstrap' -Fallback 'Error during {0} bootstrap: {1}' -FormatArgs @('Chocolatey', $_.Exception.Message))
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

		Reset-ChocolateyAvailabilityState
	}

	return $result
}

<#
    .SYNOPSIS
    Internal function Invoke-DownloadFile.
#>

function Invoke-DownloadFile
{
	<# .SYNOPSIS Downloads a file with retry logic and WebClient fallback. #>
	param
	(
		[Parameter(Mandatory = $true)]
		[string]
		$Uri,

		[Parameter(Mandatory = $true)]
		[string]
		$OutFile,

		[int]
		$MaxAttempts = 3
	)

	Set-DownloadSecurityProtocol

	$attemptErrors = [System.Collections.Generic.List[string]]::new()
	for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++)
	{
		try
		{
			Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -UserAgent 'Baseline' -TimeoutSec 30 -ErrorAction Stop
			if (Test-Path -LiteralPath $OutFile)
			{
				return
			}
		}
		catch
		{
			$attemptErrors.Add("attempt ${attempt}: $($_.Exception.Message)")
			Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
			Start-Sleep -Seconds ([Math]::Min($attempt * 2, 5))
		}
	}

	$webClient = $null
	try
	{
		Set-DownloadSecurityProtocol
		$webClient = [System.Net.WebClient]::new()
		$webClient.Headers['User-Agent'] = 'Baseline'
		$webClient.DownloadFile($Uri, $OutFile)
		if (Test-Path -LiteralPath $OutFile)
		{
			return
		}
	}
	catch
	{
		$attemptErrors.Add("webclient fallback: $($_.Exception.Message)")
		Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
	}
	finally
	{
		if ($null -ne $webClient)
		{
			try
			{
				$webClient.Dispose()
			}
			catch
			{
				Write-PackageHelperWarning "Failed to dispose WebClient after download attempt: $($_.Exception.Message)"
			}
		}
	}

	throw ("Failed to download '{0}'. {1}" -f $Uri, ($attemptErrors -join ' | '))
}

<#
    .SYNOPSIS
    Internal function Get-BaselineLatestReleaseAssetUrl.
#>

function Get-BaselineLatestReleaseAssetUrl
{
	<# .SYNOPSIS Resolves the latest non-draft Baseline release asset URL from GitHub Releases. #>
	param
	(
		[string]$Owner = 'sdmanson8',
		[string]$Repository = 'Baseline',
		[string]$AssetName = 'Baseline.exe'
	)

	Set-DownloadSecurityProtocol

	$apiUrl = "https://api.github.com/repos/$Owner/$Repository/releases"
	$releasesJson = (New-Object System.Net.WebClient).DownloadString($apiUrl)
	$releases = $releasesJson | ConvertFrom-BaselineJson -Depth 16
	if (-not $releases -or $releases.Count -eq 0)
	{
		throw "No releases found at $apiUrl"
	}

	$latest = Get-BaselineLatestReleaseEntry -Releases $releases
	if (-not $latest)
	{
		throw "No non-draft releases found at $apiUrl"
	}

	$asset = $latest.assets | Where-Object { $_.name -ieq $AssetName } | Select-Object -First 1
	if (-not $asset -or [string]::IsNullOrWhiteSpace([string]$asset.browser_download_url))
	{
		throw "Release '$($latest.tag_name)' does not contain asset '$AssetName'."
	}

	return [pscustomobject]@{
		TagName = [string]$latest.tag_name
		AssetName = [string]$asset.name
		SizeBytes = [long]$asset.size
		DownloadUrl = [string]$asset.browser_download_url
	}
}

<#
    .SYNOPSIS
    Internal function Save-BaselineExecutable.
#>

function Save-BaselineExecutable
{
	<# .SYNOPSIS Downloads the latest Baseline.exe release asset to Downloads\Baseline\Baseline.exe. #>
	param
	(
		[string]$Owner = 'sdmanson8',
		[string]$Repository = 'Baseline',
		[string]$DestinationPath = (Join-Path (Join-Path ([System.Environment]::GetFolderPath('UserProfile')) 'Downloads\Baseline') 'Baseline.exe')
	)

	$destinationDirectory = Split-Path -Path $DestinationPath -Parent
	if ([string]::IsNullOrWhiteSpace($destinationDirectory))
	{
		throw "Destination path is invalid: $DestinationPath"
	}

	if (-not (Test-Path -LiteralPath $destinationDirectory))
	{
		New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
	}

	$releaseAsset = Get-BaselineLatestReleaseAssetUrl -Owner $Owner -Repository $Repository -AssetName 'Baseline.exe'
	Invoke-DownloadFile -Uri $releaseAsset.DownloadUrl -OutFile $DestinationPath

	return [pscustomobject]@{
		TagName = $releaseAsset.TagName
		AssetName = $releaseAsset.AssetName
		SizeBytes = $releaseAsset.SizeBytes
		DestinationPath = $DestinationPath
		DownloadUrl = $releaseAsset.DownloadUrl
	}
}

<#
    .SYNOPSIS
    Internal function Set-DownloadSecurityProtocol.
#>

function Set-DownloadSecurityProtocol
{
	<# .SYNOPSIS Enforces TLS 1.2 for downloads via SecurityProtocol. #>
	try
	{
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	}
	catch
	{
		Write-PackageHelperWarning "Could not enforce TLS 1.2 for download. Current protocol: $([Net.ServicePointManager]::SecurityProtocol)"
	}
}

<#
    .SYNOPSIS
    Internal function .
#>
function Assert-FileHash
{
	<# .SYNOPSIS Verifies a file's SHA256 hash matches an expected value. #>
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$Path,

		[Parameter(Mandatory = $true)]
		[string]$ExpectedSha256,

		[string]$Label = 'Downloaded file'
	)

	if (-not (Test-Path -LiteralPath $Path -PathType Leaf))
	{
		throw "$Label was not found: $Path"
	}

	$expected = $ExpectedSha256.Trim().ToUpperInvariant()
	$actual = $null
	if (Get-Command -Name 'Get-FileHash' -ErrorAction SilentlyContinue)
	{
		$actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
	}
	else
	{
		$stream = [System.IO.File]::OpenRead($Path)
		try
		{
			$sha256 = [System.Security.Cryptography.SHA256]::Create()
			try
			{
				$hashBytes = $sha256.ComputeHash($stream)
			}
			finally
			{
				$sha256.Dispose()
			}
		}
		finally
		{
			$stream.Dispose()
		}

		$actual = ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToUpperInvariant()
	}

	if ($actual -ne $expected)
	{
		throw "$Label failed SHA-256 verification. Expected $expected but received $actual."
	}

	return $actual
}

<#
    .SYNOPSIS
    Internal function Assert-AuthenticodeSignature.
#>

function Assert-AuthenticodeSignature
{
	<# .SYNOPSIS Verifies Authenticode signature on a file against allowed subjects. #>
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$Path,

		[string[]]$AllowedSubjects = @('CN=Microsoft Corporation')
	)

	if (-not (Get-Command -Name 'Get-AuthenticodeSignature' -ErrorAction SilentlyContinue))
	{
		throw "Get-AuthenticodeSignature is not available to verify '$Path'."
	}

	$signature = Get-AuthenticodeSignature -FilePath $Path -ErrorAction Stop
	if ($signature.Status -ne 'Valid')
	{
		throw "Authenticode signature verification failed for '$Path' (status: $($signature.Status))."
	}

	if ($AllowedSubjects.Count -gt 0)
	{
		$subject = if ($signature.SignerCertificate) { [string]$signature.SignerCertificate.Subject } else { '' }
		$subjectMatched = $false
		foreach ($allowedSubject in @($AllowedSubjects))
		{
			if ([string]::IsNullOrWhiteSpace([string]$allowedSubject)) { continue }
			if ($subject -like "*$allowedSubject*")
			{
				$subjectMatched = $true
				break
			}
		}

		if (-not $subjectMatched)
		{
			throw "Authenticode signer for '$Path' was '$subject', which is not in the allowed subject list."
		}
	}

	return $signature
}

<#
    .SYNOPSIS
    Internal function Get-PowerShellInstallerArchitecture.
#>

function Get-PowerShellInstallerArchitecture
{
	<# .SYNOPSIS Determines the PowerShell installer architecture for the current platform. #>
	if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64')
	{
		return 'win-arm64'
	}

	if ([Environment]::Is64BitOperatingSystem)
	{
		return 'win-x64'
	}

	return 'win-x86'
}

<#
    .SYNOPSIS
    Internal function Resolve-PowerShellInstallerUri.
#>

function Resolve-PowerShellInstallerUri
{
	<# .SYNOPSIS Fetches the latest PowerShell release and resolves the installer URL. #>
	param (
		[string]$ReleaseApiUri = 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest'
	)

	Set-DownloadSecurityProtocol
	$release = Invoke-RestMethod -Uri $ReleaseApiUri -Headers @{ 'User-Agent' = 'Baseline' } -TimeoutSec 30 -ErrorAction Stop
	$assetSuffix = Get-PowerShellInstallerArchitecture
	$assets = @($release.assets)
	if ($assets.Count -eq 0)
	{
		throw "PowerShell release metadata did not include any downloadable assets."
	}

	$installerAsset = $assets | Where-Object {
		$assetName = [string]$_.name
		$assetUrl = [string]$_.browser_download_url
		($assetName -match ("^PowerShell-.*-{0}\.msi$" -f [regex]::Escape($assetSuffix))) -and
		(-not [string]::IsNullOrWhiteSpace($assetUrl))
	} | Select-Object -First 1

	if (-not $installerAsset)
	{
		throw "Could not find a PowerShell MSI installer for architecture '$assetSuffix'."
	}

	return [string]$installerAsset.browser_download_url
}

<#
    .SYNOPSIS
    Internal function Get-OneDriveSetupPath.
#>

function Get-OneDriveSetupPath
{
	<# .SYNOPSIS Locates OneDriveSetup.exe across system and ProgramFiles paths. #>
	$preferredPaths = @()

	if ([Environment]::Is64BitOperatingSystem)
	{
		$preferredPaths += Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe'
		$preferredPaths += Join-Path $env:SystemRoot 'Sysnative\OneDriveSetup.exe'

		if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles))
		{
			$preferredPaths += Join-Path $env:ProgramFiles 'Microsoft OneDrive\OneDriveSetup.exe'
		}

		if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)}))
		{
			$preferredPaths += Join-Path ${env:ProgramFiles(x86)} 'Microsoft OneDrive\OneDriveSetup.exe'
			$preferredPaths += Join-Path $env:SystemRoot 'SysWOW64\OneDriveSetup.exe'
		}
	}
	else
	{
		$preferredPaths += Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe'
	}

	$preferredPaths | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}

<#
    .SYNOPSIS
    Internal function ConvertTo-NormalizedVersion.
#>

function ConvertTo-NormalizedVersion
{
	<# .SYNOPSIS Parses and normalizes a version string to a System.Version object. #>
	param
	(
		[AllowNull()]
		[string]
		$Version
	)

	if ([string]::IsNullOrWhiteSpace($Version))
	{
		return $null
	}

	$Match = [regex]::Match($Version.Trim(), "\d+(?:\.\d+){1,3}")
	if (-not $Match.Success)
	{
		return $null
	}

	$Parts = $Match.Value.Split(".")
	while ($Parts.Count -lt 4)
	{
		$Parts += "0"
	}
	if ($Parts.Count -gt 4)
	{
		$Parts = $Parts[0..3]
	}

	try
	{
		return [System.Version]($Parts -join ".")
	}
	catch
	{
		return $null
	}
}

<#
    .SYNOPSIS
    Internal function Get-InstalledVCRedistVersion.
#>

function Get-InstalledVCRedistVersion
{
	<# .SYNOPSIS Retrieves the Visual C++ Redistributable version from registry. #>
	param
	(
		[ValidateSet("x86", "x64")]
		[string]
		$Architecture
	)

	$RegistryPaths = @(
		"HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\$Architecture",
		"HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\$Architecture"
	)

	foreach ($RegistryPath in $RegistryPaths)
	{
		try
		{
			$Runtime = Get-ItemProperty -Path $RegistryPath -ErrorAction Stop
		}
		catch
		{
			continue
		}

		if ($Runtime.Installed -eq 1)
		{
			return ConvertTo-NormalizedVersion -Version $Runtime.Version
		}
	}

	return $null
}

<#
    .SYNOPSIS
    Internal function Get-InstalledDotNetRuntimeVersion.
#>

function Get-InstalledDotNetRuntimeVersion
{
	<# .SYNOPSIS Retrieves the installed .NET Runtime version by major version. #>
	param
	(
		[ValidateRange(1, 99)]
		[int]
		$MajorVersion
	)

	$RegistryPaths = @(
		"HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedfx\Microsoft.NETCore.App",
		"HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedfx\Microsoft.WindowsDesktop.App",
		"HKLM:\SOFTWARE\WOW6432Node\dotnet\Setup\InstalledVersions\x64\sharedfx\Microsoft.NETCore.App",
		"HKLM:\SOFTWARE\WOW6432Node\dotnet\Setup\InstalledVersions\x64\sharedfx\Microsoft.WindowsDesktop.App"
	)

	$InstalledVersions = foreach ($RegistryPath in $RegistryPaths)
	{
		if (-not (Test-Path -Path $RegistryPath))
		{
			continue
		}

		Get-ChildItem -Path $RegistryPath -ErrorAction SilentlyContinue | ForEach-Object {
			ConvertTo-NormalizedVersion -Version $_.PSChildName
		}
	}

	$InstalledVersions = $InstalledVersions |
		Where-Object -FilterScript {$null -ne $_ -and $_.Major -eq $MajorVersion} |
		Sort-Object -Descending -Unique

	if ($InstalledVersions)
	{
		return $InstalledVersions[0]
	}

	return $null
}

<#
    .SYNOPSIS
    Internal function Get-LatestDotNetRuntimeRelease.
#>

function Get-LatestDotNetRuntimeRelease
{
	<# .SYNOPSIS Fetches the latest .NET Runtime release metadata from Microsoft. #>
	param
	(
		[ValidateRange(1, 99)]
		[int]
		$MajorVersion
	)

	$ReleaseMetadataUri = "https://builds.dotnet.microsoft.com/dotnet/release-metadata/$MajorVersion.0/releases.json"
	$ReleaseMetadata = Invoke-RestMethod -Uri $ReleaseMetadataUri -UseBasicParsing -TimeoutSec 30
	$LatestReleaseVersion = [string]$ReleaseMetadata."latest-release"
	$Release = $null

	if (-not [string]::IsNullOrWhiteSpace($LatestReleaseVersion))
	{
		$Release = $ReleaseMetadata.releases | Where-Object -FilterScript {$_."release-version" -eq $LatestReleaseVersion} | Select-Object -First 1
	}

	if ($null -eq $Release)
	{
		$Release = $ReleaseMetadata.releases | Select-Object -First 1
	}

	if ($null -eq $Release -or $null -eq $Release.runtime)
	{
		return $null
	}

	$RuntimeFile = $Release.runtime.files | Where-Object -FilterScript {$_.name -eq "dotnet-runtime-win-x64.exe"} | Select-Object -First 1
	$DownloadUrl = [string]$RuntimeFile.url

	if ([string]::IsNullOrWhiteSpace($DownloadUrl))
	{
		return $null
	}

	$DownloadUri = [uri]$DownloadUrl

	[pscustomobject]@{
		Version     = ConvertTo-NormalizedVersion -Version $Release.runtime.version
		DownloadUrl = $DownloadUrl
		FileName    = [System.IO.Path]::GetFileName($DownloadUri.AbsolutePath)
		SourceHost  = $DownloadUri.GetLeftPart([System.UriPartial]::Authority)
		MetadataUri = $ReleaseMetadataUri
	}
}

<#
    .SYNOPSIS
    Internal function Install-VCRedist.
#>

function Install-VCRedist
{
	<# .SYNOPSIS Downloads and installs Visual C++ 2015-2022 redistributables. #>
	[CmdletBinding()]
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Redistributables"
		)]
		[ValidateSet("2015_2022_x86", "2015_2022_x64")]
		[string[]]
		$Redistributables
	)

	$vcredistVersion = $null

	try
	{
		# Version metadata from the ScoopInstaller community bucket (mutable ref -
		# tracks latest VC++ 2015-2022 redistributable). If the upstream JSON
		# schema changes, the .version field access will fail and the catch block
		# below will leave $vcredistVersion as $null, skipping the upgrade check.
		$Parameters = @{
			Uri             = "https://raw.githubusercontent.com/ScoopInstaller/Extras/refs/heads/master/bucket/vcredist2022.json"
			UseBasicParsing = $true
			TimeoutSec      = 15
		}
		$vcredistVersion = ConvertTo-NormalizedVersion -Version (Invoke-RestMethod @Parameters).version
	}
	catch [System.Net.WebException]
	{
		LogWarning "Unable to determine the latest Visual C++ Redistributable version. Installed packages will be left unchanged unless missing."
	}

	$DownloadsFolder = Join-Path $env:TEMP "Baseline-Downloads-$([System.IO.Path]::GetRandomFileName())"
	New-Item -ItemType Directory -Path $DownloadsFolder -Force -ErrorAction Stop | Out-Null

	foreach ($Redistributable in $Redistributables)
	{
		switch ($Redistributable)
		{
			2015_2022_x86
			{
				$DisplayName = "Visual C++ Redistributable (2015 - 2022) x86"
				$InstalledVersion = Get-InstalledVCRedistVersion -Architecture "x86"
				$ShouldInstall = $null -eq $InstalledVersion

				if ($null -ne $InstalledVersion -and $null -ne $vcredistVersion)
				{
					$ShouldInstall = $vcredistVersion -gt $InstalledVersion
				}

				if (-not $ShouldInstall)
				{
					LogInfo "$DisplayName already installed (version $InstalledVersion)."
					Write-ConsoleStatus -Action "Checking $DisplayName"
					Write-ConsoleStatus -Status success
					continue
				}

				if ($null -eq $InstalledVersion)
				{
					LogInfo "$DisplayName not detected. Installing it."
				}
				elseif ($null -ne $vcredistVersion)
				{
					LogInfo "$DisplayName version $InstalledVersion detected. Updating to $vcredistVersion."
				}

				try
				{
					Write-ConsoleStatus -Action "Installing $DisplayName"
					LogInfo "Installing $DisplayName"

					$Parameters = @{
						Uri             = "https://aka.ms/vs/17/release/VC_redist.x86.exe"
						OutFile         = "$DownloadsFolder\VC_redist.x86.exe"
						UseBasicParsing = $true
						TimeoutSec      = 30
					}
					Invoke-WebRequest @Parameters

					$sig = Get-AuthenticodeSignature -FilePath "$DownloadsFolder\VC_redist.x86.exe"
					if ($sig.Status -ne 'Valid') { throw "Authenticode signature verification failed for VC_redist.x86.exe (status: $($sig.Status))" }

					$VCx86Process = Start-Process -FilePath "$DownloadsFolder\VC_redist.x86.exe" -ArgumentList "/install /passive /norestart" -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
					if ($VCx86Process.ExitCode -ne 0) { throw "VC_redist.x86.exe returned exit code $($VCx86Process.ExitCode)" }

					$Paths = @(
						"$DownloadsFolder\VC_redist.x86.exe",
						"$env:TEMP\dd_vcredist_x86_*.log"
					)
					Get-ChildItem -Path $Paths -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue | Out-Null
					Write-ConsoleStatus -Status success
				}
				catch [System.Net.WebException]
				{
					LogError ($Localization.NoResponse -f "https://download.visualstudio.microsoft.com")
					LogError ($Localization.RestartFunction -f (Get-TweakSkipLabel $MyInvocation))
					Write-ConsoleStatus -Status failed

					return
				}
				catch
				{
					LogError "Failed to install ${DisplayName}: $($_.Exception.Message)"
					Write-ConsoleStatus -Status failed
					continue
				}
			}
			2015_2022_x64
			{
				$DisplayName = "Visual C++ Redistributable (2015 - 2022) x64"
				$InstalledVersion = Get-InstalledVCRedistVersion -Architecture "x64"
				$ShouldInstall = $null -eq $InstalledVersion

				if ($null -ne $InstalledVersion -and $null -ne $vcredistVersion)
				{
					$ShouldInstall = $vcredistVersion -gt $InstalledVersion
				}

				if (-not $ShouldInstall)
				{
					LogInfo "$DisplayName already installed (version $InstalledVersion)."
					Write-ConsoleStatus -Action "Checking $DisplayName"
					Write-ConsoleStatus -Status success
					continue
				}

				if ($null -eq $InstalledVersion)
				{
					LogInfo "$DisplayName not detected. Installing it."
				}
				elseif ($null -ne $vcredistVersion)
				{
					LogInfo "$DisplayName version $InstalledVersion detected. Updating to $vcredistVersion."
				}

				try
				{
					Write-ConsoleStatus -Action "Installing $DisplayName"
					LogInfo "Installing $DisplayName"

					$Parameters = @{
						Uri             = "https://aka.ms/vs/17/release/VC_redist.x64.exe"
						OutFile         = "$DownloadsFolder\VC_redist.x64.exe"
						UseBasicParsing = $true
						TimeoutSec      = 30
					}
					Invoke-WebRequest @Parameters

					$sig = Get-AuthenticodeSignature -FilePath "$DownloadsFolder\VC_redist.x64.exe"
					if ($sig.Status -ne 'Valid') { throw "Authenticode signature verification failed for VC_redist.x64.exe (status: $($sig.Status))" }

					$VCx64Process = Start-Process -FilePath "$DownloadsFolder\VC_redist.x64.exe" -ArgumentList "/install /passive /norestart" -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
					if ($VCx64Process.ExitCode -ne 0) { throw "VC_redist.x64.exe returned exit code $($VCx64Process.ExitCode)" }

					$Paths = @(
						"$DownloadsFolder\VC_redist.x64.exe",
						"$env:TEMP\dd_vcredist_amd64_*.log"
					)
					Get-ChildItem -Path $Paths -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue | Out-Null
					Write-ConsoleStatus -Status success
				}
				catch [System.Net.WebException]
				{
					LogError ($Localization.NoResponse -f "https://download.visualstudio.microsoft.com")
					LogError ($Localization.RestartFunction -f (Get-TweakSkipLabel $MyInvocation))
					Write-ConsoleStatus -Status failed

					return
				}
				catch
				{
					LogError "Failed to install ${DisplayName}: $($_.Exception.Message)"
					Write-ConsoleStatus -Status failed
					continue
				}
			}
		}
	}
}

<#
    .SYNOPSIS
    Internal function Install-DotNetRuntimeVersion.
#>

function Install-DotNetRuntimeVersion
{
	<#
		.SYNOPSIS
		Shared helper that installs or updates a single .NET runtime version.

		.DESCRIPTION
		Downloads and installs a .NET Desktop Runtime for the specified major version.
		Returns a status string: "success", "skip", "return", or "continue" so the
		caller can apply the appropriate flow-control (continue / return) inside its
		foreach loop.
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[int]
		$MajorVersion,

		[Parameter(Mandatory = $true)]
		[string]
		$DisplayName,

		[Parameter(Mandatory = $true)]
		[string]
		$DownloadsFolder,

		[Parameter(Mandatory = $true)]
		[System.Management.Automation.InvocationInfo]
		$CallerInvocation
	)

	$InstalledVersion = Get-InstalledDotNetRuntimeVersion -MajorVersion $MajorVersion
	$LatestVersion = $null
	$DownloadUrl = $null
	$FileName = $null
	$SourceHost = "https://builds.dotnet.microsoft.com"

	try
	{
		$Release = Get-LatestDotNetRuntimeRelease -MajorVersion $MajorVersion
		if ($null -ne $Release)
		{
			$LatestVersion = $Release.Version
			$DownloadUrl = $Release.DownloadUrl
			$FileName = $Release.FileName
			$SourceHost = $Release.SourceHost
		}
	}
	catch [System.Net.WebException]
	{
		if ($null -ne $InstalledVersion)
		{
			LogWarning "Unable to determine the latest $DisplayName version. Detected installed version $InstalledVersion, so the install will be skipped."
		}
		else
		{
			LogError ($Localization.NoResponse -f "https://builds.dotnet.microsoft.com")
			LogError ($Localization.RestartFunction -f (Get-TweakSkipLabel $CallerInvocation))
			Write-ConsoleStatus -Action "Installing $DisplayName"
			Write-ConsoleStatus -Status failed

			return "return"
		}
	}

	$ShouldInstall = $null -eq $InstalledVersion

	if ($null -ne $InstalledVersion -and $null -ne $LatestVersion)
	{
		$ShouldInstall = $LatestVersion -gt $InstalledVersion
	}

	if (-not $ShouldInstall)
	{
		LogInfo "$DisplayName already installed (version $InstalledVersion)."
		Write-ConsoleStatus -Action "Checking $DisplayName"
		Write-ConsoleStatus -Status success
		return "skip"
	}

	if ($null -eq $LatestVersion)
	{
		LogError "Unable to determine the latest $DisplayName version."
		Write-ConsoleStatus -Action "Installing $DisplayName"
		Write-ConsoleStatus -Status failed
		return "return"
	}

	if ($null -eq $InstalledVersion)
	{
		LogInfo "$DisplayName not detected. Installing version $LatestVersion."
	}
	else
	{
		LogInfo "$DisplayName version $InstalledVersion detected. Updating to $LatestVersion."
	}

	try
	{
		Write-ConsoleStatus -Action "Installing .NET $LatestVersion x64"
		LogInfo "Installing .NET $LatestVersion x64"

		$Parameters = @{
			Uri             = $DownloadUrl
			OutFile         = "$DownloadsFolder\$FileName"
			UseBasicParsing = $true
			TimeoutSec      = 30
		}
		Invoke-WebRequest @Parameters

		$sig = Get-AuthenticodeSignature -FilePath "$DownloadsFolder\$FileName"
		if ($sig.Status -ne 'Valid') { throw "Authenticode signature verification failed for $FileName (status: $($sig.Status))" }

		$InstallProcess = Start-Process -FilePath "$DownloadsFolder\$FileName" -ArgumentList "/install /passive /norestart" -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
		if ($InstallProcess.ExitCode -ne 0) { throw "$FileName returned exit code $($InstallProcess.ExitCode)" }

		$Paths = @(
			"$DownloadsFolder\$FileName",
			"$env:TEMP\Microsoft_.NET_Runtime*.log"
		)
		Get-ChildItem -Path $Paths -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue | Out-Null
		Write-ConsoleStatus -Status success
		return "success"
	}
	catch [System.Net.WebException]
	{
		LogError ($Localization.NoResponse -f $SourceHost)
		LogError ($Localization.RestartFunction -f (Get-TweakSkipLabel $CallerInvocation))
		Write-ConsoleStatus -Status failed

		return "return"
	}
	catch
	{
		LogError "Failed to install .NET $LatestVersion x64: $($_.Exception.Message)"
		Write-ConsoleStatus -Status failed
		return "continue"
	}
}

<#
    .SYNOPSIS
    Internal function Install-DotNetRuntimes.
#>

function Install-DotNetRuntimes
{
	<# .SYNOPSIS Installs specified .NET runtimes by name (NET8x64, NET9x64). #>
	[CmdletBinding()]
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Runtimes"
		)]
		[ValidateSet("NET8x64", "NET9x64")]
		[string[]]
		$Runtimes
	)

	$DownloadsFolder = Join-Path $env:TEMP "Baseline-Downloads-$([System.IO.Path]::GetRandomFileName())"
	New-Item -ItemType Directory -Path $DownloadsFolder -Force -ErrorAction Stop | Out-Null

	foreach ($Runtime in $Runtimes)
	{
		switch ($Runtime)
		{
			NET8x64
			{
				$Result = Install-DotNetRuntimeVersion -MajorVersion 8 -DisplayName ".NET 8 x64" -DownloadsFolder $DownloadsFolder -CallerInvocation $MyInvocation
				if ($Result -eq "return") { return }
				if ($Result -eq "continue" -or $Result -eq "skip") { continue }
			}
			NET9x64
			{
				$Result = Install-DotNetRuntimeVersion -MajorVersion 9 -DisplayName ".NET 9 x64" -DownloadsFolder $DownloadsFolder -CallerInvocation $MyInvocation
				if ($Result -eq "return") { return }
				if ($Result -eq "continue" -or $Result -eq "skip") { continue }
			}
		}
	}
}
