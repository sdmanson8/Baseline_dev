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
	foreach ($entry in @($Script:WindowsUpdateSelectionControls))
	{
		if ($entry -and $entry.CheckBox -and [bool]$entry.CheckBox.IsChecked -and $entry.Update)
		{
			[void]$selected.Add($entry.Update)
		}
	}

	return [object[]]$selected.ToArray()
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
	Register-GuiEventHandler -Source $button -EventName 'Click' -Handler ({
		Invoke-GuiSafeAction -Context 'WindowsUpdate.RuntimePanel' -ShowDialog -Action $Action
	}.GetNewClosure()) | Out-Null
	return $button
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
	Register-GuiEventHandler -Source $checkBox -EventName 'Checked' -Handler ({ Update-GuiWindowsUpdateActionState }.GetNewClosure()) | Out-Null
	Register-GuiEventHandler -Source $checkBox -EventName 'Unchecked' -Handler ({ Update-GuiWindowsUpdateActionState }.GetNewClosure()) | Out-Null

	[void]$Script:WindowsUpdateSelectionControls.Add([pscustomobject]@{
		CheckBox = $checkBox
		Update   = $Update
	})

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

	$updates = @($Script:WindowsUpdateAvailableUpdates)
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
	foreach ($entry in @($Script:WindowsUpdateHistoryEntries))
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
	$timer.Add_Tick({
		if (-not [string]::IsNullOrWhiteSpace([string]$syncHash.Status))
		{
			Set-GuiWindowsUpdateStatus -Message ([string]$syncHash.Status)
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
			Complete-GuiWindowsUpdateOperation -Payload $payload
		}
		catch
		{
			Set-GuiWindowsUpdateStatus -Message ('Windows Update operation failed: {0}' -f $_.Exception.Message) -State 'Error'
			if ($showFailureScript)
			{
				& $showFailureScript -Context ('WindowsUpdate.{0}' -f $Action) -Exception $_.Exception -ShowDialog
			}
			else
			{
				Write-Warning ("Windows Update operation failed [{0}]: {1}" -f $Action, $_.Exception.Message)
			}
		}
		finally
		{
			$Script:WindowsUpdateOperationInProgress = $false
			Update-GuiWindowsUpdateActionState
			try { $ps.Dispose() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'UpdatesPanel.Start-GuiWindowsUpdateOperation.DisposePowerShell' }
			try { $runspace.Dispose() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'UpdatesPanel.Start-GuiWindowsUpdateOperation.DisposeRunspace' }
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

	$Script:BtnWindowsUpdateScan = New-GuiWindowsUpdateActionButton -Label 'Scan for Updates' -Variant 'Primary' -Action { Start-GuiWindowsUpdateOperation -Action 'Scan' }
	$Script:BtnWindowsUpdateDownload = New-GuiWindowsUpdateActionButton -Label 'Download Only' -Variant 'Secondary' -Action { Start-GuiWindowsUpdateOperation -Action 'Download' }
	$Script:BtnWindowsUpdateInstall = New-GuiWindowsUpdateActionButton -Label 'Install Selected' -Variant 'Secondary' -Action { Start-GuiWindowsUpdateOperation -Action 'Install' }
	$Script:BtnWindowsUpdateHistory = New-GuiWindowsUpdateActionButton -Label 'Refresh History' -Variant 'Subtle' -Action { Start-GuiWindowsUpdateOperation -Action 'History' }

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
