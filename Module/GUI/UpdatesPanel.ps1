# Windows Update runtime panel: manifest-independent scan, download, install, and history UI.

function Initialize-GuiWindowsUpdateRuntimeState
{
	if (-not ($Script:WindowsUpdateAvailableUpdates -is [System.Collections.IList]))
	{
		$Script:WindowsUpdateAvailableUpdates = New-Object 'System.Collections.Generic.List[object]'
	}
	if (-not ($Script:WindowsUpdateSelectionControls -is [System.Collections.IList]))
	{
		$Script:WindowsUpdateSelectionControls = New-Object 'System.Collections.Generic.List[object]'
	}
	if (-not ($Script:WindowsUpdateHistoryEntries -is [System.Collections.IList]))
	{
		$Script:WindowsUpdateHistoryEntries = New-Object 'System.Collections.Generic.List[object]'
	}
}

function Get-GuiWindowsUpdateBrushConverter
{
	if ($Script:SharedBrushConverter)
	{
		return $Script:SharedBrushConverter
	}

	$Script:SharedBrushConverter = [System.Windows.Media.BrushConverter]::new()
	return $Script:SharedBrushConverter
}

function New-GuiWindowsUpdateTextBlock
{
	param (
		[string]$Text,
		[double]$FontSize,
		[object]$Foreground,
		[switch]$Bold,
		[switch]$Wrap
	)

	$textBlock = New-Object System.Windows.Controls.TextBlock
	$textBlock.Text = $Text
	$textBlock.FontSize = $FontSize
	if ($Foreground) { $textBlock.Foreground = $Foreground }
	if ($Bold) { $textBlock.FontWeight = [System.Windows.FontWeights]::SemiBold }
	if ($Wrap) { $textBlock.TextWrapping = 'Wrap' }
	return $textBlock
}

function Set-GuiWindowsUpdateStatus
{
	param (
		[string]$Message,
		[ValidateSet('Neutral', 'Success', 'Warning', 'Error')]
		[string]$State = 'Neutral'
	)

	if (-not $Script:TxtWindowsUpdateRuntimeStatus)
	{
		return
	}

	$Script:TxtWindowsUpdateRuntimeStatus.Text = $Message
	$theme = Get-GuiCurrentTheme
	$brushConverter = Get-GuiWindowsUpdateBrushConverter
	$color = switch ($State)
	{
		'Success' { $theme.SuccessText }
		'Warning' { $theme.CautionText }
		'Error' { $theme.DangerText }
		default { $theme.TextSecondary }
	}
	if (-not [string]::IsNullOrWhiteSpace([string]$color))
	{
		$Script:TxtWindowsUpdateRuntimeStatus.Foreground = $brushConverter.ConvertFromString($color)
	}
}

function Update-GuiWindowsUpdateActionState
{
	$busy = [bool]$Script:WindowsUpdateOperationInProgress
	$selectedCount = @(Get-GuiWindowsUpdateSelectedItems).Count

	if ($Script:BtnWindowsUpdateScan) { $Script:BtnWindowsUpdateScan.IsEnabled = -not $busy }
	if ($Script:BtnWindowsUpdateHistory) { $Script:BtnWindowsUpdateHistory.IsEnabled = -not $busy }
	if ($Script:BtnWindowsUpdateDownload) { $Script:BtnWindowsUpdateDownload.IsEnabled = (-not $busy) -and ($selectedCount -gt 0) }
	if ($Script:BtnWindowsUpdateInstall) { $Script:BtnWindowsUpdateInstall.IsEnabled = (-not $busy) -and ($selectedCount -gt 0) }
}

function Get-GuiWindowsUpdateSelectedItems
{
	Initialize-GuiWindowsUpdateRuntimeState
	$selected = New-Object 'System.Collections.Generic.List[object]'
	foreach ($entry in [object[]]$Script:WindowsUpdateSelectionControls.ToArray())
	{
		if (-not $entry -or -not $entry.Update) { continue }
		$isSelected = [bool]$entry.Selected
		if (-not $isSelected -and $entry.CheckBox)
		{
			$isSelected = [bool]$entry.CheckBox.IsChecked
		}
		if ($isSelected)
		{
			[void]$selected.Add($entry.Update)
		}
	}

	return [object[]]$selected.ToArray()
}

function Sync-GuiWindowsUpdateSelectionEntry
{
	param (
		[object]$SelectionEntry
	)

	if ($SelectionEntry -and $SelectionEntry.CheckBox)
	{
		$SelectionEntry.Selected = [bool]$SelectionEntry.CheckBox.IsChecked
	}
	Update-GuiWindowsUpdateActionState
}

function ConvertTo-GuiWindowsUpdateIdentitySelection
{
	param (
		[object[]]$Updates
	)

	$selected = New-Object 'System.Collections.Generic.List[object]'
	foreach ($update in @($Updates))
	{
		if (-not $update) { continue }
		[void]$selected.Add([pscustomobject]@{
			Id             = [string]$update.Id
			RevisionNumber = [int]$update.RevisionNumber
			Title          = [string]$update.Title
		})
	}

	return [object[]]$selected.ToArray()
}

function New-GuiWindowsUpdateActionButton
{
	param (
		[string]$Label,
		[string]$Variant,
		[scriptblock]$Action
	)

	$button = New-PresetButton -Label $Label -Variant $Variant -Compact
	$button.Margin = [System.Windows.Thickness]::new(0, 0, 8, 8)
	$button.MinWidth = 118
	$invokeGuiSafeActionScript = ${function:Invoke-GuiSafeAction}
	Register-GuiEventHandler -Source $button -EventName 'Click' -Handler ({
		& $invokeGuiSafeActionScript -Context 'WindowsUpdate.RuntimePanel' -ShowDialog -Action $Action
	}.GetNewClosure()) | Out-Null
	return $button
}

function Show-GuiWindowsUpdateRuntimeView
{
	$theme = Get-GuiCurrentTheme
	$brushConverter = Get-GuiWindowsUpdateBrushConverter

	$window = New-Object System.Windows.Window
	$window.Title = 'Run Windows Updates'
	$window.Width = 960
	$window.Height = 720
	$window.MinWidth = 760
	$window.MinHeight = 520
	$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
	$window.Background = $brushConverter.ConvertFromString($theme.WindowBg)
	$window.Foreground = $brushConverter.ConvertFromString($theme.TextPrimary)
	if (Get-Command -Name 'GUICommon\Set-GuiWindowChromeTheme' -ErrorAction SilentlyContinue)
	{
		[void](GUICommon\Set-GuiWindowChromeTheme -Window $window -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))
	}
	if (Get-Command -Name 'GUICommon\Add-GuiSharedScrollBarResources' -ErrorAction SilentlyContinue)
	{
		[void](GUICommon\Add-GuiSharedScrollBarResources -Target $window -Theme $theme)
	}
	if ((Test-Path -Path Variable:\Script:MainForm) -and $Script:MainForm)
	{
		$window.Owner = $Script:MainForm
		$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
	}

	$scrollViewer = New-Object System.Windows.Controls.ScrollViewer
	$scrollViewer.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
	$scrollViewer.HorizontalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
	$scrollViewer.Background = $brushConverter.ConvertFromString($theme.WindowBg)
	$scrollViewer.Content = New-GuiUpdatesRuntimePanel
	$window.Content = $scrollViewer

	[void]$window.Show()
}

function Set-GuiWindowsUpdatePresetSelection
{
	param (
		[Parameter(Mandatory = $true)]
		[ValidateSet('Default', 'Security', 'DisableAll')]
		[string]$PresetName
	)

	$commandList = switch ($PresetName)
	{
		'Default'
		{
			@(
				'WindowsUpdateDisableAll -Disable'
				'WindowsUpdateSecurityOnlyMode -Disable'
				'WindowsUpdatePause -Disable'
				'UpdateAutoDownload -Enable'
				'UpdateDriver -Enable'
				'UpdateRestart -Enable'
				'FeatureUpdateDeferral -Disable'
				'QualityUpdateDeferral -Default'
			)
		}
		'Security'
		{
			@(
				'WindowsUpdateDisableAll -Disable'
				'UpdateAutoDownload -Disable'
				'UpdateDriver -Disable'
				'UpdateRestart -Disable'
				'FeatureUpdateDeferral -Enable'
				'QualityUpdateDeferral -FourDays'
			)
		}
		'DisableAll'
		{
			@(
				'WindowsUpdateDisableAll -Enable'
			)
		}
	}

	$displayName = switch ($PresetName)
	{
		'Default' { 'Default Windows Update Settings' }
		'Security' { 'Security Windows Update Settings' }
		'DisableAll' { 'Disable All Windows Updates' }
	}

	$summary = switch ($PresetName)
	{
		'Default' { 'Loads a selection that clears Baseline Windows Update policy controls back to Windows defaults.' }
		'Security' { 'Loads a selection that delays feature updates, applies a short quality update delay, and blocks update drivers/restarts.' }
		'DisableAll' { 'Loads a high-risk selection that disables Windows Update policy, services, and scheduled update tasks.' }
	}

	$selectionDefinitionCommand = Get-GuiRuntimeCommand -Name 'Get-GuiSelectionDefinitionFromCommands' -CommandType 'Function'
	$setTabPresetCommand = Get-GuiRuntimeCommand -Name 'Set-TabPreset' -CommandType 'Function'
	if (-not $selectionDefinitionCommand)
	{
		throw 'Get-GuiSelectionDefinitionFromCommands is not available.'
	}
	if (-not $setTabPresetCommand)
	{
		throw 'Set-TabPreset is not available.'
	}

	$selectionDefinition = & $selectionDefinitionCommand `
		-Name $displayName `
		-CommandLines $commandList `
		-SourcePath ("WindowsUpdates::{0}" -f $PresetName) `
		-ModeKind 'Preset' `
		-StatusMessagePrefix 'Windows Update preset loaded' `
		-Summary $summary

	& $setTabPresetCommand -PrimaryTab 'Updates' -PresetTier $displayName -SelectionDefinition $selectionDefinition
}

function New-GuiWindowsUpdateLeadCard
{
	param (
		[Parameter(Mandatory = $true)]
		[string]$Title,
		[Parameter(Mandatory = $true)]
		[string]$Description,
		[string[]]$Bullets = @(),
		[string]$ButtonLabel,
		[string]$ButtonVariant = 'Secondary',
		[scriptblock]$Action,
		[string]$BorderColor,
		[string]$TitleColor
	)

	$theme = Get-GuiCurrentTheme
	$brushConverter = Get-GuiWindowsUpdateBrushConverter
	$resolvedBorderColor = if ([string]::IsNullOrWhiteSpace($BorderColor)) { $theme.CardBorder } else { $BorderColor }
	$resolvedTitleColor = if ([string]::IsNullOrWhiteSpace($TitleColor)) { $theme.TextPrimary } else { $TitleColor }

	$card = New-Object System.Windows.Controls.Border
	$card.Background = $brushConverter.ConvertFromString($theme.CardBg)
	$card.BorderBrush = $brushConverter.ConvertFromString($resolvedBorderColor)
	$card.BorderThickness = [System.Windows.Thickness]::new(1.5)
	$card.CornerRadius = [System.Windows.CornerRadius]::new($Script:GuiLayout.CardCornerRadius)
	$card.Margin = [System.Windows.Thickness]::new(0, 0, 10, 10)
	$card.Padding = [System.Windows.Thickness]::new(14, 12, 14, 12)
	$card.Width = 300
	$card.MinHeight = 190

	$stack = New-Object System.Windows.Controls.StackPanel
	$stack.Orientation = 'Vertical'

	$titleBlock = New-GuiWindowsUpdateTextBlock -Text $Title -FontSize $Script:GuiLayout.FontSizeLabel -Foreground ($brushConverter.ConvertFromString($resolvedTitleColor)) -Bold -Wrap
	[void]$stack.Children.Add($titleBlock)

	$descriptionBlock = New-GuiWindowsUpdateTextBlock -Text $Description -FontSize $Script:GuiLayout.FontSizeSmall -Foreground ($brushConverter.ConvertFromString($theme.TextSecondary)) -Wrap
	$descriptionBlock.Margin = [System.Windows.Thickness]::new(0, 5, 0, 8)
	[void]$stack.Children.Add($descriptionBlock)

	foreach ($bullet in @($Bullets))
	{
		if ([string]::IsNullOrWhiteSpace([string]$bullet)) { continue }
		$bulletBlock = New-GuiWindowsUpdateTextBlock -Text ("- {0}" -f [string]$bullet) -FontSize $Script:GuiLayout.FontSizeSmall -Foreground ($brushConverter.ConvertFromString($theme.TextSecondary)) -Wrap
		$bulletBlock.Margin = [System.Windows.Thickness]::new(0, 0, 0, 3)
		[void]$stack.Children.Add($bulletBlock)
	}

	if (-not [string]::IsNullOrWhiteSpace($ButtonLabel) -and $Action)
	{
		$button = New-PresetButton -Label $ButtonLabel -Variant $ButtonVariant -Compact
		$button.Margin = [System.Windows.Thickness]::new(0, 10, 0, 0)
		$button.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
		$invokeGuiSafeActionScript = ${function:Invoke-GuiSafeAction}
		Register-GuiEventHandler -Source $button -EventName 'Click' -Handler ({
			& $invokeGuiSafeActionScript -Context ('WindowsUpdate.Card.{0}' -f $Title) -ShowDialog -Action $Action
		}.GetNewClosure()) | Out-Null
		[void]$stack.Children.Add($button)
	}

	$card.Child = $stack
	return $card
}

function New-GuiWindowsUpdatePresetCard
{
	$theme = Get-GuiCurrentTheme
	$brushConverter = Get-GuiWindowsUpdateBrushConverter
	$card = New-GuiWindowsUpdateLeadCard `
		-Title 'Update Settings Presets' `
		-Description 'Load a Windows Update policy selection, then review the regular tweak toggles below before running.' `
		-Bullets @(
			'Default Settings restores Baseline-controlled update policy values.'
			'Security Settings delays feature updates and keeps quality updates near current.'
		) `
		-BorderColor $theme.CardBorder

	$stack = [System.Windows.Controls.StackPanel]$card.Child
	$buttonPanel = New-Object System.Windows.Controls.WrapPanel
	$buttonPanel.Orientation = 'Horizontal'
	$buttonPanel.Margin = [System.Windows.Thickness]::new(0, 10, 0, 0)

	foreach ($presetButton in @(
		[pscustomobject]@{ Label = 'Default Settings'; Preset = 'Default'; Variant = 'Secondary' }
		[pscustomobject]@{ Label = 'Security Settings'; Preset = 'Security'; Variant = 'Secondary' }
	))
	{
		$button = New-PresetButton -Label ([string]$presetButton.Label) -Variant ([string]$presetButton.Variant) -Compact
		$button.Margin = [System.Windows.Thickness]::new(0, 0, 8, 8)
		$presetName = [string]$presetButton.Preset
		$invokeGuiSafeActionScript = ${function:Invoke-GuiSafeAction}
		$setGuiWindowsUpdatePresetSelectionScript = ${function:Set-GuiWindowsUpdatePresetSelection}
		$applyPresetAction = {
			& $setGuiWindowsUpdatePresetSelectionScript -PresetName $presetName
		}.GetNewClosure()
		Register-GuiEventHandler -Source $button -EventName 'Click' -Handler ({
			& $invokeGuiSafeActionScript -Context ('WindowsUpdate.Preset.{0}' -f $presetName) -ShowDialog -Action $applyPresetAction
		}.GetNewClosure()) | Out-Null
		[void]$buttonPanel.Children.Add($button)
	}

	[void]$stack.Children.Add($buttonPanel)
	return $card
}

function New-GuiWindowsUpdateLeadCardsPanel
{
	$theme = Get-GuiCurrentTheme
	$brushConverter = Get-GuiWindowsUpdateBrushConverter

	$outer = New-Object System.Windows.Controls.Border
	$outer.Background = $brushConverter.ConvertFromString($theme.HeaderBg)
	$outer.BorderBrush = $brushConverter.ConvertFromString($theme.CardBorder)
	$outer.BorderThickness = [System.Windows.Thickness]::new(1)
	$outer.CornerRadius = [System.Windows.CornerRadius]::new($Script:GuiLayout.CardCornerRadius)
	$outer.Margin = [System.Windows.Thickness]::new(8, 8, 8, 10)
	$outer.Padding = [System.Windows.Thickness]::new(14, 12, 14, 8)

	$stack = New-Object System.Windows.Controls.StackPanel
	$stack.Orientation = 'Vertical'

	$title = New-GuiWindowsUpdateTextBlock -Text 'Windows Updates' -FontSize $Script:GuiLayout.FontSizeSubheading -Foreground ($brushConverter.ConvertFromString($theme.TextPrimary)) -Bold
	[void]$stack.Children.Add($title)

	$description = New-GuiWindowsUpdateTextBlock -Text 'Use the cards for update actions and policy presets. The regular update tweak controls remain below for review and fine tuning.' -FontSize $Script:GuiLayout.FontSizeSmall -Foreground ($brushConverter.ConvertFromString($theme.TextSecondary)) -Wrap
	$description.Margin = [System.Windows.Thickness]::new(0, 4, 0, 12)
	[void]$stack.Children.Add($description)

	$cards = New-Object System.Windows.Controls.WrapPanel
	$cards.Orientation = 'Horizontal'
	$showGuiWindowsUpdateRuntimeViewScript = ${function:Show-GuiWindowsUpdateRuntimeView}
	$openUpdateRunnerAction = {
		& $showGuiWindowsUpdateRuntimeViewScript
	}.GetNewClosure()
	$setGuiWindowsUpdatePresetSelectionScript = ${function:Set-GuiWindowsUpdatePresetSelection}
	$loadDisableUpdatesPresetAction = {
		& $setGuiWindowsUpdatePresetSelectionScript -PresetName 'DisableAll'
	}.GetNewClosure()

	[void]$cards.Children.Add((New-GuiWindowsUpdateLeadCard `
		-Title 'Run Updates' `
		-Description 'Open the Windows Update runner in a separate view for scan, download, install, and history.' `
		-Bullets @('Does not apply policy tweaks.', 'Runs the Windows Update Agent workflow.') `
		-ButtonLabel 'Open Update Runner' `
		-ButtonVariant 'Primary' `
		-Action $openUpdateRunnerAction `
		-BorderColor $theme.AccentBlue `
		-TitleColor $theme.TextPrimary))

	[void]$cards.Children.Add((New-GuiWindowsUpdateLeadCard `
		-Title 'Disable Updates' `
		-Description 'High-risk policy selection that disables Windows Update. Use only for isolated systems.' `
		-Bullets @('Not recommended for daily-use systems.', 'Disables update policy, services, and scheduled tasks.') `
		-ButtonLabel 'Load Disable Selection' `
		-ButtonVariant 'DangerSubtle' `
		-Action $loadDisableUpdatesPresetAction `
		-BorderColor $theme.DangerText `
		-TitleColor $theme.DangerText))

	[void]$cards.Children.Add((New-GuiWindowsUpdatePresetCard))

	[void]$stack.Children.Add($cards)
	$outer.Child = $stack
	return $outer
}

function New-GuiWindowsUpdateEmptyMessage
{
	param (
		[string]$Text
	)

	$theme = Get-GuiCurrentTheme
	$brushConverter = Get-GuiWindowsUpdateBrushConverter
	$message = New-GuiWindowsUpdateTextBlock -Text $Text -FontSize $Script:GuiLayout.FontSizeBody -Foreground ($brushConverter.ConvertFromString($theme.TextSecondary)) -Wrap
	$message.Margin = [System.Windows.Thickness]::new(0, 4, 0, 4)
	return $message
}

function New-GuiWindowsUpdateUpdateRow
{
	param (
		[object]$Update
	)

	$theme = Get-GuiCurrentTheme
	$brushConverter = Get-GuiWindowsUpdateBrushConverter

	$row = New-Object System.Windows.Controls.Border
	$row.Background = $brushConverter.ConvertFromString($theme.CardBg)
	$row.BorderBrush = $brushConverter.ConvertFromString($theme.CardBorder)
	$row.BorderThickness = [System.Windows.Thickness]::new(1)
	$row.CornerRadius = [System.Windows.CornerRadius]::new(6)
	$row.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)
	$row.Padding = [System.Windows.Thickness]::new(10, 8, 10, 8)

	$checkBox = New-Object System.Windows.Controls.CheckBox
	$checkBox.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
	$checkBox.Margin = [System.Windows.Thickness]::new(0)
	$checkBox.Tag = $Update
	if (Get-Command -Name 'Set-HeaderToggleStyle' -CommandType Function -ErrorAction SilentlyContinue)
	{
		Set-HeaderToggleStyle -CheckBox $checkBox -Palette Mode
	}

	$content = New-Object System.Windows.Controls.StackPanel
	$content.Orientation = 'Vertical'
	$content.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)

	$title = New-GuiWindowsUpdateTextBlock -Text ([string]$Update.Title) -FontSize $Script:GuiLayout.FontSizeBody -Foreground ($brushConverter.ConvertFromString($theme.TextPrimary)) -Bold -Wrap
	[void]$content.Children.Add($title)

	$metadataParts = New-Object 'System.Collections.Generic.List[string]'
	if ($Update.KBArticleIDs -and $Update.KBArticleIDs.Count -gt 0)
	{
		[void]$metadataParts.Add(('KB {0}' -f ([string]::Join(', ', [string[]]$Update.KBArticleIDs))))
	}
	if (-not [string]::IsNullOrWhiteSpace([string]$Update.MsrcSeverity))
	{
		[void]$metadataParts.Add(('MSRC {0}' -f [string]$Update.MsrcSeverity))
	}
	if (-not [string]::IsNullOrWhiteSpace([string]$Update.Type))
	{
		[void]$metadataParts.Add([string]$Update.Type)
	}
	[void]$metadataParts.Add(('Revision {0}' -f [string]$Update.RevisionNumber))

	$metadata = New-GuiWindowsUpdateTextBlock -Text ([string]::Join(' | ', [string[]]$metadataParts.ToArray())) -FontSize $Script:GuiLayout.FontSizeSmall -Foreground ($brushConverter.ConvertFromString($theme.TextSecondary)) -Wrap
	$metadata.Margin = [System.Windows.Thickness]::new(0, 3, 0, 0)
	[void]$content.Children.Add($metadata)

	$checkBox.Content = $content
	$row.Child = $checkBox

	$selectionEntry = [pscustomobject]@{
		CheckBox = $checkBox
		Update   = $Update
		Selected = $false
	}
	[void]$Script:WindowsUpdateSelectionControls.Add($selectionEntry)

	$syncGuiWindowsUpdateSelectionEntryScript = ${function:Sync-GuiWindowsUpdateSelectionEntry}
	Register-GuiEventHandler -Source $checkBox -EventName 'Checked' -Handler ({ & $syncGuiWindowsUpdateSelectionEntryScript -SelectionEntry $selectionEntry }.GetNewClosure()) | Out-Null
	Register-GuiEventHandler -Source $checkBox -EventName 'Unchecked' -Handler ({ & $syncGuiWindowsUpdateSelectionEntryScript -SelectionEntry $selectionEntry }.GetNewClosure()) | Out-Null
	Register-GuiEventHandler -Source $checkBox -EventName 'Click' -Handler ({ & $syncGuiWindowsUpdateSelectionEntryScript -SelectionEntry $selectionEntry }.GetNewClosure()) | Out-Null

	return $row
}

function Update-GuiWindowsUpdateAvailableList
{
	Initialize-GuiWindowsUpdateRuntimeState
	if (-not $Script:WindowsUpdateAvailableListPanel)
	{
		return
	}

	$Script:WindowsUpdateAvailableListPanel.Children.Clear()
	$Script:WindowsUpdateSelectionControls.Clear()

	$updates = [object[]]$Script:WindowsUpdateAvailableUpdates.ToArray()
	if ($updates.Count -eq 0)
	{
		[void]$Script:WindowsUpdateAvailableListPanel.Children.Add((New-GuiWindowsUpdateEmptyMessage -Text 'No available updates have been scanned yet.'))
		Update-GuiWindowsUpdateActionState
		return
	}

	$theme = Get-GuiCurrentTheme
	$brushConverter = Get-GuiWindowsUpdateBrushConverter
	foreach ($classification in @('Critical', 'Security', 'Drivers', 'Optional'))
	{
		$groupUpdates = @($updates | Where-Object { [string]$_.Classification -eq $classification })
		if ($groupUpdates.Count -eq 0) { continue }

		$heading = New-GuiWindowsUpdateTextBlock -Text ('{0} ({1})' -f $classification, $groupUpdates.Count) -FontSize $Script:GuiLayout.FontSizeLabel -Foreground ($brushConverter.ConvertFromString($theme.TextPrimary)) -Bold
		$heading.Margin = [System.Windows.Thickness]::new(0, 10, 0, 6)
		[void]$Script:WindowsUpdateAvailableListPanel.Children.Add($heading)

		foreach ($update in $groupUpdates)
		{
			[void]$Script:WindowsUpdateAvailableListPanel.Children.Add((New-GuiWindowsUpdateUpdateRow -Update $update))
		}
	}

	Update-GuiWindowsUpdateActionState
}

function Update-GuiWindowsUpdateHistoryList
{
	Initialize-GuiWindowsUpdateRuntimeState
	if (-not $Script:WindowsUpdateHistoryList)
	{
		return
	}

	$Script:WindowsUpdateHistoryList.Items.Clear()
	foreach ($entry in [object[]]$Script:WindowsUpdateHistoryEntries.ToArray())
	{
		[void]$Script:WindowsUpdateHistoryList.Items.Add($entry)
	}
}

function Complete-GuiWindowsUpdateOperation
{
	param (
		[object]$Payload
	)

	if (-not $Payload)
	{
		throw 'Windows Update operation returned no payload.'
	}

	switch ([string]$Payload.Action)
	{
		'Scan'
		{
			$Script:WindowsUpdateAvailableUpdates.Clear()
			foreach ($update in @($Payload.Updates))
			{
				[void]$Script:WindowsUpdateAvailableUpdates.Add($update)
			}
			Update-GuiWindowsUpdateAvailableList
			Set-GuiWindowsUpdateStatus -Message ('Scan complete. {0} available update(s).' -f @($Payload.Updates).Count) -State 'Success'
		}
		'History'
		{
			$Script:WindowsUpdateHistoryEntries.Clear()
			foreach ($entry in @($Payload.History))
			{
				[void]$Script:WindowsUpdateHistoryEntries.Add($entry)
			}
			Update-GuiWindowsUpdateHistoryList
			Set-GuiWindowsUpdateStatus -Message ('History refreshed. {0} record(s).' -f @($Payload.History).Count) -State 'Success'
		}
		'Download'
		{
			$result = $Payload.DownloadResult
			$state = if ($result -and [bool]$result.Succeeded) { 'Success' } else { 'Warning' }
			$message = if ($result) { 'Download finished: {0} for {1} update(s).' -f $result.Result, $result.UpdateCount } else { 'Download finished without a result payload.' }
			Set-GuiWindowsUpdateStatus -Message $message -State $state
		}
		'Install'
		{
			$downloadResult = $Payload.DownloadResult
			$installResult = $Payload.InstallResult
			if ($downloadResult -and -not [bool]$downloadResult.Succeeded)
			{
				Set-GuiWindowsUpdateStatus -Message ('Install stopped after download result {0} for {1} update(s).' -f $downloadResult.Result, $downloadResult.UpdateCount) -State 'Warning'
				return
			}
			$state = if ($installResult -and [bool]$installResult.Succeeded) { 'Success' } else { 'Warning' }
			$message = if ($installResult) { 'Install finished: {0} for {1} update(s).' -f $installResult.Result, $installResult.UpdateCount } else { 'Install finished without a result payload.' }
			if ($installResult -and [bool]$installResult.RebootRequired)
			{
				$message = "$message Restart required."
				$state = 'Warning'
			}
			Set-GuiWindowsUpdateStatus -Message $message -State $state
		}
		default
		{
			throw "Unknown Windows Update operation payload action '$([string]$Payload.Action)'."
		}
	}
}

function Start-GuiWindowsUpdateOperation
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateSet('Scan', 'History', 'Download', 'Install')]
		[string]$Action
	)

	if ([bool]$Script:WindowsUpdateOperationInProgress)
	{
		return
	}

	$selectedItems = @()
	if ($Action -in @('Download', 'Install'))
	{
		$selectedItems = @(Get-GuiWindowsUpdateSelectedItems)
		if ($selectedItems.Count -eq 0)
		{
			Set-GuiWindowsUpdateStatus -Message 'Select one or more available updates first.' -State 'Warning'
			return
		}
	}

	if ($Action -eq 'Install')
	{
		$dialogCommand = Get-GuiRuntimeCommand -Name 'Show-ThemedDialog' -CommandType 'Function'
		if ($dialogCommand)
		{
			$installLabel = Get-UxLocalizedString -Key 'GuiWindowsUpdateInstallSelected' -Fallback 'Install Selected'
			$cancelLabel = Get-UxLocalizedString -Key 'GuiBtnCancel' -Fallback 'Cancel'
			$confirm = & $dialogCommand -Title 'Install Windows Updates' -Message ('Install {0} selected Windows update(s)? Windows may require a restart.' -f $selectedItems.Count) -Buttons @($installLabel, $cancelLabel) -AccentButton $installLabel
			if ($confirm -ne $installLabel)
			{
				return
			}
		}
	}

	$helperPath = Join-Path -Path $Script:GuiModuleBasePath -ChildPath 'SharedHelpers\WindowsUpdate.Helpers.ps1'
	if (-not (Test-Path -LiteralPath $helperPath))
	{
		throw "Windows Update helper is missing: $helperPath"
	}

	$Script:WindowsUpdateOperationInProgress = $true
	Update-GuiWindowsUpdateActionState

	$selectedIdentities = @(ConvertTo-GuiWindowsUpdateIdentitySelection -Updates $selectedItems)
	$syncHash = [hashtable]::Synchronized(@{
		Status = ''
	})

	$runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
	$runspace.ApartmentState = [System.Threading.ApartmentState]::MTA
	$runspace.Open()
	$ps = [System.Management.Automation.PowerShell]::Create()
	$ps.Runspace = $runspace

	$null = $ps.AddScript({
		param (
			[string]$HelperPath,
			[string]$Action,
			[object[]]$SelectedIdentities,
			[hashtable]$Sync
		)

		. $HelperPath

		function ConvertTo-PortableWindowsUpdateRecord
		{
			param ([object]$Update)

			[pscustomobject]@{
				Id             = [string]$Update.Id
				RevisionNumber = [int]$Update.RevisionNumber
				Title          = [string]$Update.Title
				Description    = [string]$Update.Description
				KBArticleIDs   = [string[]]$Update.KBArticleIDs
				MsrcSeverity   = [string]$Update.MsrcSeverity
				CategoryNames  = [string[]]@($Update.Categories | ForEach-Object { [string]$_.Name })
				Classification = [string]$Update.Classification
				IsInstalled    = [bool]$Update.IsInstalled
				IsHidden       = [bool]$Update.IsHidden
				IsDownloaded   = [bool]$Update.IsDownloaded
				Type           = [string]$Update.Type
				RebootRequired = [bool]$Update.RebootRequired
			}
		}

		function Resolve-SelectedWindowsUpdateRecords
		{
			param (
				[object[]]$AvailableUpdates,
				[object[]]$Selections
			)

			$selectedUpdates = New-Object 'System.Collections.Generic.List[object]'
			$missingTitles = New-Object 'System.Collections.Generic.List[string]'
			foreach ($selection in @($Selections))
			{
				$match = @(
					$AvailableUpdates | Where-Object {
						([string]$_.Id -eq [string]$selection.Id) -and
						([int]$_.RevisionNumber -eq [int]$selection.RevisionNumber)
					} | Select-Object -First 1
				)
				if ($match.Count -gt 0)
				{
					[void]$selectedUpdates.Add($match[0])
				}
				else
				{
					[void]$missingTitles.Add([string]$selection.Title)
				}
			}

			if ($missingTitles.Count -gt 0)
			{
				throw "Selected Windows update(s) are no longer available: $([string]::Join(', ', [string[]]$missingTitles.ToArray()))"
			}

			return [object[]]$selectedUpdates.ToArray()
		}

		function Test-BaselineWindowsUpdateDisabledForManualRun
		{
			$policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
			try
			{
				$policy = Get-ItemProperty -Path $policyPath -Name NoAutoUpdate -ErrorAction Stop
				return ([int]$policy.NoAutoUpdate -eq 1)
			}
			catch
			{
				return $false
			}
		}

		function Set-BaselineWindowsUpdateManualRunServiceState
		{
			param (
				[Parameter(Mandatory = $true)]
				[bool]$Enabled
			)

			$serviceDefinitions = @(
				[pscustomobject]@{ Name = 'BITS'; EnabledStartupType = 'Manual'; DisabledStartupType = 'Disabled' }
				[pscustomobject]@{ Name = 'wuauserv'; EnabledStartupType = 'Manual'; DisabledStartupType = 'Disabled' }
				[pscustomobject]@{ Name = 'UsoSvc'; EnabledStartupType = 'Automatic'; DisabledStartupType = 'Disabled' }
			)

			foreach ($serviceDefinition in $serviceDefinitions)
			{
				$serviceName = [string]$serviceDefinition.Name
				if ($Enabled)
				{
					Set-Service -Name $serviceName -StartupType ([string]$serviceDefinition.EnabledStartupType) -ErrorAction SilentlyContinue | Out-Null
					Start-Service -Name $serviceName -ErrorAction SilentlyContinue | Out-Null
				}
				else
				{
					Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue | Out-Null
					Set-Service -Name $serviceName -StartupType ([string]$serviceDefinition.DisabledStartupType) -ErrorAction SilentlyContinue | Out-Null
				}
			}
		}

		$disableUpdatesAfterManualRun = Test-BaselineWindowsUpdateDisabledForManualRun
		if ($disableUpdatesAfterManualRun)
		{
			$Sync.Status = 'Temporarily enabling Windows Update service for manual update run...'
			Set-BaselineWindowsUpdateManualRunServiceState -Enabled $true
		}

		try
		{
			switch ($Action)
			{
				'Scan'
				{
					$Sync.Status = 'Scanning Windows Update...'
					$updates = @(Get-WindowsUpdateList)
					$portableUpdates = @($updates | ForEach-Object { ConvertTo-PortableWindowsUpdateRecord -Update $_ })
					return [pscustomobject]@{ Action = 'Scan'; Updates = $portableUpdates }
				}
				'History'
				{
					$Sync.Status = 'Reading Windows Update history...'
					$history = @(Get-WindowsUpdateHistory -Count 50)
					return [pscustomobject]@{ Action = 'History'; History = $history }
				}
				'Download'
				{
					$Sync.Status = 'Resolving selected Windows updates...'
					$availableUpdates = @(Get-WindowsUpdateList)
					$selectedUpdates = @(Resolve-SelectedWindowsUpdateRecords -AvailableUpdates $availableUpdates -Selections $SelectedIdentities)
					$Sync.Status = 'Downloading selected Windows updates...'
					$downloadResult = Download-WindowsUpdates -Updates $selectedUpdates
					return [pscustomobject]@{ Action = 'Download'; DownloadResult = $downloadResult }
				}
				'Install'
				{
					$Sync.Status = 'Resolving selected Windows updates...'
					$availableUpdates = @(Get-WindowsUpdateList)
					$selectedUpdates = @(Resolve-SelectedWindowsUpdateRecords -AvailableUpdates $availableUpdates -Selections $SelectedIdentities)
					$Sync.Status = 'Downloading selected Windows updates...'
					$downloadResult = Download-WindowsUpdates -Updates $selectedUpdates
					$installResult = $null
					if ([bool]$downloadResult.Succeeded)
					{
						$Sync.Status = 'Installing selected Windows updates...'
						$installResult = Install-WindowsUpdates -Updates $selectedUpdates
					}
					return [pscustomobject]@{ Action = 'Install'; DownloadResult = $downloadResult; InstallResult = $installResult }
				}
			}
		}
		finally
		{
			if ($disableUpdatesAfterManualRun)
			{
				$Sync.Status = 'Disabling Windows Update service after manual update run...'
				Set-BaselineWindowsUpdateManualRunServiceState -Enabled $false
			}
		}
	}).AddArgument($helperPath).AddArgument($Action).AddArgument($selectedIdentities).AddArgument($syncHash)

	$statusText = switch ($Action)
	{
		'Scan' { 'Scanning Windows Update...' }
		'History' { 'Reading Windows Update history...' }
		'Download' { 'Downloading selected Windows updates...' }
		'Install' { 'Preparing selected Windows updates...' }
	}
	Set-GuiWindowsUpdateStatus -Message $statusText

	$asyncResult = $ps.BeginInvoke()
	$timer = [System.Windows.Threading.DispatcherTimer]::new()
	$timer.Interval = [TimeSpan]::FromMilliseconds(150)
	$showFailureScript = $Script:ShowGuiRuntimeFailureScript
	$setGuiWindowsUpdateStatusScript = ${function:Set-GuiWindowsUpdateStatus}
	$completeGuiWindowsUpdateOperationScript = ${function:Complete-GuiWindowsUpdateOperation}
	$updateGuiWindowsUpdateActionStateScript = ${function:Update-GuiWindowsUpdateActionState}
	$timer.Add_Tick({
		if (-not [string]::IsNullOrWhiteSpace([string]$syncHash.Status))
		{
			& $setGuiWindowsUpdateStatusScript -Message ([string]$syncHash.Status)
		}

		if (-not $asyncResult.IsCompleted)
		{
			return
		}

		$timer.Stop()
		try
		{
			$result = @($ps.EndInvoke($asyncResult))
			$payload = if ($result.Count -gt 0) { $result[0] } else { $null }
			& $completeGuiWindowsUpdateOperationScript -Payload $payload
		}
		catch
		{
			& $setGuiWindowsUpdateStatusScript -Message ('Windows Update operation failed: {0}' -f $_.Exception.Message) -State 'Error'
			if ($showFailureScript)
			{
				& $showFailureScript -Context ('WindowsUpdate.{0}' -f $Action) -Exception $_.Exception -ShowDialog
			}
			else
			{
				Write-Warning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix ("Windows Update operation failed [{0}]" -f $Action))
			}
		}
		finally
		{
			$Script:WindowsUpdateOperationInProgress = $false
			& $updateGuiWindowsUpdateActionStateScript
			try { $ps.Dispose() } catch { Write-SwallowedException -ErrorRecord $_ -Source 'UpdatesPanel.Start-GuiWindowsUpdateOperation.DisposePowerShell' }
			try { $runspace.Dispose() } catch { Write-SwallowedException -ErrorRecord $_ -Source 'UpdatesPanel.Start-GuiWindowsUpdateOperation.DisposeRunspace' }
		}
	}.GetNewClosure())
	$timer.Start()
}

function New-GuiUpdatesRuntimePanel
{
	Initialize-GuiWindowsUpdateRuntimeState

	$theme = Get-GuiCurrentTheme
	$brushConverter = Get-GuiWindowsUpdateBrushConverter

	$outer = New-Object System.Windows.Controls.Border
	$outer.Background = $brushConverter.ConvertFromString($theme.HeaderBg)
	$outer.BorderBrush = $brushConverter.ConvertFromString($theme.CardBorder)
	$outer.BorderThickness = [System.Windows.Thickness]::new(1)
	$outer.CornerRadius = [System.Windows.CornerRadius]::new($Script:GuiLayout.CardCornerRadius)
	$outer.Margin = [System.Windows.Thickness]::new(8, 8, 8, 10)
	$outer.Padding = [System.Windows.Thickness]::new(14, 12, 14, 12)

	$stack = New-Object System.Windows.Controls.StackPanel
	$stack.Orientation = 'Vertical'

	$title = New-GuiWindowsUpdateTextBlock -Text 'Windows Update Runtime' -FontSize $Script:GuiLayout.FontSizeSubheading -Foreground ($brushConverter.ConvertFromString($theme.TextPrimary)) -Bold
	[void]$stack.Children.Add($title)

	$description = New-GuiWindowsUpdateTextBlock -Text 'Scan, download, and install Windows Update Agent updates independently of policy tweaks and presets.' -FontSize $Script:GuiLayout.FontSizeSmall -Foreground ($brushConverter.ConvertFromString($theme.TextSecondary)) -Wrap
	$description.Margin = [System.Windows.Thickness]::new(0, 4, 0, 10)
	[void]$stack.Children.Add($description)

	$buttonPanel = New-Object System.Windows.Controls.WrapPanel
	$buttonPanel.Orientation = 'Horizontal'
	$buttonPanel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)

	$Script:GuiWindowsUpdateOperationInvoker = {
		param (
			[ValidateSet('Scan', 'Download', 'Install', 'History')]
			[string]$Action
		)

		Start-GuiWindowsUpdateOperation -Action $Action
	}
	$Script:BtnWindowsUpdateScan = New-GuiWindowsUpdateActionButton -Label 'Scan for Updates' -Variant 'Primary' -Action { & $Script:GuiWindowsUpdateOperationInvoker -Action 'Scan' }
	$Script:BtnWindowsUpdateDownload = New-GuiWindowsUpdateActionButton -Label 'Download Only' -Variant 'Secondary' -Action { & $Script:GuiWindowsUpdateOperationInvoker -Action 'Download' }
	$Script:BtnWindowsUpdateInstall = New-GuiWindowsUpdateActionButton -Label 'Install Selected' -Variant 'Secondary' -Action { & $Script:GuiWindowsUpdateOperationInvoker -Action 'Install' }
	$Script:BtnWindowsUpdateHistory = New-GuiWindowsUpdateActionButton -Label 'Refresh History' -Variant 'Subtle' -Action { & $Script:GuiWindowsUpdateOperationInvoker -Action 'History' }

	[void]$buttonPanel.Children.Add($Script:BtnWindowsUpdateScan)
	[void]$buttonPanel.Children.Add($Script:BtnWindowsUpdateDownload)
	[void]$buttonPanel.Children.Add($Script:BtnWindowsUpdateInstall)
	[void]$buttonPanel.Children.Add($Script:BtnWindowsUpdateHistory)
	[void]$stack.Children.Add($buttonPanel)

	$statusBorder = New-Object System.Windows.Controls.Border
	$statusBorder.Background = $brushConverter.ConvertFromString($theme.CardBg)
	$statusBorder.BorderBrush = $brushConverter.ConvertFromString($theme.CardBorder)
	$statusBorder.BorderThickness = [System.Windows.Thickness]::new(1)
	$statusBorder.CornerRadius = [System.Windows.CornerRadius]::new(6)
	$statusBorder.Padding = [System.Windows.Thickness]::new(10, 7, 10, 7)
	$statusBorder.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)
	$Script:TxtWindowsUpdateRuntimeStatus = New-GuiWindowsUpdateTextBlock -Text 'Ready.' -FontSize $Script:GuiLayout.FontSizeSmall -Foreground ($brushConverter.ConvertFromString($theme.TextSecondary)) -Wrap
	$statusBorder.Child = $Script:TxtWindowsUpdateRuntimeStatus
	[void]$stack.Children.Add($statusBorder)

	$availableHeading = New-GuiWindowsUpdateTextBlock -Text 'Available Updates' -FontSize $Script:GuiLayout.FontSizeLabel -Foreground ($brushConverter.ConvertFromString($theme.TextPrimary)) -Bold
	$availableHeading.Margin = [System.Windows.Thickness]::new(0, 2, 0, 6)
	[void]$stack.Children.Add($availableHeading)

	$Script:WindowsUpdateAvailableListPanel = New-Object System.Windows.Controls.StackPanel
	$Script:WindowsUpdateAvailableListPanel.Orientation = 'Vertical'
	[void]$stack.Children.Add($Script:WindowsUpdateAvailableListPanel)

	$historyHeading = New-GuiWindowsUpdateTextBlock -Text 'Update History' -FontSize $Script:GuiLayout.FontSizeLabel -Foreground ($brushConverter.ConvertFromString($theme.TextPrimary)) -Bold
	$historyHeading.Margin = [System.Windows.Thickness]::new(0, 12, 0, 6)
	[void]$stack.Children.Add($historyHeading)

	$Script:WindowsUpdateHistoryList = New-Object System.Windows.Controls.ListView
	$Script:WindowsUpdateHistoryList.MinHeight = 110
	$Script:WindowsUpdateHistoryList.MaxHeight = 220
	$Script:WindowsUpdateHistoryList.BorderThickness = [System.Windows.Thickness]::new(1)
	$Script:WindowsUpdateHistoryList.BorderBrush = $brushConverter.ConvertFromString($theme.CardBorder)
	$Script:WindowsUpdateHistoryList.Background = $brushConverter.ConvertFromString($theme.CardBg)
	$Script:WindowsUpdateHistoryList.Foreground = $brushConverter.ConvertFromString($theme.TextPrimary)

	$gridView = New-Object System.Windows.Controls.GridView
	foreach ($column in @(
		[pscustomobject]@{ Header = 'Date'; Property = 'Date'; Width = 145 }
		[pscustomobject]@{ Header = 'Result'; Property = 'Result'; Width = 120 }
		[pscustomobject]@{ Header = 'Operation'; Property = 'OperationName'; Width = 110 }
		[pscustomobject]@{ Header = 'Title'; Property = 'Title'; Width = 420 }
	))
	{
		$gridColumn = New-Object System.Windows.Controls.GridViewColumn
		$gridColumn.Header = $column.Header
		$gridColumn.DisplayMemberBinding = New-Object -TypeName System.Windows.Data.Binding -ArgumentList $column.Property
		$gridColumn.Width = [double]$column.Width
		[void]$gridView.Columns.Add($gridColumn)
	}
	$Script:WindowsUpdateHistoryList.View = $gridView
	[void]$stack.Children.Add($Script:WindowsUpdateHistoryList)

	$outer.Child = $stack
	Update-GuiWindowsUpdateAvailableList
	Update-GuiWindowsUpdateHistoryList
	Update-GuiWindowsUpdateActionState
	return $outer
}
