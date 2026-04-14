# Apps view filter state, source preference, and catalog helpers

	<#
	    .SYNOPSIS
	    Internal function ConvertTo-AppPackageSourcePreference.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function ConvertTo-AppPackageSourcePreference
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[string]$Source
		)

		$normalizedSource = if ([string]::IsNullOrWhiteSpace([string]$Source)) { 'winget' } else { [string]$Source.Trim().ToLowerInvariant() }
		switch ($normalizedSource)
		{
			'winget' { return 'winget' }
			'choco' { return 'choco' }
			'chocolatey' { return 'choco' }
			default { return 'winget' }
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Initialize-AppPackageSourcePreferenceState.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Initialize-AppPackageSourcePreferenceState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		$Script:AppsPackageSourcePreference = ConvertTo-AppPackageSourcePreference -Source $Script:AppsPackageSourcePreference
		if ($null -eq $Script:AppsSourceUiUpdating)
		{
			$Script:AppsSourceUiUpdating = $false
		}
	}

	<#
	    .SYNOPSIS
	    Internal function .

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>
	function Get-AppsViewRenderSignature
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[object]$PackageManagerAvailabilityState = $null
		)

		Initialize-AppPackageSourcePreferenceState
		Initialize-AppCategoryFilterState

		$searchQuery = if ($Script:AppsModeActive) { [string]$Script:AppsSearchText } else { [string]$Script:SearchText }
		$themeName = if ([string]::IsNullOrWhiteSpace([string]$Script:CurrentThemeName)) { 'Dark' } else { [string]$Script:CurrentThemeName }
		$catalogCount = if ($Script:BaselineApplicationsCatalog -is [System.Array]) { [int]$Script:BaselineApplicationsCatalog.Count } else { -1 }
		$cacheSignature = Get-ApplicationCacheSignature -CacheState $Script:InstalledAppsCache
		$packageManagerAvailabilitySignature = if ($PackageManagerAvailabilityState -and $PackageManagerAvailabilityState.PSObject.Properties['AvailabilitySignature'])
		{
			[string]$PackageManagerAvailabilityState.AvailabilitySignature
		}
		else
		{
			Get-AppsPackageManagerAvailabilitySignature
		}

		return @(
			"Theme=$themeName"
			"Mode=$([bool]$Script:AppsModeActive)"
			"Search=$searchQuery"
			"Category=$([string]$Script:AppsCategoryFilter)"
			"Source=$([string](ConvertTo-AppPackageSourcePreference -Source $Script:AppsPackageSourcePreference))"
			"Loaded=$([bool]$Script:AppsViewLoaded)"
			"Dirty=$([bool]$Script:AppsViewDirty)"
			"Refresh=$([bool]$Script:AppsCacheRefreshInProgress)"
			"PackageManagers=$packageManagerAvailabilitySignature"
			"Cache=$cacheSignature"
			"Catalog=$catalogCount"
		) -join '|'
	}

	<#
	    .SYNOPSIS
	    Internal function Get-AppsCacheRefreshPromptText.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Get-AppsCacheRefreshPromptText
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		return (Get-UxLocalizedString -Key 'GuiAppsCacheRefreshRequired' -Fallback 'Installed status not scanned')
	}

	<#
	    .SYNOPSIS
	    Internal function .

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>
	function Get-AppsPackageManagerAvailabilityState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		$wingetAvailable = $true
		if (Get-Command -Name 'Test-WinGetAvailable' -CommandType Function -ErrorAction SilentlyContinue)
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
		if (Get-Command -Name 'Test-ChocolateyAvailable' -CommandType Function -ErrorAction SilentlyContinue)
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

		$bothUnavailable = (-not $wingetAvailable -and -not $chocolateyAvailable)
		$bannerText = $null
		if ($bothUnavailable)
		{
			$bannerText = Get-UxLocalizedString -Key 'GuiAppsPackageManagersUnavailable' -Fallback 'WinGet and Chocolatey are unavailable on this system.'
		}

		$state = [pscustomobject]@{
			WinGetAvailable = [bool]$wingetAvailable
			ChocolateyAvailable = [bool]$chocolateyAvailable
			BothUnavailable = [bool]$bothUnavailable
			AvailabilitySignature = ('WinGet={0}|Chocolatey={1}' -f [bool]$wingetAvailable, [bool]$chocolateyAvailable)
			BannerText = $bannerText
		}

		$Script:AppsPackageManagerAvailabilityState = $state
		return $state
	}

	<#
	    .SYNOPSIS
	    Internal function Get-AppsPackageManagerAvailabilitySignature.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Get-AppsPackageManagerAvailabilitySignature
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		$state = Get-AppsPackageManagerAvailabilityState
		return [string]$state.AvailabilitySignature
	}

	<#
	    .SYNOPSIS
	    Internal function .

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>
	function Update-AppsPackageManagerBanner
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[object]$AvailabilityState = $null
		)

		if (-not $Script:AppsPackageManagerBanner -and -not $Script:TxtAppsPackageManagerBanner)
		{
			return
		}

		if ($null -eq $AvailabilityState)
		{
			$AvailabilityState = Get-AppsPackageManagerAvailabilityState
		}

		$showBanner = [bool]($AvailabilityState -and $AvailabilityState.BothUnavailable)
		$bannerText = if ($showBanner) { [string]$AvailabilityState.BannerText } else { $null }

		if ($Script:AppsPackageManagerBanner)
		{
			try { $Script:AppsPackageManagerBanner.Visibility = $(if ($showBanner) { 'Visible' } else { 'Collapsed' }) } catch { $null = $_ }
		}
		if ($Script:TxtAppsPackageManagerBanner)
		{
			try { $Script:TxtAppsPackageManagerBanner.Text = [string]$bannerText } catch { $null = $_ }
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Get-ApplicationCacheSignature.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Get-ApplicationCacheSignature
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[object]$CacheState
		)

		$snapshot = $CacheState
		if (Get-Command -Name 'Get-ApplicationCacheSnapshot' -CommandType Function -ErrorAction SilentlyContinue)
		{
			try
			{
				$snapshot = Get-ApplicationCacheSnapshot -CacheState $CacheState
			}
			catch
			{
				$snapshot = $CacheState
			}
		}

		$signatureParts = [System.Collections.Generic.List[string]]::new()
		foreach ($bucketName in @('WinGet', 'Chocolatey', 'WinGetUpdates', 'ChocolateyUpdates'))
		{
			$bucket = $null
			if ($snapshot -and $snapshot.PSObject.Properties[$bucketName])
			{
				$bucket = $snapshot.$bucketName
			}

			$bucketSignature = '0:'
			if ($bucket -is [System.Collections.IDictionary])
			{
				$keys = [string[]]@($bucket.Keys | ForEach-Object { [string]$_ })
				[System.Array]::Sort($keys, [System.StringComparer]::OrdinalIgnoreCase)
				$entryParts = [System.Collections.Generic.List[string]]::new()
				foreach ($key in @($keys))
				{
					$entryValue = if ($null -eq $bucket[$key]) { '<null>' } else { [string]$bucket[$key] }
					[void]$entryParts.Add(('{0}={1}' -f $key, $entryValue))
				}
				$bucketSignature = ('{0}:{1}' -f $keys.Count, ($entryParts -join ';'))
			}

			[void]$signatureParts.Add(('{0}={1}' -f $bucketName, $bucketSignature))
		}

		return ($signatureParts -join '|')
	}

	<#
	    .SYNOPSIS
	    Internal function Update-AppPackageSourcePreferenceControls.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Update-AppPackageSourcePreferenceControls
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		Initialize-AppPackageSourcePreferenceState

		if (-not $Script:BtnAppsSourceWinGet -and -not $Script:BtnAppsSourceChocolatey)
		{
			return
		}

		$selectedSource = ConvertTo-AppPackageSourcePreference -Source $Script:AppsPackageSourcePreference
		$Script:AppsSourceUiUpdating = $true
		try
		{
			if ($Script:BtnAppsSourceWinGet)
			{
				try { $Script:BtnAppsSourceWinGet.IsChecked = ($selectedSource -eq 'winget') } catch { $null = $_ }
				Set-ButtonChrome -Button $Script:BtnAppsSourceWinGet -Variant $(if ($selectedSource -eq 'winget') { 'Selection' } else { 'Subtle' }) -Compact
			}
			if ($Script:BtnAppsSourceChocolatey)
			{
				try { $Script:BtnAppsSourceChocolatey.IsChecked = ($selectedSource -eq 'choco') } catch { $null = $_ }
				Set-ButtonChrome -Button $Script:BtnAppsSourceChocolatey -Variant $(if ($selectedSource -eq 'choco') { 'Selection' } else { 'Subtle' }) -Compact
			}
		}
		finally
		{
			$Script:AppsSourceUiUpdating = $false
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-AppPackageSourcePreferenceState.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Set-AppPackageSourcePreferenceState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[string]$Source = 'winget'
		)

		Initialize-AppPackageSourcePreferenceState

		$normalizedSource = ConvertTo-AppPackageSourcePreference -Source $Source
		if ($Script:AppsPackageSourcePreference -eq $normalizedSource)
		{
			Update-AppPackageSourcePreferenceControls
			return
		}

		$Script:AppsPackageSourcePreference = $normalizedSource
		Update-AppPackageSourcePreferenceControls
		if ($Script:AppsModeActive)
		{
			Build-AppsViewCards
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Initialize-AppActionStateStore.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Initialize-AppActionStateStore
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		if (-not ($Script:AppActionStates -is [hashtable]))
		{
			$Script:AppActionStates = @{}
		}
	}

	<#
	    .SYNOPSIS
	    Internal function .

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>
	function Get-AppActionStateKey
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[object]$Application,
			[string]$SelectionKey
		)

		if (-not [string]::IsNullOrWhiteSpace([string]$SelectionKey))
		{
			return [string]$SelectionKey.Trim()
		}

		if (-not $Application)
		{
			return $null
		}

		if (Get-Command -Name 'Get-ApplicationCatalogIdentityKey' -CommandType Function -ErrorAction SilentlyContinue)
		{
			try
			{
				$catalogKey = Get-ApplicationCatalogIdentityKey -Entry $Application
				if (-not [string]::IsNullOrWhiteSpace([string]$catalogKey))
				{
					return [string]$catalogKey
				}
			}
			catch
			{
				$null = $_
			}
		}

		if ((Test-GuiObjectField -Object $Application -FieldName 'Name') -and -not [string]::IsNullOrWhiteSpace([string]$Application.Name))
		{
			return [string]$Application.Name.Trim()
		}

		return $null
	}

	<#
	    .SYNOPSIS
	    Internal function Get-AppActionState.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Get-AppActionState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[object]$Application,
			[string]$SelectionKey
		)

		Initialize-AppActionStateStore

		$key = Get-AppActionStateKey -Application $Application -SelectionKey $SelectionKey
		if ([string]::IsNullOrWhiteSpace($key))
		{
			return $null
		}

		if ($Script:AppActionStates.ContainsKey($key))
		{
			return $Script:AppActionStates[$key]
		}

		return $null
	}

	<#
	    .SYNOPSIS
	    Internal function Set-AppActionState.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Set-AppActionState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[object]$Application,
			[string]$SelectionKey,
			[string]$State,
			[string]$Message,
			[string]$Action,
			[string]$SelectedSource,
			[string]$PreferredSource
		)

		Initialize-AppActionStateStore

		$key = Get-AppActionStateKey -Application $Application -SelectionKey $SelectionKey
		if ([string]::IsNullOrWhiteSpace($key))
		{
			return
		}

		if ([string]::IsNullOrWhiteSpace([string]$State) -or $State -eq 'Cleared')
		{
			$null = $Script:AppActionStates.Remove($key)
			return
		}

		$Script:AppActionStates[$key] = @{
			SelectionKey   = $key
			State          = [string]$State
			Message        = if ([string]::IsNullOrWhiteSpace([string]$Message)) { $null } else { [string]$Message }
			Action         = if ([string]::IsNullOrWhiteSpace([string]$Action)) { $null } else { [string]$Action }
			SelectedSource = if ([string]::IsNullOrWhiteSpace([string]$SelectedSource)) { $null } else { [string]$SelectedSource }
			PreferredSource = if ([string]::IsNullOrWhiteSpace([string]$PreferredSource)) { $null } else { [string]$PreferredSource }
			UpdatedAt      = Get-Date
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Clear-AppActionState.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Clear-AppActionState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[object]$Application,
			[string]$SelectionKey
		)

		Initialize-AppActionStateStore

		$key = Get-AppActionStateKey -Application $Application -SelectionKey $SelectionKey
		if ([string]::IsNullOrWhiteSpace($key))
		{
			return
		}

		$null = $Script:AppActionStates.Remove($key)
	}

	<#
	    .SYNOPSIS
	    Internal function Set-AppActionStatesQueued.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Set-AppActionStatesQueued
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[string]$Action,
			[object]$Application,
			[object[]]$SelectedApps = @(),
			[string]$PreferredSource
		)

		Initialize-AppActionStateStore
		$targets = @()
		if ($SelectedApps -and $SelectedApps.Count -gt 0)
		{
			$targets = @($SelectedApps | Where-Object { $_ })
		}
		elseif ($Application)
		{
			$targets = @($Application)
		}

		if ($targets.Count -eq 0)
		{
			return
		}

		$queueMessage = switch ($Action)
		{
			'Install' { 'Queued for installation.' }
			'Uninstall' { 'Queued for uninstallation.' }
			'Update' { 'Queued for update.' }
			default { 'Queued.' }
		}

		foreach ($target in @($targets))
		{
			Set-AppActionState -Application $target -State 'Queued' -Message $queueMessage -Action $Action -PreferredSource $PreferredSource
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Sync-AppActionStatesFromExecutionResult.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Sync-AppActionStatesFromExecutionResult
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[string]$Action,
			[object]$Application,
			[object[]]$SelectedApps = @(),
			[object]$Result,
			[string]$Outcome,
			[string]$PreferredSource
		)

		Initialize-AppActionStateStore

		$targets = @()
		if ($SelectedApps -and $SelectedApps.Count -gt 0)
		{
			$targets = @($SelectedApps | Where-Object { $_ })
		}
		elseif ($Application)
		{
			$targets = @($Application)
		}

		if ($targets.Count -eq 0)
		{
			return
		}

		$successfulKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
		$failedStates = @{}
		$hasStructuredResult = $false

		if ($Result)
		{
			$successfulApps = @()
			if (Test-GuiObjectField -Object $Result -FieldName 'SuccessfulApps')
			{
				$successfulApps = @($Result.SuccessfulApps | Where-Object { $_ })
				if ($successfulApps.Count -gt 0)
				{
					$hasStructuredResult = $true
					foreach ($entry in @($successfulApps))
					{
						$key = Get-AppActionStateKey -SelectionKey $(if ((Test-GuiObjectField -Object $entry -FieldName 'SelectionKey')) { [string]$entry.SelectionKey } else { $null }) -Application $entry
						if (-not [string]::IsNullOrWhiteSpace($key))
						{
							[void]$successfulKeys.Add($key)
						}
					}
				}
			}

			if (Test-GuiObjectField -Object $Result -FieldName 'FailedApps')
			{
				$failedApps = @($Result.FailedApps | Where-Object { $_ })
				if ($failedApps.Count -gt 0)
				{
					$hasStructuredResult = $true
					foreach ($entry in @($failedApps))
					{
						$key = Get-AppActionStateKey -SelectionKey $(if ((Test-GuiObjectField -Object $entry -FieldName 'SelectionKey')) { [string]$entry.SelectionKey } else { $null }) -Application $entry
						if (-not [string]::IsNullOrWhiteSpace($key))
						{
							$failedStates[$key] = if ((Test-GuiObjectField -Object $entry -FieldName 'Error') -and -not [string]::IsNullOrWhiteSpace([string]$entry.Error)) { [string]$entry.Error } else { $null }
						}
					}
				}
			}
		}

		foreach ($target in @($targets))
		{
			$key = Get-AppActionStateKey -Application $target
			if ([string]::IsNullOrWhiteSpace($key))
			{
				continue
			}

			if ($failedStates.ContainsKey($key))
			{
				Set-AppActionState -Application $target -State 'Failed' -Message $failedStates[$key] -Action $Action -PreferredSource $PreferredSource
				continue
			}

			if ($successfulKeys.Contains($key))
			{
				Clear-AppActionState -Application $target
				continue
			}

			if ($hasStructuredResult)
			{
				Clear-AppActionState -Application $target
				continue
			}

			$resultOutcome = if (-not [string]::IsNullOrWhiteSpace([string]$Outcome)) { [string]$Outcome } elseif ($Result -and (Test-GuiObjectField -Object $Result -FieldName 'Outcome')) { [string]$Result.Outcome } else { $null }
			if ($resultOutcome -eq 'Failed')
			{
				$failureMessage = if ($Result -and (Test-GuiObjectField -Object $Result -FieldName 'Message')) { [string]$Result.Message } else { $null }
				Set-AppActionState -Application $target -State 'Failed' -Message $failureMessage -Action $Action -PreferredSource $PreferredSource
			}
			else
			{
				Clear-AppActionState -Application $target
			}
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Initialize-AppCategoryFilterState.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Initialize-AppCategoryFilterState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		if ([string]::IsNullOrWhiteSpace([string]$Script:AppsCategoryFilter))
		{
			$Script:AppsCategoryFilter = 'All'
		}

		if ($null -eq $Script:AppsFilterUiUpdating)
		{
			$Script:AppsFilterUiUpdating = $false
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Get-AppCategoryFilterValues.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Get-AppCategoryFilterValues
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		$catalog = @(Get-BaselineApplicationsCatalog)
		$categories = @(
			$catalog |
				ForEach-Object {
					if ($_)
					{
						$categoryName = if ([string]::IsNullOrWhiteSpace([string]$_.SubCategory)) { 'Other' } else { [string]$_.SubCategory.Trim() }
						if (-not [string]::IsNullOrWhiteSpace($categoryName))
						{
							$categoryName
						}
					}
				} |
				Sort-Object -Unique
		)

		return @('All') + $categories
	}

	<#
	    .SYNOPSIS
	    Internal function Get-FilteredApplicationsCatalogItems.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Get-FilteredApplicationsCatalogItems
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[string]$SearchQuery = $null
		)

		Initialize-AppCategoryFilterState

		$catalog = @(Get-BaselineApplicationsCatalog)
		if ($catalog.Count -eq 0)
		{
			return @()
		}

		$effectiveSearchQuery = if ([string]::IsNullOrWhiteSpace([string]$SearchQuery)) { '' } else { [string]$SearchQuery.Trim() }
		$searchTerms = @()
		if (-not [string]::IsNullOrWhiteSpace($effectiveSearchQuery))
		{
			$searchTerms = @(
				$effectiveSearchQuery -split '\s+' |
					Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
					ForEach-Object { [string]$_.Trim().ToLowerInvariant() }
			)
		}

		$selectedCategory = if ([string]::IsNullOrWhiteSpace([string]$Script:AppsCategoryFilter)) { 'All' } else { [string]$Script:AppsCategoryFilter.Trim() }
		$filteredCatalog = $catalog
		if ($selectedCategory -ne 'All')
		{
			$filteredCatalog = @(
				$filteredCatalog |
					Where-Object {
						$categoryName = if ([string]::IsNullOrWhiteSpace([string]$_.SubCategory)) { 'Other' } else { [string]$_.SubCategory.Trim() }
						$categoryName -eq $selectedCategory
					}
			)
		}

		if ($searchTerms.Count -eq 0)
		{
			return $filteredCatalog
		}

		return @(
			$filteredCatalog |
				Where-Object {
					$searchIndex = if ((Test-GuiObjectField -Object $_ -FieldName 'SearchIndex')) { [string]$_.SearchIndex } else { $null }
					if ([string]::IsNullOrWhiteSpace($searchIndex))
					{
						return $false
					}

					foreach ($term in @($searchTerms))
					{
						if ($searchIndex.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -lt 0)
						{
							return $false
						}
					}

					return $true
				}
		)
	}

	<#
	    .SYNOPSIS
	    Internal function Update-AppCategoryFilterList.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Update-AppCategoryFilterList
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		if (-not $CmbAppsCategoryFilter)
		{
			return
		}

		Initialize-AppCategoryFilterState

		$currentValue = if ($Script:AppsCategoryFilterInternalValues -and $CmbAppsCategoryFilter.SelectedIndex -ge 0 -and $CmbAppsCategoryFilter.SelectedIndex -lt $Script:AppsCategoryFilterInternalValues.Count) { $Script:AppsCategoryFilterInternalValues[$CmbAppsCategoryFilter.SelectedIndex] } elseif (-not [string]::IsNullOrWhiteSpace([string]$Script:AppsCategoryFilter)) { [string]$Script:AppsCategoryFilter.Trim() } else { 'All' }
		$values = @(Get-AppCategoryFilterValues)

		$Script:AppsFilterUiUpdating = $true
		try
		{
			$CmbAppsCategoryFilter.Items.Clear()
			$Script:AppsCategoryFilterInternalValues = [System.Collections.Generic.List[string]]::new()
			$appsCatLocKeyMap = @{
				'All'           = 'GuiAppsCategoryAll'
				'Browsers'      = 'GuiAppsCategoryBrowsers'
				'Communication' = 'GuiAppsCategoryCommunication'
				'Compression'   = 'GuiAppsCategoryCompression'
				'Development'   = 'GuiAppsCategoryDevelopment'
				'Documents'     = 'GuiAppsCategoryDocuments'
				'FileManagement'= 'GuiAppsCategoryFileManagement'
				'Gaming'        = 'GuiAppsCategoryGaming'
				'Imaging'       = 'GuiAppsCategoryImaging'
				'Media'         = 'GuiAppsCategoryMedia'
				'RemoteAccess'  = 'GuiAppsCategoryRemoteAccess'
				'Runtimes'      = 'GuiAppsCategoryRuntimes'
				'Security'      = 'GuiAppsCategorySecurity'
				'Utilities'     = 'GuiAppsCategoryUtilities'
			}
			foreach ($value in $values)
			{
				$locKey = if ($appsCatLocKeyMap.ContainsKey($value)) { $appsCatLocKeyMap[$value] } else { $null }
				$displayValue = if ($locKey) { Get-UxLocalizedString -Key $locKey -Fallback $value } else { $value }
				[void]$CmbAppsCategoryFilter.Items.Add($displayValue)
				[void]$Script:AppsCategoryFilterInternalValues.Add($value)
			}

			if ($Script:AppsCategoryFilterInternalValues.Contains($currentValue))
			{
				$found = $Script:AppsCategoryFilterInternalValues.IndexOf($currentValue)
				if ($found -ge 0) { $CmbAppsCategoryFilter.SelectedIndex = [int]$found }
				$Script:AppsCategoryFilter = $currentValue
			}
			else
			{
				$CmbAppsCategoryFilter.SelectedIndex = 0
				$Script:AppsCategoryFilter = 'All'
			}
		}
		finally
		{
			$Script:AppsFilterUiUpdating = $false
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-AppCategoryFilterState.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Set-AppCategoryFilterState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[string]$Category = 'All'
		)

		Initialize-AppCategoryFilterState

		$normalizedCategory = if ([string]::IsNullOrWhiteSpace($Category)) { 'All' } else { [string]$Category.Trim() }
		$Script:AppsCategoryFilter = $normalizedCategory

		if ($Script:AppsModeActive)
		{
			Build-AppsViewCards
		}
	}
