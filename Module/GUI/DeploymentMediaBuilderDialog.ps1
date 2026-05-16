# DeploymentMediaBuilderDialog.ps1
#
# Guided Windows installation media workflow. This dialog builds an
# auditable plan and report before any media build command is allowed to run.

function New-GuiDeploymentMediaBuildPlan
{
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[string]$SourceIso,
		[string]$WorkingDirectory,
		[int]$EditionIndex = 1,
		[string]$EditionName = '',
		[string]$AutounattendPath = '',
		[string]$DriverSource = '',
		[string]$UsbTargetRoot = '',
		[object]$IsoImageInfo,
		[ValidateSet('Create ISO', 'Create USB', 'Export Working Folder Only')]
		[string]$OutputMode = 'Create ISO',
		[switch]$InjectBootDrivers,
		[switch]$IncludeBaselineTweaks
	)

	$errors = [System.Collections.Generic.List[string]]::new()
	$resolvedWorkingDirectory = $WorkingDirectory
	if ([string]::IsNullOrWhiteSpace($resolvedWorkingDirectory))
	{
		$resolvedWorkingDirectory = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Baseline\DeploymentMediaBuilder\Working'
	}

	if ([string]::IsNullOrWhiteSpace($SourceIso))
	{
		[void]$errors.Add('Source ISO is required.')
	}
	elseif ([System.IO.Path]::GetExtension($SourceIso) -ne '.iso')
	{
		[void]$errors.Add('Source ISO must be an .iso file.')
	}
	elseif (-not (Test-Path -LiteralPath $SourceIso -PathType Leaf))
	{
		[void]$errors.Add(('Source ISO does not exist: {0}' -f $SourceIso))
	}

	if ($EditionIndex -lt 1)
	{
		[void]$errors.Add('Selected edition index must be 1 or higher.')
	}

	if (-not $IsoImageInfo)
	{
		[void]$errors.Add('Run Detect Editions before starting a build so WIM/ESD presence and available editions are verified.')
	}
	elseif (-not $IsoImageInfo.PSObject.Properties['ImagePath'] -or [string]::IsNullOrWhiteSpace([string]$IsoImageInfo.ImagePath))
	{
		[void]$errors.Add('Detected ISO image details are incomplete; run Detect Editions again.')
	}

	if (-not [System.IO.Path]::IsPathRooted($resolvedWorkingDirectory))
	{
		[void]$errors.Add('Working directory must be an absolute path.')
	}

	if (-not [string]::IsNullOrWhiteSpace($AutounattendPath))
	{
		if ([System.IO.Path]::GetExtension($AutounattendPath) -ne '.xml')
		{
			[void]$errors.Add('Autounattend file must be an .xml file.')
		}
		elseif (-not (Test-Path -LiteralPath $AutounattendPath -PathType Leaf))
		{
			[void]$errors.Add(('Autounattend file does not exist: {0}' -f $AutounattendPath))
		}
	}

	if (-not [string]::IsNullOrWhiteSpace($DriverSource))
	{
		if (-not (Test-Path -LiteralPath $DriverSource -PathType Container))
		{
			[void]$errors.Add(('Driver source directory does not exist: {0}' -f $DriverSource))
		}
	}

	if ($OutputMode -eq 'Create USB')
	{
		if ([string]::IsNullOrWhiteSpace($UsbTargetRoot))
		{
			[void]$errors.Add('USB target root is required when output mode is Create USB.')
		}
		elseif (-not (Test-Path -LiteralPath $UsbTargetRoot -PathType Container))
		{
			[void]$errors.Add(('USB target root does not exist: {0}' -f $UsbTargetRoot))
		}
		else
		{
			$normalizedUsbRoot = [System.IO.Path]::GetFullPath($UsbTargetRoot)
			$driveRoot = [System.IO.Path]::GetPathRoot($normalizedUsbRoot)
			if ($normalizedUsbRoot.TrimEnd('\') -ne $driveRoot.TrimEnd('\'))
			{
				[void]$errors.Add('USB target must be the root of a removable drive, for example E:\.')
			}
			else
			{
				$driveLetter = $driveRoot.TrimEnd('\')
				$logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $driveLetter.Replace("'", "''")) -ErrorAction SilentlyContinue
				if (-not $logicalDisk -or [int]$logicalDisk.DriveType -ne 2)
				{
					[void]$errors.Add('USB target must be a removable drive.')
				}
				elseif (@([System.IO.Directory]::GetFileSystemEntries($driveRoot)).Count -gt 0)
				{
					[void]$errors.Add('USB target root must be empty before Baseline copies media to it.')
				}
			}
		}
	}

	$steps = [System.Collections.Generic.List[string]]::new()
	[void]$steps.Add('Confirm the selected source is an official Microsoft Windows 10/11 ISO.')
	[void]$steps.Add('Copy the ISO contents into the working directory; never modify the original ISO.')
	[void]$steps.Add('Verify sources\install.wim or sources\install.esd before image customization.')
	if ($IsoImageInfo -and $IsoImageInfo.PSObject.Properties['ImagePath'])
	{
		[void]$steps.Add(('Detected install image: {0}' -f $IsoImageInfo.ImagePath))
	}
	[void]$steps.Add(('Use selected image index {0}{1}.' -f $EditionIndex, $(if ([string]::IsNullOrWhiteSpace($EditionName)) { '' } else { " ($EditionName)" })))
	if (-not [string]::IsNullOrWhiteSpace($AutounattendPath)) { [void]$steps.Add(('Stage autounattend.xml from {0}.' -f $AutounattendPath)) }
	if ($IncludeBaselineTweaks) { [void]$steps.Add('Stage selected Baseline setup customizations as an auditable first-logon plan.') }
	if (-not [string]::IsNullOrWhiteSpace($DriverSource)) { [void]$steps.Add(('Inject drivers from {0} into install.wim.' -f $DriverSource)) }
	if ($InjectBootDrivers) { [void]$steps.Add('Inject selected storage/network drivers into boot.wim.') }
	[void]$steps.Add(('Produce output mode: {0}.' -f $OutputMode))
	if ($OutputMode -eq 'Create USB') { [void]$steps.Add(('Copy prepared media to empty removable USB target: {0}' -f $UsbTargetRoot)) }
	[void]$steps.Add('Save the build report, clean up mounts, and fail visibly on DISM or oscdimg errors.')

	$safety = @(
		'Official Microsoft ISO only.',
		'Never modify the original ISO.',
		'Always use a temp/working directory.',
		'Always verify WIM/ESD presence and selected image index.',
		'Always show the selected edition before build.',
		'Always produce a build log/report.',
		'Always cleanup mounts.',
		'Support safe cancellation.',
		'Never silently ignore DISM or oscdimg failures.',
		'Use Preview Build Plan before exposing Start ISO Build.'
	)

	return [pscustomobject]@{
		IsValid = ($errors.Count -eq 0)
		Errors = @($errors.ToArray())
		SourceIso = $SourceIso
		WorkingDirectory = $resolvedWorkingDirectory
		OutputMode = $OutputMode
		EditionIndex = $EditionIndex
		EditionName = $EditionName
		IsoImageInfo = $IsoImageInfo
		AutounattendPath = $AutounattendPath
		DriverSource = $DriverSource
		UsbTargetRoot = $UsbTargetRoot
		InjectBootDrivers = [bool]$InjectBootDrivers
		IncludeBaselineTweaks = [bool]$IncludeBaselineTweaks
		Safety = $safety
		Steps = @($steps.ToArray())
		CreatedUtc = [DateTime]::UtcNow
	}
}

function Get-GuiDeploymentMediaIsoImageInfo
{
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true)]
		[string]$SourceIso
	)

	if ([string]::IsNullOrWhiteSpace($SourceIso))
	{
		throw 'Source ISO is required.'
	}
	if ([System.IO.Path]::GetExtension($SourceIso) -ne '.iso')
	{
		throw 'Source ISO must be an .iso file.'
	}
	if (-not (Test-Path -LiteralPath $SourceIso -PathType Leaf))
	{
		throw ('Source ISO does not exist: {0}' -f $SourceIso)
	}
	if (-not (Get-Command -Name 'Mount-DiskImage' -CommandType Function -ErrorAction SilentlyContinue))
	{
		throw 'Mount-DiskImage is required to inspect Windows ISO media.'
	}
	if (-not (Get-Command -Name 'Get-WindowsImage' -CommandType Cmdlet -ErrorAction SilentlyContinue))
	{
		throw 'Get-WindowsImage is required to read install.wim/install.esd editions.'
	}

	$diskImage = $null
	$result = $null
	$primaryError = $null
	$cleanupError = $null
	try
	{
		$diskImage = Mount-DiskImage -ImagePath $SourceIso -StorageType ISO -Access ReadOnly -PassThru -ErrorAction Stop
		$volume = $diskImage | Get-Volume -ErrorAction Stop | Select-Object -First 1
		if (-not $volume -or [string]::IsNullOrWhiteSpace([string]$volume.DriveLetter))
		{
			throw 'Mounted ISO did not expose a drive letter.'
		}

		$isoRoot = ('{0}:\' -f $volume.DriveLetter)
		$wimPath = Join-Path $isoRoot 'sources\install.wim'
		$esdPath = Join-Path $isoRoot 'sources\install.esd'
		$imagePath = $null
		$imageKind = $null
		if (Test-Path -LiteralPath $wimPath -PathType Leaf)
		{
			$imagePath = $wimPath
			$imageKind = 'WIM'
		}
		elseif (Test-Path -LiteralPath $esdPath -PathType Leaf)
		{
			$imagePath = $esdPath
			$imageKind = 'ESD'
		}
		else
		{
			throw 'The ISO does not contain sources\install.wim or sources\install.esd.'
		}

		$editions = [System.Collections.Generic.List[object]]::new()
		foreach ($image in @(Get-WindowsImage -ImagePath $imagePath -ErrorAction Stop))
		{
			[void]$editions.Add([pscustomobject]@{
				Index = [int]$image.ImageIndex
				Name = [string]$image.ImageName
				Description = [string]$image.ImageDescription
				Size = $image.ImageSize
			})
		}
		if ($editions.Count -lt 1)
		{
			throw 'The install image did not expose any editions.'
		}

		$result = [pscustomobject]@{
			SourceIso = $SourceIso
			IsoRoot = $isoRoot
			ImagePath = $imagePath
			ImageKind = $imageKind
			Editions = @($editions.ToArray())
			DetectedUtc = [DateTime]::UtcNow
		}
	}
	catch
	{
		$primaryError = $_
	}
	finally
	{
		if ($diskImage)
		{
			try { Dismount-DiskImage -ImagePath $SourceIso -ErrorAction Stop }
			catch { $cleanupError = $_ }
		}
	}

	if ($cleanupError)
	{
		throw ('Failed to cleanup mounted ISO: {0}' -f $cleanupError.Exception.Message)
	}
	if ($primaryError)
	{
		throw $primaryError
	}

	return $result
}

function Convert-GuiDeploymentMediaBuildPlanToText
{
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Plan
	)

	$lines = [System.Collections.Generic.List[string]]::new()
	[void]$lines.Add('Deployment Media Builder plan')
	[void]$lines.Add(('Source ISO: {0}' -f $Plan.SourceIso))
	[void]$lines.Add(('Working directory: {0}' -f $Plan.WorkingDirectory))
	[void]$lines.Add(('Output: {0}' -f $Plan.OutputMode))
	if (-not [string]::IsNullOrWhiteSpace([string]$Plan.UsbTargetRoot)) { [void]$lines.Add(('USB target: {0}' -f $Plan.UsbTargetRoot)) }
	[void]$lines.Add(('Selected edition index: {0}' -f $Plan.EditionIndex))
	if (-not [string]::IsNullOrWhiteSpace([string]$Plan.EditionName)) { [void]$lines.Add(('Selected edition: {0}' -f $Plan.EditionName)) }
	if (-not [string]::IsNullOrWhiteSpace([string]$Plan.AutounattendPath)) { [void]$lines.Add(('Autounattend: {0}' -f $Plan.AutounattendPath)) }
	if (-not [string]::IsNullOrWhiteSpace([string]$Plan.DriverSource)) { [void]$lines.Add(('Drivers: {0}' -f $Plan.DriverSource)) }
	if ($Plan.IsoImageInfo -and $Plan.IsoImageInfo.PSObject.Properties['ImagePath'])
	{
		[void]$lines.Add(('Detected image: {0} ({1})' -f $Plan.IsoImageInfo.ImagePath, $Plan.IsoImageInfo.ImageKind))
		[void]$lines.Add('Available editions:')
		foreach ($edition in @($Plan.IsoImageInfo.Editions))
		{
			[void]$lines.Add((' - {0}: {1}' -f $edition.Index, $edition.Name))
		}
	}
	[void]$lines.Add(('Boot driver injection: {0}' -f [bool]$Plan.InjectBootDrivers))
	[void]$lines.Add(('Baseline setup customizations: {0}' -f [bool]$Plan.IncludeBaselineTweaks))
	[void]$lines.Add('')

	if (-not [bool]$Plan.IsValid)
	{
		[void]$lines.Add('Blocking validation errors:')
		foreach ($errorText in @($Plan.Errors)) { [void]$lines.Add((' - {0}' -f $errorText)) }
		[void]$lines.Add('')
	}

	[void]$lines.Add('Safety contract:')
	foreach ($item in @($Plan.Safety)) { [void]$lines.Add((' - {0}' -f $item)) }
	[void]$lines.Add('')
	[void]$lines.Add('Build steps:')
	foreach ($step in @($Plan.Steps)) { [void]$lines.Add((' - {0}' -f $step)) }

	return ($lines.ToArray() -join [Environment]::NewLine)
}

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
	if (Get-Command -Name 'LogInfo' -CommandType Function -ErrorAction SilentlyContinue)
	{
		LogInfo $Message
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

function Invoke-GuiDeploymentMediaProcess
{
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true)]
		[string]$FilePath,
		[object[]]$ArgumentList = @(),
		[int]$TimeoutSeconds = 7200,
		[int[]]$AllowedExitCodes = @(0)
	)

	if (-not (Get-Command -Name 'Invoke-BaselineProcess' -CommandType Function -ErrorAction SilentlyContinue))
	{
		throw 'Invoke-BaselineProcess is required for deployment media external tool execution.'
	}

	return Invoke-BaselineProcess -FilePath $FilePath -ArgumentList $ArgumentList -TimeoutSeconds $TimeoutSeconds -AllowedExitCodes $AllowedExitCodes
}

function Invoke-GuiDeploymentMediaRobocopy
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Source,
		[Parameter(Mandatory = $true)]
		[string]$Destination
	)

	$robocopyPath = Join-Path $env:SystemRoot 'System32\robocopy.exe'
	if (-not (Test-Path -LiteralPath $robocopyPath -PathType Leaf))
	{
		throw ('robocopy.exe was not found at {0}.' -f $robocopyPath)
	}

	[void][System.IO.Directory]::CreateDirectory($Destination)
	$arguments = @($Source, $Destination, '/E', '/COPY:DAT', '/DCOPY:DAT', '/R:2', '/W:2', '/NFL', '/NDL')
	$null = Invoke-GuiDeploymentMediaProcess -FilePath $robocopyPath -ArgumentList $arguments -TimeoutSeconds 7200 -AllowedExitCodes @(0, 1, 2, 3, 4, 5, 6, 7)
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
		[scriptblock]$ProgressCallback
	)

	if ([string]::IsNullOrWhiteSpace([string]$Plan.DriverSource) -and -not [bool]$Plan.InjectBootDrivers)
	{
		return
	}

	foreach ($requiredCommand in @('Mount-WindowsImage', 'Add-WindowsDriver', 'Dismount-WindowsImage'))
	{
		if (-not (Get-Command -Name $requiredCommand -ErrorAction SilentlyContinue))
		{
			throw ('{0} is required for deployment media driver injection.' -f $requiredCommand)
		}
	}

	[void][System.IO.Directory]::CreateDirectory($MountRoot)

	if (-not [string]::IsNullOrWhiteSpace([string]$Plan.DriverSource))
	{
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
			Mount-WindowsImage -ImagePath $installImagePath -Index ([int]$Plan.EditionIndex) -Path $installMountPath -ErrorAction Stop | Out-Null
			Add-WindowsDriver -Path $installMountPath -Driver ([string]$Plan.DriverSource) -Recurse -ErrorAction Stop | Out-Null
			Dismount-WindowsImage -Path $installMountPath -Save -ErrorAction Stop | Out-Null
		}
		catch
		{
			$originalError = $_.Exception.Message
			try { Dismount-WindowsImage -Path $installMountPath -Discard -ErrorAction Stop | Out-Null }
			catch { throw ('Install image driver injection failed: {0} Cleanup failed: {1}' -f $originalError, $_.Exception.Message) }
			throw ('Install image driver injection failed: {0}' -f $originalError)
		}
	}

	if ([bool]$Plan.InjectBootDrivers)
	{
		if ([string]::IsNullOrWhiteSpace([string]$Plan.DriverSource))
		{
			throw 'Boot driver injection requires a driver source directory.'
		}

		$bootImagePath = Join-Path $MediaRoot 'sources\boot.wim'
		if (-not (Test-Path -LiteralPath $bootImagePath -PathType Leaf))
		{
			throw ('Prepared media does not contain sources\boot.wim under {0}.' -f $MediaRoot)
		}

		$bootImages = @(Get-WindowsImage -ImagePath $bootImagePath -ErrorAction Stop)
		foreach ($bootImage in $bootImages)
		{
			$bootMountPath = Join-Path $MountRoot ('Boot-{0}' -f $bootImage.ImageIndex)
			[void][System.IO.Directory]::CreateDirectory($bootMountPath)
			Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message ('Mounting boot image index {0} for driver injection.' -f $bootImage.ImageIndex)
			try
			{
				Mount-WindowsImage -ImagePath $bootImagePath -Index ([int]$bootImage.ImageIndex) -Path $bootMountPath -ErrorAction Stop | Out-Null
				Add-WindowsDriver -Path $bootMountPath -Driver ([string]$Plan.DriverSource) -Recurse -ErrorAction Stop | Out-Null
				Dismount-WindowsImage -Path $bootMountPath -Save -ErrorAction Stop | Out-Null
			}
			catch
			{
				$originalError = $_.Exception.Message
				try { Dismount-WindowsImage -Path $bootMountPath -Discard -ErrorAction Stop | Out-Null }
				catch { throw ('Boot image driver injection failed: {0} Cleanup failed: {1}' -f $originalError, $_.Exception.Message) }
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
		[scriptblock]$ProgressCallback
	)

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

	$diskImage = $null
	$primaryError = $null
	$cleanupError = $null
	$outputPath = $null

	try
	{
		Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message 'Mounting source ISO read-only.'
		$diskImage = Mount-DiskImage -ImagePath ([string]$Plan.SourceIso) -StorageType ISO -Access ReadOnly -PassThru -ErrorAction Stop
		$volume = $diskImage | Get-Volume -ErrorAction Stop | Select-Object -First 1
		if (-not $volume -or [string]::IsNullOrWhiteSpace([string]$volume.DriveLetter))
		{
			throw 'Mounted ISO did not expose a drive letter.'
		}

		$isoRoot = ('{0}:\' -f $volume.DriveLetter)
		Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message ('Copying ISO contents from {0} to {1}.' -f $isoRoot, $mediaRoot)
		Invoke-GuiDeploymentMediaRobocopy -Source $isoRoot -Destination $mediaRoot
	}
	catch
	{
		$primaryError = $_
	}
	finally
	{
		if ($diskImage)
		{
			try { Dismount-DiskImage -ImagePath ([string]$Plan.SourceIso) -ErrorAction Stop }
			catch { $cleanupError = $_ }
		}
	}

	if ($cleanupError)
	{
		throw ('Failed to cleanup mounted ISO: {0}' -f $cleanupError.Exception.Message)
	}
	if ($primaryError)
	{
		throw $primaryError
	}

	$installImagePath = Get-GuiDeploymentMediaPreparedInstallImagePath -MediaRoot $mediaRoot
	Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message ('Prepared install image: {0}.' -f $installImagePath)

	if (-not [string]::IsNullOrWhiteSpace([string]$Plan.AutounattendPath))
	{
		$answerDestination = Join-Path $mediaRoot 'autounattend.xml'
		Copy-Item -LiteralPath ([string]$Plan.AutounattendPath) -Destination $answerDestination -Force -ErrorAction Stop
		Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message ('Staged autounattend.xml at {0}.' -f $answerDestination)
	}

	if ([bool]$Plan.IncludeBaselineTweaks)
	{
		$selectedTweaks = @(Get-GuiDeploymentMediaSelectedTweaksForSetup)
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

	Invoke-GuiDeploymentMediaDriverInjection -Plan $Plan -MediaRoot $mediaRoot -MountRoot $mountRoot -ProgressCallback $ProgressCallback

	switch ([string]$Plan.OutputMode)
	{
		'Export Working Folder Only'
		{
			$outputPath = $mediaRoot
		}
		'Create ISO'
		{
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
			$null = Invoke-GuiDeploymentMediaProcess -FilePath $oscdimgPath -ArgumentList $arguments -TimeoutSeconds 7200 -AllowedExitCodes @(0)
			if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf))
			{
				throw ('oscdimg.exe completed but ISO output was not created: {0}' -f $outputPath)
			}
		}
		'Create USB'
		{
			$targetRoot = [System.IO.Path]::GetFullPath([string]$Plan.UsbTargetRoot)
			$bootsectPath = Join-Path $mediaRoot 'boot\bootsect.exe'
			if (-not (Test-Path -LiteralPath $bootsectPath -PathType Leaf))
			{
				throw ('USB boot sector tool is missing from prepared media: {0}' -f $bootsectPath)
			}
			Write-GuiDeploymentMediaBuildStatus -ProgressCallback $ProgressCallback -Message ('Copying prepared media to USB target {0}.' -f $targetRoot)
			Invoke-GuiDeploymentMediaRobocopy -Source $mediaRoot -Destination $targetRoot
			$driveArgument = [System.IO.Path]::GetPathRoot($targetRoot).TrimEnd('\')
			$null = Invoke-GuiDeploymentMediaProcess -FilePath $bootsectPath -ArgumentList @('/nt60', $driveArgument, '/force') -TimeoutSeconds 300 -AllowedExitCodes @(0)
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

function Show-GuiDeploymentMediaBuilderDialog
{
	[CmdletBinding()]
	[OutputType([hashtable])]
	param ()

	if (-not $Script:CurrentTheme)
	{
		return @{ Cancelled = $true; Previewed = $false; Started = $false; ReportPath = $null; OutputPath = $null; BuildRoot = $null }
	}

	$theme = $Script:CurrentTheme
	$titleText = Get-UxLocalizedString -Key 'GuiDeploymentMediaBuilderTitle' -Fallback 'Deployment Media Builder'
	$subtitleText = Get-UxLocalizedString -Key 'GuiDeploymentMediaBuilderSubtitle' -Fallback 'Create an auditable Windows 10/11 setup media plan before modifying any image.'
	$previewLabel = Get-UxLocalizedString -Key 'GuiDeploymentMediaBuilderPreview' -Fallback 'Preview Build Plan'
	$startLabel = Get-UxLocalizedString -Key 'GuiDeploymentMediaBuilderStart' -Fallback 'Start ISO Build'
	$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'

	[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$titleText"
	Width="920" Height="720"
	MinWidth="760" MinHeight="560"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontSize="12"
	Background="Transparent"
	WindowStyle="None"
	AllowsTransparency="True">
	<Border Name="RootBorder" CornerRadius="8" Background="$($theme.WindowBg)" BorderBrush="$($theme.BorderColor)" BorderThickness="1">
		<Grid>
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="*"/>
				<RowDefinition Height="Auto"/>
			</Grid.RowDefinitions>
			<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="16,12,10,12">
				<Grid>
					<StackPanel>
						<TextBlock Text="$titleText" FontSize="18" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
						<TextBlock Text="$subtitleText" FontSize="12" Foreground="$($theme.TextMuted)" Margin="0,4,0,0" TextWrapping="Wrap"/>
					</StackPanel>
					<Button Name="BtnDlgClose" Content="x" FontFamily="Arial" Width="32" Height="28" HorizontalAlignment="Right" VerticalAlignment="Top"
						Background="Transparent" BorderThickness="0" Foreground="$($theme.TextPrimary)" Cursor="Hand"/>
				</Grid>
			</Border>
			<ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Padding="18,16,18,16">
				<Grid>
					<Grid.RowDefinitions>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="*"/>
					</Grid.RowDefinitions>
					<Grid.ColumnDefinitions>
						<ColumnDefinition Width="180"/>
						<ColumnDefinition Width="*"/>
						<ColumnDefinition Width="Auto"/>
					</Grid.ColumnDefinitions>

					<TextBlock Grid.Row="0" Grid.Column="0" Text="Source ISO" Foreground="$($theme.TextPrimary)" VerticalAlignment="Center" Margin="0,0,12,10"/>
					<TextBox Name="TxtSourceIso" Grid.Row="0" Grid.Column="1" MinHeight="30" Margin="0,0,8,10"/>
					<StackPanel Grid.Row="0" Grid.Column="2" Orientation="Horizontal" Margin="0,0,0,10">
						<Button Name="BtnBrowseIso" Content="Browse..." MinWidth="92" MinHeight="30" Margin="0,0,6,0"/>
						<Button Name="BtnDetectIso" Content="Detect Editions" MinWidth="110" MinHeight="30"/>
					</StackPanel>

					<TextBlock Grid.Row="1" Grid.Column="0" Text="Working directory" Foreground="$($theme.TextPrimary)" VerticalAlignment="Center" Margin="0,0,12,10"/>
					<TextBox Name="TxtWorkingDirectory" Grid.Row="1" Grid.Column="1" MinHeight="30" Margin="0,0,8,10"/>
					<Button Name="BtnBrowseWorking" Grid.Row="1" Grid.Column="2" Content="Browse..." MinWidth="92" MinHeight="30" Margin="0,0,0,10"/>

					<TextBlock Grid.Row="2" Grid.Column="0" Text="Edition index" Foreground="$($theme.TextPrimary)" VerticalAlignment="Center" Margin="0,0,12,10"/>
					<StackPanel Grid.Row="2" Grid.Column="1" Grid.ColumnSpan="2" Orientation="Horizontal" Margin="0,0,0,10">
						<TextBox Name="TxtEditionIndex" Width="90" MinHeight="30" Text="1"/>
						<ComboBox Name="CmbDetectedEdition" Width="300" MinHeight="30" Margin="8,0,0,0" IsEnabled="False" ToolTip="Run Detect Editions after selecting a source ISO."/>
						<ComboBox Name="CmbOutputMode" Width="210" MinHeight="30" Margin="8,0,0,0" SelectedIndex="0">
							<ComboBoxItem Content="Create ISO"/>
							<ComboBoxItem Content="Create USB"/>
							<ComboBoxItem Content="Export Working Folder Only"/>
						</ComboBox>
					</StackPanel>

					<TextBlock Grid.Row="3" Grid.Column="0" Text="Installation customizations" Foreground="$($theme.TextPrimary)" VerticalAlignment="Center" Margin="0,0,12,10"/>
					<TextBox Name="TxtAutounattend" Grid.Row="3" Grid.Column="1" MinHeight="30" Margin="0,0,8,10"/>
					<Button Name="BtnBrowseAutounattend" Grid.Row="3" Grid.Column="2" Content="Browse..." MinWidth="92" MinHeight="30" Margin="0,0,0,10"/>

					<TextBlock Grid.Row="4" Grid.Column="0" Text="Drivers" Foreground="$($theme.TextPrimary)" VerticalAlignment="Center" Margin="0,0,12,10"/>
					<StackPanel Grid.Row="4" Grid.Column="1" Grid.ColumnSpan="2" Orientation="Vertical" Margin="0,0,0,10">
						<Grid>
							<Grid.ColumnDefinitions>
								<ColumnDefinition Width="*"/>
								<ColumnDefinition Width="Auto"/>
							</Grid.ColumnDefinitions>
							<TextBox Name="TxtDriverSource" Grid.Column="0" MinHeight="30" Margin="0,0,8,0"/>
							<Button Name="BtnBrowseDrivers" Grid.Column="1" Content="Browse..." MinWidth="92" MinHeight="30"/>
						</Grid>
						<CheckBox Name="ChkBootDrivers" Content="Inject storage/network drivers into boot.wim" Foreground="$($theme.TextPrimary)" Margin="0,8,0,0"/>
						<CheckBox Name="ChkBaselineTweaks" Content="Stage selected Baseline setup customizations" Foreground="$($theme.TextPrimary)" Margin="0,4,0,0"/>
					</StackPanel>

					<TextBlock Grid.Row="5" Grid.Column="0" Text="USB target" Foreground="$($theme.TextPrimary)" VerticalAlignment="Center" Margin="0,0,12,10"/>
					<TextBox Name="TxtUsbTargetRoot" Grid.Row="5" Grid.Column="1" MinHeight="30" Margin="0,0,8,10" ToolTip="Root of an empty removable drive, for example E:\"/>
					<Button Name="BtnBrowseUsbTarget" Grid.Row="5" Grid.Column="2" Content="Browse..." MinWidth="92" MinHeight="30" Margin="0,0,0,10"/>

					<TextBox Name="TxtPlanPreview" Grid.Row="6" Grid.Column="0" Grid.ColumnSpan="3" MinHeight="260" AcceptsReturn="True" TextWrapping="Wrap"
						VerticalScrollBarVisibility="Auto" IsReadOnly="True"/>
				</Grid>
			</ScrollViewer>
			<Border Grid.Row="2" Background="$($theme.HeaderBg)" BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0" Padding="16,10,16,10">
				<StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
					<Button Name="BtnPreview" Content="$previewLabel" MinWidth="132" MinHeight="32" Margin="0,0,8,0"/>
					<Button Name="BtnStartBuild" Content="$startLabel" MinWidth="118" MinHeight="32" Margin="0,0,8,0" IsEnabled="False"/>
					<Button Name="BtnClose" Content="$closeLabel" MinWidth="90" MinHeight="32"/>
				</StackPanel>
			</Border>
		</Grid>
	</Border>
</Window>
"@

	$reader = New-Object System.Xml.XmlNodeReader $xaml
	$window = [Windows.Markup.XamlReader]::Load($reader)
	$window.Owner = $Script:MainForm

	$txtSourceIso = $window.FindName('TxtSourceIso')
	$txtWorkingDirectory = $window.FindName('TxtWorkingDirectory')
	$txtEditionIndex = $window.FindName('TxtEditionIndex')
	$cmbDetectedEdition = $window.FindName('CmbDetectedEdition')
	$cmbOutputMode = $window.FindName('CmbOutputMode')
	$txtAutounattend = $window.FindName('TxtAutounattend')
	$txtDriverSource = $window.FindName('TxtDriverSource')
	$txtUsbTargetRoot = $window.FindName('TxtUsbTargetRoot')
	$chkBootDrivers = $window.FindName('ChkBootDrivers')
	$chkBaselineTweaks = $window.FindName('ChkBaselineTweaks')
	$txtPlanPreview = $window.FindName('TxtPlanPreview')
	$btnPreview = $window.FindName('BtnPreview')
	$btnStartBuild = $window.FindName('BtnStartBuild')
	$btnClose = $window.FindName('BtnClose')
	$btnDlgClose = $window.FindName('BtnDlgClose')
	$btnBrowseIso = $window.FindName('BtnBrowseIso')
	$btnDetectIso = $window.FindName('BtnDetectIso')
	$btnBrowseWorking = $window.FindName('BtnBrowseWorking')
	$btnBrowseAutounattend = $window.FindName('BtnBrowseAutounattend')
	$btnBrowseDrivers = $window.FindName('BtnBrowseDrivers')
	$btnBrowseUsbTarget = $window.FindName('BtnBrowseUsbTarget')

	$result = @{ Cancelled = $true; Previewed = $false; Started = $false; ReportPath = $null; OutputPath = $null; BuildRoot = $null }
	$currentPlan = $null
	$detectedIsoInfo = $null
	$txtWorkingDirectory.Text = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Baseline\DeploymentMediaBuilder\Working'
	$txtPlanPreview.Text = "Select an official Microsoft Windows 10/11 ISO, run Detect Editions, then use Preview Build Plan before Start ISO Build."

	$browseFile = {
		param([string]$Filter)
		$dialog = New-Object Microsoft.Win32.OpenFileDialog
		$dialog.Filter = $Filter
		if ($dialog.ShowDialog($window) -eq $true) { return $dialog.FileName }
		return $null
	}
	$browseFolder = {
		Add-Type -AssemblyName System.Windows.Forms
		$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
		$dialog.ShowNewFolderButton = $true
		if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dialog.SelectedPath }
		return $null
	}
	$getOutputMode = {
		if ($cmbOutputMode.SelectedItem -and $cmbOutputMode.SelectedItem.Content) { return [string]$cmbOutputMode.SelectedItem.Content }
		return 'Create ISO'
	}
	$getEditionName = {
		if ($cmbDetectedEdition.SelectedItem -and $cmbDetectedEdition.SelectedItem.Tag)
		{
			return [string]$cmbDetectedEdition.SelectedItem.Tag.Name
		}
		return ''
	}
	$getPlan = {
		$editionIndex = 1
		if (-not [int]::TryParse([string]$txtEditionIndex.Text, [ref]$editionIndex)) { $editionIndex = 0 }
		return New-GuiDeploymentMediaBuildPlan -SourceIso $txtSourceIso.Text -WorkingDirectory $txtWorkingDirectory.Text -EditionIndex $editionIndex -EditionName (& $getEditionName) -AutounattendPath $txtAutounattend.Text -DriverSource $txtDriverSource.Text -UsbTargetRoot $txtUsbTargetRoot.Text -IsoImageInfo $detectedIsoInfo -OutputMode (& $getOutputMode) -InjectBootDrivers:([bool]$chkBootDrivers.IsChecked) -IncludeBaselineTweaks:([bool]$chkBaselineTweaks.IsChecked)
	}

	$btnBrowseIso.Add_Click({ $path = & $browseFile 'Windows ISO (*.iso)|*.iso'; if ($path) { $txtSourceIso.Text = $path } }.GetNewClosure())
	$btnDetectIso.Add_Click({
		try
		{
			$detectedIsoInfo = Get-GuiDeploymentMediaIsoImageInfo -SourceIso $txtSourceIso.Text
			$cmbDetectedEdition.Items.Clear()
			foreach ($edition in @($detectedIsoInfo.Editions))
			{
				$item = New-Object System.Windows.Controls.ComboBoxItem
				$item.Content = ('{0}: {1}' -f $edition.Index, $edition.Name)
				$item.Tag = $edition
				[void]$cmbDetectedEdition.Items.Add($item)
			}
			if ($cmbDetectedEdition.Items.Count -gt 0)
			{
				$cmbDetectedEdition.IsEnabled = $true
				$cmbDetectedEdition.SelectedIndex = 0
				$txtEditionIndex.Text = [string]$detectedIsoInfo.Editions[0].Index
			}
			$txtPlanPreview.Text = ('Detected {0}: {1}{2}Edition count: {3}' -f $detectedIsoInfo.ImageKind, $detectedIsoInfo.ImagePath, [Environment]::NewLine, @($detectedIsoInfo.Editions).Count)
			$btnStartBuild.IsEnabled = $false
		}
		catch
		{
			$detectedIsoInfo = $null
			$cmbDetectedEdition.Items.Clear()
			$cmbDetectedEdition.IsEnabled = $false
			$btnStartBuild.IsEnabled = $false
			$txtPlanPreview.Text = ('ISO detection failed: {0}' -f $_.Exception.Message)
			try { LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Deployment media ISO detection failed') } catch { Write-Warning 'Deployment media ISO detection failed, and the failure could not be written to the Baseline log.' }
			[void](Show-ThemedDialog -Title $titleText -Message ("ISO detection failed.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
		}
	}.GetNewClosure())
	$cmbDetectedEdition.Add_SelectionChanged({
		if ($cmbDetectedEdition.SelectedItem -and $cmbDetectedEdition.SelectedItem.Tag)
		{
			$txtEditionIndex.Text = [string]$cmbDetectedEdition.SelectedItem.Tag.Index
			$btnStartBuild.IsEnabled = $false
		}
	}.GetNewClosure())
	$btnBrowseAutounattend.Add_Click({ $path = & $browseFile 'Answer files (*.xml)|*.xml'; if ($path) { $txtAutounattend.Text = $path } }.GetNewClosure())
	$btnBrowseWorking.Add_Click({ $path = & $browseFolder; if ($path) { $txtWorkingDirectory.Text = $path } }.GetNewClosure())
	$btnBrowseDrivers.Add_Click({ $path = & $browseFolder; if ($path) { $txtDriverSource.Text = $path } }.GetNewClosure())
	$btnBrowseUsbTarget.Add_Click({ $path = & $browseFolder; if ($path) { $txtUsbTargetRoot.Text = [System.IO.Path]::GetPathRoot($path) } }.GetNewClosure())

	$btnPreview.Add_Click({
		$currentPlan = & $getPlan
		$txtPlanPreview.Text = Convert-GuiDeploymentMediaBuildPlanToText -Plan $currentPlan
		$btnStartBuild.IsEnabled = [bool]$currentPlan.IsValid
		$result.Previewed = $true
	}.GetNewClosure())

	$btnStartBuild.Add_Click({
		$currentPlan = & $getPlan
		$txtPlanPreview.Text = Convert-GuiDeploymentMediaBuildPlanToText -Plan $currentPlan
		if (-not [bool]$currentPlan.IsValid)
		{
			$btnStartBuild.IsEnabled = $false
			return
		}
		$confirm = Show-ThemedDialog -Title $titleText -Message "Start ISO Build will copy the selected Microsoft ISO into a working folder, apply the requested media customizations, produce the selected output, and save an auditable build report. Confirm that the source ISO, edition, and output target are correct before continuing." -Buttons @('Cancel', 'Start ISO Build') -AccentButton 'Start ISO Build'
		if ($confirm -ne 'Start ISO Build') { return }
		$btnStartBuild.IsEnabled = $false
		try
		{
			$buildResult = Invoke-GuiDeploymentMediaBuild -Plan $currentPlan -ProgressCallback {
				param([string]$Message)
				$txtPlanPreview.Text = (Convert-GuiDeploymentMediaBuildPlanToText -Plan $currentPlan) + [Environment]::NewLine + [Environment]::NewLine + $Message
			}.GetNewClosure()
			$result.Cancelled = $false
			$result.Started = $true
			$result.ReportPath = $buildResult.ReportPath
			$result.OutputPath = $buildResult.OutputPath
			$result.BuildRoot = $buildResult.BuildRoot
			$txtPlanPreview.Text = (Convert-GuiDeploymentMediaBuildPlanToText -Plan $currentPlan) + [Environment]::NewLine + [Environment]::NewLine + ('Build output: {0}' -f $buildResult.OutputPath) + [Environment]::NewLine + ('Build report saved: {0}' -f $buildResult.ReportPath)
		}
		catch
		{
			$btnStartBuild.IsEnabled = $true
			$txtPlanPreview.Text = (Convert-GuiDeploymentMediaBuildPlanToText -Plan $currentPlan) + [Environment]::NewLine + [Environment]::NewLine + ('Build failed: {0}' -f $_.Exception.Message)
			try { LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Deployment media build failed') } catch { Write-Warning 'Deployment media build failed, and the failure could not be written to the Baseline log.' }
			[void](Show-ThemedDialog -Title $titleText -Message ("Deployment media build failed.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
		}
	}.GetNewClosure())

	$closeHandler = { $window.Close() }.GetNewClosure()
	$btnClose.Add_Click($closeHandler)
	$btnDlgClose.Add_Click($closeHandler)
	[void]$window.ShowDialog()

	return $result
}
