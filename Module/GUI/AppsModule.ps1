# App-focused helpers used by the Baseline GUI.

# P5 rollback checkpoint: AppsModule helpers are split into Module\GUI\AppsModule\*.ps1.
# Keep this explicit order so catalog, state, and chrome helpers load before orchestration entrypoints.
$appsModuleSplitRoot = Join-Path $PSScriptRoot 'AppsModule'
. (Join-Path $appsModuleSplitRoot 'CatalogHelpers.ps1')
. (Join-Path $appsModuleSplitRoot 'SelectionQueueState.ps1')
. (Join-Path $appsModuleSplitRoot 'ProgressNavChrome.ps1')

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

	$catalog = if (Get-Command -Name 'Get-LoadedBaselineApplicationsCatalog' -CommandType Function -ErrorAction SilentlyContinue) { @(Get-LoadedBaselineApplicationsCatalog) } else { @($Script:BaselineApplicationsCatalog) }
	if (-not $catalog) { return }

	$installApps   = [System.Collections.Generic.List[object]]::new()
	$uninstallApps = [System.Collections.Generic.List[object]]::new()
	$updateApps    = [System.Collections.Generic.List[object]]::new()
	foreach ($app in @($catalog))
	{
		if (-not $app) { continue }
		$appId = Get-ApplicationCatalogIdentityKey -Entry $app
		switch ((Get-AppQueuedAction -AppId $appId))
		{
			'Install'   { [void]$installApps.Add($app) }
			'Uninstall' { [void]$uninstallApps.Add($app) }
			'Update'    { [void]$updateApps.Add($app) }
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
	if ($updateApps.Count -gt 0)
	{
		[void]$taskQueue.Add([pscustomobject]@{ Action = 'Update'; Apps = @($updateApps) })
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
				try { $applyState.Timer.Stop() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Start-AppsModuleQueuedActionAsync.TimerStop' }
				try { $applyState.Timer.Dispose() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Start-AppsModuleQueuedActionAsync.TimerDispose' }
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
			LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionAppQueueStateFailed' -Fallback 'Failed to apply queued app actions'))
			try { $applyState.Timer.Stop() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Start-AppsModuleQueuedActionAsync.TimerStop' }
			try { $applyState.Timer.Dispose() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Start-AppsModuleQueuedActionAsync.TimerDispose' }
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
		try { Update-AppsPackageManagerBanner -AvailabilityState $packageManagerAvailabilityState } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Build-AppsViewCards.UpdateAppsPackageManagerBanner' }
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
	$appsViewModeActive = if ([string]::IsNullOrWhiteSpace([string]$Script:AppsViewMode)) { 'Cards' } else { [string]$Script:AppsViewMode }
	if ($appsViewModeActive -eq 'List')
	{
		$Script:AppsWrapPanel.Orientation = [System.Windows.Controls.Orientation]::Vertical
		$Script:AppsWrapPanel.ItemWidth = [double]::NaN
		$Script:AppsWrapPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Stretch
		$Script:AppsWrapPanel.Margin = [System.Windows.Thickness]::new(10, 10, 10, 10)
	}
	else
	{
		$Script:AppsWrapPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
		$Script:AppsWrapPanel.ItemWidth = [double]::NaN
		$Script:AppsWrapPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
		$Script:AppsWrapPanel.Margin = [System.Windows.Thickness]::new(10)
	}
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
	Update-AppStatusFilterList
	if (Get-Command -Name 'Update-AppsCategoryTabCounts' -CommandType Function -ErrorAction SilentlyContinue)
	{
		try { Update-AppsCategoryTabCounts } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Build-AppsViewCards.UpdateAppsCategoryTabCounts' }
	}
	$allCatalog = @(Get-BaselineApplicationsCatalog)
	$activeSearchQuery = if ($Script:AppsModeActive) { [string]$Script:AppsSearchText } else { [string]$Script:SearchText }
	$catalog = @(Get-AppsCatalogItemsBySearchStatusAndSourceFilters -SearchQuery $activeSearchQuery)

	# Per Apps Filter spec: if a previously selected app has been hidden by the
	# current filter combination, drop it from the selection set so bulk actions
	# only operate on what the user can actually see.
	if ($Script:SelectedAppIds -and $Script:SelectedAppIds.Count -gt 0)
	{
		$visibleKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
		foreach ($visibleEntry in $catalog)
		{
			if (-not $visibleEntry) { continue }
			$visibleKey = Get-ApplicationCatalogIdentityKey -Entry $visibleEntry
			if (-not [string]::IsNullOrWhiteSpace([string]$visibleKey))
			{
				[void]$visibleKeys.Add([string]$visibleKey)
			}
		}
		$stale = @($Script:SelectedAppIds | Where-Object { -not $visibleKeys.Contains([string]$_) })
		if ($stale.Count -gt 0)
		{
			foreach ($staleKey in $stale)
			{
				[void]$Script:SelectedAppIds.Remove([string]$staleKey)
			}
			if (Get-Command -Name 'Update-AppsSelectionSummary' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Update-AppsSelectionSummary
			}
		}
	}
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
		if ($Script:TxtAppsProgressText) { $Script:TxtAppsProgressText.Text = $emptySummaryText }
		$Script:AppsViewBuildSignature = $renderSignature
		Update-AppsSelectionSummary
		return
	}

	if ($catalog.Count -eq 0)
	{
		$emptyMessage = if ($activeStatusFilter -eq 'Installed')
		{
			(Get-UxLocalizedString -Key 'GuiAppsEmptyStateNoInstalled' -Fallback 'No installed applications match the current filters.')
		}
		elseif ($activeStatusFilter -eq 'NotInstalled')
		{
			(Get-UxLocalizedString -Key 'GuiAppsEmptyStateNoNotInstalled' -Fallback 'Every application in the current filters is already installed.')
		}
		elseif ($activeStatusFilter -eq 'UpdateAvailable')
		{
			(Get-UxLocalizedString -Key 'GuiAppsEmptyStateNoUpdates' -Fallback 'No updates are available for the current filters.')
		}
		elseif (-not [string]::IsNullOrWhiteSpace([string]$activeSearchQuery) -and ($Script:AppsCategoryFilter -and $Script:AppsCategoryFilter -ne 'All'))
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
		if ($Script:TxtAppsProgressText)
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
			$Script:TxtAppsProgressText.Text = $summaryText
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
	if ($Script:TxtAppsProgressText -and $buildProgressLabel)
	{
		$Script:TxtAppsProgressText.Text = $buildProgressLabel
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
		$appsViewModeLocal = if ([string]::IsNullOrWhiteSpace([string]$Script:AppsViewMode)) { 'Cards' } else { [string]$Script:AppsViewMode }
		$card = [System.Windows.Controls.Border]::new()
		if ($appsViewModeLocal -eq 'List')
		{
			$listWidthBinding = [System.Windows.Data.Binding]::new('ActualWidth')
			$listWidthBinding.Source = $Script:AppsWrapPanel
			$listWidthBinding.Mode = [System.Windows.Data.BindingMode]::OneWay
			$null = [System.Windows.Data.BindingOperations]::SetBinding($card, [System.Windows.Controls.Border]::WidthProperty, $listWidthBinding)
			$card.Margin = [System.Windows.Thickness]::new(0, 4, 0, 4)
			$card.Padding = [System.Windows.Thickness]::new(12, 8, 12, 8)
			$card.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Stretch
		}
		else
		{
			$card.Width = 340
			$card.Margin = [System.Windows.Thickness]::new(8)
			$card.Padding = [System.Windows.Thickness]::new(16)
		}
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

		if (-not [string]::IsNullOrWhiteSpace($entityType) -and @('winget','choco') -notcontains $entityType)
		{
			$typeBadge = [System.Windows.Controls.TextBlock]::new()
			$typeBadge.Text = switch ($entityType)
			{
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
				$selectionRow = [System.Windows.Controls.DockPanel]::new()
				$selectionRow.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
				$selectionRow.LastChildFill = $false

				$selectionCheckBox = [System.Windows.Controls.CheckBox]::new()
				$selectionCheckBox.Content = (Get-UxLocalizedString -Key 'GuiAppsSelectLabel' -Fallback 'Select')
				$selectionCheckBox.Margin = [System.Windows.Thickness]::new(0)
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
				[void]$stack.Children.Add($selectionRow)

			$buttonRow = [System.Windows.Controls.WrapPanel]::new()
			$buttonRow.Orientation = 'Horizontal'
			$buttonRow.Margin = [System.Windows.Thickness]::new(0, 12, 0, 0)

			$appCapture = $app
			$primaryActionKind = if ($isInstalled) { 'Uninstall' } else { 'Install' }
			$primaryActionRequiresCache = ($primaryActionKind -ne 'Install')
			$queuedActionForApp = Get-AppQueuedAction -AppId $selectionKeyCapture
			$primaryButton = [System.Windows.Controls.Button]::new()
			$primaryButton.Content = $primaryAction
			$primaryButton.MinWidth = 88
			$primaryButton.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
			$primaryButton.Cursor = [System.Windows.Input.Cursors]::Hand
			$primaryButton.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress) -and (-not $isAppActionBusy) -and ((-not $primaryActionRequiresCache) -or $cacheReady)
			$appCardWinGetId = $null
			$appCardChocoId = $null
			if ($appCapture.PSObject.Properties['WinGetId'] -and -not [string]::IsNullOrWhiteSpace([string]$appCapture.WinGetId))
			{
				$appCardWinGetId = [string]$appCapture.WinGetId
			}
			elseif ($appCapture.ExtraArgs -and $appCapture.ExtraArgs.PSObject.Properties['WinGetId'] -and -not [string]::IsNullOrWhiteSpace([string]$appCapture.ExtraArgs.WinGetId))
			{
				$appCardWinGetId = [string]$appCapture.ExtraArgs.WinGetId
			}
			if ($appCapture.PSObject.Properties['ChocoId'] -and -not [string]::IsNullOrWhiteSpace([string]$appCapture.ChocoId))
			{
				$appCardChocoId = [string]$appCapture.ChocoId
			}
			elseif ($appCapture.ExtraArgs -and $appCapture.ExtraArgs.PSObject.Properties['ChocoId'] -and -not [string]::IsNullOrWhiteSpace([string]$appCapture.ExtraArgs.ChocoId))
			{
				$appCardChocoId = [string]$appCapture.ExtraArgs.ChocoId
			}
			$hasMultipleSources = (-not [string]::IsNullOrWhiteSpace($appCardWinGetId)) -and (-not [string]::IsNullOrWhiteSpace($appCardChocoId))

			$primaryButton.ToolTip = if ($primaryActionKind -eq 'Install')
			{
				if ($hasMultipleSources -and -not [string]::IsNullOrWhiteSpace($selectedSourceLabel))
				{
					(Get-UxLocalizedString -Key 'GuiAppsQueueInstallViaSourceTip' -Fallback ('Will install via {0} (preferred). It runs when you click Apply Changes.' -f $selectedSourceLabel))
				}
				else
				{
					(Get-UxLocalizedString -Key 'Tooltip_QueueInstallApplication' -Fallback 'Stage an install for this app. It runs when you click Apply Changes.')
				}
			}
			else
			{
				(Get-UxLocalizedString -Key 'Tooltip_QueueUninstallApplication' -Fallback 'Stage an uninstall for this app. It runs when you click Apply Changes.')
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
					$current = Get-AppQueuedAction -AppId $selectionKeyCapture
					$desired = if ($current -eq $capturedPrimaryAction) { 'DoNothing' } else { $capturedPrimaryAction }
					& $setAppQueuedActionCommand -AppId $selectionKeyCapture -Action $desired
				}
				catch
				{
					$null = & $Script:ShowGuiRuntimeFailureScript -Context 'AppPrimaryButton' -Exception $_.Exception -ShowDialog
				}
			}.GetNewClosure())
			[void]$buttonRow.Children.Add($primaryButton)

			$updateButton = $null
			if ($isInstalled -or $hasUpdateAvailable)
			{
				$updateButton = [System.Windows.Controls.Button]::new()
				$updateButton.Content = (Get-UxLocalizedString -Key 'Update' -Fallback 'Update')
				$updateButton.MinWidth = 88
				$updateButton.Cursor = [System.Windows.Input.Cursors]::Hand
				$updateButton.IsEnabled = -not $isAppActionBusy
				$updateButton.ToolTip = if (-not [string]::IsNullOrWhiteSpace($selectedSourceLabel))
				{
					(Get-UxLocalizedString -Key 'GuiAppsQueueUpdateViaSourceTip' -Fallback ('Stage an update using {0}. It runs when you click Apply Changes.' -f $selectedSourceLabel))
				}
				else
				{
					(Get-UxLocalizedString -Key 'Tooltip_QueueUpdateApplication' -Fallback 'Stage an update for this app. It runs when you click Apply Changes.')
				}
				Set-ButtonChrome -Button $updateButton -Variant 'Secondary' -Compact
				Set-GuiButtonIconContent -Button $updateButton -IconName 'ArrowSync' -Text (Get-UxLocalizedString -Key 'Update' -Fallback 'Update') -IconSize 14 -Gap 6 -TextFontSize 11 -ToolTip $updateButton.ToolTip
				[void]$Script:AppsActionButtons.Add($updateButton)
				$updateButton.Add_Click({
					param($buttonSender, $buttonEventArgs)
					$null = $buttonEventArgs
					try
					{
						$current = Get-AppQueuedAction -AppId $selectionKeyCapture
						$desired = if ($current -eq 'Update') { 'DoNothing' } else { 'Update' }
						& $setAppQueuedActionCommand -AppId $selectionKeyCapture -Action $desired
					}
					catch
					{
						$null = & $Script:ShowGuiRuntimeFailureScript -Context 'AppUpdateButton' -Exception $_.Exception -ShowDialog
					}
				}.GetNewClosure())
				[void]$buttonRow.Children.Add($updateButton)
			}

			[void]$stack.Children.Add($buttonRow)

			# Queued-state badge, shown only when this app has a staged action.
			$queuedBadge = [System.Windows.Controls.Border]::new()
			$queuedBadge.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
			$queuedBadge.CornerRadius = [System.Windows.CornerRadius]::new(4)
			$queuedBadge.Padding = [System.Windows.Thickness]::new(8, 3, 8, 3)
			$queuedBadge.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
			$queuedBadge.Background = $bc.ConvertFromString($theme.AccentBlue)
			$queuedBadge.Visibility = [System.Windows.Visibility]::Collapsed
			$queuedBadgeText = [System.Windows.Controls.TextBlock]::new()
			$queuedBadgeText.FontSize = 11
			$queuedBadgeText.FontWeight = [System.Windows.FontWeights]::SemiBold
			$queuedBadgeText.Foreground = $bc.ConvertFromString($theme.ButtonPrimaryFg)
			$queuedBadgeText.Text = ''
			$queuedBadge.Child = $queuedBadgeText
			[void]$stack.Children.Add($queuedBadge)

			# Register controls so Sync-AppsQueuedActionControls can refresh button chrome
			# and badge visibility whenever the staged action for this app changes.
			if (-not [string]::IsNullOrWhiteSpace($selectionKeyCapture))
			{
				$Script:AppsQueuedActionControlMap[$selectionKeyCapture] = [pscustomobject]@{
					PrimaryButton     = $primaryButton
					PrimaryActionKind = $primaryActionKind
					UpdateButton      = $updateButton
					Badge             = $queuedBadge
					BadgeText         = $queuedBadgeText
				}
				[void]$Script:AppsQueuedActionControls.Add([pscustomobject]@{
					AppId = $selectionKeyCapture
				})
				Sync-AppsQueuedActionControls -AppId $selectionKeyCapture
			}
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
				try { Add-CardHoverEffects -Card $card -FocusSources $focusSources } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Build-AppsViewCards.AddCardHoverEffects' }
			}
		}

		[void]$Script:AppsWrapPanel.Children.Add($card)
		if (($Script:AppsWrapPanel.Children.Count % 10) -eq 0)
		{
			try { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Build-AppsViewCards.DispatcherYield' }
		}
	}

	if ($Script:TxtAppsProgressText)
	{
		if (-not $cacheReady)
		{
			$Script:TxtAppsProgressText.Text = $cacheRefreshPrompt
			Update-AppsSelectionSummary
			return
		}
		$filterActive = ($Script:AppsCategoryFilter -and $Script:AppsCategoryFilter -ne 'All') -or ($activeStatusFilter -and $activeStatusFilter -ne 'All')
		$summaryText = if ($filterActive)
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
		$Script:TxtAppsProgressText.Text = $summaryText
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

	$scanEntryTrace = Join-Path $env:TEMP 'Baseline-ScanEntry-trace.txt'
	try { "$([DateTime]::UtcNow.ToString('o'))`tStart-AppsCacheRefresh entered (InProgress={0})" -f $Script:AppsCacheRefreshInProgress | Out-File -FilePath $scanEntryTrace -Append -Encoding UTF8 -Force } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Start-AppsCacheRefresh.WriteEntryTrace' }

	if ($Script:AppsCacheRefreshInProgress)
	{
		return
	}

	$Script:AppsCacheRefreshInProgress = $true
	Set-AppsActionControlsEnabled -Enabled $false
	# Resolve every localized label here on the UI thread. The background
	# runspace does NOT have Get-UxLocalizedString / Get-UxBilingualLocalizedString
	# (they live in Module/GUI/UxPolicy.ps1 and aren't imported by
	# Regions\Applications.psm1), so calling them inside the scriptblock throws
	# "The term 'Get-UxLocalizedString' is not recognized" on the very first
	# line — the runspace errors out, the timer flips to the failure path, and
	# the user sees the Scan button grey out and come right back with zero
	# progress rendered.
	$phaseWinGetInstalled = Get-UxLocalizedString -Key 'Progress_CheckingInstallStatus' -Fallback 'Checking installation status...'
	$phaseChocolateyInstalled = Get-UxLocalizedString -Key 'GuiAppsCacheRefreshScanningChocolateyInstalled' -Fallback 'Checking Chocolatey installation status...'
	$phaseWinGetUpdates = Get-UxLocalizedString -Key 'Progress_WinGet_CheckingUpdates' -Fallback 'Checking for WinGet updates...'
	$phaseChocolateyUpdates = Get-UxLocalizedString -Key 'GuiAppsCacheRefreshScanningChocolateyUpdates' -Fallback 'Checking Chocolatey update availability...'
	$phaseComplete = Get-UxLocalizedString -Key 'GuiAppsCacheRefreshComplete' -Fallback 'Installed apps scanned.'
	$syncHash = [hashtable]::Synchronized(@{
		Completed    = 0
		Total        = 4
		CurrentAction = $phaseWinGetInstalled
		PhaseWinGetInstalled = $phaseWinGetInstalled
		PhaseChocolateyInstalled = $phaseChocolateyInstalled
		PhaseWinGetUpdates = $phaseWinGetUpdates
		PhaseChocolateyUpdates = $phaseChocolateyUpdates
		PhaseComplete = $phaseComplete
		Warnings     = [System.Collections.Generic.List[string]]::new()
		IsComplete   = $false
		Error        = $null
	})
	if ($Script:TxtAppsProgressText)
	{
		$initialProgressText = Set-SharedProgressBarState -ProgressBar $Script:AppsProgressBar -ProgressText $Script:TxtAppsProgressText -Completed $syncHash.Completed -Total $syncHash.Total -CurrentAction $syncHash.CurrentAction -PassThruText
		$Script:TxtAppsProgressText.Text = $initialProgressText
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
	# LogError is exported as an alias for Write-BaselineError (Logging.psm1);
	# without -CommandType Function,Alias this lookup always misses and throws
	# 'LogError not found.' from the guard below — surfaces as GUI-GENERIC-001
	# when the user clicks Scan Installed Apps.
	$appsLogErrorCommand = Get-Command 'LogError' -CommandType Function, Alias -ErrorAction SilentlyContinue | Select-Object -First 1
	if (-not $appsLogErrorCommand)
	{
		$appsLogErrorCommand = Get-Command 'Write-BaselineError' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	}
	$appsSetActionControlsEnabledCommand = Get-Command 'Set-AppsActionControlsEnabled' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1

	if (-not $appsGetApplicationCacheSnapshotCommand) { throw 'Get-ApplicationCacheSnapshot not found.' }
	if (-not $appsSetSharedProgressBarStateCommand) { throw 'Set-SharedProgressBarState not found.' }
	if (-not $appsGetUxLocalizedStringCommand) { throw 'Get-UxLocalizedString not found.' }
	if (-not $appsBuildAppsViewCardsCommand) { throw 'Build-AppsViewCards not found.' }
	if (-not $appsLogErrorCommand) { throw 'LogError not found.' }
	if (-not $appsSetActionControlsEnabledCommand) { throw 'Set-AppsActionControlsEnabled not found.' }

	$null = $ps.AddScript({
		param ($ModulePath, $Sync)
		$scanTracePath = Join-Path $env:TEMP 'Baseline-ScanWorker-trace.txt'
		function Write-ScanTrace { param([string]$Message) try { "$([DateTime]::UtcNow.ToString('o'))`t$Message" | Out-File -FilePath $scanTracePath -Append -Encoding UTF8 -Force } catch { $null = $_ } }
		Write-ScanTrace "--- scan worker start ---"
		Write-ScanTrace ("ModulePath={0} exists={1}" -f $ModulePath, (Test-Path $ModulePath))
		try
		{
		Write-ScanTrace "Import-Module Applications.psm1 START"
		Import-Module -Force -Global -Name $ModulePath
		Write-ScanTrace "Import-Module Applications.psm1 DONE"
		$wingetCache = @{}
		$chocolateyCache = @{}
		$wingetUpdateCache = @{}
		$chocolateyUpdateCache = @{}
		$Sync.Total = 4
		$Sync.Completed = 0
		$Sync.CurrentAction = $Sync.PhaseWinGetInstalled
		try
		{
			$Sync.CurrentAction = $Sync.PhaseWinGetInstalled
			Write-ScanTrace "Get-InstalledAppCache START"
			$wingetCache = Get-InstalledAppCache
			Write-ScanTrace ("Get-InstalledAppCache DONE count={0}" -f (@($wingetCache.Keys).Count))
		}
		catch
		{
			Write-ScanTrace ("Get-InstalledAppCache FAILED: {0}" -f $_.Exception.Message)
			[void]$Sync.Warnings.Add(("WinGet installed-cache scan failed: {0}" -f $_.Exception.Message))
		}
		finally
		{
			$Sync.Completed = 1
		}
		try
		{
			$Sync.CurrentAction = $Sync.PhaseChocolateyInstalled
			Write-ScanTrace "Get-InstalledChocolateyAppCache START"
			$chocolateyCache = Get-InstalledChocolateyAppCache
			Write-ScanTrace ("Get-InstalledChocolateyAppCache DONE count={0}" -f (@($chocolateyCache.Keys).Count))
		}
		catch
		{
			Write-ScanTrace ("Get-InstalledChocolateyAppCache FAILED: {0}" -f $_.Exception.Message)
			[void]$Sync.Warnings.Add(("Chocolatey installed-cache scan failed: {0}" -f $_.Exception.Message))
		}
		finally
		{
			$Sync.Completed = 2
		}
		try
		{
			$Sync.CurrentAction = $Sync.PhaseWinGetUpdates
			Write-ScanTrace "Get-AvailableAppUpdateCache START"
			$wingetUpdateCache = Get-AvailableAppUpdateCache
			Write-ScanTrace ("Get-AvailableAppUpdateCache DONE count={0}" -f (@($wingetUpdateCache.Keys).Count))
		}
		catch
		{
			Write-ScanTrace ("Get-AvailableAppUpdateCache FAILED: {0}" -f $_.Exception.Message)
			[void]$Sync.Warnings.Add(("WinGet update-cache scan failed: {0}" -f $_.Exception.Message))
		}
		finally
		{
			$Sync.Completed = 3
		}
		try
		{
			$Sync.CurrentAction = $Sync.PhaseChocolateyUpdates
			Write-ScanTrace "Get-AvailableChocolateyUpdateCache START"
			$chocolateyUpdateCache = Get-AvailableChocolateyUpdateCache
			Write-ScanTrace ("Get-AvailableChocolateyUpdateCache DONE count={0}" -f (@($chocolateyUpdateCache.Keys).Count))
		}
		catch
		{
			Write-ScanTrace ("Get-AvailableChocolateyUpdateCache FAILED: {0}" -f $_.Exception.Message)
			[void]$Sync.Warnings.Add(("Chocolatey update-cache scan failed: {0}" -f $_.Exception.Message))
		}
		finally
		{
			$Sync.Completed = 4
		}
		$Sync.CurrentAction = $Sync.PhaseComplete
		Write-ScanTrace "--- scan worker complete ---"
		[pscustomobject]@{
			WinGet = $wingetCache
			Chocolatey = $chocolateyCache
			WinGetUpdates = $wingetUpdateCache
			ChocolateyUpdates = $chocolateyUpdateCache
		}
		}
		catch
		{
			Write-ScanTrace ("FATAL CATCH type={0} msg={1}" -f $_.Exception.GetType().FullName, $_.Exception.Message)
			if ($_.ScriptStackTrace) { Write-ScanTrace ("ScriptStackTrace: {0}" -f [string]$_.ScriptStackTrace) }
			if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) { Write-ScanTrace ("PositionMessage: {0}" -f [string]$_.InvocationInfo.PositionMessage) }
			$Sync.Error = ("{0}: {1}`n{2}" -f $_.Exception.GetType().FullName, $_.Exception.Message, [string]$_.ScriptStackTrace)
			[void]$Sync.Warnings.Add(("Scan worker fatal: {0}" -f $_.Exception.Message))
			throw
		}
	}).AddArgument($appModulePath).AddArgument($syncHash)

	$asyncResult = $ps.BeginInvoke()
	$timer = [System.Windows.Threading.DispatcherTimer]::new()
	$timer.Interval = [TimeSpan]::FromMilliseconds(100)

	# Pre-capture UI references and apps module scope as locals.
	# GetNewClosure() rebinds the tick scriptblock to a new module whose
	# $Script: scope is empty, so $Script:AppsProgressBar etc. would resolve
	# to $null inside the tick. We snapshot them here so the closure captures
	# them as regular locals.
	$tickProgressBar = $Script:AppsProgressBar
	$tickProgressText = $Script:TxtAppsProgressText
	$appsScriptScope = $ExecutionContext.SessionState.Module
	$timer.Add_Tick({
		if ($syncHash.Error)
		{
			$timer.Stop()
			& $appsSetSharedProgressBarStateCommand -ProgressBar $tickProgressBar -ProgressText $tickProgressText -Completed 0 -Total 1 -CurrentAction (& $appsGetUxLocalizedStringCommand -Key 'GuiAppsCacheRefreshFailed' -Fallback 'Failed to scan installed applications.') -PassThruText | Out-Null
			& $appsLogErrorCommand (& $appsGetUxLocalizedStringCommand -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @([string]$syncHash.Error))
			try { $ps.Dispose() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Start-AppsCacheRefresh.DisposePowerShell' }
			try { $runspace.Dispose() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Start-AppsCacheRefresh.DisposeRunspace' }
			return
		}

		if ($tickProgressBar -or $tickProgressText)
		{
			$progressText = & $appsSetSharedProgressBarStateCommand -ProgressBar $tickProgressBar -ProgressText $tickProgressText -Completed $syncHash.Completed -Total $syncHash.Total -CurrentAction $syncHash.CurrentAction -PassThruText
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
			$resolvedCache = if ($cachePayload -is [psobject])
			{
				& $appsGetApplicationCacheSnapshotCommand -CacheState $cachePayload
			}
			elseif ($cachePayload -is [hashtable])
			{
				[pscustomobject]@{
					WinGet = $cachePayload
					Chocolatey = @{}
					WinGetUpdates = @{}
					ChocolateyUpdates = @{}
				}
			}
			else
			{
				[pscustomobject]@{
					WinGet = @{}
					Chocolatey = @{}
					WinGetUpdates = @{}
					ChocolateyUpdates = @{}
				}
			}
			# Write results back into the host module's script scope so the
			# rest of the GUI (which does live in that scope) sees them.
			& $appsScriptScope {
				param ($cache)
				$Script:InstalledAppsCache = $cache
				$Script:AppsViewLoaded = $true
				$Script:AppsViewDirty = $false
			} $resolvedCache
			& $appsSetSharedProgressBarStateCommand -ProgressBar $tickProgressBar -ProgressText $tickProgressText -Completed $syncHash.Total -Total $syncHash.Total -CurrentAction $syncHash.CurrentAction | Out-Null
			if ($syncHash.Warnings -and $syncHash.Warnings.Count -gt 0)
			{
				foreach ($warning in $syncHash.Warnings)
				{
					if (Get-Command -Name 'LogWarning' -ErrorAction SilentlyContinue)
					{
						try { LogWarning $warning } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Start-AppsCacheRefresh.LogWarning' }
					}
				}
			}
			& $appsBuildAppsViewCardsCommand
		}
		catch
		{
			& $appsScriptScope {
				$Script:InstalledAppsCache = [pscustomobject]@{
					WinGet = @{}
					Chocolatey = @{}
					WinGetUpdates = @{}
					ChocolateyUpdates = @{}
				}
				$Script:AppsViewLoaded = $false
				$Script:AppsViewDirty = $true
			}
			$progressText = & $appsSetSharedProgressBarStateCommand -ProgressBar $tickProgressBar -ProgressText $tickProgressText -Completed 0 -Total 1 -CurrentAction (& $appsGetUxLocalizedStringCommand -Key 'GuiAppsCacheRefreshFailed' -Fallback 'Failed to scan installed applications.') -PassThruText
			& $appsLogErrorCommand (& $appsGetUxLocalizedStringCommand -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message))
		}
		finally
		{
			& $appsScriptScope { $Script:AppsCacheRefreshInProgress = $false }
			& $appsSetActionControlsEnabledCommand -Enabled $true
			try { $ps.Dispose() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Start-AppsCacheRefresh.DisposePowerShell' }
			try { $runspace.Dispose() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Start-AppsCacheRefresh.DisposeRunspace' }
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

