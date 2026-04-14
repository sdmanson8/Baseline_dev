# Compliance Dashboard: drift detection view accessible from the GUI.
# Provides a dialog to select a profile/snapshot, run compliance checks,
# view results, and optionally fix drifted entries via a GUI execution run.

<#
    .SYNOPSIS
    Internal function Show-ComplianceDialog.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Show-ComplianceDialog
{
	$bc = $Script:SharedBrushConverter
	$theme = $Script:CurrentTheme
	$layout = $Script:GuiLayout

	$dlg = New-Object System.Windows.Window
	$dlg.Title = (Get-UxLocalizedString -Key 'GuiComplianceTitle' -Fallback 'Check Compliance')
	$dlg.Width = $layout.DialogLargeWidth
	$dlg.Height = $layout.DialogLargeHeight
	$dlg.MinWidth = $layout.DialogLargeMinWidth
	$dlg.MinHeight = $layout.DialogLargeMinHeight
	$dlg.ResizeMode = 'CanResize'
	$dlg.WindowStartupLocation = 'CenterOwner'
	$dlg.Foreground = $bc.ConvertFromString($theme.TextPrimary)
	$dlg.FontFamily = [System.Windows.Media.FontFamily]::new('FluentSystemIcons')
	$dlg.FontSize = $layout.FontSizeBody
	$dlg.ShowInTaskbar = $false

	try { if ($Form) { $dlg.Owner = $Form } } catch { }
	$roundedParts = ConvertTo-RoundedWindow -Window $dlg -Theme $theme
	[void](Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode:($Script:CurrentThemeName -eq 'Dark'))

	$rootPanel = New-Object System.Windows.Controls.DockPanel
	$rootPanel.LastChildFill = $true
	$rootPanel.Margin = [System.Windows.Thickness]::new(16)

	# --- Top: file picker + check button ---
	$topPanel = New-Object System.Windows.Controls.StackPanel
	$topPanel.Orientation = 'Vertical'
	$topPanel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
	[System.Windows.Controls.DockPanel]::SetDock($topPanel, [System.Windows.Controls.Dock]::Top)

	$fileRow = New-Object System.Windows.Controls.DockPanel
	$fileRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)

	$btnBrowse = New-Object System.Windows.Controls.Button
	$btnBrowse.Content = (Get-UxLocalizedString -Key 'GuiComplianceBrowse' -Fallback 'Browse...')
	$btnBrowse.MinWidth = 90
	$btnBrowse.Height = $layout.ButtonHeight
	$btnBrowse.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
	$btnBrowse.FontWeight = [System.Windows.FontWeights]::SemiBold
	Set-ButtonChrome -Button $btnBrowse -Variant 'Secondary'
	[System.Windows.Controls.DockPanel]::SetDock($btnBrowse, [System.Windows.Controls.Dock]::Right)

	$txtFilePath = New-Object System.Windows.Controls.TextBox
	$txtFilePath.IsReadOnly = $true
	$txtFilePath.Height = $layout.ButtonHeight
	$txtFilePath.VerticalContentAlignment = 'Center'
	$txtFilePath.Padding = [System.Windows.Thickness]::new(8, 0, 8, 0)
	$txtFilePath.Background = $bc.ConvertFromString($theme.PanelBg)
	$txtFilePath.Foreground = $bc.ConvertFromString($theme.TextPrimary)
	$txtFilePath.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
	$txtFilePath.Text = (Get-UxLocalizedString -Key 'GuiComplianceFilePlaceholder' -Fallback '(Select a configuration profile or snapshot...)')

	[void]$fileRow.Children.Add($btnBrowse)
	[void]$fileRow.Children.Add($txtFilePath)
	[void]$topPanel.Children.Add($fileRow)

	$actionRow = New-Object System.Windows.Controls.StackPanel
	$actionRow.Orientation = 'Horizontal'
	$actionRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)

	$btnCheck = New-Object System.Windows.Controls.Button
	$btnCheck.Content = (Get-UxLocalizedString -Key 'GuiComplianceCheckButton' -Fallback 'Check Compliance')
	$btnCheck.MinWidth = $layout.ButtonMinWidth
	$btnCheck.Height = $layout.ButtonHeight
	$btnCheck.FontWeight = [System.Windows.FontWeights]::SemiBold
	$btnCheck.IsEnabled = $false
	Set-ButtonChrome -Button $btnCheck -Variant 'Primary'

	$btnFixDrift = New-Object System.Windows.Controls.Button
	$btnFixDrift.Content = (Get-UxLocalizedString -Key 'GuiComplianceFixDrift' -Fallback 'Fix Drift')
	$btnFixDrift.MinWidth = $layout.ButtonMinWidth
	$btnFixDrift.Height = $layout.ButtonHeight
	$btnFixDrift.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
	$btnFixDrift.FontWeight = [System.Windows.FontWeights]::SemiBold
	$btnFixDrift.IsEnabled = $false
	Set-ButtonChrome -Button $btnFixDrift -Variant 'Danger'

	[void]$actionRow.Children.Add($btnCheck)
	[void]$actionRow.Children.Add($btnFixDrift)
	[void]$topPanel.Children.Add($actionRow)

	# --- Summary label ---
	$summaryLabel = New-Object System.Windows.Controls.TextBlock
	$summaryLabel.Text = ''
	$summaryLabel.FontSize = $layout.FontSizeSection
	$summaryLabel.FontWeight = [System.Windows.FontWeights]::SemiBold
	$summaryLabel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)
	$summaryLabel.Foreground = $bc.ConvertFromString($theme.TextPrimary)
	[void]$topPanel.Children.Add($summaryLabel)

	[void]$rootPanel.Children.Add($topPanel)

	# --- Bottom: close button ---
	$bottomPanel = New-Object System.Windows.Controls.StackPanel
	$bottomPanel.Orientation = 'Horizontal'
	$bottomPanel.HorizontalAlignment = 'Right'
	$bottomPanel.Margin = [System.Windows.Thickness]::new(0, 12, 0, 0)
	[System.Windows.Controls.DockPanel]::SetDock($bottomPanel, [System.Windows.Controls.Dock]::Bottom)

	$btnClose = New-Object System.Windows.Controls.Button
	$btnClose.Content = (Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close')
	$btnClose.MinWidth = $layout.ButtonMinWidth
	$btnClose.Height = $layout.ButtonHeight
	$btnClose.FontWeight = [System.Windows.FontWeights]::SemiBold
	$btnClose.IsCancel = $true
	Set-ButtonChrome -Button $btnClose -Variant 'Secondary'
	$btnClose.Add_Click({ $dlg.Close() })

	[void]$bottomPanel.Children.Add($btnClose)
	[void]$rootPanel.Children.Add($bottomPanel)

	# --- Center: scrollable results list ---
	$scrollViewer = New-Object System.Windows.Controls.ScrollViewer
	$scrollViewer.VerticalScrollBarVisibility = 'Auto'
	$scrollViewer.HorizontalScrollBarVisibility = 'Disabled'

	$resultsList = New-Object System.Windows.Controls.StackPanel
	$resultsList.Orientation = 'Vertical'
	$scrollViewer.Content = $resultsList

	[void]$rootPanel.Children.Add($scrollViewer)

	Complete-RoundedWindow -Window $dlg -ContentElement $rootPanel -RoundBorder $roundedParts.RoundBorder -DockPanel $roundedParts.DockPanel

	# --- Localization capture for closures ---
	$getLocalizedString = ${function:Get-UxLocalizedString}

	# --- Shared state ---
	$complianceState = @{
		FilePath         = $null
		Report           = $null
		ProfileData      = $null
	}

	# --- Browse handler ---
	$btnBrowse.Add_Click({
		$openDialog = New-Object Microsoft.Win32.OpenFileDialog
		$openDialog.Title = (& $getLocalizedString -Key 'GuiComplianceBrowseTitle' -Fallback 'Select Configuration Profile or Snapshot')
		$openDialog.Filter = 'JSON Files (*.json)|*.json|All Files (*.*)|*.*'
		$openDialog.DefaultExt = 'json'

		$dlgOwner = if ($Script:MainForm) { $Script:MainForm } else { $null }
		if ($openDialog.ShowDialog($dlgOwner) -eq $true)
		{
			$complianceState.FilePath = $openDialog.FileName
			$txtFilePath.Text = $openDialog.FileName
			$btnCheck.IsEnabled = $true
			$summaryLabel.Text = ''
			$resultsList.Children.Clear()
			$btnFixDrift.IsEnabled = $false
			$complianceState.Report = $null
		}
	}.GetNewClosure())

	# --- Check Compliance handler ---
	$btnCheck.Add_Click({
		$filePath = $complianceState.FilePath
		if ([string]::IsNullOrWhiteSpace($filePath) -or -not (Test-Path -LiteralPath $filePath -ErrorAction SilentlyContinue))
		{
			Show-ThemedDialog -Title (& $getLocalizedString -Key 'GuiComplianceTitle' -Fallback 'Check Compliance') -Message (& $getLocalizedString -Key 'GuiComplianceSelectValid' -Fallback 'Please select a valid profile or snapshot file.') -Buttons @('OK') -AccentButton 'OK'
			return
		}

		$resultsList.Children.Clear()
		$summaryLabel.Text = (& $getLocalizedString -Key 'GuiComplianceChecking' -Fallback 'Checking compliance...')
		# Flush dispatcher so 'Checking compliance...' renders before the blocking work.
		# Uses direct dispatcher call because .GetNewClosure() doesn't capture functions.
		try { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Render) } catch { }

		try
		{
			$raw = Get-Content -LiteralPath $filePath -Raw -Encoding UTF8 -ErrorAction Stop
			$profileData = $raw | ConvertFrom-Json -ErrorAction Stop
			$complianceState.ProfileData = $profileData
		}
		catch
		{
			$summaryLabel.Text = (& $getLocalizedString -Key 'GuiComplianceLoadFailed' -Fallback 'Failed to load profile.')
			Show-ThemedDialog -Title (& $getLocalizedString -Key 'GuiComplianceTitle' -Fallback 'Check Compliance') -Message ((& $getLocalizedString -Key 'GuiComplianceLoadFailedDetail' -Fallback "Failed to read profile file.`n`n{0}") -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK'
			return
		}

		$remoteContext = $null
		try
		{
			$remoteContext = Get-GuiRemoteTargetContext
		}
		catch
		{
			$remoteContext = $null
		}

		if ($remoteContext -and $remoteContext.Connected -and $remoteContext.TargetComputers.Count -gt 0 -and $profileData.PSObject.Properties['Schema'] -and [string]$profileData.Schema -eq 'Baseline.ConfigProfile')
		{
			try
			{
				$remoteResults = @(Invoke-BaselineRemoteCompliance -ComputerName @($remoteContext.TargetComputers) -ProfilePath $filePath -Credential $remoteContext.Credential)
				$syntheticEntries = [System.Collections.Generic.List[object]]::new()
				$compliantCount = 0
				$driftedCount = 0
				foreach ($remoteResult in @($remoteResults))
				{
					if (-not $remoteResult) { continue }

					$remoteErrors = @()
					if ($remoteResult.PSObject.Properties['Errors'] -and $remoteResult.Errors)
					{
						$remoteErrors = @($remoteResult.Errors | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
					}

					$isCompliant = ($remoteResult.Compliant -eq $true) -and ($remoteErrors.Count -eq 0)
					if ($isCompliant)
					{
						$compliantCount++
					}
					else
					{
						$driftedCount++
					}

					[void]$syntheticEntries.Add([pscustomobject]@{
						Name         = [string]$remoteResult.ComputerName
						Status       = if ($isCompliant) { 'Compliant' } else { 'Drifted' }
						Detail       = if ($remoteErrors.Count -gt 0) { $remoteErrors -join '; ' } else { ('DriftedCount={0} | TotalChecked={1}' -f ([int]$remoteResult.DriftedCount), ([int]$remoteResult.TotalChecked)) }
						TotalChecked = [int]$remoteResult.TotalChecked
						DriftedCount = [int]$remoteResult.DriftedCount
						Errors       = @($remoteErrors)
					})
				}

				$report = [pscustomobject]@{
					Compliant = $compliantCount
					Drifted   = $driftedCount
					Unknown   = 0
					Entries   = @($syntheticEntries)
				}
				$complianceState.Report = $report
				$summaryLabel.Text = ((& $getLocalizedString -Key 'GuiComplianceSummaryFormat' -Fallback 'Compliant: {0} | Drifted: {1} | Unknown: {2}') -f $report.Compliant, $report.Drifted, $report.Unknown)
				$btnFixDrift.IsEnabled = $false
				$resultsList.Children.Clear()
				foreach ($entry in @($report.Entries))
				{
					if (-not $entry) { continue }

					$card = New-Object System.Windows.Controls.Border
					$card.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
					$card.Padding = [System.Windows.Thickness]::new(10, 6, 10, 6)
					$card.CornerRadius = [System.Windows.CornerRadius]::new($layout.BorderRadiusSmall)
					$card.BorderThickness = [System.Windows.Thickness]::new(1)
					$card.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
					$card.Background = $bc.ConvertFromString($theme.PanelBg)

					$stack = New-Object System.Windows.Controls.StackPanel
					$stack.Orientation = 'Vertical'

					$title = New-Object System.Windows.Controls.TextBlock
					$title.Text = [string]$entry.Name
					$title.FontWeight = [System.Windows.FontWeights]::SemiBold
					$title.Foreground = $bc.ConvertFromString($theme.TextPrimary)
					[void]$stack.Children.Add($title)

					$detail = New-Object System.Windows.Controls.TextBlock
					$detail.Text = ("Status: {0} | {1}" -f [string]$entry.Status, [string]$entry.Detail)
					$detail.TextWrapping = 'Wrap'
					$detail.Foreground = $bc.ConvertFromString($theme.TextSecondary)
					[void]$stack.Children.Add($detail)

					$card.Child = $stack
					[void]$resultsList.Children.Add($card)
				}

				$summaryLabel.Text = ("Remote compliance: Compliant targets {0} | Drifted targets {1}" -f $compliantCount, $driftedCount)
				return
			}
			catch
			{
				$summaryLabel.Text = (& $getLocalizedString -Key 'GuiComplianceCheckFailed' -Fallback 'Compliance check failed.')
				Show-ThemedDialog -Title (& $getLocalizedString -Key 'GuiComplianceTitle' -Fallback 'Check Compliance') -Message ((& $getLocalizedString -Key 'GuiComplianceCheckFailedDetail' -Fallback "Compliance check failed.`n`n{0}") -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK'
				return
			}
		}

		try
		{
			$report = Test-SystemCompliance -Profile $profileData -Manifest $Script:TweakManifest
			$complianceState.Report = $report
		}
		catch
		{
			$summaryLabel.Text = (& $getLocalizedString -Key 'GuiComplianceCheckFailed' -Fallback 'Compliance check failed.')
			Show-ThemedDialog -Title (& $getLocalizedString -Key 'GuiComplianceTitle' -Fallback 'Check Compliance') -Message ((& $getLocalizedString -Key 'GuiComplianceCheckFailedDetail' -Fallback "Compliance check failed.`n`n{0}") -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK'
			return
		}

		# Update summary
		$summaryLabel.Text = ((& $getLocalizedString -Key 'GuiComplianceSummaryFormat' -Fallback 'Compliant: {0} | Drifted: {1} | Unknown: {2}') -f $report.Compliant, $report.Drifted, $report.Unknown)

		# Enable Fix Drift only if drifted items exist
		$btnFixDrift.IsEnabled = ($report.Drifted -gt 0)

		# Populate results list
		$resultsList.Children.Clear()
		foreach ($entry in @($report.Entries))
		{
			if (-not $entry) { continue }

			$card = New-Object System.Windows.Controls.Border
			$card.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
			$card.Padding = [System.Windows.Thickness]::new(10, 6, 10, 6)
			$card.CornerRadius = [System.Windows.CornerRadius]::new($layout.BorderRadiusSmall)
			$card.BorderThickness = [System.Windows.Thickness]::new(1)
			$card.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
			$card.Background = $bc.ConvertFromString($theme.PanelBg)

			$cardGrid = New-Object System.Windows.Controls.Grid
			$col1 = New-Object System.Windows.Controls.ColumnDefinition
			$col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
			$col2 = New-Object System.Windows.Controls.ColumnDefinition
			$col2.Width = [System.Windows.GridLength]::new(100)
			$col3 = New-Object System.Windows.Controls.ColumnDefinition
			$col3.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
			[void]$cardGrid.ColumnDefinitions.Add($col1)
			[void]$cardGrid.ColumnDefinitions.Add($col2)
			[void]$cardGrid.ColumnDefinitions.Add($col3)

			$statusColor = switch ([string]$entry.Status)
			{
				'Compliant' { '#22C55E' }
				'Drifted'   { '#EF4444' }
				default     { '#9CA3AF' }
			}
			$statusGlyph = switch ([string]$entry.Status)
			{
				'Compliant' { [char]0xF299 }
				default     { [char]0xF36E }
			}

			# Name
			$nameGrid = New-Object System.Windows.Controls.Grid
			$nameGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
			$nameGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
			$nameGrid.ColumnDefinitions[0].Width = [System.Windows.GridLength]::Auto
			$nameGrid.ColumnDefinitions[1].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
			[System.Windows.Controls.Grid]::SetColumn($nameGrid, 0)

			$nameIcon = New-Object System.Windows.Controls.TextBlock
			$nameIcon.Text = $statusGlyph
			$nameIcon.FontFamily = [System.Windows.Media.FontFamily]::new('FluentSystemIcons')
			$nameIcon.FontSize = 14
			$nameIcon.VerticalAlignment = 'Center'
			$nameIcon.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
			$nameIcon.Foreground = $bc.ConvertFromString($statusColor)
			[System.Windows.Controls.Grid]::SetColumn($nameIcon, 0)

			$nameBlock = New-Object System.Windows.Controls.TextBlock
			$nameBlock.Text = [string]$entry.Name
			$nameBlock.VerticalAlignment = 'Center'
			$nameBlock.FontWeight = [System.Windows.FontWeights]::SemiBold
			$nameBlock.Foreground = $bc.ConvertFromString($theme.TextPrimary)
			$nameBlock.TextTrimming = 'CharacterEllipsis'
			[System.Windows.Controls.Grid]::SetColumn($nameBlock, 1)

			# Status badge
			$statusBlock = New-Object System.Windows.Controls.TextBlock
			$statusBlock.Text = [string]$entry.Status
			$statusBlock.HorizontalAlignment = 'Center'
			$statusBlock.VerticalAlignment = 'Center'
			$statusBlock.FontWeight = [System.Windows.FontWeights]::Bold
			$statusBlock.Foreground = $bc.ConvertFromString($statusColor)
			[System.Windows.Controls.Grid]::SetColumn($statusBlock, 1)

			# Values: current vs desired
			$valuesBlock = New-Object System.Windows.Controls.TextBlock
			$desiredText = if ($null -ne $entry.DesiredState) { [string]$entry.DesiredState } else { '(null)' }
			$actualText = if ($null -ne $entry.ActualState) { [string]$entry.ActualState } else { '(null)' }
			$valuesBlock.Text = ((& $getLocalizedString -Key 'GuiComplianceCurrentDesiredFormat' -Fallback 'Current: {0} | Desired: {1}') -f $actualText, $desiredText)
			$valuesBlock.VerticalAlignment = 'Center'
			$valuesBlock.FontSize = $layout.FontSizeSmall
			$valuesBlock.Foreground = $bc.ConvertFromString($theme.TextSecondary)
			$valuesBlock.TextTrimming = 'CharacterEllipsis'
			$valuesBlock.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
			[System.Windows.Controls.Grid]::SetColumn($valuesBlock, 2)

			[void]$nameGrid.Children.Add($nameIcon)
			[void]$nameGrid.Children.Add($nameBlock)
			[void]$cardGrid.Children.Add($nameGrid)
			[void]$cardGrid.Children.Add($statusBlock)
			[void]$cardGrid.Children.Add($valuesBlock)
			$card.Child = $cardGrid
			[void]$resultsList.Children.Add($card)
		}

		if ($report.Entries.Count -eq 0)
		{
			$emptyLabel = New-Object System.Windows.Controls.TextBlock
			$emptyLabel.Text = (& $getLocalizedString -Key 'GuiComplianceNoEntries' -Fallback 'No entries found in the selected profile.')
			$emptyLabel.Foreground = $bc.ConvertFromString($theme.TextSecondary)
			$emptyLabel.HorizontalAlignment = 'Center'
			$emptyLabel.Margin = [System.Windows.Thickness]::new(0, 20, 0, 0)
			[void]$resultsList.Children.Add($emptyLabel)
		}
	}.GetNewClosure())

	# --- Fix Drift handler ---
	$btnFixDrift.Add_Click({
		$report = $complianceState.Report
		if (-not $report -or $report.Drifted -eq 0)
		{
			Show-ThemedDialog -Title (& $getLocalizedString -Key 'GuiComplianceFixDrift' -Fallback 'Fix Drift') -Message (& $getLocalizedString -Key 'GuiComplianceNoDrifted' -Fallback 'No drifted entries to fix.') -Buttons @('OK') -AccentButton 'OK'
			return
		}

		$fixDriftLabel = (& $getLocalizedString -Key 'GuiComplianceFixDrift' -Fallback 'Fix Drift')
		$fixConfirmMsg = if ($report.Drifted -eq 1) { (& $getLocalizedString -Key 'GuiComplianceFixConfirmSingular' -Fallback "This will apply changes to fix {0} drifted setting.`n`nDo you want to continue?") -f $report.Drifted } else { (& $getLocalizedString -Key 'GuiComplianceFixConfirmPlural' -Fallback "This will apply changes to fix {0} drifted settings.`n`nDo you want to continue?") -f $report.Drifted }
		$confirmResult = Show-ThemedDialog -Title $fixDriftLabel `
			-Message $fixConfirmMsg `
			-Buttons @('Cancel', $fixDriftLabel) `
			-DestructiveButton $fixDriftLabel
		if ($confirmResult -ne $fixDriftLabel) { return }

		try
		{
			$fixCommands = Get-ComplianceFixList -ComplianceReport $report -Manifest $Script:TweakManifest
			if (-not $fixCommands -or @($fixCommands).Count -eq 0)
			{
				Show-ThemedDialog -Title $fixDriftLabel -Message (& $getLocalizedString -Key 'GuiComplianceFixNoActions' -Fallback 'Could not resolve any fix actions from the drifted entries.') -Buttons @('OK') -AccentButton 'OK'
				return
			}

			# Build tweak list from fix commands
			$fixTweakList = [System.Collections.Generic.List[hashtable]]::new()
			$order = 0
			foreach ($commandLine in @($fixCommands))
			{
				if ([string]::IsNullOrWhiteSpace([string]$commandLine)) { continue }
				$parts = ([string]$commandLine).Trim() -split '\s+', 2
				$functionName = $parts[0]
				$paramName = if ($parts.Count -gt 1) { $parts[1].TrimStart('-') } else { $null }
				if ([string]::IsNullOrWhiteSpace($functionName)) { continue }

				$manifestEntry = Get-ManifestEntryByFunction -Manifest $Script:TweakManifest -Function $functionName
				if (-not $manifestEntry) { continue }

				$order++
				$fixTweakList.Add(@{
					Key             = [string]$order
					Index           = $order
					Name            = [string]$manifestEntry.Name
					Function        = $functionName
					Type            = 'Toggle'
					TypeKind        = 'Toggle'
					TypeLabel       = 'Fix'
					TypeTone        = 'Caution'
					TypeBadgeLabel  = 'Fix'
					Category        = [string]$manifestEntry.Category
					Risk            = [string]$manifestEntry.Risk
					Restorable      = $manifestEntry.Restorable
					RecoveryLevel   = if ((Test-GuiObjectField -Object $manifestEntry -FieldName 'RecoveryLevel')) { [string]$manifestEntry.RecoveryLevel } else { 'Direct' }
					RequiresRestart = [bool]$manifestEntry.RequiresRestart
					Impact          = $manifestEntry.Impact
					PresetTier      = $manifestEntry.PresetTier
					Selection       = if ($paramName) { $paramName } else { 'Fix' }
					ToggleParam     = $paramName
					OnParam         = [string]$manifestEntry.OnParam
					OffParam        = [string]$manifestEntry.OffParam
					IsChecked       = $true
					CurrentState    = (& $getLocalizedString -Key 'GuiComplianceDriftedState' -Fallback 'Drifted from desired state')
					CurrentStateTone = 'Caution'
					StateDetail     = (& $getLocalizedString -Key 'GuiComplianceFixingDetail' -Fallback 'Fixing drift to match the compliance profile.')
					MatchesDesired  = $false
					ScenarioTags    = @()
					ReasonIncluded  = (& $getLocalizedString -Key 'GuiComplianceFixReason' -Fallback 'Included as part of compliance drift fix.')
					BlastRadius     = ''
					IsRemoval       = $false
					ExtraArgs       = $null
					GamingPreviewGroup = $null
					TroubleshootingOnly = $false
				})
			}

			if ($fixTweakList.Count -eq 0)
			{
				Show-ThemedDialog -Title $fixDriftLabel -Message (& $getLocalizedString -Key 'GuiComplianceFixNoChanges' -Fallback 'Could not resolve any fixable changes from the drifted entries.') -Buttons @('OK') -AccentButton 'OK'
				return
			}

			$dlg.Close()
			LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogComplianceFixDriftApplying' -Fallback 'Compliance Fix Drift: applying {0} fix(es).' -FormatArgs @($fixTweakList.Count))
			Start-GuiExecutionRun -TweakList @($fixTweakList) -Mode 'Run' -ExecutionTitle (& $getLocalizedString -Key 'GuiComplianceFixTitle' -Fallback 'Fixing Compliance Drift')
		}
		catch
		{
			LogError (Get-UxBilingualLocalizedString -Key 'GuiLogComplianceFixDriftFailed' -Fallback 'Compliance fix drift failed: {0}' -FormatArgs @($_.Exception.Message))
			Show-ThemedDialog -Title $fixDriftLabel -Message ((& $getLocalizedString -Key 'GuiComplianceFixBuildFailed' -Fallback "Failed to build fix list.`n`n{0}") -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK'
		}
	}.GetNewClosure())

	[void]$dlg.ShowDialog()
}
