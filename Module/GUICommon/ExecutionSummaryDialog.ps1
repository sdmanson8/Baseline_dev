# NOTE: This function is ~700 lines and contains duplicated status-styling logic
# for each outcome state. A future refactor should extract:
#   1. A status-styling lookup table (OutcomeState -> color/icon/label)
#   2. A card/row builder helper to reduce per-status boilerplate
#   3. Filter/grouping logic into a separate function
# The current implementation works correctly; the concern is maintainability.
<#
    .SYNOPSIS
    Internal function Show-ExecutionSummaryDialog.
#>
function Show-ExecutionSummaryDialog
{
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$Theme,

		[Parameter(Mandatory = $true)]
		[scriptblock]$ApplyButtonChrome,

		[object]$OwnerWindow,
		[object[]]$Results,
		[string]$Title = $null,
		[string]$SummaryText,
		[string]$LogPath,
		[object[]]$SummaryCards = @(),
		[string[]]$Buttons = @('Close'),
		[hashtable]$Strings = @{},
		[object]$UseDarkMode = $true
	)

	$bc = $Script:SharedBrushConverter
	$results = @($Results)
	$resolvedUseDarkMode = Get-GuiBooleanValue -Value $UseDarkMode -Default $true -Context 'Show-ExecutionSummaryDialog'

	# Localization helper: resolve at runtime, fall back to English if not available
	$getLocalStr = Get-Command -Name 'Get-UxLocalizedString' -CommandType Function -ErrorAction SilentlyContinue
	$L = { param([string]$Key, [string]$Fallback) if ($getLocalStr) { & $getLocalStr -Key $Key -Fallback $Fallback } else { $Fallback } }

	if ([string]::IsNullOrWhiteSpace($Title)) { $Title = (& $L 'GuiCommonExecutionSummary' 'Execution Summary') }

	$dlg = New-Object System.Windows.Window
	$dlg.Title = $Title
	$dlg.Width = $Script:GuiLayout.DialogLargeWidth
	$dlg.Height = $Script:GuiLayout.DialogLargeHeight
	$dlg.MinWidth = $Script:GuiLayout.DialogLargeMinWidth
	$dlg.MinHeight = $Script:GuiLayout.DialogLargeMinHeight
	$dlg.ResizeMode = 'CanResizeWithGrip'
	$dlg.WindowStartupLocation = 'CenterOwner'
	$dlg.Foreground = $bc.ConvertFromString($Theme.TextPrimary)
	$dlg.FontFamily = [System.Windows.Media.FontFamily]::new('FluentSystemIcons')
	$dlg.FontSize = $Script:GuiLayout.FontSizeBody
	$dlg.ShowInTaskbar = $false
	$dlg.WindowStyle = 'None'
	$dlg.AllowsTransparency = $true
	$dlg.Background = [System.Windows.Media.Brushes]::Transparent

	try
	{
		if ($OwnerWindow) { $dlg.Owner = $OwnerWindow }
	}
	catch
	{
		Write-GuiCommonWarning ("Failed to assign dialog owner for '{0}': {1}" -f $(if ($Title) { $Title } else { 'execution summary' }), $_.Exception.Message)
	}
	[void](Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode:$resolvedUseDarkMode)

	# Rounded container
	$dlgRoundBorder = New-Object System.Windows.Controls.Border
	$dlgRoundBorder.CornerRadius = [System.Windows.CornerRadius]::new(8)
	$dlgRoundBorder.Background = $bc.ConvertFromString($Theme.WindowBg)
	$dlgRoundBorder.BorderBrush = $bc.ConvertFromString($Theme.BorderColor)
	$dlgRoundBorder.BorderThickness = [System.Windows.Thickness]::new(1)
	$dlgDock = New-Object System.Windows.Controls.DockPanel
	$dlgDock.LastChildFill = $true

	# Title bar
	$dlgTBar = New-Object System.Windows.Controls.Border
	$dlgTBar.Background = $bc.ConvertFromString($(if ($Theme.HeaderBg) { $Theme.HeaderBg } else { $Theme.WindowBg }))
	$dlgTBar.CornerRadius = [System.Windows.CornerRadius]::new(8, 8, 0, 0)
	$dlgTBar.Padding = [System.Windows.Thickness]::new(12, 8, 8, 8)
	$dlgTBarGrid = New-Object System.Windows.Controls.Grid
	$dlgTBarTitle = New-Object System.Windows.Controls.TextBlock
	$dlgTBarTitle.Text = $Title
	$dlgTBarTitle.VerticalAlignment = 'Center'
	$dlgTBarTitle.FontSize = 12
	$dlgTBarTitle.Foreground = $bc.ConvertFromString($Theme.TextPrimary)
	[void]($dlgTBarGrid.Children.Add($dlgTBarTitle))
	$dlgTBarClose = New-Object System.Windows.Controls.Button
	$dlgTBarClose.Content = '×'
	$dlgTBarClose.FontFamily = [System.Windows.Media.FontFamily]::new('Arial')
	$dlgTBarClose.FontSize = 12
	$dlgTBarClose.Width = 32
	$dlgTBarClose.Height = 28
	$dlgTBarClose.Background = [System.Windows.Media.Brushes]::Transparent
	$dlgTBarClose.Foreground = $bc.ConvertFromString($Theme.TextPrimary)
	$dlgTBarClose.BorderThickness = [System.Windows.Thickness]::new(0)
	$dlgTBarClose.Cursor = [System.Windows.Input.Cursors]::Hand
	$dlgTBarClose.HorizontalAlignment = 'Right'
	$dlgTBarClose.VerticalContentAlignment = 'Center'
	$dlgTBarClose.HorizontalContentAlignment = 'Center'
	$dlgTBarClose.Add_Click({ $dlg.Close() }.GetNewClosure())
	[void]($dlgTBarGrid.Children.Add($dlgTBarClose))
	$dlgTBar.Child = $dlgTBarGrid
	$dlgTBar.Add_MouseLeftButtonDown({ $dlg.DragMove() }.GetNewClosure())
	$dlgTBarCtx2 = New-Object System.Windows.Controls.ContextMenu
	$dlgTBarCtx2Close = New-Object System.Windows.Controls.MenuItem
	$dlgTBarCtx2Close.Header = 'Close'; $dlgTBarCtx2Close.InputGestureText = 'Alt+F4'; $dlgTBarCtx2Close.FontWeight = [System.Windows.FontWeights]::Bold
	$dlgTBarCtx2Ref = $dlg
	$dlgTBarCtx2Close.Add_Click({ $dlgTBarCtx2Ref.Close() }.GetNewClosure())
	[void]$dlgTBarCtx2.Items.Add($dlgTBarCtx2Close)
	$dlgTBar.ContextMenu = $dlgTBarCtx2
	[System.Windows.Controls.DockPanel]::SetDock($dlgTBar, [System.Windows.Controls.Dock]::Top)
	[void]($dlgDock.Children.Add($dlgTBar))

	$outerGrid = New-Object System.Windows.Controls.Grid
	[void]($outerGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Auto) })))
	[void]($outerGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })))
	[void]($outerGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Auto) })))
	$headerBorder = New-Object System.Windows.Controls.Border
	$headerBorder.Padding = [System.Windows.Thickness]::new(24, 20, 24, 16)
	$headerBorder.BorderBrush = $bc.ConvertFromString($Theme.BorderColor)
	$headerBorder.BorderThickness = [System.Windows.Thickness]::new(0, 0, 0, 1)
	[System.Windows.Controls.Grid]::SetRow($headerBorder, 0)

	$headerStack = New-Object System.Windows.Controls.StackPanel
	$headerStack.Orientation = 'Vertical'

	$titleText = New-Object System.Windows.Controls.TextBlock
	$titleText.Text = $Title
	$titleText.FontSize = $Script:GuiLayout.FontSizeHeading
	$titleText.FontWeight = [System.Windows.FontWeights]::Bold
	$titleText.Foreground = $bc.ConvertFromString($Theme.TextPrimary)
	[void]($headerStack.Children.Add($titleText))
	if (-not [string]::IsNullOrWhiteSpace($SummaryText))
	{
		$summaryBlock = New-Object System.Windows.Controls.TextBlock
		$summaryBlock.Text = $SummaryText
		$summaryBlock.TextWrapping = 'Wrap'
		$summaryBlock.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
		$summaryBlock.Foreground = $bc.ConvertFromString($Theme.TextSecondary)
		[void]($headerStack.Children.Add($summaryBlock))
	}

	if (-not [string]::IsNullOrWhiteSpace($LogPath))
	{
		$logPathBlock = New-Object System.Windows.Controls.TextBlock
		$logFilePrefix = if ($Strings.ContainsKey('LogFilePrefix')) { [string]$Strings.LogFilePrefix } else { & $L 'GuiCommonLogFilePrefix' 'Log file' }
		$logPathBlock.Text = "{0}: {1}" -f $logFilePrefix, $LogPath
		$logPathBlock.TextWrapping = 'Wrap'
		$logPathBlock.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
		$logPathBlock.Foreground = $bc.ConvertFromString($Theme.TextMuted)
		$logPathBlock.FontSize = $Script:GuiLayout.FontSizeLabel
		[void]($headerStack.Children.Add($logPathBlock))
	}

	$headerBorder.Child = $headerStack
	[void]($outerGrid.Children.Add($headerBorder))
	$listScroll = New-Object System.Windows.Controls.ScrollViewer
	$listScroll.VerticalScrollBarVisibility = 'Auto'
	$listScroll.HorizontalScrollBarVisibility = 'Disabled'
	$listScroll.Margin = [System.Windows.Thickness]::new(0)
	[System.Windows.Controls.Grid]::SetRow($listScroll, 1)

	$listStack = New-Object System.Windows.Controls.StackPanel
	$listStack.Orientation = 'Vertical'
	$listStack.Margin = [System.Windows.Thickness]::new(18, 16, 18, 16)

	if (@($SummaryCards).Count -gt 0)
	{
		$summaryHeader = New-Object System.Windows.Controls.TextBlock
		$summaryHeader.Text = $(if ($Strings.ContainsKey('ImpactSummary')) { [string]$Strings.ImpactSummary } else { & $L 'GuiCommonImpactSummary' 'Impact summary' })
		$summaryHeader.FontSize = $Script:GuiLayout.FontSizeLabel
		$summaryHeader.FontWeight = [System.Windows.FontWeights]::SemiBold
		$summaryHeader.Foreground = $bc.ConvertFromString($Theme.TextSecondary)
		$summaryHeader.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
		[void]($listStack.Children.Add($summaryHeader))
		$summaryBorder = New-Object System.Windows.Controls.Border
		$summaryBorder.Background = $bc.ConvertFromString($Theme.PanelBg)
		$summaryBorder.BorderBrush = $bc.ConvertFromString($Theme.BorderColor)
		$summaryBorder.BorderThickness = [System.Windows.Thickness]::new(1)
		$summaryBorder.CornerRadius = [System.Windows.CornerRadius]::new($Script:GuiLayout.CardCornerRadius)
		$summaryBorder.Padding = [System.Windows.Thickness]::new(12, 12, 12, 4)
		$summaryBorder.Margin = [System.Windows.Thickness]::new(0, 0, 0, 14)
		$summaryBorder.Child = (New-DialogSummaryCardsPanel -Theme $Theme -SummaryCards $SummaryCards)
		[void]($listStack.Children.Add($summaryBorder))
	}

	# ── Status filter bar ──────────────────────────────────────────
	# Clickable status pills that filter the results list below.
	# Only shown for non-preview (post-execution) results.
	$statusFilterActiveRef = @{ Value = $null }  # tracks active filter; $null = show all
	$allResultCards = [System.Collections.Generic.List[object]]::new()  # populated during card build
	$allResultStatusMap = [System.Collections.Generic.List[string]]::new()  # parallel list of status category per card
	$filterBarPanel = $null
	$filterPillButtons = @{}

	$isPreviewModeForFilter = @($Results | Where-Object { @('Already in desired state', 'Will change', 'Requires restart', 'High-risk changes', 'Not fully restorable', 'Preview') -contains [string]$_.Status }).Count -gt 0
	if (-not $isPreviewModeForFilter -and @($Results).Count -gt 0)
	{
		# Count results by status category for filter pills
		$statusCounts = [ordered]@{
			'Success'         = @(@($Results) | Where-Object { [string]$_.Status -eq 'Success' }).Count
			'Skipped'         = @(@($Results) | Where-Object { [string]$_.Status -eq 'Skipped' -or [string]$_.Status -eq 'Not applicable' -or [string]$_.Status -eq 'Not Run' }).Count
			'Failed'          = @(@($Results) | Where-Object { [string]$_.Status -eq 'Failed' }).Count
			'Restart pending' = @(@($Results) | Where-Object { [string]$_.Status -eq 'Restart pending' }).Count
		}

		$filterBarBorder = New-Object System.Windows.Controls.Border
		$filterBarBorder.Background = $bc.ConvertFromString($Theme.PanelBg)
		$filterBarBorder.BorderBrush = $bc.ConvertFromString($Theme.BorderColor)
		$filterBarBorder.BorderThickness = [System.Windows.Thickness]::new(1)
		$filterBarBorder.CornerRadius = [System.Windows.CornerRadius]::new($Script:GuiLayout.CardCornerRadius)
		$filterBarBorder.Padding = [System.Windows.Thickness]::new(10, 8, 10, 8)
		$filterBarBorder.Margin = [System.Windows.Thickness]::new(0, 0, 0, 14)

		$filterBarPanel = New-Object System.Windows.Controls.WrapPanel
		$filterBarPanel.Orientation = 'Horizontal'
		$filterBarPanel.HorizontalAlignment = 'Left'

		# "All" pill
		$allPillBtn = New-Object System.Windows.Controls.Button
		$allResultsLabel = if ($Strings.ContainsKey('AllResultsPrefix')) { [string]$Strings.AllResultsPrefix } else { 'All' }
		$allPillBtn.Content = "{0}: {1}" -f $allResultsLabel, $Results.Count
		$allPillBtn.Margin = [System.Windows.Thickness]::new(0, 2, 8, 2)
		$allPillBtn.Padding = [System.Windows.Thickness]::new(12, 5, 12, 5)
		$allPillBtn.Cursor = [System.Windows.Input.Cursors]::Hand
		$allPillBtn.FontSize = $Script:GuiLayout.FontSizeLabel
		$allPillBtn.FontWeight = [System.Windows.FontWeights]::SemiBold
		$allPillBtn.BorderThickness = [System.Windows.Thickness]::new(1)
		& $ApplyButtonChrome -Button $allPillBtn -Variant 'Primary'
		$filterPillButtons['All'] = $allPillBtn
		[void]($filterBarPanel.Children.Add($allPillBtn))

		$filterPillColorMap = @{
			'Success'         = @{ Bg = $Theme.LowRiskBadgeBg; Border = $Theme.LowRiskBadge; Fg = $Theme.LowRiskBadge }
			'Skipped'         = @{ Bg = $Theme.TabBg; Border = $Theme.BorderColor; Fg = $Theme.TextSecondary }
			'Failed'          = @{ Bg = $Theme.RiskHighBadgeBg; Border = $Theme.RiskHighBadge; Fg = $Theme.RiskHighBadge }
			'Restart pending' = @{ Bg = $Theme.RiskMediumBadgeBg; Border = $Theme.RiskMediumBadge; Fg = $Theme.RiskMediumBadge }
		}

		foreach ($filterKey in $statusCounts.Keys)
		{
			$count = $statusCounts[$filterKey]
			if ($count -eq 0) { continue }
			$pillBtn = New-Object System.Windows.Controls.Button
			$displayLabel = $filterKey.ToUpperInvariant()
			$pillBtn.Content = "${displayLabel}: $count"
			$pillBtn.Margin = [System.Windows.Thickness]::new(0, 2, 8, 2)
			$pillBtn.Padding = [System.Windows.Thickness]::new(12, 5, 12, 5)
			$pillBtn.Cursor = [System.Windows.Input.Cursors]::Hand
			$pillBtn.FontSize = $Script:GuiLayout.FontSizeLabel
			$pillBtn.FontWeight = [System.Windows.FontWeights]::SemiBold
			$pillBtn.BorderThickness = [System.Windows.Thickness]::new(1)
			$pillColors = $filterPillColorMap[$filterKey]
			$pillBtn.Background = $bc.ConvertFromString($pillColors.Bg)
			$pillBtn.BorderBrush = $bc.ConvertFromString($pillColors.Border)
			$pillBtn.Foreground = $bc.ConvertFromString($pillColors.Fg)
			$filterPillButtons[$filterKey] = $pillBtn
			[void]($filterBarPanel.Children.Add($pillBtn))
		}

		$filterBarBorder.Child = $filterBarPanel
		[void]($listStack.Children.Add($filterBarBorder))

		# Wire up click handlers (after all pills created so closures can reference them)
		$capturedFilterActiveRef = $statusFilterActiveRef
		$capturedFilterPillButtons = $filterPillButtons
		$capturedAllResultCards = $allResultCards
		$capturedAllResultStatusMap = $allResultStatusMap
		$capturedApplyChrome = $ApplyButtonChrome
		$capturedFilterPillColorMap = $filterPillColorMap
		$capturedBcFilter = $bc

		$applyFilterAction = {
			param([string]$SelectedFilter)
			# Update active filter
			if ($SelectedFilter -eq 'All' -or $capturedFilterActiveRef.Value -eq $SelectedFilter)
			{
				$capturedFilterActiveRef.Value = $null
			}
			else
			{
				$capturedFilterActiveRef.Value = $SelectedFilter
			}

			# Restyle pills: active filter gets Primary chrome, others revert
			foreach ($key in @($capturedFilterPillButtons.Keys))
			{
				$btn = $capturedFilterPillButtons[$key]
				if ($key -eq 'All')
				{
					if ($null -eq $capturedFilterActiveRef.Value)
					{
						& $capturedApplyChrome -Button $btn -Variant 'Primary'
					}
					else
					{
						& $capturedApplyChrome -Button $btn -Variant 'Subtle'
					}
				}
				else
				{
					$colors = $capturedFilterPillColorMap[$key]
					if ($key -eq $capturedFilterActiveRef.Value)
					{
						# Active: brighter border
						$btn.Background = $capturedBcFilter.ConvertFromString($colors.Border)
						$btn.Foreground = $capturedBcFilter.ConvertFromString('#FFFFFF')
						$btn.BorderBrush = $capturedBcFilter.ConvertFromString($colors.Border)
					}
					else
					{
						$btn.Background = $capturedBcFilter.ConvertFromString($colors.Bg)
						$btn.Foreground = $capturedBcFilter.ConvertFromString($colors.Fg)
						$btn.BorderBrush = $capturedBcFilter.ConvertFromString($colors.Border)
					}
				}
			}

			# Show/hide result cards based on filter
			for ($fi = 0; $fi -lt $capturedAllResultCards.Count; $fi++)
			{
				$card = $capturedAllResultCards[$fi]
				$cardStatus = $capturedAllResultStatusMap[$fi]
				if ($null -eq $capturedFilterActiveRef.Value -or $cardStatus -eq $capturedFilterActiveRef.Value)
				{
					$card.Visibility = [System.Windows.Visibility]::Visible
				}
				else
				{
					$card.Visibility = [System.Windows.Visibility]::Collapsed
				}
			}
		}

		$capturedApplyFilter = $applyFilterAction

		# "All" pill click
		$allPillBtn.Add_Click({
			& $capturedApplyFilter 'All'
		}.GetNewClosure())

		# Status pill clicks
		foreach ($filterKey in $statusCounts.Keys)
		{
			$count = $statusCounts[$filterKey]
			if ($count -eq 0) { continue }
			$btn = $filterPillButtons[$filterKey]
			$capturedKey = $filterKey
			$btn.Add_Click({
				& $capturedApplyFilter $capturedKey
			}.GetNewClosure())
		}
	}
	# ── End status filter bar ──────────────────────────────────────

	$previewStatusOrder = @{
		'Already in desired state' = 0
		'Will change' = 1
		'Requires restart' = 2
		'High-risk changes' = 3
		'Not fully restorable' = 4
		'Preview' = 1
	}
	$previewStatuses = @('Already in desired state', 'Will change', 'Requires restart', 'High-risk changes', 'Not fully restorable', 'Preview')
	$isPreviewMode = @($results | Where-Object { $previewStatuses -contains [string]$_.Status }).Count -gt 0
	$hasPreviewGroups = @($results | Where-Object { (Test-GuiObjectField -Object $_ -FieldName 'PreviewGroupHeader') -and -not [string]::IsNullOrWhiteSpace([string]$_.PreviewGroupHeader) }).Count -gt 0
	$displayResults = if ($isPreviewMode)
	{
		if ($hasPreviewGroups)
		{
			@($results | Sort-Object `
				@{ Expression = { if ((Test-GuiObjectField -Object $_ -FieldName 'PreviewGroupSortOrder')) { [int]$_.PreviewGroupSortOrder } else { 99 } } }, `
				@{ Expression = { if ($previewStatusOrder.ContainsKey([string]$_.Status)) { [int]$previewStatusOrder[[string]$_.Status] } else { 99 } } }, `
				@{ Expression = { [int]$_.Order } })
		}
		else
		{
			@($results | Sort-Object `
				@{ Expression = { if ($previewStatusOrder.ContainsKey([string]$_.Status)) { [int]$previewStatusOrder[[string]$_.Status] } else { 99 } } }, `
				@{ Expression = { [int]$_.Order } })
		}
	}
	else
	{
		$results
	}
	$lastPreviewSection = $null

	# Pre-compute frequently used brushes before the loop to avoid repeated
	# ConvertFromString calls (saves hundreds of conversions for 269+ results).
	$preThickness1 = [System.Windows.Thickness]::new(1)
	$preBrushCardBg = $bc.ConvertFromString($Theme.CardBg)
	$preBrushCardBorder = $bc.ConvertFromString($Theme.CardBorder)
	$preBrushTextPrimary = $bc.ConvertFromString($Theme.TextPrimary)
	$preBrushTextSecondary = $bc.ConvertFromString($Theme.TextSecondary)
	$preBrushTextMuted = $bc.ConvertFromString($Theme.TextMuted)
	$preBrushSectionLabel = $bc.ConvertFromString($Theme.SectionLabel)
	$preBrushCautionText = $bc.ConvertFromString($Theme.CautionText)
	$preStatusBrushes = @{
		'Failed'                = @{ Bg = $bc.ConvertFromString($Theme.RiskHighBadgeBg); Border = $bc.ConvertFromString($Theme.RiskHighBadge); Fg = $bc.ConvertFromString($Theme.RiskHighBadge) }
		'High-risk changes'     = @{ Bg = $bc.ConvertFromString($Theme.RiskHighBadgeBg); Border = $bc.ConvertFromString($Theme.RiskHighBadge); Fg = $bc.ConvertFromString($Theme.RiskHighBadge) }
		'Not fully restorable'  = @{ Bg = $bc.ConvertFromString($Theme.RiskHighBadgeBg); Border = $bc.ConvertFromString($Theme.RiskHighBadge); Fg = $bc.ConvertFromString($Theme.RiskHighBadge) }
		'Requires restart'      = @{ Bg = $bc.ConvertFromString($Theme.RiskMediumBadgeBg); Border = $bc.ConvertFromString($Theme.RiskMediumBadge); Fg = $bc.ConvertFromString($Theme.RiskMediumBadge) }
		'Restart pending'       = @{ Bg = $bc.ConvertFromString($Theme.RiskMediumBadgeBg); Border = $bc.ConvertFromString($Theme.RiskMediumBadge); Fg = $bc.ConvertFromString($Theme.RiskMediumBadge) }
		'Will change'           = @{ Bg = $bc.ConvertFromString($Theme.StatusPillBg); Border = $bc.ConvertFromString($Theme.StatusPillBorder); Fg = $bc.ConvertFromString($Theme.StatusPillText) }
		'Already in desired state' = @{ Bg = $bc.ConvertFromString($Theme.LowRiskBadgeBg); Border = $bc.ConvertFromString($Theme.LowRiskBadge); Fg = $bc.ConvertFromString($Theme.LowRiskBadge) }
		'Preview'               = @{ Bg = $bc.ConvertFromString($Theme.StatusPillBg); Border = $bc.ConvertFromString($Theme.StatusPillBorder); Fg = $bc.ConvertFromString($Theme.StatusPillText) }
		'Skipped'               = @{ Bg = $bc.ConvertFromString($Theme.TabBg); Border = $bc.ConvertFromString($Theme.BorderColor); Fg = $bc.ConvertFromString($Theme.TextSecondary) }
		'Not applicable'        = @{ Bg = $bc.ConvertFromString($Theme.TabBg); Border = $bc.ConvertFromString($Theme.BorderColor); Fg = $bc.ConvertFromString($Theme.TextSecondary) }
		'Not Run'               = @{ Bg = $bc.ConvertFromString($Theme.TabBg); Border = $bc.ConvertFromString($Theme.CautionBorder); Fg = $bc.ConvertFromString($Theme.CautionText) }
	}
	$preDefaultStatusBrushes = @{ Bg = $bc.ConvertFromString($Theme.LowRiskBadgeBg); Border = $bc.ConvertFromString($Theme.LowRiskBadge); Fg = $bc.ConvertFromString($Theme.LowRiskBadge) }

	# Suspend layout while adding all result cards to avoid per-child
	# Measure/Arrange cycles that make the dialog slow to open.
	try { $listStack.BeginInit() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ExecutionSummaryDialog.Show-ExecutionSummaryDialog.ListStackBeginInit' }

	# Limit the initial batch to keep dialog open time fast; remaining
	# results are loaded when the user scrolls or clicks "Show all".
	$initialBatchLimit = 50
	$resultIndex = 0
	$totalResultCount = $displayResults.Count

	foreach ($result in $displayResults)
	{
		if ($isPreviewMode)
		{
			$sectionLabel = if ($hasPreviewGroups -and (Test-GuiObjectField -Object $result -FieldName 'PreviewGroupHeader') -and -not [string]::IsNullOrWhiteSpace([string]$result.PreviewGroupHeader)) {
				[string]$result.PreviewGroupHeader
			}
			elseif ([string]::IsNullOrWhiteSpace([string]$result.Status)) {
				'Will change'
			}
			else {
				[string]$result.Status
			}
			if ($sectionLabel -ne $lastPreviewSection)
			{
				$sectionHeader = New-Object System.Windows.Controls.TextBlock
				$sectionHeader.Text = $sectionLabel.ToUpperInvariant()
				$sectionHeader.FontSize = $Script:GuiLayout.FontSizeLabel
				$sectionHeader.FontWeight = [System.Windows.FontWeights]::Bold
				$sectionHeader.Foreground = $preBrushSectionLabel
				$sectionHeader.Margin = [System.Windows.Thickness]::new(0, $(if ($null -eq $lastPreviewSection) { 0 } else { 8 }), 0, 8)
				[void]($listStack.Children.Add($sectionHeader))
				$lastPreviewSection = $sectionLabel
			}
		}

		# Determine the status category for filtering and left-border color
		$cardStatusCategory = switch ([string]$result.Status)
		{
			'Success'         { 'Success'; break }
			'Skipped'         { 'Skipped'; break }
			'Not applicable'  { 'Skipped'; break }
			'Not Run'         { 'Skipped'; break }
			'Restart pending' { 'Restart pending'; break }
			'Failed'          { 'Failed'; break }
			default           { 'Success' }
		}

		$leftBorderColor = switch ($cardStatusCategory)
		{
			'Success'         { $bc.ConvertFromString($Theme.LowRiskBadge); break }
			'Skipped'         { $bc.ConvertFromString($Theme.BorderColor); break }
			'Failed'          { $bc.ConvertFromString($Theme.RiskHighBadge); break }
			'Restart pending' { $bc.ConvertFromString($Theme.RiskMediumBadge); break }
			default           { $bc.ConvertFromString($Theme.LowRiskBadge) }
		}

		$rowBorder = New-Object System.Windows.Controls.Border
		$rowBorder.Background = $preBrushCardBg
		$rowBorder.BorderBrush = $preBrushCardBorder
		$rowBorder.BorderThickness = [System.Windows.Thickness]::new(3, 1, 1, 1)
		$rowBorder.CornerRadius = [System.Windows.CornerRadius]::new($Script:GuiLayout.CardCornerRadius)
		$rowBorder.Padding = [System.Windows.Thickness]::new(14, 12, 14, 12)
		$rowBorder.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)
		$rowBorder.Cursor = [System.Windows.Input.Cursors]::Hand

		# Color the left border by status category
		$rowBorder.BorderBrush = $leftBorderColor

		$rowStack = New-Object System.Windows.Controls.StackPanel
		$rowStack.Orientation = 'Vertical'

		$headerGrid = New-Object System.Windows.Controls.Grid
		[void]($headerGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })))
		[void]($headerGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Auto) })))
		$nameBlock = New-Object System.Windows.Controls.TextBlock
		$nameBlock.Text = [string]$result.Name
		$nameBlock.FontSize = 13
		$nameBlock.FontWeight = [System.Windows.FontWeights]::SemiBold
		$nameBlock.TextWrapping = 'Wrap'
		$nameBlock.Foreground = $preBrushTextPrimary
		[System.Windows.Controls.Grid]::SetColumn($nameBlock, 0)
		[void]($headerGrid.Children.Add($nameBlock))
		$statusBorder = New-Object System.Windows.Controls.Border
		$statusBorder.CornerRadius = [System.Windows.CornerRadius]::new($Script:GuiLayout.PillCornerRadius)
		$statusBorder.Padding = [System.Windows.Thickness]::new(10, 4, 10, 4)
		$statusBorder.Margin = [System.Windows.Thickness]::new(10, 0, 0, 0)
		$statusBorder.BorderThickness = $preThickness1
		$statusText = New-Object System.Windows.Controls.TextBlock
		$statusText.Text = [string]$result.Status
		$statusText.FontSize = $Script:GuiLayout.FontSizeLabel
		$statusText.FontWeight = [System.Windows.FontWeights]::SemiBold

		$statusKey = [string]$result.Status
		$statusBrushSet = if ($preStatusBrushes.ContainsKey($statusKey)) { $preStatusBrushes[$statusKey] } else { $preDefaultStatusBrushes }
		$statusBorder.Background = $statusBrushSet.Bg
		$statusBorder.BorderBrush = $statusBrushSet.Border
		$statusText.Foreground = $statusBrushSet.Fg

		$statusBorder.Child = $statusText
		[System.Windows.Controls.Grid]::SetColumn($statusBorder, 1)
		[void]($headerGrid.Children.Add($statusBorder))
		[void]($rowStack.Children.Add($headerGrid))
		$metaParts = @()
		if (-not [string]::IsNullOrWhiteSpace([string]$result.Category)) { $metaParts += [string]$result.Category }
		if (-not [string]::IsNullOrWhiteSpace([string]$result.Selection)) { $metaParts += [string]$result.Selection }
		if (-not [string]::IsNullOrWhiteSpace([string]$result.Risk)) { $metaParts += ("{0} Risk" -f [string]$result.Risk) }
		if ($metaParts.Count -gt 0)
		{
			$metaBlock = New-Object System.Windows.Controls.TextBlock
			$metaBlock.Text = ($metaParts -join '  |  ')
			$metaBlock.TextWrapping = 'Wrap'
			$metaBlock.Margin = [System.Windows.Thickness]::new(0, 6, 0, 0)
			$metaBlock.FontSize = $Script:GuiLayout.FontSizeLabel
			$metaBlock.Foreground = $preBrushTextMuted
			[void]($rowStack.Children.Add($metaBlock))
		}

		$chipItems = New-Object System.Collections.Generic.List[object]
		$typeLabel = $null
		$typeTone = 'Muted'
		if ((Test-GuiObjectField -Object $result -FieldName 'TypeBadgeLabel') -and -not [string]::IsNullOrWhiteSpace([string]$result.TypeBadgeLabel))
		{
			$typeLabel = [string]$result.TypeBadgeLabel
		}
		elseif ((Test-GuiObjectField -Object $result -FieldName 'TypeLabel') -and -not [string]::IsNullOrWhiteSpace([string]$result.TypeLabel))
		{
			$typeLabel = [string]$result.TypeLabel
		}
		elseif ((Test-GuiObjectField -Object $result -FieldName 'Type') -and -not [string]::IsNullOrWhiteSpace([string]$result.Type))
		{
			$typeLabel = [string]$result.Type
		}
		if ((Test-GuiObjectField -Object $result -FieldName 'TypeTone') -and -not [string]::IsNullOrWhiteSpace([string]$result.TypeTone))
		{
			$typeTone = [string]$result.TypeTone
		}
		elseif ($typeLabel -eq 'Uninstall / Remove')
		{
			$typeTone = 'Danger'
		}
		elseif ($typeLabel -eq 'Toggle')
		{
			$typeTone = 'Success'
		}
		elseif ($typeLabel -eq 'Choice')
		{
			$typeTone = 'Primary'
		}
		if (-not [string]::IsNullOrWhiteSpace($typeLabel))
		{
			[void]$chipItems.Add([pscustomobject]@{
				Label = $typeLabel
				Tone = $typeTone
				ToolTip = 'Type of tweak'
			})
		}

		$currentState = $null
		$currentStateTone = 'Muted'
		if ((Test-GuiObjectField -Object $result -FieldName 'CurrentState') -and -not [string]::IsNullOrWhiteSpace([string]$result.CurrentState))
		{
			$currentState = [string]$result.CurrentState
		}
		elseif ((Test-GuiObjectField -Object $result -FieldName 'StateLabel') -and -not [string]::IsNullOrWhiteSpace([string]$result.StateLabel))
		{
			$currentState = [string]$result.StateLabel
		}
		if ((Test-GuiObjectField -Object $result -FieldName 'CurrentStateTone') -and -not [string]::IsNullOrWhiteSpace([string]$result.CurrentStateTone))
		{
			$currentStateTone = [string]$result.CurrentStateTone
		}
		elseif ($currentState -eq 'Enabled')
		{
			$currentStateTone = 'Success'
		}
		elseif ($currentState -eq 'Custom')
		{
			$currentStateTone = 'Primary'
		}
		if (-not [string]::IsNullOrWhiteSpace($currentState))
		{
			[void]$chipItems.Add([pscustomobject]@{
				Label = $currentState
				Tone = $currentStateTone
				ToolTip = 'Current state in the GUI'
			})
		}

		$outcomeState = $null
		if ((Test-GuiObjectField -Object $result -FieldName 'OutcomeState') -and -not [string]::IsNullOrWhiteSpace([string]$result.OutcomeState))
		{
			$outcomeState = [string]$result.OutcomeState
		}
		if (-not [string]::IsNullOrWhiteSpace($outcomeState))
		{
			$outcomeTone = switch -Regex ($outcomeState)
			{
				'^(Success|Already in desired state|Already at Windows default|Not applicable|Not applicable on this system)$' { 'Success'; break }
				'^(Restart pending|Failed and recoverable)$' { 'Caution'; break }
				'^(Skipped by preset or selection|Not supported by in-app restore)$' { 'Muted'; break }
				'^(Failed and manual intervention required|Not run)$' { 'Danger'; break }
				default { 'Muted' }
			}
			[void]$chipItems.Add([pscustomobject]@{
				Label = $outcomeState
				Tone = $outcomeTone
				ToolTip = 'Normalized execution outcome'
			})
		}

		if ((Test-GuiObjectField -Object $result -FieldName 'FailureCategory') -and -not [string]::IsNullOrWhiteSpace([string]$result.FailureCategory))
		{
			$failureCategory = [string]$result.FailureCategory
			$failureTone = switch -Regex ($failureCategory)
			{
				'^(Access denied|Reboot required|Missing dependency|Blocked by current system state|Network/download failure|Partial success|Manual intervention required|Unsupported OS/build)$' { 'Caution'; break }
				'^(Unsupported environment|Skipped by preset policy|Not supported by in-app restore)$' { 'Muted'; break }
				'^(Already in desired state|Not applicable|Not run)$' { 'Success'; break }
				default { 'Muted' }
			}
			[void]$chipItems.Add([pscustomobject]@{
				Label = $failureCategory
				Tone = $failureTone
				ToolTip = 'Failure category'
			})
		}

		if ([string]$result.Status -eq 'Failed' -and (Test-GuiObjectField -Object $result -FieldName 'RetryAvailability') -and -not [string]::IsNullOrWhiteSpace([string]$result.RetryAvailability))
		{
			[void]$chipItems.Add([pscustomobject]@{
				Label = [string]$result.RetryAvailability
				Tone = $(if ((Test-GuiObjectField -Object $result -FieldName 'IsRecoverable') -and [bool]$result.IsRecoverable) { 'Caution' } else { 'Danger' })
				ToolTip = 'Retry policy for this failure'
			})
		}

		if ((Test-GuiObjectField -Object $result -FieldName 'FailureCode') -and -not [string]::IsNullOrWhiteSpace([string]$result.FailureCode))
		{
			[void]$chipItems.Add([pscustomobject]@{
				Label = [string]$result.FailureCode
				Tone = 'Muted'
				ToolTip = 'Machine-readable failure code'
			})
		}

		if ((Test-GuiObjectField -Object $result -FieldName 'RequiresRestart') -and [bool]$result.RequiresRestart)
		{
			[void]$chipItems.Add([pscustomobject]@{
				Label = 'Restart required'
				Tone = 'Caution'
				ToolTip = 'This change requires a restart to take effect.'
			})
		}

		if ((Test-GuiObjectField -Object $result -FieldName 'TroubleshootingOnly') -and [bool]$result.TroubleshootingOnly)
		{
			[void]$chipItems.Add([pscustomobject]@{
				Label = 'Troubleshooting only'
				Tone = 'Caution'
				ToolTip = 'Use this only when diagnosing game compatibility, overlay, or display issues.'
			})
		}

		if ((Test-GuiObjectField -Object $result -FieldName 'Restorable') -and $null -ne $result.Restorable -and -not [bool]$result.Restorable)
		{
			[void]$chipItems.Add([pscustomobject]@{
				Label = 'Manual recovery'
				Tone = 'Danger'
				ToolTip = 'This change cannot be fully rolled back automatically.'
			})
		}

		if ((Test-GuiObjectField -Object $result -FieldName 'RecoveryLevel') -and -not [string]::IsNullOrWhiteSpace([string]$result.RecoveryLevel))
		{
			$recoveryLevelLabel = [string]$result.RecoveryLevel
			$recoveryTone = switch ($recoveryLevelLabel)
			{
				'Direct' { 'Success'; break }
				'DefaultsOnly' { 'Primary'; break }
				'RestorePoint' { 'Caution'; break }
				'Manual' { 'Danger'; break }
				default { 'Muted' }
			}
				[void]$chipItems.Add([pscustomobject]@{
					Label = "Recovery: $recoveryLevelLabel"
					Tone = $recoveryTone
					ToolTip = 'Recommended recovery path for this tweak.'
				})
		}

		$scenarioTags = @()
		if ((Test-GuiObjectField -Object $result -FieldName 'ScenarioTags') -and $result.ScenarioTags)
		{
			$scenarioTags = @($result.ScenarioTags)
		}
		elseif ((Test-GuiObjectField -Object $result -FieldName 'Tags') -and $result.Tags)
		{
			$scenarioTags = @($result.Tags)
		}
		if ($scenarioTags.Count -gt 0)
		{
			foreach ($scenarioTag in @($scenarioTags | Select-Object -First 4))
			{
				if ([string]::IsNullOrWhiteSpace([string]$scenarioTag)) { continue }
				[void]$chipItems.Add([pscustomobject]@{
					Label = [string]$scenarioTag
					Tone = 'Muted'
					ToolTip = 'Scenario tag'
				})
			}
			if ($scenarioTags.Count -gt 4)
			{
				[void]$chipItems.Add([pscustomobject]@{
					Label = "+$($scenarioTags.Count - 4) more"
					Tone = 'Muted'
					ToolTip = 'Additional scenario tags are present in the manifest.'
				})
			}
		}

		if ($chipItems.Count -gt 0)
		{
			$chipRow = New-Object System.Windows.Controls.Border
			$chipRow.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
			$chipRow.Child = (New-DialogMetadataPillPanel -Theme $Theme -Items $chipItems)
			[void]($rowStack.Children.Add($chipRow))
		}

		# ── Expandable detail section (collapsed by default) ──
		$detailStack = New-Object System.Windows.Controls.StackPanel
		$detailStack.Orientation = 'Vertical'
		$detailStack.Visibility = [System.Windows.Visibility]::Collapsed

		# Expand/collapse hint text
		$expandDetailsText = if ($Strings.ContainsKey('ExpandDetails')) { [string]$Strings.ExpandDetails } else { 'Click to expand details' }
		$collapseDetailsText = if ($Strings.ContainsKey('CollapseDetails')) { [string]$Strings.CollapseDetails } else { 'Click to collapse' }
		$expandHint = New-Object System.Windows.Controls.TextBlock
		$expandHint.Text = [char]0x25BC + '  ' + $expandDetailsText
		$expandHint.FontSize = $Script:GuiLayout.FontSizeSmall
		$expandHint.Foreground = $preBrushTextMuted
		$expandHint.Margin = [System.Windows.Thickness]::new(0, 6, 0, 0)
		$expandHint.HorizontalAlignment = 'Left'

		# Check if there are any details worth expanding
		$hasExpandableContent = (
			(-not [string]::IsNullOrWhiteSpace([string]$result.ReasonIncluded)) -or
			(-not [string]::IsNullOrWhiteSpace([string]$result.OutcomeReason) -and (
				[string]$result.Status -in @('Failed', 'Skipped', 'Restart pending', 'Not Run', 'Not applicable') -or
				((Test-GuiObjectField -Object $result -FieldName 'OutcomeState') -and [string]$result.OutcomeState -in @('Already in desired state', 'Already at Windows default', 'Not applicable on this system', 'Skipped by preset or selection', 'Not supported by in-app restore', 'Failed and recoverable', 'Failed and manual intervention required'))
			)) -or
			(-not [string]::IsNullOrWhiteSpace([string]$result.Detail)) -or
			((Test-GuiObjectField -Object $result -FieldName 'RecoveryHint') -and -not [string]::IsNullOrWhiteSpace([string]$result.RecoveryHint)) -or
			((Test-GuiObjectField -Object $result -FieldName 'RetryReason') -and -not [string]::IsNullOrWhiteSpace([string]$result.RetryReason)) -or
			(-not [string]::IsNullOrWhiteSpace([string]$result.BlastRadius))
		)

		if ($hasExpandableContent)
		{
			[void]($rowStack.Children.Add($expandHint))

			# Wire click-to-expand on the card border
			$capturedDetailStack = $detailStack
			$capturedExpandHint = $expandHint
			$rowBorder.Add_MouseLeftButtonUp({
				if ($capturedDetailStack.Visibility -eq [System.Windows.Visibility]::Collapsed)
				{
					$capturedDetailStack.Visibility = [System.Windows.Visibility]::Visible
					$capturedExpandHint.Text = [string]([char]0x25B2) + '  ' + $collapseDetailsText
				}
				else
				{
					$capturedDetailStack.Visibility = [System.Windows.Visibility]::Collapsed
					$capturedExpandHint.Text = [string]([char]0x25BC) + '  ' + $expandDetailsText
				}
			}.GetNewClosure())
		}

		# All detail content goes into $detailStack instead of $rowStack
		if (-not [string]::IsNullOrWhiteSpace([string]$result.ReasonIncluded))
		{
			$reasonSeparator = New-Object System.Windows.Controls.Separator
			$reasonSeparator.Margin = [System.Windows.Thickness]::new(0, 8, 0, 8)
			[void]($detailStack.Children.Add($reasonSeparator))
			$reasonHeader = New-Object System.Windows.Controls.TextBlock
			$reasonHeader.Text = (& $L 'GuiCommonWhyIncluded' 'WHY INCLUDED')
			$reasonHeader.FontSize = $Script:GuiLayout.FontSizeSmall
			$reasonHeader.FontWeight = [System.Windows.FontWeights]::Bold
			$reasonHeader.Foreground = $preBrushSectionLabel
			[void]($detailStack.Children.Add($reasonHeader))
			$reasonBlock = New-Object System.Windows.Controls.TextBlock
			$reasonBlock.Text = [string]$result.ReasonIncluded
			$reasonBlock.TextWrapping = 'Wrap'
			$reasonBlock.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)
			$reasonBlock.FontSize = $Script:GuiLayout.FontSizeLabel
			$reasonBlock.Foreground = $preBrushTextSecondary
			[void]($detailStack.Children.Add($reasonBlock))
		}

		$outcomeReasonStatus = if ((Test-GuiObjectField -Object $result -FieldName 'Status')) { [string]$result.Status } else { '' }
		$outcomeReasonState = if ((Test-GuiObjectField -Object $result -FieldName 'OutcomeState')) { [string]$result.OutcomeState } else { '' }
		$showOutcomeReason = (
			$outcomeReasonStatus -in @('Failed', 'Skipped', 'Restart pending', 'Not Run', 'Not applicable') -or
			$outcomeReasonState -in @('Already in desired state', 'Already at Windows default', 'Not applicable on this system', 'Skipped by preset or selection', 'Not supported by in-app restore', 'Failed and recoverable', 'Failed and manual intervention required')
		)

		if ($showOutcomeReason -and (Test-GuiObjectField -Object $result -FieldName 'OutcomeReason') -and -not [string]::IsNullOrWhiteSpace([string]$result.OutcomeReason))
		{
			$outcomeReasonSeparator = New-Object System.Windows.Controls.Separator
			$outcomeReasonSeparator.Margin = [System.Windows.Thickness]::new(0, 8, 0, 8)
			[void]($detailStack.Children.Add($outcomeReasonSeparator))
			$outcomeReasonHeader = New-Object System.Windows.Controls.TextBlock
			$outcomeReasonHeader.Text = (& $L 'GuiCommonWhyThisHappened' 'WHY THIS HAPPENED')
			$outcomeReasonHeader.FontSize = $Script:GuiLayout.FontSizeSmall
			$outcomeReasonHeader.FontWeight = [System.Windows.FontWeights]::Bold
			$outcomeReasonHeader.Foreground = $preBrushSectionLabel
			[void]($detailStack.Children.Add($outcomeReasonHeader))
			$outcomeReasonBlock = New-Object System.Windows.Controls.TextBlock
			$outcomeReasonBlock.Text = [string]$result.OutcomeReason
			$outcomeReasonBlock.TextWrapping = 'Wrap'
			$outcomeReasonBlock.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)
			$outcomeReasonBlock.FontSize = $Script:GuiLayout.FontSizeLabel
			$outcomeReasonBlock.Foreground = $(if ($result.Status -eq 'Failed' -or $result.Status -eq 'Not Run') { $preBrushTextPrimary } else { $preBrushTextSecondary })
			[void]($detailStack.Children.Add($outcomeReasonBlock))
		}

		if ([string]$result.Status -eq 'Failed' -and (Test-GuiObjectField -Object $result -FieldName 'RetryReason') -and -not [string]::IsNullOrWhiteSpace([string]$result.RetryReason))
		{
			$retrySeparator = New-Object System.Windows.Controls.Separator
			$retrySeparator.Margin = [System.Windows.Thickness]::new(0, 8, 0, 8)
			[void]($detailStack.Children.Add($retrySeparator))
			$retryHeader = New-Object System.Windows.Controls.TextBlock
			$retryHeader.Text = (& $L 'GuiCommonRetryPolicy' 'RETRY POLICY')
			$retryHeader.FontSize = $Script:GuiLayout.FontSizeSmall
			$retryHeader.FontWeight = [System.Windows.FontWeights]::Bold
			$retryHeader.Foreground = $preBrushSectionLabel
			[void]($detailStack.Children.Add($retryHeader))
			$retryBlock = New-Object System.Windows.Controls.TextBlock
			$retryBlock.Text = [string]$result.RetryReason
			$retryBlock.TextWrapping = 'Wrap'
			$retryBlock.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)
			$retryBlock.FontSize = $Script:GuiLayout.FontSizeLabel
			$retryBlock.Foreground = $(if ((Test-GuiObjectField -Object $result -FieldName 'IsRecoverable') -and [bool]$result.IsRecoverable) { $preBrushCautionText } else { $preBrushTextSecondary })
			[void]($detailStack.Children.Add($retryBlock))
		}

		if ((Test-GuiObjectField -Object $result -FieldName 'RecoveryHint') -and -not [string]::IsNullOrWhiteSpace([string]$result.RecoveryHint))
		{
			$hintSeparator = New-Object System.Windows.Controls.Separator
			$hintSeparator.Margin = [System.Windows.Thickness]::new(0, 8, 0, 8)
			[void]($detailStack.Children.Add($hintSeparator))
			$hintHeader = New-Object System.Windows.Controls.TextBlock
			$hintHeader.Text = (& $L 'GuiCommonRecoveryHint' 'RECOVERY HINT')
			$hintHeader.FontSize = $Script:GuiLayout.FontSizeSmall
			$hintHeader.FontWeight = [System.Windows.FontWeights]::Bold
			$hintHeader.Foreground = $preBrushSectionLabel
			[void]($detailStack.Children.Add($hintHeader))
			$hintBlock = New-Object System.Windows.Controls.TextBlock
			$hintBlock.Text = [string]$result.RecoveryHint
			$hintBlock.TextWrapping = 'Wrap'
			$hintBlock.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)
			$hintBlock.FontSize = $Script:GuiLayout.FontSizeLabel
			$hintBlock.Foreground = $(if ((Test-GuiObjectField -Object $result -FieldName 'IsRecoverable') -and [bool]$result.IsRecoverable) { $preBrushCautionText } else { $preBrushTextSecondary })
			[void]($detailStack.Children.Add($hintBlock))
		}

		if (-not [string]::IsNullOrWhiteSpace([string]$result.BlastRadius))
		{
			$blastBlock = New-Object System.Windows.Controls.TextBlock
			$blastBlock.Text = [string]$result.BlastRadius
			$blastBlock.TextWrapping = 'Wrap'
			$blastBlock.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
			$blastBlock.FontSize = $Script:GuiLayout.FontSizeLabel
			$blastBlock.Foreground = $preBrushTextSecondary
			[void]($detailStack.Children.Add($blastBlock))
		}

		if (-not [string]::IsNullOrWhiteSpace([string]$result.Detail))
		{
			$detailBlock = New-Object System.Windows.Controls.TextBlock
			$detailBlock.Text = [string]$result.Detail
			$detailBlock.TextWrapping = 'Wrap'
			$detailBlock.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
			$detailBlock.FontSize = $Script:GuiLayout.FontSizeLabel
			$detailBlock.Foreground = $(if ($result.Status -eq 'Failed' -or $result.Status -eq 'Not Run') { $preBrushCautionText } else { $preBrushTextSecondary })
			[void]($detailStack.Children.Add($detailBlock))
		}

		# Add the collapsible detail panel to the card
		if ($hasExpandableContent)
		{
			[void]($rowStack.Children.Add($detailStack))
		}

		$rowBorder.Child = $rowStack
		[void]($listStack.Children.Add($rowBorder))

		# Track card for status filter bar
		[void]$allResultCards.Add($rowBorder)
		[void]$allResultStatusMap.Add($cardStatusCategory)

		$resultIndex++

		# After the initial batch, stop building cards and insert a
		# "Show all" button so the dialog opens fast for large result sets.
		if ($resultIndex -eq $initialBatchLimit -and $totalResultCount -gt $initialBatchLimit)
		{
			break
		}
	}

	# If we cut the loop short, add a "Show all" button that loads the rest.
	if ($resultIndex -eq $initialBatchLimit -and $totalResultCount -gt $initialBatchLimit)
	{
		$remainingCount = $totalResultCount - $initialBatchLimit
		$remainingResults = @($displayResults | Select-Object -Skip $initialBatchLimit)
		$showAllBtn = New-Object System.Windows.Controls.Button
		$showAllResultsFormat = if ($Strings.ContainsKey('ShowAllResultsFormat')) { [string]$Strings.ShowAllResultsFormat } else { 'Show all {0} results ({1} more)' }
		$showAllBtn.Content = ($showAllResultsFormat -f $totalResultCount, $remainingCount)
		$showAllBtn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Stretch
		$showAllBtn.Margin = [System.Windows.Thickness]::new(0, 4, 0, 10)
		$showAllBtn.Padding = [System.Windows.Thickness]::new(12, 10, 12, 10)
		$showAllBtn.FontSize = $Script:GuiLayout.FontSizeBody
		$showAllBtn.Cursor = [System.Windows.Input.Cursors]::Hand
		& $ApplyButtonChrome -Button $showAllBtn -Variant 'Subtle'

		# Capture all the pre-computed brush/layout variables for the deferred build.
		$capturedListStack = $listStack
		$capturedBc = $bc
		$capturedTheme = $Theme
		$capturedIsPreviewMode = $isPreviewMode
		$capturedHasPreviewGroups = $hasPreviewGroups
		$capturedLastPreviewSection = $lastPreviewSection
		$capturedPreStatusBrushes = $preStatusBrushes
		$capturedPreDefaultStatusBrushes = $preDefaultStatusBrushes
		$capturedPreThickness1 = $preThickness1
		$capturedPreBrushCardBg = $preBrushCardBg
		$capturedPreBrushCardBorder = $preBrushCardBorder
		$capturedPreBrushTextPrimary = $preBrushTextPrimary
		$capturedPreBrushTextSecondary = $preBrushTextSecondary
		$capturedPreBrushTextMuted = $preBrushTextMuted
		$capturedPreBrushSectionLabel = $preBrushSectionLabel
		$capturedPreBrushCautionText = $preBrushCautionText

		$showAllBtn.Add_Click({
			$showAllBtn.Visibility = [System.Windows.Visibility]::Collapsed

			# Alias captured variables for the same names used in the card-building code.
			$bc = $capturedBc
			$Theme = $capturedTheme
			$isPreviewMode = $capturedIsPreviewMode
			$hasPreviewGroups = $capturedHasPreviewGroups
			$lastPreviewSection = $capturedLastPreviewSection
			$preStatusBrushes = $capturedPreStatusBrushes
			$preDefaultStatusBrushes = $capturedPreDefaultStatusBrushes
			$preThickness1 = $capturedPreThickness1
			$preBrushCardBg = $capturedPreBrushCardBg
			$preBrushCardBorder = $capturedPreBrushCardBorder
			$preBrushTextPrimary = $capturedPreBrushTextPrimary
			$preBrushTextSecondary = $capturedPreBrushTextSecondary
			$preBrushTextMuted = $capturedPreBrushTextMuted
			$preBrushSectionLabel = $capturedPreBrushSectionLabel
			$preBrushCautionText = $capturedPreBrushCautionText

			try { $capturedListStack.BeginInit() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ExecutionSummaryDialog.Show-ExecutionSummaryDialog.CapturedListStackBeginInit' }
			foreach ($result in $remainingResults)
			{
				if ($isPreviewMode)
				{
					$sectionLabel = if ($hasPreviewGroups -and (Test-GuiObjectField -Object $result -FieldName 'PreviewGroupHeader') -and -not [string]::IsNullOrWhiteSpace([string]$result.PreviewGroupHeader)) {
						[string]$result.PreviewGroupHeader
					}
					elseif ([string]::IsNullOrWhiteSpace([string]$result.Status)) {
						'Will change'
					}
					else {
						[string]$result.Status
					}
					if ($sectionLabel -ne $lastPreviewSection)
					{
						$sectionHeader = New-Object System.Windows.Controls.TextBlock
						$sectionHeader.Text = $sectionLabel.ToUpperInvariant()
						$sectionHeader.FontSize = $Script:GuiLayout.FontSizeLabel
						$sectionHeader.FontWeight = [System.Windows.FontWeights]::Bold
						$sectionHeader.Foreground = $preBrushSectionLabel
						$sectionHeader.Margin = [System.Windows.Thickness]::new(0, 8, 0, 8)
						[void]($capturedListStack.Children.Add($sectionHeader))
						$lastPreviewSection = $sectionLabel
					}
				}

				$rowBorder = New-Object System.Windows.Controls.Border
				$rowBorder.Background = $preBrushCardBg
				$rowBorder.BorderBrush = $preBrushCardBorder
				$rowBorder.BorderThickness = $preThickness1
				$rowBorder.CornerRadius = [System.Windows.CornerRadius]::new($Script:GuiLayout.CardCornerRadius)
				$rowBorder.Padding = [System.Windows.Thickness]::new(14, 12, 14, 12)
				$rowBorder.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)

				$rowStack = New-Object System.Windows.Controls.StackPanel
				$rowStack.Orientation = 'Vertical'

				$nameBlock = New-Object System.Windows.Controls.TextBlock
				$nameBlock.Text = [string]$result.Name
				$nameBlock.FontSize = 13
				$nameBlock.FontWeight = [System.Windows.FontWeights]::SemiBold
				$nameBlock.TextWrapping = 'Wrap'
				$nameBlock.Foreground = $preBrushTextPrimary
				[void]($rowStack.Children.Add($nameBlock))

				$statusKey = [string]$result.Status
				$statusBrushSet = if ($preStatusBrushes.ContainsKey($statusKey)) { $preStatusBrushes[$statusKey] } else { $preDefaultStatusBrushes }
				$statusText = New-Object System.Windows.Controls.TextBlock
				$statusText.Text = $statusKey
				$statusText.FontSize = $Script:GuiLayout.FontSizeLabel
				$statusText.Foreground = $statusBrushSet.Fg
				$statusText.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)
				[void]($rowStack.Children.Add($statusText))

				if (-not [string]::IsNullOrWhiteSpace([string]$result.Detail))
				{
					$detailBlock = New-Object System.Windows.Controls.TextBlock
					$detailBlock.Text = [string]$result.Detail
					$detailBlock.TextWrapping = 'Wrap'
					$detailBlock.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)
					$detailBlock.FontSize = $Script:GuiLayout.FontSizeLabel
					$detailBlock.Foreground = $preBrushTextSecondary
					[void]($rowStack.Children.Add($detailBlock))
				}

				$rowBorder.Child = $rowStack
				[void]($capturedListStack.Children.Add($rowBorder))
			}
			try { $capturedListStack.EndInit() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ExecutionSummaryDialog.Show-ExecutionSummaryDialog.CapturedListStackEndInit' }
		}.GetNewClosure())

		[void]($listStack.Children.Add($showAllBtn))
	}

	# ── Restart-required informational section ─────────────────────
	$restartPendingItems = @($results | Where-Object {
		[string]$_.Status -eq 'Restart pending' -or
		((Test-GuiObjectField -Object $_ -FieldName 'RequiresRestart') -and [bool]$_.RequiresRestart)
	})
	if ($restartPendingItems.Count -gt 0)
	{
		$restartSectionBorder = New-Object System.Windows.Controls.Border
		$restartSectionBorder.Background = $bc.ConvertFromString($Theme.RiskMediumBadgeBg)
		$restartSectionBorder.BorderBrush = $bc.ConvertFromString($Theme.RiskMediumBadge)
		$restartSectionBorder.BorderThickness = [System.Windows.Thickness]::new(1)
		$restartSectionBorder.CornerRadius = [System.Windows.CornerRadius]::new($Script:GuiLayout.CardCornerRadius)
		$restartSectionBorder.Padding = [System.Windows.Thickness]::new(14, 12, 14, 12)
		$restartSectionBorder.Margin = [System.Windows.Thickness]::new(0, 6, 0, 10)

		$restartSectionStack = New-Object System.Windows.Controls.StackPanel
		$restartSectionStack.Orientation = 'Vertical'

		$restartTitle = New-Object System.Windows.Controls.TextBlock
		$restartTitle.Text = (& $L 'GuiCommonRestartRequired' 'These changes need a restart to take effect:')
		$restartTitle.FontSize = $Script:GuiLayout.FontSizeBody
		$restartTitle.FontWeight = [System.Windows.FontWeights]::SemiBold
		$restartTitle.Foreground = $bc.ConvertFromString($Theme.RiskMediumBadge)
		$restartTitle.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
		[void]($restartSectionStack.Children.Add($restartTitle))

		foreach ($restartItem in $restartPendingItems)
		{
			$restartItemBlock = New-Object System.Windows.Controls.TextBlock
			$restartItemBlock.Text = [string]([char]0x2022) + '  ' + [string]$restartItem.Name
			$restartItemBlock.TextWrapping = 'Wrap'
			$restartItemBlock.FontSize = $Script:GuiLayout.FontSizeLabel
			$restartItemBlock.Foreground = $bc.ConvertFromString($Theme.RiskMediumBadge)
			$restartItemBlock.Margin = [System.Windows.Thickness]::new(4, 2, 0, 2)
			[void]($restartSectionStack.Children.Add($restartItemBlock))
		}

		$restartSectionBorder.Child = $restartSectionStack
		[void]($listStack.Children.Add($restartSectionBorder))
	}
	# ── End restart-required section ───────────────────────────────

	if ($results.Count -eq 0)
	{
		$emptyBlock = New-Object System.Windows.Controls.TextBlock
		$emptyBlock.Text = (& $L 'GuiCommonNoExecutionResults' 'No execution results are available for this run.')
		$emptyBlock.TextWrapping = 'Wrap'
		$emptyBlock.Foreground = $bc.ConvertFromString($Theme.TextSecondary)
		[void]($listStack.Children.Add($emptyBlock))
	}

	try { $listStack.EndInit() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'ExecutionSummaryDialog.Show-ExecutionSummaryDialog.ListStackEndInit' }
	$listScroll.Content = $listStack
	[void]($outerGrid.Children.Add($listScroll))
	$buttonBorder = New-Object System.Windows.Controls.Border
	$buttonBorder.Background = $bc.ConvertFromString($Theme.PanelBg)
	$buttonBorder.BorderBrush = $bc.ConvertFromString($Theme.BorderColor)
	$buttonBorder.BorderThickness = [System.Windows.Thickness]::new(0, 1, 0, 0)
	$buttonBorder.Padding = [System.Windows.Thickness]::new(16, 12, 16, 12)
	[System.Windows.Controls.Grid]::SetRow($buttonBorder, 2)

	$buttonPanel = New-Object System.Windows.Controls.WrapPanel
	$buttonPanel.Orientation = 'Horizontal'
	$buttonPanel.HorizontalAlignment = 'Right'

	$resultRef = @{
		Value = $(if ($Buttons -contains 'Close') { 'Close' } elseif ($Buttons.Count -gt 0) { $Buttons[0] } else { $null })
	}

	foreach ($label in $Buttons)
	{
		$btn = New-Object System.Windows.Controls.Button
		$btn.Content = $label
		$btn.MinWidth = $Script:GuiLayout.ButtonMinWidth
		$btn.Height = $Script:GuiLayout.ButtonHeight
		$btn.Margin = [System.Windows.Thickness]::new(6, 4, 0, 4)
		$btn.FontWeight = [System.Windows.FontWeights]::SemiBold
		$btn.Padding = [System.Windows.Thickness]::new(16, 7, 16, 7)

		if ($label -eq 'Exit')
		{
			& $ApplyButtonChrome -Button $btn -Variant 'Danger'
		}
		elseif ($label -eq 'Close')
		{
			& $ApplyButtonChrome -Button $btn -Variant 'Primary'
		}
		else
		{
			& $ApplyButtonChrome -Button $btn -Variant 'Secondary'
		}
		if ($Buttons.Count -eq 1)
		{
			$btn.IsDefault = $true
		}
		if ($label -eq 'Close')
		{
			$btn.IsCancel = $true
		}

		$btnLabel = $label
		$dlgRef = $dlg
		$resRef = $resultRef
		$btn.Add_Click({
			$resRef.Value = $btnLabel
			$dlgRef.Close()
		}.GetNewClosure())
		[void]($buttonPanel.Children.Add($btn))
	}

	$buttonBorder.Child = $buttonPanel
	[void]($outerGrid.Children.Add($buttonBorder))
	[void]($dlgDock.Children.Add($outerGrid))
	$dlgRoundBorder.Child = $dlgDock
	$dlg.Content = $dlgRoundBorder

	[void]($dlg.ShowDialog())
	return $resultRef.Value
}
