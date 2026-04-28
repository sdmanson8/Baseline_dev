# ExecutionOrchestration split file loaded by Module\GUI\ExecutionOrchestration.ps1.

	<#
	    .SYNOPSIS
	    Internal function New-ExecutionViewHeader.
	#>

	function New-ExecutionViewHeader
	{
		param (
			[Parameter(Mandatory = $true)][string]$Title,
			[Parameter(Mandatory = $true)]$BrushConverter
		)

		$panel = New-Object System.Windows.Controls.StackPanel
		$panel.Orientation = 'Vertical'

		$heading = New-Object System.Windows.Controls.TextBlock
		$heading.Text = $Title
		$heading.FontSize = $Script:GuiLayout.FontSizeHeading
		$heading.FontWeight = [System.Windows.FontWeights]::Bold
		$heading.Foreground = $BrushConverter.ConvertFromString($Script:CurrentTheme.TextPrimary)
		$heading.Margin = [System.Windows.Thickness]::new(0,0,0,6)
		[void]($panel.Children.Add($heading))

		$subheading = New-Object System.Windows.Controls.TextBlock
		$subheading.Text = Get-UxLocalizedString -Key 'GuiExecutionSubheading' -Fallback 'Progress will appear here live. Please keep this window open until completion.'
		$subheading.FontSize = $Script:GuiLayout.FontSizeSubheading
		$subheading.TextWrapping = 'Wrap'
		$subheading.Foreground = $BrushConverter.ConvertFromString($Script:CurrentTheme.TextSecondary)
		$subheading.Margin = [System.Windows.Thickness]::new(0,0,0,12)
		[void]($panel.Children.Add($subheading))

		return $panel
	}

	<#
	    .SYNOPSIS
	    Internal function New-ExecutionViewProgressSection.
	#>

	function New-ExecutionViewProgressSection
	{
		param (
			[Parameter(Mandatory = $true)]$BrushConverter,
			[bool]$ShowAbortButton = $true
		)

		$progressGrid = New-Object System.Windows.Controls.Grid
		$progressGrid.Margin = [System.Windows.Thickness]::new(0,0,0,12)
		$progressCol1 = New-Object System.Windows.Controls.ColumnDefinition
		$progressCol1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
		$progressCol2 = New-Object System.Windows.Controls.ColumnDefinition
		$progressCol2.Width = if ($ShowAbortButton)
		{
			[System.Windows.GridLength]::new($Script:GuiLayout.ProgressColumnWidth, [System.Windows.GridUnitType]::Pixel)
		}
		else
		{
			[System.Windows.GridLength]::new(0, [System.Windows.GridUnitType]::Pixel)
		}
		[void]($progressGrid.ColumnDefinitions.Add($progressCol1))
		[void]($progressGrid.ColumnDefinitions.Add($progressCol2))

		$progressStack = New-Object System.Windows.Controls.StackPanel
		$progressStack.Orientation = 'Vertical'
		$progressStack.Margin = if ($ShowAbortButton) { [System.Windows.Thickness]::new(0,0,12,0) } else { [System.Windows.Thickness]::new(0) }
		[System.Windows.Controls.Grid]::SetColumn($progressStack, 0)

		$sharedProgress = New-SharedProgressBarHost -Maximum 1 -Value 0
		$progressHost = $sharedProgress.Host
		$progressHost.Margin = [System.Windows.Thickness]::new(0,0,0,6)
		[void]($progressStack.Children.Add($progressHost))

		$progressText = New-Object System.Windows.Controls.TextBlock
		$progressText.FontSize = $Script:GuiLayout.FontSizeSubheading
		$progressText.Foreground = $BrushConverter.ConvertFromString($Script:CurrentTheme.TextSecondary)
		$progressText.Text = Get-UxExecutionPlaceholderText -Kind 'Preparing'
		$progressText.TextWrapping = 'NoWrap'
		$progressText.TextTrimming = 'CharacterEllipsis'
		$progressText.HorizontalAlignment = 'Stretch'
		[void]($progressStack.Children.Add($progressText))
		[void]($progressGrid.Children.Add($progressStack))

		$abortBtn = $null
		if ($ShowAbortButton)
		{
			$abortBtnHost = New-Object System.Windows.Controls.Border
			$abortBtnHost.Padding = [System.Windows.Thickness]::new(0)
			$abortBtnHost.HorizontalAlignment = 'Right'
			$abortBtnHost.VerticalAlignment = 'Top'
			[System.Windows.Controls.Grid]::SetColumn($abortBtnHost, 1)

			$abortBtn = New-Object System.Windows.Controls.Button
			$abortBtn.Content = Get-UxLocalizedString -Key 'GuiAbortButton' -Fallback 'Abort'
			$abortBtn.MinWidth = $Script:GuiLayout.ButtonAbortMinWidth
			$abortBtn.Height = $Script:GuiLayout.ButtonLargeHeight
			$abortBtn.Padding = [System.Windows.Thickness]::new(18,8,18,8)
			$abortBtn.HorizontalAlignment = 'Stretch'
			$abortBtn.VerticalAlignment = 'Top'
			$abortBtn.Cursor = [System.Windows.Input.Cursors]::Hand
			$abortBtn.TabIndex = 0
			Register-GuiEventHandler -Source $abortBtn -EventName 'Click' -Handler { & $Script:PromptRunAbortFn }
			Set-ButtonChrome -Button $abortBtn -Variant 'Danger'
			$abortBtnHost.Child = $abortBtn
			[void]($progressGrid.Children.Add($abortBtnHost))
		}

		return @{
			Grid        = $progressGrid
			ProgressHost = $progressHost
			ProgressBar = $sharedProgress.ProgressBar
			ProgressText = $progressText
			AbortButton = $abortBtn
		}
	}

	<#
	    .SYNOPSIS
	    Internal function New-ExecutionViewLogBox.
	#>

	function New-ExecutionViewLogBox
	{
		param (
			[Parameter(Mandatory = $true)]$BrushConverter
		)

		$logBox = New-Object System.Windows.Controls.RichTextBox
		$logBox.IsReadOnly = $true
		$logBox.VerticalScrollBarVisibility = 'Auto'
		$logBox.HorizontalScrollBarVisibility = 'Disabled'
		$logBox.BorderThickness = [System.Windows.Thickness]::new(0)
		$logBox.Padding = [System.Windows.Thickness]::new(12)
		$logBox.Background = $BrushConverter.ConvertFromString($Script:CurrentTheme.CardBg)
		$logBox.Foreground = $BrushConverter.ConvertFromString($Script:CurrentTheme.TextPrimary)
		$logBox.FontFamily = New-Object System.Windows.Media.FontFamily('Consolas')
		$logBox.FontSize = $Script:GuiLayout.FontSizeSubheading
		$logBox.TabIndex = 1
		$flowDoc = New-Object System.Windows.Documents.FlowDocument
		$flowDoc.PagePadding = [System.Windows.Thickness]::new(0)
		$flowDoc.LineHeight = 1
		$logBox.Document = $flowDoc

		return $logBox
	}

	<#
	    .SYNOPSIS
	    Internal function Enter-ExecutionView.
	#>

	function Enter-ExecutionView
	{
		param (
			[string]$Title,
			[bool]$ShowAbortButton = $true
		)

		$bc = New-SafeBrushConverter -Context 'Enter-ExecutionView'
		$Script:ExecutionPreviousContent = $ContentScroll.Content
		$Script:ExecutionPreviousScrollMode = $ContentScroll.VerticalScrollBarVisibility

		# Build the outer grid: header row (auto) + log row (fill)
		$outerGrid = New-Object System.Windows.Controls.Grid
		$outerGrid.Margin = [System.Windows.Thickness]::new(12)
		$rowHeader = New-Object System.Windows.Controls.RowDefinition
		$rowHeader.Height = [System.Windows.GridLength]::Auto
		$rowLog = New-Object System.Windows.Controls.RowDefinition
		$rowLog.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
		[void]($outerGrid.RowDefinitions.Add($rowHeader))
		[void]($outerGrid.RowDefinitions.Add($rowLog))

		# Top section: heading + subheading + progress bar + abort button
		$topPanel = New-ExecutionViewHeader -Title $Title -BrushConverter $bc
		$progressSection = New-ExecutionViewProgressSection -BrushConverter $bc -ShowAbortButton:$ShowAbortButton
		[void]($topPanel.Children.Add($progressSection.Grid))
		[System.Windows.Controls.Grid]::SetRow($topPanel, 0)
		[void]($outerGrid.Children.Add($topPanel))

		# Bottom section: scrollable rich log box
		$logBox = New-ExecutionViewLogBox -BrushConverter $bc
		[System.Windows.Controls.Grid]::SetRow($logBox, 1)
		[void]($outerGrid.Children.Add($logBox))

		# Swap content and assign execution state
		$ContentScroll.VerticalScrollBarVisibility = 'Disabled'
		$ContentScroll.Content = $outerGrid
		$Script:ExecutionLogBox = $logBox
		$Script:ExecutionLastConsoleAction = $null
		$Script:ExecutionProgressHost = $progressSection.ProgressHost
		$Script:ExecutionProgressBar = $progressSection.ProgressBar
		$Script:ExecutionProgressText = $progressSection.ProgressText
		$Script:AbortRunButton = $progressSection.AbortButton
		Reset-RunAbortState
		$Script:ExecutionWorker = $null
		$Script:ExecutionRunspace = $null
		$Script:ExecutionRunPowerShell = $null
		$Script:ExecutionRunTimer = $null
		$Script:ExecutionTimerErrorShown = $false
		$Script:SuppressRunClosePrompt = $false
		$Script:BgPS = $null
		$Script:BgAsync = $null

		# Hide filter bar, tab bar, and expert-mode banner during execution
		$PrimaryTabs.Visibility = [System.Windows.Visibility]::Collapsed
		$HeaderBorder.Visibility = [System.Windows.Visibility]::Collapsed
		if ($ExpertModeBanner) { $ExpertModeBanner.Visibility = [System.Windows.Visibility]::Collapsed }
		# Hide bottom action buttons during execution
		if ($ActionButtonBar) { $ActionButtonBar.Visibility = [System.Windows.Visibility]::Collapsed }
		if ($BtnPreviewRun) { $BtnPreviewRun.Visibility = [System.Windows.Visibility]::Collapsed }
		if ($StatusText) { $StatusText.Visibility = [System.Windows.Visibility]::Collapsed }
		if ($progressSection.AbortButton)
		{
			[void]($progressSection.AbortButton.Focus())
		}
		elseif ($logBox)
		{
			[void]($logBox.Focus())
		}
	}

	    <#
	        .SYNOPSIS
	        Internal function Exit-ExecutionView.
	    #>

	    function Exit-ExecutionView
	    {
			LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionViewEntered' -Fallback '[Exit-ExecutionView] ENTERED - restoring GUI')
			$deferAbortReset = ($Script:AbortRequested -and (Get-RunAbortDisposition) -eq 'Return')
			$savedPreviousContent = $Script:ExecutionPreviousContent
	        $Script:ExecutionLogBox = $null
	        $Script:ExecutionLastConsoleAction = $null
	        $Script:ExecutionProgressHost = $null
	        $Script:ExecutionProgressBar = $null
	        $Script:ExecutionProgressText = $null
	        $Script:AbortRunButton = $null
	        $Script:ExecutionWorker = $null
        $Script:ExecutionRunspace = $null
        $Script:ExecutionRunPowerShell = $null
        $Script:ExecutionRunTimer = $null
        $Script:ExecutionTimerErrorShown = $false
	        $Script:BgPS = $null
	        $Script:BgAsync = $null
	        $Script:ExecutionPreviousContent = $null
	        $Script:ExecutionCurrentSummaryKey = $null
	        $Script:ExecutionMode = $null

	        # Restore the outer ScrollViewer scrolling mode
	        $ContentScroll.VerticalScrollBarVisibility = 'Auto'

        # Reset run state
        if ($Script:GuiState) { & $Script:GuiState.Set 'RunInProgress' $false } else { $Script:RunInProgress = $false }

        # Restore filter bar, tab bar, and expert-mode banner
        if ($PrimaryTabs)
        {
            $PrimaryTabs.Visibility = [System.Windows.Visibility]::Visible
            if ((Test-GuiObjectField -Object $PrimaryTabs -FieldName 'IsEnabled'))
            {
                $PrimaryTabs.IsEnabled = $true
            }
        }
        if ($HeaderBorder) { $HeaderBorder.Visibility = [System.Windows.Visibility]::Visible }
        if ($ExpertModeBanner -and (Get-Command -Name 'Test-IsExpertModeUX' -CommandType Function -ErrorAction SilentlyContinue) -and (Test-IsExpertModeUX))
        {
            $ExpertModeBanner.Visibility = [System.Windows.Visibility]::Visible
        }
        # Restore bottom action buttons
        if ($ActionButtonBar) { $ActionButtonBar.Visibility = [System.Windows.Visibility]::Visible }
        if ($BtnPreviewRun) { $BtnPreviewRun.Visibility = [System.Windows.Visibility]::Visible; $BtnPreviewRun.IsEnabled = $true }
        if ($StatusText) { $StatusText.Visibility = [System.Windows.Visibility]::Visible }
        # Re-enable controls
        if ($BtnRun) { $BtnRun.IsEnabled = $true }
        if ($BtnDefaults) { $BtnDefaults.IsEnabled = $true }
        Set-GuiActionButtonsEnabled -Enabled $true
        if ($ChkScan) { $ChkScan.IsEnabled = $true }
        if ($ChkTheme) { $ChkTheme.IsEnabled = $true }
        Set-SearchControlsEnabled -Enabled $true
        if (Get-Command -Name 'Sync-UxActionButtonText' -CommandType Function -ErrorAction SilentlyContinue)
        {
            Sync-UxActionButtonText
        }
        elseif ($BtnRun)
        {
            $BtnRun.Content = Get-UxRunActionLabel
        }

        if ($Script:CurrentPrimaryTab)
        {
            try
            {
                Build-TabContent -PrimaryTab $Script:CurrentPrimaryTab
            }
            catch
            {
                LogError (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionViewBuildTabContentFailed' -Fallback '[Exit-ExecutionView] Build-TabContent failed: {0}' -FormatArgs @($_.Exception.Message))
                if ($savedPreviousContent)
                {
                    $ContentScroll.Content = $savedPreviousContent
                }
            }
        }
        elseif ($savedPreviousContent)
        {
            $ContentScroll.Content = $savedPreviousContent
        }

			if ($deferAbortReset -and $Script:MainForm -and $Script:MainForm.Dispatcher)
			{
				try
				{
					$null = Invoke-GuiDispatcherAction -Dispatcher $Script:MainForm.Dispatcher -PriorityUsage 'Pump' -Action {
						try { Reset-RunAbortState } catch { $null = $_ }
					}
				}
				catch
				{
					Reset-RunAbortState
				}
			}
			else
			{
				Reset-RunAbortState
			}

		LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionViewCompleted' -Fallback '[Exit-ExecutionView] COMPLETED - GUI restored')
    }

