# Dialog helper split file loaded by Module\GUI\DialogHelpers.ps1.

	<#
	    .SYNOPSIS
	    Internal function Show-GuiRemoteConsoleDialog.
	#>

	function Show-GuiRemoteConsoleDialog
	{
		$theme = $Script:CurrentTheme
		if (-not $theme)
		{
			return $null
		}

		$bc = New-SafeBrushConverter -Context 'DialogHelpers-RemoteConsole'
		$windowTitle = Get-UxLocalizedString -Key 'GuiRemoteConsole' -Fallback 'Remote Console'
		$windowSubtitle = Get-UxLocalizedString -Key 'GuiRemoteConsoleSubtitle' -Fallback 'Monitor and control the current remote orchestration context.'
		$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'
		$refreshLabel = Get-UxLocalizedString -Key 'GuiRefreshButton' -Fallback 'Refresh'
		$preflightLabel = Get-UxLocalizedString -Key 'GuiPlanPreflightChecks' -Fallback 'Preflight'

		[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$windowTitle"
	Width="920" Height="640"
	MinWidth="760" MinHeight="560"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="FluentSystemIcons"
	FontSize="12"
	Background="Transparent"
	WindowStyle="None"
	AllowsTransparency="True">
	<Border Name="RootBorder" CornerRadius="8">
		<Grid>
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="*"/>
				<RowDefinition Height="Auto"/>
			</Grid.RowDefinitions>

			<Border Name="DlgTitleBar" Grid.Row="0" Background="$($theme.HeaderBg)" CornerRadius="8,8,0,0" Padding="12,8,8,8" Cursor="Arrow">
				<Grid>
					<TextBlock Text="$windowTitle" VerticalAlignment="Center" FontSize="12" Foreground="$($theme.TextPrimary)"/>
					<Button Name="BtnDlgClose" Content="x" FontFamily="Arial" FontSize="12" Width="32" Height="28"
						Background="Transparent" Foreground="$($theme.TextPrimary)" BorderThickness="0" Cursor="Hand"
						HorizontalAlignment="Right" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
				</Grid>
			</Border>

			<Border Grid.Row="1" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,0,0,1"
					Padding="20,14,20,14">
				<StackPanel>
					<TextBlock Name="TxtDialogTitle" Text="$windowTitle" FontSize="16" FontWeight="SemiBold"
							   Foreground="$($theme.TextPrimary)"/>
					<TextBlock Name="TxtDialogSubtitle" Text="$windowSubtitle"
							   FontSize="12" Foreground="$($theme.TextMuted)" Margin="0,2,0,0" TextWrapping="Wrap"/>
				</StackPanel>
			</Border>

			<ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="20,18,20,18">
				<Grid>
					<Grid.RowDefinitions>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="Auto"/>
					</Grid.RowDefinitions>
					<TextBlock Name="TxtConnectedTargets" Grid.Row="0" Text="" Margin="0,0,0,8" TextWrapping="Wrap" Foreground="$($theme.TextPrimary)"/>
					<TextBlock Name="TxtApprovedTargets" Grid.Row="1" Text="" Margin="0,0,0,8" TextWrapping="Wrap" Foreground="$($theme.TextSecondary)"/>
					<TextBlock Name="TxtConnectedAt" Grid.Row="2" Text="" Margin="0,0,0,8" TextWrapping="Wrap" Foreground="$($theme.TextSecondary)"/>
					<TextBlock Name="TxtApprovalMessage" Grid.Row="3" Text="" Margin="0,0,0,8" TextWrapping="Wrap" Foreground="$($theme.TextSecondary)"/>
					<TextBlock Name="TxtCachedSessions" Grid.Row="4" Text="" Margin="0,0,0,8" TextWrapping="Wrap" Foreground="$($theme.TextSecondary)"/>
					<Border Grid.Row="5" Background="$($theme.InputBg)" BorderBrush="$($theme.BorderColor)" BorderThickness="1" CornerRadius="6" Padding="12,10,12,10" Margin="0,0,0,8">
						<StackPanel>
							<Grid Margin="0,0,0,8">
								<Grid.ColumnDefinitions>
									<ColumnDefinition Width="*"/>
									<ColumnDefinition Width="Auto"/>
								</Grid.ColumnDefinitions>
								<TextBlock Grid.Column="0" Text="Recent remote runs" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)" VerticalAlignment="Center"/>
								<TextBox Name="TxtFilterRuns" Grid.Column="1" Width="200" Padding="4" VerticalAlignment="Center"/>
							</Grid>
							<ListView Name="LstRecentRemoteRuns" BorderThickness="0" Background="Transparent" Height="180">
								<ListView.View>
									<GridView>
										<GridViewColumn Header="Date" Width="155" DisplayMemberBinding="{Binding Timestamp, StringFormat='yyyy-MM-dd HH:mm:ss'}"/>
										<GridViewColumn Header="Operation" Width="120" DisplayMemberBinding="{Binding Operation}"/>
										<GridViewColumn Header="State" Width="90" DisplayMemberBinding="{Binding TerminalState}"/>
										<GridViewColumn Header="Targets" Width="70" DisplayMemberBinding="{Binding TargetCount}"/>
										<GridViewColumn Header="Counts" Width="240" DisplayMemberBinding="{Binding CountsSummary}"/>
										<GridViewColumn Header="Summary" Width="420" DisplayMemberBinding="{Binding Summary}"/>
									</GridView>
								</ListView.View>
							</ListView>
						</StackPanel>
					</Border>
					<TextBlock Name="TxtConsoleHint" Grid.Row="6" Text="" Margin="0,6,0,0" TextWrapping="Wrap" Foreground="$($theme.TextMuted)"/>
				</Grid>
			</ScrollViewer>

			<Border Grid.Row="3" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0"
					Padding="20,10,20,10">
				<WrapPanel HorizontalAlignment="Right">
					<Button Name="BtnConnect" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnDisconnect" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnApprove" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnSavePolicy" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnLoadPolicy" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnPreflight" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnRefresh" Content="" Margin="0,0,8,0" Padding="16,6" FontSize="13"/>
					<Button Name="BtnClose" Content="" Padding="16,6" FontSize="13"/>
				</WrapPanel>
			</Border>
		</Grid>
	</Border>
</Window>
"@

		$reader = [System.Xml.XmlNodeReader]::new($xaml)
		$dlg = [Windows.Markup.XamlReader]::Load($reader)
		$dlg.Owner = $Form

		$rootBorder = $dlg.FindName('RootBorder')
		if ($rootBorder)
		{
			$rootBorder.Background = $bc.ConvertFromString($theme.WindowBg)
			$rootBorder.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
			$rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
		}

		[void](GUICommon\Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))

		$dlgTitleBar = $dlg.FindName('DlgTitleBar')
		$btnDlgClose = $dlg.FindName('BtnDlgClose')
		$btnConnect = $dlg.FindName('BtnConnect')
		$btnDisconnect = $dlg.FindName('BtnDisconnect')
		$btnApprove = $dlg.FindName('BtnApprove')
		$btnSavePolicy = $dlg.FindName('BtnSavePolicy')
		$btnLoadPolicy = $dlg.FindName('BtnLoadPolicy')
		$btnPreflight = $dlg.FindName('BtnPreflight')
		$btnRefresh = $dlg.FindName('BtnRefresh')
		$btnClose = $dlg.FindName('BtnClose')
		$txtConnectedTargets = $dlg.FindName('TxtConnectedTargets')
		$txtApprovedTargets = $dlg.FindName('TxtApprovedTargets')
		$txtConnectedAt = $dlg.FindName('TxtConnectedAt')
		$txtApprovalMessage = $dlg.FindName('TxtApprovalMessage')
		$txtCachedSessions = $dlg.FindName('TxtCachedSessions')
		$lstRecentRemoteRuns = $dlg.FindName('LstRecentRemoteRuns')
		$txtConsoleHint = $dlg.FindName('TxtConsoleHint')
		$txtFilterRuns = $dlg.FindName('TxtFilterRuns')

		$promptRemoteTargetConnectionCommand = Get-GuiRuntimeCommand -Name 'Prompt-GuiRemoteTargetConnection' -CommandType 'Function'
		$setRemoteTargetContextCommand = Get-GuiRuntimeCommand -Name 'Set-GuiRemoteTargetContext' -CommandType 'Function'
		$getRemoteTargetContextCommand = Get-GuiRuntimeCommand -Name 'Get-GuiRemoteTargetContext' -CommandType 'Function'
		$clearRemoteTargetContextCommand = Get-GuiRuntimeCommand -Name 'Clear-GuiRemoteTargetContext' -CommandType 'Function'
		$setRemoteTargetApprovalCommand = Get-GuiRuntimeCommand -Name 'Set-GuiRemoteTargetApprovalList' -CommandType 'Function'
		$testRemoteTargetApprovalCommand = Get-GuiRuntimeCommand -Name 'Test-GuiRemoteTargetApproval' -CommandType 'Function'
		$exportRemoteTargetApprovalPolicyCommand = Get-GuiRuntimeCommand -Name 'Export-GuiRemoteTargetApprovalPolicy' -CommandType 'Function'
		$importRemoteTargetApprovalPolicyCommand = Get-GuiRuntimeCommand -Name 'Import-GuiRemoteTargetApprovalPolicy' -CommandType 'Function'
		$getRemoteSessionSummaryCommand = Get-GuiRuntimeCommand -Name 'Get-BaselineRemoteSessionSummary' -CommandType 'Function'
		$getRemoteRunSummariesCommand = Get-GuiRuntimeCommand -Name 'Get-BaselineRemoteRunSummaries' -CommandType 'Function'
		$getRemoteOrchestrationDetailsCommand = Get-GuiRuntimeCommand -Name 'Get-BaselineRemoteOrchestrationDetails' -CommandType 'Function'
		$getRemoteOrchestrationSummaryCommand = Get-GuiRuntimeCommand -Name 'Get-BaselineRemoteOrchestrationSummary' -CommandType 'Function'
		$exportSupportBundleCommand = Get-GuiRuntimeCommand -Name 'Export-BaselineSupportBundle' -CommandType 'Function'
		$showGuiFileSaveDialogCommand = Get-GuiRuntimeCommand -Name 'Show-GuiFileSaveDialog' -CommandType 'Function'
		$getGuiSettingsSnapshotCommand = Get-GuiRuntimeCommand -Name 'Get-GuiSettingsSnapshot' -CommandType 'Function'
		$testRemoteConnectivityCommand = Get-GuiRuntimeCommand -Name 'Test-BaselineRemoteConnectivity' -CommandType 'Function'
		$testInteractiveHostCapture = Get-GuiFunctionCapture -Name 'Test-InteractiveHost'
		$showRemoteConsoleError = {
			param(
				[string]$Title,
				[string]$Message
			)

			$canShowDialog = $false
			try
			{
				if ($testInteractiveHostCapture)
				{
					$canShowDialog = [bool](& $testInteractiveHostCapture)
				}
			}
			catch
			{
				$canShowDialog = $false
				Write-DebugSwallowedException -ErrorRecord $_ -Source 'DialogHelpers.ShowGuiRemoteConsoleDialog.ResolveErrorDialog'
			}

			if ($canShowDialog)
			{
				[void](Show-ThemedDialog -Title $Title -Message $Message -Buttons @('OK') -AccentButton 'OK')
				return
			}

			LogWarn ($Title + ': ' + $Message)
		}.GetNewClosure()

		if ($txtFilterRuns -and (Get-Command -Name 'Set-GuiWatermarkText' -CommandType Function -ErrorAction SilentlyContinue))
		{
			Set-GuiWatermarkText -TextBox $txtFilterRuns -Text 'Filter runs...'
		}

		$remoteRunsCtx = New-Object System.Windows.Controls.ContextMenu
		$ctxOpenLog = New-Object System.Windows.Controls.MenuItem
		$ctxOpenLog.Header = 'Open Log...'
		$ctxExportBundle = New-Object System.Windows.Controls.MenuItem
		$ctxExportBundle.Header = 'Export Support Bundle...'
		$ctxIncidentPack = New-Object System.Windows.Controls.MenuItem
		$ctxIncidentPack.Header = 'Generate Incident Repro Pack...'
		$ctxExportDeepLinkedBundle = New-Object System.Windows.Controls.MenuItem
		$ctxExportDeepLinkedBundle.Header = 'Export Deep-Linked Support Bundle...'
		$ctxRetryFailed = New-Object System.Windows.Controls.MenuItem
		$ctxRetryFailed.Header = 'Retry Failed Targets'
		$ctxExportFailed = New-Object System.Windows.Controls.MenuItem
		$ctxExportFailed.Header = 'Export Failed Target List...'
		
		[void]$remoteRunsCtx.Items.Add($ctxOpenLog)
		[void]$remoteRunsCtx.Items.Add($ctxExportBundle)
		[void]$remoteRunsCtx.Items.Add($ctxIncidentPack)
		[void]$remoteRunsCtx.Items.Add($ctxExportDeepLinkedBundle)
		[void]$remoteRunsCtx.Items.Add((New-Object System.Windows.Controls.Separator))
		[void]$remoteRunsCtx.Items.Add($ctxRetryFailed)
		[void]$remoteRunsCtx.Items.Add($ctxExportFailed)
		if ($lstRecentRemoteRuns) { $lstRecentRemoteRuns.ContextMenu = $remoteRunsCtx }

		$remoteRunsCtx.Add_Opened({
			$selected = $lstRecentRemoteRuns.SelectedItem
			if (-not $selected)
			{
				$ctxOpenLog.IsEnabled = $false
				$ctxExportBundle.IsEnabled = $false
				$ctxIncidentPack.IsEnabled = $false
				$ctxRetryFailed.IsEnabled = $false
				$ctxExportFailed.IsEnabled = $false
			}
			else
			{
				$hasLog = (Test-GuiObjectField -Object $selected -FieldName 'LogPath') -and -not [string]::IsNullOrWhiteSpace($selected.LogPath)
				$hasBundle = (Test-GuiObjectField -Object $selected -FieldName 'BundlePath') -and -not [string]::IsNullOrWhiteSpace($selected.BundlePath)
				$hasFailed = (Test-GuiObjectField -Object $selected -FieldName 'FailedCount') -and $selected.FailedCount -gt 0
				$canDeepLink = (Test-GuiObjectField -Object $selected -FieldName 'RunId') -and -not [string]::IsNullOrWhiteSpace([string]$selected.RunId) -and $hasFailed

				$ctxOpenLog.IsEnabled = $hasLog
				$ctxExportBundle.IsEnabled = $hasBundle
				$ctxIncidentPack.IsEnabled = ($hasBundle -and [string]$selected.TerminalState -match '(?i)Failed')
				$ctxExportDeepLinkedBundle.IsEnabled = $canDeepLink
				$ctxRetryFailed.IsEnabled = $hasFailed
				$ctxExportFailed.IsEnabled = $hasFailed
			}
		}.GetNewClosure())

		$ctxOpenLog.Add_Click({
			$selected = $lstRecentRemoteRuns.SelectedItem
			if ($selected -and (Test-GuiObjectField -Object $selected -FieldName 'LogPath') -and -not [string]::IsNullOrWhiteSpace($selected.LogPath))
			{
				Show-LogDialog -LogPath $selected.LogPath
			}
		}.GetNewClosure())

		$ctxExportBundle.Add_Click({
			$selected = $lstRecentRemoteRuns.SelectedItem
			if ($selected -and (Test-GuiObjectField -Object $selected -FieldName 'BundlePath') -and -not [string]::IsNullOrWhiteSpace($selected.BundlePath))
			{
				try { [System.Diagnostics.Process]::Start('explorer.exe', "/select,`"$($selected.BundlePath)`"") } catch { & $showRemoteConsoleError -Title 'Remote Console' -Message "Failed to show bundle: $($_.Exception.Message)" }
			}
		}.GetNewClosure())

		$ctxIncidentPack.Add_Click({
			$selected = $lstRecentRemoteRuns.SelectedItem
			if ($selected -and (Test-GuiObjectField -Object $selected -FieldName 'BundlePath') -and -not [string]::IsNullOrWhiteSpace($selected.BundlePath))
			{
				try
				{
					$incidentPackCmd = Get-GuiRuntimeCommand -Name 'New-IncidentReproductionPack' -CommandType 'Function'
					if ($incidentPackCmd)
					{
						& $incidentPackCmd -SupportBundlePath $selected.BundlePath
					}
				}
				catch
				{
					& $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to generate incident reproduction pack.`n`n{0}" -f $_.Exception.Message)
				}
			}
		}.GetNewClosure())

		$ctxExportDeepLinkedBundle.Add_Click({
			$selected = $lstRecentRemoteRuns.SelectedItem
			if (-not $selected) { return }
			if (-not (Test-GuiObjectField -Object $selected -FieldName 'RunId') -or [string]::IsNullOrWhiteSpace([string]$selected.RunId)) { return }
			if (-not (Test-GuiObjectField -Object $selected -FieldName 'FailedCount') -or [int]$selected.FailedCount -le 0) { return }
			if (-not $exportSupportBundleCommand -or -not $showGuiFileSaveDialogCommand)
			{
				& $showRemoteConsoleError -Title 'Remote Console' -Message 'Support bundle export is unavailable in this runtime.'
				return
			}

			try
			{
				$defaultFileName = 'Baseline-SupportBundle-{0}-{1}.zip' -f ((Get-Date -Format 'yyyyMMdd-HHmmss')), ([string]$selected.ComputerName -replace '[^A-Za-z0-9._-]', '_')
				$savePath = & $showGuiFileSaveDialogCommand -Title 'Export Deep-Linked Support Bundle' -Filter 'ZIP Files (*.zip)|*.zip|All Files (*.*)|*.*' -DefaultExtension 'zip' -FileName $defaultFileName
				if ([string]::IsNullOrWhiteSpace($savePath)) { return }

				$sessionSnapshot = $null
				try { if ($getGuiSettingsSnapshotCommand) { $sessionSnapshot = & $getGuiSettingsSnapshotCommand } } catch { $sessionSnapshot = $null; Write-DebugSwallowedException -ErrorRecord $_ -Source 'DialogHelpers.ShowGuiRemoteConsoleDialog.LoadSessionSnapshot' }
				$sessionStatePath = Join-Path ([System.IO.Path]::GetTempPath()) ('BaselineSupportBundleSession_{0}.json' -f [guid]::NewGuid().ToString('N'))
				try
				{
					$sessionPayload = [ordered]@{
						Schema = 'Baseline.GuiSession'
						SchemaVersion = 1
						SavedAt = (Get-Date).ToString('o')
						State = $sessionSnapshot
					}
					($sessionPayload | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $sessionStatePath -Encoding UTF8 -Force

					$systemSnapshot = $null
					try { $systemSnapshot = New-SystemStateSnapshot -Manifest $Script:TweakManifest } catch { $systemSnapshot = $null; Write-DebugSwallowedException -ErrorRecord $_ -Source 'DialogHelpers.ShowGuiRemoteConsoleDialog.LoadSystemSnapshot' }

					$connectivityResults = @()
					try
					{
						$ctx = Invoke-CapturedFunction -Name 'Get-GuiRemoteTargetContext'
						if ($ctx -and (Test-GuiObjectField -Object $ctx -FieldName 'LastConnectivityResults'))
						{
							$connectivityResults = @($ctx.LastConnectivityResults)
						}
					}
					catch
					{
						$connectivityResults = @()
						Write-DebugSwallowedException -ErrorRecord $_ -Source 'DialogHelpers.ShowGuiRemoteConsoleDialog.LoadConnectivityResults'
					}

					$result = & $exportSupportBundleCommand -OutputPath $savePath -ProfilePath $sessionStatePath -SystemSnapshot $systemSnapshot -Manifest $Script:TweakManifest -IncludeAuditLog -IncludeTestReport -ConnectivityResults $connectivityResults -DeepLinkRunId @([string]$selected.RunId) -DeepLinkComputerName @([string]$selected.ComputerName) -DeepLinkOperation @([string]$selected.Operation)
					LogInfo ("Exported deep-linked support bundle to {0}" -f $result.OutputPath)
					try { [System.Diagnostics.Process]::Start('explorer.exe', "/select,`"$($result.OutputPath)`"") | Out-Null } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'DialogHelpers.ShowGuiRemoteConsoleDialog.StartExplorer' }
				}
				finally
				{
					if (Test-Path -LiteralPath $sessionStatePath)
					{
						try { Remove-Item -LiteralPath $sessionStatePath -Force -ErrorAction SilentlyContinue } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'DialogHelpers.ShowGuiRemoteConsoleDialog.RemoveSessionStatePath' }
					}
				}
			}
			catch
			{
				& $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to export deep-linked support bundle.`n`n{0}" -f $_.Exception.Message)
			}
		}.GetNewClosure())

		$ctxRetryFailed.Add_Click({
			$selected = $lstRecentRemoteRuns.SelectedItem
			if ($selected -and (Test-GuiObjectField -Object $selected -FieldName 'FailedCount') -and $selected.FailedCount -gt 0)
			{
				$targets = if (Test-GuiObjectField -Object $selected -FieldName 'FailedTargets') { @($selected.FailedTargets) } else { @() }
				if ($targets.Count -gt 0)
				{
					try
					{
						$ctx = Invoke-CapturedFunction -Name 'Get-GuiRemoteTargetContext'
						$cred = if ($ctx) { $ctx.Credential } else { $null }
						$null = Invoke-CapturedFunction -Name 'Set-GuiRemoteTargetContext' -Parameters @{
							ComputerName = $targets
							Credential = $cred
							StatusMessage = 'Context updated to retry failed targets.'
						}
						& $refreshConsole
					}
					catch
					{
						& $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to stage retry targets.`n`n{0}" -f $_.Exception.Message)
					}
				}
				else
				{
					& $showRemoteConsoleError -Title 'Remote Console' -Message "Failed target list not available in this summary."
				}
			}
		}.GetNewClosure())

		$ctxExportFailed.Add_Click({
			$selected = $lstRecentRemoteRuns.SelectedItem
			if ($selected -and (Test-GuiObjectField -Object $selected -FieldName 'FailedCount') -and $selected.FailedCount -gt 0)
			{
				$targets = if (Test-GuiObjectField -Object $selected -FieldName 'FailedTargets') { @($selected.FailedTargets) } else { @() }
				if ($targets.Count -gt 0)
				{
					$dialog = New-Object Microsoft.Win32.SaveFileDialog
					$dialog.Title = 'Export Failed Targets'
					$dialog.Filter = 'Text Files (*.txt)|*.txt|All Files (*.*)|*.*'
					$dialog.DefaultExt = 'txt'
					$dialog.FileName = ('FailedTargets-{0}.txt' -f $selected.Timestamp.ToString('yyyyMMdd-HHmmss'))
					if ($dialog.ShowDialog($dlg) -eq $true)
					{
						try { [System.IO.File]::WriteAllLines($dialog.FileName, $targets) } catch { & $showRemoteConsoleError -Title 'Export Failed' -Message ("Failed to write file.`n`n{0}" -f $_.Exception.Message) }
					}
				}
				else { & $showRemoteConsoleError -Title 'Remote Console' -Message "Failed target list not available in this summary." }
			}
		}.GetNewClosure())

		$refreshConsole = {
			$context = $null
			try { $context = Invoke-CapturedFunction -Name 'Get-GuiRemoteTargetContext' } catch { $context = $null }
			$sessions = @()
			try { $sessions = @((Invoke-CapturedFunction -Name 'Get-BaselineRemoteSessionSummary')) } catch { $sessions = @() }
			$recentRuns = @()
			try
			{
				if ($getRemoteRunSummariesCommand)
				{
					$recentRuns = @((Invoke-CapturedFunction -Name 'Get-BaselineRemoteRunSummaries' -Parameters @{ MaxRecords = 5 }))
				}
				elseif (Get-GuiFunctionCapture -Name 'Get-BaselineRemoteOrchestrationDetails')
				{
					$recentRuns = @((Invoke-CapturedFunction -Name 'Get-BaselineRemoteOrchestrationDetails' -Parameters @{ MaxRecords = 5 }))
				}
				else
				{
					$recentRuns = @((Invoke-CapturedFunction -Name 'Get-BaselineRemoteOrchestrationSummary' -Parameters @{ MaxRecords = 5 }))
				}
			}
			catch
			{
				$recentRuns = @()
			}

			$recentRunRows = @()
			if ($recentRuns.Count -gt 0)
			{
				$recentRunRows = @($recentRuns | ForEach-Object {
					$timestamp = $null
					try { $timestamp = [datetime]::Parse([string]$_.Timestamp) } catch { $timestamp = [datetime]::UtcNow }
					$succeededCount = if ($_.PSObject.Properties['SucceededCount']) { [int]$_.SucceededCount } else { 0 }
					$failedCount = if ($_.PSObject.Properties['FailedCount']) { [int]$_.FailedCount } else { 0 }
					$skippedCount = if ($_.PSObject.Properties['SkippedCount']) { [int]$_.SkippedCount } else { 0 }
					$retryingCount = if ($_.PSObject.Properties['RetryingCount']) { [int]$_.RetryingCount } else { 0 }
					$cancelledCount = if ($_.PSObject.Properties['CancelledCount']) { [int]$_.CancelledCount } else { 0 }
					$attempts = if ($_.PSObject.Properties['TotalAttempts']) { [int]$_.TotalAttempts } else { 0 }
					$retries = if ($_.PSObject.Properties['TotalRetries']) { [int]$_.TotalRetries } else { 0 }

					[pscustomobject]@{
						Timestamp      = $timestamp
						Operation      = if ($_.PSObject.Properties['Operation']) { [string]$_.Operation } else { 'Remote' }
						TerminalState  = if ($_.PSObject.Properties['TerminalState']) { [string]$_.TerminalState } else { 'Unknown' }
						TargetCount    = if ($_.PSObject.Properties['TargetCount']) { [int]$_.TargetCount } else { 0 }
						FailedCount    = $failedCount
						FailedTargets  = if ($_.PSObject.Properties['FailedTargets']) { @($_.FailedTargets) } else { @() }
						CountsSummary  = ('Success={0}, Failed={1}, Skipped={2}, Retrying={3}, Cancelled={4}, Attempts={5}, Retries={6}' -f $succeededCount, $failedCount, $skippedCount, $retryingCount, $cancelledCount, $attempts, $retries)
						Summary        = if ($_.PSObject.Properties['Summary']) { [string]$_.Summary } else { ('{0} | {1} | Run {2}' -f $timestamp.ToString('yyyy-MM-dd HH:mm:ss'), (if ($_.PSObject.Properties['Operation']) { [string]$_.Operation } else { 'Remote' }), (if ($_.PSObject.Properties['RunId']) { [string]$_.RunId } else { 'n/a' })) }
						LogPath        = if ($_.PSObject.Properties['LogPath']) { [string]$_.LogPath } else { $null }
						BundlePath     = if ($_.PSObject.Properties['BundlePath']) { [string]$_.BundlePath } else { $null }
					}
				})
			}

			if ($txtFilterRuns -and -not [string]::IsNullOrWhiteSpace($txtFilterRuns.Text))
			{
				$filter = $txtFilterRuns.Text
				$recentRunRows = @($recentRunRows | Where-Object {
					$_.Operation -match $filter -or
					$_.TerminalState -match $filter -or
					$_.Summary -match $filter
				})
			}

			if ($txtConnectedTargets)
			{
				if ($context -and $context.Connected -and $context.TargetComputers.Count -gt 0)
				{
					$txtConnectedTargets.Text = ('Connected targets: {0}' -f ($context.TargetComputers -join ', '))
				}
				else
				{
					$txtConnectedTargets.Text = 'Connected targets: none'
				}
			}

			if ($txtApprovedTargets)
			{
				if ($context -and $context.ApprovedTargetComputers -and $context.ApprovedTargetComputers.Count -gt 0)
				{
					$txtApprovedTargets.Text = ('Approved targets: {0}' -f ($context.ApprovedTargetComputers -join ', '))
				}
				else
				{
					$txtApprovedTargets.Text = 'Approved targets: none'
				}
			}

			if ($txtConnectedAt)
			{
				$txtConnectedAt.Text = if ($context -and $context.ConnectedAt) { ('Connected at (UTC): {0}' -f $context.ConnectedAt) } else { 'Connected at (UTC): n/a' }
			}

			if ($txtApprovalMessage)
			{
				$txtApprovalMessage.Text = if ($context -and $context.ApprovalMessage) { ('Approval message: {0}' -f $context.ApprovalMessage) } else { 'Approval message: n/a' }
			}

			if ($txtCachedSessions)
			{
				if ($sessions.Count -gt 0)
				{
					$txtCachedSessions.Text = ('Cached sessions: {0}' -f (($sessions | ForEach-Object { '{0} [{1}]' -f $_.ComputerName, $_.State }) -join '; '))
				}
				else
				{
					$txtCachedSessions.Text = 'Cached sessions: none'
				}
			}

			if ($lstRecentRemoteRuns)
			{
				$lstRecentRemoteRuns.ItemsSource = $recentRunRows
				if ($recentRunRows.Count -eq 0)
				{
					$lstRecentRemoteRuns.IsEnabled = $false
				}
				else
				{
					$lstRecentRemoteRuns.IsEnabled = $true
				}
			}

			if ($txtConsoleHint)
			{
				$txtConsoleHint.Text = 'Use the controls below to connect, approve, save policy, and load policy for the current remote context.'
			}

			if ($btnDisconnect) { $btnDisconnect.IsEnabled = [bool]($context -and $context.Connected -and $context.TargetComputers.Count -gt 0) }
			if ($btnApprove) { $btnApprove.IsEnabled = [bool]($context -and $context.Connected -and $context.TargetComputers.Count -gt 0) }
			if ($btnSavePolicy) { $btnSavePolicy.IsEnabled = [bool]($context -and $context.Connected -and $context.TargetComputers.Count -gt 0 -and $context.ApprovedTargetComputers.Count -gt 0) }
			if ($btnLoadPolicy) { $btnLoadPolicy.IsEnabled = [bool]($context -and $context.Connected -and $context.TargetComputers.Count -gt 0) }
			if ($btnPreflight) { $btnPreflight.IsEnabled = [bool]($context -and $context.Connected -and $context.TargetComputers.Count -gt 0) }
		}.GetNewClosure()

		if ($dlgTitleBar) { $dlgTitleBar.Add_MouseLeftButtonDown({ $dlg.DragMove() }.GetNewClosure()) }
		if ($btnDlgClose) { $btnDlgClose.Add_Click({ $dlg.Close() }.GetNewClosure()) }
		if ($btnClose)
		{
			$btnClose.Content = $closeLabel
			Set-ButtonChrome -Button $btnClose -Variant 'Primary' -Compact
			$btnClose.IsDefault = $true
			$btnClose.IsCancel = $true
			$btnClose.Add_Click({ $dlg.Close() }.GetNewClosure())
		}
		if ($btnRefresh)
		{
			$btnRefresh.Content = $refreshLabel
			Set-ButtonChrome -Button $btnRefresh -Variant 'Secondary' -Compact
			$btnRefresh.Add_Click({
				& $refreshConsole
			}.GetNewClosure())
		}
		if ($btnConnect)
		{
			$btnConnect.Content = (Get-UxLocalizedString -Key 'GuiRemoteConnectTitle' -Fallback 'Connect to Computer')
			Set-ButtonChrome -Button $btnConnect -Variant 'Secondary' -Compact
			$btnConnect.Add_Click({
				try
				{
					$request = Invoke-CapturedFunction -Name 'Prompt-GuiRemoteTargetConnection'
					if (-not $request) { return }
					$null = Invoke-CapturedFunction -Name 'Set-GuiRemoteTargetContext' -Parameters @{
						ComputerName = $request.ComputerName
						Credential = $request.Credential
						StatusMessage = 'Remote target connected.'
					}
					& $refreshConsole
				}
				catch
				{
					& $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to connect to remote target.`n`n{0}" -f $_.Exception.Message)
				}
			}.GetNewClosure())
		}
		if ($btnDisconnect)
		{
			$btnDisconnect.Content = (Get-UxLocalizedString -Key 'GuiRemoteDisconnectTitle' -Fallback 'Disconnect')
			Set-ButtonChrome -Button $btnDisconnect -Variant 'Secondary' -Compact
			$btnDisconnect.Add_Click({
				try
				{
					$null = Invoke-CapturedFunction -Name 'Clear-GuiRemoteTargetContext'
					& $refreshConsole
				}
				catch
				{
					& $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to disconnect remote target.`n`n{0}" -f $_.Exception.Message)
				}
			}.GetNewClosure())
		}
		if ($btnApprove)
		{
			$btnApprove.Content = (Get-UxLocalizedString -Key 'GuiMenuToolsApproveRemoteTargets' -Fallback 'Approve Target List...')
			Set-ButtonChrome -Button $btnApprove -Variant 'Secondary' -Compact
			$btnApprove.Add_Click({
				try
				{
					$context = Invoke-CapturedFunction -Name 'Get-GuiRemoteTargetContext'
					if (-not $context -or -not $context.Connected -or $context.TargetComputers.Count -eq 0) { return }
					$targets = @($context.TargetComputers)
					$null = Invoke-CapturedFunction -Name 'Set-GuiRemoteTargetApprovalList' -Parameters @{
						ComputerName = $targets
						ApprovalMessage = 'Remote target list approved from Remote Console.'
					}
					& $refreshConsole
				}
				catch
				{
					& $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to approve target list.`n`n{0}" -f $_.Exception.Message)
				}
			}.GetNewClosure())
		}
		if ($btnSavePolicy)
		{
			$btnSavePolicy.Content = (Get-UxLocalizedString -Key 'GuiMenuToolsSaveRemoteApprovalPolicy' -Fallback 'Save Remote Approval Policy...')
			Set-ButtonChrome -Button $btnSavePolicy -Variant 'Secondary' -Compact
			if (-not $exportRemoteTargetApprovalPolicyCommand) { $btnSavePolicy.IsEnabled = $false }
			$btnSavePolicy.Add_Click({
				if (-not $exportRemoteTargetApprovalPolicyCommand)
				{
					& $showRemoteConsoleError -Title 'Remote Console' -Message 'Remote approval policy export is unavailable in this runtime.'
					return
				}
				try { $null = Invoke-CapturedFunction -Name 'Export-GuiRemoteTargetApprovalPolicy' } catch { & $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to save remote approval policy.`n`n{0}" -f $_.Exception.Message) }
			}.GetNewClosure())
		}
		if ($btnLoadPolicy)
		{
			$btnLoadPolicy.Content = (Get-UxLocalizedString -Key 'GuiMenuToolsLoadRemoteApprovalPolicy' -Fallback 'Load Remote Approval Policy...')
			Set-ButtonChrome -Button $btnLoadPolicy -Variant 'Secondary' -Compact
			if (-not $importRemoteTargetApprovalPolicyCommand) { $btnLoadPolicy.IsEnabled = $false }
			$btnLoadPolicy.Add_Click({
				if (-not $importRemoteTargetApprovalPolicyCommand)
				{
					& $showRemoteConsoleError -Title 'Remote Console' -Message 'Remote approval policy import is unavailable in this runtime.'
					return
				}
				try { $null = Invoke-CapturedFunction -Name 'Import-GuiRemoteTargetApprovalPolicy'; & $refreshConsole } catch { & $showRemoteConsoleError -Title 'Remote Console' -Message ("Failed to load remote approval policy.`n`n{0}" -f $_.Exception.Message) }
			}.GetNewClosure())
		}
		if ($btnPreflight)
		{
			$btnPreflight.Content = $preflightLabel
			Set-ButtonChrome -Button $btnPreflight -Variant 'Secondary' -Compact
			$btnPreflight.Add_Click({
				try
				{
					$context = Invoke-CapturedFunction -Name 'Get-GuiRemoteTargetContext'
					if (-not $context -or -not $context.Connected -or $context.TargetComputers.Count -eq 0) { return }
					if (-not (Get-GuiFunctionCapture -Name 'Invoke-PreflightChecks')) { throw 'Preflight helper is not available.' }

					$results = Invoke-CapturedFunction -Name 'Invoke-PreflightChecks' -Parameters @{
						RemoteTargets = @($context.TargetComputers)
					}
					$lines = [System.Collections.Generic.List[string]]::new()
					[void]$lines.Add('Remote preflight results:')
					if ($results -and $results.SupportedEnvironmentClassification -and $results.SupportedEnvironmentClassification.Summary)
					{
						[void]$lines.Add($results.SupportedEnvironmentClassification.Summary)
					}
					if ($results -and $results.WinRMReachability -and $results.WinRMReachability.Summary)
					{
						[void]$lines.Add(('WinRM reachability: {0}' -f $results.WinRMReachability.Summary))
					}
					if ($results -and $results.Credentials -and $results.Credentials.Summary)
					{
						[void]$lines.Add(('Credentials: {0}' -f $results.Credentials.Summary))
					}
					if ($results -and $results.PolicyConflictSignals -and $results.PolicyConflictSignals.Summary)
					{
						[void]$lines.Add(('Policy signals: {0}' -f $results.PolicyConflictSignals.Summary))
					}

					$remoteCategories = @()
					if ($results -and $results.PSObject.Properties['RiskCategories'] -and $results.RiskCategories)
					{
						$remoteCategories = @($results.RiskCategories | Where-Object { $_ -and [string]$_.Status -ne 'Passed' })
					}
					elseif ($results -and $results.PolicyConflictSignals -and $results.PolicyConflictSignals.PSObject.Properties['Categories'])
					{
						$remoteCategories = @($results.PolicyConflictSignals.Categories | Where-Object { $_ -and [string]$_.Status -ne 'Passed' })
					}
					if ($remoteCategories.Count -gt 0)
					{
						[void]$lines.Add(' ')
						[void]$lines.Add('Risk categories:')
						foreach ($cat in $remoteCategories)
						{
							$statusMark = if ([string]$cat.Status -eq 'Failed') { '!' } else { '*' }
							[void]$lines.Add(('{0} {1} ({2}): {3}' -f $statusMark, $cat.Name, $cat.Status, $cat.Summary))
							if ($cat.RemediationActions -and @($cat.RemediationActions).Count -gt 0)
							{
								foreach ($action in $cat.RemediationActions)
								{
									if (-not [string]::IsNullOrWhiteSpace([string]$action))
									{
										[void]$lines.Add(('    -> {0}' -f [string]$action))
									}
								}
							}
							if (-not [string]::IsNullOrWhiteSpace([string]$cat.DocumentationPath))
							{
								[void]$lines.Add(('    Remediation guide: {0}' -f [string]$cat.DocumentationPath))
							}
							if (-not [string]::IsNullOrWhiteSpace([string]$cat.LogHint))
							{
								[void]$lines.Add(('    Logs: {0}' -f [string]$cat.LogHint))
							}
						}
					}

					[void]$lines.Add(' ')
					[void]$lines.Add('Checks:')
					foreach ($result in @($results.AllResults))
					{
						if (-not $result) { continue }
						$line = '{0} -> {1}: {2}' -f $result.Name, $result.Status, $result.Message
						if ($result.PSObject.Properties['Key'] -and -not [string]::IsNullOrWhiteSpace([string]$result.Key))
						{
							$line += " | Key: $($result.Key)"
						}
						if ($result.PSObject.Properties['Category'] -and -not [string]::IsNullOrWhiteSpace([string]$result.Category))
						{
							$line += " | Category: $($result.Category)"
						}
						if ($result.PSObject.Properties['RemediationActions'] -and $result.RemediationActions)
						{
							$actions = @($result.RemediationActions)
							if ($actions.Count -gt 0)
							{
								$line += " | Remediation: $($actions -join '; ')"
							}
						}
						[void]$lines.Add($line)

						if ($result.PSObject.Properties['Details'] -and $result.Details)
						{
							if ($result.Details -is [System.Collections.IDictionary])
							{
								foreach ($detailKey in @($result.Details.Keys | Sort-Object))
								{
									[void]$lines.Add(('  - {0}: {1}' -f $detailKey, $result.Details[$detailKey]))
								}
							}
							elseif ($result.Details.PSObject.Properties.Count -gt 0)
							{
								foreach ($detailProp in @($result.Details.PSObject.Properties | Sort-Object Name))
								{
									[void]$lines.Add(('  - {0}: {1}' -f $detailProp.Name, $detailProp.Value))
								}
							}
						}
					}
					[void](Show-ThemedDialog -Title 'Remote Console Preflight' -Message ($lines -join [Environment]::NewLine) -Buttons @('OK') -AccentButton 'OK')
				}
				catch
				{
					& $showRemoteConsoleError -Title 'Remote Console Preflight' -Message ("Failed to run remote preflight.`n`n{0}" -f $_.Exception.Message)
				}
			}.GetNewClosure())
		}

		$dlg.Add_ContentRendered({
			& $refreshConsole
		})
		$dlg.Add_KeyDown({
			$eventArgs = $args[1]
			if ($eventArgs.Key -eq [System.Windows.Input.Key]::Escape)
			{
				$dlg.Close()
			}
		})

		[void]($dlg.ShowDialog())
		return $null
	}

