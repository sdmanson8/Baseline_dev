# GUI session state, undo snapshots, and settings profile management

<#
    .SYNOPSIS
    Internal function Resolve-GuiModePreference.
#>

function Resolve-GuiModePreference
{
	param (
		[bool]$SafeMode,
		[bool]$AdvancedMode
	)

	if ($SafeMode)
	{
		return [pscustomobject]@{
			SafeMode = $true
			AdvancedMode = $false
		}
	}

	if ($AdvancedMode)
	{
		return [pscustomobject]@{
			SafeMode = $false
			AdvancedMode = $true
		}
	}

	return [pscustomobject]@{
		SafeMode = $true
		AdvancedMode = $false
	}
}

<#
    .SYNOPSIS
    Internal function Get-GuiRemoteTargetContext.
#>

function Get-GuiRemoteTargetContext
{
	<# .SYNOPSIS Returns the current remote target context. #>
	if (-not $Script:Ctx)
	{
		return [pscustomobject]@{
			Connected                 = $false
			TargetComputers           = @()
			ApprovedTargetComputers   = @()
			Credential                = $null
			ConnectedAt               = $null
			ApprovedAt                = $null
			StatusMessage             = $null
			ApprovalMessage           = $null
			ConnectionMethod          = 'WinRM'
			LastConnectivityResults   = @()
		}
	}

	if (-not $Script:Ctx.ContainsKey('Remote'))
	{
		$Script:Ctx['Remote'] = @{
			Connected                 = $false
			TargetComputers           = @()
			ApprovedTargetComputers   = @()
			Credential                = $null
			ConnectedAt               = $null
			ApprovedAt                = $null
			StatusMessage             = $null
			ApprovalMessage           = $null
			ConnectionMethod          = 'WinRM'
			LastConnectivityResults   = @()
		}
	}

	if (-not $Script:Ctx.Remote.ContainsKey('ConnectionMethod')) { $Script:Ctx.Remote['ConnectionMethod'] = 'WinRM' }
	if (-not $Script:Ctx.Remote.ContainsKey('LastConnectivityResults')) { $Script:Ctx.Remote['LastConnectivityResults'] = @() }

	return [pscustomobject]@{
		Connected                 = [bool]$Script:Ctx.Remote.Connected
		TargetComputers           = @($Script:Ctx.Remote.TargetComputers)
		ApprovedTargetComputers   = @($Script:Ctx.Remote.ApprovedTargetComputers)
		Credential                = $Script:Ctx.Remote.Credential
		ConnectedAt               = $Script:Ctx.Remote.ConnectedAt
		ApprovedAt                = $Script:Ctx.Remote.ApprovedAt
		StatusMessage             = $Script:Ctx.Remote.StatusMessage
		ApprovalMessage           = $Script:Ctx.Remote.ApprovalMessage
		ConnectionMethod          = [string]$Script:Ctx.Remote.ConnectionMethod
		LastConnectivityResults   = @($Script:Ctx.Remote.LastConnectivityResults)
	}
}

<#
    .SYNOPSIS
    Internal function Test-GuiRemoteTargetConnected.
#>

function Test-GuiRemoteTargetConnected
{
	<# .SYNOPSIS Tests whether a remote target context is currently active. #>
	return [bool]((Get-GuiRemoteTargetContext).Connected)
}

<#
    .SYNOPSIS
    Internal function .
#>
function Set-GuiRemoteTargetContext
{
	<# .SYNOPSIS Stores the active remote target context for the GUI session. #>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string[]]$ComputerName,

		[System.Management.Automation.PSCredential]$Credential,

		[string]$StatusMessage,

		[string]$ConnectionMethod = 'WinRM'
	)

	if (-not $Script:Ctx)
	{
		throw 'GUI context has not been initialized.'
	}

	$targets = @($ComputerName | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim() })
	if ($targets.Count -eq 0)
	{
		throw 'At least one computer name is required.'
	}

	$canonicalMethod = if (Get-Command -Name 'ConvertTo-BaselineRemoteConnectionMethod' -CommandType Function -ErrorAction SilentlyContinue) {
		ConvertTo-BaselineRemoteConnectionMethod -Method $ConnectionMethod
	} else {
		'WinRM'
	}

	$Script:Ctx.Remote.Connected = $true
	$Script:Ctx.Remote.TargetComputers = @($targets)
	$Script:Ctx.Remote.ApprovedTargetComputers = @()
	$Script:Ctx.Remote.Credential = $Credential
	$Script:Ctx.Remote.ConnectedAt = [datetime]::UtcNow.ToString('o')
	$Script:Ctx.Remote.ApprovedAt = $null
	$Script:Ctx.Remote.StatusMessage = if ([string]::IsNullOrWhiteSpace($StatusMessage)) { 'Remote target connected.' } else { [string]$StatusMessage }
	$Script:Ctx.Remote.ApprovalMessage = $null
	$Script:Ctx.Remote.ConnectionMethod = $canonicalMethod

	$displayTargets = ($targets -join ', ')
	if ($Script:MenuActionsDisconnect) { $Script:MenuActionsDisconnect.IsEnabled = $true }
	Set-GuiStatusText -Text ("Remote: {0}" -f $displayTargets) -Tone 'accent'
	try { Update-GuiRemoteModeBanner } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.Set-GuiRemoteTargetContext.UpdateGuiRemoteModeBanner' }
	return (Get-GuiRemoteTargetContext)
}

<#
    .SYNOPSIS
    Internal function Clear-GuiRemoteTargetContext.
#>

function Clear-GuiRemoteTargetContext
{
	<# .SYNOPSIS Clears the active remote target context. #>
	if (-not $Script:Ctx)
	{
		return
	}

	if (-not $Script:Ctx.ContainsKey('Remote'))
	{
		return
	}

	$Script:Ctx.Remote.Connected = $false
	$Script:Ctx.Remote.TargetComputers = @()
	$Script:Ctx.Remote.ApprovedTargetComputers = @()
	$Script:Ctx.Remote.Credential = $null
	$Script:Ctx.Remote.ConnectedAt = $null
	$Script:Ctx.Remote.ApprovedAt = $null
	$Script:Ctx.Remote.StatusMessage = $null
	$Script:Ctx.Remote.ApprovalMessage = $null
	$Script:Ctx.Remote.ConnectionMethod = 'WinRM'
	$Script:Ctx.Remote.LastConnectivityResults = @()
	if (Get-Command -Name 'Clear-BaselineRemoteSessionCache' -CommandType Function -ErrorAction SilentlyContinue)
	{
		try { Clear-BaselineRemoteSessionCache } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.Clear-GuiRemoteTargetContext.ClearBaselineRemoteSessionCache' }
	}
	if ($Script:MenuActionsDisconnect) { $Script:MenuActionsDisconnect.IsEnabled = $false }
	Set-GuiStatusText -Text (Get-UxLocalizedString -Key 'GuiRemoteDisconnected' -Fallback 'Remote target disconnected.') -Tone 'muted'
	try { Update-GuiRemoteModeBanner } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.Clear-GuiRemoteTargetContext.UpdateGuiRemoteModeBanner' }
}

<#
    .SYNOPSIS
    Internal function Set-GuiRemoteConnectivityResults.
#>

function Set-GuiRemoteConnectivityResults
{
	<#
		.SYNOPSIS
		Persists the most recent Test-BaselineRemoteConnectivity output on
		the GUI remote-target context so the Support Bundle exporter and
		Connect-dialog status panel can read it back. Stores a slim copy
		(ComputerName / Reachable / Status / Error / FailureCategory /
		BlockedByPolicy / ConnectionMethod / Timestamp) — full attempt
		histories live in remote-orchestration.jsonl.
	#>
	[CmdletBinding()]
	param (
		[Parameter()]
		[AllowNull()]
		[AllowEmptyCollection()]
		[object[]]$Results
	)

	if (-not $Script:Ctx)
	{
		throw 'GUI context has not been initialized.'
	}
	if (-not $Script:Ctx.ContainsKey('Remote'))
	{
		$null = Get-GuiRemoteTargetContext
	}

	$timestamp = [datetime]::UtcNow.ToString('o')
	$slim = [System.Collections.Generic.List[pscustomobject]]::new()
	if ($null -ne $Results)
	{
		foreach ($entry in @($Results))
		{
			if ($null -eq $entry) { continue }
			$props = $entry.PSObject.Properties
			$slim.Add([pscustomobject]@{
				ComputerName     = if ($props['ComputerName']) { [string]$entry.ComputerName } else { '' }
				Reachable        = if ($props['Reachable']) { [bool]$entry.Reachable } else { $false }
				Status           = if ($props['Status']) { [string]$entry.Status } else { 'Unknown' }
				Error            = if ($props['Error']) { [string]$entry.Error } else { '' }
				FailureCategory  = if ($props['FailureCategory']) { [string]$entry.FailureCategory } else { '' }
				BlockedByPolicy  = if ($props['BlockedByPolicy']) { [bool]$entry.BlockedByPolicy } else { $false }
				ConnectionMethod = if ($props['ConnectionMethod']) { [string]$entry.ConnectionMethod } else { '' }
				Timestamp        = $timestamp
			})
		}
	}

	$Script:Ctx.Remote.LastConnectivityResults = @($slim)
	return @($slim)
}

<#
    .SYNOPSIS
    Internal function Update-GuiRemoteModeBanner.
#>

function Update-GuiRemoteModeBanner
{
	<#
		.SYNOPSIS
		Toggles the persistent RemoteModeBanner row in MainWindow.xaml so
		the user always knows whether they are operating locally or
		against remote targets. Reads context via Get-GuiRemoteTargetContext
		and writes to the banner controls (Border / TextBlock / Disconnect
		Button) bound to script-scope on window load. No-op when the banner
		controls were not bound (headless / test runners).
	#>
	[CmdletBinding()]
	param ()

	$banner = $Script:RemoteModeBanner
	$label = $Script:RemoteModeBannerText
	if (-not $banner -or -not $label) { return }

	$context = $null
	try { $context = Get-GuiRemoteTargetContext } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.Update-GuiRemoteModeBanner.LoadRemoteTargetContext'; $context = $null }

	if (-not $context -or -not $context.Connected -or $context.TargetComputers.Count -eq 0)
	{
		$banner.Visibility = [System.Windows.Visibility]::Collapsed
		return
	}

	$methodLabel = 'WinRM'
	if (Get-Command -Name 'Get-BaselineRemoteConnectionMethodLabel' -CommandType Function -ErrorAction SilentlyContinue)
	{
		try { $methodLabel = Get-BaselineRemoteConnectionMethodLabel -Method $context.ConnectionMethod } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.Update-GuiRemoteModeBanner.ResolveRemoteConnectionMethodLabel'; $methodLabel = 'WinRM' }
	}

	$targetList = ($context.TargetComputers -join ', ')
	$label.Text = ('Remote Mode ({0}): {1}' -f $methodLabel, $targetList)
	$banner.Visibility = [System.Windows.Visibility]::Visible
}

<#
    .SYNOPSIS
    Internal function Prompt-GuiRemoteTargetConnection.
#>

function Prompt-GuiRemoteTargetConnection
{
	<#
		.SYNOPSIS
		Shows the Connect-to-Computer dialog and returns the user's
		ComputerName / Credential / ConnectionMethod selection.

		.DESCRIPTION
		Renders a themed WPF dialog with a multiline target-list TextBox,
		a connection-method ComboBox (WinRM / WinRM-HTTPS / SSH), and
		credentials radio buttons (current vs. alternate). The Test
		Connection button runs Test-BaselineRemoteConnectivity on a
		background runspace, polled by a DispatcherTimer using the
		same closure pattern, then renders
		Format-BaselineRemoteConnectivityStatus rows into the status
		panel and persists the slim copy via Set-GuiRemoteConnectivityResults.
		Falls back to Read-Host/Get-Credential when WPF / theme is
		unavailable (headless test runners).
	#>
	[CmdletBinding()]
	param ()

	$currentContext = Get-GuiRemoteTargetContext
	$defaultTargets = if ($currentContext -and $currentContext.TargetComputers.Count -gt 0) { ($currentContext.TargetComputers -join ', ') } else { '' }
	$defaultMethod = if ($currentContext -and $currentContext.ConnectionMethod) { [string]$currentContext.ConnectionMethod } else { 'WinRM' }

	$theme = $Script:CurrentTheme
	$canUseWpf = $false
	if ($theme)
	{
		try
		{
			$null = [System.Windows.Window]
			$null = [Windows.Markup.XamlReader]
			$canUseWpf = $true
		}
		catch
		{
			$canUseWpf = $false
		}
	}

	if (-not $canUseWpf)
	{
		# Headless / test-runner fallback — uses the same contract minus the UI.
		$prompt = if ($defaultTargets) { ('Computer name(s) [{0}]:' -f $defaultTargets) } else { 'Computer name(s):' }
		$targetText = Read-Host -Prompt $prompt
		if ([string]::IsNullOrWhiteSpace($targetText)) { $targetText = $defaultTargets }
		if ([string]::IsNullOrWhiteSpace($targetText)) { return $null }
		$parsed = ConvertFrom-BaselineRemoteTargetInput -InputText $targetText
		if ($parsed.Targets.Count -eq 0) { throw 'At least one computer name must be provided.' }
		$cred = $null
		try { $cred = Get-Credential -Message 'Enter credentials for remote access, or Cancel for current user.' } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.Prompt-GuiRemoteTargetConnection.GetCredential'; $cred = $null }
		return [pscustomobject]@{
			ComputerName     = @($parsed.Targets)
			Credential       = $cred
			ConnectionMethod = 'WinRM'
		}
	}

	$bc = New-SafeBrushConverter -Context 'DialogHelpers-RemoteConnect'
	$windowTitle = Get-UxLocalizedString -Key 'GuiRemoteConnectTitle' -Fallback 'Connect to Computer'
	$windowSubtitle = Get-UxLocalizedString -Key 'GuiRemoteConnectSubtitle' -Fallback 'Reach one or more remote computers over WinRM or SSH.'
	$closeLabel = Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close'
	$cancelLabel = Get-UxLocalizedString -Key 'GuiCancelButton' -Fallback 'Cancel'
	$connectLabel = Get-UxLocalizedString -Key 'GuiRemoteConnectAction' -Fallback 'Connect'
	$testLabel = Get-UxLocalizedString -Key 'GuiRemoteConnectTest' -Fallback 'Test Connection'

	[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="$windowTitle"
	Width="640" Height="640"
	MinWidth="560" MinHeight="560"
	WindowStartupLocation="CenterOwner"
	ResizeMode="CanResizeWithGrip"
	FontFamily="Segoe UI"
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
					<TextBlock Text="$windowTitle" FontSize="16" FontWeight="SemiBold" Foreground="$($theme.TextPrimary)"/>
					<TextBlock Text="$windowSubtitle" FontSize="12" Foreground="$($theme.TextMuted)" Margin="0,2,0,0" TextWrapping="Wrap"/>
				</StackPanel>
			</Border>

			<ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" Padding="20,18,20,18">
				<StackPanel>
					<TextBlock Text="Computer name(s)" FontWeight="SemiBold" FontSize="13" Foreground="$($theme.TextPrimary)" Margin="0,0,0,4"/>
					<TextBlock Text="Separate multiple names with commas, semicolons, pipes, or whitespace."
							   FontSize="11" Foreground="$($theme.TextMuted)" Margin="0,0,0,6" TextWrapping="Wrap"/>
					<TextBox Name="TxtTargets" Height="62" AcceptsReturn="True" TextWrapping="Wrap"
							 VerticalScrollBarVisibility="Auto" FontSize="13" Padding="6,4"/>
					<TextBlock Name="TxtInvalid" Foreground="#D9534F" FontSize="11" Margin="0,4,0,0" TextWrapping="Wrap" Visibility="Collapsed"/>

					<TextBlock Text="Connection method" FontWeight="SemiBold" FontSize="13" Foreground="$($theme.TextPrimary)" Margin="0,16,0,4"/>
					<ComboBox Name="CmbMethod" Height="28" FontSize="12">
						<ComboBoxItem Content="WinRM (HTTP) — default, port 5985" Tag="WinRM"/>
						<ComboBoxItem Content="WinRM over HTTPS — port 5986" Tag="WinRMHttps"/>
						<ComboBoxItem Content="SSH (PowerShell over OpenSSH) — port 22" Tag="SSH"/>
					</ComboBox>

					<TextBlock Text="Credentials" FontWeight="SemiBold" FontSize="13" Foreground="$($theme.TextPrimary)" Margin="0,16,0,4"/>
					<RadioButton Name="RbCurrentCreds" GroupName="CredsMode" Content="Use current credentials" IsChecked="True" Foreground="$($theme.TextPrimary)" Margin="0,2,0,2"/>
					<RadioButton Name="RbAlternateCreds" GroupName="CredsMode" Content="Use alternate credentials" Foreground="$($theme.TextPrimary)" Margin="0,2,0,2"/>

					<Grid Name="CredsGrid" IsEnabled="False" Margin="18,8,0,0">
						<Grid.RowDefinitions>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
							<RowDefinition Height="Auto"/>
						</Grid.RowDefinitions>
						<Grid.ColumnDefinitions>
							<ColumnDefinition Width="140"/>
							<ColumnDefinition Width="*"/>
						</Grid.ColumnDefinitions>
						<TextBlock Grid.Row="0" Grid.Column="0" Text="Domain\Username:" Foreground="$($theme.TextPrimary)" VerticalAlignment="Center" Margin="0,4,8,4"/>
						<TextBox Name="TxtUsername" Grid.Row="0" Grid.Column="1" Height="26" FontSize="12" Margin="0,4,0,4" Padding="6,2"/>
						<TextBlock Grid.Row="1" Grid.Column="0" Text="Password:" Foreground="$($theme.TextPrimary)" VerticalAlignment="Center" Margin="0,4,8,4"/>
						<PasswordBox Name="PwdPassword" Grid.Row="1" Grid.Column="1" Height="26" FontSize="12" Margin="0,4,0,4" Padding="6,2"/>
					</Grid>

					<Grid Margin="0,16,0,0">
						<Grid.ColumnDefinitions>
							<ColumnDefinition Width="Auto"/>
							<ColumnDefinition Width="*"/>
						</Grid.ColumnDefinitions>
						<Button Name="BtnTest" Grid.Column="0" Content="$testLabel" Padding="14,6" FontSize="12"/>
						<TextBlock Name="TxtTestStatus" Grid.Column="1" VerticalAlignment="Center" Margin="12,0,0,0" Foreground="$($theme.TextMuted)" FontSize="12" TextWrapping="Wrap"/>
					</Grid>

					<Border Background="$($theme.HeaderBg)" BorderBrush="$($theme.BorderColor)" BorderThickness="1" CornerRadius="4" Padding="10,8" Margin="0,12,0,0" MinHeight="120">
						<ScrollViewer VerticalScrollBarVisibility="Auto" MaxHeight="160">
							<TextBlock Name="TxtResults" FontFamily="Consolas" FontSize="12" Foreground="$($theme.TextSecondary)" TextWrapping="NoWrap" Text="(no test run yet)"/>
						</ScrollViewer>
					</Border>
				</StackPanel>
			</ScrollViewer>

			<Border Grid.Row="3" Background="$($theme.HeaderBg)"
					BorderBrush="$($theme.BorderColor)" BorderThickness="0,1,0,0"
					Padding="20,10,20,10">
				<Grid>
					<Grid.ColumnDefinitions>
						<ColumnDefinition Width="*"/>
						<ColumnDefinition Width="Auto"/>
						<ColumnDefinition Width="Auto"/>
					</Grid.ColumnDefinitions>
					<Button Name="BtnCancel" Grid.Column="1" Content="$cancelLabel" Padding="20,6" FontSize="13" Margin="0,0,8,0"/>
					<Button Name="BtnConnect" Grid.Column="2" Content="$connectLabel" Padding="20,6" FontSize="13"/>
				</Grid>
			</Border>
		</Grid>
	</Border>
</Window>
"@

	$reader = [System.Xml.XmlNodeReader]::new($xaml)
	$dlg = [Windows.Markup.XamlReader]::Load($reader)
	if ($Script:MainForm) { try { $dlg.Owner = $Script:MainForm } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.Prompt-GuiRemoteTargetConnection.SetOwner' } }

	$rootBorder = $dlg.FindName('RootBorder')
	if ($rootBorder)
	{
		$rootBorder.Background = $bc.ConvertFromString($theme.WindowBg)
		$rootBorder.BorderBrush = $bc.ConvertFromString($theme.BorderColor)
		$rootBorder.BorderThickness = [System.Windows.Thickness]::new(1)
	}

	if (Get-Command -Name 'Set-GuiWindowChromeTheme' -ErrorAction SilentlyContinue)
	{
		try { [void](Set-GuiWindowChromeTheme -Window $dlg -UseDarkMode ($Script:CurrentThemeName -eq 'Dark')) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.Prompt-GuiRemoteTargetConnection.SetWindowChromeTheme' }
	}

	$titleBar = $dlg.FindName('DlgTitleBar')
	$btnDlgClose = $dlg.FindName('BtnDlgClose')
	$txtTargets = $dlg.FindName('TxtTargets')
	$txtInvalid = $dlg.FindName('TxtInvalid')
	$cmbMethod = $dlg.FindName('CmbMethod')
	$rbCurrent = $dlg.FindName('RbCurrentCreds')
	$rbAlternate = $dlg.FindName('RbAlternateCreds')
	$credsGrid = $dlg.FindName('CredsGrid')
	$txtUsername = $dlg.FindName('TxtUsername')
	$pwdPassword = $dlg.FindName('PwdPassword')
	$btnTest = $dlg.FindName('BtnTest')
	$txtTestStatus = $dlg.FindName('TxtTestStatus')
	$txtResults = $dlg.FindName('TxtResults')
	$btnCancel = $dlg.FindName('BtnCancel')
	$btnConnect = $dlg.FindName('BtnConnect')

	if ($titleBar) { $titleBar.Add_MouseLeftButtonDown({ $dlg.DragMove() }.GetNewClosure()) }
	if ($btnDlgClose) { $btnDlgClose.Add_Click({ $dlg.Close() }.GetNewClosure()) }
	if ($btnCancel) { $btnCancel.Add_Click({ $dlg.Close() }.GetNewClosure()) }

	foreach ($btn in @($btnTest, $btnCancel, $btnConnect))
	{
		if ($btn -and (Get-Command -Name 'Set-ButtonChrome' -ErrorAction SilentlyContinue))
		{
			$variant = if ($btn -eq $btnConnect) { 'Primary' } else { 'Secondary' }
			try { Set-ButtonChrome -Button $btn -Variant $variant -Compact } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.Prompt-GuiRemoteTargetConnection.SetButtonChrome' }
		}
	}

	$txtTargets.Text = $defaultTargets
	$selectedMethodIndex = switch ($defaultMethod) { 'WinRMHttps' { 1 } 'SSH' { 2 } default { 0 } }
	$cmbMethod.SelectedIndex = $selectedMethodIndex

	$rbCurrent.Add_Checked({ $credsGrid.IsEnabled = $false }.GetNewClosure())
	$rbAlternate.Add_Checked({ $credsGrid.IsEnabled = $true; $txtUsername.Focus() | Out-Null }.GetNewClosure())

	$resultBox = @{ Value = $null }

	$buildSelection = {
		$parsed = ConvertFrom-BaselineRemoteTargetInput -InputText $txtTargets.Text
		if ($parsed.Invalid.Count -gt 0)
		{
			$txtInvalid.Text = ('Ignored invalid entries: {0}' -f ($parsed.Invalid -join ', '))
			$txtInvalid.Visibility = [System.Windows.Visibility]::Visible
		}
		else
		{
			$txtInvalid.Text = ''
			$txtInvalid.Visibility = [System.Windows.Visibility]::Collapsed
		}
		if ($parsed.Targets.Count -eq 0)
		{
			throw [System.ArgumentException]::new('At least one valid computer name is required.', 'ComputerName')
		}
		$methodTag = if ($cmbMethod.SelectedItem) { [string]$cmbMethod.SelectedItem.Tag } else { 'WinRM' }
		$method = ConvertTo-BaselineRemoteConnectionMethod -Method $methodTag
		$cred = $null
		if ($rbAlternate.IsChecked)
		{
			$cred = New-BaselineRemoteTargetCredential -Username $txtUsername.Text -SecurePassword $pwdPassword.SecurePassword
		}
		return [pscustomobject]@{
			ComputerName     = @($parsed.Targets)
			Credential       = $cred
			ConnectionMethod = $method
		}
	}.GetNewClosure()

	$renderResults = {
		param ($Results)
		$rows = Format-BaselineRemoteConnectivityStatus -Result $Results
		if ($rows.Count -eq 0)
		{
			$txtResults.Text = '(no per-target results)'
			return
		}
		$txtResults.Text = (($rows | ForEach-Object { $_.Display }) -join [Environment]::NewLine)
		try { $null = Set-GuiRemoteConnectivityResults -Results $Results } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.Prompt-GuiRemoteTargetConnection.SetGuiRemoteConnectivityResults' }
	}.GetNewClosure()

	$testState = @{ PS = $null; Async = $null; Timer = $null }

	$cleanupTest = {
		if ($testState.Timer) { try { $testState.Timer.Stop() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.Prompt-GuiRemoteTargetConnection.CleanupTestTimer' }; $testState.Timer = $null }
		if ($testState.PS)
		{
			try { $testState.PS.Dispose() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.Prompt-GuiRemoteTargetConnection.CleanupTestDisposePowerShell' }
			$testState.PS = $null
		}
		$testState.Async = $null
		$btnTest.IsEnabled = $true
	}.GetNewClosure()

	$btnTest.Add_Click({
		try
		{
			$selection = & $buildSelection
		}
		catch
		{
			$txtTestStatus.Text = $_.Exception.Message
			return
		}
		$btnTest.IsEnabled = $false
		$txtTestStatus.Text = ('Testing {0} target(s) via {1}...' -f $selection.ComputerName.Count, (Get-BaselineRemoteConnectionMethodLabel -Method $selection.ConnectionMethod))
		$txtResults.Text = '(running...)'

		$ps = [powershell]::Create()
		$ps.AddCommand('Test-BaselineRemoteConnectivity') | Out-Null
		$ps.AddParameter('ComputerName', $selection.ComputerName) | Out-Null
		$ps.AddParameter('ConnectionMethod', $selection.ConnectionMethod) | Out-Null
		if ($selection.Credential) { $ps.AddParameter('Credential', $selection.Credential) | Out-Null }
		$async = $ps.BeginInvoke()
		$testState.PS = $ps
		$testState.Async = $async

		$timer = New-Object System.Windows.Threading.DispatcherTimer
		$timer.Interval = [TimeSpan]::FromMilliseconds(150)
		$pollTick = {
			if (-not $testState.Async -or -not $testState.PS) { & $cleanupTest; return }
			if (-not $testState.Async.IsCompleted) { return }
			try
			{
				$results = @($testState.PS.EndInvoke($testState.Async))
				& $renderResults $results
				$reachable = @($results | Where-Object { $_.Reachable }).Count
				$total = $results.Count
				$txtTestStatus.Text = ('Done: {0}/{1} reachable.' -f $reachable, $total)
			}
			catch
			{
				$txtTestStatus.Text = ('Test failed: {0}' -f $_.Exception.Message)
				$txtResults.Text = ('Error: {0}' -f $_.Exception.Message)
			}
			finally
			{
				& $cleanupTest
			}
		}.GetNewClosure()
		$timer.Add_Tick($pollTick)
		$testState.Timer = $timer
		$timer.Start()
	}.GetNewClosure())

	$btnConnect.Add_Click({
		try
		{
			$selection = & $buildSelection
		}
		catch
		{
			$txtTestStatus.Text = $_.Exception.Message
			return
		}
		$resultBox.Value = $selection
		$dlg.Close()
	}.GetNewClosure())

	$dlg.Add_Closed({ & $cleanupTest }.GetNewClosure())

	[void]$dlg.ShowDialog()
	return $resultBox.Value
}

<#
    .SYNOPSIS
    Internal function Test-GuiRemoteTargetApproval.
#>

function Test-GuiRemoteTargetApproval
{
	<# .SYNOPSIS Tests whether the current remote target list is approved for the session. #>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string[]]$ComputerName
	)

	$current = @($ComputerName | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim().ToLowerInvariant() } | Sort-Object -Unique)
	$context = Get-GuiRemoteTargetContext
	$approved = @($context.ApprovedTargetComputers | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim().ToLowerInvariant() } | Sort-Object -Unique)

	if ($current.Count -ne $approved.Count)
	{
		return $false
	}

	for ($i = 0; $i -lt $current.Count; $i++)
	{
		if ($current[$i] -ne $approved[$i])
		{
			return $false
		}
	}

	return $true
}

<#
    .SYNOPSIS
    Internal function Set-GuiRemoteTargetApprovalList.
#>

function Set-GuiRemoteTargetApprovalList
{
	<# .SYNOPSIS Approves the current target list for the active GUI session. #>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string[]]$ComputerName,

		[string]$ApprovalMessage
	)

	if (-not $Script:Ctx)
	{
		throw 'GUI context has not been initialized.'
	}

	$targets = @($ComputerName | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_.Trim() })
	if ($targets.Count -eq 0)
	{
		throw 'At least one computer name is required.'
	}

	$Script:Ctx.Remote.ApprovedTargetComputers = @($targets)
	$Script:Ctx.Remote.ApprovedAt = [datetime]::UtcNow.ToString('o')
	$Script:Ctx.Remote.ApprovalMessage = if ([string]::IsNullOrWhiteSpace($ApprovalMessage)) { 'Remote target list approved.' } else { [string]$ApprovalMessage }
	return (Get-GuiRemoteTargetContext)
}

<#
    .SYNOPSIS
    Internal function Clear-GuiRemoteTargetApprovalList.
#>

function Clear-GuiRemoteTargetApprovalList
{
	<# .SYNOPSIS Clears the approved target list for the active GUI session. #>
	if (-not $Script:Ctx -or -not $Script:Ctx.ContainsKey('Remote'))
	{
		return
	}

	$Script:Ctx.Remote.ApprovedTargetComputers = @()
	$Script:Ctx.Remote.ApprovedAt = $null
	$Script:Ctx.Remote.ApprovalMessage = $null
}

<#
    .SYNOPSIS
    Internal function .
#>
function Get-GuiRemoteTargetPolicyDirectory
{
	[CmdletBinding()]
	param ()

	$settingsRoot = Get-GuiSettingsProfileDirectory
	if ([string]::IsNullOrWhiteSpace($settingsRoot))
	{
		$settingsRoot = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ApplicationData)
	}

	$policyDirectory = Join-Path $settingsRoot 'RemotePolicies'
	if (-not (Test-Path -LiteralPath $policyDirectory))
	{
		$null = New-Item -ItemType Directory -Path $policyDirectory -Force
	}

	return $policyDirectory
}

<#
    .SYNOPSIS
    Internal function Export-GuiRemoteTargetApprovalPolicy.
#>

function Export-GuiRemoteTargetApprovalPolicy
{
	<# .SYNOPSIS Saves the current approved remote target list to a reusable policy file. #>
	[CmdletBinding()]
	param (
		[string]$FilePath
	)

	$context = Get-GuiRemoteTargetContext
	if (-not $context.Connected -or $context.TargetComputers.Count -eq 0)
	{
		throw 'Connect to a remote target before saving a remote approval policy.'
	}

	if ($context.ApprovedTargetComputers.Count -eq 0)
	{
		throw 'Approve the current target list before saving a remote approval policy.'
	}

	if ([string]::IsNullOrWhiteSpace($FilePath))
	{
		$defaultName = 'Baseline-RemoteApprovalPolicy-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
		$FilePath = GUICommon\Show-GuiFileSaveDialog -Title 'Save Remote Approval Policy' -Filter 'JSON Files (*.json)|*.json|All Files (*.*)|*.*' -DefaultExtension 'json' -InitialDirectory (Get-GuiRemoteTargetPolicyDirectory) -FileName $defaultName
	}

	if ([string]::IsNullOrWhiteSpace($FilePath))
	{
		return $false
	}

	$payload = [ordered]@{
		Schema = 'Baseline.GuiRemoteTargetApprovalPolicy'
		SchemaVersion = 1
		SavedAt = [datetime]::UtcNow.ToString('o')
		TargetComputers = @($context.ApprovedTargetComputers)
		ApprovalMessage = $context.ApprovalMessage
	}

	($payload | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $FilePath -Encoding UTF8 -Force
	LogInfo ("Saved remote approval policy to {0}" -f $FilePath)
	return $true
}

<#
    .SYNOPSIS
    Internal function Import-GuiRemoteTargetApprovalPolicy.
#>

function Import-GuiRemoteTargetApprovalPolicy
{
	<# .SYNOPSIS Loads a reusable remote approval policy and applies it to the current remote target context. #>
	[CmdletBinding()]
	param (
		[string]$FilePath
	)

	if ([string]::IsNullOrWhiteSpace($FilePath))
	{
		$FilePath = GUICommon\Show-GuiFileOpenDialog -Title 'Load Remote Approval Policy' -Filter 'JSON Files (*.json)|*.json|All Files (*.*)|*.*' -InitialDirectory (Get-GuiRemoteTargetPolicyDirectory)
	}

	if ([string]::IsNullOrWhiteSpace($FilePath))
	{
		return $false
	}

	if (-not (Test-Path -LiteralPath $FilePath))
	{
		throw "Policy file not found: $FilePath"
	}

	$policy = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8 | ConvertFrom-BaselineJson -Depth 16
	if (-not $policy -or [string]::IsNullOrWhiteSpace([string]$policy.Schema) -or [string]$policy.Schema -ne 'Baseline.GuiRemoteTargetApprovalPolicy')
	{
		throw 'The selected file does not contain a valid remote approval policy.'
	}

	$targets = @($policy.TargetComputers)
	if ($targets.Count -eq 0)
	{
		throw 'The selected policy did not contain any approved targets.'
	}

	if (-not (Test-GuiRemoteTargetConnected))
	{
		throw 'Connect to a remote target before loading a remote approval policy.'
	}

	$current = Get-GuiRemoteTargetContext
	if ($current.TargetComputers.Count -ne $targets.Count -or -not (Test-GuiRemoteTargetApproval -ComputerName @($targets)))
	{
		throw 'The loaded policy does not match the currently connected target list.'
	}

	Set-GuiRemoteTargetApprovalList -ComputerName @($targets) -ApprovalMessage ([string]$policy.ApprovalMessage)
	LogInfo ("Loaded remote approval policy from {0}" -f $FilePath)
	return $true
}

<#
    .SYNOPSIS
    Internal function Save-GuiUndoSnapshot.
	#>

	function Save-GuiUndoSnapshot
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()
		$Script:UiSnapshotUndo = Get-GuiSettingsSnapshot
		Set-GuiActionButtonsEnabled -Enabled (-not (& $Script:TestGuiRunInProgressScript))
	}

	<#
	    .SYNOPSIS
	    Internal function .
	#>
	function Get-GuiSettingsSnapshot
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		# Theme preference can be 'Light', 'Dark', or 'System'. The header ChkTheme
		# only reflects the resolved Light/Dark state, so we persist the user's
		# preference (if any) so 'System' round-trips across launches.
		$themeName = if ($Script:ThemePreference) {
			[string]$Script:ThemePreference
		}
		elseif ($ChkTheme) {
			if ($ChkTheme.IsChecked) { 'Light' } else { 'Dark' }
		}
		elseif ($Script:CurrentThemeName) {
			[string]$Script:CurrentThemeName
		}
		else {
			'Dark'
		}

		# Search text is transient view state. Persisting it makes a fresh launch
		# reopen stale filtered results instead of the restored primary tab.
		$searchText = ''
		$appsSearchText = ''
		# System scan is transient machine state. Persisting it across launches can silently
		# re-run expensive detection work during startup, so session snapshots always store it off.
		$scanEnabled = $false
		$currentPrimaryTab = if ($PrimaryTabs -and $PrimaryTabs.SelectedItem -and $PrimaryTabs.SelectedItem.Tag) {
			[string]$PrimaryTabs.SelectedItem.Tag
		}
		elseif ($Script:CurrentPrimaryTab) {
			[string]$Script:CurrentPrimaryTab
		}
		else {
			$null
		}

		$currentSafeMode = if ($Script:Ctx -and $Script:Ctx.ContainsKey('Mode') -and $null -ne $Script:Ctx.Mode -and $Script:Ctx.Mode.ContainsKey('Safe')) { [bool]$Script:Ctx.Mode.Safe } else { [bool]$Script:SafeMode }
		$currentAdvancedMode = if ($Script:Ctx -and $Script:Ctx.ContainsKey('Mode') -and $null -ne $Script:Ctx.Mode -and $Script:Ctx.Mode.ContainsKey('Expert')) { [bool]$Script:Ctx.Mode.Expert } else { [bool]$Script:AdvancedMode }
		$currentModePreference = Resolve-GuiModePreference -SafeMode $currentSafeMode -AdvancedMode $currentAdvancedMode

		$snapshot = [ordered]@{
			Schema = 'Baseline.GuiSettings'
			SchemaVersion = 16
			SavedAt = (Get-Date).ToString('o')
			Theme = $themeName
			Language = if ($Script:SelectedLanguage) { [string]$Script:SelectedLanguage } else { 'en' }
			SearchText = $searchText
			AppsSearchText = $appsSearchText
			AuditRetentionDays = if ($Script:AuditRetentionDays) { [int]$Script:AuditRetentionDays } else { 90 }
			AppsPackageSourcePreference = if ($Script:AppsPackageSourcePreference) { [string]$Script:AppsPackageSourcePreference } else { 'auto' }
			AppsSourceFilter = if ($Script:AppsSourceFilter) { [string]$Script:AppsSourceFilter } else { 'All' }
			PinnedBaselineVersion = if ($Script:PinnedBaselineVersion) { [string]$Script:PinnedBaselineVersion } else { $null }
			AppsQueuedActions = @(
				if ($Script:AppsQueuedActions -is [System.Collections.Generic.Dictionary[string, string]])
				{
					$Script:AppsQueuedActions.GetEnumerator() |
						Sort-Object Key |
						ForEach-Object {
							[ordered]@{
								AppId = [string]$_.Key
								Action = [string]$_.Value
							}
						}
				}
			)
			ScanEnabled = $scanEnabled
			AutoScanOnLaunch = [bool]$Script:AutoScanOnLaunch
			RestoreLastSession = if ($null -ne $Script:RestoreLastSession) { [bool]$Script:RestoreLastSession } else { $true }
			AdvancedMode = [bool]$currentModePreference.AdvancedMode
			SafeMode = [bool]$currentModePreference.SafeMode
			RequireRunConfirmation = if ($null -ne $Script:RequireRunConfirmation) { [bool]$Script:RequireRunConfirmation } else { $true }
			PreviewBeforeRunDefault = [bool]$Script:PreviewBeforeRunDefault
			GameMode = [bool]$Script:GameMode
			GameModeProfile = if ($Script:GameModeProfile) { [string]$Script:GameModeProfile } else { $null }
			GameModeCorePlan = @($Script:GameModeCorePlan)
			GameModePlan = @($Script:GameModePlan)
			GameModeDecisionOverrides = Convert-JsonManifestValue $Script:GameModeDecisionOverrides
			GameModeAdvancedSelections = Convert-JsonManifestValue $Script:GameModeAdvancedSelections
			GameModePreviousPrimaryTab = if ($Script:GameModePreviousPrimaryTab) { [string]$Script:GameModePreviousPrimaryTab } else { $null }
			RiskFilter = if ($Script:RiskFilter) { [string]$Script:RiskFilter } else { 'All' }
			CategoryFilter = if ($Script:CategoryFilter) { [string]$Script:CategoryFilter } else { 'All' }
			PlatformFilter = if ($Script:PlatformFilter) { [string]$Script:PlatformFilter } else { 'ThisDevice' }
			AppsCategoryFilter = if ($Script:AppsCategoryFilter) { [string]$Script:AppsCategoryFilter } else { 'All' }
			AppsStatusFilter = if ($Script:AppsStatusFilter) { [string]$Script:AppsStatusFilter } else { 'All' }
			SelectedOnlyFilter = [bool]$Script:SelectedOnlyFilter
			HideUnavailableItems = [bool]$Script:HideUnavailableItems
			AppsAutoUpdate = [bool]$Script:AppsAutoUpdate
			AppsSilentInstall = if ($null -ne $Script:AppsSilentInstall) { [bool]$Script:AppsSilentInstall } else { $true }
			LoggingEnabled = if ($null -ne $Script:LoggingEnabled) { [bool]$Script:LoggingEnabled } else { $true }
			ExperimentalFeatures = [bool]$Script:ExperimentalFeatures
			DesignMode = [bool]$Script:DesignMode
			HighRiskOnlyFilter = [bool]$Script:HighRiskOnlyFilter
			RestorableOnlyFilter = [bool]$Script:RestorableOnlyFilter
			GamingOnlyFilter = [bool]$Script:GamingOnlyFilter
			CurrentPrimaryTab = $currentPrimaryTab
			LastStandardPrimaryTab = if ($Script:LastStandardPrimaryTab) { [string]$Script:LastStandardPrimaryTab } else { $null }
			ExplicitSelections = @($Script:ExplicitPresetSelections)
			ExplicitSelectionDefinitions = @(
				$Script:ExplicitPresetSelectionDefinitions.GetEnumerator() |
					Sort-Object Key |
					ForEach-Object {
						Copy-GuiExplicitSelectionDefinition -Definition $_.Value -FunctionName ([string]$_.Key)
					}
			)
			Controls = $null
		}

		$controlList = [System.Collections.Generic.List[pscustomobject]]::new($Script:TweakManifest.Count)
		for ($i = 0; $i -lt $Script:TweakManifest.Count; $i++)
		{
			$manifest = $Script:TweakManifest[$i]
			$control = $Script:Controls[$i]
			$entry = [ordered]@{
				Index = $i
				Function = $manifest.Function
				Type = $manifest.Type
			}

			switch ($manifest.Type)
			{
				'Date'
				{
					$entry.IsChecked = if ($control -and (Test-GuiObjectField -Object $control -FieldName 'IsChecked')) { [bool]$control.IsChecked } else { $false }
					$selectedDate = $null
					if ($control)
					{
						if ((Test-GuiObjectField -Object $control -FieldName 'SelectedDate') -and $control.SelectedDate)
						{
							$selectedDate = ([datetime]$control.SelectedDate).ToString('yyyy-MM-dd')
						}
						elseif ((Test-GuiObjectField -Object $control -FieldName 'DatePicker') -and $control.DatePicker -and (Test-GuiObjectField -Object $control.DatePicker -FieldName 'SelectedDate') -and $control.DatePicker.SelectedDate)
						{
							$selectedDate = ([datetime]$control.DatePicker.SelectedDate).ToString('yyyy-MM-dd')
						}
					}
					$entry.SelectedDate = $selectedDate
				}
				'Choice'
				{
					$selectedIndex = -1
					if ($control -and (Test-GuiObjectField -Object $control -FieldName 'SelectedIndex'))
					{
						$selectedIndex = [int]$control.SelectedIndex
					}
					$selectedValue = $null
					if ($selectedIndex -ge 0 -and $selectedIndex -lt $manifest.Options.Count)
					{
						$selectedValue = [string]$manifest.Options[$selectedIndex]
					}
					$entry.SelectedIndex = [int]$selectedIndex
					$entry.SelectedValue = $selectedValue
				}
				default
				{
					$entry.IsChecked = if ($control -and (Test-GuiObjectField -Object $control -FieldName 'IsChecked')) { [bool]$control.IsChecked } else { $false }
				}
			}

			$controlList.Add([pscustomobject]$entry)
		}

		$snapshot.Controls = $controlList.ToArray()
		return [pscustomobject]$snapshot
	}

	<#
	    .SYNOPSIS
	    Internal function Restore-GuiSettingsSnapshot.
	#>

	function Restore-GuiSettingsSnapshot
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[Parameter(Mandatory = $true)]
			[object]
			$Snapshot
		)

		if (-not $Snapshot)
		{
			throw "No GUI settings snapshot was supplied."
		}

		Clear-TabContentCache

		$controlStates = @{}
		if ((Test-GuiObjectField -Object $Snapshot -FieldName 'Controls'))
		{
			foreach ($entry in @($Snapshot.Controls))
			{
				if ($entry -and (Test-GuiObjectField -Object $entry -FieldName 'Function'))
				{
					$controlStates[[string]$entry.Function] = $entry
				}
			}
		}

		Initialize-GuiSelectionStateStores
		$Script:ExplicitPresetSelections.Clear()
		$Script:ExplicitPresetSelectionDefinitions.Clear()
		if ((Test-GuiObjectField -Object $Snapshot -FieldName 'ExplicitSelectionDefinitions') -and $null -ne $Snapshot.ExplicitSelectionDefinitions)
		{
			foreach ($selectionDefinition in @($Snapshot.ExplicitSelectionDefinitions))
			{
				$functionName = if ($selectionDefinition -and (Test-GuiObjectField -Object $selectionDefinition -FieldName 'Function')) { [string]$selectionDefinition.Function } else { $null }
				if (-not [string]::IsNullOrWhiteSpace($functionName))
				{
					Set-GuiExplicitSelectionDefinition -FunctionName $functionName -Definition $selectionDefinition
				}
			}
		}
		elseif ((Test-GuiObjectField -Object $Snapshot -FieldName 'ExplicitSelections'))
		{
			foreach ($functionName in @($Snapshot.ExplicitSelections))
			{
				if (-not [string]::IsNullOrWhiteSpace([string]$functionName))
				{
					[void]$Script:ExplicitPresetSelections.Add([string]$functionName)
				}
			}
		}

		for ($i = 0; $i -lt $Script:TweakManifest.Count; $i++)
		{
			$manifest = $Script:TweakManifest[$i]
			$control = $Script:Controls[$i]
			if (-not $control) { continue }

			$state = $controlStates[$manifest.Function]
			if (-not $state) { continue }

			switch ($manifest.Type)
			{
				'Date'
				{
					$isChecked = if ((Test-GuiObjectField -Object $state -FieldName 'IsChecked')) { [bool]$state.IsChecked } else { $false }
					$selectedDate = $null
					if ((Test-GuiObjectField -Object $state -FieldName 'SelectedDate') -and -not [string]::IsNullOrWhiteSpace([string]$state.SelectedDate))
					{
						$parsedDate = [datetime]::MinValue
						if (-not [datetime]::TryParseExact([string]$state.SelectedDate, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate))
						{
							throw "Invalid GUI session date value for '$([string]$manifest.Function)': '$([string]$state.SelectedDate)'."
						}
						$selectedDate = $parsedDate
					}

					if ((Test-GuiObjectField -Object $control -FieldName 'IsRestoring'))
					{
						$control.IsRestoring = $true
					}
					if ((Test-GuiObjectField -Object $control -FieldName 'CheckBox') -and $control.CheckBox)
					{
						$control.CheckBox.IsChecked = [bool]$isChecked
					}
					elseif ((Test-GuiObjectField -Object $control -FieldName 'IsChecked'))
					{
						$control.IsChecked = [bool]$isChecked
					}
					if ((Test-GuiObjectField -Object $control -FieldName 'DatePicker') -and $control.DatePicker)
					{
						$control.DatePicker.SelectedDate = $selectedDate
					}
					if ((Test-GuiObjectField -Object $control -FieldName 'SelectedDate'))
					{
						$control.SelectedDate = $selectedDate
					}
					if ((Test-GuiObjectField -Object $control -FieldName 'IsRestoring'))
					{
						$control.IsRestoring = $false
					}
				}
				'Choice'
				{
					if ((Test-GuiObjectField -Object $control -FieldName 'SelectedIndex'))
					{
						$selectedIndex = -1
						if ($manifest.Options -and (Test-GuiObjectField -Object $state -FieldName 'SelectedValue') -and -not [string]::IsNullOrWhiteSpace([string]$state.SelectedValue))
						{
							$selectedIndex = [array]::IndexOf(@($manifest.Options), [string]$state.SelectedValue)
						}
						if ($selectedIndex -lt 0 -and (Test-GuiObjectField -Object $state -FieldName 'SelectedIndex'))
						{
							$selectedIndex = [int]$state.SelectedIndex
						}
						$optCount = if ($manifest.Options) { $manifest.Options.Count } else { 0 }
						if ($selectedIndex -ge $optCount) { $selectedIndex = -1 }
						[int]$idx = $selectedIndex
						$control.SelectedIndex = $idx
					}
				}
				default
				{
					if ((Test-GuiObjectField -Object $control -FieldName 'IsChecked'))
					{
						$control.IsChecked = [bool]$state.IsChecked
					}
				}
			}
		}

		$desiredTheme = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'Theme')) { [string]$Snapshot.Theme } else { 'Dark' }
		# System scan must be rerun explicitly for the current machine state instead of being
		# replayed from a saved session.
		$desiredScan  = $false
		$desiredLanguage = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'Language') -and -not [string]::IsNullOrWhiteSpace([string]$Snapshot.Language)) { [string]$Snapshot.Language } else { $null }
		$desiredSearch = ''
		$desiredAppsSearch = ''
		$desiredAuditRetentionDays = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'AuditRetentionDays')) { [int]$Snapshot.AuditRetentionDays } else { 90 }
		$desiredAppsPackageSourcePreference = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'AppsPackageSourcePreference') -and -not [string]::IsNullOrWhiteSpace([string]$Snapshot.AppsPackageSourcePreference)) { [string]$Snapshot.AppsPackageSourcePreference } else { 'auto' }
		$desiredAppsSourceFilter = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'AppsSourceFilter') -and -not [string]::IsNullOrWhiteSpace([string]$Snapshot.AppsSourceFilter)) { [string]$Snapshot.AppsSourceFilter } else { 'All' }
		$allowedAppsSourceFilter = @('All', 'winget', 'choco')
		if ($allowedAppsSourceFilter -notcontains $desiredAppsSourceFilter) { $desiredAppsSourceFilter = 'All' }
		$desiredAppsQueuedActions = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'AppsQueuedActions') -and $null -ne $Snapshot.AppsQueuedActions) { @($Snapshot.AppsQueuedActions) } else { @() }
		$desiredPinnedBaselineVersion = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'PinnedBaselineVersion') -and -not [string]::IsNullOrWhiteSpace([string]$Snapshot.PinnedBaselineVersion)) { [string]$Snapshot.PinnedBaselineVersion } else { $null }
		$desiredAutoScanOnLaunch = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'AutoScanOnLaunch')) { [bool]$Snapshot.AutoScanOnLaunch } else { $false }
		$desiredRestoreLastSession = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'RestoreLastSession')) { [bool]$Snapshot.RestoreLastSession } else { $true }
		$desiredSafe = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'SafeMode')) { [bool]$Snapshot.SafeMode } else { $false }
		$desiredAdvanced = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'AdvancedMode')) { [bool]$Snapshot.AdvancedMode } else { $false }
		$desiredRequireRunConfirmation = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'RequireRunConfirmation')) { [bool]$Snapshot.RequireRunConfirmation } else { $true }
		$desiredPreviewBeforeRunDefault = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'PreviewBeforeRunDefault')) { [bool]$Snapshot.PreviewBeforeRunDefault } else { $false }
		$desiredGameMode = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'GameMode')) { [bool]$Snapshot.GameMode } else { $false }
		$desiredGameModeProfile = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'GameModeProfile')) { [string]$Snapshot.GameModeProfile } else { $null }
		$desiredGameModeCorePlan = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'GameModeCorePlan')) { @($Snapshot.GameModeCorePlan) } else { @() }
		$desiredGameModePlan = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'GameModePlan')) { @($Snapshot.GameModePlan) } else { @() }
		$desiredGameModeDecisionOverrides = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'GameModeDecisionOverrides') -and $null -ne $Snapshot.GameModeDecisionOverrides) { Convert-JsonManifestValue $Snapshot.GameModeDecisionOverrides } else { @{} }
		$desiredGameModeAdvancedSelections = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'GameModeAdvancedSelections') -and $null -ne $Snapshot.GameModeAdvancedSelections) { Convert-JsonManifestValue $Snapshot.GameModeAdvancedSelections } else { @{} }
		$desiredGameModePreviousPrimaryTab = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'GameModePreviousPrimaryTab')) { [string]$Snapshot.GameModePreviousPrimaryTab } else { $null }
		$desiredModePreference = Resolve-GuiModePreference -SafeMode $desiredSafe -AdvancedMode $desiredAdvanced
		$desiredSafe = [bool]$desiredModePreference.SafeMode
		$desiredAdvanced = [bool]$desiredModePreference.AdvancedMode
		$desiredRisk = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'RiskFilter') -and -not [string]::IsNullOrWhiteSpace([string]$Snapshot.RiskFilter)) { [string]$Snapshot.RiskFilter } else { 'All' }
		$desiredCategory = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'CategoryFilter') -and -not [string]::IsNullOrWhiteSpace([string]$Snapshot.CategoryFilter)) { [string]$Snapshot.CategoryFilter } else { 'All' }
		$desiredPlatform = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'PlatformFilter') -and -not [string]::IsNullOrWhiteSpace([string]$Snapshot.PlatformFilter)) { [string]$Snapshot.PlatformFilter } else { 'ThisDevice' }
		$desiredAppsCategory = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'AppsCategoryFilter') -and -not [string]::IsNullOrWhiteSpace([string]$Snapshot.AppsCategoryFilter)) { [string]$Snapshot.AppsCategoryFilter } else { 'All' }
		$desiredAppsStatus = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'AppsStatusFilter') -and -not [string]::IsNullOrWhiteSpace([string]$Snapshot.AppsStatusFilter)) { [string]$Snapshot.AppsStatusFilter } else { 'All' }
		$allowedAppsStatus = @('All', 'Installed', 'NotInstalled', 'UpdateAvailable')
		if ($allowedAppsStatus -notcontains $desiredAppsStatus) { $desiredAppsStatus = 'All' }
		$desiredSelectedOnly = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'SelectedOnlyFilter')) { [bool]$Snapshot.SelectedOnlyFilter } else { $false }
		$desiredHideUnavailableItems = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'HideUnavailableItems')) { [bool]$Snapshot.HideUnavailableItems } else { [bool]$Script:HideUnavailableItems }
		$desiredAppsAutoUpdate = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'AppsAutoUpdate')) { [bool]$Snapshot.AppsAutoUpdate } else { $false }
		$desiredAppsSilentInstall = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'AppsSilentInstall')) { [bool]$Snapshot.AppsSilentInstall } else { $true }
		$desiredLoggingEnabled = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'LoggingEnabled')) { [bool]$Snapshot.LoggingEnabled } else { $true }
		$desiredExperimentalFeatures = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'ExperimentalFeatures')) { [bool]$Snapshot.ExperimentalFeatures } else { $false }
		$desiredDesignMode = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'DesignMode')) { [bool]$Snapshot.DesignMode } else { [bool]$Script:DesignMode }
		$desiredHighRiskOnly = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'HighRiskOnlyFilter')) { [bool]$Snapshot.HighRiskOnlyFilter } else { $false }
		$desiredRestorableOnly = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'RestorableOnlyFilter')) { [bool]$Snapshot.RestorableOnlyFilter } else { $false }
		$desiredGamingOnly = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'GamingOnlyFilter')) { [bool]$Snapshot.GamingOnlyFilter } else { $false }
		$desiredTab   = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'CurrentPrimaryTab')) { [string]$Snapshot.CurrentPrimaryTab } else { $null }
		$desiredLast  = if ((Test-GuiObjectField -Object $Snapshot -FieldName 'LastStandardPrimaryTab')) { [string]$Snapshot.LastStandardPrimaryTab } else { $null }

		if ($desiredLast)
		{
			$Script:LastStandardPrimaryTab = $desiredLast
		}
		if (-not [string]::IsNullOrWhiteSpace($desiredGameModePreviousPrimaryTab))
		{
			$Script:GameModePreviousPrimaryTab = $desiredGameModePreviousPrimaryTab
		}

		# Resolve 'System' preference to a concrete Light/Dark theme based on the
		# Windows AppsUseLightTheme registry value, but keep $Script:ThemePreference
		# as 'System' so the choice persists across relaunches.
		if (Get-Command -Name 'Apply-BaselineThemePreference' -CommandType Function -ErrorAction SilentlyContinue)
		{
			try { Apply-BaselineThemePreference -Preference $desiredTheme } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.ApplyThemePreference' }
		}
		else
		{
			$resolvedTheme = if ($desiredTheme -eq 'System') {
				if (Get-Command -Name 'Get-BaselineSystemThemePreference' -CommandType Function -ErrorAction SilentlyContinue) { Get-BaselineSystemThemePreference } else { 'Dark' }
			} elseif ($desiredTheme -eq 'Light' -or $desiredTheme -eq 'Dark') {
				$desiredTheme
			} else {
				'Dark'
			}
			$Script:ThemePreference = $desiredTheme
			if ($ChkTheme)
			{
				if ($resolvedTheme -eq 'Light' -and -not $ChkTheme.IsChecked)
				{
					$ChkTheme.IsChecked = $true
				}
				elseif ($resolvedTheme -ne 'Light' -and $ChkTheme.IsChecked)
				{
					$ChkTheme.IsChecked = $false
				}
			}
			else
			{
				if ($resolvedTheme -eq 'Light')
				{
					Set-GUITheme -Theme $Script:LightTheme
				}
				else
				{
					Set-GUITheme -Theme $Script:DarkTheme
				}
			}
		}

		# Restore saved language preference.
        if ($desiredLanguage)
        {
            $Script:SelectedLanguage = $desiredLanguage
            $locDir = $Script:GuiLocalizationDirectoryPath
            if (-not [string]::IsNullOrWhiteSpace([string]$locDir))
            {
                $Global:Localization = Import-BaselineLocalization -BaseDirectory $locDir -UICulture $desiredLanguage
				[void](Set-BaselineThreadCulture -UICulture $desiredLanguage)
				$env:BASELINE_LANGUAGE = $desiredLanguage
            }
        }

		$Script:FilterUiUpdating = $true
		try
		{
			$Script:AutoScanOnLaunch = $desiredAutoScanOnLaunch
			$Script:RestoreLastSession = $desiredRestoreLastSession
			$Script:ScanEnabled = $desiredScan
			$Script:EnvironmentRecommendationData = $null
			$Script:EnvironmentSummaryText = $null
			if ($ChkScan)
			{
				if ($ChkScan.IsChecked -ne $desiredScan)
				{
					$ChkScan.IsChecked = $desiredScan
				}
			}

			$desiredViewMode = if ($desiredSafe) { 'Safe' } elseif ($desiredAdvanced) { 'Expert' } else { 'Standard' }
			if (Get-Command -Name 'Set-GuiMode' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Set-GuiMode -ViewMode $desiredViewMode -GameMode $desiredGameMode
			}
			else
			{
				$Script:SafeMode = $desiredSafe
				$Script:AdvancedMode = $desiredAdvanced
				$Script:GameMode = $desiredGameMode
				if ($Script:Ctx)
				{
					if (-not $Script:Ctx.ContainsKey('Mode'))
					{
						$Script:Ctx['Mode'] = @{ Safe = $false; Expert = $false; Game = $false; Design = $false; Scenario = $null }
					}
					$Script:Ctx.Mode.Safe = $desiredSafe
					$Script:Ctx.Mode.Expert = $desiredAdvanced
					$Script:Ctx.Mode.Game = $desiredGameMode
				}
			}
			$Script:DefaultStartupMode = if ($desiredAdvanced) { 'Expert' } else { 'Safe' }
			if (Get-Command -Name 'Set-BaselineUserPreference' -CommandType Function -ErrorAction SilentlyContinue)
			{
				try { Set-BaselineUserPreference -Key 'Theme' -Value $desiredTheme } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.RestoreGuiSettingsSnapshot.SaveThemePreference' }
				try { Set-BaselineUserPreference -Key 'DefaultStartupMode' -Value $Script:DefaultStartupMode } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.RestoreGuiSettingsSnapshot.SaveDefaultStartupModePreference' }
			}
			if ($ChkSafeMode)
			{
				$ChkSafeMode.IsChecked = $desiredSafe
				$ChkSafeMode.Content = if ($desiredSafe)
				{
					Get-UxLocalizedString -Key 'GuiHelpSectionSafeMode' -Fallback 'Safe Mode'
				}
				else
				{
					Get-UxLocalizedString -Key 'GuiHelpSectionExpertMode' -Fallback 'Expert Mode'
				}
			}
			if ($ExpertModeBanner)
			{
				$ExpertModeBanner.Visibility = if ($desiredAdvanced) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
			}
			$modeHidden = if ($desiredSafe) { [System.Windows.Visibility]::Collapsed } else { [System.Windows.Visibility]::Visible }
			if ($BtnLog) { $BtnLog.Visibility = [System.Windows.Visibility]::Collapsed }
			if ($BtnFilterToggle) { $BtnFilterToggle.Visibility = $modeHidden }
			if ($ChkScan) { $ChkScan.Visibility = $modeHidden }
			if ($Script:MenuTools) { $Script:MenuTools.Visibility = $modeHidden }
			if ($Script:MenuActionsCheckCompliance) { $Script:MenuActionsCheckCompliance.Visibility = $modeHidden }
			if ($Script:MenuActionsScanSystem) { $Script:MenuActionsScanSystem.Visibility = $modeHidden }
			if ($Script:MenuActionsAuditLog) { $Script:MenuActionsAuditLog.Visibility = $modeHidden }
			if ($Script:MenuViewFilters) { $Script:MenuViewFilters.Visibility = $modeHidden }
			if ($Script:MenuFileExportSystemState) { $Script:MenuFileExportSystemState.Visibility = $modeHidden }
			if ($Script:MenuFileExportConfigProfile) { $Script:MenuFileExportConfigProfile.Visibility = $modeHidden }

			$Script:GameMode = $desiredGameMode
			$Script:GameModeProfile = if ([string]::IsNullOrWhiteSpace($desiredGameModeProfile)) { $null } else { $desiredGameModeProfile }
			$Script:GameModeCorePlan = @($desiredGameModeCorePlan)
			$Script:GameModePlan = @($desiredGameModePlan)
			$Script:GameModeDecisionOverrides = @{}
			foreach ($overrideKey in @($desiredGameModeDecisionOverrides.Keys))
			{
				if ([string]::IsNullOrWhiteSpace([string]$overrideKey)) { continue }
				$Script:GameModeDecisionOverrides[[string]$overrideKey] = [string]$desiredGameModeDecisionOverrides[$overrideKey]
			}
			$Script:GameModeAdvancedSelections = @{}
			foreach ($advSelKey in @($desiredGameModeAdvancedSelections.Keys))
			{
				if ([string]::IsNullOrWhiteSpace([string]$advSelKey)) { continue }
				$Script:GameModeAdvancedSelections[[string]$advSelKey] = [bool]$desiredGameModeAdvancedSelections[$advSelKey]
			}
			if ($ChkGameMode)
			{
				if ([bool]$ChkGameMode.IsChecked -ne $desiredGameMode)
				{
					$ChkGameMode.IsChecked = $desiredGameMode
				}
			}

			$Script:RiskFilter = $desiredRisk
			if ($CmbRiskFilter)
			{
				if ($Script:RiskFilterInternalValues -and $Script:RiskFilterInternalValues.Contains($desiredRisk))
				{
					$found = $Script:RiskFilterInternalValues.IndexOf($desiredRisk)
					if ($found -ge 0) { $CmbRiskFilter.SelectedIndex = [int]$found }
				}
				else
				{
					[int]$idx = 0
					$CmbRiskFilter.SelectedIndex = $idx
					$Script:RiskFilter = 'All'
				}
			}

			$Script:PlatformFilter = $desiredPlatform
			$Script:HideUnavailableItems = $desiredHideUnavailableItems
			if ($ChkHideUnavailableItems) { $ChkHideUnavailableItems.IsChecked = $desiredHideUnavailableItems }
			$Script:SelectedOnlyFilter = $desiredSelectedOnly
			if ($ChkSelectedOnly) { $ChkSelectedOnly.IsChecked = $desiredSelectedOnly }
			$Script:HighRiskOnlyFilter = $desiredHighRiskOnly
			if ($ChkHighRiskOnly) { $ChkHighRiskOnly.IsChecked = $desiredHighRiskOnly }
			$Script:RestorableOnlyFilter = $desiredRestorableOnly
			if ($ChkRestorableOnly) { $ChkRestorableOnly.IsChecked = $desiredRestorableOnly }
			$Script:GamingOnlyFilter = $desiredGamingOnly
			if ($ChkGamingOnly) { $ChkGamingOnly.IsChecked = $desiredGamingOnly }
		}
		finally
		{
			$Script:FilterUiUpdating = $false
		}

		$Script:RequireRunConfirmation = $desiredRequireRunConfirmation
		$Script:PreviewBeforeRunDefault = $desiredPreviewBeforeRunDefault
		$Script:AppsAutoUpdate = $desiredAppsAutoUpdate
		$Script:AppsSilentInstall = $desiredAppsSilentInstall
		$Script:LoggingEnabled = $desiredLoggingEnabled
		$Script:ExperimentalFeatures = $desiredExperimentalFeatures
		$null = Set-PlatformFilterState -PlatformFilter $desiredPlatform
		$null = Set-HideUnavailableItemsState -HideUnavailableItems $desiredHideUnavailableItems
		$Script:SearchText = $desiredSearch
		$Script:AppsSearchText = $desiredAppsSearch
		$Script:AuditRetentionDays = [int]$desiredAuditRetentionDays
		if ($Script:Ctx -and $Script:Ctx.ContainsKey('UI'))
		{
			$Script:Ctx.UI.AuditRetentionDays = [int]$desiredAuditRetentionDays
		}
		$Script:PinnedBaselineVersion = $desiredPinnedBaselineVersion
		if ($Script:Ctx -and $Script:Ctx.ContainsKey('UI'))
		{
			$Script:Ctx.UI.PinnedBaselineVersion = $desiredPinnedBaselineVersion
		}
		$Script:AppsPackageSourcePreference = $desiredAppsPackageSourcePreference
		$Script:AppsSourceFilter = $desiredAppsSourceFilter
		Initialize-AppsQueuedActionState
		$Script:AppsQueuedActions.Clear()
		foreach ($queuedAction in @($desiredAppsQueuedActions))
		{
			if (-not $queuedAction) { continue }
			$appId = if ((Test-GuiObjectField -Object $queuedAction -FieldName 'AppId')) { [string]$queuedAction.AppId } else { $null }
			$action = if ((Test-GuiObjectField -Object $queuedAction -FieldName 'Action')) { [string]$queuedAction.Action } else { $null }
			if ([string]::IsNullOrWhiteSpace($appId) -or [string]::IsNullOrWhiteSpace($action)) { continue }
			switch ($action)
			{
				'Install' { $Script:AppsQueuedActions[$appId] = 'Install' }
				'Uninstall' { $Script:AppsQueuedActions[$appId] = 'Uninstall' }
			}
		}
		Sync-AppsQueuedActionControls
		if ($TxtSearch)
		{
			$desiredSearchText = if ($Script:AppsModeActive) { $desiredAppsSearch } else { $desiredSearch }
			if ($TxtSearch.Text -ne $desiredSearchText)
			{
				$Script:SearchUiUpdating = $true
				try
				{
					$TxtSearch.Text = $desiredSearchText
				}
				finally
				{
					$Script:SearchUiUpdating = $false
				}
			}
			if (Get-Command -Name 'Sync-GuiSearchInputChrome' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Sync-GuiSearchInputChrome
			}
		}

		Update-SearchResultsTabState

		$Script:FilterUiUpdating = $true
		try
		{
			$Script:CategoryFilter = $desiredCategory
			if ($CmbCategoryFilter)
			{
				if ($Script:CategoryFilterInternalValues -and $Script:CategoryFilterInternalValues.Contains($desiredCategory))
				{
					$found = $Script:CategoryFilterInternalValues.IndexOf($desiredCategory)
					if ($found -ge 0) { $CmbCategoryFilter.SelectedIndex = [int]$found }
				}
				else
				{
					[int]$idx = 0
					$CmbCategoryFilter.SelectedIndex = $idx
					$Script:CategoryFilter = 'All'
				}
			}
			$Script:AppsFilterUiUpdating = $true
			try
			{
				$Script:AppsCategoryFilter = $desiredAppsCategory
				if ($Script:AppsCategoryTabs -and $Script:AppsCategoryFilterInternalValues -and $Script:AppsCategoryFilterInternalValues.Count -gt 0)
				{
					if ($Script:AppsCategoryFilterInternalValues.Contains($desiredAppsCategory))
					{
						$found = $Script:AppsCategoryFilterInternalValues.IndexOf($desiredAppsCategory)
						if ($found -ge 0) { $Script:AppsCategoryTabs.SelectedIndex = [int]$found }
					}
					else
					{
						$Script:AppsCategoryTabs.SelectedIndex = 0
						$Script:AppsCategoryFilter = 'All'
					}
				}
				$Script:AppsStatusFilter = $desiredAppsStatus
				if ($CmbAppsStatusFilter -and $Script:AppsStatusFilterInternalValues -and $Script:AppsStatusFilterInternalValues.Count -gt 0)
				{
					if ($Script:AppsStatusFilterInternalValues.Contains($desiredAppsStatus))
					{
						$foundStatus = $Script:AppsStatusFilterInternalValues.IndexOf($desiredAppsStatus)
						if ($foundStatus -ge 0) { $CmbAppsStatusFilter.SelectedIndex = [int]$foundStatus }
					}
					else
					{
						$CmbAppsStatusFilter.SelectedIndex = 0
						$Script:AppsStatusFilter = 'All'
					}
				}
			}
			finally
			{
				$Script:AppsFilterUiUpdating = $false
			}
		}
		finally
		{
			$Script:FilterUiUpdating = $false
		}

		Update-CategoryFilterList -PrimaryTab $(if ($desiredSearch) { $Script:SearchResultsTabTag } else { $desiredTab })
		Update-SearchResultsTabState
		if (Get-Command -Name 'Update-AppPackageSourcePreferenceControls' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-AppPackageSourcePreferenceControls
		}
		if (Get-Command -Name 'Update-AppSourceFilterControls' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-AppSourceFilterControls
		}
		if (Get-Command -Name 'Update-AppsViewModeControls' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-AppsViewModeControls
		}

		if ([string]::IsNullOrWhiteSpace($desiredSearch) -and $desiredTab)
		{
			if ($desiredTab -eq $Script:SearchResultsTabTag)
			{
				$restoreTag = if ($desiredLast) { $desiredLast } else { $Script:LastStandardPrimaryTab }
				$restoreTab = if ($restoreTag) { Get-PrimaryTabItem -Tag $restoreTag } else { $null }
				if (-not $restoreTab)
				{
					foreach ($tab in $PrimaryTabs.Items)
					{
						if (($tab -is [System.Windows.Controls.TabItem]) -and $tab.Tag -and ([string]$tab.Tag -ne $Script:SearchResultsTabTag))
						{
							$restoreTab = $tab
							break
						}
					}
				}
				if ($restoreTab -and $PrimaryTabs.SelectedItem -ne $restoreTab)
				{
					$PrimaryTabs.SelectedItem = $restoreTab
				}
			}
			else
			{
				$targetTab = Get-PrimaryTabItem -Tag $desiredTab
				if ($targetTab -and $PrimaryTabs.SelectedItem -ne $targetTab)
				{
					$PrimaryTabs.SelectedItem = $targetTab
				}
				elseif (-not $targetTab -and $PrimaryTabs)
				{
					foreach ($tab in $PrimaryTabs.Items)
					{
						if (($tab -is [System.Windows.Controls.TabItem]) -and $tab.Tag -and ([string]$tab.Tag -ne $Script:SearchResultsTabTag))
						{
							$PrimaryTabs.SelectedItem = $tab
							break
						}
					}
				}
			}
		}

		if (Get-Command -Name 'Set-DesignModeState' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Set-DesignModeState -Enabled $desiredDesignMode
		}

		# Invalidate tab content cache so the preset panel rebuilds with the
		# restored Safe Mode / Advanced Mode state instead of reusing stale
		# cached content that was built with the default mode values.
		$Script:FilterGeneration++
		if ($Script:ClearTabContentCacheScript) { & $Script:ClearTabContentCacheScript }

		$refreshCurrentTabContentScript = ${function:Update-CurrentTabContent}
		$startGuiPerfScopeScript = Get-GuiFunctionCapture -Name 'Start-GuiPerfScope'
		$stopGuiPerfScopeScript = Get-GuiFunctionCapture -Name 'Stop-GuiPerfScope'
		$__perf = if ($startGuiPerfScopeScript) { & $startGuiPerfScopeScript -Name 'RestoreGuiSessionState.TabHydrate' } else { $null }
		try
		{
			& $refreshCurrentTabContentScript -SkipIdlePrebuild
		}
		finally
		{
			if ($stopGuiPerfScopeScript) { & $stopGuiPerfScopeScript -Scope $__perf }
		}
		$Script:StartupRestoreSessionPending = $false
		Update-HeaderModeStateText
		if ($TxtLanguageState -and -not [string]::IsNullOrWhiteSpace([string]$Script:SelectedLanguage))
		{
			$TxtLanguageState.Text = ([string]$Script:SelectedLanguage).ToUpperInvariant()
		}
		if (Get-Command -Name 'Update-GuiLocalizationStrings' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-GuiLocalizationStrings
		}
		if (Get-Command -Name 'Update-PrimaryTabHeaders' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-PrimaryTabHeaders
		}
		if (Get-Command -Name 'Sync-UxActionButtonText' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Sync-UxActionButtonText
		}
		Set-GuiActionButtonsEnabled -Enabled (-not (& $Script:TestGuiRunInProgressScript))
	}

	<#
	    .SYNOPSIS
	    Internal function Restore-GuiSnapshot.
	#>

	function Restore-GuiSnapshot
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		if (-not $Script:UiSnapshotUndo)
		{
			return $false
		}

		$redoSnapshot = Get-GuiSettingsSnapshot
		try
		{
			Restore-GuiSettingsSnapshot -Snapshot $Script:UiSnapshotUndo
		}
		catch
		{
			try
			{
				Restore-GuiSettingsSnapshot -Snapshot $redoSnapshot
			}
			catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.Restore-GuiSnapshot.RestoreRedoSnapshot' }
			throw "Failed to restore the previous GUI snapshot: $($_.Exception.Message)"
		}

		$Script:UiSnapshotUndo = $redoSnapshot
		Set-GuiActionButtonsEnabled -Enabled (-not (& $Script:TestGuiRunInProgressScript))
		return $true
	}

	<#
	    .SYNOPSIS
	    Internal function Get-GuiSettingsProfileDirectory.
	#>

	function Get-GuiSettingsProfileDirectory
	{
		param ()
		return (GUICommon\Get-GuiSettingsProfileDirectory -AppName 'Baseline')
	}

	<#
	    .SYNOPSIS
	    Internal function .
	#>
	function Get-GuiSessionStatePath
	{
		param ()
		return (GUICommon\Get-GuiSessionStatePath -AppName 'Baseline')
	}

	<#
	    .SYNOPSIS
	    Internal function .
	#>
	function Get-GuiFirstRunWelcomeMarkerPath
	{
		param ()
		return (Join-Path (Get-GuiSettingsProfileDirectory) 'Baseline-first-run-welcome.txt')
	}

	<#
	    .SYNOPSIS
	    Internal function Test-GuiFirstRunWelcomePending.
	#>

	function Test-GuiFirstRunWelcomePending
	{
		param ()
		return (-not (Test-Path -LiteralPath (Get-GuiFirstRunWelcomeMarkerPath)))
	}

	<#
	    .SYNOPSIS
	    Internal function .
	#>
	function Complete-GuiFirstRunWelcome
	{
		param ()

		$markerPath = Get-GuiFirstRunWelcomeMarkerPath
		$markerDirectory = Split-Path -Parent $markerPath
		try
		{
			if (-not (Test-Path -LiteralPath $markerDirectory))
			{
				[void](New-Item -ItemType Directory -Path $markerDirectory -Force -ErrorAction Stop)
			}

			(Get-Date).ToString('o') | Set-Content -LiteralPath $markerPath -Encoding UTF8 -Force
			return $true
		}
		catch
		{
			LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogSessionPersistWelcomeStateFailed' -Fallback 'Failed to persist first-run welcome state'))
			return $false
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Import-GuiLastRunProfile.
	#>

	function Import-GuiLastRunProfile
	{
		param ()

		$path = GUICommon\Get-GuiLastRunFilePath
		if (-not (Test-Path -LiteralPath $path -ErrorAction SilentlyContinue))
		{
			return $null
		}

		try
		{
			return (Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-BaselineJson -Depth 16)
		}
		catch
		{
			LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogSessionLoadLastRunFailed' -Fallback 'Failed to load last run profile'))
			return $null
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Import-GuiInterruptedRunProfile.
	#>

	function Import-GuiInterruptedRunProfile
	{
		param ()

		$path = GUICommon\Get-GuiInterruptedRunFilePath
		if (-not (Test-Path -LiteralPath $path -ErrorAction SilentlyContinue))
		{
			return $null
		}

		try
		{
			return (Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-BaselineJson -Depth 16)
		}
		catch
		{
			LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogSessionLoadInterruptedRunFailed' -Fallback 'Failed to load interrupted run profile'))
			return $null
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Clear-GuiLastRunProfile.
	#>

	function Clear-GuiLastRunProfile
	{
		param ()

		$path = GUICommon\Get-GuiLastRunFilePath
		if (Test-Path -LiteralPath $path -ErrorAction SilentlyContinue)
		{
			try
			{
				Remove-Item -LiteralPath $path -Force -ErrorAction Stop
			}
			catch
			{
				LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogSessionRemoveLastRunFailed' -Fallback 'Failed to remove last run profile'))
			}
		}
		$Script:LastRunProfile = $null
	}

	<#
	    .SYNOPSIS
	    Internal function Clear-GuiInterruptedRunProfile.
	#>

	function Clear-GuiInterruptedRunProfile
	{
		param ()

		$path = GUICommon\Get-GuiInterruptedRunFilePath
		if (Test-Path -LiteralPath $path -ErrorAction SilentlyContinue)
		{
			try
			{
				Remove-Item -LiteralPath $path -Force -ErrorAction Stop
			}
			catch
			{
				LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogSessionRemoveInterruptedRunFailed' -Fallback 'Failed to remove interrupted run profile'))
			}
		}
		$Script:InterruptedRunProfile = $null
	}

	<#
	    .SYNOPSIS
	    Internal function Save-GuiInterruptedRunProfile.
	#>

	function Save-GuiInterruptedRunProfile
	{
		param (
			[Parameter(Mandatory = $true)]
			[object[]]$ResumeCandidates,

			[string]$Mode = 'Run',
			[string]$Reason = 'Interrupted'
		)

		$candidates = @($ResumeCandidates | Where-Object { $_ })
		if ($candidates.Count -eq 0)
		{
			return $false
		}

		$payload = [ordered]@{
			Schema = 'Baseline.InterruptedRun'
			SchemaVersion = 1
			Timestamp = (Get-Date).ToString('o')
			Mode = [string]$Mode
			Reason = [string]$Reason
			ResumeCandidates = @($candidates)
		}

		$path = GUICommon\Get-GuiInterruptedRunFilePath
		try
		{
			($payload | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $path -Encoding UTF8 -Force
			$Script:InterruptedRunProfile = [pscustomobject]$payload
			return $true
		}
		catch
		{
			LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogSessionSaveInterruptedRunFailed' -Fallback 'Failed to save interrupted run profile'))
			return $false
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Save-GuiSessionState.
	#>

	function Save-GuiSessionState
	{
		param ()
		return (GUICommon\Save-GuiSessionStateDocument -Snapshot (Get-GuiSettingsSnapshot) -AppName 'Baseline')
	}

	<#
	    .SYNOPSIS
	    Internal function .
	#>
	function Restore-GuiSessionState
	{
		param (
			[object]
			$Snapshot = $null
		)

		$snapshot = $Snapshot
		if (-not $snapshot)
		{
			$snapshot = GUICommon\Read-GuiSessionStateDocument -AppName 'Baseline' -ExpectedSchema 'Baseline.GuiSettings'
		}
		if (-not $snapshot)
		{
			return $false
		}

		try
		{
			Restore-GuiSettingsSnapshot -Snapshot $snapshot
			LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogSessionRestoredPreviousState' -Fallback 'Restored previous GUI session state.')
			return $true
		}
		catch
		{
			LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix (Get-UxBilingualLocalizedString -Key 'GuiLogRestoreSessionFailed' -Fallback 'Failed to restore GUI session state'))
			return $false
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Export-GuiSettingsProfile.
	#>

	function Export-GuiSettingsProfile
	{
		param ()

		$snapshot = Get-GuiSettingsSnapshot
		$savePath = GUICommon\Show-GuiSettingsSaveDialog -AppName 'Baseline'
		if ([string]::IsNullOrWhiteSpace($savePath))
		{
			return $false
		}

		try
		{
			[void](GUICommon\Write-GuiSettingsProfileDocument -Snapshot $snapshot -FilePath $savePath)
			LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogExportGuiSettings' -Fallback 'Exported GUI settings to {0}' -FormatArgs @($savePath))
			Set-GuiStatusText -Text (Get-UxLocalizedString -Key 'GuiLogExportGuiSettings' -Fallback '' -FormatArgs @($savePath)) -Tone 'accent'
			return $true
		}
		catch
		{
			LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to export GUI settings')
			[void](Show-ThemedDialog -Title (Get-UxLocalizedString -Key 'GuiExportSettings' -Fallback '') -Message (Get-UxLocalizedString -Key 'GuiLogExportGuiSettingsFailed' -Fallback '' -FormatArgs @($_.Exception.Message)) -Buttons @('OK') -AccentButton 'OK')
			return $false
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Import-GuiSettingsProfile.
	#>

	function Import-GuiSettingsProfile
	{
		param ()

		$importTitle = (Get-UxLocalizedString -Key 'GuiImportSettings' -Fallback 'Import Settings')
		$importChoice = Show-GuiSettingsImportDialog -AppName 'Baseline'
		if ([string]::IsNullOrWhiteSpace($importChoice))
		{
			return $false
		}

		$profilePath = $null
		$sourceLabel = $null
		$sourceDescription = $null
		$useSessionStateReader = $false

		switch ($importChoice)
		{
			'Own'
			{
				$sourceLabel = (Get-UxLocalizedString -Key 'GuiImportSettingsOwnTitle' -Fallback 'Saved profile')
				$sourceDescription = (Get-UxLocalizedString -Key 'GuiImportSettingsOwnDetail' -Fallback ("Open a Baseline settings profile from the {0} settings folder." -f 'Baseline'))
				$profilePath = GUICommon\Show-GuiFileOpenDialog -Title $importTitle -Filter 'Baseline Settings (*.json)|*.json|All Files (*.*)|*.*' -InitialDirectory (Get-GuiSettingsProfileDirectory)
			}
			'Recommended'
			{
				$sourceLabel = (Get-UxLocalizedString -Key 'GuiImportSettingsRecommendedTitle' -Fallback 'Last run')
				$sourceDescription = (Get-UxLocalizedString -Key 'GuiImportSettingsRecommendedDetail' -Fallback 'Load the profile saved after Baseline finished its last run.')
				$profilePath = GUICommon\Get-GuiLastRunFilePath
			}
			'Backup'
			{
				$sourceLabel = (Get-UxLocalizedString -Key 'GuiImportSettingsBackupTitle' -Fallback 'Session backup')
				$sourceDescription = (Get-UxLocalizedString -Key 'GuiImportSettingsBackupDetail' -Fallback 'Load the current session-state backup used for undo and restore.')
				$profilePath = Get-GuiSessionStatePath
				$useSessionStateReader = $true
			}
			'Custom'
			{
				$sourceLabel = (Get-UxLocalizedString -Key 'GuiImportSettingsCustomTitle' -Fallback 'Custom file')
				$sourceDescription = (Get-UxLocalizedString -Key 'GuiImportSettingsCustomDetail' -Fallback 'Browse to any compatible Baseline settings JSON file.')
				$profilePath = GUICommon\Show-GuiFileOpenDialog -Title $importTitle -Filter 'Baseline Settings (*.json)|*.json|All Files (*.*)|*.*'
			}
			default
			{
				return $false
			}
		}

		if ([string]::IsNullOrWhiteSpace($profilePath))
		{
			return $false
		}

		if (-not (Test-Path -LiteralPath $profilePath -ErrorAction SilentlyContinue))
		{
			$missingMessage = switch ($importChoice)
			{
				'Recommended' { Get-UxLocalizedString -Key 'GuiImportSettingsNoLastRun' -Fallback '' }
				'Backup' { Get-UxLocalizedString -Key 'GuiImportSettingsNoSessionBackup' -Fallback '' }
				default { Get-UxLocalizedString -Key 'GuiImportSettingsFileNotFound' -Fallback '' }
			}
			LogWarning (Get-UxBilingualLocalizedString -Key 'GuiLogImportGuiSettingsReadFailed' -Fallback 'Failed to read GUI settings profile: {0}' -FormatArgs @($missingMessage))
			[void](Show-ThemedDialog -Title $importTitle -Message $missingMessage -Buttons @('OK') -AccentButton 'OK')
			return $false
		}

		Show-BaselineImportOverlay -Title $importTitle -Description $sourceDescription -StatusText (Get-UxLocalizedString -Key 'GuiImportSettingsPreparing' -Fallback 'Preparing import...')
		if ($Script:MainForm -and $Script:MainForm.Dispatcher)
		{
			Invoke-GuiDispatcherAction -Dispatcher $Script:MainForm.Dispatcher -Action { } -PriorityUsage 'RenderRefresh' -Synchronous
		}

		try
		{
			if ($useSessionStateReader)
			{
				$snapshot = GUICommon\Read-GuiSessionStateDocument -AppName 'Baseline' -ExpectedSchema 'Baseline.GuiSettings'
			if (-not $snapshot)
			{
				throw 'The selected session backup did not contain a valid Baseline settings snapshot.'
			}
			}
			else
			{
				$snapshot = GUICommon\Read-GuiSettingsProfileDocument -FilePath $profilePath -ExpectedSchema 'Baseline.GuiSettings'
			}
		}
		catch
		{
			Hide-BaselineUpdateOverlay
			LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to read GUI settings profile')
			[void](Show-ThemedDialog -Title $importTitle -Message (Get-UxLocalizedString -Key 'GuiLogImportGuiSettingsReadFailed' -Fallback '' -FormatArgs @($_.Exception.Message)) -Buttons @('OK') -AccentButton 'OK')
			return $false
		}

		Save-GuiUndoSnapshot
		try
		{
			Show-BaselineImportOverlay -Title $importTitle -Description $sourceDescription -StatusText (Get-UxLocalizedString -Key 'GuiImportSettingsApplying' -Fallback 'Applying settings...')
			if ($Script:MainForm -and $Script:MainForm.Dispatcher)
			{
				Invoke-GuiDispatcherAction -Dispatcher $Script:MainForm.Dispatcher -Action { } -PriorityUsage 'RenderRefresh' -Synchronous
			}

			Restore-GuiSettingsSnapshot -Snapshot $snapshot
			Set-GuiStatusText -Text (Get-UxLocalizedString -Key 'GuiLogImportGuiSettings' -Fallback '' -FormatArgs @($sourceLabel)) -Tone 'accent'
			LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogImportGuiSettings' -Fallback 'Imported GUI settings from {0}' -FormatArgs @($profilePath))
			Set-GuiActionButtonsEnabled -Enabled (-not (& $Script:TestGuiRunInProgressScript))
			return $true
		}
		catch
		{
			LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to import GUI settings')
			if ($Script:UiSnapshotUndo)
			{
				try
				{
					Restore-GuiSettingsSnapshot -Snapshot $Script:UiSnapshotUndo
				}
				catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'SessionState.Import-GuiSettingsProfile.RestoreUndoSnapshot' }
			}
			$Script:UiSnapshotUndo = $null
			Set-GuiActionButtonsEnabled -Enabled (-not (& $Script:TestGuiRunInProgressScript))
			Hide-BaselineUpdateOverlay
			[void](Show-ThemedDialog -Title $importTitle -Message (Get-UxLocalizedString -Key 'GuiLogImportGuiSettingsFailed' -Fallback '' -FormatArgs @($_.Exception.Message)) -Buttons @('OK') -AccentButton 'OK')
			return $false
		}
		finally
		{
			Hide-BaselineUpdateOverlay
		}
	}
