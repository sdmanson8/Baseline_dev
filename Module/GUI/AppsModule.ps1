# Apps module: extracted from Module/Regions/GUI.psm1 during the Phase 2
# decomposition. Dot-sourced at the top of GUI.psm1 so all $Script: state
# resolves against GUI.psm1 module scope, identical to the pre-extraction
# behavior. Do not add standalone state here - shared state must remain
# anchored in GUI.psm1.

<#
    .SYNOPSIS
    Internal function .
#>
function Get-ApplicationEntityType
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Entry
	)

	$validEntityTypes = @('winget', 'choco', 'uwp', 'feature', 'system', 'placeholder')

	if ($Entry -and $Entry.PSObject.Properties['EntityType'])
	{
		$explicitType = [string]$Entry.EntityType
		if (-not [string]::IsNullOrWhiteSpace($explicitType))
		{
			$normalizedType = $explicitType.Trim().ToLowerInvariant()
			if ($validEntityTypes -contains $normalizedType)
			{
				return $normalizedType
			}
		}
	}

	if ($Entry -and $Entry.PSObject.Properties['Type'])
	{
		$explicitType = [string]$Entry.Type
		if (-not [string]::IsNullOrWhiteSpace($explicitType))
		{
			$normalizedType = $explicitType.Trim().ToLowerInvariant()
			if ($validEntityTypes -contains $normalizedType)
			{
				return $normalizedType
			}
		}
	}

	$topLevelWinGetId = $null
	$topLevelChocoId = $null
	try
	{
		if ($Entry.PSObject.Properties['WinGetId'])
		{
			$topLevelWinGetId = [string]$Entry.WinGetId
		}
		if ($Entry.PSObject.Properties['ChocoId'])
		{
			$topLevelChocoId = [string]$Entry.ChocoId
		}
	}
	catch
	{
		$null = $_
	}

	if (-not [string]::IsNullOrWhiteSpace($topLevelWinGetId))
	{
		return 'winget'
	}

	if (-not [string]::IsNullOrWhiteSpace($topLevelChocoId))
	{
		return 'choco'
	}

	$winGetId = $null
	$chocoId = $null
	try
	{
		if ($Entry.ExtraArgs)
		{
			if ($Entry.ExtraArgs.PSObject.Properties['WinGetId'])
			{
				$winGetId = [string]$Entry.ExtraArgs.WinGetId
			}
			if ($Entry.ExtraArgs.PSObject.Properties['ChocoId'])
			{
				$chocoId = [string]$Entry.ExtraArgs.ChocoId
			}
		}
	}
	catch
	{
		$null = $_
	}

	if (-not [string]::IsNullOrWhiteSpace($winGetId))
	{
		return 'winget'
	}

	if (-not [string]::IsNullOrWhiteSpace($chocoId))
	{
		return 'choco'
	}

	return 'placeholder'
}

<#
    .SYNOPSIS
    Internal function Test-ApplicationExecutionSupport.
#>

function Test-ApplicationExecutionSupport
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Entry
	)

	if ($Entry -and $Entry.PSObject.Properties['SupportsExecution'] -and -not [bool]$Entry.SupportsExecution)
	{
		return $false
	}

	$entityType = Get-ApplicationEntityType -Entry $Entry
	$winGetId = $null
	$chocoId = $null
	$storeUri = $null
	$directUrl = $null
	$command = $null

	try
	{
		if ($Entry.PSObject.Properties['WinGetId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.WinGetId))
		{
			$winGetId = [string]$Entry.WinGetId
		}
		elseif ($Entry.ExtraArgs -and $Entry.ExtraArgs.PSObject.Properties['WinGetId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.WinGetId))
		{
			$winGetId = [string]$Entry.ExtraArgs.WinGetId
		}

		if ($Entry.PSObject.Properties['ChocoId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ChocoId))
		{
			$chocoId = [string]$Entry.ChocoId
		}
		elseif ($Entry.ExtraArgs -and $Entry.ExtraArgs.PSObject.Properties['ChocoId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.ChocoId))
		{
			$chocoId = [string]$Entry.ExtraArgs.ChocoId
		}

		if ($Entry.ExtraArgs)
		{
			if ($Entry.ExtraArgs.PSObject.Properties['StoreUri'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.StoreUri))
			{
				$storeUri = [string]$Entry.ExtraArgs.StoreUri
			}
			if ($Entry.ExtraArgs.PSObject.Properties['DirectUrl'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.DirectUrl))
			{
				$directUrl = [string]$Entry.ExtraArgs.DirectUrl
			}
			if ($Entry.ExtraArgs.PSObject.Properties['Command'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.Command))
			{
				$command = [string]$Entry.ExtraArgs.Command
			}
		}
	}
	catch
	{
		$null = $_
	}

	switch ($entityType)
	{
		'uwp' { return $false }
		'feature' { return $false }
		'system' { return $false }
		'placeholder' { return $false }
		default
		{
			if (-not [string]::IsNullOrWhiteSpace($storeUri) -or -not [string]::IsNullOrWhiteSpace($directUrl) -or -not [string]::IsNullOrWhiteSpace($command))
			{
				return $true
			}

			if (-not [string]::IsNullOrWhiteSpace($chocoId))
			{
				return $true
			}

			if (-not [string]::IsNullOrWhiteSpace($winGetId))
			{
				if (Get-Command -Name 'Test-WinGetAvailable' -CommandType Function -ErrorAction SilentlyContinue)
				{
					try
					{
						return [bool](Test-WinGetAvailable)
					}
					catch
					{
						return $false
					}
				}

				return $true
			}

			return $false
		}
	}
}

<#
    .SYNOPSIS
    Internal function Get-ApplicationCatalogIdentityKey.
#>

function Get-ApplicationCatalogIdentityKey
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Entry
	)

	$entityType = Get-ApplicationEntityType -Entry $Entry
	$topLevelWinGetId = $null
	$topLevelChocoId = $null
	try
	{
		if ($Entry.PSObject.Properties['WinGetId'])
		{
			$topLevelWinGetId = [string]$Entry.WinGetId
		}
		if ($Entry.PSObject.Properties['ChocoId'])
		{
			$topLevelChocoId = [string]$Entry.ChocoId
		}
	}
	catch
	{
		$null = $_
	}

	if (-not [string]::IsNullOrWhiteSpace($topLevelWinGetId))
	{
		return ("winget:{0}" -f [string]$topLevelWinGetId.Trim().ToLowerInvariant())
	}

	if (-not [string]::IsNullOrWhiteSpace($topLevelChocoId))
	{
		return ("choco:{0}" -f [string]$topLevelChocoId.Trim().ToLowerInvariant())
	}

	if ($Entry.ExtraArgs)
	{
		try
		{
			if ($Entry.ExtraArgs.PSObject.Properties['WinGetId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.WinGetId))
			{
				return ("winget:{0}" -f [string]$Entry.ExtraArgs.WinGetId.Trim().ToLowerInvariant())
			}
			if ($Entry.ExtraArgs.PSObject.Properties['ChocoId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.ChocoId))
			{
				return ("choco:{0}" -f [string]$Entry.ExtraArgs.ChocoId.Trim().ToLowerInvariant())
			}
		}
		catch
		{
			$null = $_
		}
	}

	$name = if (-not [string]::IsNullOrWhiteSpace([string]$Entry.Name)) { [string]$Entry.Name.Trim().ToLowerInvariant() } else { '<unknown>' }
	$subCategory = if (-not [string]::IsNullOrWhiteSpace([string]$Entry.SubCategory)) { [string]$Entry.SubCategory.Trim().ToLowerInvariant() } else { '<none>' }
	return ("{0}:{1}:{2}" -f $entityType, $subCategory, $name)
}

<#
    .SYNOPSIS
    Internal function Get-ApplicationExecutionState.
#>

function Get-ApplicationExecutionState
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Entry,

		[hashtable]$WinGetInstalledCache = @{},

		[hashtable]$ChocolateyInstalledCache = @{},

		[hashtable]$WinGetUpdateCache = @{},

		[hashtable]$ChocolateyUpdateCache = @{},

		[string]$PreferredSource = $null
	)

	$entityType = Get-ApplicationEntityType -Entry $Entry
	$selectionKey = Get-ApplicationCatalogIdentityKey -Entry $Entry
	$supportsExecution = Test-ApplicationExecutionSupport -Entry $Entry
	$normalizedPreferredSource = if ([string]::IsNullOrWhiteSpace([string]$PreferredSource))
	{
		$null
	}
	else
	{
		switch ([string]$PreferredSource.Trim().ToLowerInvariant())
		{
			'winget' { 'winget' }
			'choco' { 'choco' }
			'chocolatey' { 'choco' }
			default { $null }
		}
	}
	$sourceForState = $null
	$winGetId = $null
	$chocoId = $null
	$storeUri = $null
	$directUrl = $null
	$command = $null
	$packageId = $null
	$updateKey = $null
	$isInstalled = $false
	$hasUpdateAvailable = $false

	if ($Entry.PSObject.Properties['WinGetId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.WinGetId))
	{
		$winGetId = [string]$Entry.WinGetId
	}
	elseif ($Entry.ExtraArgs -and $Entry.ExtraArgs.PSObject.Properties['WinGetId'])
	{
		$winGetId = [string]$Entry.ExtraArgs.WinGetId
	}

	if ($Entry.PSObject.Properties['ChocoId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ChocoId))
	{
		$chocoId = [string]$Entry.ChocoId
	}
	elseif ($Entry.ExtraArgs -and $Entry.ExtraArgs.PSObject.Properties['ChocoId'])
	{
		$chocoId = [string]$Entry.ExtraArgs.ChocoId
	}

	if ($Entry.ExtraArgs)
	{
		if ($Entry.ExtraArgs.PSObject.Properties['StoreUri'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.StoreUri))
		{
			$storeUri = [string]$Entry.ExtraArgs.StoreUri
		}
		if ($Entry.ExtraArgs.PSObject.Properties['DirectUrl'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.DirectUrl))
		{
			$directUrl = [string]$Entry.ExtraArgs.DirectUrl
		}
		if ($Entry.ExtraArgs.PSObject.Properties['Command'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.Command))
		{
			$command = [string]$Entry.ExtraArgs.Command
		}
	}

	$wingetAvailable = $true
	if (-not [string]::IsNullOrWhiteSpace($winGetId) -and (Get-Command -Name 'Test-WinGetAvailable' -CommandType Function -ErrorAction SilentlyContinue))
	{
		try
		{
			$wingetAvailable = [bool](Test-WinGetAvailable)
		}
		catch
		{
			$wingetAvailable = $false
		}
	}
	$chocolateyAvailable = $true
	if (-not [string]::IsNullOrWhiteSpace($chocoId) -and (Get-Command -Name 'Test-ChocolateyAvailable' -CommandType Function -ErrorAction SilentlyContinue))
	{
		try
		{
			$chocolateyAvailable = [bool](Test-ChocolateyAvailable)
		}
		catch
		{
			$chocolateyAvailable = $false
		}
	}

	if ($normalizedPreferredSource -eq 'winget' -and -not [string]::IsNullOrWhiteSpace($winGetId))
	{
		$sourceForState = 'winget'
	}
	elseif ($normalizedPreferredSource -eq 'choco' -and -not [string]::IsNullOrWhiteSpace($chocoId))
	{
		$sourceForState = 'choco'
	}
	elseif ($entityType -eq 'winget' -and -not [string]::IsNullOrWhiteSpace($winGetId))
	{
		$sourceForState = 'winget'
	}
	elseif ($entityType -eq 'choco' -and -not [string]::IsNullOrWhiteSpace($chocoId))
	{
		$sourceForState = 'choco'
	}
	elseif (-not [string]::IsNullOrWhiteSpace($winGetId))
	{
		$sourceForState = 'winget'
	}
	elseif (-not [string]::IsNullOrWhiteSpace($chocoId))
	{
		$sourceForState = 'choco'
	}
	else
	{
		$sourceForState = $entityType
	}

	switch ($sourceForState)
	{
		'winget'
		{
			$packageId = $winGetId
			if (-not [string]::IsNullOrWhiteSpace($packageId))
			{
				if (-not $wingetAvailable)
				{
					if (-not [string]::IsNullOrWhiteSpace($chocoId) -and $chocolateyAvailable)
					{
						$sourceForState = 'choco'
						$packageId = $chocoId
						$isInstalled = [bool](Test-ApplicationPackageIdInCache -PackageId $packageId -Cache $ChocolateyInstalledCache)
						$updateKey = [string]$packageId
						$hasUpdateAvailable = $isInstalled -and [bool](Test-ApplicationPackageIdInCache -PackageId $updateKey -Cache $ChocolateyUpdateCache)
					}
					else
					{
						$sourceForState = 'unsupported'
						$packageId = $null
						$supportsExecution = $false
					}
				}
				else
				{
					$isInstalled = [bool](Test-ApplicationPackageIdInCache -PackageId $packageId -Cache $WinGetInstalledCache)
					$updateKey = [string]$packageId
					$hasUpdateAvailable = $isInstalled -and [bool](Test-ApplicationPackageIdInCache -PackageId $updateKey -Cache $WinGetUpdateCache)
				}
			}
			else
			{
				$supportsExecution = $false
			}
		}
		'choco'
		{
			$packageId = $chocoId
			if (-not [string]::IsNullOrWhiteSpace($packageId))
			{
				$isInstalled = [bool](Test-ApplicationPackageIdInCache -PackageId $packageId -Cache $ChocolateyInstalledCache)
				$updateKey = [string]$packageId
				$hasUpdateAvailable = $isInstalled -and [bool](Test-ApplicationPackageIdInCache -PackageId $updateKey -Cache $ChocolateyUpdateCache)
				if (-not $chocolateyAvailable)
				{
					if (-not [string]::IsNullOrWhiteSpace($winGetId) -and $wingetAvailable)
					{
						$sourceForState = 'winget'
						$packageId = $winGetId
						$isInstalled = [bool](Test-ApplicationPackageIdInCache -PackageId $packageId -Cache $WinGetInstalledCache)
						$updateKey = [string]$packageId
						$hasUpdateAvailable = $isInstalled -and [bool](Test-ApplicationPackageIdInCache -PackageId $updateKey -Cache $WinGetUpdateCache)
					}
					else
					{
						$sourceForState = 'unsupported'
						$packageId = $null
						$isInstalled = $false
						$hasUpdateAvailable = $false
						$supportsExecution = $false
					}
				}
			}
			else
			{
				$sourceForState = 'unsupported'
				$packageId = $null
				$supportsExecution = $false
			}
		}
		'store'
		{
			$packageId = $storeUri
			if (-not [string]::IsNullOrWhiteSpace($packageId))
			{
				$supportsExecution = [bool]$supportsExecution
			}
			else
			{
				$supportsExecution = $false
			}
		}
		'direct'
		{
			$packageId = $directUrl
			if (-not [string]::IsNullOrWhiteSpace($packageId))
			{
				$supportsExecution = [bool]$supportsExecution
			}
			else
			{
				$supportsExecution = $false
			}
		}
		'command'
		{
			$packageId = $command
			if (-not [string]::IsNullOrWhiteSpace($packageId))
			{
				$supportsExecution = [bool]$supportsExecution
			}
			else
			{
				$supportsExecution = $false
			}
		}
		default
		{
			$supportsExecution = $false
			$isInstalled = $false
			$hasUpdateAvailable = $false
		}
	}

	$state = if (-not $supportsExecution)
	{
		'Unsupported'
	}
	elseif ($hasUpdateAvailable)
	{
		'Update available'
	}
	elseif ($isInstalled)
	{
		'Installed'
	}
	else
	{
		'Not installed'
	}

	$primaryAction = if (-not $supportsExecution)
	{
		$null
	}
	elseif ($hasUpdateAvailable)
	{
		'Update'
	}
	elseif ($isInstalled)
	{
		'Uninstall'
	}
	else
	{
		'Install'
	}

	$route = $null
	if ($supportsExecution -and (Get-Command -Name 'Resolve-ApplicationExecutionRoute' -CommandType Function -ErrorAction SilentlyContinue))
	{
		try
		{
			$route = Resolve-ApplicationExecutionRoute -Application $Entry -PreferredSource $PreferredSource -Action $(if ([string]::IsNullOrWhiteSpace($primaryAction)) { 'Install' } else { $primaryAction })
		}
		catch
		{
			$route = $null
		}
	}

	return [pscustomobject]@{
		SelectionKey = $selectionKey
		EntityType = $entityType
		SupportsExecution = [bool]$supportsExecution
		State = $state
		IsInstalled = [bool]$isInstalled
		UpdateAvailable = [bool]$hasUpdateAvailable
		PackageId = $packageId
		PreferredSource = if ($route -and $route.PSObject.Properties['PreferredSource']) { [string]$route.PreferredSource } else { $normalizedPreferredSource }
		SelectedSource = if ($route -and $route.PSObject.Properties['SelectedSource']) { [string]$route.SelectedSource } else { $sourceForState }
		AvailableSources = if ($route -and $route.PSObject.Properties['AvailableSources']) { @($route.AvailableSources) } else { @() }
		Route = if ($route -and $route.PSObject.Properties['Route']) { [string]$route.Route } else { $sourceForState }
		Action = $primaryAction
	}
}

<#
    .SYNOPSIS
    Internal function Get-ApplicationCacheSnapshot.
#>

function Get-ApplicationCacheSnapshot
{
	[CmdletBinding()]
	param (
		[object]$CacheState
	)

	$snapshot = [pscustomobject]@{
		WinGet = @{}
		Chocolatey = @{}
		WinGetUpdates = @{}
		ChocolateyUpdates = @{}
	}

	if ($CacheState -is [hashtable])
	{
		$snapshot.WinGet = $CacheState
		return $snapshot
	}

	if ($CacheState -and $CacheState.PSObject.Properties['WinGet'])
	{
		if ($CacheState.WinGet -is [hashtable])
		{
			$snapshot.WinGet = $CacheState.WinGet
		}
		if ($CacheState.PSObject.Properties['Chocolatey'] -and ($CacheState.Chocolatey -is [hashtable]))
		{
			$snapshot.Chocolatey = $CacheState.Chocolatey
		}
		if ($CacheState.PSObject.Properties['WinGetUpdates'] -and ($CacheState.WinGetUpdates -is [hashtable]))
		{
			$snapshot.WinGetUpdates = $CacheState.WinGetUpdates
		}
		if ($CacheState.PSObject.Properties['ChocolateyUpdates'] -and ($CacheState.ChocolateyUpdates -is [hashtable]))
		{
			$snapshot.ChocolateyUpdates = $CacheState.ChocolateyUpdates
		}
	}

	return $snapshot
}

<#
    .SYNOPSIS
    Internal function Get-BaselineApplicationsCatalog.
#>

function Get-BaselineApplicationsCatalog
{
	[CmdletBinding()]
	param (
		[switch]$Force
	)

	if (Get-Command -Name 'Test-WinGetAvailable' -CommandType Function -ErrorAction SilentlyContinue)
	{
		try { $null = Test-WinGetAvailable -Refresh } catch { $null = $_ }
	}
	if (Get-Command -Name 'Test-ChocolateyAvailable' -CommandType Function -ErrorAction SilentlyContinue)
	{
		try { $null = Test-ChocolateyAvailable -Refresh } catch { $null = $_ }
	}

	if (-not $Force -and ($Script:BaselineApplicationsCatalog -is [System.Array]) -and $Script:BaselineApplicationsCatalog.Count -gt 0)
	{
		return $Script:BaselineApplicationsCatalog
	}

	$catalogDirectory = $null
	$candidateCatalogDirectories = [System.Collections.Generic.List[string]]::new()
	foreach ($basePath in @($Script:GuiModuleBasePath))
	{
		if ([string]::IsNullOrWhiteSpace([string]$basePath))
		{
			continue
		}

		try
		{
			[void]$candidateCatalogDirectories.Add((Join-Path -Path $basePath -ChildPath 'Data\AppsCategory'))
			if ((Split-Path -Path $basePath -Leaf) -ieq 'Regions')
			{
				$moduleRoot = Split-Path -Path $basePath -Parent
				if (-not [string]::IsNullOrWhiteSpace([string]$moduleRoot))
				{
					[void]$candidateCatalogDirectories.Add((Join-Path -Path $moduleRoot -ChildPath 'Data\AppsCategory'))
				}
			}
		}
		catch
		{
			$null = $_
		}
	}

	$catalogFiles = @()
	foreach ($candidateDirectory in @($candidateCatalogDirectories | Select-Object -Unique))
	{
		if (-not [string]::IsNullOrWhiteSpace([string]$candidateDirectory) -and (Test-Path -LiteralPath $candidateDirectory -PathType Container))
		{
			$catalogDirectory = $candidateDirectory
			$catalogFiles = @(Get-ChildItem -LiteralPath $catalogDirectory -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)
			if ($catalogFiles.Count -gt 0)
			{
				break
			}
		}
	}

	if (-not $catalogFiles -or $catalogFiles.Count -eq 0)
	{
		LogError (Get-UxBilingualLocalizedString -Key 'GuiLogApplicationsCatalogNotFound' -Fallback 'Applications catalog not found: {0}' -FormatArgs @($catalogDirectory))
		$Script:BaselineApplicationsCatalog = @()
		return $Script:BaselineApplicationsCatalog
	}

	try
	{
		$catalogFilesJson = foreach ($catalogFile in $catalogFiles)
		{
			[pscustomobject]@{
				Path = [string]$catalogFile.FullName
				Json = (Get-Content -LiteralPath $catalogFile.FullName -Raw -ErrorAction Stop | ConvertFrom-BaselineJson -Depth 16 -ErrorAction Stop)
			}
		}
	}
	catch
	{
		LogError (Get-UxBilingualLocalizedString -Key 'GuiLogApplicationsCatalogLoadFailed' -Fallback 'Failed to load applications catalog: {0}' -FormatArgs @($_.Exception.Message))
		$Script:BaselineApplicationsCatalog = @()
		return $Script:BaselineApplicationsCatalog
	}

	$dedupe = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	$catalog = [System.Collections.Generic.List[object]]::new()

	foreach ($catalogFile in @($catalogFilesJson))
	{
		foreach ($entry in @($catalogFile.Json.Entries))
		{
			if (-not $entry) { continue }

			$winGetId = $null
			$chocoId = $null
			try
			{
				if ($entry.PSObject.Properties['WinGetId'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.WinGetId))
				{
					$winGetId = [string]$entry.WinGetId
				}
				if ($entry.PSObject.Properties['ChocoId'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.ChocoId))
				{
					$chocoId = [string]$entry.ChocoId
				}
				if ($entry.ExtraArgs)
				{
					if ($entry.ExtraArgs.PSObject.Properties['WinGetId'])
					{
						$winGetId = [string]$entry.ExtraArgs.WinGetId
					}
					if ($entry.ExtraArgs.PSObject.Properties['ChocoId'])
					{
						$chocoId = [string]$entry.ExtraArgs.ChocoId
					}
				}
			}
			catch
			{
				$null = $_
			}

			$identityKey = Get-ApplicationCatalogIdentityKey -Entry $entry
			if (-not $dedupe.Add($identityKey)) { continue }

			$displayName = if (-not [string]::IsNullOrWhiteSpace([string]$entry.Name)) { [string]$entry.Name } else { $(if (-not [string]::IsNullOrWhiteSpace($winGetId)) { $winGetId } elseif (-not [string]::IsNullOrWhiteSpace($chocoId)) { $chocoId } else { 'Unknown application' }) }
			$entityType = Get-ApplicationEntityType -Entry $entry
			$supportsExecution = Test-ApplicationExecutionSupport -Entry $entry
			$descriptionKey = $null
			if ($entry.PSObject.Properties['DescriptionKey'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.DescriptionKey))
			{
				$descriptionKey = [string]$entry.DescriptionKey
			}
			else
			{
				$identitySlug = (($identityKey -replace '[^A-Za-z0-9]+', '_').Trim('_'))
				if (-not [string]::IsNullOrWhiteSpace([string]$identitySlug))
				{
					$descriptionKey = 'GuiAppDescription_{0}' -f $identitySlug
				}
			}
			$resolvedDescription = if (-not [string]::IsNullOrWhiteSpace([string]$descriptionKey))
			{
				Get-UxLocalizedString -Key $descriptionKey -Fallback ([string]$entry.Description)
			}
			else
			{
				[string]$entry.Description
			}
			$searchIndex = @(
				$displayName
				$winGetId
				$chocoId
				$entityType
				$resolvedDescription
				$entry.Detail
				$entry.SubCategory
				($entry.Tags -join ' ')
				$entry.Risk
				$entry.Impact
				$entry.WhyThisMatters
				$entry.SourceRegion
			)
			if ($entry.ExtraArgs)
			{
				$searchIndex += @(
					$entry.ExtraArgs.WinGetId
					$entry.ExtraArgs.ChocoId
					$entry.ExtraArgs.StoreUri
					$entry.ExtraArgs.DirectUrl
					$entry.ExtraArgs.Command
				)
			}
			$searchIndex = @($searchIndex | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ }) -join ' '

			[void]$catalog.Add([pscustomobject]@{
				Name = $displayName
				WinGetId = $winGetId
				ChocoId = $chocoId
				Type = $entityType
				EntityType = $entityType
				SupportsExecution = [bool]$supportsExecution
				Description = [string]$resolvedDescription
				DescriptionKey = [string]$descriptionKey
				Detail = [string]$entry.Detail
				SubCategory = [string]$entry.SubCategory
				Tags = @($entry.Tags)
				Risk = [string]$entry.Risk
				Safe = [bool]$entry.Safe
				Impact = [string]$entry.Impact
				RequiresRestart = [bool]$entry.RequiresRestart
				Caution = [bool]$entry.Caution
				WhyThisMatters = [string]$entry.WhyThisMatters
				SourceRegion = [string]$entry.SourceRegion
				ExtraArgs = $entry.ExtraArgs
				SearchIndex = [string]$searchIndex.ToLowerInvariant()
			})
		}
	}

	$Script:BaselineApplicationsCatalog = @($catalog)
	return $Script:BaselineApplicationsCatalog
}

<#
    .SYNOPSIS
    Internal function Set-AppsActionControlsEnabled.
#>

function Set-AppsActionControlsEnabled
{
	[CmdletBinding()]
	param (
		[bool]$Enabled = $true
	)

	if ($Script:BtnUpdateAllApps) { $Script:BtnUpdateAllApps.IsEnabled = $Enabled }
	if ($Script:BtnRun -and $Script:AppsModeActive) { $Script:BtnRun.IsEnabled = $Enabled }
	if ($Script:AppsBulkActionButtons -is [System.Collections.IEnumerable])
	{
		foreach ($bulkButton in @($Script:AppsBulkActionButtons))
		{
			if ($bulkButton)
			{
				try { $bulkButton.IsEnabled = $Enabled } catch { $null = $_ }
			}
		}
	}
	if ($Script:CmbAppsCategoryFilter)
	{
		try { $Script:CmbAppsCategoryFilter.IsEnabled = $Enabled } catch { $null = $_ }
	}
	if ($Script:BtnAppsSourceWinGet)
	{
		try { $Script:BtnAppsSourceWinGet.IsEnabled = $Enabled } catch { $null = $_ }
	}
	if ($Script:BtnAppsSourceChocolatey)
	{
		try { $Script:BtnAppsSourceChocolatey.IsEnabled = $Enabled } catch { $null = $_ }
	}
	if ($Script:BtnApplyQueuedActions)
	{
		try { $Script:BtnApplyQueuedActions.IsEnabled = $Enabled } catch { $null = $_ }
	}
	if ($Script:BtnClearQueuedActions)
	{
		try { $Script:BtnClearQueuedActions.IsEnabled = $Enabled } catch { $null = $_ }
	}
	if ($Script:AppsActionButtons -is [System.Collections.IEnumerable])
	{
		foreach ($actionButton in @($Script:AppsActionButtons))
		{
			if ($actionButton)
			{
				try { $actionButton.IsEnabled = $Enabled } catch { $null = $_ }
			}
		}
	}
	if ($Script:AppsQueuedActionControls -is [System.Collections.IEnumerable])
	{
		foreach ($queuedControl in @($Script:AppsQueuedActionControls))
		{
			if (-not $queuedControl) { continue }
			foreach ($controlName in @('Install', 'Uninstall', 'DoNothing'))
			{
				if ($queuedControl.PSObject.Properties[$controlName] -and $queuedControl.$controlName)
				{
					try { $queuedControl.$controlName.IsEnabled = $Enabled } catch { $null = $_ }
				}
			}
		}
	}
	if ($Script:AppsSelectionControls -is [System.Collections.IEnumerable])
	{
		foreach ($selectionControl in @($Script:AppsSelectionControls))
		{
			if ($selectionControl)
			{
				try { $selectionControl.IsEnabled = $Enabled } catch { $null = $_ }
			}
		}
	}
	if (Get-Command -Name 'Update-AppsSelectionSummary' -CommandType Function -ErrorAction SilentlyContinue)
	{
		Update-AppsSelectionSummary
	}
}

<#
    .SYNOPSIS
    Internal function Initialize-AppsSelectionState.
#>

function Initialize-AppsSelectionState
{
	[CmdletBinding()]
	param ()

	if (-not ($Script:SelectedAppIds -is [System.Collections.Generic.HashSet[string]]))
	{
		$Script:SelectedAppIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	}
	if (-not ($Script:AppsSelectionControls -is [System.Collections.Generic.List[object]]))
	{
		$Script:AppsSelectionControls = [System.Collections.Generic.List[object]]::new()
	}
	if (-not ($Script:AppsBulkActionButtons -is [System.Collections.Generic.List[object]]))
	{
		$Script:AppsBulkActionButtons = [System.Collections.Generic.List[object]]::new()
	}
	if ($null -eq $Script:AppsSelectionUiUpdating)
	{
		$Script:AppsSelectionUiUpdating = $false
	}
}

<#
    .SYNOPSIS
    Internal function Initialize-AppsQueuedActionState.
#>

function Initialize-AppsQueuedActionState
{
	<#
		.SYNOPSIS
		Lazily initialises the per-app queued-action dictionary.
		Keys are app IDs (case-insensitive); values are 'Install', 'Uninstall', or 'DoNothing'.
	#>
	[CmdletBinding()]
	param ()

	if (-not ($Script:AppsQueuedActions -is [System.Collections.Generic.Dictionary[string, string]]))
	{
		$Script:AppsQueuedActions = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	}
	if (-not ($Script:AppsQueuedActionControls -is [System.Collections.Generic.List[object]]))
	{
		$Script:AppsQueuedActionControls = [System.Collections.Generic.List[object]]::new()
	}
	if (-not ($Script:AppsQueuedActionControlMap -is [System.Collections.Generic.Dictionary[string, object]]))
	{
		$Script:AppsQueuedActionControlMap = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
	}
	if ($null -eq $Script:AppsQueuedActionUiUpdating)
	{
		$Script:AppsQueuedActionUiUpdating = $false
	}
}

<#
    .SYNOPSIS
    Internal function Sync-AppsQueuedActionControls.
#>

function Sync-AppsQueuedActionControls
{
	<#
		.SYNOPSIS
		Updates the queued-action radio buttons so they match the pending queue state.
	#>
	[CmdletBinding()]
	param (
		[string]$AppId
	)

	Initialize-AppsQueuedActionState
	if ($Script:AppsQueuedActionUiUpdating) { return }

	$controlPairs = @()
	if (-not [string]::IsNullOrWhiteSpace($AppId))
	{
		$controlSet = $null
		if ($Script:AppsQueuedActionControlMap.TryGetValue([string]$AppId, [ref]$controlSet))
		{
			$controlPairs = @([pscustomobject]@{
				AppId = [string]$AppId
				Controls = $controlSet
			})
		}
	}
	else
	{
		foreach ($pair in @($Script:AppsQueuedActionControlMap.GetEnumerator()))
		{
			if (-not $pair.Value) { continue }
			$controlPairs += [pscustomobject]@{
				AppId = [string]$pair.Key
				Controls = $pair.Value
			}
		}
	}

	if ($controlPairs.Count -eq 0) { return }

	$Script:AppsQueuedActionUiUpdating = $true
	try
	{
		foreach ($pair in @($controlPairs))
		{
			$action = Get-AppQueuedAction -AppId $pair.AppId
			$controls = $pair.Controls
			if (-not $controls) { continue }

			try
			{
				if ($controls.PSObject.Properties['Install'] -and $controls.Install)
				{
					$controls.Install.IsChecked = ([string]$action -eq 'Install')
				}
				if ($controls.PSObject.Properties['Uninstall'] -and $controls.Uninstall)
				{
					$controls.Uninstall.IsChecked = ([string]$action -eq 'Uninstall')
				}
				if ($controls.PSObject.Properties['DoNothing'] -and $controls.DoNothing)
				{
					$controls.DoNothing.IsChecked = ([string]$action -eq 'DoNothing')
				}
			}
			catch
			{
				$null = $_
			}
		}
	}
	finally
	{
		$Script:AppsQueuedActionUiUpdating = $false
	}
}

<#
    .SYNOPSIS
    Internal function Get-QueuedAppsProfileActions.
#>

function Get-QueuedAppsProfileActions
{
	<#
		.SYNOPSIS
		Builds a portable list of queued app actions for configuration profiles.
	#>
	[CmdletBinding()]
	param ()

	Initialize-AppsQueuedActionState

	$catalog = @(Get-BaselineApplicationsCatalog)
	if ($catalog.Count -eq 0 -or $Script:AppsQueuedActions.Count -eq 0)
	{
		return @()
	}

	$profileActions = [System.Collections.Generic.List[object]]::new()
	foreach ($app in @($catalog))
	{
		if (-not $app) { continue }

		$appId = Get-ApplicationCatalogIdentityKey -Entry $app
		$action = Get-AppQueuedAction -AppId $appId
		if ([string]::IsNullOrWhiteSpace([string]$action) -or $action -eq 'DoNothing')
		{
			continue
		}

		$profileActions.Add([ordered]@{
			AppId = [string]$appId
			Action = [string]$action
			Name = if ($app.PSObject.Properties['Name']) { [string]$app.Name } else { $null }
			WinGetId = if ($app.PSObject.Properties['WinGetId']) { [string]$app.WinGetId } else { $null }
			ChocoId = if ($app.PSObject.Properties['ChocoId']) { [string]$app.ChocoId } else { $null }
		}) | Out-Null
	}

	return @($profileActions)
}

<#
    .SYNOPSIS
    Internal function Set-AppQueuedAction.
#>

function Set-AppQueuedAction
{
	<#
		.SYNOPSIS
		Records the desired action for a single app in the pending queue.

		.DESCRIPTION
		Sets the per-app queued action to Install, Uninstall, or DoNothing.
		Setting DoNothing (the default) removes the entry so the queue stays
		clean and only explicitly requested changes are applied.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$AppId,

		[Parameter(Mandatory)]
		[ValidateSet('Install', 'Uninstall', 'DoNothing')]
		[string]$Action
	)

	Initialize-AppsQueuedActionState
	$normalizedId = [string]$AppId.Trim()
	if ([string]::IsNullOrWhiteSpace($normalizedId)) { return }

	if ($Action -eq 'DoNothing')
	{
		[void]$Script:AppsQueuedActions.Remove($normalizedId)
	}
	else
	{
		$Script:AppsQueuedActions[$normalizedId] = $Action
	}

	Sync-AppsQueuedActionControls -AppId $normalizedId
	Update-AppsSelectionSummary
}

<#
    .SYNOPSIS
    Internal function Get-AppQueuedAction.
#>

function Get-AppQueuedAction
{
	<#
		.SYNOPSIS
		Returns the queued action for an app (Install, Uninstall, or DoNothing).
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$AppId
	)

	Initialize-AppsQueuedActionState
	$normalizedId = [string]$AppId.Trim()
	if ([string]::IsNullOrWhiteSpace($normalizedId))
	{
		return 'DoNothing'
	}
	$value = $null
	if ($Script:AppsQueuedActions.TryGetValue($normalizedId, [ref]$value))
	{
		return $value
	}
	return 'DoNothing'
}

<#
    .SYNOPSIS
    Internal function Clear-AppsQueuedActions.
#>

function Clear-AppsQueuedActions
{
	<#
		.SYNOPSIS
		Clears all pending queued app actions without touching the selection state.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	[CmdletBinding()]
	param ()

	Initialize-AppsQueuedActionState
	$Script:AppsQueuedActions.Clear()
	Sync-AppsQueuedActionControls
	Update-AppsSelectionSummary
}

<#
    .SYNOPSIS
    Internal function .
#>
function Start-AppsModuleQueuedActionAsync
{
	<#
		.SYNOPSIS
		Applies the per-app queued actions (Install / Uninstall) in a single pass.

		.DESCRIPTION
		Reads $Script:AppsQueuedActions, groups apps by requested action, and
		dispatches one Start-AppsModuleBatchActionAsync call per action type.
		Install and uninstall batches are sequenced so the app action runspace has
		time to finish, refresh caches, and return to an idle state before the next
		group begins. The queue is cleared after the last group finishes.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	[CmdletBinding()]
	param ()

	Initialize-AppsQueuedActionState

	if ($Script:AppsQueuedActions.Count -eq 0) { return }
	if ($Script:AppsOperationInProgress -or $Script:AppsCacheRefreshInProgress) { return }

	$catalog = $Script:BaselineApplicationsCatalog
	if (-not $catalog) { return }

	$installApps   = [System.Collections.Generic.List[object]]::new()
	$uninstallApps = [System.Collections.Generic.List[object]]::new()
	foreach ($app in @($catalog))
	{
		if (-not $app) { continue }
		$appId = Get-ApplicationCatalogIdentityKey -Entry $app
		switch ((Get-AppQueuedAction -AppId $appId))
		{
			'Install'   { [void]$installApps.Add($app) }
			'Uninstall' { [void]$uninstallApps.Add($app) }
		}
	}

	$taskQueue = [System.Collections.Generic.List[object]]::new()
	if ($installApps.Count -gt 0)
	{
		[void]$taskQueue.Add([pscustomobject]@{ Action = 'Install'; Apps = @($installApps) })
	}
	if ($uninstallApps.Count -gt 0)
	{
		[void]$taskQueue.Add([pscustomobject]@{ Action = 'Uninstall'; Apps = @($uninstallApps) })
	}

	if ($taskQueue.Count -eq 0)
	{
		Clear-AppsQueuedActions
		return
	}

	$applyState = [pscustomobject]@{
		Tasks = @($taskQueue)
		Index = 0
		Active = $false
		Timer = $null
	}

	$applyTick = {
		try
		{
			if ($Script:AppsOperationInProgress -or $Script:AppsCacheRefreshInProgress)
			{
				return
			}

			if ($applyState.Active)
			{
				$applyState.Active = $false
				$applyState.Index++
			}

			if ($applyState.Index -ge $applyState.Tasks.Count)
			{
				try { $applyState.Timer.Stop() } catch { $null = $_ }
				try { $applyState.Timer.Dispose() } catch { $null = $_ }
				$applyState.Timer = $null
				Clear-AppsQueuedActions
				return
			}

			$currentTask = $applyState.Tasks[$applyState.Index]
			if (-not $currentTask) { return }

			$action = [string]$currentTask.Action
			$apps = @($currentTask.Apps)
			if ($apps.Count -eq 0)
			{
				$applyState.Index++
				return
			}

			$applyState.Active = $true
			Start-AppsModuleBatchActionAsync -Action $action -SelectedApps $apps
		}
		catch
		{
			LogError (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionAppQueueStateFailed' -Fallback 'Failed to apply queued app actions: {0}' -FormatArgs @($_.Exception.Message))
			try { $applyState.Timer.Stop() } catch { $null = $_ }
			try { $applyState.Timer.Dispose() } catch { $null = $_ }
			$applyState.Timer = $null
			Clear-AppsQueuedActions
		}
	}.GetNewClosure()

	$timer = [System.Windows.Threading.DispatcherTimer]::new()
	$timer.Interval = [TimeSpan]::FromMilliseconds(250)
	$timer.Add_Tick($applyTick)
	$applyState.Timer = $timer
	$timer.Start()
	& $applyTick
}

<#
    .SYNOPSIS
    Internal function Get-SelectedAppsCatalogItems.
#>

function Get-SelectedAppsCatalogItems
{
	[CmdletBinding()]
	param ()

	Initialize-AppsSelectionState

	if (-not $Script:SelectedAppIds -or $Script:SelectedAppIds.Count -eq 0)
	{
		return @()
	}

	$catalog = @(Get-BaselineApplicationsCatalog)
	if ($catalog.Count -eq 0)
	{
		return @()
	}

	return @(
		$catalog |
			Where-Object {
				if (-not $_)
				{
					$false
				}
				else
				{
					$selectionKey = Get-ApplicationCatalogIdentityKey -Entry $_
					-not [string]::IsNullOrWhiteSpace($selectionKey) -and $Script:SelectedAppIds.Contains([string]$selectionKey)
				}
			}
	)
}

<#
    .SYNOPSIS
    Internal function Update-AppsSelectionSummary.
#>

function Update-AppsSelectionSummary
{
	[CmdletBinding()]
	param ()

	if (-not $Script:TxtAppSelectionStatus -and -not $Script:BtnInstallSelectedApps -and -not $Script:BtnUninstallSelectedApps -and -not $Script:BtnUpdateSelectedApps -and -not $Script:BtnClearAppSelection -and -not $Script:BtnScanInstalledApps -and -not $Script:BtnApplyQueuedActions -and -not $Script:BtnClearQueuedActions)
	{
		return
	}

	Initialize-AppsSelectionState

	$selectedApps = @(Get-SelectedAppsCatalogItems)
	$selectedCount = $selectedApps.Count
	Initialize-AppsQueuedActionState
	$queuedCount = if ($Script:AppsQueuedActions) { $Script:AppsQueuedActions.Count } else { 0 }
	$theme = Get-GuiCurrentTheme
	if (-not $theme)
	{
		$theme = $Script:CurrentTheme
	}
	$bc = New-SafeBrushConverter -Context 'Update-AppsSelectionSummary'

	if ($Script:TxtAppSelectionStatus)
	{
		$selectionLabel = switch ($selectedCount)
		{
			0 { (Get-UxLocalizedString -Key 'GuiAppsNoSelection' -Fallback 'No apps selected') }
			1 { (Get-UxLocalizedString -Key 'GuiAppsSingleSelected' -Fallback '1 app selected') }
			default { (Get-UxLocalizedString -Key 'GuiAppsMultipleSelected' -Fallback '{0} apps selected' -FormatArgs @($selectedCount)) }
		}
		if ($queuedCount -gt 0)
		{
			$queuedLabel = if ($queuedCount -eq 1)
			{
				(Get-UxLocalizedString -Key 'GuiAppsQueuedSingle' -Fallback '1 queued change')
			}
			else
			{
				(Get-UxLocalizedString -Key 'GuiAppsQueuedMultiple' -Fallback '{0} queued changes' -FormatArgs @($queuedCount))
			}
			$selectionLabel = '{0} | {1}' -f $selectionLabel, $queuedLabel
		}
		$Script:TxtAppSelectionStatus.Text = $selectionLabel
		if ($Script:TxtAppSelectionStatus.PSObject.Properties['FontWeight'])
		{
			$Script:TxtAppSelectionStatus.FontWeight = $(if ($selectedCount -gt 0) { [System.Windows.FontWeights]::SemiBold } else { [System.Windows.FontWeights]::Normal })
		}
		if ($theme)
		{
			$Script:TxtAppSelectionStatus.Foreground = $bc.ConvertFromString($(if ($selectedCount -gt 0) { $theme.AccentBlue } else { $theme.TextSecondary }))
		}
	}

		$cacheReady = [bool]($Script:AppsViewLoaded -and -not $Script:AppsViewDirty)
		$installDisabledTooltip = if ($Script:AppsOperationInProgress)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionBusyTooltip' -Fallback 'Wait for the current app action to finish before starting another one.')
		}
		elseif ($Script:AppsCacheRefreshInProgress)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionRefreshTooltip' -Fallback 'Wait for the app catalog to finish scanning before selecting actions.')
		}
		elseif ($selectedCount -eq 0)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionSelectTooltip' -Fallback 'Select at least one app to enable this action.')
		}
		else
		{
			$null
		}
		$catalogActionDisabledTooltip = if ($Script:AppsOperationInProgress)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionBusyTooltip' -Fallback 'Wait for the current app action to finish before starting another one.')
		}
		elseif ($Script:AppsCacheRefreshInProgress)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionRefreshTooltip' -Fallback 'Wait for the app catalog to finish scanning before selecting actions.')
		}
		elseif ($selectedCount -eq 0)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionSelectTooltip' -Fallback 'Select at least one app to enable this action.')
		}
		elseif (-not $cacheReady)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionCatalogRequiredTooltip' -Fallback 'Scan installed apps before uninstalling or updating.')
		}
		else
		{
			$null
		}
		$scanDisabledTooltip = if ($Script:AppsOperationInProgress)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionBusyTooltip' -Fallback 'Wait for the current app action to finish before starting another one.')
		}
		elseif ($Script:AppsCacheRefreshInProgress)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionRefreshTooltip' -Fallback 'Wait for the app catalog to finish scanning before selecting actions.')
		}
		else
		{
			$null
		}

		if ($Script:BtnInstallSelectedApps)
		{
			$Script:BtnInstallSelectedApps.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress) -and ($selectedCount -gt 0)
			$Script:BtnInstallSelectedApps.ToolTip = if ($installDisabledTooltip) { $installDisabledTooltip } else { (Get-UxLocalizedString -Key 'GuiAppsInstallSelectedTip' -Fallback 'Install every checked application.') }
		}
		if ($Script:BtnUninstallSelectedApps)
		{
			$Script:BtnUninstallSelectedApps.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress) -and $cacheReady -and ($selectedCount -gt 0)
			$Script:BtnUninstallSelectedApps.ToolTip = if ($catalogActionDisabledTooltip) { $catalogActionDisabledTooltip } else { (Get-UxLocalizedString -Key 'GuiAppsUninstallSelectedTip' -Fallback 'Uninstall every checked application.') }
		}
		if ($Script:BtnUpdateSelectedApps)
		{
			$Script:BtnUpdateSelectedApps.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress) -and $cacheReady -and ($selectedCount -gt 0)
			$Script:BtnUpdateSelectedApps.ToolTip = if ($catalogActionDisabledTooltip) { $catalogActionDisabledTooltip } else { (Get-UxLocalizedString -Key 'GuiAppsUpdateSelectedTip' -Fallback 'Update every checked application.') }
		}
		if ($Script:BtnClearAppSelection)
		{
			$Script:BtnClearAppSelection.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress) -and ($selectedCount -gt 0)
			$Script:BtnClearAppSelection.ToolTip = if ($selectedCount -eq 0)
			{
				(Get-UxLocalizedString -Key 'GuiAppsClearSelectionEmptyTip' -Fallback 'No apps are selected.')
			}
			elseif ($Script:AppsOperationInProgress -or $Script:AppsCacheRefreshInProgress)
			{
				(Get-UxLocalizedString -Key 'GuiAppsClearSelectionBusyTip' -Fallback 'Wait for the current app action to finish before clearing the selection.')
			}
			else
			{
				(Get-UxLocalizedString -Key 'GuiAppsClearSelectionTip' -Fallback 'Clear all checked applications.')
			}
		}
		if ($Script:BtnScanInstalledApps)
		{
			$Script:BtnScanInstalledApps.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress)
			$Script:BtnScanInstalledApps.ToolTip = if ($scanDisabledTooltip) { $scanDisabledTooltip } else { (Get-UxLocalizedString -Key 'GuiAppsScanInstalledAppsTip' -Fallback 'Scan installed apps to update install status.') }
		}
		if ($Script:BtnApplyQueuedActions)
		{
			$Script:BtnApplyQueuedActions.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress) -and ($queuedCount -gt 0)
			$Script:BtnApplyQueuedActions.ToolTip = if ($queuedCount -eq 0)
			{
				(Get-UxLocalizedString -Key 'GuiAppsApplyQueuedEmptyTip' -Fallback 'Queue an install or uninstall action first.')
			}
			elseif ($Script:AppsOperationInProgress -or $Script:AppsCacheRefreshInProgress)
			{
				(Get-UxLocalizedString -Key 'GuiAppsActionBusyTooltip' -Fallback 'Wait for the current app action to finish before starting another one.')
			}
			else
			{
				(Get-UxLocalizedString -Key 'GuiAppsApplyQueuedTip' -Fallback 'Apply queued install and uninstall changes.')
			}
		}
		if ($Script:BtnClearQueuedActions)
		{
			$Script:BtnClearQueuedActions.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress) -and ($queuedCount -gt 0)
			$Script:BtnClearQueuedActions.ToolTip = if ($queuedCount -eq 0)
			{
				(Get-UxLocalizedString -Key 'GuiAppsClearQueuedEmptyTip' -Fallback 'No queued app changes to clear.')
			}
			elseif ($Script:AppsOperationInProgress -or $Script:AppsCacheRefreshInProgress)
			{
				(Get-UxLocalizedString -Key 'GuiAppsActionBusyTooltip' -Fallback 'Wait for the current app action to finish before starting another one.')
			}
			else
			{
				(Get-UxLocalizedString -Key 'GuiAppsClearQueuedTip' -Fallback 'Clear all queued app changes without applying them.')
			}
		}
	}

<#
    .SYNOPSIS
    Internal function Set-AppSelectionState.
#>

function Set-AppSelectionState
{
	[CmdletBinding()]
	param (
		[Alias('WinGetId', 'AppKey', 'ApplicationId')]
		[string]$SelectionKey,

		[bool]$Selected = $false
	)

	if ([string]::IsNullOrWhiteSpace($SelectionKey))
	{
		return
	}

	Initialize-AppsSelectionState
	$normalizedId = [string]$SelectionKey.Trim()
	if ($Selected)
	{
		[void]$Script:SelectedAppIds.Add($normalizedId)
	}
	else
	{
		[void]$Script:SelectedAppIds.Remove($normalizedId)
	}

	Update-AppsSelectionSummary
}

<#
    .SYNOPSIS
    Internal function Clear-AppSelectionState.
#>

function Clear-AppSelectionState
{
	[CmdletBinding()]
	param ()

	Initialize-AppsSelectionState

	if ($Script:AppsSelectionUiUpdating)
	{
		return
	}

	$Script:AppsSelectionUiUpdating = $true
	try
	{
		$Script:SelectedAppIds.Clear()
		foreach ($selectionControl in @($Script:AppsSelectionControls))
		{
			if ($selectionControl)
			{
				try { $selectionControl.IsChecked = $false } catch { $null = $_ }
			}
		}
	}
	finally
	{
		$Script:AppsSelectionUiUpdating = $false
	}

	Update-AppsSelectionSummary
}

<#
    .SYNOPSIS
    Internal function Ensure-SheenProgressBarType.
#>

function Ensure-SheenProgressBarType
{
	[CmdletBinding()]
	param ()

	if ('SheenProgressBar' -as [type])
	{
		return
	}

	Add-Type -AssemblyName System.Windows.Forms
	Add-Type -AssemblyName System.Drawing
	Add-Type -AssemblyName WindowsFormsIntegration

	$csharpCode = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

public class SheenProgressBar : Control
{
    private int _minimum = 0;
    private int _maximum = 100;
    private int _value = 0;
    private bool _isIndeterminate = false;
    private float _highlightPhase = 0f;
    private Timer _animTimer;

    public int Minimum
    {
        get { return _minimum; }
        set { _minimum = Math.Max(0, Math.Min(value, _maximum)); Invalidate(); }
    }

    public int Maximum
    {
        get { return _maximum; }
        set
        {
            _maximum = Math.Max(1, value);
            if (_minimum > _maximum) { _minimum = _maximum; }
            if (_value > _maximum) { _value = _maximum; }
            Invalidate();
        }
    }

    public int Value
    {
        get { return _value; }
        set { _value = Math.Max(_minimum, Math.Min(value, _maximum)); Invalidate(); }
    }

    public bool IsIndeterminate
    {
        get { return _isIndeterminate; }
        set { _isIndeterminate = value; Invalidate(); }
    }

	public int SheenWidth { get; set; }
	public int SheenAlphaPeak { get; set; }
	public Color BarColor { get; set; }
	public Color BackgroundColor { get; set; }

    public SheenProgressBar()
    {
        this.DoubleBuffered = true;
        this.MinimumSize = new Size(1, 1);
		this.SheenWidth = 80;
		this.SheenAlphaPeak = 150;
		this.BarColor = Color.FromArgb(0, 120, 215);
		this.BackgroundColor = Color.FromArgb(40, 40, 40);
        _animTimer = new Timer();
        _animTimer.Interval = 30;
        _animTimer.Tick += (s, e) =>
        {
            _highlightPhase += 0.03f;
            if (_highlightPhase > 1.2f) _highlightPhase = -0.2f;
            Invalidate();
        };
        _animTimer.Start();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;

        Rectangle bounds = new Rectangle(0, 0, this.Width, this.Height);
        using (SolidBrush bgBrush = new SolidBrush(BackgroundColor))
        {
            g.FillRectangle(bgBrush, bounds);
        }

        if (this.Width <= 0 || this.Height <= 0)
        {
            return;
        }

        if (_isIndeterminate)
        {
            int sweepWidth = Math.Max(SheenWidth * 2, Math.Max(30, this.Width / 3));
            int travelWidth = this.Width + sweepWidth + SheenWidth;
            int sweepX = (int)(((_highlightPhase + 0.2f) / 1.4f) * travelWidth) - sweepWidth;
            Rectangle sweepRect = new Rectangle(sweepX, 0, sweepWidth, this.Height);

            using (SolidBrush barBrush = new SolidBrush(BarColor))
            {
                g.FillRectangle(barBrush, sweepRect);
            }

            using (LinearGradientBrush sheenBrush = new LinearGradientBrush(
                sweepRect, Color.Transparent, Color.Transparent, LinearGradientMode.Horizontal))
            {
                ColorBlend blend = new ColorBlend();
                blend.Positions = new float[] { 0f, 0.35f, 0.5f, 0.65f, 1f };
                blend.Colors = new Color[]
                {
                    Color.FromArgb(0, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak / 2, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak / 2, 255, 255, 255),
                    Color.FromArgb(0, 255, 255, 255)
                };
                sheenBrush.InterpolationColors = blend;

                Region prev = g.Clip;
                g.SetClip(bounds);
                g.FillRectangle(sheenBrush, sweepRect);
                g.Clip = prev;
            }

            return;
        }

        int range = Math.Max(1, _maximum - _minimum);
        int fillWidth = (int)(((float)(_value - _minimum) / range) * this.Width);
        fillWidth = Math.Max(0, Math.Min(fillWidth, this.Width));
        if (fillWidth <= 0) return;

        Rectangle fillRect = new Rectangle(0, 0, fillWidth, this.Height);
        using (SolidBrush barBrush = new SolidBrush(BarColor))
        {
            g.FillRectangle(barBrush, fillRect);
        }

        if (fillWidth > 4)
        {
            int sheenX = (int)(_highlightPhase * (fillRect.Width + SheenWidth)) - SheenWidth + fillRect.X;
            Rectangle sheenRect = new Rectangle(sheenX, fillRect.Y, SheenWidth, fillRect.Height);

            using (LinearGradientBrush sheenBrush = new LinearGradientBrush(
                sheenRect, Color.Transparent, Color.Transparent, LinearGradientMode.Horizontal))
            {
                ColorBlend blend = new ColorBlend();
                blend.Positions = new float[] { 0f, 0.35f, 0.5f, 0.65f, 1f };
                blend.Colors = new Color[]
                {
                    Color.FromArgb(0, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak / 2, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak / 2, 255, 255, 255),
                    Color.FromArgb(0, 255, 255, 255)
                };
                sheenBrush.InterpolationColors = blend;

                Region prev = g.Clip;
                g.SetClip(fillRect);
                g.FillRectangle(sheenBrush, sheenRect);
                g.Clip = prev;
            }
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing && _animTimer != null)
        {
            _animTimer.Stop();
            _animTimer.Dispose();
        }
        base.Dispose(disposing);
    }
}
"@

	Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies "System.Windows.Forms", "System.Drawing"
}

<#
    .SYNOPSIS
    Internal function New-SharedProgressBarHost.
#>

function New-SharedProgressBarHost
{
	[CmdletBinding()]
	param (
		[int]$Maximum = 100,
		[int]$Value = 0,
		[switch]$Indeterminate,
		[double]$Height = $Script:GuiLayout.ProgressBarHeight,
		[double]$MinWidth = $Script:GuiLayout.ProgressBarMinWidth
	)

	Ensure-SheenProgressBarType

	$windowsFormsHost = [System.Windows.Forms.Integration.WindowsFormsHost]::new()
	$windowsFormsHost.HorizontalAlignment = 'Stretch'
	$windowsFormsHost.VerticalAlignment = 'Center'
	$windowsFormsHost.MinWidth = $MinWidth
	$windowsFormsHost.Height = $Height

	$progressBar = [SheenProgressBar]::new()
	$progressBar.Dock = [System.Windows.Forms.DockStyle]::Fill
	$progressBar.Minimum = 0
	$progressBar.Maximum = [Math]::Max(1, $Maximum)
	$progressBar.Value = [Math]::Min([Math]::Max(0, $Value), $progressBar.Maximum)
	$progressBar.IsIndeterminate = [bool]$Indeterminate
	Set-SheenProgressBarTheme -ProgressBar $progressBar
	$windowsFormsHost.Child = $progressBar

	return @{
		Host        = $windowsFormsHost
		ProgressBar = $progressBar
	}
}

<#
    .SYNOPSIS
    Internal function Set-SheenProgressBarTheme.
#>

function Set-SheenProgressBarTheme
{
	[CmdletBinding()]
	param (
		[object]$ProgressBar,
		[hashtable]$Theme = $null
	)

	if (-not $ProgressBar)
	{
		return
	}

	if (-not $Theme)
	{
		$Theme = Get-GuiCurrentTheme
	}

	if (-not $Theme)
	{
		return
	}

	try
	{
		$ProgressBar.BarColor = [System.Drawing.ColorTranslator]::FromHtml([string]$Theme.AccentBlue)
		$ProgressBar.BackgroundColor = [System.Drawing.ColorTranslator]::FromHtml([string]$Theme.CardBorder)
	}
	catch
	{
		$null = $_
	}
}

<#
    .SYNOPSIS
    Internal function Set-SharedProgressBarState.
#>

function Set-SharedProgressBarState
{
	[CmdletBinding()]
	param (
		[object]$ProgressBar,
		[object]$ProgressText,
		[int]$Completed = 0,
		[int]$Total = 0,
		[string]$CurrentAction = $null,
		[switch]$Indeterminate,
		[switch]$PassThruText
	)

	$displayText = $null
	if ($ProgressBar)
	{
		if ($Indeterminate -or $Total -le 0)
		{
			if ($ProgressBar.PSObject.Properties['IsIndeterminate'])
			{
				$ProgressBar.IsIndeterminate = $true
			}
			if ($ProgressBar.PSObject.Properties['Maximum'])
			{
				$ProgressBar.Maximum = 1
			}
			if ($ProgressBar.PSObject.Properties['Value'])
			{
				$ProgressBar.Value = 0
			}
		}
		else
		{
			$safeTotal = [Math]::Max(1, $Total)
			$safeCompleted = [Math]::Min([Math]::Max(0, $Completed), $safeTotal)
			if ($ProgressBar.PSObject.Properties['IsIndeterminate'])
			{
				$ProgressBar.IsIndeterminate = $false
			}
			if ($ProgressBar.PSObject.Properties['Maximum'])
			{
				$ProgressBar.Maximum = $safeTotal
			}
			if ($ProgressBar.PSObject.Properties['Value'])
			{
				$ProgressBar.Value = $safeCompleted
			}
		}
	}

	if ($ProgressText)
	{
		if ($Indeterminate -or $Total -le 0)
		{
			$displayText = if ([string]::IsNullOrWhiteSpace([string]$CurrentAction))
			{
				Get-UxExecutionPlaceholderText -Kind 'Working'
			}
			else
			{
				[string]$CurrentAction
			}
			$ProgressText.Text = $displayText
		}
		else
		{
			$safeTotal = [Math]::Max(1, $Total)
			$safeCompleted = [Math]::Min([Math]::Max(0, $Completed), $safeTotal)
			$pct = [Math]::Round(($safeCompleted / [double]$safeTotal) * 100)
			$displayText = '{0}/{1} ({2}%)' -f $safeCompleted, $safeTotal, $pct
			$ProgressText.Text = $displayText
			if (-not [string]::IsNullOrWhiteSpace([string]$CurrentAction))
			{
				$ProgressText.Text += " - $CurrentAction"
			}
			$displayText = $ProgressText.Text
		}
	}
	elseif (-not $Indeterminate -and $Total -gt 0)
	{
		$safeTotal = [Math]::Max(1, $Total)
		$safeCompleted = [Math]::Min([Math]::Max(0, $Completed), $safeTotal)
		$pct = [Math]::Round(($safeCompleted / [double]$safeTotal) * 100)
		$displayText = '{0}/{1} ({2}%)' -f $safeCompleted, $safeTotal, $pct
		if (-not [string]::IsNullOrWhiteSpace([string]$CurrentAction))
		{
			$displayText += " - $CurrentAction"
		}
	}

	if ($PassThruText)
	{
		return $displayText
	}
}

<#
    .SYNOPSIS
    Internal function Initialize-AppsProgressSection.
#>

function Initialize-AppsProgressSection
{
	[CmdletBinding()]
	param ()

	if (-not $Script:AppsProgressContainer)
	{
		return
	}

	if (-not $Script:AppsProgressHost -or -not $Script:AppsProgressBar)
	{
		$sharedProgress = New-SharedProgressBarHost -Maximum 1 -Value 0
		$Script:AppsProgressHost = $sharedProgress.Host
		$Script:AppsProgressBar = $sharedProgress.ProgressBar
		$Script:AppsProgressContainer.Child = $Script:AppsProgressHost
	}

	$theme = Get-GuiCurrentTheme
	if ($theme)
	{
		$bc = New-SafeBrushConverter -Context 'Initialize-AppsProgressSection'
		$Script:AppsProgressContainer.Background = $bc.ConvertFromString($theme.CardBorder)
	}

	Set-SheenProgressBarTheme -ProgressBar $Script:AppsProgressBar

	if ($Script:AppsProgressBar)
	{
		$Script:AppsProgressBar.IsIndeterminate = $false
		$Script:AppsProgressBar.Maximum = 1
		$Script:AppsProgressBar.Value = 0
	}
	if ($Script:TxtAppsProgressText)
	{
		$Script:TxtAppsProgressText.Text = (Get-AppsCacheRefreshPromptText)
	}
	if ($Script:TxtAppCacheStatus)
	{
		$Script:TxtAppCacheStatus.Text = (Get-AppsCacheRefreshPromptText)
	}
}

<#
    .SYNOPSIS
    Internal function Build-AppsViewCards.
#>

function Build-AppsViewCards
{
	[CmdletBinding()]
	param ()

	if (-not $Script:AppsWrapPanel) { return }

	$bc = New-SafeBrushConverter -Context 'Build-AppsViewCards'
	$theme = Get-GuiCurrentTheme
	Initialize-AppsSelectionState
	$packageManagerAvailabilityState = $null
	if (Get-Command -Name 'Get-AppsPackageManagerAvailabilityState' -CommandType Function -ErrorAction SilentlyContinue)
	{
		try
		{
			$packageManagerAvailabilityState = Get-AppsPackageManagerAvailabilityState
		}
		catch
		{
			$packageManagerAvailabilityState = $null
		}
	}
	if (Get-Command -Name 'Update-AppsPackageManagerBanner' -CommandType Function -ErrorAction SilentlyContinue)
	{
		try { Update-AppsPackageManagerBanner -AvailabilityState $packageManagerAvailabilityState } catch { $null = $_ }
	}
	$renderSignature = $null
	if (Get-Command -Name 'Get-AppsViewRenderSignature' -CommandType Function -ErrorAction SilentlyContinue)
	{
		$renderSignature = Get-AppsViewRenderSignature -PackageManagerAvailabilityState $packageManagerAvailabilityState
		if ($Script:AppsWrapPanel.Children.Count -gt 0 -and $Script:AppsViewBuildSignature -eq $renderSignature)
		{
			Sync-AppsQueuedActionControls
			Update-AppsSelectionSummary
			return
		}
	}
	$Script:AppsWrapPanel.Children.Clear()
	if ($Script:AppsActionButtons -is [System.Collections.Generic.List[object]])
	{
		$Script:AppsActionButtons.Clear()
	}
	else
	{
		$Script:AppsActionButtons = [System.Collections.Generic.List[object]]::new()
	}
	if ($Script:AppsSelectionControls -is [System.Collections.Generic.List[object]])
	{
		$Script:AppsSelectionControls.Clear()
	}
	else
	{
		$Script:AppsSelectionControls = [System.Collections.Generic.List[object]]::new()
	}
	if ($Script:AppsQueuedActionControls -is [System.Collections.Generic.List[object]])
	{
		$Script:AppsQueuedActionControls.Clear()
	}
	else
	{
		$Script:AppsQueuedActionControls = [System.Collections.Generic.List[object]]::new()
	}
	if ($Script:AppsQueuedActionControlMap -is [System.Collections.Generic.Dictionary[string, object]])
	{
		$Script:AppsQueuedActionControlMap.Clear()
	}
	else
	{
		$Script:AppsQueuedActionControlMap = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
	}

	Update-AppCategoryFilterList
	$allCatalog = @(Get-BaselineApplicationsCatalog)
	$activeSearchQuery = if ($Script:AppsModeActive) { [string]$Script:AppsSearchText } else { [string]$Script:SearchText }
	$catalog = @(Get-FilteredApplicationsCatalogItems -SearchQuery $activeSearchQuery)
	$installedCacheSnapshot = Get-ApplicationCacheSnapshot -CacheState $Script:InstalledAppsCache
	$installedWingetCache = $installedCacheSnapshot.WinGet
	$installedChocolateyCache = $installedCacheSnapshot.Chocolatey
	$wingetUpdateCache = $installedCacheSnapshot.WinGetUpdates
	$chocolateyUpdateCache = $installedCacheSnapshot.ChocolateyUpdates
	$cacheReady = [bool]($Script:AppsViewLoaded -and -not $Script:AppsViewDirty)
	$cacheRefreshPrompt = if (Get-Command -Name 'Get-AppsCacheRefreshPromptText' -CommandType Function -ErrorAction SilentlyContinue)
	{
		Get-AppsCacheRefreshPromptText
	}
	else
	{
		(Get-UxLocalizedString -Key 'GuiAppsCacheRefreshRequired' -Fallback 'Installed status not scanned')
	}
	$setAppSelectionStateCommand = Get-GuiRuntimeCommand -Name 'Set-AppSelectionState' -CommandType 'Function'
	$setAppQueuedActionCommand = Get-GuiRuntimeCommand -Name 'Set-AppQueuedAction' -CommandType 'Function'
	$startAppsModuleActionAsyncCommand = Get-GuiRuntimeCommand -Name 'Start-AppsModuleActionAsync' -CommandType 'Function'
	if (-not $setAppSelectionStateCommand) { throw 'Set-AppSelectionState not found.' }
	if (-not $setAppQueuedActionCommand) { throw 'Set-AppQueuedAction not found.' }
	if (-not $startAppsModuleActionAsyncCommand) { throw 'Start-AppsModuleActionAsync not found.' }

	if ($allCatalog.Count -eq 0)
	{
		$emptyState = [System.Windows.Controls.Border]::new()
		$emptyState.Margin = [System.Windows.Thickness]::new(12)
		$emptyState.Padding = [System.Windows.Thickness]::new(18)
		$emptyState.CornerRadius = [System.Windows.CornerRadius]::new(8)
		$emptyState.Background = $bc.ConvertFromString($theme.CardBg)
		$emptyState.BorderBrush = $bc.ConvertFromString($theme.CardBorder)
		$emptyState.BorderThickness = [System.Windows.Thickness]::new(1)
		$emptyState.Child = [System.Windows.Controls.TextBlock]::new()
		$emptyState.Child.Text = (Get-UxLocalizedString -Key 'GuiAppsEmptyStateNoPackageBackedApplications' -Fallback 'No package-backed applications were found.')
		$emptyState.Child.TextWrapping = 'Wrap'
		$emptyState.Child.Foreground = $bc.ConvertFromString($theme.TextSecondary)
		[void]$Script:AppsWrapPanel.Children.Add($emptyState)
		$emptySummaryText = (Get-UxLocalizedString -Key 'GuiAppsEmptyStateNoPackageBackedApplications' -Fallback 'No package-backed applications were found.')
		if ($Script:TxtAppCacheStatus) { $Script:TxtAppCacheStatus.Text = $emptySummaryText }
		if ($Script:TxtAppsProgressText) { $Script:TxtAppsProgressText.Text = $emptySummaryText }
		$Script:AppsViewBuildSignature = $renderSignature
		Update-AppsSelectionSummary
		return
	}

	if ($catalog.Count -eq 0)
	{
		$emptyMessage = if (-not [string]::IsNullOrWhiteSpace([string]$activeSearchQuery) -and ($Script:AppsCategoryFilter -and $Script:AppsCategoryFilter -ne 'All'))
		{
			(Get-UxLocalizedString -Key 'GuiAppsEmptyStateSearchAndCategory' -Fallback 'No apps match your search in the selected category.')
		}
		elseif (-not [string]::IsNullOrWhiteSpace([string]$activeSearchQuery))
		{
			(Get-UxLocalizedString -Key 'GuiAppsEmptyStateSearch' -Fallback 'No apps match your search.')
		}
		elseif ($Script:AppsCategoryFilter -and $Script:AppsCategoryFilter -ne 'All')
		{
			(Get-UxLocalizedString -Key 'GuiAppsEmptyStateNoCategoryMatches' -Fallback 'No applications match the selected category.')
		}
		else
		{
			(Get-UxLocalizedString -Key 'GuiAppsEmptyStateNoPackageBackedApplications' -Fallback 'No package-backed applications were found.')
		}
		$emptyState = [System.Windows.Controls.Border]::new()
		$emptyState.Margin = [System.Windows.Thickness]::new(12)
		$emptyState.Padding = [System.Windows.Thickness]::new(18)
		$emptyState.CornerRadius = [System.Windows.CornerRadius]::new(8)
		$emptyState.Background = $bc.ConvertFromString($theme.CardBg)
		$emptyState.BorderBrush = $bc.ConvertFromString($theme.CardBorder)
		$emptyState.BorderThickness = [System.Windows.Thickness]::new(1)
		$emptyState.Child = [System.Windows.Controls.TextBlock]::new()
		$emptyState.Child.Text = $emptyMessage
		$emptyState.Child.TextWrapping = 'Wrap'
		$emptyState.Child.Foreground = $bc.ConvertFromString($theme.TextSecondary)
		[void]$Script:AppsWrapPanel.Children.Add($emptyState)
		if ($Script:TxtAppCacheStatus)
		{
			$installedCount = 0
			$updateAvailableCount = 0
			foreach ($entry in @($allCatalog))
			{
				if (-not $entry) { continue }
				$appState = Get-ApplicationExecutionState -Entry $entry -WinGetInstalledCache $installedWingetCache -ChocolateyInstalledCache $installedChocolateyCache -WinGetUpdateCache $wingetUpdateCache -ChocolateyUpdateCache $chocolateyUpdateCache -PreferredSource $Script:AppsPackageSourcePreference
				if ($appState.IsInstalled)
				{
					$installedCount++
				}
				if ($appState.UpdateAvailable)
				{
					$updateAvailableCount++
				}
			}
			$summaryText = if ($updateAvailableCount -gt 0)
			{
				[string]::Format((Get-UxLocalizedString -Key 'AppStatusSummaryWithUpdates' -Fallback 'Installed: {0}/{1} | Updates available: {2} | Showing: 0/{1}'), $installedCount, $allCatalog.Count, $updateAvailableCount)
			}
			else
			{
				[string]::Format((Get-UxLocalizedString -Key 'AppStatusSummary' -Fallback 'Installed: {0}/{1} | Showing: 0/{1}'), $installedCount, $allCatalog.Count)
			}
			$Script:TxtAppCacheStatus.Text = $summaryText
			if ($Script:TxtAppsProgressText)
			{
				$Script:TxtAppsProgressText.Text = $summaryText
			}
		}
		$Script:AppsViewBuildSignature = $renderSignature
		Update-AppsSelectionSummary
		return
	}

	$sortedCatalog = @($catalog | Sort-Object SubCategory, Name)
	$buildProgressLabel = [string]::Format(
		(Get-UxLocalizedString -Key 'GuiAppsLoadingCatalog' -Fallback 'Loading {0}...'),
		(Get-UxLocalizedString -Key 'Category_SoftwareApps_Title' -Fallback 'Software & Apps')
	)
	$installedCount = 0
	$updateAvailableCount = 0
	if ($Script:TxtAppCacheStatus -and $Script:AppsProgressBar)
	{
		$Script:TxtAppCacheStatus.Text = $buildProgressLabel
	}
	if ($Script:TxtAppsProgressText -and $buildProgressLabel)
	{
		$Script:TxtAppsProgressText.Text = $buildProgressLabel
	}
	if ($Script:AppsProgressBar)
	{
		try { $Script:AppsProgressBar.IsIndeterminate = $true } catch { Write-GuiRuntimeWarning -Context 'Build-AppsViewCards:ProgressBar' -Message $_.Exception.Message }
	}

	foreach ($app in @($sortedCatalog))
	{
		if (-not $app)
		{
			continue
		}

		$selectionCheckBox = $null
		$primaryButton = $null
		$updateButton = $null
		$appCapture = $null
		$isInstalledCapture = $false

		$appState = Get-ApplicationExecutionState -Entry $app -WinGetInstalledCache $installedWingetCache -ChocolateyInstalledCache $installedChocolateyCache -WinGetUpdateCache $wingetUpdateCache -ChocolateyUpdateCache $chocolateyUpdateCache -PreferredSource $Script:AppsPackageSourcePreference
		$entityType = [string]$appState.EntityType
		$supportsExecution = [bool]$appState.SupportsExecution
		$isInstalled = [bool]$appState.IsInstalled
		$hasUpdateAvailable = [bool]$appState.UpdateAvailable
		if ($isInstalled) { $installedCount++ }
		if ($hasUpdateAvailable) { $updateAvailableCount++ }
		$selectionKeyCapture = [string]$appState.SelectionKey
		$appActionState = if (-not [string]::IsNullOrWhiteSpace($selectionKeyCapture)) { Get-AppActionState -Application $app -SelectionKey $selectionKeyCapture } else { $null }

		$statusLabel = if ($appActionState)
		{
			switch ([string]$appActionState.State)
			{
				'Queued' { (Get-UxLocalizedString -Key 'GuiAppsQueued' -Fallback 'Queued') }
				'Installing' { (Get-UxLocalizedString -Key 'GuiAppsInstalling' -Fallback 'Installing') }
				'Failed' { (Get-UxLocalizedString -Key 'GuiAppsFailed' -Fallback 'Failed') }
				default
				{
					switch ($appState.State)
					{
						'Installed' { (Get-UxLocalizedString -Key 'Status_Installed' -Fallback 'Installed') }
						'Update available' { (Get-UxLocalizedString -Key 'GuiAppsUpdateAvailable' -Fallback 'Update available') }
						'Unsupported' { (Get-UxLocalizedString -Key 'GuiAppsUnsupportedAction' -Fallback 'Unsupported') }
						default { (Get-UxLocalizedString -Key 'Status_NotInstalled' -Fallback 'Not Installed') }
					}
				}
			}
		}
		else
		{
			switch ($appState.State)
			{
				'Installed' { (Get-UxLocalizedString -Key 'Status_Installed' -Fallback 'Installed') }
				'Update available' { (Get-UxLocalizedString -Key 'GuiAppsUpdateAvailable' -Fallback 'Update available') }
				'Unsupported' { (Get-UxLocalizedString -Key 'GuiAppsUnsupportedAction' -Fallback 'Unsupported') }
				default { (Get-UxLocalizedString -Key 'Status_NotInstalled' -Fallback 'Not Installed') }
			}
		}
		if (-not $cacheReady -and $supportsExecution)
		{
			$statusLabel = (Get-UxLocalizedString -Key 'GuiAppsCacheRefreshRequired' -Fallback 'Installed status not scanned')
		}
		$statusForeground = if ($appActionState)
		{
			switch ([string]$appActionState.State)
			{
				'Queued' { $theme.AccentBlue }
				'Installing' { $theme.AccentBlue }
				'Failed' { $theme.CautionBorder }
				default
				{
					switch ($appState.State)
					{
						'Installed' { $theme.ToggleOn }
						'Update available' { $theme.AccentBlue }
						'Unsupported' { $theme.TextMuted }
						default { $theme.TextMuted }
					}
				}
			}
		}
		if (-not $cacheReady -and $supportsExecution)
		{
			$statusForeground = $theme.TextMuted
		}
		else
		{
			switch ($appState.State)
			{
				'Installed' { $theme.ToggleOn }
				'Update available' { $theme.AccentBlue }
				'Unsupported' { $theme.TextMuted }
				default { $theme.TextMuted }
			}
		}

		$primaryAction = if ($supportsExecution)
		{
			if ($isInstalled)
			{
				(Get-UxLocalizedString -Key 'Uninstall' -Fallback 'Uninstall')
			}
			else
			{
				(Get-UxLocalizedString -Key 'Install' -Fallback 'Install')
			}
		}
		else
		{
			(Get-UxLocalizedString -Key 'GuiAppsUnsupportedAction' -Fallback 'Unsupported')
		}
		$selectedSource = if ($appState -and $appState.PSObject.Properties['SelectedSource']) { [string]$appState.SelectedSource } else { $null }
		$selectedSourceLabel = switch ($selectedSource)
		{
			'winget' { (Get-UxLocalizedString -Key 'GuiAppsSourceWinGet' -Fallback 'WinGet') }
			'choco' { (Get-UxLocalizedString -Key 'GuiAppsSourceChocolatey' -Fallback 'Chocolatey') }
			'store' { (Get-UxLocalizedString -Key 'GuiAppsSourceStore' -Fallback 'Store') }
			'direct' { (Get-UxLocalizedString -Key 'GuiAppsSourceDirect' -Fallback 'Direct Download') }
			'command' { (Get-UxLocalizedString -Key 'GuiAppsSourceCommand' -Fallback 'Custom Command') }
			default { $null }
		}
		$selectedSourceTooltip = switch ($selectedSource)
		{
			'winget' { (Get-UxLocalizedString -Key 'GuiAppsSourceWinGetTip' -Fallback 'This app will use WinGet for the selected action.') }
			'choco' { (Get-UxLocalizedString -Key 'GuiAppsSourceChocolateyTip' -Fallback 'This app will use Chocolatey for the selected action.') }
			'store' { (Get-UxLocalizedString -Key 'GuiAppsSourceStoreTip' -Fallback 'This app opens the Microsoft Store for the selected action.') }
			'direct' { (Get-UxLocalizedString -Key 'GuiAppsSourceDirectTip' -Fallback 'This app uses a direct download route for the selected action.') }
			'command' { (Get-UxLocalizedString -Key 'GuiAppsSourceCommandTip' -Fallback 'This app uses a custom command route for the selected action.') }
			default { $null }
		}
		$statusTone = if ($appActionState)
		{
			switch ([string]$appActionState.State)
			{
				'Queued' { 'Primary' }
				'Installing' { 'Caution' }
				'Failed' { 'Danger' }
				default
				{
					switch ($appState.State)
					{
						'Installed' { 'Success' }
						'Update available' { 'Primary' }
						'Unsupported' { 'Muted' }
						default { 'Muted' }
					}
				}
			}
		}
		else
		{
			switch ($appState.State)
			{
				'Installed' { 'Success' }
				'Update available' { 'Primary' }
				'Unsupported' { 'Muted' }
				default { 'Muted' }
			}
		}
		$statusTooltip = if ($appActionState -and -not [string]::IsNullOrWhiteSpace([string]$appActionState.Message))
		{
			[string]$appActionState.Message
		}
		else
		{
			switch ([string]$appState.State)
			{
				'Installed' { (Get-UxLocalizedString -Key 'GuiAppsStatusInstalledTip' -Fallback 'This app is currently installed.') }
				'Update available' { (Get-UxLocalizedString -Key 'GuiAppsStatusUpdateAvailableTip' -Fallback 'An update is available for this app.') }
				'Unsupported' { (Get-UxLocalizedString -Key 'GuiAppsStatusUnsupportedTip' -Fallback 'This catalog entry does not support direct execution.') }
				default { (Get-UxLocalizedString -Key 'GuiAppsStatusNotInstalledTip' -Fallback 'This app is not currently installed.') }
			}
		}
		if (-not $cacheReady -and $supportsExecution)
		{
			$statusTooltip = $cacheRefreshPrompt
		}
		$isAppActionBusy = $appActionState -and @('Queued', 'Installing') -contains [string]$appActionState.State
		$appIconName = if (Get-Command -Name 'Get-GuiApplicationIconName' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Get-GuiApplicationIconName -Name $app.Name -SubCategory $app.SubCategory -Tags $app.Tags -SourceRegion $app.SourceRegion
		}
		else
		{
			'AppGeneric'
		}
		$card = [System.Windows.Controls.Border]::new()
		$card.Width = 340
		$card.Margin = [System.Windows.Thickness]::new(8)
		$card.Padding = [System.Windows.Thickness]::new(16)
		$card.CornerRadius = [System.Windows.CornerRadius]::new(8)
		$card.Background = $bc.ConvertFromString($theme.CardBg)
		$card.BorderBrush = $bc.ConvertFromString($theme.CardBorder)
		$card.BorderThickness = [System.Windows.Thickness]::new(1)

		$stack = [System.Windows.Controls.StackPanel]::new()
		$stack.Orientation = 'Vertical'

		$headerGrid = [System.Windows.Controls.Grid]::new()
		$headerGrid.Margin = [System.Windows.Thickness]::new(0, 0, 0, 2)
		$headerGrid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new())
		$headerGrid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new())
		$headerGrid.ColumnDefinitions[0].Width = [System.Windows.GridLength]::Auto
		$headerGrid.ColumnDefinitions[1].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)

		if ($appIconName)
		{
			$appIcon = New-GuiIconTextBlock -IconName $appIconName -Size 18 -Foreground $bc.ConvertFromString($theme.AccentBlue) -VerticalAlignment 'Center'
			if ($appIcon)
			{
				$appIcon.Margin = [System.Windows.Thickness]::new(0, 1, 12, 0)
				[System.Windows.Controls.Grid]::SetColumn($appIcon, 0)
				[void]$headerGrid.Children.Add($appIcon)
			}
		}

		$title = [System.Windows.Controls.TextBlock]::new()
		$title.Text = [string]$app.Name
		$title.FontSize = 14
		$title.FontWeight = [System.Windows.FontWeights]::Bold
		$title.TextWrapping = 'Wrap'
		$title.Foreground = $bc.ConvertFromString($theme.TextPrimary)
		[System.Windows.Controls.Grid]::SetColumn($title, 1)
		[void]$headerGrid.Children.Add($title)
		[void]$stack.Children.Add($headerGrid)

		if (-not [string]::IsNullOrWhiteSpace([string]$app.SubCategory))
		{
			$subTitle = [System.Windows.Controls.TextBlock]::new()
			$subTitle.Text = [string]$app.SubCategory
			$subTitle.FontSize = 10
			$subTitle.Margin = [System.Windows.Thickness]::new(0, 2, 0, 0)
			$subTitle.Foreground = $bc.ConvertFromString($theme.SectionLabel)
			[void]$stack.Children.Add($subTitle)
		}

		if (-not [string]::IsNullOrWhiteSpace($entityType) -and $entityType -ne 'winget')
		{
			$typeBadge = [System.Windows.Controls.TextBlock]::new()
			$typeBadge.Text = switch ($entityType)
			{
				'choco' { (Get-UxLocalizedString -Key 'AppTypeBadgeChoco' -Fallback 'Chocolatey package') }
				'uwp' { (Get-UxLocalizedString -Key 'AppTypeBadgeUWP' -Fallback 'UWP app') }
				'feature' { (Get-UxLocalizedString -Key 'AppTypeBadgeFeature' -Fallback 'Windows feature') }
				'system' { (Get-UxLocalizedString -Key 'AppTypeBadgeSystem' -Fallback 'System component') }
				'placeholder' { (Get-UxLocalizedString -Key 'AppTypeBadgePlaceholder' -Fallback 'No install method') }
				default { [string]$entityType }
			}
			$typeBadge.FontSize = 9
			$typeBadge.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)
			$typeBadge.Foreground = $bc.ConvertFromString($theme.TextMuted)
			[void]$stack.Children.Add($typeBadge)
		}

		if (-not [string]::IsNullOrWhiteSpace([string]$app.Description))
		{
			$description = [System.Windows.Controls.TextBlock]::new()
			$description.Text = [string]$app.Description
			$description.TextWrapping = 'Wrap'
			$description.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
			$description.Foreground = $bc.ConvertFromString($theme.TextSecondary)
			[void]$stack.Children.Add($description)
		}

		if (-not [string]::IsNullOrWhiteSpace([string]$app.Detail))
		{
			$detail = [System.Windows.Controls.TextBlock]::new()
			$detail.Text = [string]$app.Detail
			$detail.TextWrapping = 'Wrap'
			$detail.Margin = [System.Windows.Thickness]::new(0, 6, 0, 0)
			$detail.FontSize = 10
			$detail.Foreground = $bc.ConvertFromString($theme.TextMuted)
			[void]$stack.Children.Add($detail)
		}

		$metadataItems = [System.Collections.Generic.List[object]]::new()
		if (-not [string]::IsNullOrWhiteSpace($statusLabel))
		{
			[void]$metadataItems.Add([pscustomobject]@{
				Label = $statusLabel
				Tone = $statusTone
				ToolTip = $statusTooltip
			})
		}
		if (-not [string]::IsNullOrWhiteSpace($selectedSourceLabel))
		{
			[void]$metadataItems.Add([pscustomobject]@{
				Label = $selectedSourceLabel
				Tone = 'Primary'
				ToolTip = $selectedSourceTooltip
			})
		}
		if ($metadataItems.Count -gt 0)
		{
			$metadataPanel = GUICommon\New-DialogMetadataPillPanel -Theme $theme -Items $metadataItems
			if ($metadataPanel)
			{
				$metadataPanel.Margin = [System.Windows.Thickness]::new(0, 10, 0, 0)
				[void]$stack.Children.Add($metadataPanel)
			}
		}

			if ($supportsExecution)
			{
				if (-not $cacheReady)
				{
					$refreshNotice = [System.Windows.Controls.TextBlock]::new()
					$refreshNotice.Text = $cacheRefreshPrompt
					$refreshNotice.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
					$refreshNotice.TextWrapping = [System.Windows.TextWrapping]::Wrap
					$refreshNotice.FontSize = 10
					$refreshNotice.Foreground = $bc.ConvertFromString($theme.TextMuted)
					$refreshNotice.ToolTip = $cacheRefreshPrompt
					[void]$stack.Children.Add($refreshNotice)
				}

				$selectionRow = [System.Windows.Controls.DockPanel]::new()
				$selectionRow.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
				$selectionRow.LastChildFill = $true

				$selectionCheckBox = [System.Windows.Controls.CheckBox]::new()
				$selectionCheckBox.Content = (Get-UxLocalizedString -Key 'GuiAppsSelectLabel' -Fallback 'Select')
				$selectionCheckBox.Margin = [System.Windows.Thickness]::new(12, 0, 0, 0)
				$selectionCheckBox.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
				$selectionCheckBox.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
				$selectionCheckBox.ToolTip = (Get-UxLocalizedString -Key 'GuiAppsSelectTooltip' -Fallback 'Include this app in bulk actions.')
				$selectionCheckBox.Foreground = $bc.ConvertFromString($theme.TextPrimary)
				$selectionCheckBox.Tag = $selectionKeyCapture
				$selectionCheckBox.IsChecked = [bool]($Script:SelectedAppIds -and $Script:SelectedAppIds.Contains($selectionKeyCapture))
				$selectionCheckBox.Add_Checked({
					if ($Script:AppsSelectionUiUpdating) { return }
					& $setAppSelectionStateCommand -SelectionKey $selectionKeyCapture -Selected $true
				}.GetNewClosure())
				$selectionCheckBox.Add_Unchecked({
					if ($Script:AppsSelectionUiUpdating) { return }
					& $setAppSelectionStateCommand -SelectionKey $selectionKeyCapture -Selected $false
				}.GetNewClosure())
				[System.Windows.Controls.DockPanel]::SetDock($selectionCheckBox, [System.Windows.Controls.Dock]::Right)
				[void]$selectionRow.Children.Add($selectionCheckBox)
				[void]$Script:AppsSelectionControls.Add($selectionCheckBox)

				$statusRow = [System.Windows.Controls.TextBlock]::new()
				$statusRow.Text = $statusLabel
				$statusRow.Margin = [System.Windows.Thickness]::new(0)
				$statusRow.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
				$statusRow.TextWrapping = [System.Windows.TextWrapping]::Wrap
				$statusRow.FontSize = 10
				$statusRow.Foreground = $bc.ConvertFromString($statusForeground)
				if (-not [string]::IsNullOrWhiteSpace($statusTooltip))
				{
					$statusRow.ToolTip = $statusTooltip
				}
				[void]$selectionRow.Children.Add($statusRow)
				[void]$stack.Children.Add($selectionRow)

			$buttonRow = [System.Windows.Controls.WrapPanel]::new()
			$buttonRow.Orientation = 'Horizontal'
			$buttonRow.Margin = [System.Windows.Thickness]::new(0, 12, 0, 0)

			$appCapture = $app
			$primaryActionKind = if ($isInstalled) { 'Uninstall' } else { 'Install' }
			$primaryActionRequiresCache = ($primaryActionKind -ne 'Install')
			$primaryButton = [System.Windows.Controls.Button]::new()
			$primaryButton.Content = $primaryAction
			$primaryButton.MinWidth = 88
			$primaryButton.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
			$primaryButton.Cursor = [System.Windows.Input.Cursors]::Hand
			$primaryButton.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress) -and (-not $isAppActionBusy) -and ((-not $primaryActionRequiresCache) -or $cacheReady)
			$primaryButton.ToolTip = if ($primaryActionKind -eq 'Install')
			{
				(Get-UxLocalizedString -Key 'Tooltip_InstallApplication' -Fallback 'Install this application.')
			}
			else
			{
				(Get-UxLocalizedString -Key 'Tooltip_UninstallApplication' -Fallback 'Uninstall this application.')
			}
			Set-ButtonChrome -Button $primaryButton -Variant 'Primary' -Compact
			$primaryButtonIcon = if ($primaryActionKind -eq 'Install') { 'ArrowDownload' } else { 'Delete' }
			Set-GuiButtonIconContent -Button $primaryButton -IconName $primaryButtonIcon -Text $primaryAction -IconSize 14 -Gap 6 -TextFontSize 11 -ToolTip $primaryButton.ToolTip
			[void]$Script:AppsActionButtons.Add($primaryButton)
			$capturedPrimaryAction = $primaryActionKind
			$primaryButton.Add_Click({
				param($buttonSender, $buttonEventArgs)
				$null = $buttonEventArgs
				try
				{
					& $startAppsModuleActionAsyncCommand -Action $capturedPrimaryAction -Application $appCapture
				}
				catch
				{
					$null = & $Script:ShowGuiRuntimeFailureScript -Context 'AppPrimaryButton' -Exception $_.Exception -ShowDialog
				}
			}.GetNewClosure())
			[void]$buttonRow.Children.Add($primaryButton)

			if ($isInstalled -or $hasUpdateAvailable)
			{
				$updateButton = [System.Windows.Controls.Button]::new()
				$updateButton.Content = (Get-UxLocalizedString -Key 'Update' -Fallback 'Update')
				$updateButton.MinWidth = 88
				$updateButton.Cursor = [System.Windows.Input.Cursors]::Hand
				$updateButton.IsEnabled = -not $isAppActionBusy
				$updateButton.ToolTip = if (-not [string]::IsNullOrWhiteSpace($selectedSourceLabel))
				{
					(Get-UxLocalizedString -Key 'GuiAppsUpdateSelectedViaSourceTip' -Fallback ('Update using {0}.' -f $selectedSourceLabel))
				}
				else
				{
					(Get-UxLocalizedString -Key 'Tooltip_UpdateApplication' -Fallback 'Update this application.')
				}
				Set-ButtonChrome -Button $updateButton -Variant 'Secondary' -Compact
				Set-GuiButtonIconContent -Button $updateButton -IconName 'ArrowSync' -Text (Get-UxLocalizedString -Key 'Update' -Fallback 'Update') -IconSize 14 -Gap 6 -TextFontSize 11 -ToolTip $updateButton.ToolTip
				[void]$Script:AppsActionButtons.Add($updateButton)
					$updateButton.Add_Click({
					param($buttonSender, $buttonEventArgs)
					$null = $buttonEventArgs
					try
					{
						& $startAppsModuleActionAsyncCommand -Action 'Update' -Application $appCapture
					}
					catch
					{
						$null = & $Script:ShowGuiRuntimeFailureScript -Context 'AppUpdateButton' -Exception $_.Exception -ShowDialog
					}
				}.GetNewClosure())
				[void]$buttonRow.Children.Add($updateButton)
			}

			[void]$stack.Children.Add($buttonRow)
		}
		else
		{
			$unsupportedText = [System.Windows.Controls.TextBlock]::new()
			$unsupportedText.Text = (Get-UxLocalizedString -Key 'GuiAppsUnsupportedAction' -Fallback 'No install method available.')
			$unsupportedText.Margin = [System.Windows.Thickness]::new(0, 10, 0, 0)
			$unsupportedText.TextWrapping = [System.Windows.TextWrapping]::Wrap
			$unsupportedText.FontSize = 10
			$unsupportedText.Foreground = $bc.ConvertFromString($theme.TextMuted)
			[void]$stack.Children.Add($unsupportedText)
		}

		$card.Child = $stack

		if (Get-Command -Name 'Add-CardHoverEffects' -CommandType Function -ErrorAction SilentlyContinue)
		{
			$focusSources = @()
			if ($selectionCheckBox) { $focusSources += $selectionCheckBox }
			if ($primaryButton) { $focusSources += $primaryButton }
			if ($updateButton) { $focusSources += $updateButton }
			if ($focusSources.Count -gt 0)
			{
				try { Add-CardHoverEffects -Card $card -FocusSources $focusSources } catch { $null = $_ }
			}
		}

		[void]$Script:AppsWrapPanel.Children.Add($card)
		if (($Script:AppsWrapPanel.Children.Count % 10) -eq 0)
		{
			try { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background) } catch { $null = $_ }
		}
	}

	if ($Script:TxtAppCacheStatus)
	{
		if (-not $cacheReady)
		{
			$Script:TxtAppCacheStatus.Text = $cacheRefreshPrompt
			if ($Script:TxtAppsProgressText)
			{
				$Script:TxtAppsProgressText.Text = $cacheRefreshPrompt
			}
			Update-AppsSelectionSummary
			return
		}
		$summaryText = if ($Script:AppsCategoryFilter -and $Script:AppsCategoryFilter -ne 'All')
		{
			if ($updateAvailableCount -gt 0)
			{
				[string]::Format((Get-UxLocalizedString -Key 'AppStatusSummaryFilteredWithUpdates' -Fallback 'Installed: {0}/{1} | Updates available: {2} | Showing: {3}/{1}'), $installedCount, $allCatalog.Count, $updateAvailableCount, $catalog.Count)
			}
			else
			{
				[string]::Format((Get-UxLocalizedString -Key 'AppStatusSummaryFiltered' -Fallback 'Installed: {0}/{1} | Showing: {2}/{1}'), $installedCount, $allCatalog.Count, $catalog.Count)
			}
		}
		else
		{
			if ($updateAvailableCount -gt 0)
			{
				[string]::Format((Get-UxLocalizedString -Key 'AppStatusSummaryAllWithUpdates' -Fallback 'Installed: {0}/{1} | Updates available: {2}'), $installedCount, $allCatalog.Count, $updateAvailableCount)
			}
			else
			{
				[string]::Format((Get-UxLocalizedString -Key 'AppStatusSummaryAll' -Fallback 'Installed: {0}/{1}'), $installedCount, $allCatalog.Count)
			}
		}
		$Script:TxtAppCacheStatus.Text = $summaryText
		if ($Script:TxtAppsProgressText)
		{
			$Script:TxtAppsProgressText.Text = $summaryText
		}
	}
	if ($Script:AppsProgressBar)
	{
		try
		{
			$Script:AppsProgressBar.IsIndeterminate = $false
			$Script:AppsProgressBar.Maximum = 1
			$Script:AppsProgressBar.Value = 0
		}
		catch
		{
			Write-GuiRuntimeWarning -Context 'Build-AppsViewCards:ProgressBarReset' -Message $_.Exception.Message
		}
	}
	$Script:AppsViewBuildSignature = $renderSignature
	Update-AppsSelectionSummary
}

<#
    .SYNOPSIS
    Internal function Start-AppsCacheRefresh.
#>

function Start-AppsCacheRefresh
{
	[CmdletBinding()]
	param ()

	if ($Script:AppsCacheRefreshInProgress)
	{
		return
	}

	$Script:AppsCacheRefreshInProgress = $true
	Set-AppsActionControlsEnabled -Enabled $false
	Initialize-AppsProgressSection
	if ($Script:AppsProgressContainer)
	{
		$Script:AppsProgressContainer.Visibility = [System.Windows.Visibility]::Visible
	}
	$syncHash = [hashtable]::Synchronized(@{
		Completed    = 0
		Total        = 4
		CurrentAction = (Get-UxLocalizedString -Key 'Progress_CheckingInstallStatus' -Fallback 'Checking installation status...')
		IsComplete   = $false
		Error        = $null
	})
	if ($Script:TxtAppCacheStatus)
	{
		$initialProgressText = Set-SharedProgressBarState -ProgressBar $Script:AppsProgressBar -ProgressText $Script:TxtAppsProgressText -Completed $syncHash.Completed -Total $syncHash.Total -CurrentAction $syncHash.CurrentAction -PassThruText
		$Script:TxtAppCacheStatus.Text = $initialProgressText
	}

	$appModulePath = Join-Path -Path $Script:GuiModuleBasePath -ChildPath 'Regions\Applications.psm1'
	$runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
	$runspace.Open()
	$ps = [System.Management.Automation.PowerShell]::Create()
	$ps.Runspace = $runspace
	$appsGetApplicationCacheSnapshotCommand = Get-Command 'Get-ApplicationCacheSnapshot' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$appsSetSharedProgressBarStateCommand = Get-Command 'Set-SharedProgressBarState' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$appsGetUxLocalizedStringCommand = Get-Command 'Get-UxLocalizedString' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$appsBuildAppsViewCardsCommand = Get-Command 'Build-AppsViewCards' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$appsLogErrorCommand = Get-Command 'LogError' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$appsSetActionControlsEnabledCommand = Get-Command 'Set-AppsActionControlsEnabled' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1

	if (-not $appsGetApplicationCacheSnapshotCommand) { throw 'Get-ApplicationCacheSnapshot not found.' }
	if (-not $appsSetSharedProgressBarStateCommand) { throw 'Set-SharedProgressBarState not found.' }
	if (-not $appsGetUxLocalizedStringCommand) { throw 'Get-UxLocalizedString not found.' }
	if (-not $appsBuildAppsViewCardsCommand) { throw 'Build-AppsViewCards not found.' }
	if (-not $appsLogErrorCommand) { throw 'LogError not found.' }
	if (-not $appsSetActionControlsEnabledCommand) { throw 'Set-AppsActionControlsEnabled not found.' }

	$null = $ps.AddScript({
		param ($ModulePath, $Sync)
		Import-Module -Force -Name $ModulePath
		$wingetCache = @{}
		$chocolateyCache = @{}
		$wingetUpdateCache = @{}
		$chocolateyUpdateCache = @{}
		$Sync.Total = 4
		$Sync.Completed = 0
		$Sync.CurrentAction = (Get-UxLocalizedString -Key 'Progress_CheckingInstallStatus' -Fallback 'Checking installation status...')
		try
		{
			$Sync.CurrentAction = (Get-UxLocalizedString -Key 'Progress_CheckingInstallStatus' -Fallback 'Checking installation status...')
			$wingetCache = Get-InstalledAppCache
		}
		catch
		{
			LogWarning (Get-UxBilingualLocalizedString -Key 'GuiLogWinGetInstalledCacheRefreshFailed' -Fallback 'WinGet installed-cache scan failed: {0}' -FormatArgs @($_.Exception.Message))
		}
		finally
		{
			$Sync.Completed = 1
		}
		try
		{
			$Sync.CurrentAction = (Get-UxLocalizedString -Key 'GuiAppsCacheRefreshScanningChocolateyInstalled' -Fallback 'Checking Chocolatey installation status...')
			$chocolateyCache = Get-InstalledChocolateyAppCache
		}
		catch
		{
			LogWarning (Get-UxBilingualLocalizedString -Key 'GuiLogChocolateyInstalledCacheRefreshFailed' -Fallback 'Chocolatey installed-cache scan failed: {0}' -FormatArgs @($_.Exception.Message))
		}
		finally
		{
			$Sync.Completed = 2
		}
		try
		{
			$Sync.CurrentAction = (Get-UxLocalizedString -Key 'Progress_WinGet_CheckingUpdates' -Fallback 'Checking for WinGet updates...')
			$wingetUpdateCache = Get-AvailableAppUpdateCache
		}
		catch
		{
			LogWarning (Get-UxBilingualLocalizedString -Key 'GuiLogWinGetUpdateCacheRefreshFailed' -Fallback 'WinGet update-cache scan failed: {0}' -FormatArgs @($_.Exception.Message))
		}
		finally
		{
			$Sync.Completed = 3
		}
		try
		{
			$Sync.CurrentAction = (Get-UxLocalizedString -Key 'GuiAppsCacheRefreshScanningChocolateyUpdates' -Fallback 'Checking Chocolatey update availability...')
			$chocolateyUpdateCache = Get-AvailableChocolateyUpdateCache
		}
		catch
		{
			LogWarning (Get-UxBilingualLocalizedString -Key 'GuiLogChocolateyUpdateCacheRefreshFailed' -Fallback 'Chocolatey update-cache scan failed: {0}' -FormatArgs @($_.Exception.Message))
		}
		finally
		{
			$Sync.Completed = 4
		}
		$Sync.CurrentAction = (Get-UxLocalizedString -Key 'GuiAppsCacheRefreshComplete' -Fallback 'Installed apps scanned.')
		[pscustomobject]@{
			WinGet = $wingetCache
			Chocolatey = $chocolateyCache
			WinGetUpdates = $wingetUpdateCache
			ChocolateyUpdates = $chocolateyUpdateCache
		}
	}).AddArgument($appModulePath).AddArgument($syncHash)

	$asyncResult = $ps.BeginInvoke()
	$timer = [System.Windows.Threading.DispatcherTimer]::new()
	$timer.Interval = [TimeSpan]::FromMilliseconds(100)
	$timer.Add_Tick({
		if ($syncHash.Error)
		{
			$timer.Stop()
			if ($Script:TxtAppCacheStatus)
			{
				$Script:TxtAppCacheStatus.Text = (Set-SharedProgressBarState -ProgressBar $Script:AppsProgressBar -ProgressText $Script:TxtAppsProgressText -Completed 0 -Total 1 -CurrentAction (Get-UxLocalizedString -Key 'GuiAppsCacheRefreshFailed' -Fallback 'Failed to scan installed applications.') -PassThruText)
			}
			& $appsLogErrorCommand (& $appsGetUxLocalizedStringCommand -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @([string]$syncHash.Error))
			try { $ps.Dispose() } catch { $null = $_ }
			try { $runspace.Dispose() } catch { $null = $_ }
			return
		}

		if ($Script:AppsProgressBar -or $Script:TxtAppsProgressText)
		{
			$progressText = & $appsSetSharedProgressBarStateCommand -ProgressBar $Script:AppsProgressBar -ProgressText $Script:TxtAppsProgressText -Completed $syncHash.Completed -Total $syncHash.Total -CurrentAction $syncHash.CurrentAction -PassThruText
			if ($Script:TxtAppCacheStatus)
			{
				$Script:TxtAppCacheStatus.Text = $progressText
			}
		}

		if (-not $asyncResult.IsCompleted)
		{
			return
		}

		$timer.Stop()
		try
		{
			$cacheResult = @($ps.EndInvoke($asyncResult))
			$cachePayload = if ($cacheResult.Count -gt 0) { $cacheResult[0] } else { $null }
			if ($cachePayload -is [psobject])
			{
				$Script:InstalledAppsCache = & $appsGetApplicationCacheSnapshotCommand -CacheState $cachePayload
			}
			elseif ($cachePayload -is [hashtable])
			{
				$Script:InstalledAppsCache = [pscustomobject]@{
					WinGet = $cachePayload
					Chocolatey = @{}
					WinGetUpdates = @{}
					ChocolateyUpdates = @{}
				}
			}
			else
			{
				$Script:InstalledAppsCache = [pscustomobject]@{
					WinGet = @{}
					Chocolatey = @{}
					WinGetUpdates = @{}
					ChocolateyUpdates = @{}
				}
			}
			$Script:AppsViewLoaded = $true
			$Script:AppsViewDirty = $false
			& $appsSetSharedProgressBarStateCommand -ProgressBar $Script:AppsProgressBar -ProgressText $Script:TxtAppsProgressText -Completed $syncHash.Total -Total $syncHash.Total -CurrentAction $syncHash.CurrentAction | Out-Null
			& $appsBuildAppsViewCardsCommand
		}
		catch
		{
			$Script:InstalledAppsCache = [pscustomobject]@{
				WinGet = @{}
				Chocolatey = @{}
				WinGetUpdates = @{}
				ChocolateyUpdates = @{}
			}
			$Script:AppsViewLoaded = $false
			$Script:AppsViewDirty = $true
			$progressText = & $appsSetSharedProgressBarStateCommand -ProgressBar $Script:AppsProgressBar -ProgressText $Script:TxtAppsProgressText -Completed 0 -Total 1 -CurrentAction (& $appsGetUxLocalizedStringCommand -Key 'GuiAppsCacheRefreshFailed' -Fallback 'Failed to scan installed applications.') -PassThruText
			if ($Script:TxtAppCacheStatus)
			{
				$Script:TxtAppCacheStatus.Text = $progressText
			}
			& $appsLogErrorCommand (& $appsGetUxLocalizedStringCommand -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message))
		}
		finally
		{
			$Script:AppsCacheRefreshInProgress = $false
			& $appsSetActionControlsEnabledCommand -Enabled $true
			try { $ps.Dispose() } catch { $null = $_ }
			try { $runspace.Dispose() } catch { $null = $_ }
		}
	}.GetNewClosure())
	$timer.Start()
}

<#
    .SYNOPSIS
    Internal function Start-AppsModuleActionAsync.
#>

function Start-AppsModuleActionAsync
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateSet('Install', 'Uninstall', 'Update', 'UpdateAll')]
		[string]$Action,

		[string]$WinGetId,

		[string]$ChocoId,

		[string]$DisplayName,

		[object]$Application,

		[string]$PreferredSource = $null
	)

	$resolvedWinGetId = $WinGetId
	$resolvedChocoId = $ChocoId
	$resolvedDisplayName = $DisplayName
	if ($Application)
	{
		if ([string]::IsNullOrWhiteSpace([string]$resolvedDisplayName) -and $Application.PSObject.Properties['Name'])
		{
			$resolvedDisplayName = [string]$Application.Name
		}
		if ([string]::IsNullOrWhiteSpace([string]$resolvedWinGetId) -and $Application.PSObject.Properties['WinGetId'])
		{
			$resolvedWinGetId = [string]$Application.WinGetId
		}
		if ([string]::IsNullOrWhiteSpace([string]$resolvedChocoId) -and $Application.PSObject.Properties['ChocoId'])
		{
			$resolvedChocoId = [string]$Application.ChocoId
		}
	}
	Initialize-AppPackageSourcePreferenceState
	$resolvedPreferredSource = ConvertTo-AppPackageSourcePreference -Source $(if ([string]::IsNullOrWhiteSpace([string]$PreferredSource)) { $Script:AppsPackageSourcePreference } else { $PreferredSource })

	$appModulePath = Join-Path -Path $Script:GuiModuleBasePath -ChildPath 'Regions\Applications.psm1'
	$bgUICulture = if ([string]::IsNullOrWhiteSpace([string]$Script:SelectedLanguage)) { 'en' } else { [string]$Script:SelectedLanguage }
	Start-GuiAppExecutionRun `
		-Action $Action `
		-LoaderPath $appModulePath `
		-LocalizationDirectory $Script:GuiLocalizationDirectoryPath `
		-UICulture $bgUICulture `
		-LogFilePath $Global:LogFilePath `
		-WinGetId $resolvedWinGetId `
		-ChocoId $resolvedChocoId `
		-DisplayName $resolvedDisplayName `
		-Application $Application `
		-PreferredSource $resolvedPreferredSource `
		-PackageManagerAvailabilityState $Script:AppsPackageManagerAvailabilityState
}

<#
    .SYNOPSIS
    Internal function Start-AppsModuleBatchActionAsync.
#>

function Start-AppsModuleBatchActionAsync
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateSet('Install', 'Uninstall', 'Update')]
		[string]$Action,

		[object[]]$SelectedApps = @(),

		[string]$PreferredSource = $null
	)

	Initialize-AppsSelectionState
	if (-not $SelectedApps -or $SelectedApps.Count -eq 0)
	{
		$SelectedApps = @(Get-SelectedAppsCatalogItems)
	}
	else
	{
		$SelectedApps = @($SelectedApps | Where-Object { $_ })
	}

	Initialize-AppPackageSourcePreferenceState
	$resolvedPreferredSource = ConvertTo-AppPackageSourcePreference -Source $(if ([string]::IsNullOrWhiteSpace([string]$PreferredSource)) { $Script:AppsPackageSourcePreference } else { $PreferredSource })

	if ($SelectedApps.Count -eq 0)
	{
		return
	}

	$appModulePath = Join-Path -Path $Script:GuiModuleBasePath -ChildPath 'Regions\Applications.psm1'
	$bgUICulture = if ([string]::IsNullOrWhiteSpace([string]$Script:SelectedLanguage)) { 'en' } else { [string]$Script:SelectedLanguage }
	Start-GuiAppExecutionRun `
		-Action $Action `
		-LoaderPath $appModulePath `
		-LocalizationDirectory $Script:GuiLocalizationDirectoryPath `
		-UICulture $bgUICulture `
		-LogFilePath $Global:LogFilePath `
		-SelectedApps @($SelectedApps) `
		-PreferredSource $resolvedPreferredSource `
		-PackageManagerAvailabilityState $Script:AppsPackageManagerAvailabilityState
}

<#
    .SYNOPSIS
    Internal function Set-GuiAppsMode.
#>

function Set-GuiAppsMode
{
	[CmdletBinding()]
	param (
		[bool]$Enable = $false
	)

	if ($Script:AppsModeActive -eq $Enable)
	{
		return
	}

	$Script:AppsModeActive = $Enable
	if ($Script:NavModeTweaks) { $Script:NavModeTweaks.IsChecked = -not $Enable }
	if ($Script:NavModeApps) { $Script:NavModeApps.IsChecked = $Enable }
	if ($Enable -and (-not $Script:AppsProgressBar -or -not $Script:AppsProgressHost))
	{
		Initialize-AppsProgressSection
	}
	if ($Enable -and $Script:AppsProgressBar -and -not $Script:AppsOperationInProgress -and -not $Script:AppsCacheRefreshInProgress)
	{
		$appsViewAlreadyRendered = [bool]($Script:AppsWrapPanel -and $Script:AppsWrapPanel.Children -and $Script:AppsWrapPanel.Children.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$Script:AppsViewBuildSignature))
		if (-not $appsViewAlreadyRendered)
		{
			$Script:AppsProgressBar.IsIndeterminate = $false
			$Script:AppsProgressBar.Maximum = 1
			$Script:AppsProgressBar.Value = 0
			if ($Script:TxtAppsProgressText)
			{
				$Script:TxtAppsProgressText.Text = (Get-AppsCacheRefreshPromptText)
			}
			if ($Script:TxtAppCacheStatus)
			{
				$Script:TxtAppCacheStatus.Text = (Get-AppsCacheRefreshPromptText)
			}
			if (Get-Command -Name 'Update-AppsPackageManagerBanner' -CommandType Function -ErrorAction SilentlyContinue)
			{
				try { Update-AppsPackageManagerBanner } catch { $null = $_ }
			}
		}
	}

	$collapsed = [System.Windows.Visibility]::Collapsed
	$visible = [System.Windows.Visibility]::Visible

	if ($Script:TweaksView) { $Script:TweaksView.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:AppsView) { $Script:AppsView.Visibility = if ($Enable) { $visible } else { $collapsed } }
	if ($Script:PrimaryTabHost) { $Script:PrimaryTabHost.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:ExpertModeBanner) { $Script:ExpertModeBanner.Visibility = if ($Enable) { $collapsed } else { $visible } }

	if ($Script:TxtSearch)
	{
		$desiredSearchText = if ($Enable) { [string]$Script:AppsSearchText } else { [string]$Script:SearchText }
		if ($Script:TxtSearch.Text -ne $desiredSearchText)
		{
			$Script:SearchUiUpdating = $true
			try
			{
				$Script:TxtSearch.Text = $desiredSearchText
			}
			finally
			{
				$Script:SearchUiUpdating = $false
			}
		}
	}

	if ($Enable)
	{
		Initialize-AppPackageSourcePreferenceState
		Update-AppPackageSourcePreferenceControls
	}

	foreach ($control in @($Script:BtnFilterToggle, $Script:FilterOptionsPanel))
	{
		if ($control)
		{
			$control.Visibility = if ($Enable) { $collapsed } else { $visible }
		}
	}

	if ($Script:BtnPreviewRun) { $Script:BtnPreviewRun.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:BtnDefaults) { $Script:BtnDefaults.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:BtnRun) { $Script:BtnRun.Visibility = if ($Enable) { $collapsed } else { $visible } }

	if ($Enable)
	{
		Build-AppsViewCards
	}
	else
	{
		if ($Script:CurrentPrimaryTab)
		{
			$Script:FilterGeneration++
			if ($Script:UpdateCurrentTabContentScript)
			{
				& $Script:UpdateCurrentTabContentScript
			}
			elseif (Get-Command -Name 'Update-CurrentTabContent' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Update-CurrentTabContent
			}
		}
	}

	if (Get-Command -Name 'Sync-UxActionButtonText' -CommandType Function -ErrorAction SilentlyContinue)
	{
		if ($Script:SyncUxActionButtonTextScript)
		{
			& $Script:SyncUxActionButtonTextScript
		}
		else
		{
			Sync-UxActionButtonText
		}
	}
}
