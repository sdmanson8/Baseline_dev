# Baseline update overlay helpers for progress, update checks, and import flows.


<#
    .SYNOPSIS
#>

function Initialize-BaselineUpdateOverlay
{
	[CmdletBinding()]
	param ()

	if (-not $Script:CustomPBarContainer -or -not $Script:UpdateDialogOverlay) { return }

	Ensure-SheenProgressBarType

	$sharedProgress = New-SharedProgressBarHost -Maximum 100 -Value 0
	$windowsFormsHost = $sharedProgress.Host
	$progressBar = $sharedProgress.ProgressBar
	$Script:CustomProgressBar = $progressBar
	$Script:CustomProgressHost = $windowsFormsHost
	$Script:CustomPBarContainer.Child = $windowsFormsHost
}

<#
    .SYNOPSIS
#>

function Show-BaselineUpdateOverlay
{
	[CmdletBinding()]
	param (
		[string]$Title = (Get-UxLocalizedString -Key 'GuiUpdateDialogTitle' -Fallback 'Update Baseline'),
		[string]$Description = (Get-UxLocalizedString -Key 'GuiUpdateDialogDescription' -Fallback 'A new version of Baseline is available from GitHub. Do you want to download and extract it now?'),
		[string]$StatusText = (Get-UxLocalizedString -Key 'GuiUpdateDialogReady' -Fallback 'Ready to download.'),
		[string]$ProgressPct = '0%',
		[string]$PrimaryButtonText = (Get-UxLocalizedString -Key 'GuiUpdateDialogDownload' -Fallback 'Download Update'),
		[string]$SecondaryButtonText = (Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Cancel'),
		[bool]$ShowButtons = $true,
		[bool]$ShowProgressPct = $true,
		[switch]$Indeterminate
	)

	if ($Script:UpdateDialogOverlay)
	{
		$Script:UpdateDialogOverlay.Visibility = [System.Windows.Visibility]::Visible
	}
	if ($Script:CustomProgressBar)
	{
		$Script:CustomProgressBar.IsIndeterminate = [bool]$Indeterminate
		$Script:CustomProgressBar.Value = 0
	}
	if ($Script:TxtOverlayTitle) { $Script:TxtOverlayTitle.Text = [string]$Title }
	if ($Script:TxtUpdateDescription) { $Script:TxtUpdateDescription.Text = [string]$Description }
	if ($Script:TxtDownloadProgressLabel) { $Script:TxtDownloadProgressLabel.Text = [string]$StatusText }
	if ($Script:TxtDownloadProgressPct)
	{
		$Script:TxtDownloadProgressPct.Text = [string]$ProgressPct
		$Script:TxtDownloadProgressPct.Visibility = if ($ShowProgressPct) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
	}
	if ($Script:BtnDownloadYes)
	{
		$Script:BtnDownloadYes.Content = [string]$PrimaryButtonText
		$Script:BtnDownloadYes.Visibility = if ($ShowButtons) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
		$Script:BtnDownloadYes.IsEnabled = [bool]$ShowButtons
	}
	if ($Script:BtnDownloadNo)
	{
		$Script:BtnDownloadNo.Content = [string]$SecondaryButtonText
		$Script:BtnDownloadNo.Visibility = if ($ShowButtons) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
		$Script:BtnDownloadNo.IsEnabled = [bool]$ShowButtons
	}
}

<#
    .SYNOPSIS
#>

function Show-BaselineUpdateCheckDialog
{
	[CmdletBinding()]
	param ()

	$title = (Get-UxLocalizedString -Key 'GuiUpdateDialogTitle' -Fallback 'Update Baseline')
	$checkingDescription = (Get-UxLocalizedString -Key 'GuiUpdateCheckDescription' -Fallback 'Checking GitHub releases for a newer Baseline version.')
	$checkingStatus = (Get-UxLocalizedString -Key 'GuiUpdateCheckStatus' -Fallback 'Checking for updates...')
	$openReleaseLabel = (Get-UxLocalizedString -Key 'GuiUpdateCheckOpenRelease' -Fallback 'Open Release Page')
	$closeLabel = (Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close')
	$upToDateDescription = (Get-UxLocalizedString -Key 'GuiUpdateCheckUpToDateDescription' -Fallback 'Baseline is already up to date.')
	$upToDateStatus = (Get-UxLocalizedString -Key 'GuiUpdateCheckUpToDateStatus' -Fallback 'Already up to date.')
	$availableDescription = (Get-UxLocalizedString -Key 'GuiUpdateCheckAvailableDescription' -Fallback 'A newer version of Baseline is available on GitHub Releases.')
	$availableStatus = (Get-UxLocalizedString -Key 'GuiUpdateCheckAvailableStatus' -Fallback 'Update available.')
	$errorDescription = (Get-UxLocalizedString -Key 'GuiUpdateCheckFailedDescription' -Fallback 'Unable to check for updates right now.')
	$offlineDescription = (Get-UxLocalizedString -Key 'GuiUpdateCheckOfflineDescription' -Fallback 'Unable to check for updates because the network is offline.')
	$offlineStatus = (Get-UxLocalizedString -Key 'GuiUpdateCheckOfflineStatus' -Fallback 'Skipped (offline).')
	$releasePageUrl = 'https://github.com/sdmanson8/Baseline/releases/latest'
	$currentVersion = '0.0.0'
	$hideBaselineUpdateOverlayCommand = Get-GuiRuntimeCommand -Name 'Hide-BaselineUpdateOverlay' -CommandType 'Function'
	$hideBaselineUpdateOverlayAction = {
		if ($hideBaselineUpdateOverlayCommand)
		{
			try { & $hideBaselineUpdateOverlayCommand } catch { Write-SwallowedException -ErrorRecord $_ -Source 'UpdateOverlayModule.HideUpdateOverlayCommand' }
		}

		Hide-BaselineUpdateOverlay
	}.GetNewClosure()
	$showSingleCloseButton = {
		if ($Script:BtnDownloadNo)
		{
			$Script:BtnDownloadNo.Visibility = [System.Windows.Visibility]::Collapsed
			$Script:BtnDownloadNo.IsEnabled = $false
		}
	}
	$setUpdateCheckPrimaryClickEvent = {
		param ([scriptblock]$Handler)

		if (-not $Script:BtnDownloadYes) { return }

		if ($Script:UpdateCheckPrimaryClickEvent)
		{
			try { $Script:BtnDownloadYes.Remove_Click($Script:UpdateCheckPrimaryClickEvent) } catch { Write-SwallowedException -ErrorRecord $_ -Source 'UpdateOverlayModule.RemoveUpdateCheckPrimaryClickEvent' }
			$Script:UpdateCheckPrimaryClickEvent = $null
		}
		if ($Script:DownloadStartEvent)
		{
			try { $Script:BtnDownloadYes.Remove_Click($Script:DownloadStartEvent) } catch { Write-SwallowedException -ErrorRecord $_ -Source 'UpdateOverlayModule.RemoveDownloadStartEvent' }
		}
		if ($Script:DownloadExtractEvent)
		{
			try { $Script:BtnDownloadYes.Remove_Click($Script:DownloadExtractEvent) } catch { Write-SwallowedException -ErrorRecord $_ -Source 'UpdateOverlayModule.RemoveDownloadExtractEvent' }
		}

		$Script:UpdateCheckPrimaryClickEvent = $Handler.GetNewClosure()
		$Script:BtnDownloadYes.Add_Click($Script:UpdateCheckPrimaryClickEvent)
	}
	$setUpdateCheckCloseClickEvent = {
		param ([scriptblock]$Handler)

		if (-not $Script:BtnDownloadNo) { return }

		if ($Script:UpdateCheckSecondaryClickEvent)
		{
			try { $Script:BtnDownloadNo.Remove_Click($Script:UpdateCheckSecondaryClickEvent) } catch { Write-SwallowedException -ErrorRecord $_ -Source 'UpdateOverlayModule.RemoveUpdateCheckSecondaryClickEvent' }
			$Script:UpdateCheckSecondaryClickEvent = $null
		}

		$Script:UpdateCheckSecondaryClickEvent = $Handler.GetNewClosure()
		$Script:BtnDownloadNo.Add_Click($Script:UpdateCheckSecondaryClickEvent)
	}
	$wireCloseButtons = {
		& $setUpdateCheckPrimaryClickEvent $hideBaselineUpdateOverlayAction
		& $setUpdateCheckCloseClickEvent $hideBaselineUpdateOverlayAction
	}

	try
	{
		$currentVersion = [string](Get-BaselineDisplayVersion)
	}
	catch { Write-SwallowedException -ErrorRecord $_ -Source 'UpdateOverlayModule.LoadCurrentVersion' }

	Show-BaselineUpdateOverlay -Title $title -Description $checkingDescription -StatusText $checkingStatus -ShowButtons:$false -ShowProgressPct:$false -Indeterminate

	try
	{
		$includePrerelease = $false
		$updateBranch = if (Get-Command -Name 'Get-BaselineDefaultUpdateBranch' -CommandType Function -ErrorAction SilentlyContinue) { Get-BaselineDefaultUpdateBranch } else { 'Stable' }
		if (Get-Command -Name 'Get-BaselineUpdateSettings' -CommandType Function -ErrorAction SilentlyContinue)
		{
			$updateSettings = Get-BaselineUpdateSettings
			$includePrerelease = if ($updateSettings -and $updateSettings.PSObject.Properties['IncludePrereleaseBuilds']) { [bool]$updateSettings.IncludePrereleaseBuilds } else { $false }
			if ($updateSettings -and $updateSettings.PSObject.Properties['UpdateBranch'] -and -not [string]::IsNullOrWhiteSpace([string]$updateSettings.UpdateBranch))
			{
				$updateBranch = [string]$updateSettings.UpdateBranch
			}
		}
		if (Get-Command -Name 'ConvertTo-BaselineUpdateBranch' -CommandType Function -ErrorAction SilentlyContinue)
		{
			$updateBranch = ConvertTo-BaselineUpdateBranch -Branch $updateBranch
		}
		if (Get-Command -Name 'Get-BaselineUpdateReleasePageUrl' -CommandType Function -ErrorAction SilentlyContinue)
		{
			$releasePageUrl = Get-BaselineUpdateReleasePageUrl -Branch $updateBranch
		}
		$checkResult = Invoke-BaselineUpdateCheck -CurrentVersion $currentVersion -UpdateBranch $updateBranch -IncludePrerelease:$includePrerelease
		$release = $checkResult.Release
		if ([string]$checkResult.Status -eq 'Skipped (offline)')
		{
			Show-BaselineUpdateOverlay -Title $title -Description $offlineDescription -StatusText $offlineStatus -PrimaryButtonText $closeLabel -SecondaryButtonText $closeLabel -ShowButtons:$true -ShowProgressPct:$false
			& $showSingleCloseButton
			& $wireCloseButtons
			return
		}
		if ([string]$checkResult.Status -eq 'Failed')
		{
			$errorStatus = if ([string]::IsNullOrWhiteSpace([string]$checkResult.Message)) { $errorDescription } else { [string]$checkResult.Message }
			Show-BaselineUpdateOverlay -Title $title -Description $errorDescription -StatusText $errorStatus -PrimaryButtonText $closeLabel -SecondaryButtonText $closeLabel -ShowButtons:$true -ShowProgressPct:$false
			& $showSingleCloseButton
			& $wireCloseButtons
			return
		}
		if (-not $release -or -not [bool]$checkResult.IsUpdateAvailable)
		{
			$latestText = if ([string]::IsNullOrWhiteSpace([string]$checkResult.LatestVersion)) { [string]$currentVersion } else { [string]$checkResult.LatestVersion }
			Show-BaselineUpdateOverlay -Title $title -Description $upToDateDescription -StatusText ($upToDateStatus -f $latestText) -PrimaryButtonText $closeLabel -SecondaryButtonText $closeLabel -ShowButtons:$true -ShowProgressPct:$false
			& $showSingleCloseButton
			& $wireCloseButtons
			return
		}

		$latestTag = [string]$release.tag_name
		$releaseAssetPattern = if (Get-Command -Name 'Get-BaselineUpdateAssetPattern' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Get-BaselineUpdateAssetPattern -Branch $updateBranch
		}
		else
		{
			if ([string]::Equals($updateBranch, 'Beta', [System.StringComparison]::OrdinalIgnoreCase))
			{
				'Baseline-*-beta.zip'
			}
			else
			{
				'Baseline-*-stable.zip'
			}
		}

		$releaseAsset = $release.assets | Where-Object { $_.name -like $releaseAssetPattern } | Select-Object -First 1
		if ($releaseAsset)
		{
			$availableDescription = (Get-UxLocalizedString -Key 'GuiUpdateCheckAvailableDescription' -Fallback 'A newer version of Baseline is available on GitHub Releases.') -f $latestTag
			$availableStatus = (Get-UxLocalizedString -Key 'GuiUpdateCheckAvailableStatus' -Fallback 'Update available: {0}.') -f $latestTag
			Show-BaselineUpdateOverlay -Title $title -Description $availableDescription -StatusText $availableStatus -PrimaryButtonText $openReleaseLabel -SecondaryButtonText $closeLabel -ShowButtons:$true -ShowProgressPct:$false
			& $setUpdateCheckPrimaryClickEvent {
				try
				{
					[void](Invoke-UserLaunch -FilePath $releasePageUrl -Description 'Baseline release page')
				}
				catch
				{
					Write-SwallowedException -ErrorRecord $_ -Source 'UpdateOverlayModule.OpenReleasePage'
				}
				& $hideBaselineUpdateOverlayAction
			}
			& $setUpdateCheckCloseClickEvent $hideBaselineUpdateOverlayAction
			return
		}

		Show-BaselineUpdateOverlay -Title $title -Description $errorDescription -StatusText ($availableStatus -f $latestTag) -PrimaryButtonText $closeLabel -SecondaryButtonText $closeLabel -ShowButtons:$true -ShowProgressPct:$false
		& $showSingleCloseButton
		& $wireCloseButtons
	}
	catch
	{
		Show-BaselineUpdateOverlay -Title $title -Description $errorDescription -StatusText $_.Exception.Message -PrimaryButtonText $closeLabel -SecondaryButtonText $closeLabel -ShowButtons:$true -ShowProgressPct:$false
		& $showSingleCloseButton
		& $wireCloseButtons
	}
}

<#
    .SYNOPSIS
#>

function Show-BaselineImportOverlay
{
	[CmdletBinding()]
	param (
		[string]$Title = (Get-UxLocalizedString -Key 'GuiImportSettings' -Fallback 'Import Settings'),
		[string]$Description = (Get-UxLocalizedString -Key 'GuiImportSettingsOverlayDescription' -Fallback 'Loading the selected settings profile.'),
		[string]$StatusText = (Get-UxLocalizedString -Key 'GuiImportSettingsPreparing' -Fallback 'Preparing import...')
	)

	Show-BaselineUpdateOverlay -Title $Title -Description $Description -StatusText $StatusText -ShowButtons:$false -ShowProgressPct:$false -Indeterminate
}

function Hide-BaselineUpdateOverlay
{
	[CmdletBinding()]
	param ()

	if ($Script:UpdateDialogOverlay)
	{
		$Script:UpdateDialogOverlay.Visibility = [System.Windows.Visibility]::Collapsed
	}
}

<#
    .SYNOPSIS
#>

function Start-BaselineDownload
{
	param (
		[string]$Uri,
		[string]$DestinationPath
	)

	LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogStartBackgroundDownload' -Fallback 'Starting background download from {0}' -FormatArgs @($Uri))

	if ($Script:BtnDownloadYes) { $Script:BtnDownloadYes.IsEnabled = $false }
	if ($Script:BtnDownloadNo) { $Script:BtnDownloadNo.IsEnabled = $false }
	if ($Script:CustomProgressBar)
	{
		$Script:CustomProgressBar.IsIndeterminate = $false
		$Script:CustomProgressBar.Value = 0
	}
	if ($Script:TxtDownloadProgressPct) { $Script:TxtDownloadProgressPct.Text = "0%" }
	if ($Script:TxtDownloadProgressLabel) { $Script:TxtDownloadProgressLabel.Text = (Get-UxLocalizedString -Key 'GuiStatusDownloadConnecting' -Fallback 'Connecting to GitHub...') }

		$syncHash = [hashtable]::Synchronized(@{
			ProgressPct = 0
			Status      = (Get-UxLocalizedString -Key 'GuiStatusDownloadInitializing' -Fallback 'Initializing...')
			IsComplete  = $false
			Error       = $null
		})

	$runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
	$runspace.Open()
	$ps = [System.Management.Automation.PowerShell]::Create()
	$ps.Runspace = $runspace

	[void]$ps.AddScript({
		param($DownloadUri, $Path, $Sync)
		$response = $null
		$responseStream = $null
		$targetStream = $null
		try
		{
			$webRequest = [System.Net.WebRequest]::Create($DownloadUri)
			$response = $webRequest.GetResponse()
			$totalBytes = $response.ContentLength

			$responseStream = $response.GetResponseStream()
			$targetStream = [System.IO.File]::Create($Path)

			$buffer = New-Object byte[] 65536
			$totalRead = 0

			do
			{
				$read = $responseStream.Read($buffer, 0, $buffer.Length)
				if ($read -gt 0)
				{
					$targetStream.Write($buffer, 0, $read)
					$totalRead += $read
					if ($totalBytes -gt 0)
					{
						$Sync.ProgressPct = [math]::Round(($totalRead / $totalBytes) * 100)
						$mbRead = [math]::Round($totalRead / 1MB, 2)
						$mbTotal = [math]::Round($totalBytes / 1MB, 2)
							$Sync.Status = (Get-UxLocalizedString -Key 'GuiStatusDownloadProgressFormat' -Fallback 'Downloading... {0} MB / {1} MB' -FormatArgs @($mbRead, $mbTotal))
					}
				}
			}
			while ($read -gt 0)

			$Sync.IsComplete = $true
			$Sync.Status = (Get-UxLocalizedString -Key 'GuiStatusDownloadComplete' -Fallback 'Download complete.')
		}
		catch
		{
			$Sync.Error = $_.Exception.Message
			$Sync.IsComplete = $true
		}
		finally
		{
			if ($targetStream) { $targetStream.Dispose() }
			if ($responseStream) { $responseStream.Dispose() }
			if ($response) { $response.Dispose() }
		}
	}).AddArgument($Uri).AddArgument($DestinationPath).AddArgument($syncHash)

	$asyncResult = $ps.BeginInvoke()

	$timer = [System.Windows.Threading.DispatcherTimer]::new()
	$timer.Interval = [TimeSpan]::FromMilliseconds(50)

	$timer.Add_Tick({
		if ($syncHash.Error)
		{
			$timer.Stop()
			if ($Script:TxtDownloadProgressLabel) { $Script:TxtDownloadProgressLabel.Text = (Get-UxLocalizedString -Key 'GuiStatusDownloadFailedFormat' -Fallback 'Download failed: {0}' -FormatArgs @($syncHash.Error)) }
			if ($Script:BtnDownloadYes) { $Script:BtnDownloadYes.Content = (Get-UxLocalizedString -Key 'GuiStatusDownloadRetry' -Fallback 'Retry') }
			if ($Script:BtnDownloadYes) { $Script:BtnDownloadYes.IsEnabled = $true }
			if ($Script:BtnDownloadNo) { $Script:BtnDownloadNo.IsEnabled = $true }
			try { $ps.Dispose() } catch { Write-SwallowedException -ErrorRecord $_ -Source 'UpdateOverlayModule.DownloadCleanup.DisposePowerShell' }
			try { $runspace.Dispose() } catch { Write-SwallowedException -ErrorRecord $_ -Source 'UpdateOverlayModule.DownloadCleanup.DisposeRunspace' }
			return
		}

		if ($Script:CustomProgressBar) { $Script:CustomProgressBar.Value = $syncHash.ProgressPct }
		if ($Script:TxtDownloadProgressPct) { $Script:TxtDownloadProgressPct.Text = "$($syncHash.ProgressPct)%" }
		if ($Script:TxtDownloadProgressLabel) { $Script:TxtDownloadProgressLabel.Text = $syncHash.Status }

		if ($syncHash.IsComplete -and -not $syncHash.Error)
		{
			$timer.Stop()
			if ($Script:CustomProgressBar) { $Script:CustomProgressBar.Value = 100 }
			if ($Script:TxtDownloadProgressPct) { $Script:TxtDownloadProgressPct.Text = "100%" }
			if ($Script:BtnDownloadYes) { $Script:BtnDownloadYes.Content = (Get-UxLocalizedString -Key 'GuiStatusDownloadExtractRestart' -Fallback 'Extract & Restart') }
			if ($Script:BtnDownloadYes) { $Script:BtnDownloadYes.IsEnabled = $true }
			if ($Script:BtnDownloadNo) { $Script:BtnDownloadNo.IsEnabled = $true }

			if ($Script:BtnDownloadYes -and $Script:DownloadStartEvent)
			{
				try { $Script:BtnDownloadYes.Remove_Click($Script:DownloadStartEvent) } catch { Write-SwallowedException -ErrorRecord $_ -Source 'UpdateOverlayModule.RemoveDownloadStartEvent' }
			}
			if ($Script:BtnDownloadYes -and $Script:DownloadExtractEvent)
			{
				$Script:BtnDownloadYes.Add_Click($Script:DownloadExtractEvent)
			}

			try { $ps.Dispose() } catch { Write-SwallowedException -ErrorRecord $_ -Source 'UpdateOverlayModule.DownloadCleanup.DisposePowerShell' }
			try { $runspace.Dispose() } catch { Write-SwallowedException -ErrorRecord $_ -Source 'UpdateOverlayModule.DownloadCleanup.DisposeRunspace' }
		}
	}.GetNewClosure())

	$timer.Start()
}
