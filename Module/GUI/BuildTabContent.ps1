	$Script:CurrentPrimaryTab = $null
	$Script:SubTabControls = @{}


	. (Join-Path $Script:GuiExtractedRoot 'PresetUI.ps1')


	<#
	    .SYNOPSIS
	    Internal function Add-TabSectionsToPanel.
	#>

	function Add-TabSectionsToPanel
	{
		param ([object]$BuildContext)

		foreach ($subKey in $BuildContext.CategoryTweaks.Keys)
		{
			try
			{
				$indexes = $BuildContext.CategoryTweaks[$subKey]
			}
			catch
			{
				throw "Build-TabContent/ResolveSection for tab '$($BuildContext.PrimaryTab)' section '$([string]$subKey)' failed: $($_.Exception.Message)"
			}

			$showSectionHeader = $BuildContext.IsSearchResultsTab -or ($BuildContext.CategoryTweaks.Count -gt 1) -or ([string]$subKey -ne 'General')
			if ($showSectionHeader)
			{
				try
				{
					[void]($BuildContext.MainPanel.Children.Add((New-SectionHeader -Text $subKey)))
				}
				catch
				{
					throw "Build-TabContent/SectionHeader for tab '$($BuildContext.PrimaryTab)' section '$([string]$subKey)' failed: $($_.Exception.Message)"
				}
			}

			try
			{
				$cautionTweaksList = [System.Collections.Generic.List[object]]::new()
				foreach ($index in $indexes)
				{
					if ($Script:TweakManifest[$index].Caution)
					{
						$cautionTweaksList.Add($Script:TweakManifest[$index])
					}
				}
				$cautionTweaks = $cautionTweaksList
			}
			catch
			{
				throw "Build-TabContent/CollectCautionTweaks for tab '$($BuildContext.PrimaryTab)' section '$([string]$subKey)' failed: $($_.Exception.Message)"
			}

			foreach ($index in $indexes)
			{
				try
				{
					$tweak = $Script:TweakManifest[$index]
				}
				catch
				{
					throw "Build-TabContent/ResolveTweak for tab '$($BuildContext.PrimaryTab)' at index $index failed: $($_.Exception.Message)"
				}

				try
				{
					$row = Build-TweakRow -Index $index -Tweak $tweak -BrushConverter $BuildContext.BrushConverter
				}
				catch
				{
					throw "Build-TabContent/Row for tab '$($BuildContext.PrimaryTab)' failed at index $index ($([string]$tweak.Type) / $([string]$tweak.Function) / $([string]$tweak.Name)): $($_.Exception.Message)"
				}

				if ($row)
				{
					try
					{
						[void]($BuildContext.MainPanel.Children.Add($row))
					}
					catch
					{
						throw "Build-TabContent/AddRow for tab '$($BuildContext.PrimaryTab)' failed at index $index ($([string]$tweak.Type) / $([string]$tweak.Function) / $([string]$tweak.Name)): $($_.Exception.Message)"
					}
				}
			}

			try
			{
				$cautionSection = New-CautionSection -CautionTweaks $cautionTweaks
			}
			catch
			{
				throw "Build-TabContent/CautionSection for tab '$($BuildContext.PrimaryTab)' section '$([string]$subKey)' failed: $($_.Exception.Message)"
			}

			if ($cautionSection)
			{
				try
				{
					[void]($BuildContext.MainPanel.Children.Add($cautionSection))
				}
				catch
				{
					throw "Build-TabContent/AddCautionSection for tab '$($BuildContext.PrimaryTab)' section '$([string]$subKey)' failed: $($_.Exception.Message)"
				}
			}
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Save-TabContentCacheEntry.
	#>

	function Save-TabContentCacheEntry
	{
		param (
			[object]$BuildContext,
			[int[]]$AllTabIndexes,
			[switch]$CacheOnly
		)

		if (-not $CacheOnly)
		{
			$ContentScroll.Content = $BuildContext.MainPanel
		}
		$controlRefs = @{}
		foreach ($index in @($AllTabIndexes))
		{
			if ($Script:Controls.ContainsKey($index) -and $Script:Controls[$index])
			{
				$controlRefs[[int]$index] = $Script:Controls[$index]
			}
		}
		$Script:TabContentCache[$BuildContext.PrimaryTab] = @{
			Panel = $BuildContext.MainPanel
			ControlRefs = $controlRefs
			PresetStatusBadge = $Script:PresetStatusBadge
			FilterGeneration = $Script:FilterGeneration
		}
	}

	# Helper for Dispatcher.BeginInvoke tab pre-builds. Uses [scriptblock]::Create()
	# to embed $Tag as a string literal — PowerShell scriptblocks use dynamic scoping
	# so function parameters do not survive past the function return. The block is then
	# re-bound to this module so $Script: variables and sibling functions
	# (Build-TabContent, Test-GuiRunInProgress, etc.) remain resolvable.
	<#
	    .SYNOPSIS
	    Internal function New-TabPreBuildAction.
	#>

	function New-TabPreBuildAction
	{
		param ([string]$Tag)
		$safe = $Tag -replace "'", "''"
		$sb = [scriptblock]::Create(@"
try
{
	if (-not (Test-GuiRunInProgress) -and -not (`$Script:TabContentCache -and `$Script:TabContentCache.ContainsKey('$safe')))
	{
		Build-TabContent -PrimaryTab '$safe' -BackgroundBuild
	}
}
catch { Write-GuiRuntimeWarning -Context 'TabPreBuild:$safe' -Message `$_.Exception.Message }
"@)
		$mod = $ExecutionContext.SessionState.Module
		if ($mod) { $sb = $mod.NewBoundScriptBlock($sb) }
		return $sb
	}

	<#
	    .SYNOPSIS
	    Internal function Build-TabContent.
	#>

	function Build-TabContent
	{
		param (
			[string]$PrimaryTab,
			[switch]$BackgroundBuild,
			[switch]$SkipIdlePrebuild
		)

		if (-not $BackgroundBuild)
		{
			$Script:CurrentPrimaryTab = $PrimaryTab
			$Script:PresetStatusBadge = $null
			if (Get-Command -Name 'Update-PrimaryTabHeaders' -CommandType Function -ErrorAction SilentlyContinue)
			{
				try { Update-PrimaryTabHeaders } catch { $null = $_ }
			}
			if (Restore-CachedTabContent -PrimaryTab $PrimaryTab)
			{
				return
			}
		}
		elseif ($Script:TabContentCache.ContainsKey($PrimaryTab))
		{
			return
		}

		try
		{
			$buildContext = New-TabContentBuildContext -PrimaryTab $PrimaryTab
		}
		catch
		{
			throw "Build-TabContent/Preamble for tab '$PrimaryTab' failed: $($_.Exception.Message)"
		}

		Add-TabContentLeadPanel -BuildContext $buildContext

		$activeFilterItems = Get-ActiveTabFilterItems -BuildContext $buildContext
		if ($activeFilterItems.Count -gt 0)
		{
			try
			{
				[void]($buildContext.MainPanel.Children.Add((New-ActiveFiltersBanner -BuildContext $buildContext -ActiveFilterItems $activeFilterItems)))
			}
			catch
			{
				Write-GuiRuntimeWarning -Context 'Build-TabContent/ActiveFiltersBanner' -Message ("Active filters banner failed for tab '{0}': {1}" -f $PrimaryTab, $_.Exception.Message)
			}
		}

		if ($buildContext.CategoryTweaks.Count -eq 0)
		{
			try
			{
				[void]($buildContext.MainPanel.Children.Add((New-EmptyTabStateCard -BuildContext $buildContext -HasActiveFilters:($activeFilterItems.Count -gt 0))))
			}
			catch
			{
				throw "Build-TabContent/EmptyState for tab '$PrimaryTab' failed: $($_.Exception.Message)"
			}
		}

		try
		{
			$allTabIndexes = Get-TabContentIndexArray -CategoryTweaks $buildContext.CategoryTweaks
		}
		catch
		{
			throw "Build-TabContent/CollectTabIndexes for tab '$PrimaryTab' failed: $($_.Exception.Message)"
		}

		if ($allTabIndexes.Count -gt 0)
		{
			try
			{
				[void]($buildContext.MainPanel.Children.Add((New-TabSelectionBar -AllTabIndexes $allTabIndexes)))
			}
			catch
			{
				throw "Build-TabContent/SelectionBar for tab '$PrimaryTab' failed: $($_.Exception.Message)"
			}
		}

		# Suspend WPF layout passes while adding tweak rows to avoid
		# expensive per-child Measure/Arrange cycles.
		$panelSuspended = $false
		try
		{
			if ($buildContext.MainPanel -is [System.Windows.FrameworkElement])
			{
				$buildContext.MainPanel.BeginInit()
				$panelSuspended = $true
			}
		}
		catch { <# BeginInit not critical — continue without suspension #> }

		Add-TabSectionsToPanel -BuildContext $buildContext

		if ($panelSuspended)
		{
			try { $buildContext.MainPanel.EndInit() } catch { <# non-fatal #> }
		}

		try
		{
			Save-TabContentCacheEntry -BuildContext $buildContext -AllTabIndexes $allTabIndexes -CacheOnly:$BackgroundBuild
		}
		catch
		{
			throw "Build-TabContent/AssignContent for tab '$PrimaryTab' failed: $($_.Exception.Message)"
		}

		if (-not $BackgroundBuild)
		{
			try
			{
				Update-MainContentPanelWidth -Panel $buildContext.MainPanel
			}
			catch
			{
				throw "Build-TabContent/UpdatePanelWidth for tab '$PrimaryTab' failed: $($_.Exception.Message)"
			}
			try
			{
				Restore-CurrentTabScrollOffset -TabKey $PrimaryTab
			}
			catch
			{
				throw "Build-TabContent/RestoreScrollOffset for tab '$PrimaryTab' failed: $($_.Exception.Message)"
			}

			# Schedule pre-builds for uncached tabs at idle priority so first-visit
			# switches are instant instead of waiting for on-demand construction.
			if (-not $SkipIdlePrebuild -and $PrimaryTabs -and $PrimaryTabs.Dispatcher)
			{
				$searchTag = $Script:SearchResultsTabTag
				foreach ($tabItem in $PrimaryTabs.Items)
				{
					if (-not ($tabItem -is [System.Windows.Controls.TabItem]) -or -not $tabItem.Tag) { continue }
					$tabTag = [string]$tabItem.Tag
					if ($tabTag -eq $PrimaryTab -or $tabTag -eq $searchTag) { continue }
					if ($Script:TabContentCache -and $Script:TabContentCache.ContainsKey($tabTag)) { continue }
					# Use a helper function (instead of .GetNewClosure()) to capture $tabTag
					# per-iteration while preserving the scope chain so that Build-TabContent
					# and its dependencies (New-TabContentBuildContext, etc.) remain resolvable.
					$preBuildAction = New-TabPreBuildAction -Tag $tabTag
					$null = $PrimaryTabs.Dispatcher.BeginInvoke(
						[System.Action]$preBuildAction,
						[System.Windows.Threading.DispatcherPriority]::ApplicationIdle
					)
				}
			}
		}
	}
