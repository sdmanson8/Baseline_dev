using module ..\..\Logging.psm1
using module ..\..\SharedHelpers.psm1

<#
	.SYNOPSIS
	Configures the Connected User Experiences and Telemetry (DiagTrack) service.


	
.DESCRIPTION
	
Applies the Connected User Experiences and Telemetry (DiagTrack) service in GUI and headless runs.
	.PARAMETER Disable
	Disable the Connected User Experiences and Telemetry (DiagTrack) service, and block connection for the Unified Telemetry Client Outbound Traffic

	.PARAMETER Enable
	Enable the Connected User Experiences and Telemetry (DiagTrack) service, and allow connection for the Unified Telemetry Client Outbound Traffic (default value)

	.EXAMPLE
	DiagTrackService -Disable

	.EXAMPLE
	DiagTrackService -Enable

	.NOTES
	Disabling the "Connected User Experiences and Telemetry" service (DiagTrack) can cause you not being able to get Xbox achievements anymore and affects Feedback Hub

	.NOTES
	Current user
#>

function DiagTrackService
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Disable"
		)]
		[switch]
		$Disable,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Enable"
		)]
		[switch]
		$Enable
	)

	# Checking whether "InitialActions" function was removed in preset file
	if (-not ("WinAPI.GetStrings" -as [type]))
	{
		# Get the name of a preset (e.g Bootstrap/Baseline.ps1) regardless if it was renamed
		# $_.File has no EndsWith() method
		$PresetName = Split-Path -Path (((Get-PSCallStack).Position | Where-Object -FilterScript {$_.File}).File | Where-Object -FilterScript {$_.EndsWith(".ps1")}) -Leaf

		LogError ($Localization.InitialActionsCheckFailed -f $PresetName)
	}

	switch ($PSCmdlet.ParameterSetName)
	{
		"Disable"
		{
			# Connected User Experiences and Telemetry
			# Disabling the "Connected User Experiences and Telemetry" service (DiagTrack) can cause you not being able to get Xbox achievements anymore and affects Feedback Hub
			LogInfo 'Disabling the "Connected User Experiences and Telemetry" service'
			Get-Service -Name DiagTrack -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
			Get-Service -Name DiagTrack | Set-Service -StartupType Disabled -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null

			# Block connection for the Unified Telemetry Client Outbound Traffic
			Get-NetFirewallRule -Group DiagTrack | Set-NetFirewallRule -Enabled True -Action Block | Out-Null
		}
		"Enable"
		{
			# Connected User Experiences and Telemetry
			LogInfo 'Enabling the "Connected User Experiences and Telemetry" service'
			Get-Service -Name DiagTrack | Set-Service -StartupType Automatic -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
			Get-Service -Name DiagTrack | Start-Service -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null

			# Allow connection for the Unified Telemetry Client Outbound Traffic
			Get-NetFirewallRule -Group DiagTrack | Set-NetFirewallRule -Enabled True -Action Allow | Out-Null
		}
	}
}

<#
	.SYNOPSIS
	Diagnostic data


	
.DESCRIPTION
	
Applies the Baseline behavior for diagnostic data.
	.PARAMETER Minimal
	Set the diagnostic data collection to minimum

	.PARAMETER Default
	Set the diagnostic data collection to default (default value)

	.EXAMPLE
	DiagnosticDataLevel -Minimal

	.EXAMPLE
	DiagnosticDataLevel -Default

	.NOTES
	Machine-wide
#>
function DiagnosticDataLevel
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Minimal"
		)]
		[switch]
		$Minimal,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Default"
		)]
		[switch]
		$Default
	)

	if (-not (Test-Path -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection))
	{
		New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Force | Out-Null
	}

	if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack))
	{
		New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack -Force | Out-Null
	}

    # Get Windows edition
    $isEnterpriseOrEducation = $false
    if (Get-Command -Name 'Get-BaselineSystemPlatformInfo' -ErrorAction SilentlyContinue)
    {
        $editionId = [string](Get-BaselineSystemPlatformInfo).EditionID
        $isEnterpriseOrEducation = $editionId -match '(?i)Enterprise|Education'
    }
    else
    {
        $WindowsEdition = (Get-WmiObject -Class Win32_OperatingSystem).Caption
        $isEnterpriseOrEducation = ($WindowsEdition -match "Enterprise") -or ($WindowsEdition -match "Education")
    }

    switch ($PSCmdlet.ParameterSetName) {
        "Minimal" {
			Write-ConsoleStatus -Action "Set Diagnostic Data Collection to Minimal"
			LogInfo "Setting Diagnostic Data Collection to Minimal"
			try
			{
				if ($isEnterpriseOrEducation) {
					New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -PropertyType DWord -Value 0 -Force -ErrorAction Stop | Out-Null
				} else {
					New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -PropertyType DWord -Value 1 -Force -ErrorAction Stop | Out-Null
				}

				New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection -Name MaxTelemetryAllowed -PropertyType DWord -Value 1 -Force -ErrorAction Stop | Out-Null
				Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" -Name ShowedToastAtLevel -Type DWord -Value 1 | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to set Diagnostic Data Collection to Minimal: $($_.Exception.Message)"
			}
		}
        "Default" {
            # Optional diagnostic data
			Write-ConsoleStatus -Action "Set Diagnostic Data Collection to Default"
			LogInfo "Setting Diagnostic Data Collection to Default"
			try
			{
				New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection -Name MaxTelemetryAllowed -PropertyType DWord -Value 3 -Force -ErrorAction Stop | Out-Null
				Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" -Name ShowedToastAtLevel -Type DWord -Value 3 | Out-Null
				if ((Get-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -ErrorAction SilentlyContinue))
				{
					Remove-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" | Out-Null
				}
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to set Diagnostic Data Collection to Default: $($_.Exception.Message)"
			}
		}
    }
}

<#
	.SYNOPSIS
	The diagnostics tracking scheduled tasks


	
.DESCRIPTION
	
Applies the Baseline behavior for the diagnostics tracking scheduled tasks.
	.PARAMETER Disable
	Turn off the diagnostics tracking scheduled tasks

	.PARAMETER Enable
	Turn on the diagnostics tracking scheduled tasks (default value)

	.EXAMPLE
	ScheduledTasks -Disable

	.EXAMPLE
	ScheduledTasks -Enable

	.NOTES
	A pop-up dialog box lets a user select tasks

	.NOTES
	Current user
#>

function Request-GuiScheduledTasksSelection
{
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateSet('Enable', 'Disable')]
		[string]
		$Mode,

		[Parameter(Mandatory = $false)]
		[string[]]
		$SelectedNames = @()
	)

	$queue = Get-Variable -Name 'GUIRunState' -ValueOnly -ErrorAction Ignore
	if (-not $queue)
	{
		throw 'GUI execution could not open the Scheduled Tasks picker because the GUI request queue is unavailable.'
	}

	$responseState = [hashtable]::Synchronized(@{
		Done = $false
		Result = $null
		Error = $null
	})

	$queue.Enqueue([PSCustomObject]@{
		Kind = '_InteractiveSelectionRequest'
		RequestType = 'ScheduledTasks'
		Mode = $Mode
		SelectedNames = @($SelectedNames)
		ResponseState = $responseState
	})

	while (-not [bool]$responseState['Done'])
	{
		$runState = Get-Variable -Name 'runState' -ValueOnly -ErrorAction Ignore
		if ($runState -and $runState.ContainsKey('AbortRequested') -and [bool]$runState['AbortRequested'])
		{
			return $null
		}

		Start-Sleep -Milliseconds 200
	}

	if (-not [string]::IsNullOrWhiteSpace([string]$responseState['Error']))
	{
		throw [System.InvalidOperationException]::new([string]$responseState['Error'])
	}

	return $responseState['Result']
}

<#
    .SYNOPSIS
    Runs scheduled tasks.

    
.DESCRIPTION
    
Supports scheduled tasks handling inside Baseline.
#>

function ScheduledTasks
{
	[CmdletBinding(DefaultParameterSetName = "Disable")]
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Disable"
		)]
		[switch]
		$Disable,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Enable"
		)]
		[switch]
		$Enable,

		[Parameter(Mandatory = $false)]
		[string[]]
		$SelectedTaskNames,

		[Parameter(Mandatory = $false)]
		[switch]
		$CollectSelectionOnly,

		[Parameter(Mandatory = $false)]
		[switch]
		$NonInteractive
	)

	$modulePath = if (-not [string]::IsNullOrWhiteSpace([string]$PSCommandPath))
	{
		[string]$PSCommandPath
	}
	elseif ($MyInvocation.MyCommand.Module -and -not [string]::IsNullOrWhiteSpace([string]$MyInvocation.MyCommand.Module.Path))
	{
		[string]$MyInvocation.MyCommand.Module.Path
	}
	else
	{
		$null
	}

	#region Variables
	# Initialize an array list to store the selected scheduled tasks
	$SelectedTasks = New-Object -TypeName System.Collections.ArrayList($null)
	$SelectionState = [PSCustomObject]@{
		Confirmed = $false
	}
	$script:ScheduledTasksSelectionResult = $null
	$SelectedTaskNamesProvided = $PSBoundParameters.ContainsKey('SelectedTaskNames')

	# The following tasks will have their checkboxes checked
	[string[]]$CheckedScheduledTasks = @(
		# Collects program telemetry information if opted-in to the Microsoft Customer Experience Improvement Program
		"MareBackup",

		# Collects program telemetry information if opted-in to the Microsoft Customer Experience Improvement Program
		"Microsoft Compatibility Appraiser",

		# Updates compatibility database
		"StartupAppTask",

		# This task collects and uploads autochk SQM data if opted-in to the Microsoft Customer Experience Improvement Program
		"Proxy",

		# If the user has consented to participate in the Windows Customer Experience Improvement Program, this job collects and sends usage data to Microsoft
		"Consolidator",

		# The USB CEIP (Customer Experience Improvement Program) task collects Universal Serial Bus related statistics and information about your machine and sends it to the Windows Device Connectivity engineering group at Microsoft
		"UsbCeip",

		# The Windows Disk Diagnostic reports general disk and system information to Microsoft for users participating in the Customer Experience Program
		"Microsoft-Windows-DiskDiagnosticDataCollector",

		# This task shows various Map related toasts
		"MapsToastTask",

		# This task checks for updates to maps which you have downloaded for offline use
		"MapsUpdateTask",

		# Initializes Family Safety monitoring and enforcement
		"FamilySafetyMonitor",

		# Synchronizes the latest settings with the Microsoft family features service
		"FamilySafetyRefreshTask",

		# XblGameSave Standby Task
		"XblGameSaveTask"
	)
	#endregion Variables

	#region Functions
	function Get-CheckboxClicked
	{
			<#
			    .SYNOPSIS
			    Sync a task checkbox into the scheduled-task selection list.

			    .DESCRIPTION
			    Adds or removes the task stored in the checkbox Tag from the SelectedTasks collection based on the current check state.

			    .PARAMETER CheckBox
			    Checkbox control whose Tag contains the task payload.

			    .EXAMPLE
			    $checkBox | Get-CheckboxClicked
			#>
		[CmdletBinding()]
		param
		(
			[Parameter(
				Mandatory = $true,
				ValueFromPipeline = $true
			)]
			[ValidateNotNull()]
			$CheckBox
		)

		$Task = $CheckBox.Tag

		if ($CheckBox.IsChecked)
		{
			if ($null -ne $Task -and -not ($SelectedTasks | Where-Object -FilterScript {$_.TaskName -eq $Task.TaskName}))
			{
				[void]$SelectedTasks.Add($Task)
			}
		}
		else
		{
			if ($null -ne $Task)
			{
				$TaskToRemove = $SelectedTasks | Where-Object -FilterScript {$_.TaskName -eq $Task.TaskName} | Select-Object -First 1
				if ($null -ne $TaskToRemove)
				{
					[void]$SelectedTasks.Remove($TaskToRemove)
				}
			}
		}

		if ($null -ne $Button)
		{
			$Button.IsEnabled = ($SelectedTasks.Count -gt 0)
		}
	}

	<#
	    .SYNOPSIS
	    Checks scheduled task seed selected.

	    
.DESCRIPTION
	    
Supports scheduled task seed selected handling inside Baseline.
	#>

	function Test-ScheduledTaskSeedSelected
	{
		[CmdletBinding()]
		param
		(
			[Parameter(Mandatory = $true)]
			$Task
		)

		if ($SelectedTaskNamesProvided)
		{
			return [bool](@($SelectedTaskNames | Where-Object -FilterScript {$_ -eq $Task.TaskName}).Count -gt 0)
		}

		return [bool](@($CheckedScheduledTasks | Where-Object -FilterScript {$Task.TaskName -match $_}).Count -gt 0)
	}

	<#
	    .SYNOPSIS
	    Gets selected scheduled task list.

	    
.DESCRIPTION
	    
Supports selected scheduled task list handling inside Baseline.
	#>

	function Get-SelectedScheduledTaskList
	{
		return @($SelectedTasks | Where-Object { $_ })
	}

	<#
	    .SYNOPSIS
	    Gets selected scheduled task names.

	    
.DESCRIPTION
	    
Supports selected scheduled task names handling inside Baseline.
	#>
	function Get-SelectedScheduledTaskNames
	{
		return @(
			Get-SelectedScheduledTaskList |
				ForEach-Object {[string]$_.TaskName} |
				Where-Object {-not [string]::IsNullOrWhiteSpace($_)}
		)
	}

	<#
	    .SYNOPSIS
	    Runs scheduled tasks operation.

	    
.DESCRIPTION
	    
Supports scheduled tasks operation handling inside Baseline.
	#>

	function Invoke-ScheduledTasksOperation
	{
		param (
			[object[]]$TaskList
		)

		$ResolvedTaskList = @($TaskList | Where-Object { $_ })
		if ($ResolvedTaskList.Count -eq 0)
		{
			return
		}

		switch ($PSCmdlet.ParameterSetName)
		{
			"Enable"
			{
				$ResolvedTaskList | Enable-ScheduledTask
			}
			"Disable"
			{
				$ResolvedTaskList | Disable-ScheduledTask
			}
		}
	}

	<#
	    .SYNOPSIS
	    Confirms scheduled tasks selection.

	    
.DESCRIPTION
	    
Supports scheduled tasks selection handling inside Baseline.
	#>

	function Confirm-ScheduledTasksSelection
	{
		$SelectedTaskList = @(Get-SelectedScheduledTaskList)
		$SelectionState.Confirmed = $true

		if ($CollectSelectionOnly)
		{
			$script:ScheduledTasksSelectionResult = [PSCustomObject]@{
				Mode = $PSCmdlet.ParameterSetName
				SelectedTaskNames = @(Get-SelectedScheduledTaskNames)
			}
			if ($null -ne $Window)
			{
				[void]$Window.Close()
			}
			return
		}

		foreach ($popupControl in @($Button, $CheckBoxSelectAll, $PanelContainer))
		{
			if ($null -ne $popupControl)
			{
				$popupControl.IsEnabled = $false
			}
		}

		$commandParameters = @{
			SelectedTaskNames = @(Get-SelectedScheduledTaskNames)
		}
		$commandParameters[$PSCmdlet.ParameterSetName] = $true

		if ($modulePath -and (Get-Command -Name 'Start-GuiPopupCommandAsync' -ErrorAction SilentlyContinue))
		{
			[void](GUICommon\Start-GuiPopupCommandAsync -Window $Form -ModulePath $modulePath -CommandName 'ScheduledTasks' -CommandParameters $commandParameters)
			return
		}

		if ($null -ne $Window)
		{
			[void]$Window.Close()
		}

		Invoke-ScheduledTasksOperation -TaskList $SelectedTaskList
	}

	<#
	    .SYNOPSIS
	    Adds task control.

	    
.DESCRIPTION
	    
Supports task control handling inside Baseline.
	#>

	function Add-TaskControl
	{
		[CmdletBinding()]
		param
		(
			[Parameter(
				Mandatory = $true,
				ValueFromPipeline = $true
			)]
			[ValidateNotNull()]
			$Task
		)

		process
		{
			$CheckBox = New-Object -TypeName System.Windows.Controls.CheckBox
			$CheckBox.Add_Click({Get-CheckboxClicked -CheckBox $_.Source})
			$CheckBox.Tag = $Task

			$LabelPanel = New-Object -TypeName System.Windows.Controls.StackPanel
			$LabelPanel.Orientation = 'Horizontal'
			$LabelPanel.VerticalAlignment = 'Center'

			$IconBlock = New-Object -TypeName System.Windows.Controls.TextBlock
			$IconBlock.Text = [char]0xF4C3
			$IconBlock.FontFamily = [System.Windows.Media.FontFamily]::new('FluentSystemIcons')
			$IconBlock.FontSize = 14
			$IconBlock.VerticalAlignment = 'Center'
			$IconBlock.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
			[void]$LabelPanel.Children.Add($IconBlock)

			$TextBlock = New-Object -TypeName System.Windows.Controls.TextBlock
			$TextBlock.Text = $Task.TaskName
			$TextBlock.VerticalAlignment = 'Center'
			[void]$LabelPanel.Children.Add($TextBlock)

			$StackPanel = New-Object -TypeName System.Windows.Controls.StackPanel
			[void]$StackPanel.Children.Add($CheckBox)
			[void]$StackPanel.Children.Add($LabelPanel)
			[void]$PanelContainer.Children.Add($StackPanel)

			# If task checked add to the array list
			if (Test-ScheduledTaskSeedSelected -Task $Task)
			{
				[void]$SelectedTasks.Add($Task)
			}
			else
			{
				$CheckBox.IsChecked = $false
			}

			if ($null -ne $Button)
			{
				$Button.IsEnabled = ($SelectedTasks.Count -gt 0)
			}
		}
	}
	#endregion Functions

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
			if (-not $CollectSelectionOnly)
			{
				Write-ConsoleStatus -Action "Enable Diagnostics Tracking Scheduled Tasks"
				LogInfo "Enabling Diagnostics Tracking Scheduled Tasks"
			}
			$State           = "Disabled"
			# Extract the localized "Enable" string from shell32.dll
			$ButtonContent   = [WinAPI.GetStrings]::GetString(51472)
		}
		"Disable"
		{
			if (-not $CollectSelectionOnly)
			{
				Write-ConsoleStatus -Action "Disable Diagnostics Tracking Scheduled Tasks"
				LogInfo "Disabling Diagnostics Tracking Scheduled Tasks"
			}
			$State           = "Ready"
			$ButtonContent   = $Localization.Disable
		}
	}

	# Getting list of all scheduled tasks according to the conditions
	$Tasks = Get-ScheduledTask | Where-Object -FilterScript {($_.State -eq $State) -and ($_.TaskName -in $CheckedScheduledTasks)}

	if (-not $Tasks)
	{
		if ($CollectSelectionOnly)
		{
			return [PSCustomObject]@{
				Mode = $PSCmdlet.ParameterSetName
				SelectedTaskNames = @()
			}
		}
		return
	}

	if ($Global:GUIMode -and -not $CollectSelectionOnly -and -not $SelectedTaskNamesProvided)
	{
		$selectionResult = Request-GuiScheduledTasksSelection -Mode $PSCmdlet.ParameterSetName -SelectedNames @($SelectedTaskNames)
		if ($null -ne $selectionResult)
		{
			$SelectedTaskNames = @($selectionResult.SelectedTaskNames)
			$SelectedTaskNamesProvided = $true
		}
	}

	if ($SelectedTaskNamesProvided -and -not $CollectSelectionOnly)
	{
		$ResolvedSelectedTasks = @(
			$Tasks | Where-Object -FilterScript {$SelectedTaskNames -contains $_.TaskName}
		)
		Invoke-ScheduledTasksOperation -TaskList $ResolvedSelectedTasks
		Write-ConsoleStatus -Status success
		return
	}

	if ($NonInteractive -and -not $SelectedTaskNamesProvided)
	{
		LogWarning 'Skipping diagnostics tracking scheduled tasks because no preselected tasks were provided for noninteractive execution.'
		Write-ConsoleStatus -Status warning
		return
	}

	Add-Type -AssemblyName PresentationCore, PresentationFramework

	#region XAML Markup
	# This block defines the dialog XAML used at runtime.
	[xml]$XAML = @"
	<Window
		xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Name="Window"
		MinHeight="450" MinWidth="400"
		SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen"
		TextOptions.TextFormattingMode="Display" SnapsToDevicePixels="True"
		FontFamily="FluentSystemIcons" FontSize="12" ShowInTaskbar="True"
		Background="Transparent" WindowStyle="None" AllowsTransparency="True" Foreground="#262626">
		<Window.Resources>
			<Style TargetType="StackPanel">
				<Setter Property="Orientation" Value="Horizontal"/>
				<Setter Property="VerticalAlignment" Value="Top"/>
			</Style>
			<Style TargetType="CheckBox">
				<Setter Property="Margin" Value="10, 10, 5, 10"/>
				<Setter Property="IsChecked" Value="True"/>
			</Style>
			<Style TargetType="TextBlock">
				<Setter Property="Margin" Value="5, 10, 10, 10"/>
			</Style>
			<Style TargetType="Button">
				<Setter Property="Margin" Value="20"/>
				<Setter Property="Padding" Value="10"/>
			</Style>
			<Style TargetType="Border">
				<Setter Property="Grid.Row" Value="1"/>
				<Setter Property="CornerRadius" Value="0"/>
				<Setter Property="BorderThickness" Value="0, 1, 0, 1"/>
				<Setter Property="BorderBrush" Value="#000000"/>
			</Style>
			<Style TargetType="ScrollViewer">
				<Setter Property="HorizontalScrollBarVisibility" Value="Disabled"/>
				<Setter Property="BorderBrush" Value="#000000"/>
				<Setter Property="BorderThickness" Value="0, 1, 0, 1"/>
			</Style>
		</Window.Resources>
		<Border Name="RootBorder" CornerRadius="8">
			<Grid>
				<Grid.RowDefinitions>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="*"/>
					<RowDefinition Height="Auto"/>
				</Grid.RowDefinitions>
				<ScrollViewer Name="Scroll" Grid.Row="0"
					HorizontalScrollBarVisibility="Disabled"
					VerticalScrollBarVisibility="Auto">
					<StackPanel Name="PanelContainer" Orientation="Vertical"/>
				</ScrollViewer>
				<Button Name="Button" Grid.Row="2"/>
			</Grid>
		</Border>
	</Window>
"@
	#endregion XAML Markup

	$Form = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $XAML))
	$XAML.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
		Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name)
	}

	# Apply theme styling
	if (Test-Path -Path Variable:\Script:CurrentTheme) {
		$Theme = $Script:CurrentTheme
		$UseDarkMode = if (Test-Path -Path Variable:\Script:CurrentThemeName) { $Script:CurrentThemeName -eq 'Dark' } else { $false }
		$RootBorder.Background = [System.Windows.Media.Brush](New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.Color]::FromArgb(255, [System.Convert]::ToInt32($Theme.WindowBg.Substring(1, 2), 16), [System.Convert]::ToInt32($Theme.WindowBg.Substring(3, 2), 16), [System.Convert]::ToInt32($Theme.WindowBg.Substring(5, 2), 16))))
		$RootBorder.BorderBrush = [System.Windows.Media.Brush](New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.Color]::FromArgb(255, [System.Convert]::ToInt32($Theme.BorderColor.Substring(1, 2), 16), [System.Convert]::ToInt32($Theme.BorderColor.Substring(3, 2), 16), [System.Convert]::ToInt32($Theme.BorderColor.Substring(5, 2), 16))))
		$RootBorder.BorderThickness = '1'
		Set-GuiWindowChromeTheme -Window $Form -UseDarkMode $UseDarkMode
	} else {
		$RootBorder.Background = [System.Windows.Media.Brush](New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.Color]::FromArgb(255, 241, 241, 241)))
		$RootBorder.BorderBrush = [System.Windows.Media.Brush](New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.Color]::FromArgb(255, 200, 200, 200)))
		$RootBorder.BorderThickness = '1'
	}

	#region Sendkey function
	# Emulate the Backspace key sending to prevent the console window to freeze
	Start-Sleep -Milliseconds 500

	Add-Type -AssemblyName System.Windows.Forms

	# We cannot use Get-Process -Id $PID as script might be invoked via Terminal with different $PID
	Get-Process -Name Baseline, powershell, WindowsTerminal -ErrorAction Ignore | Where-Object -FilterScript {$_.MainWindowTitle -match "Baseline \| Utility for Windows"} | ForEach-Object -Process {
		# Show window, if minimized
		[WinAPI.ForegroundWindow]::ShowWindowAsync($_.MainWindowHandle, 10)

		Start-Sleep -Seconds 1

		# Force move the console window to the foreground
		[WinAPI.ForegroundWindow]::SetForegroundWindow($_.MainWindowHandle)

		Start-Sleep -Seconds 1

		# Emulate the Backspace key sending
		[System.Windows.Forms.SendKeys]::SendWait("{BACKSPACE 1}")
	}
	#endregion Sendkey function

	$Window.Add_Loaded({$Tasks | Add-TaskControl})
	$Button.Content = $ButtonContent
	$Button.Add_Click({Confirm-ScheduledTasksSelection})

	$Window.Title = $Localization.ScheduledTasks
	if (Test-Path -Path Function:\Add-GuiPopupWindowChrome)
	{
		[void](GUICommon\Add-GuiPopupWindowChrome -Window $Form -RootBorder $RootBorder -PanelContainer $PanelContainer -Theme $Theme -UseDarkMode $UseDarkMode)
	}
	$Button.IsEnabled = $false

	if ($Global:GUIMode -and -not $CollectSelectionOnly)
	{
		# GUI-mode runs collect the scheduled task selection on the main UI thread when this tweak starts.
	}
	else
	{
		# Restore minimized dialogs and bring them to the foreground once when shown.
		Initialize-WpfWindowForeground -Window $Form
		$Form.ShowDialog() | Out-Null
	}

	if ($CollectSelectionOnly)
	{
		return $script:ScheduledTasksSelectionResult
	}

	if ($Form.PSObject.Properties['GuiPopupOperationError'] -and $Form.GuiPopupOperationError)
	{
		$operationError = $Form.GuiPopupOperationError
		Remove-HandledErrorRecord -ErrorRecord $operationError
		LogError "Failed to $(if ($PSCmdlet.ParameterSetName -eq 'Disable') { 'disable' } else { 'enable' }) scheduled tasks: $($operationError.Exception.Message)"
		Write-ConsoleStatus -Status failed
		throw $operationError
	}

	if ($SelectionState.Confirmed)
	{
		Write-ConsoleStatus -Status success
	}

	if (-not $SelectionState.Confirmed)
	{
		LogWarning 'Skipping diagnostics tracking scheduled tasks because no selection was confirmed.'
		Write-ConsoleStatus -Status warning
	}

}

<#
.SYNOPSIS
Enable or disable PowerShell 7 Telemetry

.PARAMETER Enable
Enable PowerShell 7 Telemetry (default value)

.PARAMETER Disable
Disable PowerShell 7 Telemetry

.EXAMPLE
Powershell7Telemetry -Enable

.EXAMPLE
Powershell7Telemetry -Disable

.NOTES
Current user
#>
function Powershell7Telemetry
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Enable"
		)]
		[switch]
		$Enable,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Disable"
		)]
		[switch]
		$Disable
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
			Write-ConsoleStatus -Action "Enabling PowerShell 7 Telemetry"
			LogInfo "Enabling PowerShell 7 Telemetry"
			try
			{
				[Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '', 'Machine')
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to enable PowerShell 7 Telemetry: $($_.Exception.Message)"
			}
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Disabling PowerShell 7 Telemetry"
			LogInfo "Disabling PowerShell 7 Telemetry"
			try
			{
				[Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'Machine')
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to disable PowerShell 7 Telemetry: $($_.Exception.Message)"
			}
		}
	}
}

<#
	.SYNOPSIS
	Windows Error Reporting


	
.DESCRIPTION
	
Applies the Baseline behavior for windows Error Reporting.
	.PARAMETER Disable
	Turn off Windows Error Reporting

	.PARAMETER Enable
	Turn on Windows Error Reporting (default value)

	.EXAMPLE
	ErrorReporting -Disable

	.EXAMPLE
	ErrorReporting -Enable

	.NOTES
	Current user
#>
function ErrorReporting
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Disable"
		)]
		[switch]
		$Disable,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Enable"
		)]
		[switch]
		$Enable
	)

	# Remove all policies in order to make changes visible in UI only if it's possible
	Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -Name Disabled -Force -ErrorAction Ignore | Out-Null
	Remove-RegistryValueSafe -Path "HKCU:\Software\Policies\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" | Out-Null
	Set-Policy -Scope Computer -Path "SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -Name Disabled -Type CLEAR | Out-Null
	Set-Policy -Scope User -Path "Software\Policies\Microsoft\Windows\Windows Error Reporting" -Name Disabled -Type CLEAR | Out-Null

	switch ($PSCmdlet.ParameterSetName)
	{
		"Disable"
			{
				Write-ConsoleStatus -Action "Disable Windows Error Reporting"
				LogInfo "Disabling Windows Error Reporting"
				try
				{
					Get-ScheduledTask -TaskName QueueReporting -ErrorAction Ignore | Disable-ScheduledTask | Out-Null
					Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\Windows Error Reporting" -Name Disabled -Type DWord -Value 1 | Out-Null
					try
					{
						Get-Service -Name WerSvc -ErrorAction Stop | Stop-Service -Force -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
					}
					catch
					{
						LogWarning "Windows Error Reporting Service stop failed: $($_.Exception.Message)"
						Remove-HandledErrorRecord -ErrorRecord $_
					}

					try
					{
						Get-Service -Name WerSvc -ErrorAction Stop | Set-Service -StartupType Disabled -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
					}
					catch
					{
						LogWarning "Windows Error Reporting Service startup-type update failed: $($_.Exception.Message)"
						Remove-HandledErrorRecord -ErrorRecord $_
					}
					Write-ConsoleStatus -Status success
				}
				catch
				{
				Write-ConsoleStatus -Status failed
				LogError "Failed to disable Windows Error Reporting: $($_.Exception.Message)"
			}
		}
		"Enable"
		{
			Write-ConsoleStatus -Action "Enable Windows Error Reporting"
			LogInfo "Enabling Windows Error Reporting"
			try
			{
				Get-ScheduledTask -TaskName QueueReporting -ErrorAction Ignore | Enable-ScheduledTask | Out-Null
				if ((Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\Windows Error Reporting" -Name Disabled -ErrorAction SilentlyContinue))
				{
					Remove-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" | Out-Null
				}
				Get-Service -Name WerSvc | Set-Service -StartupType Manual -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
				Get-Service -Name WerSvc | Start-Service -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to enable Windows Error Reporting: $($_.Exception.Message)"
			}
		}
	}
}

<#
    .SYNOPSIS
    Device Management Wireless Application Protocol (WAP) Push Service settings

    .DESCRIPTION
    Note: This service is needed for Microsoft Intune interoperability

    .PARAMETER Enable
    Enable the Device Management Wireless Application Protocol (WAP) Push Service

    .PARAMETER Disable
    Disable the Device Management Wireless Application Protocol (WAP) Push Service

    .EXAMPLE
    WAPPush -Enable

    .EXAMPLE
    WAPPush -Disable

    .NOTES
    Current user
#>

function WAPPush
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Enable"
		)]
		[switch]
		$Enable,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Disable"
		)]
		[switch]
		$Disable
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
			Write-ConsoleStatus -Action "Enabling Device Management Wireless Application Protocol (WAP) Push Service"
			LogInfo "Enabling Device Management Wireless Application Protocol (WAP) Push Service"
			try
			{
				Set-Service "dmwappushservice" -StartupType Automatic -ErrorAction Stop | Out-Null
				Start-Service "dmwappushservice" -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
				Set-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice" -Name "DelayedAutoStart" -Type DWord -Value 1 -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to enable the WAP Push Service: $($_.Exception.Message)"
			}
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Disabling Device Management Wireless Application Protocol (WAP) Push Service"
			LogInfo "Disabling Device Management Wireless Application Protocol (WAP) Push Service"
			try
			{
				Stop-Service "dmwappushservice" -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
				Set-Service "dmwappushservice" -StartupType Disabled -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to disable the WAP Push Service: $($_.Exception.Message)"
			}
		}
	}
}

Export-ModuleMember -Function '*'
