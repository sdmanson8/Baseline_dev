# DeploymentMediaBuilder.UI.ps1
# Inline view state, status, and background-operation helpers.

function Get-GuiDeploymentMediaBuilderOutputMode
{
	[CmdletBinding()]
	param ()

	if ($Script:CmbDeploymentMediaOutputMode -and $Script:CmbDeploymentMediaOutputMode.SelectedItem)
	{
		$selectedItem = $Script:CmbDeploymentMediaOutputMode.SelectedItem
		if ($selectedItem -and $selectedItem.PSObject.Properties['Content'])
		{
			return [string]$selectedItem.Content
		}
		return [string]$selectedItem
	}

	return 'Create ISO'
}

function Get-GuiDeploymentMediaBuilderEditionName
{
	[CmdletBinding()]
	param ()

	$selectedEdition = Get-GuiDeploymentMediaBuilderSelectedEdition
	if ($selectedEdition -and $selectedEdition.PSObject.Properties['Name'])
	{
		return [string]$selectedEdition.Name
	}

	return ''
}

function Convert-GuiDeploymentMediaBuilderInputPath
{
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[AllowNull()]
		[string]$Path
	)

	$candidate = ([string]$Path).Trim()
	if ([string]::IsNullOrWhiteSpace($candidate)) { return '' }
	$candidate = $candidate.Trim('"')
	if ([string]::IsNullOrWhiteSpace($candidate)) { return '' }

	try { return [System.IO.Path]::GetFullPath($candidate) }
	catch
	{
		if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Write-SwallowedException -ErrorRecord $_ -Source 'DeploymentMediaBuilderView.ConvertInputPath.GetFullPath' -Severity Warning
		}
		return $candidate
	}
}

function Get-GuiDeploymentMediaBuilderSourceIsoPath
{
	[CmdletBinding()]
	[OutputType([string])]
	param ()

	if (-not $Script:TxtDeploymentMediaSourceIso) { return '' }
	return Convert-GuiDeploymentMediaBuilderInputPath -Path ([string]$Script:TxtDeploymentMediaSourceIso.Text)
}

function Test-GuiDeploymentMediaBuilderSourceMatchesDetectedIso
{
	[CmdletBinding()]
	[OutputType([bool])]
	param ()

	if (-not $Script:DeploymentMediaDetectedIsoInfo) { return $false }
	if (-not $Script:DeploymentMediaDetectedIsoInfo.PSObject.Properties['SourceIso']) { return $false }

	$sourceIso = Get-GuiDeploymentMediaBuilderSourceIsoPath
	$detectedSourceIso = Convert-GuiDeploymentMediaBuilderInputPath -Path ([string]$Script:DeploymentMediaDetectedIsoInfo.SourceIso)
	if ([string]::IsNullOrWhiteSpace($sourceIso) -or [string]::IsNullOrWhiteSpace($detectedSourceIso)) { return $false }

	return [string]::Equals($sourceIso, $detectedSourceIso, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-GuiDeploymentMediaBuilderSelectedEdition
{
	[CmdletBinding()]
	param ()

	if (-not $Script:CmbDeploymentMediaDetectedEdition -or -not $Script:CmbDeploymentMediaDetectedEdition.SelectedItem)
	{
		return $null
	}

	$selectedItem = $Script:CmbDeploymentMediaDetectedEdition.SelectedItem
	if ($selectedItem -is [System.Windows.Controls.ComboBoxItem] -and $selectedItem.Tag)
	{
		return $selectedItem.Tag
	}

	if ($selectedItem.PSObject.Properties['Edition'] -and $selectedItem.Edition)
	{
		return $selectedItem.Edition
	}

	$selectedKey = [string]$selectedItem
	if (
		-not [string]::IsNullOrWhiteSpace($selectedKey) -and
		$Script:DeploymentMediaDetectedEditionLookup -and
		$Script:DeploymentMediaDetectedEditionLookup.ContainsKey($selectedKey)
	)
	{
		return $Script:DeploymentMediaDetectedEditionLookup[$selectedKey]
	}

	if ($Script:DeploymentMediaDetectedIsoInfo -and $Script:DeploymentMediaDetectedIsoInfo.PSObject.Properties['Editions'])
	{
		$editionIndex = 0
		if ($selectedItem.PSObject.Properties['Index'])
		{
			[void][int]::TryParse([string]$selectedItem.Index, [ref]$editionIndex)
		}
		elseif ($Script:TxtDeploymentMediaEditionIndex)
		{
			[void][int]::TryParse([string]$Script:TxtDeploymentMediaEditionIndex.Text, [ref]$editionIndex)
		}

		foreach ($edition in @($Script:DeploymentMediaDetectedIsoInfo.Editions))
		{
			if ($edition.PSObject.Properties['Index'] -and [int]$edition.Index -eq $editionIndex)
			{
				return $edition
			}
		}
	}

	return $null
}

function New-GuiDeploymentMediaBuilderEditionItem
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Edition
	)

	if (-not $Edition.PSObject.Properties['Index'])
	{
		return $null
	}

	$index = 0
	if (-not [int]::TryParse([string]$Edition.Index, [ref]$index) -or $index -lt 1)
	{
		return $null
	}

	$name = ''
	if ($Edition.PSObject.Properties['Name'])
	{
		$name = [string]$Edition.Name
	}
	if ([string]::IsNullOrWhiteSpace($name) -and $Edition.PSObject.Properties['ImageName'])
	{
		$name = [string]$Edition.ImageName
	}
	if ([string]::IsNullOrWhiteSpace($name))
	{
		$name = 'Windows image'
	}

	$architecture = ''
	if ($Edition.PSObject.Properties['Architecture'])
	{
		$architecture = [string]$Edition.Architecture
	}

	$displayName = ('{0}: {1}' -f $index, $name)
	if (-not [string]::IsNullOrWhiteSpace($architecture))
	{
		$displayName = ('{0} ({1})' -f $displayName, $architecture)
	}

	return [pscustomobject]@{
		DisplayName  = $displayName
		Index        = $index
		Name         = $name
		Architecture = $architecture
		Edition      = $Edition
	}
}

function Set-GuiDeploymentMediaBuilderDetectedIsoInfo
{
	[CmdletBinding()]
	[OutputType([int])]
	param (
		[Parameter(Mandatory = $true)]
		[object]$IsoInfo
	)

	$Script:DeploymentMediaDetectedIsoInfo = $IsoInfo
	return (Set-GuiDeploymentMediaBuilderDetectedEditionItems -IsoInfo $IsoInfo)
}

function Set-GuiDeploymentMediaBuilderDetectedEditionItems
{
	[CmdletBinding()]
	[OutputType([int])]
	param (
		[Parameter(Mandatory = $true)]
		[object]$IsoInfo
	)

	$Script:DeploymentMediaDetectedEditionLookup = @{}
	if (-not $Script:CmbDeploymentMediaDetectedEdition)
	{
		Write-GuiDeploymentMediaBuilderViewDebugLog -Message 'Deployment media edition binding skipped because the edition ComboBox is not available.' -Source 'DeploymentMediaBuilderView.EditionBinding.NoCombo'
		return 0
	}

	$Script:CmbDeploymentMediaDetectedEdition.ItemsSource = $null
	$Script:CmbDeploymentMediaDetectedEdition.Items.Clear()
	$Script:CmbDeploymentMediaDetectedEdition.DisplayMemberPath = 'DisplayName'
	$Script:CmbDeploymentMediaDetectedEdition.SelectedValuePath = 'Index'

	if (-not $IsoInfo -or -not $IsoInfo.PSObject.Properties['Editions'])
	{
		$Script:CmbDeploymentMediaDetectedEdition.IsEnabled = $false
		Write-GuiDeploymentMediaBuilderViewDebugLog -Message 'Deployment media edition binding received no usable ISO info payload.' -Source 'DeploymentMediaBuilderView.EditionBinding.NoPayload'
		return 0
	}

	$items = [System.Collections.Generic.List[object]]::new()
	foreach ($edition in @($IsoInfo.Editions))
	{
		$item = New-GuiDeploymentMediaBuilderEditionItem -Edition $edition
		if (-not $item) { continue }

		$Script:DeploymentMediaDetectedEditionLookup[[string]$item.DisplayName] = $edition
		$Script:DeploymentMediaDetectedEditionLookup[[string]$item.Index] = $edition
		[void]$items.Add($item)
	}

	$Script:CmbDeploymentMediaDetectedEdition.ItemsSource = @($items.ToArray())
	$itemCount = @($items.ToArray()).Count
	$Script:CmbDeploymentMediaDetectedEdition.IsEnabled = ($itemCount -gt 0)
	if ($itemCount -gt 0)
	{
		$Script:CmbDeploymentMediaDetectedEdition.SelectedIndex = 0
		Sync-GuiDeploymentMediaBuilderEditionSelection
	}
	Write-GuiDeploymentMediaBuilderViewDebugLog -Message ('Deployment media edition binding completed. ImageKind="{0}"; ImagePath="{1}"; SourceIso="{2}"; Items={3}; ComboItems={4}; IsEnabled={5}; SelectedIndex={6}; TextIndex="{7}"' -f $(if ($IsoInfo.PSObject.Properties['ImageKind']) { [string]$IsoInfo.ImageKind } else { '' }), $(if ($IsoInfo.PSObject.Properties['ImagePath']) { [string]$IsoInfo.ImagePath } else { '' }), $(if ($IsoInfo.PSObject.Properties['SourceIso']) { [string]$IsoInfo.SourceIso } else { '' }), $itemCount, [int]$Script:CmbDeploymentMediaDetectedEdition.Items.Count, [bool]$Script:CmbDeploymentMediaDetectedEdition.IsEnabled, [int]$Script:CmbDeploymentMediaDetectedEdition.SelectedIndex, $(if ($Script:TxtDeploymentMediaEditionIndex) { [string]$Script:TxtDeploymentMediaEditionIndex.Text } else { '' })) -Source 'DeploymentMediaBuilderView.EditionBinding.Completed'

	return [int]$itemCount
}

function Sync-GuiDeploymentMediaBuilderEditionSelection
{
	[CmdletBinding()]
	param ()

	$selectedEdition = Get-GuiDeploymentMediaBuilderSelectedEdition
	if ($selectedEdition -and $selectedEdition.PSObject.Properties['Index'] -and $Script:TxtDeploymentMediaEditionIndex)
	{
		$Script:TxtDeploymentMediaEditionIndex.Text = [string]$selectedEdition.Index
	}
}

function Get-GuiDeploymentMediaBuilderPlan
{
	[CmdletBinding()]
	param ()

	$editionIndex = 1
	if ($Script:TxtDeploymentMediaEditionIndex)
	{
		if (-not [int]::TryParse([string]$Script:TxtDeploymentMediaEditionIndex.Text, [ref]$editionIndex))
		{
			$editionIndex = 0
		}
	}

	return New-GuiDeploymentMediaBuildPlan `
		-SourceIso (Get-GuiDeploymentMediaBuilderSourceIsoPath) `
		-WorkingDirectory $(if ($Script:TxtDeploymentMediaWorkingDirectory) { [string]$Script:TxtDeploymentMediaWorkingDirectory.Text } else { '' }) `
		-EditionIndex $editionIndex `
		-EditionName (Get-GuiDeploymentMediaBuilderEditionName) `
		-AutounattendPath $(if ($Script:TxtDeploymentMediaAutounattend) { [string]$Script:TxtDeploymentMediaAutounattend.Text } else { '' }) `
		-DriverSource $(if ($Script:TxtDeploymentMediaDriverSource) { [string]$Script:TxtDeploymentMediaDriverSource.Text } else { '' }) `
		-UsbTargetRoot $(if ($Script:TxtDeploymentMediaUsbTargetRoot) { [string]$Script:TxtDeploymentMediaUsbTargetRoot.Text } else { '' }) `
		-IsoImageInfo $Script:DeploymentMediaDetectedIsoInfo `
		-OutputMode (Get-GuiDeploymentMediaBuilderOutputMode) `
		-InjectBootDrivers:([bool]($Script:ChkDeploymentMediaBootDrivers -and $Script:ChkDeploymentMediaBootDrivers.IsChecked)) `
		-IncludeBaselineTweaks:([bool]($Script:ChkDeploymentMediaBaselineTweaks -and $Script:ChkDeploymentMediaBaselineTweaks.IsChecked))
}

function Test-GuiDeploymentMediaBuilderPreviewPrerequisites
{
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param ()

	$sourceIso = Get-GuiDeploymentMediaBuilderSourceIsoPath
	if ([string]::IsNullOrWhiteSpace($sourceIso))
	{
		return [pscustomobject]@{ Ready = $false; Message = 'Step 1: choose or import a Windows ISO before previewing.' }
	}
	if ([System.IO.Path]::GetExtension($sourceIso) -ne '.iso')
	{
		return [pscustomobject]@{ Ready = $false; Message = 'Step 1: the source path must point to an .iso file.' }
	}
	if (-not (Test-Path -LiteralPath $sourceIso -PathType Leaf -ErrorAction SilentlyContinue))
	{
		return [pscustomobject]@{ Ready = $false; Message = 'Step 1: the selected ISO path does not exist.' }
	}
	if (-not $Script:DeploymentMediaDetectedIsoInfo)
	{
		return [pscustomobject]@{ Ready = $false; Message = 'Step 2: run Detect Editions for the selected ISO.' }
	}
	if (-not (Test-GuiDeploymentMediaBuilderSourceMatchesDetectedIso))
	{
		return [pscustomobject]@{ Ready = $false; Message = 'Step 2: run Detect Editions again after changing the source ISO.' }
	}
	if (-not $Script:CmbDeploymentMediaDetectedEdition -or -not $Script:CmbDeploymentMediaDetectedEdition.SelectedItem)
	{
		return [pscustomobject]@{ Ready = $false; Message = 'Step 2: select a detected Windows edition.' }
	}

	$editionIndex = 0
	if (-not $Script:TxtDeploymentMediaEditionIndex -or -not [int]::TryParse([string]$Script:TxtDeploymentMediaEditionIndex.Text, [ref]$editionIndex) -or $editionIndex -lt 1)
	{
		return [pscustomobject]@{ Ready = $false; Message = 'Step 2: choose a valid image index.' }
	}

	$workingDirectory = ''
	if ($Script:TxtDeploymentMediaWorkingDirectory)
	{
		$workingDirectory = ([string]$Script:TxtDeploymentMediaWorkingDirectory.Text).Trim()
	}
	if ([string]::IsNullOrWhiteSpace($workingDirectory))
	{
		return [pscustomobject]@{ Ready = $false; Message = 'Step 3: choose a working directory.' }
	}
	if (-not [System.IO.Path]::IsPathRooted($workingDirectory))
	{
		return [pscustomobject]@{ Ready = $false; Message = 'Step 3: the working directory must be an absolute path.' }
	}

	if ((Get-GuiDeploymentMediaBuilderOutputMode) -eq 'Create USB')
	{
		$usbTargetRoot = ''
		if ($Script:TxtDeploymentMediaUsbTargetRoot)
		{
			$usbTargetRoot = ([string]$Script:TxtDeploymentMediaUsbTargetRoot.Text).Trim()
		}
		if ([string]::IsNullOrWhiteSpace($usbTargetRoot))
		{
			return [pscustomobject]@{ Ready = $false; Message = 'Step 3: choose a USB target root for Create USB output.' }
		}
	}

	return [pscustomobject]@{ Ready = $true; Message = 'Ready to preview the build plan.' }
}

function Update-GuiDeploymentMediaBuilderPreviewAvailability
{
	[CmdletBinding()]
	param (
		[bool]$ControlsEnabled = $true
	)

	if (-not $Script:BtnDeploymentMediaPreviewPlan) { return }

	$state = Test-GuiDeploymentMediaBuilderPreviewPrerequisites
	$ready = $ControlsEnabled -and -not $Script:DeploymentMediaBuilderOperation -and [bool]$state.Ready
	$Script:BtnDeploymentMediaPreviewPlan.IsEnabled = $ready
	$Script:BtnDeploymentMediaPreviewPlan.ToolTip = [string]$state.Message

	$diagnosticKey = ('{0}|{1}|{2}|{3}|{4}|{5}' -f $ready, $ControlsEnabled, [bool]$Script:DeploymentMediaBuilderOperation, [bool]$state.Ready, [string]$state.Message, (Get-GuiDeploymentMediaBuilderSourceIsoPath))
	$lastDiagnosticKey = ''
	$lastDiagnosticKeyVariable = Get-Variable -Scope Script -Name DeploymentMediaLastPreviewAvailabilityKey -ErrorAction SilentlyContinue
	if ($lastDiagnosticKeyVariable) { $lastDiagnosticKey = [string]$lastDiagnosticKeyVariable.Value }
	if ($lastDiagnosticKey -ne $diagnosticKey)
	{
		$Script:DeploymentMediaLastPreviewAvailabilityKey = $diagnosticKey
		try
		{
			$detectedSource = if ($Script:DeploymentMediaDetectedIsoInfo -and $Script:DeploymentMediaDetectedIsoInfo.PSObject.Properties['SourceIso']) { [string]$Script:DeploymentMediaDetectedIsoInfo.SourceIso } else { '' }
			$editionItems = if ($Script:CmbDeploymentMediaDetectedEdition) { [int]$Script:CmbDeploymentMediaDetectedEdition.Items.Count } else { 0 }
			$selectedEdition = if ($Script:CmbDeploymentMediaDetectedEdition) { [int]$Script:CmbDeploymentMediaDetectedEdition.SelectedIndex } else { -1 }
			LogDebug ('Deployment media preview availability changed. Ready={0}; ControlsEnabled={1}; OperationActive={2}; PrerequisitesReady={3}; Reason="{4}"; SourceIso="{5}"; DetectedSourceIso="{6}"; EditionItems={7}; SelectedEditionIndex={8}' -f $ready, $ControlsEnabled, [bool]$Script:DeploymentMediaBuilderOperation, [bool]$state.Ready, [string]$state.Message, (Get-GuiDeploymentMediaBuilderSourceIsoPath), $detectedSource, $editionItems, $selectedEdition)
		}
		catch
		{
			Write-SwallowedException -ErrorRecord $_ -Source 'DeploymentMediaBuilderView.UpdatePreviewAvailability.Log' -Severity Warning
		}
	}
}

function Set-GuiDeploymentMediaBuilderStatus
{
	[CmdletBinding()]
	param (
		[string]$Message = '',
		[ValidateSet('muted', 'success', 'warning', 'error')]
		[string]$Tone = 'muted',
		[switch]$ShowBanner
	)

	$theme = $Script:CurrentTheme
	$color = if ($theme) { [string]$theme.TextSecondary } else { '#CDD6EA' }
	switch ($Tone)
	{
		'success' { if ($theme) { $color = [string]$theme.LogSuccess } }
		'warning' { if ($theme) { $color = [string]$theme.LogWarning } }
		'error' { if ($theme) { $color = [string]$theme.LogError } }
	}

	$brush = $null
	try { $brush = ConvertTo-GuiBrush -Color $color -Context 'DeploymentMediaBuilderView.Status' }
	catch
	{
		Write-SwallowedException -ErrorRecord $_ -Source 'DeploymentMediaBuilderView.SetStatus.ConvertBrush' -Severity Warning
		$brush = $null
	}

	foreach ($target in @($Script:TxtDeploymentMediaSelectionStatus, $Script:TxtDeploymentMediaBuildStatus))
	{
		if ($target)
		{
			$target.Text = [string]$Message
			if ($brush) { $target.Foreground = $brush }
		}
	}

	if ($Script:DeploymentMediaStatusBanner)
	{
		try
		{
			$bannerBackground = $null
			$bannerBorder = $null
			switch ($Tone)
			{
				'success'
				{
					if ($theme)
					{
						$bannerBackground = [string]$theme.LowRiskBadgeBg
						$bannerBorder = [string]$theme.LowRiskBadge
					}
				}
				'warning'
				{
					if ($theme)
					{
						$bannerBackground = [string]$theme.RiskMediumBadgeBg
						$bannerBorder = [string]$theme.RiskMediumBadge
					}
				}
				'error'
				{
					if ($theme)
					{
						$bannerBackground = [string]$theme.RiskHighBadgeBg
						$bannerBorder = [string]$theme.RiskHighBadge
					}
				}
				default
				{
					if ($theme)
					{
						$bannerBackground = [string]$theme.CardBg
						$bannerBorder = [string]$theme.CardBorder
					}
				}
			}
			if (-not [string]::IsNullOrWhiteSpace($bannerBackground))
			{
				$Script:DeploymentMediaStatusBanner.Background = ConvertTo-GuiBrush -Color $bannerBackground -Context 'DeploymentMediaBuilderView.StatusBanner.Background'
			}
			if (-not [string]::IsNullOrWhiteSpace($bannerBorder))
			{
				$Script:DeploymentMediaStatusBanner.BorderBrush = ConvertTo-GuiBrush -Color $bannerBorder -Context 'DeploymentMediaBuilderView.StatusBanner.Border'
			}
		}
		catch
		{
			Write-SwallowedException -ErrorRecord $_ -Source 'DeploymentMediaBuilderView.SetStatus.BannerBrush' -Severity Warning
		}
		$Script:DeploymentMediaStatusBanner.Visibility = if ($ShowBanner -and -not [string]::IsNullOrWhiteSpace([string]$Message)) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
	}
}

function Select-GuiDeploymentMediaBuilderWorkerPayload
{
	[CmdletBinding()]
	param (
		[object[]]$Result
	)

	$items = @($Result | Where-Object { $null -ne $_ })
	if ($items.Count -lt 1) { return $null }

	foreach ($item in @($items))
	{
		if (
			$item.PSObject.Properties['SourceIso'] -and
			$item.PSObject.Properties['ImagePath'] -and
			$item.PSObject.Properties['Editions']
		)
		{
			return $item
		}
	}
	foreach ($item in @($items))
	{
		if (
			$item.PSObject.Properties['Path'] -and
			$item.PSObject.Properties['AcquisitionMode']
		)
		{
			return $item
		}
	}
	foreach ($item in @($items))
	{
		if (
			$item.PSObject.Properties['OutputPath'] -and
			$item.PSObject.Properties['ReportPath']
		)
		{
			return $item
		}
	}

	return $items[$items.Count - 1]
}

function Write-GuiDeploymentMediaBuilderErrorLog
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$ErrorRecord,

		[Parameter(Mandatory = $true)]
		[string]$Prefix,

		[Parameter(Mandatory = $true)]
		[string]$Source
	)

	try { LogError (Format-BaselineErrorForLog -ErrorObject $ErrorRecord -Prefix $Prefix) }
	catch { Write-SwallowedException -ErrorRecord $_ -Source $Source -Severity Warning }
}

function Write-GuiDeploymentMediaBuilderViewDebugLog
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Message,

		[string]$Source = 'DeploymentMediaBuilderView.DebugLog'
	)

	try { LogDebug $Message }
	catch
	{
		if (Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Write-SwallowedException -ErrorRecord $_ -Source $Source -Severity Warning
		}
	}
}

function Resolve-GuiDeploymentMediaBuilderSupportPath
{
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateSet('Dialog', 'Execution', 'ProcessHelper')]
		[string]$Name
	)

	$candidates = [System.Collections.Generic.List[string]]::new()
	foreach ($root in @($Script:GuiExtractedRoot, $PSScriptRoot))
	{
		if ([string]::IsNullOrWhiteSpace([string]$root)) { continue }

		switch ($Name)
		{
			'Dialog' { [void]$candidates.Add((Join-Path ([string]$root) 'DeploymentMediaBuilderDialog.ps1')) }
			'Execution'
			{
				[void]$candidates.Add((Join-Path ([string]$root) 'DeploymentMediaBuilder\DeploymentMediaBuilder.Execution.ps1'))
				[void]$candidates.Add((Join-Path ([string]$root) 'DeploymentMediaBuilder.Execution.ps1'))
			}
			'ProcessHelper' { [void]$candidates.Add((Join-Path ([string]$root) '..\SharedHelpers\Process.Helpers.ps1')) }
		}
	}

	foreach ($candidate in @($candidates))
	{
		if ([string]::IsNullOrWhiteSpace([string]$candidate)) { continue }
		$fullPath = [System.IO.Path]::GetFullPath([string]$candidate)
		if (Test-Path -LiteralPath $fullPath -PathType Leaf)
		{
			return $fullPath
		}
	}

	throw ('Required Deployment Media Builder support file was not found: {0}' -f $Name)
}

function Complete-GuiDeploymentMediaBuilderBackgroundOperation
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Operation
	)

	Write-GuiDeploymentMediaBuilderViewDebugLog -Message ('Deployment media background operation finalizing. Name="{0}"; TimedOut={1}; CancelRequested={2}; ForceRequested={3}; TerminalReported={4}; SyncDone={5}; SyncStatus="{6}"' -f [string]$Operation.Name, [bool]$Operation.TimedOut, [bool]$Operation.CancelRequested, [bool]$Operation.CancellationForceRequested, [bool]$Operation.TerminalReported, [bool]$Operation.Sync.Done, [string]$Operation.Sync.Status) -Source 'DeploymentMediaBuilderView.BackgroundOperation.Finalize'

	if ([object]::ReferenceEquals($Script:DeploymentMediaBuilderOperation, $Operation))
	{
		$Script:DeploymentMediaBuilderOperation = $null
	}

	try { if ($Operation.PowerShell) { $Operation.PowerShell.Dispose() } }
	catch { Write-SwallowedException -ErrorRecord $_ -Source 'DeploymentMediaBuilderView.BackgroundOperation.DisposePowerShell' -Severity Warning }
	try { if ($Operation.Timer) { $Operation.Timer.Stop() } }
	catch { Write-SwallowedException -ErrorRecord $_ -Source 'DeploymentMediaBuilderView.BackgroundOperation.StopTimer' -Severity Warning }
	try { if ($Operation.Runspace) { $Operation.Runspace.Dispose() } }
	catch { Write-SwallowedException -ErrorRecord $_ -Source 'DeploymentMediaBuilderView.BackgroundOperation.DisposeRunspace' -Severity Warning }

	if ($Operation.FinallyCallback)
	{
		& $Operation.FinallyCallback
	}

	Write-GuiDeploymentMediaBuilderViewDebugLog -Message ('Deployment media background operation finalized. Name="{0}"; ActiveOperation={1}' -f [string]$Operation.Name, [bool]$Script:DeploymentMediaBuilderOperation) -Source 'DeploymentMediaBuilderView.BackgroundOperation.Finalized'
}

function Convert-GuiDeploymentMediaBuilderWorkerErrorRecord
{
	[CmdletBinding()]
	[OutputType([System.Management.Automation.ErrorRecord])]
	param (
		[Parameter(Mandatory = $true)]
		[System.Management.Automation.ErrorRecord]$ErrorRecord,

		[string]$OperationName = 'Deployment media operation'
	)

	$exception = $ErrorRecord.Exception
	if ($exception -is [System.Management.Automation.MethodInvocationException] -and $exception.InnerException)
	{
		$innerException = $exception.InnerException
		if ($innerException -is [System.Management.Automation.RuntimeException] -and $innerException.ErrorRecord)
		{
			return $innerException.ErrorRecord
		}

		return (New-Object System.Management.Automation.ErrorRecord $innerException, 'DeploymentMediaBuilderWorkerFailed', ([System.Management.Automation.ErrorCategory]::OperationStopped), $OperationName)
	}

	return $ErrorRecord
}

function Stop-GuiDeploymentMediaBuilderBackgroundOperation
{
	[CmdletBinding()]
	[OutputType([bool])]
	param (
		[string]$Reason = 'Deployment media operation cancelled by operator.'
	)

	$operation = $Script:DeploymentMediaBuilderOperation
	if (-not $operation)
	{
		Write-GuiDeploymentMediaBuilderViewDebugLog -Message ('Deployment media cancellation ignored because no operation is active. Reason="{0}"' -f $Reason) -Source 'DeploymentMediaBuilderView.BackgroundOperation.Cancel.NoActiveOperation'
		return $false
	}

	if ($operation.CancelRequested)
	{
		Write-GuiDeploymentMediaBuilderViewDebugLog -Message ('Deployment media cancellation request ignored because cancellation is already pending. Name="{0}"; Reason="{1}"' -f [string]$operation.Name, $Reason) -Source 'DeploymentMediaBuilderView.BackgroundOperation.Cancel.AlreadyPending'
		Set-GuiDeploymentMediaBuilderStatus -Message 'Cancellation is already pending for the deployment media operation.' -Tone 'warning' -ShowBanner
		return $true
	}

	$operation.CancelRequested = $true
	$operation.CancelRequestedUtc = [DateTime]::UtcNow
	$operation.CancelEscalationUtc = $operation.CancelRequestedUtc.AddSeconds(30)
	if ($operation.Sync)
	{
		$operation.Sync.CancelRequested = $true
		$operation.Sync.CancelReason = $Reason
		$operation.Sync.RequestedUtc = $operation.CancelRequestedUtc
		$operation.Sync.Status = 'Cancelling deployment media operation...'
	}

	Set-GuiDeploymentMediaBuilderStatus -Message 'Cancelling deployment media operation...' -Tone 'warning' -ShowBanner
	Write-GuiDeploymentMediaBuilderViewDebugLog -Message ('Deployment media cancellation requested. Name="{0}"; Reason="{1}"; EscalationUtc="{2:o}"' -f [string]$operation.Name, $Reason, $operation.CancelEscalationUtc) -Source 'DeploymentMediaBuilderView.BackgroundOperation.Cancel.Requested'
	return $true
}

function Start-GuiDeploymentMediaBuilderBackgroundOperation
{
	[CmdletBinding()]
	[OutputType([bool])]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Name,

		[Parameter(Mandatory = $true)]
		[scriptblock]$Worker,

		[hashtable]$Context = @{},

		[ValidateRange(1, 86400)]
		[int]$TimeoutSeconds = 7200,

		[scriptblock]$StatusCallback,
		[Parameter(Mandatory = $true)]
		[scriptblock]$CompletedCallback,
		[Parameter(Mandatory = $true)]
		[scriptblock]$FailedCallback,
		[scriptblock]$FinallyCallback
	)

	if ($Script:DeploymentMediaBuilderOperation)
	{
		Write-GuiDeploymentMediaBuilderViewDebugLog -Message ('Deployment media background operation rejected because another operation is active. Requested="{0}"; Active="{1}"' -f $Name, [string]$Script:DeploymentMediaBuilderOperation.Name) -Source 'DeploymentMediaBuilderView.BackgroundOperation.Start.AlreadyActive'
		Set-GuiDeploymentMediaBuilderStatus -Message 'A deployment media operation is already running.' -Tone 'warning' -ShowBanner
		return $false
	}

	$contextKeys = @()
	if ($Context) { $contextKeys = @($Context.Keys | ForEach-Object { [string]$_ } | Sort-Object) }
	Write-GuiDeploymentMediaBuilderViewDebugLog -Message ('Deployment media background operation starting. Name="{0}"; TimeoutSeconds={1}; ContextKeys="{2}"' -f $Name, $TimeoutSeconds, ($contextKeys -join ',')) -Source 'DeploymentMediaBuilderView.BackgroundOperation.Start'

	$syncHash = [hashtable]::Synchronized(@{
		Status = ''
		Done = $false
		CancelRequested = $false
		CancelReason = ''
		RequestedUtc = $null
		CurrentStage = ''
		StageStartedUtc = $null
	})

	$runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
	$runspace.ApartmentState = 'STA'
	$runspace.ThreadOptions = 'ReuseThread'
	$runspace.Open()
	Write-GuiDeploymentMediaBuilderViewDebugLog -Message ('Deployment media runspace opened. Name="{0}"; ApartmentState="{1}"; ThreadOptions="{2}"' -f $Name, [string]$runspace.ApartmentState, [string]$runspace.ThreadOptions) -Source 'DeploymentMediaBuilderView.BackgroundOperation.RunspaceOpened'

	$ps = [System.Management.Automation.PowerShell]::Create()
	$ps.Runspace = $runspace

	$operationScript = {
		param (
			[string]$WorkerText,
			[hashtable]$WorkerContext,
			[hashtable]$Sync
		)

		try
		{
			$workerBlock = [scriptblock]::Create($WorkerText)
			& $workerBlock -Context $WorkerContext -Sync $Sync
		}
		finally
		{
			$Sync.Done = $true
		}
	}

	$null = $ps.AddScript($operationScript).AddArgument($Worker.ToString()).AddArgument($Context).AddArgument($syncHash)

	$asyncResult = $ps.BeginInvoke()
	$timer = [System.Windows.Threading.DispatcherTimer]::new()
	$timer.Interval = [TimeSpan]::FromMilliseconds(150)
	$deadlineUtc = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
	$operation = [pscustomobject]@{
		Name = $Name
		PowerShell = $ps
		Runspace = $runspace
		AsyncResult = $asyncResult
		Timer = $timer
		Sync = $syncHash
		DeadlineUtc = $deadlineUtc
		TimeoutSeconds = $TimeoutSeconds
		TimedOut = $false
		TerminalReported = $false
		FinallyCallback = $FinallyCallback
		CancelRequested = $false
		CancelRequestedUtc = $null
		CancelEscalationUtc = $null
		CancellationForceRequested = $false
		LastStatus = ''
	}
	$Script:DeploymentMediaBuilderOperation = $operation
	Write-GuiDeploymentMediaBuilderViewDebugLog -Message ('Deployment media background operation dispatched. Name="{0}"; AsyncCompleted={1}; DeadlineUtc="{2:o}"' -f $Name, [bool]$asyncResult.IsCompleted, $deadlineUtc) -Source 'DeploymentMediaBuilderView.BackgroundOperation.Dispatched'

	$completeOperationScript = ${function:Complete-GuiDeploymentMediaBuilderBackgroundOperation}
	$convertWorkerErrorScript = ${function:Convert-GuiDeploymentMediaBuilderWorkerErrorRecord}
	$selectWorkerPayloadScript = ${function:Select-GuiDeploymentMediaBuilderWorkerPayload}
	$writeDebugLogScript = ${function:Write-GuiDeploymentMediaBuilderViewDebugLog}
	$writeSwallowedExceptionScript = Get-Command -Name 'Write-SwallowedException' -CommandType Function -ErrorAction SilentlyContinue
	$timer.Add_Tick({
		$status = [string]$syncHash.Status
		if ($StatusCallback -and -not [string]::IsNullOrWhiteSpace($status) -and $status -ne [string]$operation.LastStatus)
		{
			$operation.LastStatus = $status
			& $writeDebugLogScript -Message ('Deployment media background operation status changed. Name="{0}"; Status="{1}"' -f [string]$operation.Name, $status) -Source 'DeploymentMediaBuilderView.BackgroundOperation.Status'
			& $StatusCallback -Message $status
		}

		if (-not $operation.TimedOut -and -not $asyncResult.IsCompleted -and [DateTime]::UtcNow -ge $operation.DeadlineUtc)
		{
			$operation.TimedOut = $true
			$operation.CancelRequested = $true
			$operation.CancelRequestedUtc = [DateTime]::UtcNow
			$operation.CancelEscalationUtc = $operation.CancelRequestedUtc.AddSeconds(30)
			$syncHash.CancelRequested = $true
			$syncHash.CancelReason = ('{0} timed out after {1} second(s).' -f $Name, $TimeoutSeconds)
			$syncHash.RequestedUtc = $operation.CancelRequestedUtc
			$syncHash.Status = ('Cancelling {0} after timeout.' -f $Name)
			& $writeDebugLogScript -Message ('Deployment media background operation timeout reached. Name="{0}"; TimeoutSeconds={1}; DeadlineUtc="{2:o}"' -f $Name, $TimeoutSeconds, $operation.DeadlineUtc) -Source 'DeploymentMediaBuilderView.BackgroundOperation.Timeout'
			$timeoutException = [System.TimeoutException]::new(('{0} timed out after {1} second(s).' -f $Name, $TimeoutSeconds))
			$timeoutRecord = New-Object System.Management.Automation.ErrorRecord $timeoutException, 'DeploymentMediaBuilderOperationTimeout', ([System.Management.Automation.ErrorCategory]::OperationTimeout), $Name
			if (-not $operation.TerminalReported)
			{
				$operation.TerminalReported = $true
				& $FailedCallback -ErrorRecord $timeoutRecord
			}
			return
		}

		if ($operation.CancelRequested -and -not $operation.CancellationForceRequested -and -not $asyncResult.IsCompleted -and $operation.CancelEscalationUtc -and [DateTime]::UtcNow -ge $operation.CancelEscalationUtc)
		{
			$operation.CancellationForceRequested = $true
			& $writeDebugLogScript -Message ('Deployment media background operation cancellation escalation reached. Name="{0}"; CancelRequestedUtc="{1:o}"; EscalationUtc="{2:o}"' -f $Name, $operation.CancelRequestedUtc, $operation.CancelEscalationUtc) -Source 'DeploymentMediaBuilderView.BackgroundOperation.CancelEscalation'
			try { $null = $ps.BeginStop($null, $null) }
			catch
			{
				& $writeDebugLogScript -Message ('Deployment media background operation BeginStop failed during cancellation escalation. Name="{0}"; ExceptionType="{1}"; Message="{2}"' -f $Name, $_.Exception.GetType().FullName, $_.Exception.Message) -Source 'DeploymentMediaBuilderView.BackgroundOperation.BeginStopDebug'
				if ($writeSwallowedExceptionScript) { & $writeSwallowedExceptionScript -ErrorRecord $_ -Source 'DeploymentMediaBuilderView.BackgroundOperation.BeginStop' -Severity Warning }
			}
			if (-not $operation.TerminalReported)
			{
				$operation.TerminalReported = $true
				$cancelException = [System.OperationCanceledException]::new(('{0} cancellation did not complete within the grace period.' -f $Name))
				$cancelRecord = New-Object System.Management.Automation.ErrorRecord $cancelException, 'DeploymentMediaBuilderOperationCancelled', ([System.Management.Automation.ErrorCategory]::OperationStopped), $Name
				& $FailedCallback -ErrorRecord $cancelRecord
			}
			& $completeOperationScript -Operation $operation
			return
		}

		if (-not $asyncResult.IsCompleted)
		{
			return
		}

		$timer.Stop()
		try
		{
			$result = @($ps.EndInvoke($asyncResult))
			& $writeDebugLogScript -Message ('Deployment media background operation completed worker invoke. Name="{0}"; ResultCount={1}; TerminalReported={2}' -f $Name, @($result).Count, [bool]$operation.TerminalReported) -Source 'DeploymentMediaBuilderView.BackgroundOperation.EndInvoke'
			if (-not $operation.TerminalReported)
			{
				$payload = & $selectWorkerPayloadScript -Result $result
				& $writeDebugLogScript -Message ('Deployment media background operation selected payload. Name="{0}"; PayloadType="{1}"' -f $Name, $(if ($payload) { $payload.GetType().FullName } else { '<null>' })) -Source 'DeploymentMediaBuilderView.BackgroundOperation.Payload'
				& $CompletedCallback -Result $payload
			}
		}
		catch
		{
			& $writeDebugLogScript -Message ('Deployment media background operation EndInvoke raised. Name="{0}"; ExceptionType="{1}"; Message="{2}"' -f $Name, $_.Exception.GetType().FullName, $_.Exception.Message) -Source 'DeploymentMediaBuilderView.BackgroundOperation.EndInvokeRaised'
			if ($writeSwallowedExceptionScript) { & $writeSwallowedExceptionScript -ErrorRecord $_ -Source 'DeploymentMediaBuilder.UI.Start-GuiDeploymentMediaBuilderBackgroundOperation:catch370' -Severity Debug }
			& $writeDebugLogScript -Message ('Deployment media background operation worker failed. Name="{0}"; ExceptionType="{1}"; Message="{2}"' -f $Name, $_.Exception.GetType().FullName, $_.Exception.Message) -Source 'DeploymentMediaBuilderView.BackgroundOperation.WorkerFailed'

			if (-not $operation.TerminalReported)
			{
				$workerErrorRecord = & $convertWorkerErrorScript -ErrorRecord $_ -OperationName $Name
				& $FailedCallback -ErrorRecord $workerErrorRecord
			}
		}
		finally
		{
			& $completeOperationScript -Operation $operation
		}
	}.GetNewClosure())
	$timer.Start()
	Write-GuiDeploymentMediaBuilderViewDebugLog -Message ('Deployment media background operation dispatcher timer started. Name="{0}"; IntervalMs={1}' -f $Name, [int]$timer.Interval.TotalMilliseconds) -Source 'DeploymentMediaBuilderView.BackgroundOperation.TimerStarted'

	return $true
}

function Set-GuiDeploymentMediaBuilderControlsEnabled
{
	[CmdletBinding()]
	param ([bool]$Enabled = $true)

	$controls = @(
		$Script:CmbDeploymentMediaMicrosoftIso,
		$Script:BtnDeploymentMediaDownloadMicrosoftIso,
		$Script:TxtDeploymentMediaSourceIso,
		$Script:BtnDeploymentMediaBrowseIso,
		$Script:BtnDeploymentMediaDetectIso,
		$Script:TxtDeploymentMediaEditionIndex,
		$Script:CmbDeploymentMediaDetectedEdition,
		$Script:TxtDeploymentMediaWorkingDirectory,
		$Script:BtnDeploymentMediaBrowseWorking,
		$Script:CmbDeploymentMediaOutputMode,
		$Script:TxtDeploymentMediaUsbTargetRoot,
		$Script:BtnDeploymentMediaBrowseUsbTarget,
		$Script:TxtDeploymentMediaAutounattend,
		$Script:BtnDeploymentMediaCreateAutounattend,
		$Script:BtnDeploymentMediaBrowseAutounattend,
		$Script:TxtDeploymentMediaDriverSource,
		$Script:BtnDeploymentMediaBrowseDrivers,
		$Script:ChkDeploymentMediaBootDrivers,
		$Script:ChkDeploymentMediaBaselineTweaks,
		$Script:BtnDeploymentMediaPreviewPlan
	)

	foreach ($control in $controls)
	{
		if ($control) { $control.IsEnabled = $Enabled }
	}
	if ($Script:CmbDeploymentMediaDetectedEdition)
	{
		$Script:CmbDeploymentMediaDetectedEdition.IsEnabled = $Enabled -and $Script:CmbDeploymentMediaDetectedEdition.Items.Count -gt 0
	}
	Update-GuiDeploymentMediaBuilderPreviewAvailability -ControlsEnabled:$Enabled

	if ($Script:BtnDeploymentMediaStartBuild)
	{
		if ($Script:DeploymentMediaBuilderOperation)
		{
			$Script:BtnDeploymentMediaStartBuild.IsEnabled = $true
			Set-GuiDeploymentMediaBuilderStartButtonMode -CancellationMode
		}
		else
		{
			$Script:BtnDeploymentMediaStartBuild.IsEnabled = $Enabled -and $Script:DeploymentMediaCurrentPlan -and [bool]$Script:DeploymentMediaCurrentPlan.IsValid
			Set-GuiDeploymentMediaBuilderStartButtonMode
		}
	}
}

function Set-GuiDeploymentMediaBuilderStartButtonMode
{
	[CmdletBinding()]
	param (
		[switch]$CancellationMode
	)

	if (-not $Script:BtnDeploymentMediaStartBuild) { return }

	if ($CancellationMode)
	{
		Set-GuiButtonIconContent -Button $Script:BtnDeploymentMediaStartBuild -IconName 'Clear' -Text (Get-UxLocalizedString -Key 'GuiDeploymentMediaCancelOperation' -Fallback 'Cancel Operation') -ToolTip (Get-UxLocalizedString -Key 'GuiDeploymentMediaCancelOperationTip' -Fallback 'Request cancellation and cleanup for the active deployment media operation.')
		Set-ButtonChrome -Button $Script:BtnDeploymentMediaStartBuild -Variant 'Secondary'
		return
	}

	Set-GuiButtonIconContent -Button $Script:BtnDeploymentMediaStartBuild -IconName 'RunTweaks' -Text (Get-UxLocalizedString -Key 'GuiDeploymentMediaStartBuild' -Fallback 'Start ISO Build') -ToolTip (Get-UxLocalizedString -Key 'GuiDeploymentMediaStartBuildTip' -Fallback 'Build the selected deployment media after the plan preview validates successfully.')
	Set-ButtonChrome -Button $Script:BtnDeploymentMediaStartBuild -Variant 'Primary'
}

function Reset-GuiDeploymentMediaBuilderStartState
{
	[CmdletBinding()]
	param ()

	$Script:DeploymentMediaCurrentPlan = $null
	if ($Script:BtnDeploymentMediaStartBuild)
	{
		$Script:BtnDeploymentMediaStartBuild.IsEnabled = $false
	}
	Update-GuiDeploymentMediaBuilderPreviewAvailability
}

function Initialize-GuiDeploymentMediaMicrosoftIsoOptionList
{
	[CmdletBinding()]
	param ()

	if (-not $Script:CmbDeploymentMediaMicrosoftIso) { return }
	if ($Script:CmbDeploymentMediaMicrosoftIso.Items.Count -gt 0) { return }
	if (-not (Get-Command -Name 'Get-GuiDeploymentMediaMicrosoftIsoOptions' -CommandType Function -ErrorAction SilentlyContinue)) { return }

	foreach ($option in @(Get-GuiDeploymentMediaMicrosoftIsoOptions))
	{
		$item = New-Object System.Windows.Controls.ComboBoxItem
		$item.Content = [string]$option.Label
		$item.Tag = $option
		[void]$Script:CmbDeploymentMediaMicrosoftIso.Items.Add($item)
	}
	if ($Script:CmbDeploymentMediaMicrosoftIso.Items.Count -gt 0 -and $Script:CmbDeploymentMediaMicrosoftIso.SelectedIndex -lt 0)
	{
		$Script:CmbDeploymentMediaMicrosoftIso.SelectedIndex = 0
	}
}

function Set-GuiDeploymentMediaBuilderInitialText
{
	[CmdletBinding()]
	param ()

	if ($Script:TxtDeploymentMediaPlanPreview -and [string]::IsNullOrWhiteSpace([string]$Script:TxtDeploymentMediaPlanPreview.Text))
	{
		$Script:TxtDeploymentMediaPlanPreview.Text = 'Use the official Microsoft Media Creation Tool workflow, import an existing ISO, run Detect Editions, then preview the build plan.'
	}
	if ($Script:TxtDeploymentMediaDetectedIsoSummary -and [string]::IsNullOrWhiteSpace([string]$Script:TxtDeploymentMediaDetectedIsoSummary.Text))
	{
		$Script:TxtDeploymentMediaDetectedIsoSummary.Text = 'No ISO inspected yet.'
	}
}

function Sync-GuiDeploymentMediaBuilderViewText
{
	[CmdletBinding()]
	param ()

	if ($Script:BtnDeploymentMediaDetectIso)
	{
		Set-GuiButtonIconContent -Button $Script:BtnDeploymentMediaDetectIso -IconName 'Search' -Text (Get-UxLocalizedString -Key 'GuiDeploymentMediaDetectIso' -Fallback 'Detect Editions') -ToolTip (Get-UxLocalizedString -Key 'GuiDeploymentMediaDetectIsoTip' -Fallback 'Inspect the selected Windows ISO and list available image editions.') -IconSize 14 -Gap 6 -TextFontSize 11
		Set-ButtonChrome -Button $Script:BtnDeploymentMediaDetectIso -Variant 'Secondary' -Compact
	}
	if ($Script:BtnDeploymentMediaDownloadMicrosoftIso)
	{
		Set-GuiButtonIconContent -Button $Script:BtnDeploymentMediaDownloadMicrosoftIso -IconName 'ArrowDownload' -Text (Get-UxLocalizedString -Key 'GuiDeploymentMediaDownloadMicrosoftIso' -Fallback 'Start') -ToolTip (Get-UxLocalizedString -Key 'GuiDeploymentMediaDownloadMicrosoftIsoTip' -Fallback 'Start the selected ISO acquisition workflow. Media Creation Tool options launch the official Microsoft tool and auto-import the completed ISO.') -IconSize 14 -Gap 6 -TextFontSize 11
		Set-ButtonChrome -Button $Script:BtnDeploymentMediaDownloadMicrosoftIso -Variant 'Secondary' -Compact
	}
	if ($Script:BtnDeploymentMediaPreviewPlan)
	{
		Set-GuiButtonIconContent -Button $Script:BtnDeploymentMediaPreviewPlan -IconName 'PreviewRun' -Text (Get-UxLocalizedString -Key 'GuiDeploymentMediaPreviewPlan' -Fallback 'Preview Build Plan') -ToolTip (Get-UxLocalizedString -Key 'GuiDeploymentMediaPreviewPlanTip' -Fallback 'Validate inputs and show the exact setup media build plan before starting.')
		Set-ButtonChrome -Button $Script:BtnDeploymentMediaPreviewPlan -Variant 'Preview'
	}
	if ($Script:BtnDeploymentMediaStartBuild)
	{
		Set-GuiDeploymentMediaBuilderStartButtonMode
	}

	foreach ($button in @(
		$Script:BtnDeploymentMediaBrowseIso,
		$Script:BtnDeploymentMediaBrowseWorking,
		$Script:BtnDeploymentMediaBrowseUsbTarget,
		$Script:BtnDeploymentMediaCreateAutounattend,
		$Script:BtnDeploymentMediaBrowseAutounattend,
		$Script:BtnDeploymentMediaBrowseDrivers
	))
	{
		if ($button)
		{
			Set-ButtonChrome -Button $button -Variant 'Secondary' -Compact
		}
	}

	foreach ($combo in @($Script:CmbDeploymentMediaMicrosoftIso, $Script:CmbDeploymentMediaDetectedEdition, $Script:CmbDeploymentMediaOutputMode))
	{
		if ($combo -and (Get-Command -Name 'Set-ChoiceComboStyle' -CommandType Function -ErrorAction SilentlyContinue))
		{
			Set-ChoiceComboStyle -Combo $combo
		}
	}

	Set-GuiDeploymentMediaBuilderInitialText
	Update-GuiDeploymentMediaBuilderPreviewAvailability
	if (-not $Script:DeploymentMediaCurrentPlan)
	{
		Set-GuiDeploymentMediaBuilderStatus -Message 'Choose an ISO and detect editions to begin.' -Tone 'muted'
	}
}

function Show-GuiDeploymentMediaBuilderFileDialog
{
	[CmdletBinding()]
	param (
		[string]$Filter
	)

	$dialog = New-Object Microsoft.Win32.OpenFileDialog
	$dialog.Filter = $Filter
	if ($dialog.ShowDialog($Script:MainForm) -eq $true)
	{
		return $dialog.FileName
	}
	return $null
}

function Show-GuiDeploymentMediaBuilderFolderDialog
{
	[CmdletBinding()]
	param (
		[string]$Description = 'Select folder'
	)

	Add-Type -AssemblyName System.Windows.Forms
	$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
	$dialog.Description = $Description
	$dialog.ShowNewFolderButton = $true
	if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK)
	{
		return $dialog.SelectedPath
	}
	return $null
}

