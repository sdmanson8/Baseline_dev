<#
    .SYNOPSIS
    Internal function Add-GuiPopupWindowChrome.
#>
function Add-GuiPopupWindowChrome
{
	<# .SYNOPSIS Adds a shared title bar with minimize and close buttons to a borderless picker window. #>
	param(
		[Parameter(Mandatory = $true)]
		[System.Windows.Window]$Window,

		[Parameter(Mandatory = $true)]
		[System.Windows.Controls.Border]$RootBorder,

		[System.Windows.Controls.Panel]$PanelContainer = $null,

		[string]$Title = $null,

		[hashtable]$Theme = $null,

		[object]$UseDarkMode = $true
	)

	$resolvedUseDarkMode = Get-GuiBooleanValue -Value $UseDarkMode -Default $true -Context 'Add-GuiPopupWindowChrome'

	if (-not $Window -or -not $RootBorder)
	{
		return $false
	}

	try
	{
		if ((Test-GuiObjectField -Object $Window -FieldName 'GuiPopupChromeApplied') -and [bool]$Window.GuiPopupChromeApplied)
		{
			return $true
		}
	}
	catch
	{
		$null = $_
	}

	$contentElement = $RootBorder.Child
	if (-not $contentElement)
	{
		return $false
	}

	try
	{
		$RootBorder.Child = $null
	}
	catch
	{
		$null = $_
	}

	$bc = $Script:SharedBrushConverter
	$themeRef = if ($Theme) { $Theme } elseif (Test-GuiObjectField -Object $Script:CurrentTheme -FieldName 'WindowBg') { $Script:CurrentTheme } else { @{} }
	$fallbackWindowBg = if ($resolvedUseDarkMode) { '#1E1E2E' } else { '#F3F3F3' }
	$fallbackHeaderBg = if ($resolvedUseDarkMode) { '#181825' } else { '#FFFFFF' }
	$fallbackBorderColor = if ($resolvedUseDarkMode) { '#333346' } else { '#D0D0D0' }
	$fallbackTextPrimary = if ($resolvedUseDarkMode) { '#CDD6F4' } else { '#1F1F1F' }

	$getThemeColor = {
		param(
			[string]$ColorName,
			[string]$DefaultColor
		)

		try
		{
			if ($themeRef -and ($themeRef -is [System.Collections.IDictionary]) -and $themeRef.Contains($ColorName))
			{
				$value = [string]$themeRef[$ColorName]
				if (-not [string]::IsNullOrWhiteSpace($value))
				{
					return $value
				}
			}
		}
		catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Add-GuiPopupWindowChrome.ResolveThemeColor' }

		return $DefaultColor
	}.GetNewClosure()

	$windowTitle = if ([string]::IsNullOrWhiteSpace([string]$Title)) { [string]$Window.Title } else { [string]$Title }
	$Window.Title = $windowTitle

	$titleBarBackground = & $getThemeColor -ColorName 'HeaderBg' -DefaultColor (& $getThemeColor -ColorName 'WindowBg' -DefaultColor $fallbackHeaderBg)
	$titleBarTextColor = & $getThemeColor -ColorName 'TextPrimary' -DefaultColor $fallbackTextPrimary
	$borderColor = & $getThemeColor -ColorName 'BorderColor' -DefaultColor $fallbackBorderColor
	$closeLabel = 'Close'
	if (Test-Path -Path Function:\Get-UxLocalizedString)
	{
		try
		{
			$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'
		}
		catch
		{
			$closeLabel = 'Close'
		}
	}

	$titleBar = New-Object System.Windows.Controls.Border
	$titleBar.Background = $bc.ConvertFromString($titleBarBackground)
	$titleBar.BorderBrush = $bc.ConvertFromString($borderColor)
	$titleBar.BorderThickness = [System.Windows.Thickness]::new(0, 0, 0, 1)
	$titleBar.CornerRadius = [System.Windows.CornerRadius]::new(8, 8, 0, 0)
	$titleBar.Padding = [System.Windows.Thickness]::new(12, 8, 8, 8)
	$titleBar.Cursor = [System.Windows.Input.Cursors]::Arrow
	$titleBar.SnapsToDevicePixels = $true

	$titleGrid = New-Object System.Windows.Controls.Grid
	$titleGrid.SnapsToDevicePixels = $true
	$titleColumn = New-Object System.Windows.Controls.ColumnDefinition
	$titleColumn.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
	$titleColumn.MinWidth = 120
	$buttonsColumn = New-Object System.Windows.Controls.ColumnDefinition
	$buttonsColumn.Width = [System.Windows.GridLength]::Auto
	[void]$titleGrid.ColumnDefinitions.Add($titleColumn)
	[void]$titleGrid.ColumnDefinitions.Add($buttonsColumn)

	$titleBlock = New-Object System.Windows.Controls.TextBlock
	$titleBlock.Text = $windowTitle
	$titleBlock.VerticalAlignment = 'Center'
	$titleBlock.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe UI')
	$titleBlock.FontSize = 12
	$titleBlock.FontWeight = [System.Windows.FontWeights]::SemiBold
	$titleBlock.Foreground = $bc.ConvertFromString($titleBarTextColor)
	$titleBlock.TextTrimming = 'CharacterEllipsis'
	[System.Windows.Controls.Grid]::SetColumn($titleBlock, 0)
	[void]$titleGrid.Children.Add($titleBlock)

	$buttonStack = New-Object System.Windows.Controls.StackPanel
	$buttonStack.Orientation = 'Horizontal'
	$buttonStack.HorizontalAlignment = 'Right'
	$buttonStack.VerticalAlignment = 'Center'
	[System.Windows.Controls.Grid]::SetColumn($buttonStack, 1)

	$windowRef = $Window
	$minimizeButton = New-Object System.Windows.Controls.Button
	$minimizeButton.Content = [char]0x2212
	$minimizeButton.FontFamily = [System.Windows.Media.FontFamily]::new('Arial')
	$minimizeButton.FontSize = 12
	$minimizeButton.Width = 36
	$minimizeButton.Height = 28
	$minimizeButton.Background = [System.Windows.Media.Brushes]::Transparent
	$minimizeButton.BorderThickness = [System.Windows.Thickness]::new(0)
	$minimizeButton.Cursor = [System.Windows.Input.Cursors]::Hand
	$minimizeButton.HorizontalContentAlignment = 'Center'
	$minimizeButton.VerticalContentAlignment = 'Center'
	$minimizeButton.ToolTip = 'Minimize'
	if (Test-Path -Path Function:\Set-WindowCaptionButtonStyle)
	{
		try { Set-WindowCaptionButtonStyle -Button $minimizeButton } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Add-GuiPopupWindowChrome.SetMinimizeButtonStyle' }
	}
	$minimizeButton.Add_Click({ $windowRef.WindowState = [System.Windows.WindowState]::Minimized }.GetNewClosure())

	$closeButton = New-Object System.Windows.Controls.Button
	$closeButton.Content = '×'
	$closeButton.FontFamily = [System.Windows.Media.FontFamily]::new('Arial')
	$closeButton.FontSize = 12
	$closeButton.Width = 36
	$closeButton.Height = 28
	$closeButton.Background = [System.Windows.Media.Brushes]::Transparent
	$closeButton.BorderThickness = [System.Windows.Thickness]::new(0)
	$closeButton.Cursor = [System.Windows.Input.Cursors]::Hand
	$closeButton.HorizontalContentAlignment = 'Center'
	$closeButton.VerticalContentAlignment = 'Center'
	$closeButton.ToolTip = $closeLabel
	if (Test-Path -Path Function:\Set-WindowCaptionButtonStyle)
	{
		try { Set-WindowCaptionButtonStyle -Button $closeButton -Variant 'Close' } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Add-GuiPopupWindowChrome.SetCloseButtonStyle' }
	}
	$closeButton.Add_Click({ $windowRef.Close() }.GetNewClosure())
	$closeButton.Margin = [System.Windows.Thickness]::new(0, 0, 0, 0)
	$minimizeButton.Margin = [System.Windows.Thickness]::new(0, 0, 4, 0)

	[void]$buttonStack.Children.Add($minimizeButton)
	[void]$buttonStack.Children.Add($closeButton)
	[void]$titleGrid.Children.Add($buttonStack)
	$titleBar.Child = $titleGrid
	$titleBar.Add_MouseLeftButtonDown({ $windowRef.DragMove() }.GetNewClosure())

	$menu = New-Object System.Windows.Controls.ContextMenu
	$miMinimize = New-Object System.Windows.Controls.MenuItem
	$miMinimize.Header = 'Minimize'
	$miMinimize.Add_Click({ $windowRef.WindowState = [System.Windows.WindowState]::Minimized }.GetNewClosure())
	$miClose = New-Object System.Windows.Controls.MenuItem
	$miClose.Header = $closeLabel
	$miClose.InputGestureText = 'Alt+F4'
	$miClose.FontWeight = [System.Windows.FontWeights]::Bold
	$miClose.Add_Click({ $windowRef.Close() }.GetNewClosure())
	[void]$menu.Items.Add($miMinimize)
	[void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))
	[void]$menu.Items.Add($miClose)
	$titleBar.ContextMenu = $menu

	$popupDock = New-Object System.Windows.Controls.DockPanel
	$popupDock.LastChildFill = $true
	[System.Windows.Controls.DockPanel]::SetDock($titleBar, [System.Windows.Controls.Dock]::Top)
	[void]$popupDock.Children.Add($titleBar)

	$progressHost = New-Object System.Windows.Controls.Border
	$progressHost.Margin = [System.Windows.Thickness]::new(12, 6, 12, 0)
	$progressHost.Height = [double]$Script:GuiLayout.PopupProgressBarHeight
	$progressHost.MinWidth = [double]$Script:GuiLayout.PopupProgressBarMinWidth
	$progressHost.CornerRadius = [System.Windows.CornerRadius]::new(2)
	$progressHost.Background = $bc.ConvertFromString($(if ($Theme.CardBorder) { $Theme.CardBorder } else { $borderColor }))
	$progressHost.Visibility = [System.Windows.Visibility]::Collapsed
	$progressHost.SnapsToDevicePixels = $true

	$progressBar = New-Object System.Windows.Controls.ProgressBar
	$progressBar.Minimum = 0
	$progressBar.Maximum = 100
	$progressBar.Value = 0
	$progressBar.IsIndeterminate = $true
	$progressBar.BorderThickness = [System.Windows.Thickness]::new(0)
	$progressBar.Background = $bc.ConvertFromString($(if ($Theme.CardBorder) { $Theme.CardBorder } else { $borderColor }))
	$progressBar.Foreground = $bc.ConvertFromString($(if ($Theme.AccentBlue) { $Theme.AccentBlue } else { $titleBarTextColor }))
	$progressBar.HorizontalAlignment = 'Stretch'
	$progressBar.VerticalAlignment = 'Stretch'
	$progressBar.SnapsToDevicePixels = $true
	$progressHost.Child = $progressBar

	$progressInserted = $false
	if ($contentElement -is [System.Windows.Controls.Grid])
	{
		$contentGrid = [System.Windows.Controls.Grid]$contentElement
		$rowDefinitions = $contentGrid.RowDefinitions
		if ($rowDefinitions -and $rowDefinitions.Count -gt 0)
		{
			$insertRowIndex = [Math]::Max(0, $rowDefinitions.Count - 1)
			$progressRow = New-Object System.Windows.Controls.RowDefinition
			$progressRow.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Auto)
			$rowDefinitions.Insert($insertRowIndex, $progressRow)

			foreach ($child in @($contentGrid.Children))
			{
				$childRow = [System.Windows.Controls.Grid]::GetRow($child)
				if ($childRow -ge $insertRowIndex)
				{
					[System.Windows.Controls.Grid]::SetRow($child, $childRow + 1)
				}
			}

			[System.Windows.Controls.Grid]::SetRow($progressHost, $insertRowIndex)
			[System.Windows.Controls.Grid]::SetColumnSpan($progressHost, [Math]::Max(1, [int]$contentGrid.ColumnDefinitions.Count))
			[void]$contentGrid.Children.Add($progressHost)
			$progressInserted = $true
		}
	}

	if (-not $progressInserted)
	{
		[void]$popupDock.Children.Add($progressHost)
	}

	[void]$popupDock.Children.Add($contentElement)
	$RootBorder.Child = $popupDock

	try
	{
		if ((Test-GuiObjectField -Object $Window -FieldName 'GuiPopupRootBorder'))
		{
			$Window.GuiPopupRootBorder = $RootBorder
		}
		else
		{
			$Window | Add-Member -NotePropertyName 'GuiPopupRootBorder' -NotePropertyValue $RootBorder -Force
		}
		if ((Test-GuiObjectField -Object $Window -FieldName 'GuiPopupContentElement'))
		{
			$Window.GuiPopupContentElement = $contentElement
		}
		else
		{
			$Window | Add-Member -NotePropertyName 'GuiPopupContentElement' -NotePropertyValue $contentElement -Force
		}
		if ((Test-GuiObjectField -Object $Window -FieldName 'GuiPopupTitleBar'))
		{
			$Window.GuiPopupTitleBar = $titleBar
		}
		else
		{
			$Window | Add-Member -NotePropertyName 'GuiPopupTitleBar' -NotePropertyValue $titleBar -Force
		}
		if ((Test-GuiObjectField -Object $Window -FieldName 'GuiPopupTitleText'))
		{
			$Window.GuiPopupTitleText = $titleBlock
		}
		else
		{
			$Window | Add-Member -NotePropertyName 'GuiPopupTitleText' -NotePropertyValue $titleBlock -Force
		}
		if ((Test-GuiObjectField -Object $Window -FieldName 'GuiPopupMinimizeButton'))
		{
			$Window.GuiPopupMinimizeButton = $minimizeButton
		}
		else
		{
			$Window | Add-Member -NotePropertyName 'GuiPopupMinimizeButton' -NotePropertyValue $minimizeButton -Force
		}
		if ((Test-GuiObjectField -Object $Window -FieldName 'GuiPopupCloseButton'))
		{
			$Window.GuiPopupCloseButton = $closeButton
		}
		else
		{
			$Window | Add-Member -NotePropertyName 'GuiPopupCloseButton' -NotePropertyValue $closeButton -Force
		}
		if ($PanelContainer)
		{
			if ((Test-GuiObjectField -Object $Window -FieldName 'GuiPopupThemePanelContainer'))
			{
				$Window.GuiPopupThemePanelContainer = $PanelContainer
			}
			else
			{
				$Window | Add-Member -NotePropertyName 'GuiPopupThemePanelContainer' -NotePropertyValue $PanelContainer -Force
			}
		}
		if ((Test-GuiObjectField -Object $Window -FieldName 'GuiPopupProgressHost'))
		{
			$Window.GuiPopupProgressHost = $progressHost
		}
		else
		{
			$Window | Add-Member -NotePropertyName 'GuiPopupProgressHost' -NotePropertyValue $progressHost -Force
		}
		if ((Test-GuiObjectField -Object $Window -FieldName 'GuiPopupProgressBar'))
		{
			$Window.GuiPopupProgressBar = $progressBar
		}
		else
		{
			$Window | Add-Member -NotePropertyName 'GuiPopupProgressBar' -NotePropertyValue $progressBar -Force
		}
		[void](Register-GuiPopupThemeWindow -Window $Window)
	}
	catch
	{
		$null = $_
	}

	try
	{
		if ((Test-GuiObjectField -Object $Window -FieldName 'GuiPopupChromeApplied'))
		{
			$Window.GuiPopupChromeApplied = $true
		}
		else
		{
			$Window | Add-Member -NotePropertyName 'GuiPopupChromeApplied' -NotePropertyValue $true -Force
		}
	}
	catch
	{
		$null = $_
	}

	[void](Set-GuiPopupWindowTheme -Window $Window -Theme $Theme -UseDarkMode:$resolvedUseDarkMode)

	return $true
}

<#
    .SYNOPSIS
    Internal function Show-GuiActivatedDialog.
#>
function Show-GuiActivatedDialog
{
	# Without forcing activation, WPF dialogs sometimes open unactivated and the
	# first click only focuses the window instead of firing the control. A short
	# Topmost toggle on Loaded and ContentRendered reliably pulls the dialog to the
	# foreground and keeps first interaction consistent.
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[System.Windows.Window]$Window
	)

	$activate = {
		param($s, $e)
		$null = $e
		try { if (-not $s.IsVisible) { return } } catch { return }
		try { $s.Topmost = $true } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.FocusSelf.TopmostOn' }
		try { [void]$s.Activate() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.FocusSelf.Activate' }
		try { [void]$s.Focus() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.FocusSelf.Focus' }
		try { $s.Topmost = $false } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.FocusSelf.TopmostOff' }
	}

	$Window.Add_Loaded($activate)
	$Window.Add_ContentRendered($activate)

	return $Window.ShowDialog()
}

<#
    .SYNOPSIS
    Internal function Register-GuiPopupThemeWindow.
#>
function Register-GuiPopupThemeWindow
{
	<# .SYNOPSIS Registers an existing popup window for global theme updates and an optional repaint callback. #>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[System.Windows.Window]$Window,

		[Parameter(Mandatory = $false)]
		[scriptblock]$ThemeCallback = $null
	)

	if (-not $Window)
	{
		return $false
	}

	try
	{
		if ($ThemeCallback)
		{
			if ((Test-GuiObjectField -Object $Window -FieldName 'GuiPopupThemeCallback'))
			{
				$Window.GuiPopupThemeCallback = $ThemeCallback
			}
			else
			{
				$Window | Add-Member -NotePropertyName 'GuiPopupThemeCallback' -NotePropertyValue $ThemeCallback -Force
			}
		}

		if (-not $Script:GuiPopupThemeWindows.Contains($Window))
		{
			[void]$Script:GuiPopupThemeWindows.Add($Window)
		}

		$registrationAttached = $false
		if ((Test-GuiObjectField -Object $Window -FieldName 'GuiPopupThemeRegistrationAttached'))
		{
			$registrationAttached = [bool]$Window.GuiPopupThemeRegistrationAttached
		}

		if (-not $registrationAttached)
		{
			$Window.Add_Closed({
				param($sender, $eventArgs)
				try
				{
					if ($Script:GuiPopupThemeWindows)
					{
						[void]$Script:GuiPopupThemeWindows.Remove($sender)
					}
				}
				catch
				{
					$null = $_
				}
			}.GetNewClosure())

			if ((Test-GuiObjectField -Object $Window -FieldName 'GuiPopupThemeRegistrationAttached'))
			{
				$Window.GuiPopupThemeRegistrationAttached = $true
			}
			else
			{
				$Window | Add-Member -NotePropertyName 'GuiPopupThemeRegistrationAttached' -NotePropertyValue $true -Force
			}
		}
	}
	catch
	{
		Write-GuiCommonWarning ("Failed to register popup window for theme updates: {0}" -f $_.Exception.Message)
		return $false
	}

	return $true
}

<#
    .SYNOPSIS
    Internal function Set-GuiPopupWindowProgress.
#>
function Set-GuiPopupWindowProgress
{
	<# .SYNOPSIS Shows or hides the shared miniature progress strip on a popup window. #>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[System.Windows.Window]$Window,

		[Parameter(Mandatory = $false)]
		[bool]$Visible = $true,

		[Parameter(Mandatory = $false)]
		[switch]$Indeterminate,

		[Parameter(Mandatory = $false)]
		[int]$Completed = 0,

		[Parameter(Mandatory = $false)]
		[int]$Total = 0
	)

	if (-not $Window)
	{
		return $false
	}

	$progressHost = Get-GuiObjectField -Object $Window -FieldName 'GuiPopupProgressHost'
	$progressBar = Get-GuiObjectField -Object $Window -FieldName 'GuiPopupProgressBar'
	if (-not $progressHost -or -not $progressBar)
	{
		return $false
	}

	try
	{
		if ($Visible)
		{
			$progressHost.Visibility = [System.Windows.Visibility]::Visible
			if ($Indeterminate -or $Total -le 0)
			{
				$progressBar.IsIndeterminate = $true
				$progressBar.Maximum = 1
				$progressBar.Value = 0
			}
			else
			{
				$safeTotal = [Math]::Max(1, $Total)
				$safeCompleted = [Math]::Min([Math]::Max(0, $Completed), $safeTotal)
				$progressBar.IsIndeterminate = $false
				$progressBar.Maximum = $safeTotal
				$progressBar.Value = $safeCompleted
			}
		}
		else
		{
			$progressHost.Visibility = [System.Windows.Visibility]::Collapsed
			$progressBar.IsIndeterminate = $false
			$progressBar.Maximum = 1
			$progressBar.Value = 0
		}
	}
	catch
	{
		$null = $_
	}

	return $true
}

<#
    .SYNOPSIS
    Internal function Set-GuiPopupWindowTheme.
#>
function Set-GuiPopupWindowTheme
{
	<# .SYNOPSIS Applies the shared popup chrome surface colors to an open popup window. #>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[System.Windows.Window]$Window,

		[Parameter(Mandatory = $false)]
		[hashtable]$Theme = $null,

		[Parameter(Mandatory = $false)]
		[object]$UseDarkMode = $true
	)

	$resolvedUseDarkMode = Get-GuiBooleanValue -Value $UseDarkMode -Default $true -Context 'Set-GuiPopupWindowTheme'

	if (-not $Window)
	{
		return $false
	}

	$bc = $Script:SharedBrushConverter
	$themeRef = if ($Theme) { $Theme } elseif (Test-GuiObjectField -Object $Script:CurrentTheme -FieldName 'WindowBg') { $Script:CurrentTheme } else { @{} }
	$fallbackWindowBg = if ($resolvedUseDarkMode) { '#1E1E2E' } else { '#F3F3F3' }
	$fallbackHeaderBg = if ($resolvedUseDarkMode) { '#181825' } else { '#FFFFFF' }
	$fallbackBorderColor = if ($resolvedUseDarkMode) { '#333346' } else { '#D0D0D0' }
	$fallbackTextPrimary = if ($resolvedUseDarkMode) { '#CDD6F4' } else { '#1F1F1F' }
	$fallbackAccentBlue = if ($resolvedUseDarkMode) { '#89B4FA' } else { '#3B82F6' }

	$getThemeColor = {
		param(
			[string]$ColorName,
			[string]$DefaultColor
		)

		try
		{
			if ($themeRef -and ($themeRef -is [System.Collections.IDictionary]) -and $themeRef.Contains($ColorName))
			{
				$value = [string]$themeRef[$ColorName]
				if (-not [string]::IsNullOrWhiteSpace($value))
				{
					return $value
				}
			}
		}
		catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.ResolveThemeColor' }

		return $DefaultColor
	}.GetNewClosure()

	$windowBg = & $getThemeColor -ColorName 'WindowBg' -DefaultColor $fallbackWindowBg
	$panelBg = & $getThemeColor -ColorName 'PanelBg' -DefaultColor $windowBg
	$titleBarBackground = & $getThemeColor -ColorName 'HeaderBg' -DefaultColor (& $getThemeColor -ColorName 'WindowBg' -DefaultColor $fallbackHeaderBg)
	$titleBarTextColor = & $getThemeColor -ColorName 'TextPrimary' -DefaultColor $fallbackTextPrimary
	$borderColor = & $getThemeColor -ColorName 'BorderColor' -DefaultColor $fallbackBorderColor
	$accentBlue = & $getThemeColor -ColorName 'AccentBlue' -DefaultColor $fallbackAccentBlue

	try { $Window.Background = $bc.ConvertFromString($windowBg) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.SetWindowBackground' }
	try { $Window.Foreground = $bc.ConvertFromString($titleBarTextColor) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.SetWindowForeground' }

	$rootBorder = Get-GuiObjectField -Object $Window -FieldName 'GuiPopupRootBorder'
	if ($rootBorder)
	{
		try { $rootBorder.Background = $bc.ConvertFromString($windowBg) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.SetRootBorderBackground' }
		try { $rootBorder.BorderBrush = $bc.ConvertFromString($borderColor) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.SetRootBorderBorderBrush' }
		try { $rootBorder.BorderThickness = [System.Windows.Thickness]::new(1) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.SetRootBorderThickness' }
	}

	$titleBar = Get-GuiObjectField -Object $Window -FieldName 'GuiPopupTitleBar'
	if ($titleBar)
	{
		try { $titleBar.Background = $bc.ConvertFromString($titleBarBackground) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.SetTitleBarBackground' }
		try { $titleBar.BorderBrush = $bc.ConvertFromString($borderColor) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.SetTitleBarBorderBrush' }
		try { $titleBar.BorderThickness = [System.Windows.Thickness]::new(0, 0, 0, 1) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.SetTitleBarBorderThickness' }
	}

	$titleText = Get-GuiObjectField -Object $Window -FieldName 'GuiPopupTitleText'
	if ($titleText)
	{
		try { $titleText.Foreground = $bc.ConvertFromString($titleBarTextColor) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.SetTitleTextForeground' }
	}

	$panelContainer = Get-GuiObjectField -Object $Window -FieldName 'GuiPopupThemePanelContainer'
	if ($panelContainer)
	{
		try { $panelContainer.Background = $bc.ConvertFromString($panelBg) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.SetPanelContainerBackground' }
	}

	$progressHost = Get-GuiObjectField -Object $Window -FieldName 'GuiPopupProgressHost'
	if ($progressHost)
	{
		try { $progressHost.Background = $bc.ConvertFromString($borderColor) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.SetProgressHostBackground' }
	}

	$progressBar = Get-GuiObjectField -Object $Window -FieldName 'GuiPopupProgressBar'
	if ($progressBar)
	{
		try
		{
			$progressBar.Background = $bc.ConvertFromString($borderColor)
			$progressBar.Foreground = $bc.ConvertFromString($accentBlue)
		}
		catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.SetProgressBarBrushes' }
	}

	$minimizeButton = Get-GuiObjectField -Object $Window -FieldName 'GuiPopupMinimizeButton'
	if ($minimizeButton -and (Get-Command -Name 'Set-WindowCaptionButtonStyle' -ErrorAction SilentlyContinue))
	{
		try { Set-WindowCaptionButtonStyle -Button $minimizeButton } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.SetPopupMinimizeButtonStyle' }
	}

	$closeButton = Get-GuiObjectField -Object $Window -FieldName 'GuiPopupCloseButton'
	if ($closeButton -and (Get-Command -Name 'Set-WindowCaptionButtonStyle' -ErrorAction SilentlyContinue))
	{
		try { Set-WindowCaptionButtonStyle -Button $closeButton -Variant 'Close' } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.SetPopupCloseButtonStyle' }
	}

	try
	{
		if (Test-Path -Path Function:\Set-GuiWindowChromeTheme)
		{
			[void](Set-GuiWindowChromeTheme -Window $Window -UseDarkMode:$resolvedUseDarkMode)
		}
	}
	catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Set-GuiPopupWindowTheme.ApplyChrome' }

	$themeCallback = Get-GuiObjectField -Object $Window -FieldName 'GuiPopupThemeCallback'
	if ($themeCallback -is [scriptblock])
	{
		try
		{
			& $themeCallback -Window $Window -Theme $themeRef -UseDarkMode $resolvedUseDarkMode
		}
		catch
		{
			Write-GuiCommonWarning ("Failed to run popup theme callback for window '{0}': {1}" -f [string]$Window.Title, $_.Exception.Message)
		}
	}

	return $true
}

<#
    .SYNOPSIS
    Internal function Update-GuiPopupWindowThemes.
#>
function Update-GuiPopupWindowThemes
{
	<# .SYNOPSIS Repaints all registered popup windows for the current theme. #>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $false)]
		[hashtable]$Theme = $null,

		[Parameter(Mandatory = $false)]
		[object]$UseDarkMode = $true
	)

	$resolvedUseDarkMode = Get-GuiBooleanValue -Value $UseDarkMode -Default $true -Context 'Update-GuiPopupWindowThemes'

	if (-not $Script:GuiPopupThemeWindows -or $Script:GuiPopupThemeWindows.Count -eq 0)
	{
		return 0
	}

	$updatedCount = 0
	foreach ($window in @($Script:GuiPopupThemeWindows))
	{
		if (-not $window)
		{
			continue
		}

		try
		{
			if (-not [bool]$window.IsLoaded -and -not [bool]$window.IsVisible)
			{
				[void]$Script:GuiPopupThemeWindows.Remove($window)
				continue
			}
		}
		catch
		{
			# If a window has already torn down, prune it from the registry.
			[void]$Script:GuiPopupThemeWindows.Remove($window)
			continue
		}

			try
			{
				if (Set-GuiPopupWindowTheme -Window $window -Theme $Theme -UseDarkMode:$resolvedUseDarkMode)
				{
					$updatedCount++
				}
		}
		catch
		{
			Write-GuiCommonWarning ("Failed to update popup theme for an open window: {0}" -f $_.Exception.Message)
		}
	}

	return $updatedCount
}

<#
    .SYNOPSIS
    Internal function Start-GuiPopupCommandAsync.
#>
function Start-GuiPopupCommandAsync
{
	<# .SYNOPSIS Runs a popup action on a background STA runspace while the popup shows its miniature progress strip. #>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[System.Windows.Window]$Window,

		[Parameter(Mandatory = $true)]
		[string]$ModulePath,

		[Parameter(Mandatory = $true)]
		[string]$CommandName,

		[Parameter(Mandatory = $false)]
		[hashtable]$CommandParameters = @{},

		[Parameter(Mandatory = $false)]
		[string[]]$AdditionalModulePaths = @()
	)

	if (-not $Window -or [string]::IsNullOrWhiteSpace($ModulePath) -or [string]::IsNullOrWhiteSpace($CommandName))
	{
		return $false
	}

	try
	{
		if (Test-GuiObjectField -Object $Window -FieldName 'GuiPopupOperationError')
		{
			$Window.GuiPopupOperationError = $null
		}
		else
		{
			$Window | Add-Member -NotePropertyName 'GuiPopupOperationError' -NotePropertyValue $null -Force
		}

		if (Test-GuiObjectField -Object $Window -FieldName 'GuiPopupOperationResult')
		{
			$Window.GuiPopupOperationResult = $null
		}
		else
		{
			$Window | Add-Member -NotePropertyName 'GuiPopupOperationResult' -NotePropertyValue $null -Force
		}

		Set-GuiPopupWindowProgress -Window $Window -Visible $true -Indeterminate | Out-Null
	}
	catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Start-GuiPopupCommandAsync.InitializeOperationState' }

	$syncHash = [hashtable]::Synchronized(@{
		Done = $false
		Error = $null
		Result = $null
	})

	$runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
	$runspace.ApartmentState = 'STA'
	$runspace.ThreadOptions = 'ReuseThread'
	$runspace.Open()
	$ps = [System.Management.Automation.PowerShell]::Create()
	$ps.Runspace = $runspace

	$operation = {
		param(
			[string]$PopupModulePath,
			[string]$PopupCommandName,
			[hashtable]$PopupCommandParameters,
			[string[]]$PopupAdditionalModulePaths,
			[hashtable]$Sync
		)

		try
		{
			foreach ($path in @($PopupAdditionalModulePaths | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }))
			{
				Import-Module -Force -Name $path -ErrorAction Stop | Out-Null
			}

			Import-Module -Force -Name $PopupModulePath -ErrorAction Stop | Out-Null
			$Sync.Result = & $PopupCommandName @PopupCommandParameters
		}
		catch
		{
			$Sync.Error = $_
		}
		finally
		{
			$Sync.Done = $true
		}
	}.GetNewClosure()

	$null = $ps.AddScript($operation).
		AddArgument($ModulePath).
		AddArgument($CommandName).
		AddArgument($CommandParameters).
		AddArgument(@($AdditionalModulePaths)).
		AddArgument($syncHash)

	$asyncResult = $ps.BeginInvoke()
	$timer = [System.Windows.Threading.DispatcherTimer]::new()
	$timer.Interval = [TimeSpan]::FromMilliseconds(50)
	$timer.Add_Tick({
		if (-not $asyncResult.IsCompleted)
		{
			return
		}

		$timer.Stop()

		try { $ps.EndInvoke($asyncResult) | Out-Null } catch { if (-not $syncHash.Error) { $syncHash.Error = $_ } }
		try { $ps.Dispose() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Start-GuiPopupCommandAsync.DisposePowerShell' }
		try { $runspace.Close(); $runspace.Dispose() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Start-GuiPopupCommandAsync.DisposeRunspace' }

		try
		{
			if ($syncHash.Error)
			{
				if (Test-GuiObjectField -Object $Window -FieldName 'GuiPopupOperationError')
				{
					$Window.GuiPopupOperationError = $syncHash.Error
				}
				else
				{
					$Window | Add-Member -NotePropertyName 'GuiPopupOperationError' -NotePropertyValue $syncHash.Error -Force
				}
			}
			else
			{
				if (Test-GuiObjectField -Object $Window -FieldName 'GuiPopupOperationResult')
				{
					$Window.GuiPopupOperationResult = $syncHash.Result
				}
				else
				{
					$Window | Add-Member -NotePropertyName 'GuiPopupOperationResult' -NotePropertyValue $syncHash.Result -Force
				}
			}

			Set-GuiPopupWindowProgress -Window $Window -Visible $false | Out-Null
			$Window.Close()
		}
		catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PopupWindows.Start-GuiPopupCommandAsync.CompleteOperationState' }
	}.GetNewClosure())
	$timer.Start()

	return $true
}
