# Apps view filter state, source preference, and catalog helpers

	<#
	    .SYNOPSIS
	    Internal function ConvertTo-AppPackageSourcePreference.
	#>

	function ConvertTo-AppPackageSourcePreference
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[string]$Source
		)

		$normalizedSource = if ([string]::IsNullOrWhiteSpace([string]$Source)) { 'auto' } else { [string]$Source.Trim().ToLowerInvariant() }
		switch ($normalizedSource)
		{
			'auto' { return 'auto' }
			'winget' { return 'winget' }
			'choco' { return 'choco' }
			'chocolatey' { return 'choco' }
			default { return 'auto' }
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Initialize-AppPackageSourcePreferenceState.
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
	#>
	function Get-AppsViewRenderSignature
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[object]$PackageManagerAvailabilityState = $null
		)

		Initialize-AppPackageSourcePreferenceState
		Initialize-AppCategoryFilterState
		Initialize-AppStatusFilterState

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
			"Status=$([string]$Script:AppsStatusFilter)"
			"Source=$([string](ConvertTo-AppPackageSourcePreference -Source $Script:AppsPackageSourcePreference))"
			"SourceFilter=$([string]$Script:AppsSourceFilter)"
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
			try { $Script:AppsPackageManagerBanner.Visibility = $(if ($showBanner) { 'Visible' } else { 'Collapsed' }) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ApplicationsView.Update-AppsPackageManagerBanner.Visibility' }
		}
		if ($Script:TxtAppsPackageManagerBanner)
		{
			try { $Script:TxtAppsPackageManagerBanner.Text = [string]$bannerText } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ApplicationsView.Update-AppsPackageManagerBanner.Text' }
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Get-ApplicationCacheSignature.
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
	#>

	function Update-AppPackageSourcePreferenceControls
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		Initialize-AppPackageSourcePreferenceState
	}

	<#
	    .SYNOPSIS
	    Internal function Update-AppSourceFilterControls.
	#>

	function Update-AppSourceFilterControls
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		if (-not $Script:BtnAppsSourceFilterAll -and -not $Script:BtnAppsSourceFilterWinGet -and -not $Script:BtnAppsSourceFilterChocolatey)
		{
			return
		}

		$allowed = @('All', 'winget', 'choco')
		$current = if ([string]::IsNullOrWhiteSpace([string]$Script:AppsSourceFilter)) { 'All' } else { [string]$Script:AppsSourceFilter }
		if ($allowed -notcontains $current) { $current = 'All'; $Script:AppsSourceFilter = 'All' }

		$allText = Get-UxLocalizedString -Key 'GuiAppsSourceFilterAll' -Fallback 'All'
		$wingetText = Get-UxLocalizedString -Key 'GuiAppsSourceFilterWinGet' -Fallback 'WinGet'
		$chocoText = Get-UxLocalizedString -Key 'GuiAppsSourceFilterChocolatey' -Fallback 'Chocolatey'
		$allTip = Get-UxLocalizedString -Key 'GuiAppsSourceFilterAllTip' -Fallback 'Show apps from any package source.'
		$wingetTip = Get-UxLocalizedString -Key 'GuiAppsSourceFilterWinGetTip' -Fallback 'Show only apps available through WinGet.'
		$chocoTip = Get-UxLocalizedString -Key 'GuiAppsSourceFilterChocolateyTip' -Fallback 'Show only apps available through Chocolatey.'

		# Layout + chrome come from AppsFilterRadioStyle in MainWindow.xaml — only
		# sync dynamic state (IsChecked, localized Content, ToolTip) here.
		$Script:AppsSourceFilterUiUpdating = $true
		try
		{
			if ($Script:BtnAppsSourceFilterAll)
			{
				$isOn = ($current -eq 'All')
				try { $Script:BtnAppsSourceFilterAll.IsChecked = $isOn } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ApplicationsView.Update-AppsSourceFilterControls.All' }
				$Script:BtnAppsSourceFilterAll.Content = $allText
				$Script:BtnAppsSourceFilterAll.ToolTip = $allTip
			}
			if ($Script:BtnAppsSourceFilterWinGet)
			{
				$isOn = ($current -eq 'winget')
				try { $Script:BtnAppsSourceFilterWinGet.IsChecked = $isOn } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ApplicationsView.Update-AppsSourceFilterControls.WinGet' }
				$Script:BtnAppsSourceFilterWinGet.Content = $wingetText
				$Script:BtnAppsSourceFilterWinGet.ToolTip = $wingetTip
			}
			if ($Script:BtnAppsSourceFilterChocolatey)
			{
				$isOn = ($current -eq 'choco')
				try { $Script:BtnAppsSourceFilterChocolatey.IsChecked = $isOn } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ApplicationsView.Update-AppsSourceFilterControls.Chocolatey' }
				$Script:BtnAppsSourceFilterChocolatey.Content = $chocoText
				$Script:BtnAppsSourceFilterChocolatey.ToolTip = $chocoTip
			}
		}
		finally
		{
			$Script:AppsSourceFilterUiUpdating = $false
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Update-AppsViewModeControls.
	#>

	function Update-AppsViewModeControls
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		if (-not $Script:BtnAppsViewCards -and -not $Script:BtnAppsViewList)
		{
			return
		}

		$current = if ([string]::IsNullOrWhiteSpace([string]$Script:AppsViewMode)) { 'Cards' } else { [string]$Script:AppsViewMode }
		if ($current -ne 'List') { $current = 'Cards' }

		# Layout + chrome come from AppsFilterRadioStyle in MainWindow.xaml — only
		# sync dynamic state (IsChecked) here.
		$Script:AppsViewModeUiUpdating = $true
		try
		{
			if ($Script:BtnAppsViewCards)
			{
				$isOn = ($current -eq 'Cards')
				try { $Script:BtnAppsViewCards.IsChecked = $isOn } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ApplicationsView.Update-AppsViewModeControls.Cards' }
			}
			if ($Script:BtnAppsViewList)
			{
				$isOn = ($current -eq 'List')
				try { $Script:BtnAppsViewList.IsChecked = $isOn } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ApplicationsView.Update-AppsViewModeControls.List' }
			}
		}
		finally
		{
			$Script:AppsViewModeUiUpdating = $false
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-AppSourceFilterState.
	#>

	function Set-AppSourceFilterState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[string]$Source = 'All'
		)

		$allowed = @('All', 'winget', 'choco')
		$normalized = if ([string]::IsNullOrWhiteSpace([string]$Source)) { 'All' } else { [string]$Source.Trim() }
		if ($normalized -eq 'chocolatey') { $normalized = 'choco' }
		if ($allowed -notcontains $normalized) { $normalized = 'All' }

		if ($Script:AppsSourceFilter -eq $normalized)
		{
			Update-AppSourceFilterControls
			return
		}

		$Script:AppsSourceFilter = $normalized
		Update-AppSourceFilterControls
		if ($Script:AppsModeActive)
		{
			Build-AppsViewCards
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-AppPackageSourcePreferenceState.
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
	#>

	function Initialize-AppCategoryFilterState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		if ([string]::IsNullOrWhiteSpace([string]$Script:AppsCategoryFilter))
		{
			$Script:AppsCategoryFilter = if (Get-Command -Name 'Get-AppsDefaultCatalogCategory' -CommandType Function -ErrorAction SilentlyContinue) { Get-AppsDefaultCatalogCategory } else { 'Browsers' }
		}
		elseif ($Script:AppsCategoryFilter -eq 'All')
		{
			$Script:AppsCategoryFilter = if (Get-Command -Name 'Get-AppsDefaultCatalogCategory' -CommandType Function -ErrorAction SilentlyContinue) { Get-AppsDefaultCatalogCategory } else { 'Browsers' }
		}

		if ($null -eq $Script:AppsFilterUiUpdating)
		{
			$Script:AppsFilterUiUpdating = $false
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Get-AppCategoryFilterValues.
	#>

	function Get-AppCategoryFilterValues
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		$categories = if (Get-Command -Name 'Get-AppsCatalogCategoryNames' -CommandType Function -ErrorAction SilentlyContinue)
		{
			@(Get-AppsCatalogCategoryNames)
		}
		else
		{
			@()
		}

		return $categories
	}

	<#
	    .SYNOPSIS
	    Internal function Get-FilteredApplicationsCatalogItems.
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
	#>

	function Update-AppCategoryFilterList
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		if (-not $Script:AppsCategoryTabs)
		{
			return
		}

		Initialize-AppCategoryFilterState

		$currentValue = if (Get-Command -Name 'Resolve-AppsCatalogCategory' -CommandType Function -ErrorAction SilentlyContinue) { Resolve-AppsCatalogCategory -Category $Script:AppsCategoryFilter } elseif (-not [string]::IsNullOrWhiteSpace([string]$Script:AppsCategoryFilter) -and [string]$Script:AppsCategoryFilter -ne 'All') { [string]$Script:AppsCategoryFilter.Trim() } else { 'Browsers' }
		$values = @(Get-AppCategoryFilterValues)

		$Script:AppsFilterUiUpdating = $true
		try
		{
			$Script:AppsCategoryTabs.Items.Clear()
			$Script:AppsCategoryFilterInternalValues = [System.Collections.Generic.List[string]]::new()
			$appsCatLocKeyMap = @{
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
			$appsCatIconMap = @{
				'Browsers'       = 'Globe'
				'Communication'  = 'Chat'
				'Compression'    = 'Archive'
				'Development'    = 'WindowDevTools'
				'Documents'      = 'Document'
				'FileManagement' = 'Folder'
				'Gaming'         = 'Games'
				'Imaging'        = 'Image'
				'Media'          = 'Video'
				'RemoteAccess'   = 'PhoneDesktop'
				'Runtimes'       = 'Box'
				'Security'       = 'Shield'
				'Utilities'      = 'Toolbox'
			}
			$selectedIndex = 0
			for ($i = 0; $i -lt $values.Count; $i++)
			{
				$value = $values[$i]
				$locKey = if ($appsCatLocKeyMap.ContainsKey($value)) { $appsCatLocKeyMap[$value] } else { $null }
				$displayValue = if ($locKey) { Get-UxLocalizedString -Key $locKey -Fallback $value } else { $value }
				$iconName = if ($appsCatIconMap.ContainsKey($value)) { $appsCatIconMap[$value] } else { 'Apps' }

				$tabItem = New-Object System.Windows.Controls.TabItem
				if ($iconName -and (Get-Command -Name 'New-GuiLabeledIconContent' -CommandType Function -ErrorAction SilentlyContinue))
				{
					$tabItem.Header = New-GuiLabeledIconContent -IconName $iconName -Text $displayValue -IconSize 16 -Gap 6 -AllowTextOnlyFallback
				}
				else
				{
					$tabItem.Header = $displayValue
				}
				$tabItem.Tag = $value
				$tabItem | Add-Member -NotePropertyName 'AppsDisplayName' -NotePropertyValue $displayValue -Force
				$tabItem | Add-Member -NotePropertyName 'AppsIconName' -NotePropertyValue $iconName -Force
				if ($Script:CurrentTheme)
				{
					try { $tabItem.Foreground = ConvertTo-GuiBrush -Color $Script:CurrentTheme.TextPrimary -Context 'AppsCategoryTabs/Foreground' } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ApplicationsView.Update-AppsCategoryTabs.Foreground' }
					try { $tabItem.Background = ConvertTo-GuiBrush -Color $Script:CurrentTheme.TabBg -Context 'AppsCategoryTabs/Background' } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ApplicationsView.Update-AppsCategoryTabs.Background' }
				}
				$tabItem.Padding = [System.Windows.Thickness]::new(14, 7, 14, 7)
				[void]$Script:AppsCategoryTabs.Items.Add($tabItem)
				[void]$Script:AppsCategoryFilterInternalValues.Add($value)
				Add-AppsCategoryTabHoverEffects -Tab $tabItem
				if ($value -eq $currentValue) { $selectedIndex = $i }
			}

			if ($Script:AppsCategoryFilterInternalValues.Contains($currentValue))
			{
				$Script:AppsCategoryTabs.SelectedIndex = [int]$selectedIndex
				$Script:AppsCategoryFilter = $currentValue
			}
			elseif ($Script:AppsCategoryFilterInternalValues.Count -gt 0)
			{
				$Script:AppsCategoryTabs.SelectedIndex = 0
				$Script:AppsCategoryFilter = [string]$Script:AppsCategoryFilterInternalValues[0]
			}
		}
		finally
		{
			$Script:AppsFilterUiUpdating = $false
		}

		Update-AppsCategoryTabVisuals
	}

	<#
	    .SYNOPSIS
	    Internal function Update-AppsCategoryTabVisuals.
	#>

	function Update-AppsCategoryTabVisuals
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()
		if (-not $Script:AppsCategoryTabs) { return }
		$bc = New-SafeBrushConverter -Context 'Update-AppsCategoryTabVisuals'
		foreach ($tab in $Script:AppsCategoryTabs.Items)
		{
			if (-not ($tab -is [System.Windows.Controls.TabItem])) { continue }
			$tab.BorderThickness = [System.Windows.Thickness]::new(1)
			$tab.Padding = [System.Windows.Thickness]::new(14, 7, 14, 7)
			if ($tab -eq $Script:AppsCategoryTabs.SelectedItem)
			{
				$tab.Background = $bc.ConvertFromString($Script:CurrentTheme.TabActiveBg)
				$tab.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextPrimary)
				$tab.FontWeight = [System.Windows.FontWeights]::SemiBold
				$tab.BorderBrush = $bc.ConvertFromString($Script:CurrentTheme.ActiveTabBorder)
			}
			else
			{
				$tab.Background = $bc.ConvertFromString($Script:CurrentTheme.TabBg)
				$tab.Foreground = $bc.ConvertFromString($Script:CurrentTheme.TextMuted)
				$tab.FontWeight = [System.Windows.FontWeights]::Normal
				$tab.BorderBrush = [System.Windows.Media.Brushes]::Transparent
			}
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Update-AppsCategoryTabCounts.
	#>

	function Update-AppsCategoryTabCounts
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()
		if (-not $Script:AppsCategoryTabs -or $Script:AppsCategoryTabs.Items.Count -eq 0) { return }

		$activeSearchQuery = if ($Script:AppsModeActive) { [string]$Script:AppsSearchText } else { [string]$Script:SearchText }
		$currentCategory = if (Get-Command -Name 'Resolve-AppsCatalogCategory' -CommandType Function -ErrorAction SilentlyContinue) { Resolve-AppsCatalogCategory -Category $Script:AppsCategoryFilter } elseif (-not [string]::IsNullOrWhiteSpace([string]$Script:AppsCategoryFilter) -and [string]$Script:AppsCategoryFilter -ne 'All') { [string]$Script:AppsCategoryFilter.Trim() } else { 'Browsers' }
		$catalog = @(Get-AppsCatalogItemsBySearchStatusAndSourceFilters -SearchQuery $activeSearchQuery)
		$currentCount = $catalog.Count

		foreach ($tab in $Script:AppsCategoryTabs.Items)
		{
			if (-not ($tab -is [System.Windows.Controls.TabItem])) { continue }
			$tag = [string]$tab.Tag
			if ([string]::IsNullOrWhiteSpace($tag)) { continue }
			$displayName = if ($tab.PSObject.Properties['AppsDisplayName']) { [string]$tab.AppsDisplayName } else { $tag }
			$iconName = if ($tab.PSObject.Properties['AppsIconName']) { [string]$tab.AppsIconName } else { $null }
			$headerText = if ($tag -eq $currentCategory) { "$displayName ($currentCount)" } else { $displayName }
			if ($iconName -and (Get-Command -Name 'New-GuiLabeledIconContent' -CommandType Function -ErrorAction SilentlyContinue))
			{
				$tab.Header = New-GuiLabeledIconContent -IconName $iconName -Text $headerText -IconSize 16 -Gap 6 -AllowTextOnlyFallback
			}
			else
			{
				$tab.Header = $headerText
			}
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Add-AppsCategoryTabHoverEffects.
	#>

	function Add-AppsCategoryTabHoverEffects
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ([System.Windows.Controls.TabItem]$Tab)
		if (-not $Tab) { return }
		$setGuiControlPropertyScript = ${function:Set-GuiControlProperty}
		$invokeGuiSafeActionScript = ${function:Invoke-GuiSafeAction}
		$newSafeBrushConverterScript = $Script:NewSafeBrushConverterScript
		$newSafeThicknessScript = ${function:New-SafeThickness}
		$updateAppsCategoryTabVisualsScript = ${function:Update-AppsCategoryTabVisuals}

		$mouseEnterHandler = {
			if ($Tab -eq $Script:AppsCategoryTabs.SelectedItem) { return }
			$bc = & $newSafeBrushConverterScript -Context 'Add-AppsCategoryTabHoverEffects/MouseEnter'

			$hoverBgColor = if ($Script:CurrentTheme -and -not [string]::IsNullOrWhiteSpace([string]$Script:CurrentTheme.TabHoverBg)) { [string]$Script:CurrentTheme.TabHoverBg } else { '#3670B8' }
			$textPrimaryColor = if ($Script:CurrentTheme -and -not [string]::IsNullOrWhiteSpace([string]$Script:CurrentTheme.TextPrimary)) { [string]$Script:CurrentTheme.TextPrimary } else { '#F4F7FF' }
			$hoverBorderColor = if ($Script:CurrentTheme -and -not [string]::IsNullOrWhiteSpace([string]$Script:CurrentTheme.BorderColor)) { [string]$Script:CurrentTheme.BorderColor } else { '#293044' }

			[void](& $setGuiControlPropertyScript -Control $Tab -PropertyName 'Background' -Value ($bc.ConvertFromString($hoverBgColor)) -Context 'Add-AppsCategoryTabHoverEffects/MouseEnter/Background')
			[void](& $setGuiControlPropertyScript -Control $Tab -PropertyName 'Foreground' -Value ($bc.ConvertFromString($textPrimaryColor)) -Context 'Add-AppsCategoryTabHoverEffects/MouseEnter/Foreground')
			[void](& $setGuiControlPropertyScript -Control $Tab -PropertyName 'BorderBrush' -Value ($bc.ConvertFromString($hoverBorderColor)) -Context 'Add-AppsCategoryTabHoverEffects/MouseEnter/BorderBrush')
		}.GetNewClosure()
		Register-GuiEventHandler -Source $Tab -EventName 'MouseEnter' -Handler ({
			& $invokeGuiSafeActionScript -Context 'Add-AppsCategoryTabHoverEffects/MouseEnter' -Action $mouseEnterHandler
		}.GetNewClosure())

		$refreshTabVisualsHandler = {
			& $updateAppsCategoryTabVisualsScript
		}.GetNewClosure()
		Register-GuiEventHandler -Source $Tab -EventName 'MouseLeave' -Handler ({
			& $invokeGuiSafeActionScript -Context 'Add-AppsCategoryTabHoverEffects/MouseLeave' -Action $refreshTabVisualsHandler
		}.GetNewClosure())

		$gotFocusHandler = {
			if ($Tab -eq $Script:AppsCategoryTabs.SelectedItem) { return }
			$bc = & $newSafeBrushConverterScript -Context 'Add-AppsCategoryTabHoverEffects/GotFocus'
			$focusRingColor = if ($Script:CurrentTheme -and -not [string]::IsNullOrWhiteSpace([string]$Script:CurrentTheme.FocusRing)) { [string]$Script:CurrentTheme.FocusRing } else { '#9ACAFF' }
			[void](& $setGuiControlPropertyScript -Control $Tab -PropertyName 'BorderBrush' -Value ($bc.ConvertFromString($focusRingColor)) -Context 'Add-AppsCategoryTabHoverEffects/GotFocus/BorderBrush')
			[void](& $setGuiControlPropertyScript -Control $Tab -PropertyName 'BorderThickness' -Value (& $newSafeThicknessScript -Uniform 1) -Context 'Add-AppsCategoryTabHoverEffects/GotFocus/BorderThickness')
		}.GetNewClosure()
		Register-GuiEventHandler -Source $Tab -EventName 'GotKeyboardFocus' -Handler ({
			& $invokeGuiSafeActionScript -Context 'Add-AppsCategoryTabHoverEffects/GotFocus' -Action $gotFocusHandler
		}.GetNewClosure())

		Register-GuiEventHandler -Source $Tab -EventName 'LostKeyboardFocus' -Handler ({
			& $invokeGuiSafeActionScript -Context 'Add-AppsCategoryTabHoverEffects/LostFocus' -Action $refreshTabVisualsHandler
		}.GetNewClosure())
	}

	<#
	    .SYNOPSIS
	    Internal function Set-AppCategoryFilterState.
	#>

	function Set-AppCategoryFilterState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[string]$Category = 'All'
		)

		Initialize-AppCategoryFilterState

		$normalizedCategory = if (Get-Command -Name 'Resolve-AppsCatalogCategory' -CommandType Function -ErrorAction SilentlyContinue) { Resolve-AppsCatalogCategory -Category $Category } elseif ([string]::IsNullOrWhiteSpace($Category) -or [string]$Category -eq 'All') { 'Browsers' } else { [string]$Category.Trim() }
		$Script:AppsCategoryFilter = $normalizedCategory

		Update-AppsCategoryTabVisuals

		if ($Script:AppsModeActive)
		{
			Build-AppsViewCards
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Initialize-AppStatusFilterState.
	#>

	function Initialize-AppStatusFilterState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		$allowed = @('All', 'Installed', 'NotInstalled', 'UpdateAvailable')
		if ([string]::IsNullOrWhiteSpace([string]$Script:AppsStatusFilter) -or $allowed -notcontains [string]$Script:AppsStatusFilter)
		{
			$Script:AppsStatusFilter = 'All'
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Update-AppStatusFilterList.
	#>

	function Update-AppStatusFilterList
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		$statusCombo = if ($Script:CmbAppsStatusFilter) { $Script:CmbAppsStatusFilter } else { $CmbAppsStatusFilter }
		if (-not $statusCombo)
		{
			return
		}

		Initialize-AppStatusFilterState

		$values = @('All', 'Installed', 'NotInstalled', 'UpdateAvailable')
		$locKeyMap = @{
			'All'             = 'GuiAppsStatusFilterAll'
			'Installed'       = 'GuiAppsStatusFilterInstalled'
			'NotInstalled'    = 'GuiAppsStatusFilterNotInstalled'
			'UpdateAvailable' = 'GuiAppsStatusFilterUpdateAvailable'
		}
		$fallbackMap = @{
			'All'             = 'All'
			'Installed'       = 'Installed'
			'NotInstalled'    = 'Not Installed'
			'UpdateAvailable' = 'Updates Available'
		}

		$currentValue = if ($Script:AppsStatusFilterInternalValues -and $statusCombo.SelectedIndex -ge 0 -and $statusCombo.SelectedIndex -lt $Script:AppsStatusFilterInternalValues.Count) { $Script:AppsStatusFilterInternalValues[$statusCombo.SelectedIndex] } elseif (-not [string]::IsNullOrWhiteSpace([string]$Script:AppsStatusFilter)) { [string]$Script:AppsStatusFilter.Trim() } else { 'All' }

		$Script:AppsFilterUiUpdating = $true
		try
		{
			$statusCombo.Items.Clear()
			$Script:AppsStatusFilterInternalValues = [System.Collections.Generic.List[string]]::new()
			if (Get-Command -Name 'Set-ChoiceComboStyle' -CommandType Function -ErrorAction SilentlyContinue)
			{
				try { Set-ChoiceComboStyle -Combo $statusCombo } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ApplicationsView.Update-AppStatusFilterList.SetChoiceComboStyle' }
			}
			$statusBrushConverter = New-SafeBrushConverter -Context 'Update-AppStatusFilterList'
			$statusForeground = $null
			if ($Script:CurrentTheme -and -not [string]::IsNullOrWhiteSpace([string]$Script:CurrentTheme.TextPrimary))
			{
				try { $statusForeground = $statusBrushConverter.ConvertFromString([string]$Script:CurrentTheme.TextPrimary) } catch { $statusForeground = $null }
			}
			if (-not $statusForeground)
			{
				try { $statusForeground = $statusBrushConverter.ConvertFromString('#F4F7FF') } catch { $statusForeground = $null }
			}
			foreach ($value in $values)
			{
				if ($value -eq 'UpdateAvailable')
				{
					$separator = New-Object System.Windows.Controls.Separator
					$separator.IsHitTestVisible = $false
					$separator.Focusable = $false
					[void]$statusCombo.Items.Add($separator)
					[void]$Script:AppsStatusFilterInternalValues.Add($null)
				}
				$locKey = $locKeyMap[$value]
				$fallback = $fallbackMap[$value]
				$displayValue = Get-UxLocalizedString -Key $locKey -Fallback $fallback
				if ([string]::IsNullOrWhiteSpace([string]$displayValue)) { $displayValue = $fallback }
				$item = New-Object System.Windows.Controls.ComboBoxItem
				$item.Content = [string]$displayValue
				if ($statusForeground)
				{
					try { $item.Foreground = $statusForeground } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ApplicationsView.Update-AppStatusFilterList.Foreground' }
					try { $item.SetValue([System.Windows.Documents.TextElement]::ForegroundProperty, $statusForeground) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ApplicationsView.Update-AppStatusFilterList.ForegroundProperty' }
				}
				[void]$statusCombo.Items.Add($item)
				[void]$Script:AppsStatusFilterInternalValues.Add($value)
			}

			if ($Script:AppsStatusFilterInternalValues.Contains($currentValue))
			{
				$found = $Script:AppsStatusFilterInternalValues.IndexOf($currentValue)
				if ($found -ge 0) { $statusCombo.SelectedIndex = [int]$found }
				$Script:AppsStatusFilter = $currentValue
			}
			else
			{
				$statusCombo.SelectedIndex = 0
				$Script:AppsStatusFilter = 'All'
			}
		}
		finally
		{
			$Script:AppsFilterUiUpdating = $false
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-AppStatusFilterState.
	#>

	function Set-AppStatusFilterState
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[string]$Status = 'All'
		)

		Initialize-AppStatusFilterState

		$allowed = @('All', 'Installed', 'NotInstalled', 'UpdateAvailable')
		$normalized = if ([string]::IsNullOrWhiteSpace($Status)) { 'All' } else { [string]$Status.Trim() }
		if ($allowed -notcontains $normalized) { $normalized = 'All' }
		$Script:AppsStatusFilter = $normalized

		if ($Script:AppsModeActive)
		{
			Build-AppsViewCards
		}
	}
