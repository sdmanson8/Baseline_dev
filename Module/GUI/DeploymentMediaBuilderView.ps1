# DeploymentMediaBuilderView.ps1

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

	if ($Script:CmbDeploymentMediaDetectedEdition -and $Script:CmbDeploymentMediaDetectedEdition.SelectedItem -and $Script:CmbDeploymentMediaDetectedEdition.SelectedItem.Tag)
	{
		return [string]$Script:CmbDeploymentMediaDetectedEdition.SelectedItem.Tag.Name
	}

	return ''
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
		-SourceIso $(if ($Script:TxtDeploymentMediaSourceIso) { [string]$Script:TxtDeploymentMediaSourceIso.Text } else { '' }) `
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
	try { $brush = ConvertTo-GuiBrush -Color $color -Context 'DeploymentMediaBuilderView.Status' } catch { $brush = $null }

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
		$Script:DeploymentMediaStatusBanner.Visibility = if ($ShowBanner -and -not [string]::IsNullOrWhiteSpace([string]$Message)) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
	}
}

function Set-GuiDeploymentMediaBuilderControlsEnabled
{
	[CmdletBinding()]
	param ([bool]$Enabled = $true)

	$controls = @(
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

	if ($Script:BtnDeploymentMediaStartBuild)
	{
		$Script:BtnDeploymentMediaStartBuild.IsEnabled = $Enabled -and $Script:DeploymentMediaCurrentPlan -and [bool]$Script:DeploymentMediaCurrentPlan.IsValid
	}
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
}

function Set-GuiDeploymentMediaBuilderInitialText
{
	[CmdletBinding()]
	param ()

	if ($Script:TxtDeploymentMediaPlanPreview -and [string]::IsNullOrWhiteSpace([string]$Script:TxtDeploymentMediaPlanPreview.Text))
	{
		$Script:TxtDeploymentMediaPlanPreview.Text = 'Select an official Microsoft Windows 10/11 ISO, run Detect Editions, then use Preview Build Plan before Start ISO Build.'
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
	if ($Script:BtnDeploymentMediaPreviewPlan)
	{
		Set-GuiButtonIconContent -Button $Script:BtnDeploymentMediaPreviewPlan -IconName 'PreviewRun' -Text (Get-UxLocalizedString -Key 'GuiDeploymentMediaPreviewPlan' -Fallback 'Preview Build Plan') -ToolTip (Get-UxLocalizedString -Key 'GuiDeploymentMediaPreviewPlanTip' -Fallback 'Validate inputs and show the exact setup media build plan before starting.') -IconSize 14 -Gap 6 -TextFontSize 11
		Set-ButtonChrome -Button $Script:BtnDeploymentMediaPreviewPlan -Variant 'Preview' -Compact
	}
	if ($Script:BtnDeploymentMediaStartBuild)
	{
		Set-GuiButtonIconContent -Button $Script:BtnDeploymentMediaStartBuild -IconName 'RunTweaks' -Text (Get-UxLocalizedString -Key 'GuiDeploymentMediaStartBuild' -Fallback 'Start ISO Build') -ToolTip (Get-UxLocalizedString -Key 'GuiDeploymentMediaStartBuildTip' -Fallback 'Build the selected deployment media after the plan preview validates successfully.') -IconSize 14 -Gap 6 -TextFontSize 11
		Set-ButtonChrome -Button $Script:BtnDeploymentMediaStartBuild -Variant 'Primary' -Compact
	}

	foreach ($button in @(
		$Script:BtnDeploymentMediaBrowseIso,
		$Script:BtnDeploymentMediaBrowseWorking,
		$Script:BtnDeploymentMediaBrowseUsbTarget,
		$Script:BtnDeploymentMediaBrowseAutounattend,
		$Script:BtnDeploymentMediaBrowseDrivers
	))
	{
		if ($button)
		{
			Set-ButtonChrome -Button $button -Variant 'Secondary' -Compact
		}
	}

	foreach ($combo in @($Script:CmbDeploymentMediaDetectedEdition, $Script:CmbDeploymentMediaOutputMode))
	{
		if ($combo -and (Get-Command -Name 'Set-ChoiceComboStyle' -CommandType Function -ErrorAction SilentlyContinue))
		{
			Set-ChoiceComboStyle -Combo $combo
		}
	}

	Set-GuiDeploymentMediaBuilderInitialText
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

function Invoke-GuiDeploymentMediaBuilderDetectIso
{
	[CmdletBinding()]
	param ()

	if (-not $Script:TxtDeploymentMediaSourceIso) { return }

	try
	{
		$isoInfo = Get-GuiDeploymentMediaIsoImageInfo -SourceIso ([string]$Script:TxtDeploymentMediaSourceIso.Text)
		$Script:DeploymentMediaDetectedIsoInfo = $isoInfo
		if ($Script:CmbDeploymentMediaDetectedEdition)
		{
			$Script:CmbDeploymentMediaDetectedEdition.Items.Clear()
			foreach ($edition in @($isoInfo.Editions))
			{
				$item = New-Object System.Windows.Controls.ComboBoxItem
				$item.Content = ('{0}: {1}' -f $edition.Index, $edition.Name)
				$item.Tag = $edition
				[void]$Script:CmbDeploymentMediaDetectedEdition.Items.Add($item)
			}
			$Script:CmbDeploymentMediaDetectedEdition.IsEnabled = ($Script:CmbDeploymentMediaDetectedEdition.Items.Count -gt 0)
			if ($Script:CmbDeploymentMediaDetectedEdition.Items.Count -gt 0)
			{
				$Script:CmbDeploymentMediaDetectedEdition.SelectedIndex = 0
			}
		}
		if ($Script:TxtDeploymentMediaEditionIndex -and $isoInfo.Editions -and @($isoInfo.Editions).Count -gt 0)
		{
			$Script:TxtDeploymentMediaEditionIndex.Text = [string]$isoInfo.Editions[0].Index
		}
		if ($Script:TxtDeploymentMediaDetectedIsoSummary)
		{
			$Script:TxtDeploymentMediaDetectedIsoSummary.Text = ('Detected {0}: {1}. Editions: {2}.' -f $isoInfo.ImageKind, $isoInfo.ImagePath, @($isoInfo.Editions).Count)
		}
		if ($Script:TxtDeploymentMediaPlanPreview)
		{
			$Script:TxtDeploymentMediaPlanPreview.Text = ('Detected {0}: {1}{2}Edition count: {3}' -f $isoInfo.ImageKind, $isoInfo.ImagePath, [Environment]::NewLine, @($isoInfo.Editions).Count)
		}
		Reset-GuiDeploymentMediaBuilderStartState
		Set-GuiDeploymentMediaBuilderStatus -Message 'ISO editions detected. Preview the build plan to continue.' -Tone 'success' -ShowBanner
	}
	catch
	{
		$Script:DeploymentMediaDetectedIsoInfo = $null
		if ($Script:CmbDeploymentMediaDetectedEdition)
		{
			$Script:CmbDeploymentMediaDetectedEdition.Items.Clear()
			$Script:CmbDeploymentMediaDetectedEdition.IsEnabled = $false
		}
		Reset-GuiDeploymentMediaBuilderStartState
		if ($Script:TxtDeploymentMediaDetectedIsoSummary) { $Script:TxtDeploymentMediaDetectedIsoSummary.Text = 'ISO detection failed.' }
		if ($Script:TxtDeploymentMediaPlanPreview) { $Script:TxtDeploymentMediaPlanPreview.Text = ('ISO detection failed: {0}' -f $_.Exception.Message) }
		Set-GuiDeploymentMediaBuilderStatus -Message ('ISO detection failed: {0}' -f $_.Exception.Message) -Tone 'error' -ShowBanner
		try { LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Deployment media ISO detection failed') } catch { Write-Warning 'Deployment media ISO detection failed, and the failure could not be written to the Baseline log.' }
		[void](Show-ThemedDialog -Title 'Deployment Media Builder' -Message ("ISO detection failed.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
	}
}

function Invoke-GuiDeploymentMediaBuilderPreviewPlan
{
	[CmdletBinding()]
	param ()

	$plan = Get-GuiDeploymentMediaBuilderPlan
	$Script:DeploymentMediaCurrentPlan = $plan
	if ($Script:TxtDeploymentMediaPlanPreview)
	{
		$Script:TxtDeploymentMediaPlanPreview.Text = Convert-GuiDeploymentMediaBuildPlanToText -Plan $plan
	}
	if ($Script:BtnDeploymentMediaStartBuild)
	{
		$Script:BtnDeploymentMediaStartBuild.IsEnabled = [bool]$plan.IsValid
	}

	if ([bool]$plan.IsValid)
	{
		Set-GuiDeploymentMediaBuilderStatus -Message 'Build plan validated. Start ISO Build is available.' -Tone 'success' -ShowBanner
	}
	else
	{
		Set-GuiDeploymentMediaBuilderStatus -Message 'Build plan needs required inputs before Start ISO Build can run.' -Tone 'warning' -ShowBanner
	}
}

function Invoke-GuiDeploymentMediaBuilderStartBuild
{
	[CmdletBinding()]
	param ()

	$plan = Get-GuiDeploymentMediaBuilderPlan
	$Script:DeploymentMediaCurrentPlan = $plan
	if ($Script:TxtDeploymentMediaPlanPreview)
	{
		$Script:TxtDeploymentMediaPlanPreview.Text = Convert-GuiDeploymentMediaBuildPlanToText -Plan $plan
	}
	if (-not [bool]$plan.IsValid)
	{
		if ($Script:BtnDeploymentMediaStartBuild) { $Script:BtnDeploymentMediaStartBuild.IsEnabled = $false }
		Set-GuiDeploymentMediaBuilderStatus -Message 'Preview the plan and resolve validation issues before starting.' -Tone 'warning' -ShowBanner
		return
	}

	$confirm = Show-ThemedDialog -Title 'Deployment Media Builder' -Message "Start ISO Build will copy the selected Microsoft ISO into a working folder, apply the requested setup customizations, produce the selected output, and save an auditable build report. Confirm that the source ISO, edition, and output target are correct before continuing." -Buttons @('Cancel', 'Start ISO Build') -AccentButton 'Start ISO Build'
	if ($confirm -ne 'Start ISO Build') { return }

	$Script:DeploymentMediaBuildInProgress = $true
	Set-GuiDeploymentMediaBuilderControlsEnabled -Enabled:$false
	Set-GuiDeploymentMediaBuilderStatus -Message 'Deployment media build started.' -Tone 'muted' -ShowBanner
	try
	{
		$buildResult = Invoke-GuiDeploymentMediaBuild -Plan $plan -ProgressCallback {
			param([string]$Message)
			if ($Script:TxtDeploymentMediaPlanPreview)
			{
				$Script:TxtDeploymentMediaPlanPreview.Text = (Convert-GuiDeploymentMediaBuildPlanToText -Plan $plan) + [Environment]::NewLine + [Environment]::NewLine + $Message
			}
			Set-GuiDeploymentMediaBuilderStatus -Message $Message -Tone 'muted' -ShowBanner
		}.GetNewClosure()
		$Script:DeploymentMediaCurrentPlan = $plan
		if ($Script:TxtDeploymentMediaPlanPreview)
		{
			$Script:TxtDeploymentMediaPlanPreview.Text = (Convert-GuiDeploymentMediaBuildPlanToText -Plan $plan) + [Environment]::NewLine + [Environment]::NewLine + ('Build output: {0}' -f $buildResult.OutputPath) + [Environment]::NewLine + ('Build report saved: {0}' -f $buildResult.ReportPath)
		}
		Set-GuiDeploymentMediaBuilderStatus -Message ('Build complete. Report: {0}' -f $buildResult.ReportPath) -Tone 'success' -ShowBanner
	}
	catch
	{
		if ($Script:TxtDeploymentMediaPlanPreview)
		{
			$Script:TxtDeploymentMediaPlanPreview.Text = (Convert-GuiDeploymentMediaBuildPlanToText -Plan $plan) + [Environment]::NewLine + [Environment]::NewLine + ('Build failed: {0}' -f $_.Exception.Message)
		}
		Set-GuiDeploymentMediaBuilderStatus -Message ('Build failed: {0}' -f $_.Exception.Message) -Tone 'error' -ShowBanner
		try { LogError (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Deployment media build failed') } catch { Write-Warning 'Deployment media build failed, and the failure could not be written to the Baseline log.' }
		[void](Show-ThemedDialog -Title 'Deployment Media Builder' -Message ("Deployment media build failed.`n`n{0}" -f $_.Exception.Message) -Buttons @('OK') -AccentButton 'OK')
	}
	finally
	{
		$Script:DeploymentMediaBuildInProgress = $false
		Set-GuiDeploymentMediaBuilderControlsEnabled -Enabled:$true
	}
}

function Initialize-GuiDeploymentMediaBuilderView
{
	[CmdletBinding()]
	param ()

	if ($Script:DeploymentMediaBuilderViewInitialized) { return }
	if (-not $Script:DeploymentMediaView) { return }

	$Script:DeploymentMediaBuilderViewInitialized = $true
	if ($Script:TxtDeploymentMediaWorkingDirectory -and [string]::IsNullOrWhiteSpace([string]$Script:TxtDeploymentMediaWorkingDirectory.Text))
	{
		$Script:TxtDeploymentMediaWorkingDirectory.Text = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Baseline\DeploymentMediaBuilder\Working'
	}
	if ($Script:CmbDeploymentMediaOutputMode -and $Script:CmbDeploymentMediaOutputMode.SelectedIndex -lt 0)
	{
		$Script:CmbDeploymentMediaOutputMode.SelectedIndex = 0
	}

	$markPlanDirty = {
		Reset-GuiDeploymentMediaBuilderStartState
		Set-GuiDeploymentMediaBuilderStatus -Message 'Preview the build plan after changing inputs.' -Tone 'muted'
	}.GetNewClosure()

	foreach ($textBox in @(
		$Script:TxtDeploymentMediaSourceIso,
		$Script:TxtDeploymentMediaEditionIndex,
		$Script:TxtDeploymentMediaWorkingDirectory,
		$Script:TxtDeploymentMediaUsbTargetRoot,
		$Script:TxtDeploymentMediaAutounattend,
		$Script:TxtDeploymentMediaDriverSource
	))
	{
		if ($textBox)
		{
			Register-GuiEventHandler -Source $textBox -EventName 'TextChanged' -Handler $markPlanDirty | Out-Null
		}
	}

	foreach ($selector in @($Script:CmbDeploymentMediaDetectedEdition, $Script:CmbDeploymentMediaOutputMode))
	{
		if ($selector)
		{
			Register-GuiEventHandler -Source $selector -EventName 'SelectionChanged' -Handler $markPlanDirty | Out-Null
		}
	}

	foreach ($checkBox in @($Script:ChkDeploymentMediaBootDrivers, $Script:ChkDeploymentMediaBaselineTweaks))
	{
		if ($checkBox)
		{
			Register-GuiEventHandler -Source $checkBox -EventName 'Checked' -Handler $markPlanDirty | Out-Null
			Register-GuiEventHandler -Source $checkBox -EventName 'Unchecked' -Handler $markPlanDirty | Out-Null
		}
	}

	if ($Script:BtnDeploymentMediaBrowseIso)
	{
		Register-GuiEventHandler -Source $Script:BtnDeploymentMediaBrowseIso -EventName 'Click' -Handler ({
			$path = Show-GuiDeploymentMediaBuilderFileDialog -Filter 'Windows ISO (*.iso)|*.iso'
			if ($path -and $Script:TxtDeploymentMediaSourceIso) { $Script:TxtDeploymentMediaSourceIso.Text = $path }
		}.GetNewClosure()) | Out-Null
	}
	if ($Script:BtnDeploymentMediaBrowseAutounattend)
	{
		Register-GuiEventHandler -Source $Script:BtnDeploymentMediaBrowseAutounattend -EventName 'Click' -Handler ({
			$path = Show-GuiDeploymentMediaBuilderFileDialog -Filter 'Answer files (*.xml)|*.xml'
			if ($path -and $Script:TxtDeploymentMediaAutounattend) { $Script:TxtDeploymentMediaAutounattend.Text = $path }
		}.GetNewClosure()) | Out-Null
	}
	if ($Script:BtnDeploymentMediaBrowseWorking)
	{
		Register-GuiEventHandler -Source $Script:BtnDeploymentMediaBrowseWorking -EventName 'Click' -Handler ({
			$path = Show-GuiDeploymentMediaBuilderFolderDialog -Description 'Select the deployment media working directory.'
			if ($path -and $Script:TxtDeploymentMediaWorkingDirectory) { $Script:TxtDeploymentMediaWorkingDirectory.Text = $path }
		}.GetNewClosure()) | Out-Null
	}
	if ($Script:BtnDeploymentMediaBrowseDrivers)
	{
		Register-GuiEventHandler -Source $Script:BtnDeploymentMediaBrowseDrivers -EventName 'Click' -Handler ({
			$path = Show-GuiDeploymentMediaBuilderFolderDialog -Description 'Select the deployment driver source directory.'
			if ($path -and $Script:TxtDeploymentMediaDriverSource) { $Script:TxtDeploymentMediaDriverSource.Text = $path }
		}.GetNewClosure()) | Out-Null
	}
	if ($Script:BtnDeploymentMediaBrowseUsbTarget)
	{
		Register-GuiEventHandler -Source $Script:BtnDeploymentMediaBrowseUsbTarget -EventName 'Click' -Handler ({
			$path = Show-GuiDeploymentMediaBuilderFolderDialog -Description 'Select the removable drive root.'
			if ($path -and $Script:TxtDeploymentMediaUsbTargetRoot) { $Script:TxtDeploymentMediaUsbTargetRoot.Text = [System.IO.Path]::GetPathRoot($path) }
		}.GetNewClosure()) | Out-Null
	}
	if ($Script:BtnDeploymentMediaDetectIso)
	{
		Register-GuiEventHandler -Source $Script:BtnDeploymentMediaDetectIso -EventName 'Click' -Handler ({ Invoke-GuiDeploymentMediaBuilderDetectIso }.GetNewClosure()) | Out-Null
	}
	if ($Script:BtnDeploymentMediaPreviewPlan)
	{
		Register-GuiEventHandler -Source $Script:BtnDeploymentMediaPreviewPlan -EventName 'Click' -Handler ({ Invoke-GuiDeploymentMediaBuilderPreviewPlan }.GetNewClosure()) | Out-Null
	}
	if ($Script:BtnDeploymentMediaStartBuild)
	{
		Register-GuiEventHandler -Source $Script:BtnDeploymentMediaStartBuild -EventName 'Click' -Handler ({ Invoke-GuiDeploymentMediaBuilderStartBuild }.GetNewClosure()) | Out-Null
	}

	Sync-GuiDeploymentMediaBuilderViewText
}
