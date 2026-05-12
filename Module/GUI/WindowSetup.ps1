	if (-not [System.Windows.Application]::Current)
	{
		$Script:GuiApplication = [System.Windows.Application]::new()
	}
	$Script:InitialResolvedThemeName = 'Light'
	try
	{
		$startupThemeName = Get-BaselineStartupThemeName
		if ($startupThemeName -in @('Light', 'Dark')) { $Script:InitialResolvedThemeName = [string]$startupThemeName }
	}
	catch
	{
		Write-SwallowedException -ErrorRecord $_ -Source 'WindowSetup.ResolveInitialTheme'
	}
	[void](Set-GuiThemeResources -Target ([System.Windows.Application]::Current) -ThemeName $Script:InitialResolvedThemeName)

	$loadedForm = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $XAML))

	if (-not ($loadedForm -is [System.Windows.Window]))
	{
		throw "XAML root did not load as System.Windows.Window. Actual type: $($loadedForm.GetType().FullName)"
	}

	[System.Windows.Window]$Form = $loadedForm
	$Script:MainForm = $Form
	[void](Set-GuiThemeResources -Target $Form -ThemeName $Script:InitialResolvedThemeName)

	try
	{
		$selectWindowIconFrame = {
			param(
				[Parameter(Mandatory = $true)]
				[System.Collections.IEnumerable]
				$Frames,
				[Parameter(Mandatory = $true)]
				[int]$TargetPixelWidth
			)

			$closest = $Frames |
				Sort-Object -Property @{ Expression = { [Math]::Abs($_.PixelWidth - $TargetPixelWidth) } } |
				Select-Object -First 1
			return $closest
		}

		$repoBasePath = Split-Path -Path $Script:GuiModuleBasePath -Parent
		$windowIconPath = Join-Path -Path $repoBasePath -ChildPath 'Assets\baseline.ico'
		if (-not [string]::IsNullOrWhiteSpace([string]$windowIconPath) -and (Test-Path -LiteralPath $windowIconPath -PathType Leaf))
		{
			$windowIconUri = [System.Uri]::new([System.IO.Path]::GetFullPath($windowIconPath), [System.UriKind]::Absolute)
			$iconDecoder = [System.Windows.Media.Imaging.IconBitmapDecoder]::new(
				$windowIconUri,
				[System.Windows.Media.Imaging.BitmapCreateOptions]::None,
				[System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
			)
			$windowIconSource = if ($iconDecoder.Frames -and $iconDecoder.Frames.Count -gt 0)
			{
				& $selectWindowIconFrame -Frames $iconDecoder.Frames -TargetPixelWidth 32
			}
			else
			{
				$null
			}
			if (-not $windowIconSource)
			{
				$windowIconSource = [System.Windows.Media.Imaging.BitmapFrame]::Create($windowIconUri)
			}
			if ($windowIconSource -and $windowIconSource.CanFreeze)
			{
				$windowIconSource.Freeze()
			}
			$Form.Icon = $windowIconSource
			$titleBarLogo = $Form.FindName('TitleBarLogo')
			if ($titleBarLogo)
			{
				$titleBarLogo.Source = $windowIconSource
				[System.Windows.Media.RenderOptions]::SetBitmapScalingMode($titleBarLogo, [System.Windows.Media.BitmapScalingMode]::HighQuality)
				$titleBarLogo.SnapsToDevicePixels = $true
				$titleBarLogo.UseLayoutRounding = $true
			}
		}
	}
	catch
	{
		Write-GuiRuntimeWarning -Context 'WindowIcon' -Message $_.Exception.Message
	}

	# Size the window to 85% of the screen working area so it fits any resolution
	# without being full-screen. Falls back to safe defaults if the call fails.
	# When the user has a saved placement and it still falls
	# on a connected display we restore that instead.
	try
	{
		$workArea = [System.Windows.SystemParameters]::WorkArea
		$widthRatio = if ($workArea.Width -ge 2560) { 0.55 } elseif ($workArea.Width -ge 1920) { 0.65 } else { 0.85 }
		$targetW  = [Math]::Round($workArea.Width  * $widthRatio)
		$targetH  = [Math]::Round($workArea.Height * 0.85)
		$maxW = [Math]::Min(1400, $workArea.Width)

		# On small screens, clamp MinWidth to the available work area
		$effectiveMinW = [Math]::Min($guiWindowMinWidth, $workArea.Width)
		$effectiveMinH = [Math]::Min($guiWindowMinHeight, $workArea.Height)

		$defaultW = [Math]::Min([Math]::Max($targetW, $effectiveMinW), $maxW)
		$defaultH = [Math]::Min([Math]::Max($targetH, $effectiveMinH), $workArea.Height)
		$defaultLeft = $workArea.Left + (([double]$workArea.Width  - $defaultW) / 2.0)
		$defaultTop  = $workArea.Top  + (([double]$workArea.Height - $defaultH) / 2.0)

		$Form.MinWidth  = $effectiveMinW
		$Form.MinHeight = $effectiveMinH

		$placement = $null
		if (Get-Command -Name 'Resolve-BaselineWindowPlacement' -ErrorAction SilentlyContinue)
		{
			try
			{
				$defaultRect = [pscustomobject]@{
					Left   = [double]$defaultLeft
					Top    = [double]$defaultTop
					Width  = [double]$defaultW
					Height = [double]$defaultH
				}
				$placement = Resolve-BaselineWindowPlacement -DefaultRect $defaultRect
			}
			catch { Write-SwallowedException -ErrorRecord $_ -Source 'WindowSetup.ResolvePlacement'; $placement = $null }
		}

		if ($placement)
		{
			$Form.Width  = [Math]::Max([double]$placement.Width,  [double]$effectiveMinW)
			$Form.Height = [Math]::Max([double]$placement.Height, [double]$effectiveMinH)
			$Form.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
			$Form.Left = [double]$placement.Left
			$Form.Top  = [double]$placement.Top
			if ($placement.Maximized)
			{
				$Form.WindowState = [System.Windows.WindowState]::Maximized
			}
		}
		else
		{
			$Form.Width  = $defaultW
			$Form.Height = $defaultH
		}
	}
	catch
	{
		Write-SwallowedException -ErrorRecord $_ -Source 'WindowSetup.ApplyDefaultWindowBounds'
		$Form.MinWidth = $guiWindowMinWidth
		$Form.MinHeight = $guiWindowMinHeight
		$Form.Width  = [Math]::Max(940, $guiWindowMinWidth)
		$Form.Height = [Math]::Max(720, $guiWindowMinHeight)
	}
	$HeaderBorder    = $Form.FindName("HeaderBorder")
	$HeaderSeparator = $Form.FindName("HeaderSeparator")
	$TitleText       = $Form.FindName("TitleText")
	$WindowBorder  = $Form.FindName("RootBorder")
	$TitleBar      = $Form.FindName("TitleBar")
	$TitleBarText  = $Form.FindName("TitleBarText")
	$BtnMinimize   = $Form.FindName("BtnMinimize")
	$BtnMaximize   = $Form.FindName("BtnMaximize")
	$BtnClose      = $Form.FindName("BtnClose")

	# Wire custom title bar: drag, minimize, maximize, close
	if ($TitleBar)
	{
		$TitleBar.Add_MouseLeftButtonDown({
			if ($_.ClickCount -eq 2)
			{
				if ($Form.WindowState -eq [System.Windows.WindowState]::Maximized)
				{
					$Form.WindowState = [System.Windows.WindowState]::Normal
				}
				else
				{
					$Form.WindowState = [System.Windows.WindowState]::Maximized
				}
			}
			else
			{
				$Form.DragMove()
			}
		})
	}
	# System-style right-click context menu for the custom title bar
	if ($TitleBar)
	{
		$sysMenu = New-Object System.Windows.Controls.ContextMenu
		$miRestore = New-Object System.Windows.Controls.MenuItem
		$miRestore.Header = 'Restore'
		$miRestore.Add_Click({ $Form.WindowState = [System.Windows.WindowState]::Normal })
		$miMove = New-Object System.Windows.Controls.MenuItem
		$miMove.Header = 'Move'
		$miMove.IsEnabled = $false
		$miSize = New-Object System.Windows.Controls.MenuItem
		$miSize.Header = 'Size'
		$miSize.IsEnabled = $false
		$miMinimize = New-Object System.Windows.Controls.MenuItem
		$miMinimize.Header = 'Minimize'
		$miMinimize.Add_Click({ $Form.WindowState = [System.Windows.WindowState]::Minimized })
		$miMaximize = New-Object System.Windows.Controls.MenuItem
		$miMaximize.Header = 'Maximize'
		$miMaximize.Add_Click({ $Form.WindowState = [System.Windows.WindowState]::Maximized })
		$sep = New-Object System.Windows.Controls.Separator
		$miRememberPos = New-Object System.Windows.Controls.MenuItem
		$miRememberPos.Header = 'Remember Window Position'
		$miRememberPos.IsCheckable = $true
		$miRememberPos.ToolTip = 'Restore this window''s size and position on next launch.'
		try
		{
			if (Get-Command -Name 'Get-BaselineUserPreference' -ErrorAction SilentlyContinue)
			{
				$miRememberPos.IsChecked = [bool](Get-BaselineUserPreference -Key 'RememberWindowPosition' -Default $true)
			}
			else { $miRememberPos.IsChecked = $true }
		}
		catch { Write-SwallowedException -ErrorRecord $_ -Source 'WindowSetup.LoadRememberWindowPosition'; $miRememberPos.IsChecked = $true }
		$miRememberPos.Add_Click({
			try
			{
				if (Get-Command -Name 'Set-BaselineUserPreference' -ErrorAction SilentlyContinue)
				{
					Set-BaselineUserPreference -Key 'RememberWindowPosition' -Value ([bool]$miRememberPos.IsChecked)
				}
			}
			catch { Write-SwallowedException -ErrorRecord $_ -Source 'WindowSetup.RememberPositionToggle' 2>$null }
		})
		$sepRemember = New-Object System.Windows.Controls.Separator
		$miClose = New-Object System.Windows.Controls.MenuItem
		$miClose.Header = 'Close'
		$miClose.InputGestureText = 'Alt+F4'
		$miClose.FontWeight = [System.Windows.FontWeights]::Bold
		$miClose.Add_Click({ $Form.Close() })
		[void]$sysMenu.Items.Add($miRestore)
		[void]$sysMenu.Items.Add($miMove)
		[void]$sysMenu.Items.Add($miSize)
		[void]$sysMenu.Items.Add($miMinimize)
		[void]$sysMenu.Items.Add($miMaximize)
		[void]$sysMenu.Items.Add($sepRemember)
		[void]$sysMenu.Items.Add($miRememberPos)
		[void]$sysMenu.Items.Add($sep)
		[void]$sysMenu.Items.Add($miClose)
		$Script:TitleBarSystemMenu = $sysMenu
		$Script:TitleBarSystemMenuItems = @{ Restore = $miRestore; Minimize = $miMinimize; Maximize = $miMaximize; Move = $miMove; Size = $miSize }
		$sysMenu.Add_Opened({
			$isMax = $Form.WindowState -eq [System.Windows.WindowState]::Maximized
			$Script:TitleBarSystemMenuItems.Restore.IsEnabled = $isMax
			$Script:TitleBarSystemMenuItems.Maximize.IsEnabled = -not $isMax
			$Script:TitleBarSystemMenuItems.Move.IsEnabled = -not $isMax
			$Script:TitleBarSystemMenuItems.Size.IsEnabled = -not $isMax
		})
		$TitleBar.ContextMenu = $sysMenu
	}
	if ($BtnMinimize) { $BtnMinimize.Add_Click({ $Form.WindowState = [System.Windows.WindowState]::Minimized }) }
	if ($BtnMaximize)
	{
		$BtnMaximize.Add_Click({
			if ($Form.WindowState -eq [System.Windows.WindowState]::Maximized)
			{
				$Form.WindowState = [System.Windows.WindowState]::Normal
			}
			else
			{
				$Form.WindowState = [System.Windows.WindowState]::Maximized
			}
		})
	}
	if ($BtnClose) { $BtnClose.Add_Click({ $Form.Close() }) }

	# Persist window placement on close so the next launch
	# can restore it. Maximized windows save their RestoreBounds, not the
	# screen-filling rect, so the user gets a usable window on relaunch.
	$Form.Add_Closing({
		try
		{
			if (-not (Get-Command -Name 'Save-BaselineWindowPlacement' -ErrorAction SilentlyContinue)) { return }
			$rect = $null
			$isMax = $Form.WindowState -eq [System.Windows.WindowState]::Maximized
			if ($isMax)
			{
				$restore = $Form.RestoreBounds
				if (-not [System.Windows.Rect]::Empty.Equals($restore) -and $restore.Width -gt 0 -and $restore.Height -gt 0)
				{
					$rect = [pscustomobject]@{ Left = $restore.Left; Top = $restore.Top; Width = $restore.Width; Height = $restore.Height }
				}
			}
			else
			{
				$rect = [pscustomobject]@{ Left = $Form.Left; Top = $Form.Top; Width = $Form.Width; Height = $Form.Height }
			}
			if ($rect)
			{
				Save-BaselineWindowPlacement -Left ([double]$rect.Left) -Top ([double]$rect.Top) `
					-Width ([double]$rect.Width) -Height ([double]$rect.Height) -Maximized $isMax | Out-Null
			}
		}
		catch
		{
			Write-SwallowedException -ErrorRecord $_ -Source 'WindowSetup.SaveWindowPlacement' 2>$null
		}
	})

	# Adjust border radius when maximized (no rounding needed when filling screen)
	$Form.Add_StateChanged({
		if ($Form.WindowState -eq [System.Windows.WindowState]::Maximized)
		{
			$WindowBorder.CornerRadius = [System.Windows.CornerRadius]::new(0)
			$WindowBorder.Margin = [System.Windows.Thickness]::new(7)
			if ($TitleBar) { $TitleBar.CornerRadius = [System.Windows.CornerRadius]::new(0) }
			if ($BottomBorder) { $BottomBorder.CornerRadius = [System.Windows.CornerRadius]::new(0) }
		}
		else
		{
			$WindowBorder.CornerRadius = [System.Windows.CornerRadius]::new(8)
			$WindowBorder.Margin = [System.Windows.Thickness]::new(0)
			if ($TitleBar) { $TitleBar.CornerRadius = [System.Windows.CornerRadius]::new(8, 8, 0, 0) }
			if ($BottomBorder) { $BottomBorder.CornerRadius = [System.Windows.CornerRadius]::new(0, 0, 8, 8) }
		}
	})
	$PrimaryTabs   = $Form.FindName("PrimaryTabs")
	$PrimaryTabDropdown = $Form.FindName("PrimaryTabDropdown")
	$PrimaryTabHost = $Form.FindName("PrimaryTabHost")
	$ContentBorder = $Form.FindName("ContentBorder")
	$ContentScroll = $Form.FindName("ContentScroll")
	$ExpertModeBanner = $Form.FindName("ExpertModeBanner")
	$BottomBorder  = $Form.FindName("BottomBorder")
	if ($BottomBorder) { $BottomBorder.CornerRadius = [System.Windows.CornerRadius]::new(0, 0, 8, 8) }
	$StatusText    = $Form.FindName("StatusText")
	$Script:StatusTextControl = $StatusText
	$ActionButtonBar = $Form.FindName("ActionButtonBar")
	$BtnPreviewRun = $Form.FindName("BtnPreviewRun")
	$BtnRun        = $Form.FindName("BtnRun")
	$Script:RunPathContextLabel = $Form.FindName("RunPathContextLabel")
	$BtnDefaults   = $Form.FindName("BtnDefaults")
	$BtnExportSettings = $null
	$BtnImportSettings = $null
	$BtnRestoreSnapshot = $null
	$ChkTheme      = $Form.FindName("ChkTheme")
	$BtnLanguage   = $Form.FindName("BtnLanguage")
	$LanguagePopup = $Form.FindName("LanguagePopup")
	$LanguagePopupBorder = $Form.FindName("LanguagePopupBorder")
	$TxtLanguageSearch = $Form.FindName("TxtLanguageSearch")
	$TxtLanguageSearchPlaceholder = $Form.FindName("TxtLanguageSearchPlaceholder")
	$LanguageListPanel = $Form.FindName("LanguageListPanel")
	$TxtLanguageState = $Form.FindName("TxtLanguageState")
	$ChkSafeMode   = $Form.FindName("ChkSafeMode")
	$ChkGameMode   = $Form.FindName("ChkGameMode")
	$SafeModeGroup = $Form.FindName("SafeModeGroup")
	$ThemeToggleGroup = $Form.FindName("ThemeToggleGroup")
	$TxtAdvancedModeState = $Form.FindName("TxtAdvancedModeState")
	$TxtThemeState = $Form.FindName("TxtThemeState")
	$BtnStartHere  = $Form.FindName("BtnStartHere")
	$BtnHelp       = $Form.FindName("BtnHelp")
	$BtnLog        = $Form.FindName("BtnLog")
	$ChkScan       = $Form.FindName("ChkScan")
	$ScanLabel     = $Form.FindName("ScanLabel")
	$SearchLabel   = $Form.FindName("SearchLabel")
	$TxtSearch     = $Form.FindName("TxtSearch")
	$TxtSearchPlaceholder = $Form.FindName("TxtSearchPlaceholder")
	$BtnClearSearch = $Form.FindName("BtnClearSearch")
	$RiskFilterLabel = $Form.FindName("RiskFilterLabel")
	$CategoryFilterLabel = $Form.FindName("CategoryFilterLabel")
	$PlatformFilterLabel = $Form.FindName("PlatformFilterLabel")
	$ViewFilterLabel = $Form.FindName("ViewFilterLabel")
	$CmbRiskFilter = $Form.FindName("CmbRiskFilter")
	$CmbCategoryFilter = $Form.FindName("CmbCategoryFilter")
	$CmbPlatformFilter = $Form.FindName("CmbPlatformFilter")
	$ChkHideUnavailableItems = $Form.FindName("ChkHideUnavailableItems")
	$ChkSelectedOnly = $Form.FindName("ChkSelectedOnly")
	$ChkHighRiskOnly = $Form.FindName("ChkHighRiskOnly")
	$ChkRestorableOnly = $Form.FindName("ChkRestorableOnly")
	$ChkGamingOnly = $Form.FindName("ChkGamingOnly")
	$ChkDesignMode = $Form.FindName("ChkDesignMode")
	$BtnFilterToggle = $Form.FindName("BtnFilterToggle")
	$FilterOptionsPanel = $Form.FindName("FilterOptionsPanel")
	$NavModeTweaks = $Form.FindName("NavModeTweaks")
	$NavModeApps = $Form.FindName("NavModeApps")
	$NavModeUpdates = $Form.FindName("NavModeUpdates")
	$NavModeDeploymentMedia = $Form.FindName("NavModeDeploymentMedia")
	$ModeSubtitle = $Form.FindName("ModeSubtitle")
	$TweaksView = $Form.FindName("TweaksView")
	$DeploymentMediaView = $Form.FindName("DeploymentMediaView")
	$DeploymentMediaScroll = $Form.FindName("DeploymentMediaScroll")
	$DeploymentMediaWrapPanel = $Form.FindName("DeploymentMediaWrapPanel")
	$BtnDeploymentMediaDetectIso = $Form.FindName("BtnDeploymentMediaDetectIso")
	$BtnDeploymentMediaPreviewPlan = $Form.FindName("BtnDeploymentMediaPreviewPlan")
	$BtnDeploymentMediaStartBuild = $Form.FindName("BtnDeploymentMediaStartBuild")
	$DeploymentMediaStatusBanner = $Form.FindName("DeploymentMediaStatusBanner")
	$TxtDeploymentMediaSelectionStatus = $Form.FindName("TxtDeploymentMediaSelectionStatus")
	$TxtDeploymentMediaBuildStatus = $Form.FindName("TxtDeploymentMediaBuildStatus")
	$TxtDeploymentMediaSourceIso = $Form.FindName("TxtDeploymentMediaSourceIso")
	$BtnDeploymentMediaBrowseIso = $Form.FindName("BtnDeploymentMediaBrowseIso")
	$TxtDeploymentMediaEditionIndex = $Form.FindName("TxtDeploymentMediaEditionIndex")
	$CmbDeploymentMediaDetectedEdition = $Form.FindName("CmbDeploymentMediaDetectedEdition")
	$TxtDeploymentMediaDetectedIsoSummary = $Form.FindName("TxtDeploymentMediaDetectedIsoSummary")
	$TxtDeploymentMediaWorkingDirectory = $Form.FindName("TxtDeploymentMediaWorkingDirectory")
	$BtnDeploymentMediaBrowseWorking = $Form.FindName("BtnDeploymentMediaBrowseWorking")
	$CmbDeploymentMediaOutputMode = $Form.FindName("CmbDeploymentMediaOutputMode")
	$TxtDeploymentMediaUsbTargetRoot = $Form.FindName("TxtDeploymentMediaUsbTargetRoot")
	$BtnDeploymentMediaBrowseUsbTarget = $Form.FindName("BtnDeploymentMediaBrowseUsbTarget")
	$TxtDeploymentMediaAutounattend = $Form.FindName("TxtDeploymentMediaAutounattend")
	$BtnDeploymentMediaBrowseAutounattend = $Form.FindName("BtnDeploymentMediaBrowseAutounattend")
	$TxtDeploymentMediaDriverSource = $Form.FindName("TxtDeploymentMediaDriverSource")
	$BtnDeploymentMediaBrowseDrivers = $Form.FindName("BtnDeploymentMediaBrowseDrivers")
	$ChkDeploymentMediaBootDrivers = $Form.FindName("ChkDeploymentMediaBootDrivers")
	$ChkDeploymentMediaBaselineTweaks = $Form.FindName("ChkDeploymentMediaBaselineTweaks")
	$TxtDeploymentMediaPlanPreview = $Form.FindName("TxtDeploymentMediaPlanPreview")
	$AppsView = $Form.FindName("AppsView")
	$AppsScroll = $Form.FindName("AppsScroll")
	$AppsWrapPanel = $Form.FindName("AppsWrapPanel")
	$BtnUpdateAllApps = $Form.FindName("BtnUpdateAllApps")
	$AppsPackageManagerBanner = $Form.FindName("AppsPackageManagerBanner")
	$TxtAppsPackageManagerBanner = $Form.FindName("TxtAppsPackageManagerBanner")
	$AppsCategoryTabs = $Form.FindName("AppsCategoryTabs")
	$BtnAppsFilterToggle = $Form.FindName("BtnAppsFilterToggle")
	$AppsFilterOptionsPanel = $Form.FindName("AppsFilterOptionsPanel")
	$AppsSourceLabel = $Form.FindName("AppsSourceLabel")
	$AppsStatusLabel = $Form.FindName("AppsStatusLabel")
	$CmbAppsStatusFilter = $Form.FindName("CmbAppsStatusFilter")
	$TxtAppSelectionStatus = $Form.FindName("TxtAppSelectionStatus")
	$BtnInstallSelectedApps = $Form.FindName("BtnInstallSelectedApps")
	$BtnUninstallSelectedApps = $Form.FindName("BtnUninstallSelectedApps")
	$BtnUpdateSelectedApps = $Form.FindName("BtnUpdateSelectedApps")
	$BtnApplyQueuedActions = $Form.FindName("BtnApplyQueuedActions")
	$BtnClearQueuedActions = $Form.FindName("BtnClearQueuedActions")
	$BtnScanInstalledApps = $Form.FindName("BtnScanInstalledApps")
	$AppsActionSeparator1 = $Form.FindName("AppsActionSeparator1")
	$BtnAppsSourceFilterAll = $Form.FindName("BtnAppsSourceFilterAll")
	$BtnAppsSourceFilterWinGet = $Form.FindName("BtnAppsSourceFilterWinGet")
	$BtnAppsSourceFilterChocolatey = $Form.FindName("BtnAppsSourceFilterChocolatey")
	$AppsFilterViewDivider = $Form.FindName("AppsFilterViewDivider")
	$AppsViewModeLabel = $Form.FindName("AppsViewModeLabel")
	$BtnAppsViewCards = $Form.FindName("BtnAppsViewCards")
	$BtnAppsViewList = $Form.FindName("BtnAppsViewList")
	$BtnAppsAddCustom = $Form.FindName("BtnAppsAddCustom")
	$UpdateDialogOverlay = $Form.FindName("UpdateDialogOverlay")
	$UpdateDialogCard = $Form.FindName("UpdateDialogCard")
	$TxtOverlayTitle = $Form.FindName("TxtOverlayTitle")
	$TxtUpdateDescription = $Form.FindName("TxtUpdateDescription")
	$CustomPBarContainer = $Form.FindName("CustomPBarContainer")
	$TxtDownloadProgressLabel = $Form.FindName("TxtDownloadProgressLabel")
	$TxtDownloadProgressPct = $Form.FindName("TxtDownloadProgressPct")
	$BtnDownloadNo = $Form.FindName("BtnDownloadNo")
	$BtnDownloadYes = $Form.FindName("BtnDownloadYes")

	# --- Top Menu Bar controls ---
	$MenuBarBorder              = $Form.FindName("MenuBarBorder")
	$MainMenuBar                = $Form.FindName("MainMenuBar")
	$MenuFile                   = $Form.FindName("MenuFile")
	$MenuFileImportSettings     = $Form.FindName("MenuFileImportSettings")
	$MenuFileExportSettings     = $Form.FindName("MenuFileExportSettings")
	$MenuFileSettings           = $Form.FindName("MenuFileSettings")
	$MenuFileAuditSettings      = $Form.FindName("MenuFileAuditSettings")
	$MenuFileExportConfigProfile = $Form.FindName("MenuFileExportConfigProfile")
	$MenuFileExportSystemState  = $Form.FindName("MenuFileExportSystemState")
	$MenuFileExit               = $Form.FindName("MenuFileExit")
	$MenuActions                = $Form.FindName("MenuActions")
	$MenuActionsConnectToComputer = $Form.FindName("MenuActionsConnectToComputer")
	$MenuActionsDisconnect      = $Form.FindName("MenuActionsDisconnect")
	$RemoteModeBanner            = $Form.FindName("RemoteModeBanner")
	$RemoteModeBannerText        = $Form.FindName("RemoteModeBannerText")
	$BtnRemoteModeBannerDisconnect = $Form.FindName("BtnRemoteModeBannerDisconnect")
	$MenuActionsPreviewRun      = $Form.FindName("MenuActionsPreviewRun")
	$MenuActionsRunTweaks       = $Form.FindName("MenuActionsRunTweaks")
	$MenuActionsUndoLastRun     = $Form.FindName("MenuActionsUndoLastRun")
	$MenuActionsRestoreDefaults = $Form.FindName("MenuActionsRestoreDefaults")
	$MenuActionsCheckCompliance = $Form.FindName("MenuActionsCheckCompliance")
	$MenuActionsScanSystem      = $Form.FindName("MenuActionsScanSystem")
	$MenuActionsAuditLog        = $Form.FindName("MenuActionsAuditLog")
	$MenuActionsSep1            = $Form.FindName("MenuActionsSep1")
	$MenuActionsSep2            = $Form.FindName("MenuActionsSep2")
	$MenuActionsSep3            = $Form.FindName("MenuActionsSep3")
	$MenuView                   = $Form.FindName("MenuView")
	$MenuViewFilters            = $Form.FindName("MenuViewFilters")
	$MenuViewLogsPanel          = $Form.FindName("MenuViewLogsPanel")
	$MenuViewTheme              = $Form.FindName("MenuViewTheme")
	$MenuTools                  = $Form.FindName("MenuTools")
	$MenuToolsAppsManager       = $Form.FindName("MenuToolsAppsManager")
	$MenuToolsUpdateAllApps     = $Form.FindName("MenuToolsUpdateAllApps")
	$MenuToolsExportSupportBundle = $Form.FindName("MenuToolsExportSupportBundle")
	$MenuToolsAdvanced = $Form.FindName("MenuToolsAdvanced")
	$MenuToolsDeploymentMediaBuilder = $Form.FindName("MenuToolsDeploymentMediaBuilder")
	$MenuToolsApproveRemoteTargets = $Form.FindName("MenuToolsApproveRemoteTargets")
	$MenuToolsSaveRemoteApprovalPolicy = $Form.FindName("MenuToolsSaveRemoteApprovalPolicy")
	$MenuToolsLoadRemoteApprovalPolicy = $Form.FindName("MenuToolsLoadRemoteApprovalPolicy")
	$MenuToolsRemoteConsole = $Form.FindName("MenuToolsRemoteConsole")
	$MenuToolsOperatorConsole = $Form.FindName("MenuToolsOperatorConsole")
	$MenuToolsRemoteSessionStatus = $Form.FindName("MenuToolsRemoteSessionStatus")
	$MenuToolsRemovalPersistence = $Form.FindName("MenuToolsRemovalPersistence")
	$MenuToolsSepApps           = $Form.FindName("MenuToolsSepApps")
	$MenuHelp                   = $Form.FindName("MenuHelp")
	$MenuHelpHelp               = $Form.FindName("MenuHelpHelp")
	$MenuHelpStartGuide         = $Form.FindName("MenuHelpStartGuide")
	$MenuHelpReadme             = $Form.FindName("MenuHelpReadme")
	$MenuHelpFAQ                = $Form.FindName("MenuHelpFAQ")
	$MenuHelpChangelog          = $Form.FindName("MenuHelpChangelog")
	$MenuHelpCheckForUpdate     = $Form.FindName("MenuHelpCheckForUpdate")
	$MenuHelpReleaseStatus      = $Form.FindName("MenuHelpReleaseStatus")
	$MenuHelpTroubleshooting    = $Form.FindName("MenuHelpTroubleshooting")
	$MenuHelpAbout              = $Form.FindName("MenuHelpAbout")

	$Script:WindowBorder                 = $WindowBorder
	$Script:MenuBarBorder                = $MenuBarBorder
	$Script:MainMenuBar                  = $MainMenuBar
	$Script:MenuFile                     = $MenuFile
	$Script:MenuActions                  = $MenuActions
	$Script:MenuActionsConnectToComputer = $MenuActionsConnectToComputer
	$Script:MenuActionsDisconnect        = $MenuActionsDisconnect
	$Script:RemoteModeBanner             = $RemoteModeBanner
	$Script:RemoteModeBannerText         = $RemoteModeBannerText
	$Script:BtnRemoteModeBannerDisconnect = $BtnRemoteModeBannerDisconnect
	$Script:MenuView                     = $MenuView
	$Script:MenuTools                    = $MenuTools
	$Script:MenuHelp                     = $MenuHelp
	$Script:MenuViewFilters              = $MenuViewFilters
	$Script:MenuViewTheme                = $MenuViewTheme
	$Script:MenuActionsCheckCompliance   = $MenuActionsCheckCompliance
	$Script:MenuActionsScanSystem        = $MenuActionsScanSystem
	$Script:MenuActionsAuditLog          = $MenuActionsAuditLog
	$Script:MenuViewLogsPanel            = $MenuViewLogsPanel
	$Script:MenuHelpChangelog            = $MenuHelpChangelog
	$Script:MenuHelpCheckForUpdate       = $MenuHelpCheckForUpdate
	$Script:MenuActionsUndoLastRun       = $MenuActionsUndoLastRun
	$Script:MenuActionsRestoreDefaults   = $MenuActionsRestoreDefaults
	$Script:MenuActionsPreviewRun        = $MenuActionsPreviewRun
	$Script:MenuActionsRunTweaks         = $MenuActionsRunTweaks
	$Script:MenuFileExportSettings       = $MenuFileExportSettings
	$Script:MenuFileImportSettings       = $MenuFileImportSettings
	$Script:MenuFileSettings             = $MenuFileSettings
	$Script:MenuFileAuditSettings        = $MenuFileAuditSettings
	$Script:MenuFileExportConfigProfile  = $MenuFileExportConfigProfile
	$Script:MenuFileExportSystemState    = $MenuFileExportSystemState
	$Script:MenuToolsAppsManager         = $MenuToolsAppsManager
	$Script:MenuToolsUpdateAllApps       = $MenuToolsUpdateAllApps
	$Script:MenuToolsExportSupportBundle = $MenuToolsExportSupportBundle
	$Script:MenuToolsAdvanced = $MenuToolsAdvanced
	$Script:MenuToolsDeploymentMediaBuilder = $MenuToolsDeploymentMediaBuilder
	$Script:MenuToolsApproveRemoteTargets = $MenuToolsApproveRemoteTargets
	$Script:MenuToolsSaveRemoteApprovalPolicy = $MenuToolsSaveRemoteApprovalPolicy
	$Script:MenuToolsLoadRemoteApprovalPolicy = $MenuToolsLoadRemoteApprovalPolicy
	$Script:MenuToolsRemoteConsole = $MenuToolsRemoteConsole
	$Script:MenuToolsOperatorConsole = $MenuToolsOperatorConsole
	$Script:MenuToolsRemoteSessionStatus = $MenuToolsRemoteSessionStatus
	$Script:MenuToolsRemovalPersistence = $MenuToolsRemovalPersistence
	$Script:MenuActionsSep1              = $MenuActionsSep1
	$Script:MenuActionsSep2              = $MenuActionsSep2
	$Script:MenuActionsSep3              = $MenuActionsSep3
	$Script:MenuToolsSepApps             = $MenuToolsSepApps
	$Script:MenuHelpHelp                 = $MenuHelpHelp
	$Script:MenuHelpStartGuide           = $MenuHelpStartGuide
	$Script:MenuHelpReadme               = $MenuHelpReadme
	$Script:MenuHelpFAQ                  = $MenuHelpFAQ
	$Script:MenuHelpReleaseStatus        = $MenuHelpReleaseStatus
	$Script:MenuHelpTroubleshooting      = $MenuHelpTroubleshooting
	$Script:MenuHelpAbout                = $MenuHelpAbout

	$Script:PrimaryTabHost = $PrimaryTabHost
	$Script:ExpertModeBanner = $ExpertModeBanner
	$Script:SafeModeGroup = $SafeModeGroup
	$Script:ThemeToggleGroup = $ThemeToggleGroup
	$Script:SearchLabel = $SearchLabel
	$Script:TxtSearch = $TxtSearch
	$Script:TxtSearchPlaceholder = $TxtSearchPlaceholder
	$Script:BtnClearSearch = $BtnClearSearch
	$Script:BtnFilterToggle = $BtnFilterToggle
	$Script:FilterOptionsPanel = $FilterOptionsPanel
	$Script:RiskFilterLabel = $RiskFilterLabel
	$Script:CategoryFilterLabel = $CategoryFilterLabel
	$Script:PlatformFilterLabel = $PlatformFilterLabel
	$Script:ViewFilterLabel = $ViewFilterLabel
	$Script:ChkSelectedOnly = $ChkSelectedOnly
	$Script:CmbPlatformFilter = $CmbPlatformFilter
	$Script:ChkHideUnavailableItems = $ChkHideUnavailableItems
	$Script:ChkHighRiskOnly = $ChkHighRiskOnly
	$Script:ChkRestorableOnly = $ChkRestorableOnly
	$Script:ChkGamingOnly = $ChkGamingOnly
	$Script:BtnPreviewRun = $BtnPreviewRun
	$Script:BtnRun = $BtnRun
	$Script:BtnDefaults = $BtnDefaults
	$Script:BtnStartHere = $BtnStartHere
	$Script:BtnHelp = $BtnHelp
	$Script:NavModeTweaks = $NavModeTweaks
	$Script:NavModeApps = $NavModeApps
	$Script:NavModeUpdates = $NavModeUpdates
	$Script:NavModeDeploymentMedia = $NavModeDeploymentMedia
	$Script:ModeSubtitle = $ModeSubtitle
	$Script:TweaksView = $TweaksView
	$Script:DeploymentMediaView = $DeploymentMediaView
	$Script:DeploymentMediaScroll = $DeploymentMediaScroll
	$Script:DeploymentMediaWrapPanel = $DeploymentMediaWrapPanel
	$Script:BtnDeploymentMediaDetectIso = $BtnDeploymentMediaDetectIso
	$Script:BtnDeploymentMediaPreviewPlan = $BtnDeploymentMediaPreviewPlan
	$Script:BtnDeploymentMediaStartBuild = $BtnDeploymentMediaStartBuild
	$Script:DeploymentMediaStatusBanner = $DeploymentMediaStatusBanner
	$Script:TxtDeploymentMediaSelectionStatus = $TxtDeploymentMediaSelectionStatus
	$Script:TxtDeploymentMediaBuildStatus = $TxtDeploymentMediaBuildStatus
	$Script:TxtDeploymentMediaSourceIso = $TxtDeploymentMediaSourceIso
	$Script:BtnDeploymentMediaBrowseIso = $BtnDeploymentMediaBrowseIso
	$Script:TxtDeploymentMediaEditionIndex = $TxtDeploymentMediaEditionIndex
	$Script:CmbDeploymentMediaDetectedEdition = $CmbDeploymentMediaDetectedEdition
	$Script:TxtDeploymentMediaDetectedIsoSummary = $TxtDeploymentMediaDetectedIsoSummary
	$Script:TxtDeploymentMediaWorkingDirectory = $TxtDeploymentMediaWorkingDirectory
	$Script:BtnDeploymentMediaBrowseWorking = $BtnDeploymentMediaBrowseWorking
	$Script:CmbDeploymentMediaOutputMode = $CmbDeploymentMediaOutputMode
	$Script:TxtDeploymentMediaUsbTargetRoot = $TxtDeploymentMediaUsbTargetRoot
	$Script:BtnDeploymentMediaBrowseUsbTarget = $BtnDeploymentMediaBrowseUsbTarget
	$Script:TxtDeploymentMediaAutounattend = $TxtDeploymentMediaAutounattend
	$Script:BtnDeploymentMediaBrowseAutounattend = $BtnDeploymentMediaBrowseAutounattend
	$Script:TxtDeploymentMediaDriverSource = $TxtDeploymentMediaDriverSource
	$Script:BtnDeploymentMediaBrowseDrivers = $BtnDeploymentMediaBrowseDrivers
	$Script:ChkDeploymentMediaBootDrivers = $ChkDeploymentMediaBootDrivers
	$Script:ChkDeploymentMediaBaselineTweaks = $ChkDeploymentMediaBaselineTweaks
	$Script:TxtDeploymentMediaPlanPreview = $TxtDeploymentMediaPlanPreview
	$Script:AppsView = $AppsView
	$Script:AppsScroll = $AppsScroll
	$Script:AppsWrapPanel = $AppsWrapPanel
	$Script:BtnUpdateAllApps = $BtnUpdateAllApps
	$Script:AppsPackageManagerBanner = $AppsPackageManagerBanner
	$Script:TxtAppsPackageManagerBanner = $TxtAppsPackageManagerBanner
	$Script:AppsCategoryTabs = $AppsCategoryTabs
	$Script:BtnAppsFilterToggle = $BtnAppsFilterToggle
	$Script:AppsFilterOptionsPanel = $AppsFilterOptionsPanel
	$Script:AppsSourceLabel = $AppsSourceLabel
	$Script:AppsStatusLabel = $AppsStatusLabel
	$Script:CmbAppsStatusFilter = $CmbAppsStatusFilter
	$Script:TxtAppSelectionStatus = $TxtAppSelectionStatus
	$Script:BtnInstallSelectedApps = $BtnInstallSelectedApps
	$Script:BtnUninstallSelectedApps = $BtnUninstallSelectedApps
	$Script:BtnUpdateSelectedApps = $BtnUpdateSelectedApps
	$Script:BtnApplyQueuedActions = $BtnApplyQueuedActions
	$Script:BtnClearQueuedActions = $BtnClearQueuedActions
	$Script:BtnScanInstalledApps = $BtnScanInstalledApps
	$Script:AppsActionSeparator1 = $AppsActionSeparator1
	$Script:BtnAppsSourceFilterAll = $BtnAppsSourceFilterAll
	$Script:BtnAppsSourceFilterWinGet = $BtnAppsSourceFilterWinGet
	$Script:BtnAppsSourceFilterChocolatey = $BtnAppsSourceFilterChocolatey
	$Script:AppsFilterViewDivider = $AppsFilterViewDivider
	$Script:AppsViewModeLabel = $AppsViewModeLabel
	$Script:BtnAppsViewCards = $BtnAppsViewCards
	$Script:BtnAppsViewList = $BtnAppsViewList
	$Script:BtnAppsAddCustom = $BtnAppsAddCustom
	$Script:UpdateDialogOverlay = $UpdateDialogOverlay
	$Script:UpdateDialogCard = $UpdateDialogCard
	$Script:TxtOverlayTitle = $TxtOverlayTitle
	$Script:TxtUpdateDescription = $TxtUpdateDescription
	$Script:CustomPBarContainer = $CustomPBarContainer
	$Script:TxtDownloadProgressLabel = $TxtDownloadProgressLabel
	$Script:TxtDownloadProgressPct = $TxtDownloadProgressPct
	$Script:BtnDownloadNo = $BtnDownloadNo
	$Script:BtnDownloadYes = $BtnDownloadYes
	$Script:ExecutionLogBox = $null
	$Script:ExecutionPreviousContent = $null
	$Script:ExecutionLastConsoleAction = $null
	$Script:ExecutionProgressHost = $null
	$Script:ExecutionProgressBar = $null
	$Script:ExecutionProgressText = $null
	$Script:ExecutionProgressIndeterminate = $false
	$Script:ExecutionLastProgressCompleted = -1
	$Script:ExecutionSubProgressBar = $null
	$Script:ExecutionSubProgressText = $null
	$Script:AbortRunButton = $null
	$Script:AbortRequested = $false
	$Script:ExecutionWorker = $null
	$Script:ExecutionRunspace = $null
	$Script:ExecutionRunPowerShell = $null
		$Script:ExecutionRunTimer = $null
		$Script:RunAbortDisposition = $null
		$Script:ExecutionMode = $null
		$Script:SuppressRunClosePrompt = $false
		$Script:ForceCloseCompleted = $false
		$Script:ExecutionTimerErrorShown = $false
	$Script:AbortDialogShowing = $false
	$Script:BgPS = $null
	$Script:BgAsync = $null
	$Script:BaselineApplicationsCatalog = $null
	$Script:BaselineApplicationsCatalogByCategory = @{}
	$Script:BaselineApplicationsCatalogCategory = $null
	$Script:InstalledAppsCache = [pscustomobject]@{
		WinGet = @{}
		Chocolatey = @{}
		WinGetUpdates = @{}
		ChocolateyUpdates = @{}
	}
	$Script:AppsModeActive = $false
	$Script:UpdatesModeActive = $false
	$Script:UpdatesReturnPrimaryTab = $null
	$Script:DeploymentMediaModeActive = $false
	$Script:DeploymentMediaReturnPrimaryTab = $null
	$Script:DeploymentMediaBuilderViewInitialized = $false
	$Script:DeploymentMediaDetectedIsoInfo = $null
	$Script:DeploymentMediaCurrentPlan = $null
	$Script:DeploymentMediaBuildInProgress = $false
	$Script:AppsViewLoaded = $false
	$Script:AppsViewDirty = $false
	$Script:AppsViewBuildSignature = $null
	$Script:AppsCacheRefreshInProgress = $false
	$Script:AppsOperationInProgress = $false
	$Script:AppsCategoryFilter = 'Browsers'
	$Script:AppsStatusFilter = 'All'
	$Script:AppsViewMode = 'Cards'
	$Script:AppsViewModeUiUpdating = $false
	$Script:AppsFilterUiUpdating = $false
	$Script:TxtAppsProgressText = $null
	$Script:AppsProgressBar = $null
	$Script:AppsActionButtons = [System.Collections.Generic.List[object]]::new()
	$Script:AppsBulkActionButtons = [System.Collections.Generic.List[object]]::new()
	$Script:AppsSelectionControls = [System.Collections.Generic.List[object]]::new()
	$Script:AppsQueuedActionControls = [System.Collections.Generic.List[object]]::new()
	$Script:AppsQueuedActionControlMap = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
	$Script:SelectedAppIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	$Script:AppsSelectionUiUpdating = $false
	$Script:AppsQueuedActionUiUpdating = $false
	$Script:AppActionStates = @{}
	foreach ($bulkButton in @($BtnInstallSelectedApps, $BtnUninstallSelectedApps, $BtnUpdateSelectedApps, $BtnApplyQueuedActions, $BtnClearQueuedActions, $BtnScanInstalledApps))
	{
		if ($bulkButton)
		{
			[void]$Script:AppsBulkActionButtons.Add($bulkButton)
		}
	}
	$Script:DownloadStartEvent = $null
	$Script:DownloadExtractEvent = $null
	$Script:UpdateCheckPrimaryClickEvent = $null
	$Script:UpdateCheckSecondaryClickEvent = $null
	Initialize-BaselineUpdateOverlay
	$Script:SearchText = ''
	$Script:AppsSearchText = ''
	$Script:AppsPackageSourcePreference = 'auto'
	$Script:AppsSourceFilter = 'All'
	$Script:AppsSourceFilterUiUpdating = $false
	$Script:SearchResultsTabTag = '__SEARCH_RESULTS__'
	$Script:LastStandardPrimaryTab = $null
	$Script:TabScrollOffsets = @{}
	$Script:TabContentCache = @{}
	$Script:CategoryFilterListCache = @{}
	$Script:LastCategoryFilterPopulateKey = $null
	$Script:LastCategoryFilterSignature = $null
	$Script:FilterGeneration = 0
	$Script:SearchRefreshTimer = $null
	$Script:FilterRefreshTimer = $null
	$Script:PendingFilterValues = @{}
	$Script:SearchUiUpdating = $false
	$Script:AppsSourceUiUpdating = $false
	$Script:ThemeUiUpdating = $false
	$Script:SearchRefreshDelayMs = $Script:GuiLayout.SearchRefreshDelayMs
	$Script:CurrentThemeName = $Script:InitialResolvedThemeName
	$Script:UiSnapshotUndo = $null
	$Script:PresetStatusMessage = $null
	$Script:PresetStatusTone = 'info'
	$Script:PresetStatusBadge = $null
	$Script:PresetProgressHost = $null
	$Script:PresetProgressBar = $null
	$Script:EnvironmentRecommendationData = $null
	$Script:EnvironmentSummaryText = $null
	$Script:SecondaryActionGroupBorder = $null
	$previousGuiUnhandledExceptionHooked = [bool]$Script:GuiUnhandledExceptionHooked
	$previousGuiUnhandledExceptionHandler = $Script:GuiUnhandledExceptionHandler
	$previousGuiDispatcher = if ($Script:MainForm -and $Script:MainForm.Dispatcher)
	{
		$Script:MainForm.Dispatcher
	}
	elseif ($Form -and $Form.Dispatcher)
	{
		$Form.Dispatcher
	}
	else
	{
		$null
	}

	if ($previousGuiUnhandledExceptionHooked -and $previousGuiUnhandledExceptionHandler -and $previousGuiDispatcher)
	{
		try
		{
			$previousGuiDispatcher.remove_UnhandledException($previousGuiUnhandledExceptionHandler)
		}
		catch { Write-SwallowedException -ErrorRecord $_ -Source 'WindowSetup.RemoveUnhandledExceptionHook' }
	}

	$Script:GuiUnhandledExceptionHooked = $false
	$Script:GuiUnhandledExceptionHandler = $null
	$Script:ExplicitPresetSelections = [System.Collections.Generic.HashSet[string]]::new(
		[System.StringComparer]::OrdinalIgnoreCase
	)
	$Script:ExplicitPresetSelectionDefinitions = @{}

	$Script:GuiDispatcherHandlingError = $false
	if (-not $Script:GuiUnhandledExceptionHooked -and $Form -and $Form.Dispatcher)
	{
		$Script:GuiUnhandledExceptionHandler = [System.Windows.Threading.DispatcherUnhandledExceptionEventHandler]{
			param($unusedSender, $e)

			if ($Script:GuiDispatcherHandlingError)
			{
				$e.Handled = $true
				return
			}
			$Script:GuiDispatcherHandlingError = $true

			$isFatal = $false
			try
			{
				$showGuiRuntimeFailureScript = $Script:ShowGuiRuntimeFailureScript
				if ($showGuiRuntimeFailureScript)
				{
					$null = & $showGuiRuntimeFailureScript -Context 'WPF Dispatcher' -Exception $e.Exception -ShowDialog
				}
				else
				{
					Write-Warning (Format-BaselineErrorForLog -ErrorObject $e -Prefix 'GUI event failed [WPF Dispatcher]')
				}

				# Treat critical .NET exceptions as fatal - do not suppress them
				$ex = $e.Exception
				$isFatal = $ex -is [System.StackOverflowException] -or
					$ex -is [System.OutOfMemoryException] -or
					$ex -is [System.AccessViolationException] -or
					$ex -is [System.InvalidProgramException]
			}
			catch
			{
				# If our own handler fails, the original exception must not be swallowed
				$isFatal = $true
			}
			finally
			{
				$Script:GuiDispatcherHandlingError = $false
			}

			$e.Handled = -not $isFatal
		}

		try
		{
			$Form.Dispatcher.add_UnhandledException($Script:GuiUnhandledExceptionHandler)
			$Script:GuiUnhandledExceptionHooked = $true
		}
		catch { Write-SwallowedException -ErrorRecord $_ -Source 'WindowSetup.AddUnhandledExceptionHook' }
	}
	$Script:RiskFilter = 'All'
	$Script:CategoryFilter = 'All'
	$Script:PlatformFilter = 'ThisDevice'
	$Script:CategoryFilterInternalValues = [System.Collections.Generic.List[string]]::new()
	$Script:PlatformFilterInternalValues = [System.Collections.Generic.List[string]]::new()
	$Script:AppsCategoryFilterInternalValues = [System.Collections.Generic.List[string]]::new()
	$Script:AppsStatusFilterInternalValues = [System.Collections.Generic.List[string]]::new()
	$Script:LastPlatformFilterPopulateKey = $null
	$Script:SelectedOnlyFilter = $false
	$Script:HighRiskOnlyFilter = $false
	$Script:RestorableOnlyFilter = $false
	$Script:GamingOnlyFilter = $false
	$Script:HideUnavailableItems = $true
	$Script:DesignMode = $false
	$Script:RestoreLastSession = $true
	$Script:AutoScanOnLaunch = $false
	$Script:RequireRunConfirmation = $true
	$Script:AutoCheckUpdates = $true
	$Script:UpdateCheckFrequency = 'Startup'
	$Script:UpdateBranch = if (Get-Command -Name 'Get-BaselineDefaultUpdateBranch' -CommandType Function -ErrorAction SilentlyContinue) { Get-BaselineDefaultUpdateBranch } else { 'Stable' }
	$Script:IncludePrereleaseUpdates = $false
	$Script:ScanEnabled = $false
	$Script:DebugLoggingEnabled = $false
	$Script:LogLevel = 'All'
	$Script:LogFileDirectory = ''
	$Script:UIDensity = if (Get-Command -Name 'Get-BaselineUiDensity' -CommandType Function -ErrorAction SilentlyContinue) { Get-BaselineUiDensity } else { 'Comfort' }
	try
	{
		if (Get-Command -Name 'Get-BaselineUserPreference' -CommandType Function -ErrorAction SilentlyContinue)
		{
			$Script:HideUnavailableItems = [bool](Get-BaselineUserPreference -Key 'HideUnavailableItems' -Default $true)
			$Script:DesignMode = [bool](Get-BaselineUserPreference -Key 'DesignMode' -Default $false)
			$Script:RestoreLastSession = [bool](Get-BaselineUserPreference -Key 'RestoreLastSession' -Default $true)
			$Script:AutoScanOnLaunch = [bool](Get-BaselineUserPreference -Key 'AutoScanOnLaunch' -Default $false)
			$Script:RequireRunConfirmation = [bool](Get-BaselineUserPreference -Key 'RequireRunConfirmation' -Default $true)
			$Script:AutoCheckUpdates = [bool](Get-BaselineUserPreference -Key 'AutoCheckUpdates' -Default $true)
			$Script:UpdateCheckFrequency = [string](Get-BaselineUserPreference -Key 'UpdateCheckFrequency' -Default 'Startup')
			if (Get-Command -Name 'ConvertTo-BaselineUpdateCheckFrequency' -CommandType Function -ErrorAction SilentlyContinue) { $Script:UpdateCheckFrequency = ConvertTo-BaselineUpdateCheckFrequency -Frequency $Script:UpdateCheckFrequency }
			$defaultUpdateBranch = if (Get-Command -Name 'Get-BaselineDefaultUpdateBranch' -CommandType Function -ErrorAction SilentlyContinue) { Get-BaselineDefaultUpdateBranch } else { 'Stable' }
			$Script:UpdateBranch = [string](Get-BaselineUserPreference -Key 'UpdateBranch' -Default $defaultUpdateBranch)
			if (Get-Command -Name 'ConvertTo-BaselineUpdateBranch' -CommandType Function -ErrorAction SilentlyContinue) { $Script:UpdateBranch = ConvertTo-BaselineUpdateBranch -Branch $Script:UpdateBranch }
			$Script:IncludePrereleaseUpdates = [bool](Get-BaselineUserPreference -Key 'IncludePrereleaseUpdates' -Default $false)
			$Script:DebugLoggingEnabled = [bool](Get-BaselineUserPreference -Key 'DebugLoggingEnabled' -Default $false)
			$Script:LogLevel = [string](Get-BaselineUserPreference -Key 'LogLevel' -Default 'All')
			if (Get-Command -Name 'Normalize-GuiLogLevel' -CommandType Function -ErrorAction SilentlyContinue) { $Script:LogLevel = Normalize-GuiLogLevel -Level $Script:LogLevel }
			$Script:LogFileDirectory = [string](Get-BaselineUserPreference -Key 'LogFileDirectory' -Default '')
			$Script:UIDensity = if (Get-Command -Name 'Normalize-BaselineUiDensity' -CommandType Function -ErrorAction SilentlyContinue) { Normalize-BaselineUiDensity -Density ([string](Get-BaselineUserPreference -Key 'UIDensity' -Default $Script:UIDensity)) } else { [string](Get-BaselineUserPreference -Key 'UIDensity' -Default $Script:UIDensity) }
			$Script:AppsPackageSourcePreference = [string](Get-BaselineUserPreference -Key 'AppsPackageSourcePreference' -Default $Script:AppsPackageSourcePreference)
		}
	}
	catch
	{
		Write-SwallowedException -ErrorRecord $_ -Source 'WindowSetup.LoadGuiPreferences'
		$Script:HideUnavailableItems = $true
		$Script:DesignMode = $false
		$Script:RestoreLastSession = $true
		$Script:RequireRunConfirmation = $true
		$Script:AutoCheckUpdates = $true
		$Script:UpdateCheckFrequency = 'Startup'
		$Script:UpdateBranch = if (Get-Command -Name 'Get-BaselineDefaultUpdateBranch' -CommandType Function -ErrorAction SilentlyContinue) { Get-BaselineDefaultUpdateBranch } else { 'Stable' }
		$Script:IncludePrereleaseUpdates = $false
		$Script:DebugLoggingEnabled = $false
		$Script:LogFileDirectory = ''
		$Script:AppsPackageSourcePreference = 'auto'
	}
	if (Get-Command -Name 'Set-BaselineDebugLogging' -CommandType Function -ErrorAction SilentlyContinue)
	{
		try { Set-BaselineDebugLogging -Enabled ([bool]$Script:DebugLoggingEnabled) }
		catch { Write-SwallowedException -ErrorRecord $_ -Source 'WindowSetup.ApplyDebugLoggingPreference' }
	}
	if (Get-Command -Name 'Set-GuiPerfTraceState' -CommandType Function -ErrorAction SilentlyContinue)
	{
		try { Set-GuiPerfTraceState -Enabled ([bool]$Script:DebugLoggingEnabled) }
		catch { Write-SwallowedException -ErrorRecord $_ -Source 'WindowSetup.ApplyPerfTraceState' }
	}
	$Script:SafeMode = $true
	$Script:AdvancedMode = $false

	# Auto-detect language from system UI culture. Session restore may override this.
	$Script:SelectedLanguage = $null
	$cultureToFileMap = @{ 'zh-cn' = 'zh-Hans'; 'zh-sg' = 'zh-Hans'; 'zh-tw' = 'zh-Hant'; 'zh-hk' = 'zh-Hant'; 'zh-mo' = 'zh-Hant' }
	$uiCultureLower = $PSUICulture.ToLower()
	$autoLangCandidates = @()
	if ($cultureToFileMap.ContainsKey($uiCultureLower)) { $autoLangCandidates += $cultureToFileMap[$uiCultureLower] }
	$autoLangCandidates += @($uiCultureLower, ($PSUICulture -split '-')[0].ToLower())
	$locDirInit = $Script:GuiLocalizationDirectoryPath
	foreach ($candidate in $autoLangCandidates)
	{
		if (-not [string]::IsNullOrWhiteSpace([string]$locDirInit))
		{
			try
			{
				$null = Resolve-BaselineLocalizationFile -BaseDirectory $locDirInit -FileName "$candidate.json"
				$Script:SelectedLanguage = $candidate
				break
			}
			catch { Write-SwallowedException -ErrorRecord $_ -Source 'WindowSetup.ResolveLocalizationCandidate'; $null = $_ }
		}
	}
	if (-not $Script:SelectedLanguage) { $Script:SelectedLanguage = 'en' }
	Initialize-GameModeState
	if ($Script:TweakIndicesByPrimaryTab -and $Script:GamingCrossTabFunctions -and $Script:GamingCrossTabFunctions.Count -gt 0)
	{
		if (-not $Script:TweakIndicesByPrimaryTab.ContainsKey('Gaming'))
		{
			$Script:TweakIndicesByPrimaryTab['Gaming'] = [System.Collections.Generic.List[int]]::new()
		}
		$gamingIndexBucket = $Script:TweakIndicesByPrimaryTab['Gaming']
		for ($gamingIndex = 0; $gamingIndex -lt $Script:TweakManifest.Count; $gamingIndex++)
		{
			$gamingTweak = $Script:TweakManifest[$gamingIndex]
			if (-not $gamingTweak) { continue }
			$gamingFunction = [string]$gamingTweak.Function
			if ([string]::IsNullOrWhiteSpace($gamingFunction)) { continue }
			if ($Script:GamingCrossTabFunctions.Contains($gamingFunction) -and -not $gamingIndexBucket.Contains($gamingIndex))
			{
				[void]$gamingIndexBucket.Add($gamingIndex)
			}
		}
	}
	$Script:FilterUiUpdating = $false
	$Script:ExecutionSummaryRecords = @()
	$Script:ExecutionSummaryLookup = @{}
	$Script:ExecutionCurrentSummaryKey = $null
	$Script:GuiDisplayVersion = Get-BaselineDisplayVersion

		# Keep the native window title concise; version details live in Help.
		$headerTitle = $Form.Title
		try
		{
			$windowTitle = Get-UxMainWindowTitleText
			$Form.Title = $windowTitle
			if ($TitleBarText) { $TitleBarText.Text = $windowTitle }
			$headerTitle = $windowTitle
		}
		catch { Write-GuiRuntimeWarning -Context 'WindowTitle' -Message $_.Exception.Message }
		$TitleText.Text = $headerTitle
