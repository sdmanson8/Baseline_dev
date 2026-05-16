$Script:DownloadStartEvent = {
		$uri = 'https://github.com/sdmanson8/Baseline/archive/refs/heads/main.zip'
		$tempPath = Join-Path ([System.IO.Path]::GetTempPath()) 'Baseline_Update.zip'
		if ($startBaselineDownloadScript)
		{
			& $startBaselineDownloadScript -Uri $uri -DestinationPath $tempPath
		}
		else
		{
			LogWarning 'Start-BaselineDownload not available; update download action was skipped.'
		}
	}.GetNewClosure()

	$Script:DownloadExtractEvent = {
		if ($TxtDownloadProgressLabel) { $TxtDownloadProgressLabel.Text = (Get-UxLocalizedString -Key 'GuiStatusExtractingArchive' -Fallback 'Extracting archive...') }
		if ($BtnDownloadYes) { $BtnDownloadYes.IsEnabled = $false }
		if ($BtnDownloadNo) { $BtnDownloadNo.IsEnabled = $false }

		$zipPath = Join-Path ([System.IO.Path]::GetTempPath()) 'Baseline_Update.zip'
		$extractPath = Join-Path ([System.IO.Path]::GetTempPath()) 'Baseline_New'

		Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

		if ($TxtDownloadProgressLabel) { $TxtDownloadProgressLabel.Text = (Get-UxLocalizedString -Key 'GuiStatusReadyToRestart' -Fallback 'Ready to restart!') }

		# Add your custom bootstrap/overwrite logic here to finalize the update
	}.GetNewClosure()
